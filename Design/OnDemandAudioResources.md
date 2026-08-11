# 설계안 — 음성 데이터 On-Demand Resources(ODR) 전환

> 목표: App Store **업데이트 시 음성(m4a) 재다운로드를 방지**하고, **신규 설치 시에는 음성을 (첫 사용 시점에) 내려받도록** 한다. 음성 데이터 자체는 바뀌지 않으므로 업데이트 다운로드에서 제외한다.

이 문서는 **구현 전 검토용 설계·계획**입니다. 코드/프로젝트는 아직 변경하지 않았습니다.

---

## 1. 현재 구조 (분석)

- 음성 파일: `ListenToGospel/AudioFiles/{01.마태오복음, 02.마르코복음, 03.루카복음, 04.요한복음}/*.m4a`
  - **89개 파일, 총 약 339MB**
- 앱 프로젝트는 Xcode 16 **파일 시스템 동기화 그룹**(`PBXFileSystemSynchronizedRootGroup`, pbxproj 25–29행)을 사용 → `ListenToGospel` 폴더 안의 모든 파일이 자동으로 앱 번들에 포함됨. 즉 **음성 339MB가 앱 바이너리에 직접 번들**되어 있음.
- 로드 코드: `BiblePlayerViewModel.audioURL(for:)`(595행~)이 `Bundle.main.url(forResource:…,subdirectory:)` → 디렉터리 나열 → 번들 워킹 순으로 파일 URL을 해석함. 모두 **로컬 번들 존재를 전제**로 함.

### 문제
- App Store 업데이트 시, 음성이 바뀌지 않았어도 앱 페이로드에 포함되어 있어 **매 업데이트마다 339MB를 다시 받음**.
- 초기 설치 용량도 과도하게 큼.

---

## 2. 접근 방식: On-Demand Resources (선택됨)

Apple 기본 기능. 태그가 지정된 리소스는 앱 바이너리와 **분리**되어 App Store가 호스팅하고, 런타임에 `NSBundleResourceRequest`로 내려받아 **시스템 관리 캐시**에 저장된다.

### 요구사항 충족 근거
- **신규 설치**: 앱 다운로드에는 on-demand 태그가 포함되지 않음 → 첫 재생 시점에 해당 음성을 내려받음. ✅ "새로 설치할 때는 음성 다운로드".
- **앱 업데이트**: 음성 태그 콘텐츠가 그대로면(해시 동일) 업데이트 페이로드에 포함되지 않고, **이미 내려받아 캐시된 음성은 유지**되어 재다운로드하지 않음. ✅ "업데이트 시 재다운로드 안 함".
- **부가 효과**: App Store 초기 다운로드/업데이트 용량이 수백 MB → 수 MB 수준으로 감소.

### 반드시 알아둘 주의점(트레이드오프)
1. **캐시 퍼지**: ODR 캐시는 "purgeable"이다. 앱이 실행 중이 아닐 때 기기 저장공간이 부족하면 시스템이 지울 수 있고, 이후 다시 필요할 때 재다운로드된다. (완전한 영구 보관을 보장하려면 §7의 "대안 B: 자체 캐시" 필요 — 이번 선택은 ODR)
2. **이번 릴리스 1회 전환 비용**: 이 업데이트로 번들에서 음성이 빠지므로, **기존 사용자도 업데이트 후 처음 듣는 복음은 1회 다운로드**가 발생한다(이후 업데이트부터는 재다운로드 없음). 릴리스 노트에 안내 권장.
3. **첫 재생 지연/네트워크 필요**: 아직 안 받은 복음을 처음 재생할 때 다운로드가 끝나야 재생 시작. 오프라인이면 재생 불가 → 명확한 안내 UI 필요(§6).

---

## 3. 태그 전략

리소스를 태그(asset tag) 단위 "asset pack"으로 묶는다.

| 방식 | 팩 수 | 팩 크기 | 장점 | 단점 |
|---|---|---|---|---|
| 전체 1태그 | 1 | ~339MB | 가장 단순 | 첫 사용 시 339MB 한 번에 |
| **복음별 (권장)** | **4** | 복음당 ~60~120MB | 선택한 복음만 받음, 연속 재생이 매끄러움(책 전체 선다운로드), 동기화 그룹의 **하위 폴더 단위 태그**로 깔끔 | 복음 첫 재생 시 그 책 전체를 받음 |
| 장별 | 89 | 장당 ~3.8MB | 최소 다운로드 | 태그 89개 관리, 연속 재생 시 다음 장 프리페치 로직 필요 |

**권장: 복음별 4개 태그.** 앱의 사용 흐름(복음 선택 → 선택 장부터 끝까지 연속 재생)과 맞고, 파일 시스템 동기화 그룹에서 **4개 하위 폴더에 각각 태그**만 지정하면 되어 89개 파일을 개별 관리할 필요가 없다.

제안 태그 이름:
- `audio-matthew` → `AudioFiles/01.마태오복음`
- `audio-mark` → `AudioFiles/02.마르코복음`
- `audio-luke` → `AudioFiles/03.루카복음`
- `audio-john` → `AudioFiles/04.요한복음`

> 데이터 절약을 더 원하면 장별(89태그)로 세분화 가능. 그 경우 §5 코드에 "현재 장 + 다음 1~2장 프리페치"를 추가한다.

---

## 4. Xcode 프로젝트 변경

### 4.1 ODR 태그 지정 (동기화 그룹 환경)
Xcode 16 동기화 그룹에서는 pbxproj를 손으로 편집하지 말고 **Xcode File Inspector**로 지정한다(수동 편집은 빌드 검증 없이 위험):

1. 프로젝트 네비게이터에서 `AudioFiles/01.마태오복음` 폴더 선택.
2. File Inspector(⌥⌘1) → **"On Demand Resource Tags"** 필드에 `audio-matthew` 입력.
3. 나머지 3개 복음 폴더도 각 태그로 반복.
   - Xcode가 pbxproj에 동기화 그룹 예외(`PBXFileSystemSynchronizedBuildFileExceptionSet` / membership exception, `ASSET_TAGS`)와 프로젝트 속성 `KnownAssetTags`를 자동 추가한다.

### 4.2 초기 설치/프리페치 설정
Target → Build Settings 및 Resource Tags 탭:
- **Initial Install Tags**: 비워 둔다(넣으면 앱 최초 설치 시 함께 받아 "신규 설치 시 다운로드" 취지와 용량 이점이 약해짐).
- **Prefetched Tag Order**: 비워 두거나(완전 on-demand), 선택적으로 넣으면 설치 후 백그라운드 선다운로드. → **비움 권장**(요구사항은 "첫 사용 시 다운로드").
- 결과: 4개 태그 모두 순수 **on-demand**.

### 4.3 확인 사항
- iOS 배포 타깃은 ODR 지원(iOS 9+)이라 문제 없음.
- 개발/테스트 중에는 Xcode가 로컬에서 ODR을 시뮬레이트(로컬 서버). TestFlight/App Store에서는 Apple이 호스팅.

---

## 5. 코드 변경 설계

### 5.1 새 컴포넌트: `AudioResourceProvider`
`NSBundleResourceRequest`를 복음(태그) 단위로 관리하는 얕은 래퍼.

책임:
- `tag(for gospel:) -> String`
- `isDownloaded(gospel:) async -> Bool` — `conditionallyBeginAccessingResources`로 이미 캐시됐는지 확인.
- `ensureDownloaded(gospel:, onProgress:) async throws` — 미다운로드 시 `beginAccessingResources`로 내려받기(진행률은 `request.progress` 관찰).
- 재생 중인 복음의 request를 **강한 참조로 유지**(재생 도중 퍼지 방지), 다른 복음으로 전환하거나 정지 시 `endAccessingResources` 호출로 해제.
- `loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent` 로 첫 재생 다운로드 우선순위 상향.

### 5.2 `Bible.Gospel` 확장
```
var onDemandResourceTag: String  // "audio-matthew" 등
```

### 5.3 재생 흐름 변경 (`BiblePlayerViewModel`)
`play(_:)`/`playFromSelection()`에서 실제 `audioURL(for:)` 해석 **이전에** 다운로드 보장 단계 삽입:

1. 대상 장의 복음 태그가 캐시됐는지 확인.
2. 아니면 상태를 "다운로드 중"으로 전환하고 `ensureDownloaded` 실행(진행률 → `playbackMessage`/전용 `downloadProgress`에 반영, VoiceOver 안내).
3. 성공 시 기존 `audioURL(for:)`로 URL 해석 → 재생. (ODR 다운로드 후 리소스는 접근 유지 동안 `Bundle.main`으로 조회 가능하므로 **기존 해석 코드는 그대로 재사용**, 폴백 경로도 유지.)
4. 실패 시(오프라인/공간부족) 에러 메시지 표시, 재생 시작 안 함.

연속 재생(다음 장 자동 재생)은 같은 복음 태그 내이므로 추가 다운로드 없음. 복음이 바뀌는 경우는 앱 특성상 사용자가 명시적으로 다른 복음을 선택할 때뿐 → 그 시점에 새 태그 다운로드.

### 5.4 상태/모델 추가
- `@Published var downloadState: DownloadState`  (`idle`/`downloading(progress:)`/`failed(message:)`)
- 기존 `missingResourceNames` 로직은 "번들에 파일이 없다"는 의미였으므로 ODR 도입 후에는 다운로드 상태로 대체/정리.

---

## 6. 오프라인·에러·접근성 UX

- **다운로드 중**: 재생 바/타이머 바 영역에 "음성 내려받는 중… 45%" 표시. VoiceOver로 진행/완료 안내(기존 `AccessibilitySupport` 패턴 활용). 큰 다운로드(복음 전체)이므로 진행률 표시 중요.
- **오프라인 첫 재생**: "이 복음을 처음 들으려면 인터넷 연결이 필요합니다. 연결 후 다시 시도해 주세요." (이미 받은 복음은 오프라인 재생 가능.)
- **저장공간 부족**(`NSBundleOnDemandResourceOutOfSpaceError`): "기기 저장공간이 부족합니다." 안내.
- **취소**: 다운로드 중 정지 시 요청 취소 가능.

---

## 7. 대안 및 선택 근거

- **대안 A(선택): ODR** — 외부 서버 불필요(Apple 호스팅), 앱 용량/업데이트 용량 대폭 감소, 요구사항 충족. 단점: 시스템 퍼지 가능성.
- **대안 B: 자체 서버/CDN + 영구 캐시(Application Support)** — 퍼지 없이 완전 영구 보관·완전 제어. 단점: 339MB 호스팅 위치·비용, 다운로드/캐시/무결성 코드 직접 구현. (요구가 "영구 보관 보장"이면 재검토.)

---

## 8. 마이그레이션 · 롤아웃

1. 번들에서 음성 제거 + ODR 태그 지정(§4). → 앱 바이너리 급감.
2. 이 버전은 `1.1`(빌드 1) 라인에서 진행 중 → ODR 릴리스는 별도 마이너 버전으로 올리는 것을 권장(예: `1.2`).
3. 릴리스 노트: "이번 업데이트부터 음성은 필요할 때 내려받아 저장합니다. 처음 듣는 복음은 1회 다운로드가 필요하며, 이후 앱 업데이트에서는 다시 받지 않습니다."
4. `docs/`(마케팅/지원 페이지)에 다운로드 동작 안내 추가.

---

## 9. 테스트 계획

- **Xcode 로컬 ODR 시뮬레이션**: 태그 다운로드/접근/해제, 진행률.
- **Debug 메뉴 → Disk Gauge**로 ODR 용량/퍼지 동작 확인.
- 시나리오:
  1. 신규 설치 → 복음 첫 재생 시 다운로드 발생, 재생 성공.
  2. 이미 받은 복음 → 오프라인에서도 재생.
  3. 안 받은 복음 오프라인 재생 → 에러 안내.
  4. 앱 업데이트(빌드만 올림) → **기존 다운로드 유지, 재다운로드 없음** 확인.
  5. 저장공간 부족 → 에러 안내.
- 회귀: 연속 재생/이어 듣기/시리·단축어 재생/수면 타이머가 다운로드 단계와 정상 연동되는지.

---

## 10. 실행 체크리스트 (승인 후)

- [ ] `AudioFiles` 4개 복음 폴더에 ODR 태그 지정(Xcode File Inspector)
- [ ] Initial Install / Prefetch 태그 비움 확인
- [ ] `Bible.Gospel.onDemandResourceTag` 추가
- [ ] `AudioResourceProvider`(NSBundleResourceRequest 래퍼) 구현
- [ ] `BiblePlayerViewModel` 재생 흐름에 다운로드 보장 단계 삽입 + 상태/UI
- [ ] 오프라인/공간부족/진행률 UX + VoiceOver 안내
- [ ] 버전 `1.2`로 상향, 릴리스 노트/문서 갱신
- [ ] Xcode 실기기·TestFlight 검증(이 환경에선 iOS 빌드 검증 불가)
