import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/call_provider.dart';
import '../../providers/repository_providers.dart';

class LiveCallScreen extends ConsumerWidget {
  final String callRequestId;

  const LiveCallScreen({super.key, required this.callRequestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callAsync = ref.watch(callProvider);

    return callAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
      data: (data) {
        if (data.state == CallState.ended) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showPostCallSheet(context, ref, callRequestId);
          });
        }

        if (data.state == CallState.connecting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D0D0D),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Connecting...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        if (data.state == CallState.error) {
          return Scaffold(
            backgroundColor: const Color(0xFF0D0D0D),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    data.errorMessage ?? AppStrings.errorGeneric,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Go back', style: TextStyle(color: AppColors.primary)),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0D0D0D),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: _PeerGrid(peers: data.peers),
                ),
                _CallControls(
                  isMuted: data.isMuted,
                  isVideoOff: data.isVideoOff,
                  callRequestId: callRequestId,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPostCallSheet(BuildContext context, WidgetRef ref, String callRequestId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RatingSheet(
        onSubmit: (rating, note) {
          Navigator.of(context).pop();
          _applyRating(ref, rating, note);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.sessionSaved)),
          );
          context.go('/sessions');
        },
      ),
    );
  }

  Future<void> _applyRating(WidgetRef ref, int rating, String? note) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    final logs = await ref.read(sessionLogRepositoryProvider).getLogs(user.id);
    if (logs.isEmpty) return;
    final latest = logs.first;
    final updated = latest.copyWith(rating: rating, memberNotes: note);
    await ref.read(sessionLogRepositoryProvider).updateLog(updated);
  }
}

class _PeerGrid extends StatelessWidget {
  final List peers;

  const _PeerGrid({required this.peers});

  @override
  Widget build(BuildContext context) {
    if (peers.isEmpty) {
      return const Center(
        child: Text(
          'Waiting for trainer to join...',
          style: TextStyle(color: Colors.white60, fontSize: 16),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: peers.length,
      itemBuilder: (_, i) {
        final peer = peers[i];
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primary.withAlpha(40),
                  child: Text(
                    (peer.name as String? ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  peer.name as String? ?? 'Unknown',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CallControls extends ConsumerWidget {
  final bool isMuted;
  final bool isVideoOff;
  final String callRequestId;

  const _CallControls({
    required this.isMuted,
    required this.isVideoOff,
    required this.callRequestId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlBtn(
            icon: isMuted ? Icons.mic_off : Icons.mic,
            label: isMuted ? 'Unmute' : 'Mute',
            onTap: () => ref.read(callProvider.notifier).toggleMute(),
          ),
          _ControlBtn(
            icon: isVideoOff ? Icons.videocam_off : Icons.videocam,
            label: isVideoOff ? 'Video On' : 'Video Off',
            onTap: () => ref.read(callProvider.notifier).toggleVideo(),
          ),
          _ControlBtn(
            icon: Icons.flip_camera_ios,
            label: 'Flip',
            onTap: () => ref.read(callProvider.notifier).switchCamera(),
          ),
          _ControlBtn(
            icon: Icons.call_end,
            label: 'End',
            color: AppColors.error,
            onTap: () => ref.read(callProvider.notifier).endCall(callRequestId),
          ),
        ],
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ControlBtn({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final btnColor = color ?? Colors.white24;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: btnColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RatingSheet extends StatefulWidget {
  final void Function(int rating, String? note) onSubmit;

  const _RatingSheet({required this.onSubmit});

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  int _rating = 0;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            AppStrings.rateSession,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return IconButton(
                onPressed: () => setState(() => _rating = i + 1),
                icon: Icon(
                  _rating > i ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: AppColors.warning,
                  size: 40,
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: AppStrings.addNote,
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _rating == 0
                  ? null
                  : () => widget.onSubmit(
                        _rating,
                        _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
                      ),
              child: const Text(
                AppStrings.submit,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
