# macOS 개발환경 한방 설치 스크립트

[![macOS](https://img.shields.io/badge/macOS-only-black)](#)
[![Shell](https://img.shields.io/badge/shell-zsh%20default%20%2B%20bash%20compatible-blue)](#)

새 Mac을 개발용으로 빠르게 세팅하는 bootstrap 스크립트입니다. Homebrew, VS Code, Chrome/Edge, Docker Desktop, Python, Git, Oh My Zsh, Oh My Posh, MesloLGS NF, 주요 CLI 도구, 선택형 AI/Web/iOS/Android 개발 도구를 설치하고 기본 셸 환경을 구성합니다.

공개 레포로 올려도 되는 구성을 목표로 만들었습니다. 사내 URL, 토큰, 비공개 패키지, 개인 계정 정보는 포함하지 않습니다.

GitHub: <https://github.com/AidALL/macos-dev-setup>

## 빠른 시작

권장 위치는 홈 디렉터리 아래 `~/macos-dev-setup`입니다.

```bash
cd ~
git clone https://github.com/AidALL/macos-dev-setup.git macos-dev-setup
cd macos-dev-setup
```

이 README의 명령은 모두 저장소 루트(`~/macos-dev-setup`) 기준 상대경로로 작성합니다.

터미널에서 안내를 보며 선택하려면:

```bash
./install-dev-environment.sh
```

추천 기본값으로 바로 설치하려면:

```bash
./install-dev-environment.sh --yes
```

설치 전에 무엇이 설치되고 어떤 파일이 바뀌는지 확인하려면:

```bash
./install-dev-environment.sh --yes --dry-run
```

모든 프로필을 설치하려면:

```bash
./install-dev-environment.sh --all
```

스크립트는 macOS 기본 셸인 zsh를 기준으로 실행됩니다. `bash ./install-dev-environment.sh --yes`처럼 실행해도 내부에서 zsh로 넘겨 같은 방식으로 동작합니다.

처음 실행하기 전에는 스크립트 내용을 한 번 읽어보는 것을 권장합니다. 이 스크립트는 Homebrew 패키지와 앱을 설치하고, `~/.zshrc`, Git 전역 설정, Oh My Zsh 설정을 변경합니다.

GitHub에서 바로 내려받아 실행하려면:

```bash
mkdir -p ~/macos-dev-setup
cd ~/macos-dev-setup
curl -fsSL https://raw.githubusercontent.com/AidALL/macos-dev-setup/main/install-dev-environment.sh -o ./install-dev-environment.sh
chmod +x ./install-dev-environment.sh
./install-dev-environment.sh --yes --dry-run
./install-dev-environment.sh --yes
```

## 기본 설치 항목

- Homebrew
- Rosetta 2 (Apple Silicon에서 Intel/amd64 호환성용)
- Xcode Command Line Tools 확인
- Visual Studio Code, Google Chrome, Microsoft Edge, Docker Desktop, iTerm2
- Git, GitHub CLI
- Python, `uv`, `pipx`
- Oh My Zsh, Oh My Posh, MesloLGS NF
- zsh history 50,000개 보관
- zsh 플러그인: autosuggestions, syntax highlighting, completions
- Git Unicode 설정
- macOS 한글 파일명 자소분리 방지를 위한 `nfd2nfc`
- `nfc-filenames` 파일명 NFC 변환 helper

## 선택 프로필

| 옵션 | 설치 내용 |
| --- | --- |
| `--minimal` | core 앱, 셸, Python, Git, 브라우저, Docker, 터미널 유틸리티 |
| `--ai` | Codex, Claude Code, Gemini CLI |
| `--web` | Node, pnpm, yarn, httpie, watchman, Postman |
| `--sw` | Go, Rust, C/C++ 빌드 도구, shellcheck, shfmt |
| `--ios` | CocoaPods, SwiftLint, SwiftFormat, XcodeGen, xcbeautify, xcodes, Tuist |
| `--android`, `--and` | Android Studio, platform-tools, Java, Gradle, Kotlin, Maven |
| `--all` | 모든 프로필 |
| `--dry-run` | 실제 설치 없이 선택된 설치 계획 출력 |
| `--no-rosetta` | Apple Silicon에서 Rosetta 2 설치 건너뛰기 |
| `--no-nfc-normalization` | `nfd2nfc` 설치와 상주 감시 기능 건너뛰기 |
| `--no-nfc-watch` | `nfd2nfc`는 설치하되 상주 감시 기능만 끄기 |

`--yes` 또는 비대화형 실행은 기본적으로 `core + --ai + --web + --sw`를 설치합니다.

## Rosetta 2와 Docker

Apple Silicon Mac의 기본 앱과 `arm64` Docker 이미지는 Rosetta 없이도 동작합니다. 다만 개발환경에서는 Intel용 CLI, 앱, `amd64`/`x86_64` Docker 이미지가 섞여 들어오는 경우가 있어 Rosetta 2를 기본으로 설치합니다.

인터랙티브 실행에서는 설명을 보여주고 설치 여부를 묻습니다. 비대화형 실행에서는 기본으로 켜집니다. 끄려면:

```bash
ROSETTA=0 ./install-dev-environment.sh --yes
./install-dev-environment.sh --yes --no-rosetta
```

## 한글 파일명 자소분리 대응

macOS에서 작성한 한글 파일명은 Windows/Linux 등 다른 OS에서 자소분리되어 보일 수 있습니다. 이 스크립트는 이를 줄이기 위해 `nfd2nfc`를 설치하고, 사용자가 동의하면 `Desktop`, `Documents`, `Downloads` 폴더를 상시 감시해 NFC 파일명으로 정리합니다.

인터랙티브 실행 시 다음처럼 안내하고 동의를 받습니다.

```text
macOS에서 작성한 한글 파일명은 Windows/Linux 등 다른 OS에서 자소분리되어 보일 수 있습니다.
이를 줄이기 위해 nfd2nfc를 설치하고 Desktop, Documents, Downloads 폴더를 상시 감시해 NFC 파일명으로 정리합니다.
nfd2nfc를 설치하고 상주 감시 기능을 켜는 데 동의하십니까? [Y/n]
```

비대화형 실행에서는 기본으로 켜집니다. 끄려면:

```bash
NFC_NORMALIZATION=0 ./install-dev-environment.sh --yes
```

`nfd2nfc`는 설치하되 상주 감시만 끄려면:

```bash
NFC_WATCH=0 ./install-dev-environment.sh --yes
```

감시 경로를 바꾸려면:

```bash
NFC_WATCH_PATHS="$HOME/Downloads:$HOME/Work" ./install-dev-environment.sh --yes
```

기존 파일명을 직접 점검하고 변환할 수도 있습니다.

```bash
nfc-filenames ~/Downloads
nfc-filenames --apply ~/Downloads
```

첫 번째 명령은 dry run입니다. 출력 내용을 확인한 뒤 `--apply`를 사용하세요.

## 설치 후 권한

`nfd2nfc` watcher는 macOS LaunchAgent로 실행됩니다. macOS가 일부 폴더 접근을 막으면 Full Disk Access 권한을 부여해야 할 수 있습니다.

```bash
which nfd2nfc-watcher
```

위 명령으로 나온 경로를 System Settings의 Full Disk Access에 추가하세요.

## 문제 해결

`backup_path:3: command not found: mkdir`처럼 기본 명령을 찾지 못하는 에러가 나면, 현재 셸의 `PATH`가 깨졌거나 스크립트를 `source`로 실행한 경우일 수 있습니다. 최신 스크립트는 안전한 기본 `PATH`를 복구하고, zsh 기본 실행과 bash 실행 호환성을 모두 지원합니다.

다시 실행할 때는 아래처럼 실행하세요.

```bash
./install-dev-environment.sh --yes
```

## 안전장치

- 기존 `~/.zshrc`와 Oh My Posh 테마 파일은 `~/.zsh-setup-backups/` 아래에 백업합니다.
- Homebrew 패키지는 이미 설치되어 있으면 건너뜁니다.
- Oh My Zsh와 플러그인은 git checkout이면 업데이트하고, 기존 비-git 디렉터리는 백업 후 이동합니다.
- `--dry-run`으로 설치 전 계획을 확인할 수 있습니다.
- 인터랙티브 실행에서는 실제 설치 전에 최종 확인을 한 번 더 받습니다.
- macOS 전용 스크립트입니다. Linux/Windows에서는 실행하지 않습니다.

## 공개 레포 체크리스트

공개 저장소로 올리기 전 아래만 확인하면 됩니다.

- 회사 전용 패키지, 내부 URL, 토큰, 계정명이 들어가지 않았는지 확인
- 회사 보안 정책상 자동 설치 가능한 앱 목록인지 확인
- 라이선스 파일 추가: 회사 정책이 허용하면 MIT 또는 Apache-2.0 권장
- README의 설치 명령을 실제 GitHub URL 기준으로 업데이트

## 왜 nfd2nfc인가

검토한 후보 중 `nfd2nfc`를 기본값으로 선택했습니다. Homebrew core로 설치할 수 있고, dry-run/JSON/CLI/TUI/상주 watcher를 지원하며, macOS의 실제 on-disk 파일명을 기준으로 변환하는 구현을 갖고 있어 새 Mac bootstrap에 가장 잘 맞습니다.

비교한 후보:

- `mrg`: 최근 Python 도구이고 macOS 부산물 정리 기능이 좋지만 Python 3.13+ 요구
- `unicode_norm`: NFC/NFD/NFKC/NFKD까지 지원하는 범용 도구지만 별도 tap 기반
- `fixname-cli`: npm 기반으로 단순하지만 디렉터리명 처리와 성숙도 면에서 기본값으로는 보류
- `convmv`: 오래 검증된 도구지만 새 Mac 온보딩 UX로는 덜 직관적
