import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/app_logger.dart';

class DevPanelOverlay extends StatefulWidget {
  final Widget child;

  const DevPanelOverlay({super.key, required this.child});

  @override
  State<DevPanelOverlay> createState() => _DevPanelOverlayState();
}

class _DevPanelOverlayState extends State<DevPanelOverlay> {
  bool _visible = false;

  void _toggle() => setState(() => _visible = !_visible);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          bottom: 100,
          right: 16,
          child: FloatingActionButton.small(
            heroTag: 'dev_panel_fab',
            backgroundColor: AppColors.textSecondary.withAlpha(200),
            onPressed: _toggle,
            child: const Icon(Icons.more_vert, color: Colors.white, size: 18),
          ),
        ),
        if (_visible)
          Positioned(
            bottom: 160,
            right: 16,
            child: _DevPanel(onClose: _toggle),
          ),
      ],
    );
  }
}

class _DevPanel extends StatelessWidget {
  final VoidCallback onClose;

  const _DevPanel({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final logs = AppLogger.instance.recentLogs;

    return Material(
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      color: Colors.transparent,
      child: Container(
        width: 300,
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
              child: Row(
                children: [
                  const Text(
                    AppStrings.devPanel,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Colors.white54, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(AppStrings.envVars),
                  _EnvRow('TOKEN_SERVER', 'http://localhost:3000'),
                  _EnvRow('100MS_APP_ID', '*** masked ***'),
                  const SizedBox(height: 8),
                  _SectionLabel(AppStrings.buildInfo),
                  _EnvRow('Version', '1.0.0+1'),
                  _EnvRow('Flavor', 'debug'),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _SectionLabel(AppStrings.recentLogs),
            ),
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                shrinkWrap: true,
                itemCount: logs.length,
                itemBuilder: (_, i) {
                  final entry = logs[i];
                  return GestureDetector(
                    onLongPress: () {
                      Clipboard.setData(ClipboardData(text: entry.toString()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        entry.toString(),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
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
        color: Colors.white38,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _EnvRow extends StatelessWidget {
  final String label;
  final String value;
  const _EnvRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
