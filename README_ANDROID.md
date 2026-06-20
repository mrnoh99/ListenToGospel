# 복음서듣기 Android

가톨릭 한국어 성경 오디오 앱 (마태오·마르코·루카·요한복음서) Android 버전

## 기술 스택

- **언어**: Kotlin
- **UI**: Jetpack Compose + Material 3
- **오디오**: MediaPlayer + Foreground Service
- **상태 관리**: ViewModel + StateFlow
- **최소 Android**: API 26 (Android 8.0)

## 기능

- 4복음서 선택 그리드 → 장 목록 → 재생
- 백그라운드 오디오 재생 (잠금화면 알림)
- 장 완료 시 다음 장 자동 재생
- 수면 타이머 (30/60/90/120분)
- 마지막 위치 자동 저장 및 이어듣기 제안
- 오디오 포커스 처리 (전화/알림 인터럽트)

## 프로젝트 설정

### 1. 저장소 클론
```bash
git clone -b android-studio https://github.com/mrnoh99/ListenToGospel.git ListenToGospel-Android
cd ListenToGospel-Android
```

### 2. 오디오 파일 복사
오디오 파일(89개 M4A, 약 339MB)은 크기로 인해 git에 포함되지 않습니다.  
iOS 프로젝트와 같은 경로에 클론했다면:
```bash
chmod +x copy_audio_assets.sh
./copy_audio_assets.sh
# 다른 경로라면:
./copy_audio_assets.sh /path/to/ListenToGospel/ListenToGospel/AudioFiles
```

### 3. Android Studio에서 열기
이 폴더(`settings.gradle.kts`가 있는 루트)를 Android Studio에서 Open합니다.

### 4. 빌드 및 실행
Gradle Sync 후 실행 버튼을 누르면 됩니다.

## 프로젝트 구조

```
app/src/main/
├── java/njs/listentogospel/
│   ├── ListenToGospelApp.kt       # Application class
│   ├── MainActivity.kt            # 단일 Activity
│   ├── model/Bible.kt             # Gospel enum, BibleChapter
│   ├── data/PlaybackPersistence.kt # SharedPreferences 저장
│   ├── audio/AudioPlayer.kt       # MediaPlayer 관리
│   ├── service/PlaybackService.kt # Foreground Service (알림)
│   ├── viewmodel/BiblePlayerViewModel.kt
│   └── ui/
│       ├── MainScreen.kt
│       ├── theme/
│       └── components/
└── assets/AudioFiles/             # M4A 오디오 파일 (별도 복사 필요)
```
