# ListenToGospel

이 저장소에는 **ListenToGospel** iOS 앱 전체 프로젝트(Xcode)·오디오 자산과, **GitHub Pages**용 정적 페이지(`docs/`)가 함께 있습니다.

## GitHub Pages (마케팅 · 지원 · 개인정보)

저장소 **Settings → Pages** 에서 Branch **main**, Folder **`/docs`** 를 선택하세요.

- 마케팅: https://mrnoh99.github.io/ListenToGospel/
- 지원: https://mrnoh99.github.io/ListenToGospel/support.html
- 개인정보 처리방침: https://mrnoh99.github.io/ListenToGospel/privacy.html

상세 설정은 [`docs/GITHUB_PAGES.md`](docs/GITHUB_PAGES.md) 를 참고하세요.

## Xcode 앱

- 솔루션: `ListenToGospel.xcodeproj`
- 소스 및 리소스: `ListenToGospel/` (Swift, 에셋, `AudioFiles/`)
- 앱 plist 등: `Config/Info.plist` (프로젝트 설정에 따라 다를 수 있음)

로컬에서 `ListenToGospel.xcodeproj` 를 Xcode로 여세요.

## App Store Connect

| 항목 | 값 |
|------|-----|
| 앱 이름 | 복음서듣기 |
| 번들 ID | `njs.ListenToGospel` |
| 버전 | 1.0 (빌드 1) |
| 마케팅 URL | https://mrnoh99.github.io/ListenToGospel/ |
| 지원 URL | https://mrnoh99.github.io/ListenToGospel/support.html |
| 개인정보 처리방침 URL | https://mrnoh99.github.io/ListenToGospel/privacy.html |

**키워드** (100자 이내, 쉼표 구분):

```
성경,가톨릭,복음,듣기,오디오,성경듣기,수면,타이머,불면,숙면,잠자기,천주교,성당,불면증,잘자기,bible,복음서,gospel,catholic
```

**부제 예시**: 가톨릭 4복음 · VoiceOver · 시리·단축어

**앱 설명에 넣을 문구 (VoiceOver · 시리 · 손쉬운 사용)**:

> 시각장애인을 위한 **Apple VoiceOver(화면 읽기)** 를 지원합니다. 「복음 선택」「장 목록」「재생 제어」 제목으로 빠르게 탐색하고, 복음·장·재생·수면 타이머를 음성으로 조작할 수 있습니다.
>
> **시리·단축어(App Intents)**: 「복음서듣기에서 마태오 3장 재생」, 「이어서 재생」, 「수면 타이머 30분」, 「복음서듣기 정지」. [말하기 예시 표](https://mrnoh99.github.io/ListenToGospel/#siri)
>
> **손쉬운 사용**: 재생·정지·장 변경 **햅틱** · **Voice Control**(「재생 탭」「마태오 탭」) · 앱 실행 시 **이어 듣기 제안** · 잠금 화면 **이전·다음 장**. [자세히](https://mrnoh99.github.io/ListenToGospel/#accessibility-features)

### 시리 · 단축어 (말하기 예시)

| 말하기 예시 | 동작 |
|------------|------|
| 「복음서듣기에서 마태오 3장 재생」 | 해당 장 재생 |
| 「이어서 재생」(앱 이름 포함) | 정지 위치에서 이어 듣기 |
| 「수면 타이머 30분」 | 30분 후 자동 정지 |
| 「복음서듣기 정지」 | 재생 정지 |

### 손쉬운 사용 · 재생 편의

| 기능 | 설명 |
|------|------|
| 햅틱 피드백 | 재생·정지·장 변경 시 짧은 진동으로 상태 확인 |
| Voice Control | 「재생 탭」「마태오 탭」처럼 음성으로 버튼 조작 |
| VoiceOver 제목(Rotor) | 「복음 선택」「장 목록」「재생 제어」 구역별 탐색 |
| 이어 듣기 제안 | 앱 재실행 시 「이어서 마태오 5장 재생」 한 번 탭으로 재개 |
| 잠금 화면 | 재생 중 이전 곡·다음 곡으로 장 넘기기 |

## 라이선스 · 저작권

오디오 및 앱 재배포 정책은 사용 중인 원본 라이선스에 따릅니다.
