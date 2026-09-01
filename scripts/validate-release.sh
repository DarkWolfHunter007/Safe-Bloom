#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# Safe Bloom — Release Metadata Validation Script
# ──────────────────────────────────────────────────────────────────────────────
# Run this script to validate that latest-release.json is well-formed,
# that all referenced artifacts exist at their download URLs, and that
# SHA-256 values actually match the downloadable files.
#
# Usage:
#   ./scripts/validate-release.sh                    # Validate latest-release.json in repo root
#   ./scripts/validate-release.sh /path/to/file.json # Validate a specific file
#   SKIP_DOWNLOAD=1 ./scripts/validate-release.sh    # Skip download verification (schema only)
#
# Exit codes:
#   0 = All checks passed
#   1 = Validation failure
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

METADATA_FILE="${1:-latest-release.json}"
SKIP_DOWNLOAD="${SKIP_DOWNLOAD:-0}"
ERRORS=0
WARNINGS=0

# ── Color helpers ─────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

pass()  { echo -e "${GREEN}✅ PASS:${NC} $1"; }
fail()  { echo -e "${RED}❌ FAIL:${NC} $1"; ERRORS=$((ERRORS + 1)); }
warn()  { echo -e "${YELLOW}⚠️  WARN:${NC} $1"; WARNINGS=$((WARNINGS + 1)); }
info()  { echo -e "   ℹ️  $1"; }

echo "═══════════════════════════════════════════════════════════════"
echo "  Safe Bloom — Release Metadata Validation"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ── Test A: Metadata file exists ─────────────────────────────────────────────
if [ ! -f "${METADATA_FILE}" ]; then
  fail "Metadata file not found: ${METADATA_FILE}"
  echo ""
  echo "Result: ${ERRORS} failures"
  exit 1
fi
pass "Metadata file exists: ${METADATA_FILE}"

# ── Test A.1: Valid JSON ─────────────────────────────────────────────────────
if ! python3 -m json.tool "${METADATA_FILE}" > /dev/null 2>&1; then
  fail "Metadata is not valid JSON"
  exit 1
fi
pass "Metadata is valid JSON"

# ── Test A.2: Required fields present ────────────────────────────────────────
REQUIRED_FIELDS="tag version commit_sha release_date release_url artifacts generated_by"
for field in ${REQUIRED_FIELDS}; do
  if ! python3 -c "import json; d=json.load(open('${METADATA_FILE}')); assert '${field}' in d" 2>/dev/null; then
    fail "Missing required field: ${field}"
  else
    pass "Required field present: ${field}"
  fi
done

# ── Test D: Tag / version / commit look correct ──────────────────────────────
python3 << VALIDATE_FIELDS
import json, re, sys

with open('${METADATA_FILE}') as f:
    data = json.load(f)

errors = 0

# Tag must start with 'v'
tag = data.get('tag', '')
if not re.match(r'^v\d+', tag):
    print('\033[0;31m❌ FAIL:\033[0m Tag does not match expected format v*: ' + tag)
    errors += 1
else:
    print('\033[0;32m✅ PASS:\033[0m Tag format valid: ' + tag)

# Version should be the tag without 'v' prefix
version = data.get('version', '')
expected_version = tag.lstrip('v')
if version != expected_version:
    print(f'\033[0;31m❌ FAIL:\033[0m Version "{version}" does not match tag "{tag}" (expected "{expected_version}")')
    errors += 1
else:
    print(f'\033[0;32m✅ PASS:\033[0m Version matches tag: {version}')

# Commit SHA must be 40 hex characters
commit = data.get('commit_sha', '')
if not re.match(r'^[0-9a-f]{40}$', commit):
    print(f'\033[0;31m❌ FAIL:\033[0m commit_sha is not a valid 40-char hex SHA: {commit}')
    errors += 1
else:
    print(f'\033[0;32m✅ PASS:\033[0m commit_sha is valid: {commit[:12]}...')

# Release date must be ISO 8601
release_date = data.get('release_date', '')
if not re.match(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$', release_date):
    print(f'\033[0;31m❌ FAIL:\033[0m release_date is not ISO 8601 UTC: {release_date}')
    errors += 1
else:
    print(f'\033[0;32m✅ PASS:\033[0m release_date is ISO 8601: {release_date}')

# generated_by must be github-actions
generated_by = data.get('generated_by', '')
if generated_by != 'github-actions':
    print(f'\033[0;31m❌ FAIL:\033[0m generated_by is not "github-actions": {generated_by}')
    errors += 1
else:
    print(f'\033[0;32m✅ PASS:\033[0m generated_by: {generated_by}')

sys.exit(errors)
VALIDATE_FIELDS
if [ $? -ne 0 ]; then
  ERRORS=$((ERRORS + 1))
fi

# ── Test B & C: Artifacts validation ─────────────────────────────────────────
echo ""
echo "── Artifact Validation ──────────────────────────────────────────"

python3 << ARTIFACT_VALIDATE
import json, re, sys

with open('${METADATA_FILE}') as f:
    data = json.load(f)

artifacts = data.get('artifacts', [])
errors = 0
expected_abis = {'arm64-v8a', 'armeabi-v7a', 'x86_64', 'universal'}
found_abis = set()

if len(artifacts) < 4:
    print(f'\033[0;31m❌ FAIL:\033[0m Expected at least 4 artifacts, found {len(artifacts)}')
    errors += 1
else:
    print(f'\033[0;32m✅ PASS:\033[0m Found {len(artifacts)} artifacts')

for i, artifact in enumerate(artifacts):
    prefix = f'  Artifact[{i}] ({artifact.get("filename", "?")}):'

    # Required artifact fields
    for field in ['filename', 'abi', 'sha256', 'download_url', 'size_bytes']:
        if field not in artifact:
            print(f'\033[0;31m❌ FAIL:\033[0m {prefix} missing field "{field}"')
            errors += 1

    # SHA-256 must be 64 hex characters
    sha = artifact.get('sha256', '')
    if not re.match(r'^[0-9a-f]{64}$', sha):
        print(f'\033[0;31m❌ FAIL:\033[0m {prefix} sha256 is not valid (64 hex chars): {sha}')
        errors += 1
    else:
        print(f'\033[0;32m✅ PASS:\033[0m {prefix} sha256 format valid: {sha[:16]}...')

    # Check for obviously fake/placeholder SHA values
    if sha in ['0' * 64, 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855']:
        print(f'\033[0;31m❌ FAIL:\033[0m {prefix} sha256 appears to be a placeholder (zero-hash or empty-file hash)')
        errors += 1

    # Filename must end with .apk
    filename = artifact.get('filename', '')
    if not filename.endswith('.apk'):
        print(f'\033[0;31m❌ FAIL:\033[0m {prefix} filename does not end with .apk')
        errors += 1

    # Download URL must point to the correct repo and tag
    url = artifact.get('download_url', '')
    tag = data.get('tag', '')
    if tag not in url:
        print(f'\033[0;31m❌ FAIL:\033[0m {prefix} download_url does not contain tag {tag}')
        errors += 1
    if 'DarkWolfHunter007/Safe-Bloom' not in url:
        print(f'\033[0;31m❌ FAIL:\033[0m {prefix} download_url does not reference correct repository')
        errors += 1

    # Size must be positive
    size = artifact.get('size_bytes', 0)
    if not isinstance(size, int) or size <= 0:
        print(f'\033[0;31m❌ FAIL:\033[0m {prefix} size_bytes is not a positive integer: {size}')
        errors += 1

    abi = artifact.get('abi', '')
    found_abis.add(abi)

# Check all expected ABIs are present
missing_abis = expected_abis - found_abis
if missing_abis:
    print(f'\033[0;31m❌ FAIL:\033[0m Missing ABI variants: {missing_abis}')
    errors += 1
else:
    print(f'\033[0;32m✅ PASS:\033[0m All expected ABI variants present: {sorted(found_abis)}')

sys.exit(min(errors, 1))
ARTIFACT_VALIDATE

if [ $? -ne 0 ]; then
  ERRORS=$((ERRORS + 1))
fi

# ── Test B (download): Verify artifacts actually exist at URLs ───────────────
if [ "${SKIP_DOWNLOAD}" = "0" ]; then
  echo ""
  echo "── Download Verification ──────────────────────────────────────"

  python3 << DOWNLOAD_VERIFY
import json, urllib.request, hashlib, sys, tempfile, os

with open('${METADATA_FILE}') as f:
    data = json.load(f)

errors = 0
for artifact in data.get('artifacts', []):
    url = artifact['download_url']
    filename = artifact['filename']
    expected_sha = artifact['sha256']

    print(f'\n  Checking: {filename}')
    print(f'    URL: {url}')

    try:
        req = urllib.request.Request(url, method='HEAD')
        resp = urllib.request.urlopen(req, timeout=15)
        status = resp.getcode()
        if status == 200:
            print(f'\033[0;32m✅ PASS:\033[0m    {filename} exists (HTTP {status})')
        else:
            print(f'\033[0;31m❌ FAIL:\033[0m    {filename} returned HTTP {status}')
            errors += 1
    except Exception as e:
        print(f'\033[0;31m❌ FAIL:\033[0m    {filename} not accessible: {e}')
        errors += 1
        continue

    # Full download + SHA-256 verification
    try:
        print(f'    Downloading for SHA-256 verification...')
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix='.apk')
        urllib.request.urlretrieve(url, tmp.name)
        with open(tmp.name, 'rb') as f:
            actual_sha = hashlib.sha256(f.read()).hexdigest()
        os.unlink(tmp.name)

        if actual_sha == expected_sha:
            print(f'\033[0;32m✅ PASS:\033[0m    SHA-256 verified: {actual_sha[:16]}...')
        else:
            print(f'\033[0;31m❌ FAIL:\033[0m    SHA-256 MISMATCH!')
            print(f'      Expected: {expected_sha}')
            print(f'      Actual:   {actual_sha}')
            errors += 1
    except Exception as e:
        print(f'\033[0;33m⚠️  WARN:\033[0m    Could not download for SHA-256 check: {e}')

sys.exit(min(errors, 1))
DOWNLOAD_VERIFY

  if [ $? -ne 0 ]; then
    ERRORS=$((ERRORS + 1))
  fi
else
  warn "Download verification skipped (SKIP_DOWNLOAD=1)"
fi

# ── Test G: Verify SHA-256 uniqueness ────────────────────────────────────────
echo ""
echo "── SHA-256 Uniqueness Check ─────────────────────────────────────"
python3 << SHA_UNIQUE
import json, sys

with open('${METADATA_FILE}') as f:
    data = json.load(f)

shas = [a['sha256'] for a in data.get('artifacts', [])]
if len(shas) != len(set(shas)):
    print('\033[0;31m❌ FAIL:\033[0m Duplicate SHA-256 values found — different APKs must not share the same hash')
    sys.exit(1)
else:
    print(f'\033[0;32m✅ PASS:\033[0m All {len(shas)} SHA-256 values are unique')
SHA_UNIQUE
if [ $? -ne 0 ]; then
  ERRORS=$((ERRORS + 1))
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════"
if [ "${ERRORS}" -gt 0 ]; then
  echo -e "${RED}  RESULT: ${ERRORS} failure(s), ${WARNINGS} warning(s)${NC}"
  exit 1
else
  echo -e "${GREEN}  RESULT: All checks passed (${WARNINGS} warning(s))${NC}"
  exit 0
fi
