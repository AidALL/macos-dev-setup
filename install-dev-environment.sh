#!/bin/zsh

if [ -z "${ZSH_VERSION:-}" ]; then
  if [ -n "${BASH_VERSION:-}" ] && [ "${BASH_SOURCE[0]:-}" != "$0" ]; then
    printf 'error: this installer should be executed, not sourced.\n' >&2
    printf 'try: ./install-dev-environment.sh --yes\n' >&2
    return 1 2>/dev/null || exit 1
  fi

  if [ -x /bin/zsh ]; then
    exec /bin/zsh "$0" "$@"
  fi

  printf 'error: this installer requires zsh, which is built into macOS.\n' >&2
  exit 1
fi

if [[ "${ZSH_EVAL_CONTEXT:-}" == *:file ]]; then
  printf 'error: this installer should be executed, not sourced.\n' >&2
  printf 'try: ./install-dev-environment.sh --yes\n' >&2
  return 1
fi

emulate -R zsh
set -euo pipefail

INSTALLER_DIR="${0:A:h}"

source "$INSTALLER_DIR/lib/common.zsh"
source "$INSTALLER_DIR/lib/nfc.zsh"
source "$INSTALLER_DIR/lib/installers.zsh"
source "$INSTALLER_DIR/lib/profiles.zsh"

repair_path

# One-shot installer for the macOS development setup created in this Codex session.
# Installs:
# - Homebrew, if missing
# - Rosetta 2 on Apple Silicon, if missing
# - Xcode Command Line Tools prompt, if missing
# - Profile flags: --all, --ai, --ios, --android/--and, --web, --sw, --minimal
# - Visual Studio Code, Google Chrome, Microsoft Edge, Docker, and core VS Code extensions
# - Optional AI coding CLIs: Codex, Claude Code, Gemini CLI
# - Latest Homebrew Python, uv, pipx
# - Node.js, pnpm, yarn
# - Git, GitHub CLI, Go, Rust, build tools
# - nfd2nfc, optional background watcher, Korean filename NFC helper, and Git Unicode settings
# - Modern terminal utilities
# - Oh My Zsh
# - Oh My Posh
# - MesloLGS NF
# - zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions
# - A pastel powerline-style Oh My Posh theme
# - ~/.zshrc with 50,000 zsh history entries

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/.zsh-setup-backups/$TIMESTAMP"
ZSH_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM_DIR="$ZSH_DIR/custom"
POSH_CONFIG_DIR="$HOME/.config/oh-my-posh"
POSH_THEME="$POSH_CONFIG_DIR/pastel-p10k.omp.json"

INSTALL_AI=0
INSTALL_WEB=0
INSTALL_SW=0
INSTALL_IOS=0
INSTALL_ANDROID=0
INSTALL_ROSETTA=1
INSTALL_NFC_TOOLS=1
INSTALL_NFC_WATCH=1
ROSETTA_CHOICE_SET=0
NFC_CHOICE_SET=0
INSTALL_MINIMAL=0
PROFILE_SELECTED=0
AUTO_YES=0
DRY_RUN=0
SELF_TEST_PATH_REPAIR=0
SELF_TEST_ZSHRC_TEMPLATE=0
SELF_TEST_NFD2NFC_PATH=0
SELF_TEST_NFD2NFC_PLIST=0
SELF_TEST_NFC_WATCH_PATHS=0

if [[ -n "${ROSETTA+x}" ]]; then
  ROSETTA_CHOICE_SET=1
  if [[ "$ROSETTA" == "0" ]]; then
    INSTALL_ROSETTA=0
  else
    INSTALL_ROSETTA=1
  fi
fi

if [[ -n "${NFC_NORMALIZATION+x}" ]]; then
  NFC_CHOICE_SET=1
  if [[ "$NFC_NORMALIZATION" == "0" ]]; then
    INSTALL_NFC_TOOLS=0
    INSTALL_NFC_WATCH=0
  else
    INSTALL_NFC_TOOLS=1
    INSTALL_NFC_WATCH=1
  fi
fi

if [[ "$INSTALL_NFC_TOOLS" == "1" && -n "${NFC_WATCH+x}" ]]; then
  NFC_CHOICE_SET=1
  if [[ "$NFC_WATCH" == "0" ]]; then
    INSTALL_NFC_WATCH=0
  else
    INSTALL_NFC_WATCH=1
  fi
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y | --yes | --default)
      AUTO_YES=1
      PROFILE_SELECTED=1
      ;;
    --all)
      enable_all_profiles
      PROFILE_SELECTED=1
      ;;
    --ai)
      INSTALL_AI=1
      PROFILE_SELECTED=1
      ;;
    --web)
      INSTALL_WEB=1
      PROFILE_SELECTED=1
      ;;
    --sw | --software)
      INSTALL_SW=1
      PROFILE_SELECTED=1
      ;;
    --ios)
      INSTALL_IOS=1
      PROFILE_SELECTED=1
      ;;
    --android | --and)
      INSTALL_ANDROID=1
      PROFILE_SELECTED=1
      ;;
    --nfc-watch)
      INSTALL_NFC_TOOLS=1
      INSTALL_NFC_WATCH=1
      NFC_CHOICE_SET=1
      ;;
    --no-nfc-watch)
      INSTALL_NFC_TOOLS=1
      INSTALL_NFC_WATCH=0
      NFC_CHOICE_SET=1
      ;;
    --no-nfc-normalization)
      INSTALL_NFC_TOOLS=0
      INSTALL_NFC_WATCH=0
      NFC_CHOICE_SET=1
      ;;
    --no-rosetta)
      INSTALL_ROSETTA=0
      ROSETTA_CHOICE_SET=1
      ;;
    --minimal)
      INSTALL_MINIMAL=1
      PROFILE_SELECTED=1
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    --self-test-path-repair)
      SELF_TEST_PATH_REPAIR=1
      ;;
    --self-test-zshrc-template)
      SELF_TEST_ZSHRC_TEMPLATE=1
      ;;
    --self-test-nfd2nfc-path)
      SELF_TEST_NFD2NFC_PATH=1
      ;;
    --self-test-nfd2nfc-plist)
      SELF_TEST_NFD2NFC_PLIST=1
      ;;
    --self-test-nfc-watch-paths)
      SELF_TEST_NFC_WATCH_PATHS=1
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "Unknown flag: $1"
      ;;
  esac
  shift
done

if [[ "$SELF_TEST_PATH_REPAIR" == "1" || "$SELF_TEST_ZSHRC_TEMPLATE" == "1" || "$SELF_TEST_NFD2NFC_PATH" == "1" || "$SELF_TEST_NFD2NFC_PLIST" == "1" || "$SELF_TEST_NFC_WATCH_PATHS" == "1" ]]; then
  source "$INSTALLER_DIR/tests/self-tests.zsh"
fi

if [[ "$SELF_TEST_PATH_REPAIR" == "1" ]]; then
  run_path_repair_self_test
  exit 0
fi

if [[ "$SELF_TEST_ZSHRC_TEMPLATE" == "1" ]]; then
  run_zshrc_template_self_test
  exit 0
fi

if [[ "$SELF_TEST_NFD2NFC_PATH" == "1" ]]; then
  run_nfd2nfc_path_self_test
  exit 0
fi

if [[ "$SELF_TEST_NFD2NFC_PLIST" == "1" ]]; then
  run_nfd2nfc_plist_self_test
  exit 0
fi

if [[ "$SELF_TEST_NFC_WATCH_PATHS" == "1" ]]; then
  run_nfc_watch_path_self_test
  exit 0
fi

if [[ "$PROFILE_SELECTED" == "0" ]]; then
  if [[ -t 0 && -t 1 ]]; then
    run_interactive_picker
  else
    warn "No interactive terminal detected; using default profiles. Pass flags to customize."
    enable_default_profiles
  fi
fi

if [[ "$AUTO_YES" == "1" ]]; then
  enable_default_profiles
fi

if [[ "$INSTALL_MINIMAL" == "1" && "$PROFILE_SELECTED" == "1" ]]; then
  disable_optional_profiles
fi

if [[ "$INSTALL_NFC_TOOLS" == "0" ]]; then
  INSTALL_NFC_WATCH=0
fi

if [[ "${INSTALL_HEAVY_APPS:-0}" == "1" ]]; then
  warn "INSTALL_HEAVY_APPS=1 is deprecated; enabling --web behavior for Postman compatibility."
  INSTALL_WEB=1
fi

if [[ "$DRY_RUN" != "1" ]]; then
  print_selection_summary
fi

if [[ "$DRY_RUN" == "1" ]]; then
  print_installation_plan
  exit 0
fi

if [[ -t 0 && -t 1 && "$AUTO_YES" == "0" ]]; then
  print_installation_plan
  if ! prompt_yes_no "Proceed with this installation?" "y"; then
    die "Canceled by user."
  fi
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  die "This installer is intended for macOS."
fi

if [[ "$INSTALL_ROSETTA" == "1" ]]; then
  ensure_rosetta
fi

ensure_xcode_cli_tools

if ! command -v brew >/dev/null 2>&1; then
  info "Homebrew not found; installing Homebrew"
  install_homebrew
fi

if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
repair_path

command -v brew >/dev/null 2>&1 || die "Homebrew is still not available on PATH."

info "Updating Homebrew metadata"
brew update

info "Installing core command-line tools"
for formula in "${CORE_FORMULAE[@]}"; do
  install_formula "$formula"
done

if [[ "$INSTALL_NFC_TOOLS" == "1" ]]; then
  info "Installing Korean filename normalization tools"
  for formula in "${NFC_FORMULAE[@]}"; do
    install_formula "$formula"
  done
fi

if [[ "$INSTALL_AI" == "1" ]]; then
  info "Installing AI CLI prerequisites"
  for formula in "${AI_FORMULAE[@]}"; do
    install_formula "$formula"
  done
fi

if [[ "$INSTALL_WEB" == "1" ]]; then
  info "Installing web development tools"
  for formula in "${WEB_FORMULAE[@]}"; do
    install_formula "$formula"
  done
fi

if [[ "$INSTALL_SW" == "1" ]]; then
  info "Installing general software development tools"
  for formula in "${SW_FORMULAE[@]}"; do
    install_formula "$formula"
  done
fi

if [[ "$INSTALL_IOS" == "1" ]]; then
  info "Installing iOS development helpers"
  for formula in "${IOS_FORMULAE[@]}"; do
    install_formula "$formula"
  done
fi

if [[ "$INSTALL_ANDROID" == "1" ]]; then
  info "Installing Android development helpers"
  for formula in "${ANDROID_FORMULAE[@]}"; do
    install_formula "$formula"
  done
fi

info "Installing core apps and fonts"
for cask in "${CORE_CASKS[@]}"; do
  install_cask "$cask"
done

if [[ "$INSTALL_WEB" == "1" ]]; then
  info "Installing web development apps"
  for cask in "${WEB_CASKS[@]}"; do
    install_cask "$cask"
  done
fi

if [[ "$INSTALL_IOS" == "1" ]]; then
  info "Installing iOS development apps"
  for cask in "${IOS_CASKS[@]}"; do
    install_cask "$cask"
  done
fi

if [[ "$INSTALL_ANDROID" == "1" ]]; then
  info "Installing Android development apps"
  for cask in "${ANDROID_CASKS[@]}"; do
    install_cask "$cask"
  done
fi
ensure_code_cli

if command -v pipx >/dev/null 2>&1; then
  ensure_pipx_path
fi

configure_git_unicode

if [[ "$INSTALL_NFC_TOOLS" == "1" ]]; then
  write_nfc_filename_tool

  if [[ "$INSTALL_NFC_WATCH" == "1" ]]; then
    configure_nfd2nfc_watcher
  fi
fi

if [[ "$INSTALL_AI" == "1" ]]; then
  if command -v npm >/dev/null 2>&1; then
    info "Installing AI coding CLIs"
    for package in "${AI_NPM_PACKAGES[@]}"; do
      install_npm_global "$package"
    done
  else
    warn "npm is not on PATH after installing Node; open a new terminal and rerun this script to install AI coding CLIs."
  fi
fi

if command -v code >/dev/null 2>&1; then
  info "Installing VS Code extensions"
  for extension in "${CORE_VSCODE_EXTENSIONS[@]}"; do
    install_vscode_extension "$extension"
  done
  if [[ "$INSTALL_WEB" == "1" ]]; then
    for extension in "${WEB_VSCODE_EXTENSIONS[@]}"; do
      install_vscode_extension "$extension"
    done
  fi
  if [[ "$INSTALL_SW" == "1" ]]; then
    for extension in "${SW_VSCODE_EXTENSIONS[@]}"; do
      install_vscode_extension "$extension"
    done
  fi
  if [[ "$INSTALL_IOS" == "1" ]]; then
    for extension in "${IOS_VSCODE_EXTENSIONS[@]}"; do
      install_vscode_extension "$extension"
    done
  fi
  if [[ "$INSTALL_ANDROID" == "1" ]]; then
    for extension in "${ANDROID_VSCODE_EXTENSIONS[@]}"; do
      install_vscode_extension "$extension"
    done
  fi
else
  warn "VS Code installed, but the code CLI is not on PATH in this shell yet. Open a new terminal and run this script again to install VS Code extensions."
fi

clone_or_update "https://github.com/ohmyzsh/ohmyzsh.git" "$ZSH_DIR"
repair_path
/bin/mkdir -p "$ZSH_CUSTOM_DIR/plugins"

clone_or_update "https://github.com/zsh-users/zsh-autosuggestions.git" "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
clone_or_update "https://github.com/zsh-users/zsh-syntax-highlighting.git" "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"
clone_or_update "https://github.com/zsh-users/zsh-completions.git" "$ZSH_CUSTOM_DIR/plugins/zsh-completions"

/bin/mkdir -p "$POSH_CONFIG_DIR"
backup_path "$POSH_THEME"

info "Writing Oh My Posh theme: $POSH_THEME"
cat > "$POSH_THEME" <<'JSON'
{
  "$schema": "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json",
  "palette": {
    "base": "#303446",
    "surface": "#414559",
    "text": "#C6D0F5",
    "lavender": "#BABBF1",
    "blue": "#8CAAEE",
    "sapphire": "#85C1DC",
    "green": "#A6D189",
    "yellow": "#E5C890",
    "peach": "#EF9F76",
    "red": "#E78284",
    "pink": "#F4B8E4"
  },
  "blocks": [
    {
      "alignment": "left",
      "segments": [
        {
          "background": "p:lavender",
          "foreground": "p:base",
          "leading_diamond": "\ue0b6",
          "style": "diamond",
          "template": " {{ .UserName }} ",
          "type": "session"
        },
        {
          "background": "p:blue",
          "foreground": "p:base",
          "powerline_symbol": "\ue0b0",
          "style": "powerline",
          "template": " {{ .Path }} ",
          "type": "path",
          "options": {
            "folder_icon": "",
            "home_icon": "~",
            "style": "agnoster_short"
          }
        },
        {
          "background": "p:green",
          "foreground": "p:base",
          "background_templates": [
            "{{ if or (.Working.Changed) (.Staging.Changed) }}p:yellow{{ end }}",
            "{{ if and (gt .Ahead 0) (gt .Behind 0) }}p:peach{{ end }}",
            "{{ if gt .Ahead 0 }}p:sapphire{{ end }}",
            "{{ if gt .Behind 0 }}p:peach{{ end }}"
          ],
          "leading_diamond": "\ue0b6",
          "powerline_symbol": "\ue0b0",
          "style": "powerline",
          "template": " {{ .HEAD }}{{ if .BranchStatus }} {{ .BranchStatus }}{{ end }}{{ if .Working.Changed }} *{{ .Working.String }}{{ end }}{{ if .Staging.Changed }} +{{ .Staging.String }}{{ end }}{{ if gt .StashCount 0 }} stash:{{ .StashCount }}{{ end }} ",
          "trailing_diamond": "\ue0b4",
          "type": "git",
          "options": {
            "branch_icon": "",
            "fetch_status": true,
            "fetch_upstream_icon": false
          }
        }
      ],
      "type": "prompt"
    },
    {
      "alignment": "right",
      "segments": [
        {
          "background": "p:surface",
          "foreground": "p:pink",
          "leading_diamond": "\ue0b6",
          "style": "diamond",
          "template": " {{ .CurrentDate | date .Format }} ",
          "trailing_diamond": "\ue0b4",
          "type": "time",
          "options": {
            "time_format": "15:04"
          }
        }
      ],
      "type": "prompt"
    },
    {
      "alignment": "left",
      "newline": true,
      "segments": [
        {
          "foreground": "p:green",
          "foreground_templates": [
            "{{ if gt .Code 0 }}p:red{{ end }}"
          ],
          "style": "plain",
          "template": "\u276f ",
          "type": "status",
          "options": {
            "always_enabled": true
          }
        }
      ],
      "type": "prompt"
    }
  ],
  "final_space": true,
  "version": 4
}
JSON

backup_path "$HOME/.zshrc"

info "Writing ~/.zshrc"
write_zshrc_config "$HOME/.zshrc"

info "Validating zsh config"
/bin/zsh -n "$HOME/.zshrc"

if command -v oh-my-posh >/dev/null 2>&1; then
  oh-my-posh print primary --config "$POSH_THEME" --shell zsh --plain >/dev/null
fi

cat <<'DONE'

Done.

Open a new terminal, or run:
  source ~/.zshrc

In your terminal app, choose one of these fonts if prompt symbols show as question marks:
  MesloLGS NF

Existing ~/.zshrc and theme files were backed up under:
  ~/.zsh-setup-backups/

AI CLI tools install as global npm packages and still require login/API setup when first used:
  codex
  claude
  gemini

Korean filename helper:
  nfc-filenames ~/Downloads
  nfc-filenames --apply ~/Downloads

Profiles:
  no flags      core + --ai + --web + --sw
  --minimal     core only
  --ai          add Codex, Claude Code, and Gemini CLI
  --web         add Node web tooling and Postman
  --sw          add Go, Rust, build tools, and shell linters
  --ios         add iOS helper tools
  --android     add Android Studio, platform-tools, Java, Gradle, Kotlin, Maven
  --all         add every profile
DONE
