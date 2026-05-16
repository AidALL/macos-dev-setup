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

# Recover from shells or path_helper runs that leave out macOS system paths.
repair_path() {
  export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin${PATH:+:$PATH}"
}

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

info() {
  printf '\033[1;34m==>\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2
}

die() {
  printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage:
  ./install-dev-environment.sh [flags]

Default with no flags:
  interactive picker when running in a terminal
  core + --ai + --web + --sw + Rosetta + nfd2nfc watcher when input is not interactive

Flags:
  -y, --yes      Non-interactive default: core + ai + web + sw + Rosetta + nfd2nfc watcher
  --default      Alias for --yes
  --all          Install every profile: ai, web, sw, ios, android
  --ai           Install AI coding CLIs: codex, claude, gemini
  --web          Install web stack: Node, pnpm, yarn, httpie, watchman, Postman
  --sw           Install general software stack: Go, Rust, C/C++ build tools, shell linters
  --ios          Install iOS helpers: CocoaPods, SwiftLint, SwiftFormat, XcodeGen, xcbeautify, xcodes, Tuist
  --android      Install Android helpers: Android Studio, platform-tools, Java, Gradle, Kotlin, Maven
  --and          Alias for --android
  --no-nfc-normalization
                 Skip nfd2nfc installation and background watcher
  --no-nfc-watch Install nfd2nfc helper, but skip the background watcher
  --no-rosetta   Skip Rosetta 2 installation on Apple Silicon
  --minimal      Install only core apps, shell, Python, Git, browsers, Docker, and terminal utilities
  --dry-run      Print the selected installation plan without installing
  -h, --help     Show this help

Environment:
  ROSETTA=0          Skip Rosetta 2 installation on Apple Silicon
  NFC_NORMALIZATION=0 Skip nfd2nfc installation and background watcher
  NFC_WATCH=0       Skip the nfd2nfc background watcher in non-interactive runs
  NFC_WATCH_PATHS   Override watcher paths; defaults to Desktop, Documents, Downloads, and detected cloud folders
  NFC_EXTRA_WATCH_PATHS Append extra colon-separated watcher paths to the defaults

Examples:
  ./install-dev-environment.sh
  ./install-dev-environment.sh --yes
  ./install-dev-environment.sh --all
  ./install-dev-environment.sh --dry-run
  ./install-dev-environment.sh --web --ai
  ./install-dev-environment.sh --ios
  ./install-dev-environment.sh --and
  NFC_EXTRA_WATCH_PATHS="$HOME/Work" ./install-dev-environment.sh --yes
USAGE
}

expand_tilde_path() {
  local raw="$1"
  case "$raw" in
    "~")
      printf '%s' "$HOME"
      ;;
    "~/"*)
      printf '%s/%s' "$HOME" "${raw#"~/"}"
      ;;
    *)
      printf '%s' "$raw"
      ;;
  esac
}

home_relative_path() {
  local raw="$1"
  case "$raw" in
    "$HOME")
      printf '~'
      ;;
    "$HOME"/*)
      printf '~/%s' "${raw#"$HOME/"}"
      ;;
    *)
      printf '%s' "$raw"
      ;;
  esac
}

home_relative_path_list() {
  local raw="$1"
  local -a parts
  local part
  local expanded
  local output=""

  parts=("${(@s/:/)raw}")
  for part in "${parts[@]}"; do
    [[ -n "$part" ]] || continue
    expanded="$(expand_tilde_path "$part")"
    if [[ -n "$output" ]]; then
      output="$output:"
    fi
    output="$output$(home_relative_path "$expanded")"
  done

  printf '%s' "$output"
}

append_existing_watch_path() {
  local candidate="$1"
  local expanded
  local canonical
  local existing

  expanded="$(expand_tilde_path "$candidate")"
  [[ -d "$expanded" ]] || return 0
  canonical="$(/bin/realpath "$expanded" 2>/dev/null || printf '%s' "$expanded")"

  for existing in "${NFC_DEFAULT_WATCH_PATHS[@]}"; do
    [[ "$existing" == "$canonical" ]] && return 0
  done

  NFC_DEFAULT_WATCH_PATHS+=("$canonical")
}

join_colon_paths() {
  local -a paths=("$@")
  local old_ifs="$IFS"

  IFS=':'
  printf '%s' "${paths[*]}"
  IFS="$old_ifs"
}

default_nfc_watch_paths() {
  local -a NFC_DEFAULT_WATCH_PATHS
  local candidate

  NFC_DEFAULT_WATCH_PATHS=()

  append_existing_watch_path "$HOME/Desktop"
  append_existing_watch_path "$HOME/Documents"
  append_existing_watch_path "$HOME/Downloads"

  for candidate in "$HOME/Library/CloudStorage"/*(N-/); do
    append_existing_watch_path "$candidate"
  done

  append_existing_watch_path "$HOME/Library/Mobile Documents/com~apple~CloudDocs"

  for candidate in \
    "$HOME"/Google\ Drive*(N-/) \
    "$HOME"/OneDrive*(N-/) \
    "$HOME"/Dropbox*(N-/) \
    "$HOME"/Box*(N-/) \
    "$HOME"/Creative\ Cloud\ Files*(N-/) \
    "$HOME"/Adobe\ Creative\ Cloud\ Files*(N-/) \
    "$HOME"/Nextcloud*(N-/) \
    "$HOME"/ownCloud*(N-/) \
    "$HOME"/pCloud*(N-/) \
    "$HOME"/MEGA*(N-/) \
    "$HOME"/MegaSync*(N-/) \
    "$HOME"/Resilio\ Sync*(N-/) \
    "$HOME"/Seafile*(N-/) \
    "$HOME"/SynologyDrive*(N-/) \
    "$HOME"/Synology\ Drive*(N-/); do
    append_existing_watch_path "$candidate"
  done

  join_colon_paths "${NFC_DEFAULT_WATCH_PATHS[@]}"
}

resolve_nfc_watch_paths() {
  local paths_raw

  if [[ -n "${NFC_WATCH_PATHS:-}" ]]; then
    paths_raw="$NFC_WATCH_PATHS"
  else
    paths_raw="$(default_nfc_watch_paths)"
  fi

  if [[ -n "${NFC_EXTRA_WATCH_PATHS:-}" ]]; then
    if [[ -n "$paths_raw" ]]; then
      paths_raw="$paths_raw:$NFC_EXTRA_WATCH_PATHS"
    else
      paths_raw="$NFC_EXTRA_WATCH_PATHS"
    fi
  fi

  printf '%s' "$paths_raw"
}

backup_path() {
  repair_path

  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    /bin/mkdir -p "$BACKUP_DIR"
    local name
    name="$(/usr/bin/basename "$path")"
    /bin/cp -R "$path" "$BACKUP_DIR/$name"
    info "Backed up $path to $BACKUP_DIR/$name"
  fi
}

clone_or_update() {
  local repo="$1"
  local dest="$2"

  if [[ -d "$dest/.git" ]]; then
    info "Updating $(/usr/bin/basename "$dest")"
    git -C "$dest" pull --ff-only || warn "Could not fast-forward $dest; leaving it as-is."
    return
  fi

  if [[ -e "$dest" ]]; then
    repair_path
    /bin/mkdir -p "$BACKUP_DIR"
    local moved
    moved="$BACKUP_DIR/$(/usr/bin/basename "$dest")"
    warn "$dest already exists but is not a git checkout; moving it to $moved"
    /bin/mv "$dest" "$moved"
  fi

  info "Cloning $(/usr/bin/basename "$dest")"
  git clone --depth=1 "$repo" "$dest"
}

run_path_repair_self_test() {
  local temp_dir
  local test_file

  temp_dir="$(/usr/bin/mktemp -d)"
  test_file="$temp_dir/nfc-filenames"
  BACKUP_DIR="$temp_dir/backups"

  : > "$test_file"
  PATH="/opt/homebrew/bin"
  backup_path "$test_file"

  [[ -f "$BACKUP_DIR/nfc-filenames" ]] || die "PATH repair self-test failed."
  /bin/rm -rf "$temp_dir"
}

write_zshrc_config() {
  local target="$1"
  local temp_file

  repair_path
  temp_file="$(/usr/bin/mktemp "${TMPDIR:-/tmp}/macos-dev-zshrc.XXXXXX")"

  cat > "$temp_file" <<'ZSHRC'
# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Oh My Posh handles the prompt, so keep the Oh My Zsh theme disabled.
ZSH_THEME=""

# Make Homebrew tools available on Apple Silicon Macs.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Make Homebrew Python's unversioned python/pip commands available.
if [[ -n "${HOMEBREW_PREFIX:-}" && -d "$HOMEBREW_PREFIX/opt/python/libexec/bin" ]]; then
  export PATH="$HOMEBREW_PREFIX/opt/python/libexec/bin:$PATH"
fi

# User-level Python tools installed by pipx live here.
export PATH="$HOME/.local/bin:$PATH"

# Java and Android SDK paths are enabled when those tools exist.
if [[ -n "${HOMEBREW_PREFIX:-}" && -d "$HOMEBREW_PREFIX/opt/openjdk@21" ]]; then
  export JAVA_HOME="$HOMEBREW_PREFIX/opt/openjdk@21"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

if [[ -d "$HOME/Library/Android/sdk" ]]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
  export ANDROID_SDK_ROOT="$ANDROID_HOME"
  export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
fi

if command -v code >/dev/null 2>&1; then
  export EDITOR="code --wait"
else
  export EDITOR="vim"
fi

# Keep more zsh history.
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt APPEND_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY

# Extra completions must be available before Oh My Zsh runs compinit.
if [[ -d "$ZSH/custom/plugins/zsh-completions/src" ]]; then
  fpath=("$ZSH/custom/plugins/zsh-completions/src" $fpath)
fi

# Which plugins would you like to load?
plugins=(
  git
  brew
  macos
  colored-man-pages
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

# Modern CLI integrations.
if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

if command -v uv >/dev/null 2>&1; then
  eval "$(uv generate-shell-completion zsh)"
fi

if command -v eza >/dev/null 2>&1; then
  alias ls="eza --group-directories-first"
  alias ll="eza -lah --git --group-directories-first"
  alias la="eza -la --group-directories-first"
fi

# Oh My Posh prompt.
if command -v oh-my-posh >/dev/null 2>&1; then
  eval "$(oh-my-posh init zsh --config "$HOME/.config/oh-my-posh/pastel-p10k.omp.json")"
fi
ZSHRC

  if ! /bin/zsh -n "$temp_file"; then
    /bin/rm -f "$temp_file"
    die "Generated zsh config is invalid; leaving $target unchanged."
  fi

  /bin/mv "$temp_file" "$target"
}

run_zshrc_template_self_test() {
  local temp_dir

  temp_dir="$(/usr/bin/mktemp -d)"
  write_zshrc_config "$temp_dir/.zshrc"
  /bin/zsh -n "$temp_dir/.zshrc"
  /bin/rm -rf "$temp_dir"
}

run_nfd2nfc_path_self_test() {
  local temp_dir
  local found
  local watcher_found

  temp_dir="$(/usr/bin/mktemp -d)"
  /bin/mkdir -p "$temp_dir/bin"
  : > "$temp_dir/bin/nfd2nfc"
  : > "$temp_dir/bin/nfd2nfc-watcher"
  /bin/chmod +x "$temp_dir/bin/nfd2nfc"
  /bin/chmod +x "$temp_dir/bin/nfd2nfc-watcher"

  PATH="$temp_dir/bin"
  found="$(find_nfd2nfc)" || die "nfd2nfc path self-test failed."
  watcher_found="$(find_nfd2nfc_watcher)" || die "nfd2nfc-watcher path self-test failed."
  [[ -x "$found" ]] || die "nfd2nfc path self-test returned a non-executable path: $found"
  [[ -x "$watcher_found" ]] || die "nfd2nfc-watcher path self-test returned a non-executable path: $watcher_found"

  /bin/rm -rf "$temp_dir"
}

run_nfd2nfc_plist_self_test() {
  local temp_dir
  local plist
  local old_path="$PATH"

  temp_dir="$(/usr/bin/mktemp -d)"
  plist="$temp_dir/io.github.elgar328.nfd2nfc.plist"

  PATH="/opt/homebrew/bin"
  write_nfd2nfc_launch_agent_plist "$plist" "/opt/homebrew/bin/nfd2nfc-watcher" "io.github.elgar328.nfd2nfc"
  PATH="$old_path"

  [[ -s "$plist" ]] || die "nfd2nfc plist self-test produced an empty plist."
  /usr/bin/grep -q "/opt/homebrew/bin/nfd2nfc-watcher" "$plist" || die "nfd2nfc plist self-test did not write the watcher path."
  /bin/rm -rf "$temp_dir"
}

assert_path_list_contains() {
  local list="$1"
  local path="$2"

  [[ ":$list:" == *":$path:"* ]] || die "Expected watch path is missing: $path"
}

run_nfc_watch_path_self_test() {
  local temp_home
  local old_home="$HOME"
  local old_watch_paths="${NFC_WATCH_PATHS-}"
  local old_watch_paths_set="${NFC_WATCH_PATHS+x}"
  local old_extra_paths="${NFC_EXTRA_WATCH_PATHS-}"
  local old_extra_paths_set="${NFC_EXTRA_WATCH_PATHS+x}"
  local paths_raw
  local google_drive_target

  temp_home="$(/usr/bin/mktemp -d)"
  HOME="$temp_home"
  unset NFC_WATCH_PATHS
  unset NFC_EXTRA_WATCH_PATHS

  /bin/mkdir -p \
    "$HOME/Desktop" \
    "$HOME/Documents" \
    "$HOME/Downloads" \
    "$HOME/Library/CloudStorage/GoogleDrive-person@example.com" \
    "$HOME/Library/CloudStorage/OneDrive-AidALL" \
    "$HOME/Library/Mobile Documents/com~apple~CloudDocs" \
    "$HOME/Dropbox" \
    "$HOME/Synology Drive" \
    "$HOME/MEGA" \
    "$HOME/ownCloud" \
    "$HOME/pCloud Drive" \
    "$HOME/Resilio Sync" \
    "$HOME/Seafile" \
    "$HOME/Custom Cloud"
  /bin/ln -s "$HOME/Library/CloudStorage/GoogleDrive-person@example.com" "$HOME/Google Drive"

  paths_raw="$(resolve_nfc_watch_paths)"
  assert_path_list_contains "$paths_raw" "$(/bin/realpath "$HOME/Desktop")"
  assert_path_list_contains "$paths_raw" "$(/bin/realpath "$HOME/Documents")"
  assert_path_list_contains "$paths_raw" "$(/bin/realpath "$HOME/Downloads")"
  assert_path_list_contains "$paths_raw" "$(/bin/realpath "$HOME/Library/CloudStorage/GoogleDrive-person@example.com")"
  assert_path_list_contains "$paths_raw" "$(/bin/realpath "$HOME/Library/CloudStorage/OneDrive-AidALL")"
  assert_path_list_contains "$paths_raw" "$(/bin/realpath "$HOME/Library/Mobile Documents/com~apple~CloudDocs")"
  assert_path_list_contains "$paths_raw" "$(/bin/realpath "$HOME/Dropbox")"
  assert_path_list_contains "$paths_raw" "$(/bin/realpath "$HOME/Synology Drive")"
  assert_path_list_contains "$paths_raw" "$(/bin/realpath "$HOME/MEGA")"
  assert_path_list_contains "$paths_raw" "$(/bin/realpath "$HOME/ownCloud")"
  assert_path_list_contains "$paths_raw" "$(/bin/realpath "$HOME/pCloud Drive")"
  assert_path_list_contains "$paths_raw" "$(/bin/realpath "$HOME/Resilio Sync")"
  assert_path_list_contains "$paths_raw" "$(/bin/realpath "$HOME/Seafile")"
  google_drive_target="$(/bin/realpath "$HOME/Library/CloudStorage/GoogleDrive-person@example.com")"
  [[ "$(printf '%s' "$paths_raw" | /usr/bin/grep -o "$google_drive_target" | /usr/bin/wc -l | /usr/bin/tr -d ' ')" == "1" ]] \
    || die "Google Drive symlink and CloudStorage target should not be added twice."

  NFC_EXTRA_WATCH_PATHS="$HOME/Custom Cloud"
  paths_raw="$(resolve_nfc_watch_paths)"
  assert_path_list_contains "$paths_raw" "$HOME/Custom Cloud"

  NFC_WATCH_PATHS="$HOME/Downloads"
  unset NFC_EXTRA_WATCH_PATHS
  paths_raw="$(resolve_nfc_watch_paths)"
  [[ "$paths_raw" == "$HOME/Downloads" ]] || die "NFC_WATCH_PATHS should override default watch paths."

  HOME="$old_home"
  if [[ -n "$old_watch_paths_set" ]]; then
    NFC_WATCH_PATHS="$old_watch_paths"
  else
    unset NFC_WATCH_PATHS
  fi
  if [[ -n "$old_extra_paths_set" ]]; then
    NFC_EXTRA_WATCH_PATHS="$old_extra_paths"
  else
    unset NFC_EXTRA_WATCH_PATHS
  fi
  /bin/rm -rf "$temp_home"
}

install_formula() {
  local formula="$1"
  if brew list --formula "$formula" >/dev/null 2>&1; then
    info "$formula is already installed"
  else
    brew install "$formula"
  fi
}

install_cask() {
  local cask="$1"
  if brew list --cask "$cask" >/dev/null 2>&1; then
    info "$cask is already installed"
  else
    brew install --cask "$cask"
  fi
}

install_npm_global() {
  local package="$1"
  if ! command -v npm >/dev/null 2>&1; then
    warn "npm is not available yet; skipping $package"
    return
  fi

  if npm list -g --depth=0 "$package" >/dev/null 2>&1; then
    info "$package is already installed globally"
  else
    npm install -g "$package" || warn "Could not install global npm package $package"
  fi
}

path_contains() {
  local needle="$1"
  [[ ":$PATH:" == *":$needle:"* ]]
}

ensure_pipx_path() {
  local pipx_bin_dir="$HOME/.local/bin"

  if path_contains "$pipx_bin_dir"; then
    info "pipx app path is already on PATH"
    return
  fi

  info "Ensuring pipx app path exists"
  pipx ensurepath || true
  repair_path
}

install_vscode_extension() {
  local extension="$1"
  local installed_extensions

  if ! command -v code >/dev/null 2>&1; then
    warn "VS Code CLI is not available yet; skipping extension $extension"
    return
  fi

  installed_extensions="$(code --list-extensions 2>/dev/null || true)"
  if [[ $'\n'"$installed_extensions"$'\n' == *$'\n'"$extension"$'\n'* ]]; then
    info "VS Code extension $extension is already installed"
  else
    code --install-extension "$extension" || warn "Could not install VS Code extension $extension"
  fi
}

ensure_code_cli() {
  if command -v code >/dev/null 2>&1; then
    return
  fi

  local code_bin="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  if [[ -x "$code_bin" && -n "${HOMEBREW_PREFIX:-}" && -d "$HOMEBREW_PREFIX/bin" ]]; then
    ln -sf "$code_bin" "$HOMEBREW_PREFIX/bin/code" 2>/dev/null || true
    export PATH="$HOMEBREW_PREFIX/bin:$PATH"
  fi
}

ensure_rosetta() {
  if [[ "$(uname -m)" != "arm64" ]]; then
    info "Rosetta 2 is only needed on Apple Silicon; skipping"
    return
  fi

  if pkgutil --pkg-info com.apple.pkg.RosettaUpdateAuto >/dev/null 2>&1; then
    info "Rosetta 2 is already installed"
    return
  fi

  info "Installing Rosetta 2 for x86_64/amd64 compatibility"
  softwareupdate --install-rosetta --agree-to-license
}

install_homebrew() {
  local installer_url="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
  if [[ -t 0 ]]; then
    /bin/bash -c "$(curl -fsSL "$installer_url")"
  else
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL "$installer_url")"
  fi
}

ensure_xcode_cli_tools() {
  if xcode-select -p >/dev/null 2>&1; then
    info "Xcode Command Line Tools are already installed"
    return
  fi

  warn "Xcode Command Line Tools are missing. Starting Apple's installer."
  xcode-select --install >/dev/null 2>&1 || true
  warn "If a system installer opened, finish it and rerun this script if any Homebrew package fails."
}

configure_git_unicode() {
  if ! command -v git >/dev/null 2>&1; then
    return
  fi

  info "Configuring Git Unicode filename behavior"
  git config --global core.precomposeunicode true
  git config --global core.quotepath false
}

find_nfd2nfc() {
  local candidate

  repair_path
  if command -v nfd2nfc >/dev/null 2>&1; then
    command -v nfd2nfc
    return 0
  fi

  for candidate in /opt/homebrew/bin/nfd2nfc /usr/local/bin/nfd2nfc; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

find_nfd2nfc_watcher() {
  local candidate

  repair_path
  if command -v nfd2nfc-watcher >/dev/null 2>&1; then
    command -v nfd2nfc-watcher
    return 0
  fi

  for candidate in /opt/homebrew/bin/nfd2nfc-watcher /usr/local/bin/nfd2nfc-watcher; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

find_jq() {
  local candidate

  repair_path
  if command -v jq >/dev/null 2>&1; then
    command -v jq
    return 0
  fi

  for candidate in /opt/homebrew/bin/jq /usr/local/bin/jq /usr/bin/jq; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

remove_redundant_nfd2nfc_config() {
  local nfd2nfc_bin="$1"
  local jq_bin="$2"
  local existing_json
  local index
  local -a redundant_indices

  [[ -n "$jq_bin" ]] || return 0

  existing_json="$("$nfd2nfc_bin" config list --json 2>/dev/null || printf '[]')"
  redundant_indices=("${(@f)$("$jq_bin" -r '.[] | select(.status == "redundant") | .index' <<< "$existing_json" | /usr/bin/sort -rn)}")

  for index in "${redundant_indices[@]}"; do
    [[ -n "$index" ]] || continue
    "$nfd2nfc_bin" config remove "$index" >/dev/null 2>&1 || warn "Could not remove redundant nfd2nfc config index: $index"
  done
}

write_nfd2nfc_launch_agent_plist() {
  local plist="$1"
  local watcher_bin="$2"
  local service="$3"

  /bin/mkdir -p "$(/usr/bin/dirname "$plist")"
  /bin/cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$service</string>
  <key>ProgramArguments</key>
  <array>
    <string>$watcher_bin</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <dict>
    <key>Crashed</key>
    <true/>
  </dict>
</dict>
</plist>
PLIST

  [[ -s "$plist" ]] || die "Generated nfd2nfc LaunchAgent plist is empty: $plist"

  if [[ -x /usr/bin/plutil ]]; then
    /usr/bin/plutil -lint "$plist" >/dev/null
  fi
}

start_nfd2nfc_watcher() {
  local watcher_bin
  local plist
  local domain
  local service="io.github.elgar328.nfd2nfc"
  local service_state
  local bootstrap_output

  if ! watcher_bin="$(find_nfd2nfc_watcher)"; then
    warn "Could not find nfd2nfc-watcher binary; watcher was not started."
    return 1
  fi

  plist="$HOME/Library/LaunchAgents/$service.plist"
  domain="gui/$(/usr/bin/id -u)"
  write_nfd2nfc_launch_agent_plist "$plist" "$watcher_bin" "$service"

  service_state="$(/bin/launchctl print "$domain/$service" 2>/dev/null || true)"
  if [[ "$service_state" == *"state = running"* && "$service_state" == *"program = $watcher_bin"* ]]; then
    info "nfd2nfc watcher is already running"
    return 0
  fi

  if [[ -z "$service_state" ]]; then
    bootstrap_output="$(/bin/launchctl bootstrap "$domain" "$plist" 2>&1)" || {
      warn "$bootstrap_output"
      return 1
    }
  fi

  /bin/launchctl enable "$domain/$service" >/dev/null 2>&1 || true
  /bin/launchctl kickstart -k "$domain/$service" >/dev/null 2>&1 || true

  service_state="$(/bin/launchctl print "$domain/$service" 2>/dev/null || true)"
  if [[ "$service_state" == *"state = running"* ]]; then
    info "nfd2nfc watcher is running"
    return 0
  fi

  info "nfd2nfc watcher LaunchAgent is installed; macOS may report running state after a short delay"
}

configure_nfd2nfc_watcher() {
  local nfd2nfc_bin
  local jq_bin=""

  if ! nfd2nfc_bin="$(find_nfd2nfc)"; then
    warn "nfd2nfc is not available; skipping background filename watcher."
    return
  fi

  if jq_bin="$(find_jq)"; then
    :
  else
    jq_bin=""
    warn "jq is not available; skipping nfd2nfc watcher config duplicate checks."
  fi

  info "Configuring nfd2nfc background watcher"

  local paths_raw
  local path
  local expanded
  local display_path
  local existing_json
  local -a nfc_watch_path_array
  paths_raw="$(resolve_nfc_watch_paths)"
  nfc_watch_path_array=("${(@s/:/)paths_raw}")

  remove_redundant_nfd2nfc_config "$nfd2nfc_bin" "$jq_bin"
  existing_json="$("$nfd2nfc_bin" config list --json 2>/dev/null || printf '[]')"

  for path in "${nfc_watch_path_array[@]}"; do
    [[ -n "$path" ]] || continue
    expanded="$(expand_tilde_path "$path")"
    if [[ ! -d "$expanded" ]]; then
      warn "nfd2nfc watch path does not exist; skipping: $expanded"
      continue
    fi

    display_path="$(home_relative_path "$expanded")"
    if [[ -n "$jq_bin" ]] \
      && printf '%s' "$existing_json" | "$jq_bin" -e --arg path "$expanded" --arg display "$display_path" '.[] | select(.path == $path or .path == $display)' >/dev/null; then
      info "nfd2nfc already watches $display_path"
      continue
    fi

    "$nfd2nfc_bin" config add "$expanded" --action watch --mode recursive || warn "Could not add nfd2nfc watch path: $expanded"
    existing_json="$("$nfd2nfc_bin" config list --json 2>/dev/null || printf '[]')"
  done

  remove_redundant_nfd2nfc_config "$nfd2nfc_bin" "$jq_bin"
  start_nfd2nfc_watcher || warn "Could not start nfd2nfc watcher."

  info "If macOS asks for permissions, grant Full Disk Access to the nfd2nfc-watcher binary shown by: command -v nfd2nfc-watcher"
}

write_nfc_filename_tool() {
  local tool_dir="$HOME/.local/bin"
  local tool_path="$tool_dir/nfc-filenames"

  repair_path
  /bin/mkdir -p "$tool_dir"
  backup_path "$tool_path"

  info "Writing Korean filename normalization helper: $tool_path"
  cat > "$tool_path" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  nfc-filenames [--apply] [--no-recursive] [path ...]

Default is a dry run over the current directory. When nfd2nfc is installed,
this command delegates to it; otherwise it falls back to Python's Unicode NFC
normalizer.
USAGE
}

APPLY=0
RECURSIVE=1
PATHS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      APPLY=1
      ;;
    --no-recursive)
      RECURSIVE=0
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      PATHS+=("$1")
      ;;
  esac
  shift
done

if [[ "${#PATHS[@]}" -eq 0 ]]; then
  PATHS=(".")
fi

run_nfd2nfc() {
  local path
  local mode
  for path in "$@"; do
    if [[ -d "$path" ]]; then
      if [[ "$RECURSIVE" == "1" ]]; then
        mode="recursive"
      else
        mode="children"
      fi
    else
      mode="name"
    fi

    if [[ "$APPLY" == "1" ]]; then
      nfd2nfc convert "$path" --mode "$mode" --target nfc
    else
      nfd2nfc convert "$path" --mode "$mode" --target nfc --dry-run
    fi
  done
}

if command -v nfd2nfc >/dev/null 2>&1; then
  run_nfd2nfc "${PATHS[@]}"
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  printf 'error: nfd2nfc and python3 are both missing\n' >&2
  exit 1
fi

printf 'warning: nfd2nfc not found; using Python fallback\n' >&2
python3 - "$APPLY" "$RECURSIVE" "${PATHS[@]}" <<'PY'
import os
import sys
import unicodedata


apply = sys.argv[1] == "1"
recursive = sys.argv[2] == "1"
paths = sys.argv[3:] or ["."]


def iter_paths(root):
    root = os.path.abspath(root)
    if not os.path.exists(root):
        print(f"missing: {root}", file=sys.stderr)
        return
    if os.path.isfile(root) or os.path.islink(root):
        yield root
        return
    if recursive:
        for current, dirs, files in os.walk(root, topdown=False):
            for name in files:
                yield os.path.join(current, name)
            for name in dirs:
                yield os.path.join(current, name)
    else:
        for name in os.listdir(root):
            yield os.path.join(root, name)


def normalized_target(path):
    parent = os.path.dirname(path)
    name = os.path.basename(path)
    normalized = unicodedata.normalize("NFC", name)
    if name == normalized:
        return None
    return os.path.join(parent, normalized)


planned = []
for root in paths:
    for path in iter_paths(root):
        target = normalized_target(path)
        if target is not None:
            planned.append((path, target))

if not planned:
    print("No files need conversion.")
    raise SystemExit(0)

skipped = 0
for src, dst in planned:
    if os.path.exists(dst):
        try:
            same_file = os.path.samefile(src, dst)
        except OSError:
            same_file = False
        if not same_file:
            print(f"skip collision: {src} -> {dst}", file=sys.stderr)
            skipped += 1
            continue

    if apply:
        os.rename(src, dst)
        print(f"renamed: {src} -> {dst}")
    else:
        print(f"would rename: {src} -> {dst}")

if not apply:
    print("\nDry run only. Re-run with --apply to rename.")

raise SystemExit(2 if skipped else 0)
PY
SH
  /bin/chmod +x "$tool_path"
}

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
