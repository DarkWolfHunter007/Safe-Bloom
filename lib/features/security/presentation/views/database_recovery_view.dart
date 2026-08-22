import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../tracking/data/repositories/tracking_repository.dart';

class DatabaseRecoveryView extends StatefulWidget {
  final String errorMessage;
  final VoidCallback onRecovered;
  final VoidCallback onPurged;

  const DatabaseRecoveryView({
    super.key,
    required this.errorMessage,
    required this.onRecovered,
    required this.onPurged,
  });

  @override
  State<DatabaseRecoveryView> createState() => _DatabaseRecoveryViewState();
}

class _DatabaseRecoveryViewState extends State<DatabaseRecoveryView> {
  final TrackingRepository _repository = TrackingRepository.instance;
  bool _isProcessing = false;
  bool _showErrorDetails = false;

  // Kept at state level so StatefulBuilder rebuilds don't recreate/dispose them mid-dialog
  final TextEditingController _vaultController = TextEditingController();
  final TextEditingController _vaultPasswordController = TextEditingController();
  final TextEditingController _jsonController = TextEditingController();

  @override
  void dispose() {
    _vaultController.dispose();
    _vaultPasswordController.dispose();
    _jsonController.dispose();
    super.dispose();
  }

  Future<void> _handleRestoreEncryptedVault() async {
    _vaultController.clear();
    _vaultPasswordController.clear();
    bool obscure = true;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.lightCardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          title: Row(
            children: [
              const Icon(Icons.shield_rounded, color: AppColors.dropCoral, size: 22),
              const SizedBox(width: 8),
              Text(
                'Restore Encrypted Vault',
                style: AppTypography.brandTitle(fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Paste your encrypted backup vault and enter the password. If valid, your database will be safely reconstructed with the backup data.',
                  style: AppTypography.body(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _vaultController,
                  maxLines: 4,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                  decoration: InputDecoration(
                    hintText: 'Paste {"safe_bloom_backup_version": 1, ...}',
                    filled: true,
                    fillColor: AppColors.lightBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      borderSide: const BorderSide(color: AppColors.lightCardBorder),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data != null && data.text != null) {
                        _vaultController.text = data.text!;
                      }
                    },
                    icon: const Icon(Icons.paste, size: 14, color: AppColors.dropCoral),
                    label: Text('PASTE VAULT', style: AppTypography.brandTagline(color: AppColors.dropCoral, fontSize: 10)),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: _vaultPasswordController,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Vault Password',
                    filled: true,
                    fillColor: AppColors.lightBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      borderSide: const BorderSide(color: AppColors.lightCardBorder),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, size: 18),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('CANCEL', style: AppTypography.brandTagline(color: AppColors.textMuted, fontSize: 11)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.dropCoral),
              onPressed: () {
                final vault = _vaultController.text.trim();
                final pass = _vaultPasswordController.text.trim();
                if (vault.isEmpty || pass.isEmpty) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                    const SnackBar(
                      content: Text('Please provide both the vault text and the password.'),
                      backgroundColor: AppColors.petalRose,
                    ),
                  );
                  return;
                }
                Navigator.of(dialogCtx).pop({'vault': vault, 'pass': pass});
              },
              child: Text('RESTORE VAULT', style: AppTypography.brandTagline(color: Colors.white, fontSize: 11)),
            ),
          ],
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final stats = await _repository.recoverAndRestoreFromEncryptedVault(
        vaultJsonString: result['vault']!,
        passphrase: result['pass']!,
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text('Database successfully restored! (${stats['periods']} periods, ${stats['symptoms']} symptoms).'),
          backgroundColor: AppColors.dropCoral,
        ),
      );

      widget.onRecovered();
    } catch (e) {
      setState(() => _isProcessing = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Recovery failed: $e. Your local database remains untouched.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _handleRestoreUnencryptedJson() async {
    _jsonController.clear();

    final jsonStr = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.lightCardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        title: Text(
          'Restore Unencrypted Backup',
          style: AppTypography.brandTitle(fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Paste your raw unencrypted JSON backup payload below:',
                style: AppTypography.body(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _jsonController,
                maxLines: 6,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                decoration: InputDecoration(
                  hintText: '{"profile": {...}, "period_entries": [...]}',
                  filled: true,
                  fillColor: AppColors.lightBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    borderSide: const BorderSide(color: AppColors.lightCardBorder),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data != null && data.text != null) {
                      _jsonController.text = data.text!;
                    }
                  },
                  icon: const Icon(Icons.paste, size: 14, color: AppColors.dropCoral),
                  label: Text('PASTE FROM CLIPBOARD', style: AppTypography.brandTagline(color: AppColors.dropCoral, fontSize: 10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text('CANCEL', style: AppTypography.brandTagline(color: AppColors.textMuted, fontSize: 11)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.deepPlum),
            onPressed: () {
              final text = _jsonController.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  const SnackBar(
                    content: Text('Please paste a valid JSON backup.'),
                    backgroundColor: AppColors.petalRose,
                  ),
                );
                return;
              }
              Navigator.of(dialogCtx).pop(text);
            },
            child: Text('RESTORE JSON', style: AppTypography.brandTagline(color: Colors.white, fontSize: 11)),
          ),
        ],
      ),
    );

    if (jsonStr == null || jsonStr.isEmpty || !mounted) return;

    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final stats = await _repository.recoverAndRestoreFromJson(jsonStr);

      messenger.showSnackBar(
        SnackBar(
          content: Text('Database successfully restored! (${stats['periods']} periods, ${stats['symptoms']} symptoms).'),
          backgroundColor: AppColors.dropCoral,
        ),
      );

      widget.onRecovered();
    } catch (e) {
      setState(() => _isProcessing = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('JSON import failed: $e. Your local database remains untouched.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _handleConfirmPurge() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.lightCardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Text(
              'Purge & Reset App?',
              style: AppTypography.brandTitle(fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'This action is irreversible. The corrupted local database, all encryption keys, and notification alarms will be permanently wiped. Safe Bloom will return to onboarding as a fresh install.',
          style: AppTypography.body(fontSize: 13, color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text('CANCEL', style: AppTypography.brandTagline(color: AppColors.textMuted, fontSize: 11)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text('PURGE EVERYTHING', style: AppTypography.brandTagline(color: Colors.white, fontSize: 11)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      final messenger = ScaffoldMessenger.of(context);
      try {
        await _repository.wipeAllUserData();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Local data wiped cleanly. Returning to onboarding...'),
            backgroundColor: AppColors.dropCoral,
          ),
        );
        widget.onPurged();
      } catch (e) {
        setState(() => _isProcessing = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to purge data: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Warning Shield Icon
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.petalRose.withValues(alpha: 0.4),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.petalRose.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    size: 44,
                    color: AppColors.dropCoral,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Title & Subtitle
                Text(
                  'Database Recovery',
                  style: AppTypography.brandTitle(fontSize: 26),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'ENCRYPTED VAULT COULD NOT BE OPENED',
                  style: AppTypography.brandTagline(
                    color: AppColors.petalRose,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),

                // Explanation Box
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.lightCardBackground,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.lightCardBorder),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Safe Bloom encountered an issue unlocking your local encrypted database (e.g. disk corruption or Android Keystore mismatch).',
                        style: AppTypography.body(fontSize: 12, color: AppColors.textMain),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Your original database file is preserved and has NOT been deleted.',
                        style: AppTypography.body(
                          fontSize: 11,
                          color: AppColors.sageGreen,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextButton(
                        onPressed: () => setState(() => _showErrorDetails = !_showErrorDetails),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _showErrorDetails ? 'Hide technical details' : 'Show technical details',
                          style: AppTypography.body(fontSize: 11, color: AppColors.dropCoral),
                        ),
                      ),
                      if (_showErrorDetails) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.lightBackground,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                          child: Text(
                            widget.errorMessage,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const Spacer(),

                if (_isProcessing)
                  const Center(
                    child: CircularProgressIndicator(color: AppColors.dropCoral),
                  )
                else ...[
                  // 1. Restore Encrypted Backup Vault Button (Primary)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.dropCoral,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                      onPressed: _handleRestoreEncryptedVault,
                      icon: const Icon(Icons.shield_outlined, size: 18),
                      label: Text(
                        'RESTORE ENCRYPTED VAULT',
                        style: AppTypography.brandTagline(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  // 2. Restore Unencrypted JSON Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepPlum,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                      onPressed: _handleRestoreUnencryptedJson,
                      icon: const Icon(Icons.upload_file_outlined, size: 16),
                      label: Text(
                        'RESTORE UNENCRYPTED JSON',
                        style: AppTypography.brandTagline(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  // 3. Retry Button
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textMain,
                        side: const BorderSide(color: AppColors.lightCardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                      onPressed: widget.onRecovered,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(
                        'RETRY UNLOCKING DATABASE',
                        style: AppTypography.brandTagline(color: AppColors.textMain, fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  // 4. Purge Everything Destructive Action
                  TextButton.icon(
                    onPressed: _handleConfirmPurge,
                    icon: const Icon(Icons.delete_forever_outlined, size: 14, color: Colors.redAccent),
                    label: Text(
                      'PURGE ALL LOCAL DATA & RESET',
                      style: AppTypography.brandTagline(color: Colors.redAccent, fontSize: 10),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
