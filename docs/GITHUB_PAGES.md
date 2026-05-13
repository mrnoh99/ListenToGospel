# GitHub Pages로 마케팅·지원 URL 게시하기

이 폴더(`docs/`)는 App Store Connect의 **Marketing URL**과 **Support URL**에 넣을 수 있는 정적 웹 페이지입니다.

## 게시 후 사용할 URL 예시

저장소 이름이 `ListenToBibleWeb`이고 GitHub 사용자명이 `mrnoh99`일 때:

| 용도 | URL |
|------|-----|
| Marketing URL | `https://mrnoh99.github.io/ListenToBibleWeb/` |
| Support URL | `https://mrnoh99.github.io/ListenToBibleWeb/support.html` |
| 개인정보 처리방침 | `https://mrnoh99.github.io/ListenToBibleWeb/privacy.html` |

(조직 페이지나 커스텀 도메인을 쓰면 위 주소를 그에 맞게 바꿉니다.)

## GitHub에서 설정

1. 이 `docs` 폴더를 저장소 **main**(또는 기본 브랜치)에 푸시합니다.
2. GitHub 저장소 → **Settings** → **Pages**
3. **Build and deployment** → **Source**: *Deploy from a branch*
4. **Branch**: `main` / **Folder**: `/docs` → **Save**
5. 몇 분 뒤 위와 같은 `https://…github.io/…/` 주소가 활성화됩니다.

## 수정할 항목

- `index.html`: App Store 링크(승인 후 실제 URL)
- `support.html`: 지원 이메일은 `jsnoh2010@gmail.com` 로 설정되어 있습니다.
- App Store **앱 개인정보** 항목에 `privacy.html` 전체 URL을 넣을 수 있습니다.

## 참고

- `.nojekyll` 파일은 Jekyll 없이 정적 HTML만 서빙할 때 사용합니다.
- 저장소가 **비공개**여도 GitHub Pages 무료 플랜에서는 공개 사이트 정책을 확인하세요.
