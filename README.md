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

**부제 예시**: 가톨릭 4복음을 장별로 듣는 오디오 앱 · VoiceOver 지원

**앱 설명에 넣을 문구 (시각장애인·VoiceOver 강조)**:

> 시각장애인을 위한 **Apple VoiceOver(화면 읽기)** 를 지원합니다. 복음·장 선택, 재생·정지, 수면 타이머를 음성 안내로 이용할 수 있으며, 말씀을 듣는 데 맞춘 앱입니다.

## 라이선스 · 저작권

오디오 및 앱 재배포 정책은 사용 중인 원본 라이선스에 따릅니다.
