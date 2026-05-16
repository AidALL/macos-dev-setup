# NFC filename normalization helpers for install-dev-environment.sh.

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
