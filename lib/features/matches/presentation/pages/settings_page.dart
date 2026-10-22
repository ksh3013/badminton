import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../recording/data/device_readiness_service.dart';
import '../../../watch/data/watch_bridge.dart';
import '../widgets/match_widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    required this.watchState,
    required this.readiness,
    required this.cameraReady,
    this.onSignOut,
    super.key,
  });

  final WatchConnectionState watchState;
  final DeviceReadiness? readiness;
  final bool cameraReady;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) => PageScroll(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          eyebrow: 'ACCOUNT',
          title: '설정',
          subtitle: 'RALLY 기록 환경을 관리하세요.',
        ),
        SizedBox(
          width: 620,
          child: Surface(
            child: Column(
              children: [
                _SettingsDetails(
                  watchState: watchState,
                  readiness: readiness,
                  cameraReady: cameraReady,
                ),
                if (onSignOut != null) ...[
                  const Divider(height: 28),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: onSignOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('로그아웃'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _SettingsDetails extends StatelessWidget {
  const _SettingsDetails({
    required this.watchState,
    required this.readiness,
    required this.cameraReady,
  });

  final WatchConnectionState watchState;
  final DeviceReadiness? readiness;
  final bool cameraReady;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '현재 상태',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      const Text(
        '워치 브리지가 연결되면 상태와 마커가 실시간으로 동기화됩니다.',
        style: TextStyle(color: AppColors.muted, fontSize: 10),
      ),
      const SizedBox(height: 18),
      _InfoLine(
        icon: Icons.watch,
        label: '워치 연결',
        value: switch (watchState) {
          WatchConnectionState.connected => '연결됨',
          WatchConnectionState.disconnected => '끊김',
          WatchConnectionState.unavailable => '브리지 대기',
        },
      ),
      _InfoLine(
        icon: Icons.videocam_outlined,
        label: '카메라 상태',
        value: cameraReady ? '준비됨' : '시작 시 확인',
      ),
      _InfoLine(
        icon: Icons.sd_storage_outlined,
        label: '기기 저장공간',
        value: formatStorageBytes(readiness?.availableBytes),
      ),
      _InfoLine(
        icon: Icons.battery_6_bar,
        label: '배터리',
        value: readiness?.batteryPercent == null
            ? '확인 필요'
            : '${readiness!.batteryPercent}%',
        warning: (readiness?.batteryPercent ?? 100) < 15,
      ),
    ],
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.warning = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Row(
      children: [
        Icon(icon, color: AppColors.muted, size: 17),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: warning ? AppColors.orange : AppColors.greenBright,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
