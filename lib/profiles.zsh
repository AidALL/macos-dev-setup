# Profile selection and installation plan helpers for install-dev-environment.sh.

enable_default_profiles() {
  INSTALL_AI=1
  INSTALL_WEB=1
  INSTALL_SW=1
}

enable_all_profiles() {
  INSTALL_AI=1
  INSTALL_WEB=1
  INSTALL_SW=1
  INSTALL_IOS=1
  INSTALL_ANDROID=1
}

disable_optional_profiles() {
  INSTALL_AI=0
  INSTALL_WEB=0
  INSTALL_SW=0
  INSTALL_IOS=0
  INSTALL_ANDROID=0
}

prompt_yes_no() {
  local prompt="$1"
  local default_answer="$2"
  local answer
  local suffix

  if [[ "$default_answer" == "y" ]]; then
    suffix="[Y/n]"
  else
    suffix="[y/N]"
  fi

  while true; do
    printf "%s %s " "$prompt" "$suffix"
    IFS= read -r answer
    answer="${answer:-$default_answer}"
    case "$answer" in
      y | Y | yes | Yes | YES | "예" | "네" | "응" | "ㅇ" | "ㅇㅇ")
        return 0
        ;;
      n | N | no | No | NO | "아니" | "아니오" | "아니요" | "ㄴ" | "ㄴㄴ")
        return 1
        ;;
      *)
        printf "Please answer y or n. 한국어로는 예/아니요도 사용할 수 있습니다.\n"
        ;;
    esac
  done
}

run_interactive_picker() {
  cat <<'INTRO'

macOS development environment installer

Core is always installed:
  Homebrew, Xcode Command Line Tools check, VS Code, Chrome, Edge, Docker,
  Python, Git/GitHub CLI, terminal utilities, Oh My Zsh, Oh My Posh, fonts,
  Rosetta 2 on Apple Silicon when needed.

Choose extra profiles:
INTRO

  if prompt_yes_no "Install every development profile? (AI + Web + SW + iOS + Android)" "n"; then
    enable_all_profiles
  else
    if prompt_yes_no "Install recommended default profiles? (AI + Web + SW)" "y"; then
      enable_default_profiles
    fi

    if prompt_yes_no "Install iOS helpers? (CocoaPods, SwiftLint, XcodeGen, Tuist, etc.)" "n"; then
      INSTALL_IOS=1
    fi

    if prompt_yes_no "Install Android helpers? (Android Studio, platform-tools, Java, Gradle, Kotlin, Maven)" "n"; then
      INSTALL_ANDROID=1
    fi
  fi

  if [[ "$ROSETTA_CHOICE_SET" == "0" && "$(uname -s 2>/dev/null || true)" == "Darwin" && "$(uname -m 2>/dev/null || true)" == "arm64" ]]; then
    cat <<'ROSETTAINTRO'

Apple Silicon Mac에서 Intel(x86_64/amd64)용 CLI, 앱, Docker 이미지와 호환되도록 Rosetta 2를 설치합니다.
ROSETTAINTRO
    if prompt_yes_no "Rosetta 2를 설치하시겠습니까?" "y"; then
      INSTALL_ROSETTA=1
    else
      INSTALL_ROSETTA=0
    fi
  fi

  if [[ "$NFC_CHOICE_SET" == "0" ]]; then
    cat <<'NFCINTRO'

macOS에서 작성한 한글 파일명은 Windows/Linux 등 다른 OS에서 자소분리되어 보일 수 있습니다.
이를 줄이기 위해 nfd2nfc를 설치하고 Desktop, Documents, Downloads 및 감지된 클라우드 동기화 폴더를 상시 감시해 NFC 파일명으로 정리합니다.
NFCINTRO
    if prompt_yes_no "nfd2nfc를 설치하고 상주 감시 기능을 켜는 데 동의하십니까?" "y"; then
      INSTALL_NFC_TOOLS=1
      INSTALL_NFC_WATCH=1
    else
      INSTALL_NFC_TOOLS=0
      INSTALL_NFC_WATCH=0
    fi
  fi
}

print_selection_summary() {
  info "Selected profiles"
  printf "  core:    yes\n"
  printf "  ai:      %s\n" "$([[ "$INSTALL_AI" == "1" ]] && printf yes || printf no)"
  printf "  web:     %s\n" "$([[ "$INSTALL_WEB" == "1" ]] && printf yes || printf no)"
  printf "  sw:      %s\n" "$([[ "$INSTALL_SW" == "1" ]] && printf yes || printf no)"
  printf "  ios:     %s\n" "$([[ "$INSTALL_IOS" == "1" ]] && printf yes || printf no)"
  printf "  android: %s\n" "$([[ "$INSTALL_ANDROID" == "1" ]] && printf yes || printf no)"
  printf "  rosetta: %s\n" "$([[ "$INSTALL_ROSETTA" == "1" ]] && printf yes || printf no)"
  printf "  nfc:     %s\n" "$([[ "$INSTALL_NFC_TOOLS" == "1" ]] && printf yes || printf no)"
  printf "  nfcwatch:%s\n" "$([[ "$INSTALL_NFC_WATCH" == "1" ]] && printf " yes" || printf " no")"
}

CORE_FORMULAE=(
  git
  gh
  python
  python-tk
  pipx
  uv
  curl
  wget
  jq
  yq
  ripgrep
  fd
  fzf
  bat
  eza
  tree
  zoxide
  direnv
  tmux
  htop
  watch
  oh-my-posh
)

NFC_FORMULAE=(
  nfd2nfc
)

AI_FORMULAE=(
  node
)

WEB_FORMULAE=(
  node
  pnpm
  yarn
  httpie
  watchman
)

SW_FORMULAE=(
  go
  rust
  cmake
  ninja
  pkgconf
  openssl@3
  sqlite
  xz
  zstd
  shellcheck
  shfmt
)

IOS_FORMULAE=(
  cocoapods
  swiftlint
  swiftformat
  xcodegen
  xcbeautify
  ios-deploy
  xcodes
)

ANDROID_FORMULAE=(
  openjdk@21
  gradle
  kotlin
  maven
)

CORE_CASKS=(
  visual-studio-code
  google-chrome
  microsoft-edge
  docker-desktop
  iterm2
  font-meslo-for-powerlevel10k
)

WEB_CASKS=(
  postman
)

IOS_CASKS=(
  tuist
)

ANDROID_CASKS=(
  android-studio
  android-platform-tools
)

AI_NPM_PACKAGES=(
  @openai/codex
  @anthropic-ai/claude-code
  @google/gemini-cli
)

CORE_VSCODE_EXTENSIONS=(
  ms-python.python
  ms-python.vscode-pylance
  ms-python.debugpy
  charliermarsh.ruff
  ms-toolsai.jupyter
  eamodio.gitlens
  redhat.vscode-yaml
  tamasfe.even-better-toml
)

WEB_VSCODE_EXTENSIONS=(
  dbaeumer.vscode-eslint
  esbenp.prettier-vscode
  ms-azuretools.vscode-docker
  bradlc.vscode-tailwindcss
)

SW_VSCODE_EXTENSIONS=(
  github.vscode-github-actions
  rust-lang.rust-analyzer
  golang.go
)

IOS_VSCODE_EXTENSIONS=(
  swiftlang.swift-vscode
)

ANDROID_VSCODE_EXTENSIONS=(
  redhat.java
  vscjava.vscode-gradle
  fwcd.kotlin
)

print_list() {
  local title="$1"
  shift

  printf "\n%s:\n" "$title"
  if [[ "$#" -eq 0 ]]; then
    printf "  (none)\n"
    return
  fi

  local seen=$'\n'
  local item
  for item in "$@"; do
    if [[ "$seen" == *$'\n'"$item"$'\n'* ]]; then
      continue
    fi
    seen="${seen}${item}"$'\n'
    printf "  - %s\n" "$item"
  done
}

print_installation_plan() {
  local selected_formulae=("${CORE_FORMULAE[@]}")
  local selected_casks=("${CORE_CASKS[@]}")
  local selected_npm=()
  local selected_extensions=("${CORE_VSCODE_EXTENSIONS[@]}")
  local posh_theme_display
  local watch_paths_display
  posh_theme_display="$(home_relative_path "$POSH_THEME")"
  watch_paths_display="$(home_relative_path_list "$(resolve_nfc_watch_paths)")"

  if [[ "$INSTALL_NFC_TOOLS" == "1" ]]; then
    selected_formulae+=("${NFC_FORMULAE[@]}")
  fi
  if [[ "$INSTALL_AI" == "1" ]]; then
    selected_formulae+=("${AI_FORMULAE[@]}")
    selected_npm+=("${AI_NPM_PACKAGES[@]}")
  fi
  if [[ "$INSTALL_WEB" == "1" ]]; then
    selected_formulae+=("${WEB_FORMULAE[@]}")
    selected_casks+=("${WEB_CASKS[@]}")
    selected_extensions+=("${WEB_VSCODE_EXTENSIONS[@]}")
  fi
  if [[ "$INSTALL_SW" == "1" ]]; then
    selected_formulae+=("${SW_FORMULAE[@]}")
    selected_extensions+=("${SW_VSCODE_EXTENSIONS[@]}")
  fi
  if [[ "$INSTALL_IOS" == "1" ]]; then
    selected_formulae+=("${IOS_FORMULAE[@]}")
    selected_casks+=("${IOS_CASKS[@]}")
    selected_extensions+=("${IOS_VSCODE_EXTENSIONS[@]}")
  fi
  if [[ "$INSTALL_ANDROID" == "1" ]]; then
    selected_formulae+=("${ANDROID_FORMULAE[@]}")
    selected_casks+=("${ANDROID_CASKS[@]}")
    selected_extensions+=("${ANDROID_VSCODE_EXTENSIONS[@]}")
  fi

  cat <<PLAN

Installation plan
-----------------
Profiles:
  core:      yes
  ai:        $([[ "$INSTALL_AI" == "1" ]] && printf yes || printf no)
  web:       $([[ "$INSTALL_WEB" == "1" ]] && printf yes || printf no)
  sw:        $([[ "$INSTALL_SW" == "1" ]] && printf yes || printf no)
  ios:       $([[ "$INSTALL_IOS" == "1" ]] && printf yes || printf no)
  android:   $([[ "$INSTALL_ANDROID" == "1" ]] && printf yes || printf no)
  rosetta:   $([[ "$INSTALL_ROSETTA" == "1" ]] && printf yes || printf no)
  nfc:       $([[ "$INSTALL_NFC_TOOLS" == "1" ]] && printf yes || printf no)
  nfcwatch:  $([[ "$INSTALL_NFC_WATCH" == "1" ]] && printf yes || printf no)

Files and settings:
  - Back up and rewrite ~/.zshrc
  - Back up and write $posh_theme_display
  - Configure Git core.precomposeunicode and core.quotepath
PLAN

  if [[ "$INSTALL_ROSETTA" == "1" ]]; then
    printf "  - Install Rosetta 2 on Apple Silicon when missing\n"
  fi
  if [[ "$INSTALL_NFC_TOOLS" == "1" ]]; then
    printf "  - Install ~/.local/bin/nfc-filenames\n"
  fi
  if [[ "$INSTALL_NFC_WATCH" == "1" ]]; then
    printf "  - Configure nfd2nfc watcher paths: %s\n" "$watch_paths_display"
  fi

  print_list "Homebrew formulae" "${selected_formulae[@]}"
  print_list "Homebrew casks" "${selected_casks[@]}"
  print_list "Global npm packages" "${selected_npm[@]}"
  print_list "VS Code extensions" "${selected_extensions[@]}"
}
