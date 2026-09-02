import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/call_provider.dart';
import '../../providers/repository_providers.dart';

const int _zegoAppId = 726596021;
const String _zegoAppSign =
    '1420338a20a5074e8f8e5c3eec76022ced98f3a0ddf3184fdc4d36ae389c5444';

class LiveCallScreen extends ConsumerStatefulWidget {
  final String callRequestId;
  const LiveCallScreen({super.key, required this.callRequestId});

  @override
  ConsumerState<LiveCallScreen> createState() => _LiveCallScreenState();
}

class _LiveCallScreenState extends ConsumerState<LiveCallScreen> {
  bool _callEnded = false;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isFront = true;
  bool _remoteJoined = false;

  Widget? _localView;
  Widget? _remoteView;
  int? _localViewId;
  int? _remoteViewId;
  String? _remoteStreamId;

  String? _myStreamId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCall());
  }

  // roomId: first 18 alphanum chars of callRequestId — same on both sides
  String get _roomId {
    final clean = widget.callRequestId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return clean.substring(0, clean.length.clamp(0, 18));
  }

  Future<void> _startCall() async {
    if (!mounted) return;
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    ref.read(callProvider.notifier).onCallStarted(widget.callRequestId);

    // userId: strip special chars, max 20 chars
    final userId = user.id
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .substring(0, user.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').length.clamp(0, 20));

    // Stream this user publishes — must be unique per user in the room
    _myStreamId = '${_roomId}_$userId';

    debugPrint('[ZEGO] roomId=$_roomId  userId=$userId  myStream=$_myStreamId');

    await ZegoExpressEngine.createEngineWithProfile(ZegoEngineProfile(
      _zegoAppId,
      ZegoScenario.StandardVideoCall,
      appSign: _zegoAppSign,
    ));

    // Register ALL callbacks BEFORE loginRoom — events fire immediately on join
    ZegoExpressEngine.onRoomStateUpdate =
        (roomID, state, errorCode, extendedData) {
      debugPrint('[ZEGO] roomState=$state errorCode=$errorCode');
    };

    ZegoExpressEngine.onRoomUserUpdate = (roomID, updateType, userList) {
      if (!mounted) return;
      debugPrint('[ZEGO] userUpdate type=$updateType users=${userList.map((u) => u.userID)}');
      if (updateType == ZegoUpdateType.Add) {
        setState(() => _remoteJoined = true);
      } else {
        setState(() {
          _remoteJoined = false;
          _remoteView = null;
          _remoteViewId = null;
        });
      }
    };

    ZegoExpressEngine.onRoomStreamUpdate =
        (roomID, updateType, streamList, extendedData) async {
      debugPrint('[ZEGO] streamUpdate type=$updateType streams=${streamList.map((s) => s.streamID)}');
      if (updateType == ZegoUpdateType.Add) {
        for (final stream in streamList) {
          // Don't play our own stream
          if (stream.streamID == _myStreamId) continue;
          _remoteStreamId = stream.streamID;
          if (mounted) await _setupRemoteView(_remoteStreamId!);
        }
      } else if (updateType == ZegoUpdateType.Delete) {
        if (mounted) {
          setState(() {
            _remoteView = null;
            _remoteViewId = null;
            _remoteStreamId = null;
          });
        }
      }
    };

    ZegoExpressEngine.onPublisherStateUpdate =
        (streamID, state, errorCode, extendedData) {
      debugPrint('[ZEGO] publishState=$state streamID=$streamID errorCode=$errorCode');
    };

    ZegoExpressEngine.onPlayerStateUpdate =
        (streamID, state, errorCode, extendedData) {
      debugPrint('[ZEGO] playState=$state streamID=$streamID errorCode=$errorCode');
    };

    final config = ZegoRoomConfig.defaultConfig();
    config.isUserStatusNotify = true;

    final loginResult = await ZegoExpressEngine.instance.loginRoom(
      _roomId,
      ZegoUser(userId, user.name),
      config: config,
    );
    debugPrint('[ZEGO] loginRoom errorCode=${loginResult.errorCode}');

    if (loginResult.errorCode != 0) return;

    // Start local preview then publish
    final localWidget = await ZegoExpressEngine.instance.createCanvasView(
      (viewID) async {
        _localViewId = viewID;
        await ZegoExpressEngine.instance.startPreview(
          canvas: ZegoCanvas(_localViewId!),
        );
        debugPrint('[ZEGO] preview started, publishing $_myStreamId');
        await ZegoExpressEngine.instance.startPublishingStream(_myStreamId!);
      },
    );
    if (mounted) setState(() => _localView = localWidget);
  }

  Future<void> _setupRemoteView(String streamId) async {
    final remoteWidget = await ZegoExpressEngine.instance.createCanvasView(
      (viewID) async {
        _remoteViewId = viewID;
        await ZegoExpressEngine.instance.startPlayingStream(
          streamId,
          canvas: ZegoCanvas(_remoteViewId!),
        );
      },
    );
    if (mounted) setState(() => _remoteView = remoteWidget);
  }

  Future<void> _endCall() async {
    if (_callEnded) return;
    _callEnded = true;

    if (_localViewId != null) {
      await ZegoExpressEngine.instance.stopPreview();
      await ZegoExpressEngine.instance.destroyCanvasView(_localViewId!);
    }
    if (_remoteViewId != null && _remoteStreamId != null) {
      await ZegoExpressEngine.instance.stopPlayingStream(_remoteStreamId!);
      await ZegoExpressEngine.instance.destroyCanvasView(_remoteViewId!);
    }
    await ZegoExpressEngine.instance.stopPublishingStream();
    await ZegoExpressEngine.instance.logoutRoom();
    await ZegoExpressEngine.destroyEngine();

    await ref.read(callProvider.notifier).endCall(widget.callRequestId);
    if (!mounted) return;
    _showTrainerNotesSheet();
  }

  Future<void> _toggleMute() async {
    final next = !_isMuted;
    await ZegoExpressEngine.instance.muteMicrophone(next);
    setState(() => _isMuted = next);
  }

  Future<void> _toggleCamera() async {
    final next = !_isCameraOff;
    await ZegoExpressEngine.instance.enableCamera(!next);
    setState(() => _isCameraOff = next);
  }

  Future<void> _flipCamera() async {
    final next = !_isFront;
    await ZegoExpressEngine.instance.useFrontCamera(next);
    setState(() => _isFront = next);
  }

  void _showTrainerNotesSheet() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Session Complete',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text(AppStrings.sessionSaved,
                style:
                    TextStyle(fontSize: 14, color: AppColors.textSecondary)),
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
                    borderSide: BorderSide.none),
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
                      final logs = await ref
                          .read(sessionLogRepositoryProvider)
                          .getLogs('member_dk');
                      if (logs.isNotEmpty) {
                        final updated =
                            logs.first.copyWith(trainerNotes: notes);
                        await ref
                            .read(sessionLogRepositoryProvider)
                            .updateLog(updated);
                      }
                    }
                  }
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  ctx.go('/sessions');
                },
                child: const Text(AppStrings.markComplete,
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (!_callEnded) {
      ZegoExpressEngine.instance.stopPreview();
      ZegoExpressEngine.instance.stopPublishingStream();
      ZegoExpressEngine.instance.logoutRoom();
      ZegoExpressEngine.destroyEngine();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(children: [
                _remoteView != null
                    ? _remoteView!
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                                color: AppColors.primary),
                            const SizedBox(height: 16),
                            Text(
                              _remoteJoined
                                  ? 'Connecting video...'
                                  : 'Waiting for member to join...',
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                if (_localView != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    width: 90,
                    height: 140,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _isCameraOff
                          ? Container(
                              color: const Color(0xFF1A1A1A),
                              child: const Icon(Icons.videocam_off,
                                  color: Colors.white54))
                          : _localView!,
                    ),
                  ),
              ]),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlBtn(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      label: _isMuted ? 'Unmute' : 'Mute',
                      onTap: _toggleMute),
                  _ControlBtn(
                      icon: _isCameraOff
                          ? Icons.videocam_off
                          : Icons.videocam,
                      label: _isCameraOff ? 'Video On' : 'Video Off',
                      onTap: _toggleCamera),
                  _ControlBtn(
                      icon: Icons.flip_camera_ios,
                      label: 'Flip',
                      onTap: _flipCamera),
                  _ControlBtn(
                      icon: Icons.call_end,
                      label: 'End',
                      color: AppColors.error,
                      onTap: _endCall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _ControlBtn(
      {required this.icon,
      required this.label,
      this.color,
      required this.onTap});

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
                color: color ?? Colors.white24, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style:
                  const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }
}
