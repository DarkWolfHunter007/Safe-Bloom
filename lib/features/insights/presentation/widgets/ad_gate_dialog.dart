import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class AdGateDialog extends StatefulWidget {
  final VoidCallback onUnlocked;

  const AdGateDialog({super.key, required this.onUnlocked});

  @override
  State<AdGateDialog> createState() => _AdGateDialogState();
}

class _AdGateDialogState extends State<AdGateDialog> {
  int _secondsRemaining = 5;
  bool _canClose = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_secondsRemaining > 1) {
          _secondsRemaining--;
        } else {
          _secondsRemaining = 0;
          _canClose = true;
        }
      });
      return _secondsRemaining > 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.lightCardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: const BorderSide(color: AppColors.lightCardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SPONSORED BY SEED',
                    style: AppTypography.brandTagline(color: AppColors.dropCoral, fontSize: 9),
                  ),
                  GestureDetector(
                    onTap: _canClose
                        ? () {
                            widget.onUnlocked();
                            Navigator.of(context).pop();
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.xs + 2),
                      decoration: BoxDecoration(
                        color: _canClose ? AppColors.dropCoral : AppColors.petalRose.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _canClose ? '✕' : '${_secondsRemaining}s',
                        style: AppTypography.body(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.petalRose.withOpacity(0.15), AppColors.lightCardBackground],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.petalRose.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Daily Synbiotic',
                      style: AppTypography.brandTitle(fontSize: 24),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Systemic health & hormonal balance support.',
                      style: AppTypography.body(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'LEARN MORE AT SEED.COM ↗',
                style: AppTypography.brandTagline(color: AppColors.dropCoral, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
