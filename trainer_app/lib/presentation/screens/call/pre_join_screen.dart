import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/call_provider.dart';

class PreJoinScreen extends ConsumerStatefulWidget {
  final String callRequestId;

  const PreJoinScreen({super.key, required this.callRequestId});

  @override
  ConsumerState<PreJoinScreen> createState() => _PreJoinScreenState();
}

class _PreJoinScreenState extends ConsumerState<PreJoinScreen> {
  bool _micEnabled = true;
  bool _camEnabled = true;
  bool _loading = false;

  Future<void> _join() async {
    setState(() => _loading = true);

    final camStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    if (!mounted) return;

    if (camStatus.isDenied || micStatus.isDenied) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera and microphone permissions are required.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    await ref.read(callProvider.notifier).joinRoom(
          'room_${widget.callRequestId}',
          widget.callRequestId,
        );

    if (!mounted) return;
    context.go('/call/${widget.callRequestId}/live');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          AppStrings.joinPrompt,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_rounded, size: 80, color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      'Check mic and camera before joining.',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            _ToggleRow(
              label: 'Microphone',
              icon: Icons.mic_outlined,
              enabled: _micEnabled,
              onToggle: (v) => setState(() => _micEnabled = v),
            ),
            const SizedBox(height: 12),
            _ToggleRow(
              label: 'Camera',
              icon: Icons.videocam_outlined,
              enabled: _camEnabled,
              onToggle: (v) => setState(() => _camEnabled = v),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _loading ? null : _join,
                icon: const Icon(Icons.videocam),
                label: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        AppStrings.joinCall,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final ValueChanged<bool> onToggle;

  const _ToggleRow({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, color: enabled ? AppColors.primary : AppColors.textTertiary),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Switch.adaptive(
            value: enabled,
            onChanged: onToggle,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primaryLight,
          ),
        ],
      ),
    );
  }
}
