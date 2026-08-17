import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../widgets/trainer_app_bar.dart';

class PreJoinScreen extends ConsumerStatefulWidget {
  final String callRequestId;

  const PreJoinScreen({super.key, required this.callRequestId});

  @override
  ConsumerState<PreJoinScreen> createState() => _PreJoinScreenState();
}

class _PreJoinScreenState extends ConsumerState<PreJoinScreen> {
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

    context.push('/call/${widget.callRequestId}/live');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: trainerAppBar(
        context: context,
        title: 'Ready to join?',
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.videocam_outlined,
              size: 80,
              color: AppColors.primary,
            ),
            const SizedBox(height: 24),
            const Text(
              AppStrings.joinPrompt,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Camera and microphone will be available inside the call.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
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
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        AppStrings.joinCall,
                        style:
                            TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
