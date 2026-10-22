# RALLY · 배드민턴 경기 다시보기

Flutter 앱과 Supabase를 연결하는 배드민턴 경기 기록 MVP입니다.

## Supabase 연결

Supabase 프로젝트 URL과 클라이언트용 publishable key가 기본 설정되어 있습니다.
publishable key는 RLS가 활성화된 클라이언트 앱에 내장할 수 있는 공개 키입니다.
다른 환경을 사용할 때만 실행 시 dart-define으로 덮어씁니다.

```bash
flutter run
```

DB와 비공개 영상 버킷 설정은 아래 migration을 순서대로 Supabase SQL Editor에서
실행합니다.

- [`supabase/migrations/20261014130000_initial_schema.sql`](supabase/migrations/20261014130000_initial_schema.sql)
- [`supabase/migrations/20261014140000_match_access.sql`](supabase/migrations/20261014140000_match_access.sql)
- [`supabase/migrations/20261014150000_fix_match_rls_recursion.sql`](supabase/migrations/20261014150000_fix_match_rls_recursion.sql)

경기·참가자·영상 조각·마커 테이블, 소유자/참가자 RLS, `match-videos` private
bucket을 생성합니다.

service_role 같은 secret key는 Flutter 앱에 사용하지 않습니다.

녹화 중 생성된 조각은 앱 전용 지원 디렉터리의
`rally_pending_uploads.json`에 업로드 대기 상태로 기록됩니다. 업로드가 성공한
조각만 로컬 파일을 삭제하며, 앱을 다시 실행하면 남은 조각을 자동으로 재시도합니다.
Android에서는 녹화 중 foreground service 알림을 사용해 백그라운드 전환 시에도
녹화 프로세스가 유지되도록 구성되어 있습니다. Android 구현은 Camera2 기반
`camera_android`를 사용해 CameraX Activity 생명주기에 의해 녹화가 끊기지 않도록
했습니다. Android의 백그라운드 마이크 접근은 OS 정책에 따라 음성이 제한될 수
있으므로, 카메라 영상과 포그라운드 서비스 상태는 실기기에서 별도로 확인해야 합니다.

각 영상 조각은 `pending/uploading/uploaded/failed` 상태를 DB와 앱 상태에 함께
기록하며, 실패 조각은 원본 파일을 보존한 채 재시도 대상으로 남깁니다.

녹화 시작 전 Android/iOS 네이티브 채널에서 남은 저장공간과 배터리를 확인하고,
저장공간 512MB 미만 또는 배터리 15% 미만이면 사용자 확인 경고를 표시합니다.

워치 연결은 `rally/watch` 플랫폼 채널을 사용합니다. Android phone 앱은 Wear OS
Data Layer의 `/rally/command` 메시지를 수신하고 `/rally/state` 메시지를 전송하며,
Flutter 엔진이 없는 시점의 명령은 로컬 큐에 보관합니다. iOS는 `WatchConnectivity`로
명령 수신과 상태 전송을 연결합니다. Android Wear companion 화면은 `:wear` 모듈로
포함되어 휴대폰 명령 전송, 녹화 상태·업로드 진행률 표시를 제공합니다. 빌드는 다음과
같습니다.

```bash
cd android
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  ./gradlew :wear:assembleDebug
```

실제 Apple Watch용 WatchKit 화면 target은 Xcode에서 별도 target으로 추가해야 합니다.

- command: `start`, `pause`, `resume`, `stop`, `marker`
- state: `status`, `elapsedSeconds`, `uploadProgress`
- Android path: `/rally/command`, `/rally/state`
# badminton
