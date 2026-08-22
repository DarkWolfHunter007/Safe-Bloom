import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/safe_bloom_date_utils.dart';
import '../../data/repositories/tracking_repository.dart';
import '../../domain/entities/period_entry.dart';

class EditPeriodView extends StatefulWidget {
  final PeriodEntry entry;
  final List<PeriodEntry>? fullCycle;

  const EditPeriodView({
    super.key,
    required this.entry,
    this.fullCycle,
  });

  @override
  State<EditPeriodView> createState() => _EditPeriodViewState();
}

class _EditPeriodViewState extends State<EditPeriodView> {
  final TrackingRepository _repository = TrackingRepository.instance;
  late DateTime _selectedDate;
  late FlowLevel _selectedFlow;
  late TextEditingController _notesController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.entry.timestamp;
    _selectedFlow = widget.entry.flow;
    _notesController = TextEditingController(text: widget.entry.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    final notes = _notesController.text.trim();

    try {
      final updatedEntry = PeriodEntry(
        id: widget.entry.id,
        timestamp: _selectedDate,
        flow: _selectedFlow,
        notes: notes.isEmpty ? null : notes,
      );

      await _repository.updatePeriodEntry(updatedEntry);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Period entry updated securely'),
            backgroundColor: AppColors.dropCoral,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update period entry: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.lightCardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        title: Text(
          'Delete Period Entry?',
          style: AppTypography.brandTitle(fontSize: 20),
        ),
        content: Text(
          'Are you sure you want to delete this period entry? Your cycle statistics and predictions will automatically adjust.',
          style: AppTypography.body(fontSize: 13, color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'CANCEL',
              style: AppTypography.brandTagline(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dropCoral,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'DELETE ENTRY',
              style: AppTypography.brandTagline(
                color: Colors.white,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (widget.fullCycle != null && widget.fullCycle!.isNotEmpty) {
          for (final entry in widget.fullCycle!) {
            await _repository.deletePeriodEntry(entry.id);
          }
        } else {
          await _repository.deletePeriodEntry(widget.entry.id);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Period entry deleted'),
              backgroundColor: AppColors.dropCoral,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete period entry: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Edit Period Entry',
          style: AppTypography.brandTitle(fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date picker selector card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.lightCardBackground,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.lightCardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ENTRY DATE',
                          style: AppTypography.brandTagline(fontSize: 10),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_selectedDate.day} ${SafeBloomDateUtils.monthAbbr(_selectedDate.month)} ${_selectedDate.year}',
                          style: AppTypography.brandTitle(fontSize: 20),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.dropCoral,
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 548)),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 14, color: Colors.white),
                      label: Text(
                        'CHANGE',
                        style: AppTypography.brandTagline(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Flow selector
              Text(
                'PERIOD FLOW',
                style: AppTypography.brandTagline(fontSize: 10),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: FlowLevel.values.map((flow) {
                  final isSelected = _selectedFlow == flow;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedFlow = flow),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.dropCoral : AppColors.lightCardBackground,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            border: Border.all(
                              color: isSelected ? AppColors.dropCoral : AppColors.lightCardBorder,
                              width: 1.2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              flow.name.toUpperCase(),
                              style: AppTypography.body(
                                fontSize: 10,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : AppColors.textMain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),

              // Notes field
              Text(
                'NOTES',
                style: AppTypography.brandTagline(fontSize: 10),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _notesController,
                maxLines: 3,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                style: AppTypography.body(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Add optional notes about flow or observations…',
                  hintStyle: AppTypography.body(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: AppColors.lightCardBackground,
                  contentPadding: const EdgeInsets.all(AppSpacing.md),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: const BorderSide(color: AppColors.petalRose, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Save button
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
                  onPressed: _isSaving ? null : _saveChanges,
                  child: Text(
                    'SAVE CHANGES',
                    style: AppTypography.brandTagline(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Delete button
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
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(
                    'DELETE PERIOD ENTRY',
                    style: AppTypography.brandTagline(
                      color: AppColors.dropCoral,
                      fontSize: 11,
                    ),
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
