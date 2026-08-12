import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hmssdk_flutter/hmssdk_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/call_provider.dart';
import '../../providers/repository_providers.dart';
import '../../providers/auth_provider.dart';

class LiveCallScreen extends ConsumerWidget {
  final String callRequestId;

  const LiveCallScreen({super.key, required this.callRequestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callAsync = ref.watch(callProvider);

    return callAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (data) {
        if (data.state == CallState.ended) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showTrainerNotesSheet(context, ref, callRequestId);
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
                  Text('Connecting...', style: TextStyle(color: Colors.white, fontSize: 16)),
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
                  child: Stack(
                    children: [
                      _PeerGrid(tiles: data.tiles),
                      if (data.state == CallState.reconnecting)
                        const Positioned(
                          top: 16,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Chip(
                              avatar: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              label: Text('Reconnecting...'),
                            ),
                          ),
                        ),
                    ],
                  ),
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

  void _showTrainerNotesSheet(BuildContext context, WidgetRef ref, String callRequestId) {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Session Complete',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              AppStrings.sessionSaved,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: AppStrings.addNotes,
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () async {
                  final notes = controller.text.trim();
                  if (notes.isNotEmpty) {
                    final user = ref.read(currentUserProvider).valueOrNull;
                    if (user != null) {
                      final logs =
                          await ref.read(sessionLogRepositoryProvider).getLogs('member_dk');
                      if (logs.isNotEmpty) {
                        final updated = logs.first.copyWith(trainerNotes: notes);
                        await ref.read(sessionLogRepositoryProvider).updateLog(updated);
                      }
                    }
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) context.go('/sessions');
                },
                child: const Text(
                  AppStrings.markComplete,
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

class _PeerGrid extends StatelessWidget {
  final List<PeerTile> tiles;

  const _PeerGrid({required this.tiles});

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) {
      return const Center(
        child: Text(
          'Waiting for member to join...',
          style: TextStyle(color: Colors.white60, fontSize: 16),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: tiles.length == 1 ? 1 : 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: tiles.length == 1 ? 0.75 : 0.85,
      ),
      itemCount: tiles.length,
      itemBuilder: (_, i) {
        final tile = tiles[i];
        final track = tile.videoTrack;
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: const Color(0xFF1A1A1A),
                child: track != null && !track.isMute
                    ? HMSVideoView(
                        track: track,
                        setMirror: tile.peer.isLocal,
                        key: Key(track.trackId),
                      )
                    : Center(
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.primary.withAlpha(40),
                          child: Text(
                            tile.peer.name.isNotEmpty
                                ? tile.peer.name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
              ),
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tile.peer.isLocal ? '${tile.peer.name} (You)' : tile.peer.name,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
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
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color ?? Colors.white24,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }
}
