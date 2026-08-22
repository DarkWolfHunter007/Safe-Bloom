import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/repositories/tracking_repository.dart';
import '../../domain/entities/symptom_entry.dart';

class EditSymptomSheet extends StatefulWidget {
  final SymptomEntry entry;
  final VoidCallback onSaved;

  const EditSymptomSheet({
    super.key,
    required this.entry,
    required this.onSaved,
  });

  @override
  State<EditSymptomSheet> createState() => _EditSymptomSheetState();
}

class _EditSymptomSheetState extends State<EditSymptomSheet> {
  final TrackingRepository _repository = TrackingRepository.instance;
  late int _intensity;
  late TextEditingController _notesController;

  final List<String> _intensityLabels = const [
    'Very Mild',
    'Mild',
    'Moderate',
    'Severe',
    'Very Severe',
  ];

  @override
  void initState() {
    super.initState();
    _intensity = widget.entry.intensity.clamp(1, 5);
    _notesController = TextEditingController(text: widget.entry.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final notes = _notesController.text.trim();
    try {
      final updated = SymptomEntry(
        id: widget.entry.id,
        timestamp: widget.entry.timestamp,
        category: widget.entry.category,
        type: widget.entry.type,
        intensity: _intensity,
        notes: notes.isEmpty ? null : notes,
      );

      await _repository.updateSymptomEntry(updated);
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update symptom: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _deleteSymptom() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.lightCardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        title: Text('Delete Symptom?', style: AppTypography.brandTitle(fontSize: 20)),
        content: Text(
          'Are you sure you want to delete "${widget.entry.type}"?',
          style: AppTypography.body(fontSize: 13, color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('CANCEL', style: AppTypography.brandTagline(color: AppColors.textMuted, fontSize: 11)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.dropCoral),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('DELETE', style: AppTypography.brandTagline(color: Colors.white, fontSize: 11)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _repository.deleteSymptomEntry(widget.entry.id);
        widget.onSaved();
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete symptom: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.lightCardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.entry.type,
                    style: AppTypography.brandTitle(fontSize: 22),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.dropCoral),
                    onPressed: _deleteSymptom,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'INTENSITY: ${_intensityLabels[_intensity - 1].toUpperCase()}',
                style: AppTypography.brandTagline(fontSize: 10),
              ),
              Slider(
                key: const ValueKey('edit_symptom_intensity_slider'),
                value: _intensity.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                activeColor: AppColors.dropCoral,
                inactiveColor: AppColors.lightCardBorder,
                onChanged: (val) => setState(() => _intensity = val.round()),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'NOTES',
                style: AppTypography.brandTagline(fontSize: 10),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _notesController,
                maxLines: 2,
                maxLength: 200,
                style: AppTypography.body(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Add notes for this symptom…',
                  filled: true,
                  fillColor: AppColors.lightBackground,
                  contentPadding: const EdgeInsets.all(AppSpacing.md),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dropCoral,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  onPressed: _saveChanges,
                  child: Text(
                    'UPDATE SYMPTOM',
                    style: AppTypography.brandTagline(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
