# Common helpers for install-dev-environment.sh. This file is sourced by the main installer.

# Recover from shells or path_helper runs that leave out macOS system paths.
repair_path() {
  export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin${PATH:+:$PATH}"
}

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
