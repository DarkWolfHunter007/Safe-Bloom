import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _anonymousMode = true;
  bool _biometricLock = false;
  bool _cloudBackup = true;

  void _confirmDataWipe() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.lightCardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        title: Text('Wipe All Local Data?', style: AppTypography.brandTitle(fontSize: 20)),
        content: Text(
          'This action is irreversible. All period logs, symptoms, and key pairs will be purged from SQLCipher storage.',
          style: AppTypography.body(fontSize: 13, color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('CANCEL', style: AppTypography.brandTagline(color: AppColors.textMuted, fontSize: 11)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.dropCoral),
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Local SQLCipher database wiped cleanly.'),
                  backgroundColor: AppColors.dropCoral,
                ),
              );
            },
            child: Text('PURGE EVERYTHING', style: AppTypography.brandTagline(color: Colors.white, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Privacy & Security', style: AppTypography.brandTitle(fontSize: 28)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'ANONYMOUS & ENCRYPTED BY DESIGN',
            style: AppTypography.brandTagline(color: AppColors.petalRose, fontSize: 9),
          ),
          const SizedBox(height: AppSpacing.md),

          // Encryption Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.lightCardBackground,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.petalRose.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock, color: AppColors.petalRose, size: 20),
                    const SizedBox(width: 8),
                    Text('256-Bit AES Hardware Encryption', style: AppTypography.brandTitle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Your health entries are encrypted using SQLCipher. Master keys reside in iOS Keychain & Android Keystore.',
                  style: AppTypography.body(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Settings Controls Container
          Container(
            decoration: BoxDecoration(
              color: AppColors.lightCardBackground,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.lightCardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              children: [
                SwitchListTile(
                  activeColor: AppColors.dropCoral,
                  title: Text('Anonymous Mode', style: AppTypography.body(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('De-links personal email and names from cycle metrics', style: AppTypography.body(fontSize: 11, color: AppColors.textMuted)),
                  value: _anonymousMode,
                  onChanged: (val) => setState(() => _anonymousMode = val),
                ),
                const Divider(color: AppColors.lightCardBorder, height: 1),
                SwitchListTile(
                  activeColor: AppColors.dropCoral,
                  title: Text('Biometric / PIN Lock', style: AppTypography.body(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('Require Face ID / Fingerprint upon app launch', style: AppTypography.body(fontSize: 11, color: AppColors.textMuted)),
                  value: _biometricLock,
                  onChanged: (val) => setState(() => _biometricLock = val),
                ),
                const Divider(color: AppColors.lightCardBorder, height: 1),
                SwitchListTile(
                  activeColor: AppColors.dropCoral,
                  title: Text('Zero-Knowledge Backup', style: AppTypography.body(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('Encrypted cloud backups only accessible by your device key', style: AppTypography.body(fontSize: 11, color: AppColors.textMuted)),
                  value: _cloudBackup,
                  onChanged: (val) => setState(() => _cloudBackup = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Danger Zone
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.dropCoral,
                side: const BorderSide(color: AppColors.dropCoral),
                padding: const EdgeInsets.all(AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
              onPressed: _confirmDataWipe,
              icon: const Icon(Icons.delete_forever, size: 18),
              label: Text(
                'PURGE ALL MY DATA NOW',
                style: AppTypography.brandTagline(color: AppColors.dropCoral, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
