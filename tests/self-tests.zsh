# Self-tests for install-dev-environment.sh. This file is sourced only for --self-test-* flags.

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
