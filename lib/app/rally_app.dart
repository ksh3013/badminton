import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:async';

import '../core/theme/app_theme.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../core/supabase/supabase_config.dart';
import '../features/auth/presentation/auth_gate.dart';
import '../features/matches/data/match_repository.dart';
import '../features/matches/domain/match.dart';
import '../features/matches/presentation/match_controller.dart';
import '../features/matches/presentation/pages/capture_page.dart';
import '../features/matches/presentation/pages/dashboard_page.dart';
import '../features/matches/presentation/pages/matches_page.dart';
import '../features/matches/presentation/pages/replay_page.dart';
import '../features/matches/presentation/pages/settings_page.dart';
import '../features/matches/presentation/widgets/match_widgets.dart';
import '../features/recording/data/camera_recording_service.dart';
import '../features/recording/data/device_readiness_service.dart';
import '../features/watch/data/watch_bridge.dart';

Future<void> runRallyApp() async {
  await initializeSupabase();
  runApp(const RallyApp());
}

class RallyApp extends StatelessWidget {
  const RallyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'RALLY',
    theme: buildAppTheme(),
    home: SupabaseConfig.isConfigured
        ? const AuthGate(child: RallyShell())
        : const SupabaseConfigurationPage(),
  );
}

class SupabaseConfigurationPage extends StatelessWidget {
  const SupabaseConfigurationPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Surface(
          child: Text(
            'Supabase 연결 설정이 필요합니다.\n\n'
            'SUPABASE_PUBLISHABLE_KEY를 --dart-define으로 전달한 뒤 앱을 실행하세요.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}

class EmptyMatchesPage extends StatelessWidget {
  const EmptyMatchesPage({required this.onCreate, super.key});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: PageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeading(
            eyebrow: 'MATCH LIBRARY',
            title: '오늘의 기록',
            subtitle: '첫 경기를 기록하고 중요한 순간을 다시 확인하세요.',
            action: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add, size: 17),
              label: const Text('경기 만들기'),
            ),
          ),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '아직 기록된 경기가 없어요.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  '경기를 만들면 녹화, 중요 장면 표시, 업로드와 다시보기를 시작할 수 있어요.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('첫 경기 만들기'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class RallyShell extends StatefulWidget {
  const RallyShell({super.key});

  @override
  State<RallyShell> createState() => _RallyShellState();
}

class _RallyShellState extends State<RallyShell> {
  late final MatchController controller;
  late final CameraRecordingService recorder;
  late final DeviceReadinessService deviceReadiness;
  late final WatchBridge watch;
  late final StreamSubscription<WatchCommand> _watchSubscription;
  late final Future<void> _ready;
  DeviceReadiness? _readiness;
  int page = 0;

  @override
  void initState() {
    super.initState();
    controller = MatchController(
      MatchRepository(
        client: SupabaseConfig.isConfigured ? Supabase.instance.client : null,
      ),
    );
    recorder = CameraRecordingService(
      onChunk: controller.uploadChunk,
      onChunkError: (error) =>
          _message('영상 조각 업로드에 실패했어요. 원본은 보존했고 재시도할 수 있어요: $error'),
    );
    deviceReadiness = DeviceReadinessService();
    watch = WatchBridge();
    _watchSubscription = watch.commands.listen(_handleWatchCommand);
    unawaited(watch.refreshConnection());
    _ready = _initialize();
  }

  @override
  void dispose() {
    recorder.dispose();
    _watchSubscription.cancel();
    watch.dispose();
    controller.dispose();
    super.dispose();
  }

  void _selectPage(int index) => setState(() => page = index);

  Future<void> _initialize() async {
    await Future.wait([controller.initialize(), _refreshReadiness()]);
  }

  Future<void> _refreshReadiness() async {
    _readiness = await deviceReadiness.read();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _startRecording() async {
    final readiness = await deviceReadiness.read();
    _readiness = readiness;
    if (mounted) setState(() {});
    final warning = readiness.warning;
    if (warning != null && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('녹화 환경을 확인하세요'),
          content: Text(warning),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('그래도 시작'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    try {
      await recorder.start();
      await controller.start();
      await _syncWatch();
      _message('녹화를 시작했어요.');
    } catch (error) {
      _message('카메라를 시작하지 못했어요: $error');
    }
  }

  Future<void> _togglePause() async {
    final recording = controller.currentMatch.status == MatchStatus.recording;
    await _setPause(recording);
    _message(recording ? '녹화를 잠시 멈췄어요.' : '녹화를 다시 시작했어요.');
  }

  Future<void> _setPause(bool pause) async {
    final status = controller.currentMatch.status;
    if (pause && status != MatchStatus.recording) return;
    if (!pause && status != MatchStatus.paused) return;
    if (pause && !recorder.isRecording) return;
    if (!pause && !recorder.isPaused) return;
    if (pause) {
      await recorder.pause();
    } else {
      await recorder.resume();
    }
    await controller.togglePause();
    await _syncWatch();
  }

  Future<void> _endRecording() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('녹화를 종료할까요?'),
        content: const Text('종료하면 마지막 영상 조각을 저장하고 업로드를 시작합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속 녹화'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('녹화 종료'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final finalChunk = await recorder.stop();
    try {
      await controller.end(finalChunk: finalChunk);
      await _syncWatch();
      _message('녹화를 종료하고 업로드를 완료했어요.');
    } catch (error) {
      _message('업로드에 실패했어요. 원본 파일은 삭제하지 않았습니다: $error');
    }
  }

  Future<void> _addMarker() async {
    final added = await controller.addMarker();
    await _syncWatch();
    _message(added ? '현재 시점에 중요 장면을 저장했어요.' : '녹화 중일 때만 중요 장면을 표시할 수 있어요.');
  }

  Future<void> _handleWatchCommand(WatchCommand command) async {
    switch (command) {
      case WatchCommand.start:
        await _startRecording();
      case WatchCommand.pause:
        await _setPause(true);
      case WatchCommand.resume:
        await _setPause(false);
      case WatchCommand.stop:
        await _endRecording();
      case WatchCommand.marker:
        await _addMarker();
    }
  }

  Future<void> _syncWatch() => watch.sendState(
    status: controller.currentMatch.status.name,
    elapsed: controller.currentMatch.duration,
    uploadProgress: controller.currentMatch.uploadProgress,
  );

  Future<void> _retryUpload() async {
    try {
      await controller.retryPendingUploads();
      _message('업로드를 다시 시도했어요.');
    } catch (error) {
      _message('업로드 재시도에 실패했어요: $error');
    }
  }

  Future<void> _createMatch() async {
    final values = await showDialog<_CreateMatchValues>(
      context: context,
      builder: (_) => const _CreateMatchDialog(),
    );
    if (values == null) return;
    await controller.createMatch(
      title: values.title,
      place: values.place,
      players: values.players,
      playedAt: values.playedAt,
    );
    _selectPage(2);
  }

  Widget _pageBody() {
    final match = controller.currentMatch;
    switch (page) {
      case 1:
        return MatchesPage(
          matches: controller.matches,
          onCreate: _createMatch,
          onOpen: (selected) {
            controller.selectMatch(selected);
            _selectPage(selected.status == MatchStatus.complete ? 3 : 2);
          },
        );
      case 2:
        return CapturePage(
          match: match,
          onStart: _startRecording,
          onPause: _togglePause,
          onEnd: _endRecording,
          onMarker: _addMarker,
          cameraService: recorder,
          onRetry: _retryUpload,
          watchState: watch.connectionState,
        );
      case 3:
        return ReplayPage(
          match: controller.replayMatch,
          playhead: controller.playhead,
          isPlaying: controller.isPlaying,
          onPlay: controller.togglePlayback,
          onSeek: controller.seek,
          onMarkerTap: controller.seekToMarker,
        );
      case 4:
        return SettingsPage(
          watchState: watch.connectionState,
          readiness: _readiness,
          cameraReady: recorder.isInitialized,
          onSignOut: SupabaseConfig.isConfigured
              ? () => Supabase.instance.client.auth.signOut()
              : null,
        );
      default:
        return DashboardPage(
          match: match,
          matches: controller.matches,
          watchState: watch.connectionState,
          onCreate: _createMatch,
          onCapture: () => _selectPage(2),
          onMarker: _addMarker,
          onPause: _togglePause,
          onEnd: _endRecording,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            controller.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (controller.error != null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(controller.error!, textAlign: TextAlign.center),
              ),
            ),
          );
        }
        if (controller.matches.isEmpty) {
          return EmptyMatchesPage(onCreate: _createMatch);
        }
        return AnimatedBuilder(
          animation: Listenable.merge([controller, watch]),
          builder: (context, _) => AppShell(
            page: page,
            watchState: watch.connectionState,
            readiness: _readiness,
            onPageChanged: _selectPage,
            child: _pageBody(),
          ),
        );
      },
    );
  }
}

class _CreateMatchValues {
  const _CreateMatchValues({
    required this.title,
    required this.place,
    required this.players,
    required this.playedAt,
  });

  final String title;
  final String place;
  final String players;
  final DateTime playedAt;
}

class _CreateMatchDialog extends StatefulWidget {
  const _CreateMatchDialog();

  @override
  State<_CreateMatchDialog> createState() => _CreateMatchDialogState();
}

class _CreateMatchDialogState extends State<_CreateMatchDialog> {
  late final TextEditingController title = TextEditingController();
  late final TextEditingController place = TextEditingController();
  late final TextEditingController players = TextEditingController();
  var playedAt = DateTime.now();
  String? error;

  @override
  void dispose() {
    title.dispose();
    place.dispose();
    players.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('새 경기 만들기'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DialogField(title, '경기 이름', '예: 금요일 저녁 복식'),
          _DialogField(place, '장소', '예: 서초 배드민턴 센터 · 3번 코트'),
          _DialogField(players, '선수', '예: 김세환 · 박준호 / 이서연 · 최민수'),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  initialDate: playedAt,
                );
                if (picked != null) setState(() => playedAt = picked);
              },
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text('${playedAt.year}.${playedAt.month}.${playedAt.day}'),
            ),
          ),
          if (error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(error!, style: const TextStyle(color: AppColors.red)),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: () {
          if (title.text.trim().isEmpty || place.text.trim().isEmpty) {
            setState(() => error = '경기 이름과 장소는 필수예요.');
            return;
          }
          Navigator.pop(
            context,
            _CreateMatchValues(
              title: title.text.trim(),
              place: place.text.trim(),
              players: players.text.trim(),
              playedAt: playedAt,
            ),
          );
        },
        child: const Text('경기 만들기'),
      ),
    ],
  );
}

class _DialogField extends StatelessWidget {
  const _DialogField(this.controller, this.label, this.hint);

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );
}

class AppShell extends StatelessWidget {
  const AppShell({
    required this.page,
    required this.watchState,
    required this.readiness,
    required this.onPageChanged,
    required this.child,
    super.key,
  });

  final int page;
  final WatchConnectionState watchState;
  final DeviceReadiness? readiness;
  final ValueChanged<int> onPageChanged;
  final Widget child;

  static const labels = ['오늘의 기록', '내 경기', '녹화 제어', '다시보기', '설정'];
  static const icons = [
    Icons.home_outlined,
    Icons.grid_view_rounded,
    Icons.fiber_manual_record_outlined,
    Icons.play_circle_outline,
    Icons.settings_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 900;
    return Scaffold(
      body: Row(
        children: [
          if (!mobile)
            _Sidebar(
              page: page,
              onPageChanged: onPageChanged,
              readiness: readiness,
            ),
          Expanded(
            child: Column(
              children: [
                _TopBar(page: page, watchState: watchState),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: mobile
          ? NavigationBar(
              selectedIndex: page,
              onDestinationSelected: onPageChanged,
              backgroundColor: const Color(0xFF121614),
              indicatorColor: const Color(0xFF294633),
              destinations: [
                for (var i = 0; i < labels.length; i++)
                  NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
              ],
            )
          : null,
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.page,
    required this.onPageChanged,
    required this.readiness,
  });

  final int page;
  final ValueChanged<int> onPageChanged;
  final DeviceReadiness? readiness;

  @override
  Widget build(BuildContext context) => Container(
    width: 232,
    padding: const EdgeInsets.fromLTRB(16, 28, 16, 18),
    decoration: const BoxDecoration(
      color: Color(0xFF121614),
      border: Border(right: BorderSide(color: AppColors.line)),
    ),
    child: Column(
      children: [
        const Row(
          children: [
            _BrandMark(),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RALLY',
                  style: TextStyle(
                    fontFamily: 'Headline',
                    fontSize: 18,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  '경기 다시보기',
                  style: TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 38),
        for (var i = 0; i < AppShell.labels.length - 1; i++)
          _NavItem(
            label: AppShell.labels[i],
            icon: AppShell.icons[i],
            selected: page == i,
            onTap: () => onPageChanged(i),
          ),
        const Spacer(),
        StorageCard(readiness: readiness),
        const SizedBox(height: 18),
        const Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF634C3E),
              child: Text(
                '김',
                style: TextStyle(color: Color(0xFFFFE6CE), fontSize: 12),
              ),
            ),
            SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '김세환',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                Text(
                  '기록자 계정',
                  style: TextStyle(color: AppColors.dim, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppColors.lime,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
        bottomRight: Radius.circular(12),
        bottomLeft: Radius.circular(4),
      ),
    ),
    child: const Text(
      'R',
      style: TextStyle(
        color: Color(0xFF101510),
        fontFamily: 'Headline',
        fontSize: 20,
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: ListTile(
      onTap: onTap,
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      tileColor: selected ? AppColors.panelRaised : Colors.transparent,
      leading: Icon(
        icon,
        color: selected ? AppColors.ink : AppColors.muted,
        size: 19,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.ink : AppColors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.page, required this.watchState});

  final int page;
  final WatchConnectionState watchState;

  @override
  Widget build(BuildContext context) {
    final connected = watchState == WatchConnectionState.connected;
    final label = switch (watchState) {
      WatchConnectionState.connected => '워치 연결됨',
      WatchConnectionState.disconnected => '워치 연결 끊김',
      WatchConnectionState.unavailable => '워치 브리지 대기',
    };
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 34),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          const Text(
            'RALLY',
            style: TextStyle(
              color: AppColors.dim,
              fontFamily: 'Headline',
              fontSize: 11,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text('/', style: TextStyle(color: AppColors.line)),
          ),
          Text(
            AppShell.labels[page],
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const Spacer(),
          Icon(
            Icons.circle,
            color: connected ? AppColors.greenBright : AppColors.orange,
            size: 7,
          ),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(width: 20),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
