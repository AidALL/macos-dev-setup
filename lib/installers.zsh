# Package and system installer helpers for install-dev-environment.sh.

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
