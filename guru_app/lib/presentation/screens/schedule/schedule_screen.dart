import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/error/failures.dart';
import '../../../core/utils/extensions.dart';
import '../../providers/auth_provider.dart';
import '../../providers/call_request_provider.dart';
import '../../widgets/guru_app_bar.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  DateTime? _selectedDate;
  int? _selectedSlot;
  final _noteController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Select call date',
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
        _selectedSlot = null;
      });
    }
  }

  List<DateTime> _slotsFor(DateTime date) {
    final slots = <DateTime>[];
    for (var h = 6; h < 22; h++) {
      slots.add(DateTime(date.year, date.month, date.day, h, 0));
      slots.add(DateTime(date.year, date.month, date.day, h, 30));
    }
    final now = DateTime.now();
    return slots.where((s) => s.isAfter(now)).toList();
  }

  Future<void> _submit() async {
    if (_selectedDate == null || _selectedSlot == null) {
      _showError('Please select a date and time.');
      return;
    }

    final note = _noteController.text.trim();
    if (note.length > 140) {
      _showError('Note cannot exceed 140 characters.');
      return;
    }

    final slots = _slotsFor(_selectedDate!);
    final scheduledFor = slots[_selectedSlot!];

    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    setState(() => _loading = true);

    final failure = await ref
        .read(callRequestsProvider(user.id).notifier)
        .requestCall(scheduledFor, note);

    setState(() => _loading = false);

    if (!mounted) return;

    if (failure != null) {
      _showError(_failureMessage(failure));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(AppStrings.requestSent),
        action: SnackBarAction(
          label: AppStrings.myRequests,
          onPressed: () => context.push('/requests'),
        ),
      ),
    );
    context.pop();
  }

  String _failureMessage(Failure f) {
    return switch (f) {
      ValidationFailure() => f.message,
      ConflictFailure() => AppStrings.slotAlreadyTaken,
      _ => AppStrings.errorGeneric,
    };
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Expanded(child: Text(message)),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
              child: const Text(
                AppStrings.copyError,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: guruAppBar(
        context: context,
        title: 'Schedule a Call',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('Select a date'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedDate != null ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedDate != null ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      color: _selectedDate != null ? Colors.white : AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _selectedDate != null
                          ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                          : 'Tap to choose a date',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _selectedDate != null ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_drop_down,
                      color: _selectedDate != null ? Colors.white70 : AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
            if (_selectedDate != null) ...[
              const SizedBox(height: 20),
              const _SectionLabel('Select a time slot'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _slotsFor(_selectedDate!).asMap().entries.map((e) {
                  final i = e.key;
                  final slot = e.value;
                  final selected = _selectedSlot == i;
                  return ChoiceChip(
                    label: Text(slot.timeOnly),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedSlot = i),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    backgroundColor: AppColors.surface,
                    side: BorderSide(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 20),
            const _SectionLabel(AppStrings.note),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 3,
              maxLength: 140,
              decoration: InputDecoration(
                hintText: AppStrings.noteHint,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        AppStrings.requestCall,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}
