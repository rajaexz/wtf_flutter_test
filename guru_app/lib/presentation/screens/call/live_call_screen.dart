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
  bool _remoteSetupInProgress = false; // guard against concurrent _setupRemoteView calls

  Widget? _localView;
  Widget? _remoteView;
  int? _localViewId;
  int? _remoteViewId;
  String? _remoteStreamId;

  String? _myStreamId;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCall());
  }

  // roomId = full stripped callRequestId, max 64 chars (Zego limit)
  String get _roomId {
    final clean = widget.callRequestId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return clean.substring(0, clean.length.clamp(1, 64));
  }

  bool _isOwnStream(String streamId) {
    if (_myStreamId != null && streamId == _myStreamId) return true;
    if (_myUserId != null && streamId.endsWith('_$_myUserId')) return true;
    return false;
  }

  Future<void> _startCall() async {
    if (!mounted) return;
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    ref.read(callProvider.notifier).onCallStarted(widget.callRequestId);

    // userId: strip special chars, max 64 chars (Zego limit)
    final rawId = user.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final userId = rawId.substring(0, rawId.length.clamp(1, 64));

    _myStreamId = '${_roomId}_$userId';
    _myUserId = userId;

    debugPrint('[ZEGO] roomId=$_roomId  userId=$userId  myStream=$_myStreamId');

    await ZegoExpressEngine.createEngineWithProfile(ZegoEngineProfile(
      _zegoAppId,
      ZegoScenario.StandardVideoCall,
      appSign: _zegoAppSign,
    ));

    // ── Register callbacks BEFORE loginRoom ────────────────────────────────
    ZegoExpressEngine.onRoomStateUpdate = (roomID, state, errorCode, extendedData) {
      debugPrint('[ZEGO] roomState=$state error=$errorCode');
    };

    ZegoExpressEngine.onRoomUserUpdate = (roomID, updateType, userList) {
      if (!mounted) return;
      final remoteUsers = userList.where((u) => u.userID != _myUserId).toList();
      debugPrint('[ZEGO] userUpdate=$updateType users=${remoteUsers.map((u) => u.userID)}');
      if (updateType == ZegoUpdateType.Add && remoteUsers.isNotEmpty) {
        if (mounted) setState(() => _remoteJoined = true);
      } else if (updateType == ZegoUpdateType.Delete && remoteUsers.isNotEmpty) {
        if (mounted) {
          setState(() {
            _remoteJoined = false;
            _remoteView = null;
            _remoteViewId = null;
            _remoteSetupInProgress = false;
          });
        }
      }
    };

    ZegoExpressEngine.onRoomStreamUpdate = (roomID, updateType, streamList, extendedData) async {
      debugPrint('[ZEGO] streamUpdate=$updateType streams=${streamList.map((s) => s.streamID)}');
      if (updateType == ZegoUpdateType.Add) {
        for (final stream in streamList) {
          if (_isOwnStream(stream.streamID)) continue;
          // Already have remote view or setup is already running — skip
          if (_remoteViewId != null || _remoteSetupInProgress) continue;
          _remoteStreamId = stream.streamID;
          _remoteSetupInProgress = true;
          if (mounted) await _setupRemoteView(_remoteStreamId!);
        }
      } else if (updateType == ZegoUpdateType.Delete) {
        if (mounted) {
          setState(() {
            _remoteView = null;
            _remoteViewId = null;
            _remoteStreamId = null;
            _remoteSetupInProgress = false;
          });
        }
      }
    };

    ZegoExpressEngine.onPublisherStateUpdate = (streamID, state, errorCode, extendedData) {
      debugPrint('[ZEGO] publish state=$state stream=$streamID error=$errorCode');
    };

    ZegoExpressEngine.onPlayerStateUpdate = (streamID, state, errorCode, extendedData) {
      debugPrint('[ZEGO] player state=$state stream=$streamID error=$errorCode');
    };

    // ── Login ──────────────────────────────────────────────────────────────
    final config = ZegoRoomConfig.defaultConfig();
    config.isUserStatusNotify = true;

    final loginResult = await ZegoExpressEngine.instance.loginRoom(
      _roomId,
      ZegoUser(userId, user.name),
      config: config,
    );
    debugPrint('[ZEGO] loginRoom result=${loginResult.errorCode}');

    if (loginResult.errorCode != 0) {
      debugPrint('[ZEGO] ❌ loginRoom failed — cannot start call');
      return;
    }

    // ── Local preview ──────────────────────────────────────────────────────
    // Step 1: create native canvas, capture its viewID
    final localWidget = await ZegoExpressEngine.instance.createCanvasView((viewID) {
      _localViewId = viewID;
    });

    // Step 2: insert widget into tree
    if (!mounted) return;
    setState(() => _localView = localWidget);

    // Step 3: wait for PlatformView to attach to native render tree
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // Step 4: start preview + publish
    debugPrint('[ZEGO] startPreview viewId=$_localViewId');
    await ZegoExpressEngine.instance.startPreview(canvas: ZegoCanvas(_localViewId!));

    debugPrint('[ZEGO] startPublishing stream=$_myStreamId');
    await ZegoExpressEngine.instance.startPublishingStream(_myStreamId!);
  }

  Future<void> _setupRemoteView(String streamId) async {
    debugPrint('[ZEGO] _setupRemoteView stream=$streamId');

    // Step 1: create native canvas
    final remoteWidget = await ZegoExpressEngine.instance.createCanvasView((viewID) {
      _remoteViewId = viewID;
    });

    // Step 2: insert widget into tree
    if (!mounted) {
      _remoteSetupInProgress = false;
      return;
    }
    setState(() => _remoteView = remoteWidget);

    // Step 3: wait for PlatformView to attach
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) {
      _remoteSetupInProgress = false;
      return;
    }

    // Step 4: start playing
    debugPrint('[ZEGO] startPlayingStream stream=$streamId viewId=$_remoteViewId');
    await ZegoExpressEngine.instance.startPlayingStream(
      streamId,
      canvas: ZegoCanvas(_remoteViewId!),
    );
    _remoteSetupInProgress = false;
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
    _showPostCallSheet();
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

  void _showPostCallSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _RatingSheet(
        onSubmit: (rating, note) {
          Navigator.of(context).pop();
          _applyRating(rating, note);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text(AppStrings.sessionSaved)));
          context.go('/sessions');
        },
      ),
    );
  }

  Future<void> _applyRating(int rating, String? note) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    final logs = await ref.read(sessionLogRepositoryProvider).getLogs(user.id);
    if (logs.isEmpty) return;
    final updated = logs.first.copyWith(rating: rating, memberNotes: note);
    await ref.read(sessionLogRepositoryProvider).updateLog(updated);
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
                // Remote view
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
                                  : 'Waiting for trainer to join...',
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                // Local preview (small, top-right)
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
                                  color: Colors.white54),
                            )
                          : _localView!,
                    ),
                  ),
              ]),
            ),
            // Controls
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
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
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
          24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(AppStrings.rateSession,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => IconButton(
                onPressed: () => setState(() => _rating = i + 1),
                icon: Icon(
                  _rating > i
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: AppColors.warning,
                  size: 40,
                ),
              ),
            ),
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
                  borderSide: BorderSide.none),
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
                        _noteController.text.trim().isEmpty
                            ? null
                            : _noteController.text.trim(),
                      ),
              child: const Text(AppStrings.submit,
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
