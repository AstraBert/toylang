#!/bin/sh
# Installs toylang from a GitHub release.
#
#   curl -fsSL https://raw.githubusercontent.com/AstraBert/toylang/main/install.sh | sh
#   curl -fsSL .../install.sh | sh -s -- --version 0.1.0
#   curl -fsSL .../install.sh | sh -s -- --uninstall
#
# It downloads the package for this OS and CPU, checks its SHA-256, unpacks it
# into ~/.toylang and puts a small launcher called `toylang` in ~/.local/bin.
# It does NOT install the tools toylang needs: qbe, cc and Erlang (escript).

set -eu

# ---- settings (override with environment variables) ----
REPO="${TOYLANG_REPO:-AstraBert/toylang}"            # <-- set to your GitHub user/repository
TOYLANG_HOME="${TOYLANG_HOME:-$HOME/.toylang}"
BIN_DIR="${TOYLANG_BIN_DIR:-$HOME/.local/bin}"
VERSION="${TOYLANG_VERSION:-latest}"
BASE_URL="${TOYLANG_BASE_URL:-}"                  # only for mirrors and testing

MARKER="# installed by the toylang install script"

# ---- helpers ----
say()  { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

usage() {
  cat <<USAGE
Usage: install.sh [options]

  -v, --version VERSION   install a specific version (default: the latest release)
      --uninstall         remove toylang
  -h, --help              show this help

Environment variables:
  TOYLANG_HOME      where the package is unpacked   (default: ~/.toylang)
  TOYLANG_BIN_DIR   where the launcher is placed    (default: ~/.local/bin)
  TOYLANG_REPO      GitHub repository to download from
USAGE
}

detect_os() {
  case "$(uname -s)" in
    Linux)  echo linux ;;
    Darwin) echo macos ;;
    *) die "unsupported operating system: $(uname -s) (supported: Linux and macOS)" ;;
  esac
}

detect_arch() {
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64)  arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) die "unsupported CPU architecture: $arch (supported: amd64 and arm64)" ;;
  esac
  # A shell running under Rosetta on an Apple Silicon Mac reports x86_64.
  if [ "$(uname -s)" = Darwin ] && [ "$arch" = amd64 ] &&
     [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" = 1 ]; then
    arch=arm64
  fi
  echo "$arch"
}

resolve_tag() {
  if [ "$VERSION" = latest ]; then
    url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest")" ||
      die "could not find the latest release of $REPO (check the repository name, your connection, and that a release exists)"
    tag="${url##*/}"
    case "$tag" in
      v*) ;;
      *) die "no release found for $REPO" ;;
    esac
  else
    tag="v${VERSION#v}"
  fi
  echo "$tag"
}

sha256_of() {
  if have sha256sum; then
    sha256sum "$1" | cut -d' ' -f1
  elif have shasum; then
    shasum -a 256 "$1" | cut -d' ' -f1
  else
    die "need sha256sum or shasum to verify the download"
  fi
}

uninstall() {
  if [ -f "$BIN_DIR/toylang" ] && grep -q "$MARKER" "$BIN_DIR/toylang" 2>/dev/null; then
    rm -f "$BIN_DIR/toylang"
  fi
  rm -rf "$TOYLANG_HOME"
  say "toylang has been removed."
}

check_tools() {
  missing=""
  for tool in qbe cc escript; do
    have "$tool" || missing="$missing $tool"
  done
  if [ -n "$missing" ]; then
    warn "toylang needs these tools, which were not found on your PATH:$missing"
    case "$1" in
      macos)
        say "  macOS:  xcode-select --install   (provides cc)"
        say "          brew install qbe erlang" ;;
      *)
        say "  Debian/Ubuntu:  sudo apt install qbe erlang gcc"
        say "  Other distributions: use your package manager, or build qbe from https://c9x.me/compile/" ;;
    esac
  fi
}

install() {
  have curl || die "curl is required"
  have tar  || die "tar is required"

  os="$(detect_os)"
  arch="$(detect_arch)"
  tag="$(resolve_tag)"
  name="toylang-${tag#v}-${os}-${arch}"
  base="${BASE_URL:-https://github.com/$REPO/releases/download/$tag}"

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT INT TERM

  say "Installing toylang $tag for $os-$arch"
  curl -fSL --progress-bar -o "$tmp/$name.tar.gz" "$base/$name.tar.gz" ||
    die "download failed: $base/$name.tar.gz (is there a package for $os-$arch in release $tag?)"
  curl -fsSL -o "$tmp/$name.tar.gz.sha256" "$base/$name.tar.gz.sha256" ||
    die "could not download the checksum file"

  expected="$(cut -d' ' -f1 "$tmp/$name.tar.gz.sha256")"
  actual="$(sha256_of "$tmp/$name.tar.gz")"
  [ "$expected" = "$actual" ] ||
    die "checksum mismatch (expected $expected, got $actual); nothing was installed"

  tar -xzf "$tmp/$name.tar.gz" -C "$tmp"
  for f in toylang toylang.escript libruntime.a; do
    [ -f "$tmp/$name/$f" ] || die "the package is missing $f"
  done

  # Don't overwrite a command we didn't create.
  if [ -e "$BIN_DIR/toylang" ] && ! grep -q "$MARKER" "$BIN_DIR/toylang" 2>/dev/null; then
    die "$BIN_DIR/toylang already exists and was not installed by this script; remove it or set TOYLANG_BIN_DIR"
  fi

  mkdir -p "$TOYLANG_HOME" "$BIN_DIR"
  rm -rf "$TOYLANG_HOME/$name"
  mv "$tmp/$name" "$TOYLANG_HOME/$name"
  chmod +x "$TOYLANG_HOME/$name/toylang"
  chmod +x "$TOYLANG_HOME/$name/toylang.escript"
  chmod +x "$TOYLANG_HOME/$name/build.sh"
  ln -sfn "$TOYLANG_HOME/$name" "$TOYLANG_HOME/current"
  chmod +x "$TOYLANG_HOME/current/toylang"

  # Keep only the version we just installed.
  for d in "$TOYLANG_HOME"/toylang-*; do
    [ -d "$d" ] || continue
    [ "$d" = "$TOYLANG_HOME/$name" ] || rm -rf "$d"
  done

  # The launcher runs the packaged script by its real path, so the script
  # can find libruntime.a and the escript next to itself.
  cat > "$BIN_DIR/toylang" <<LAUNCHER
#!/bin/sh
$MARKER
exec "$TOYLANG_HOME/current/toylang" "\$@"
LAUNCHER
  chmod +x "$BIN_DIR/toylang"

  say "Installed toylang $tag in $TOYLANG_HOME/$name"
  say "Launcher: $BIN_DIR/toylang"

  check_tools "$os"

  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) say ""
       say "$BIN_DIR is not on your PATH. Add this line to your shell profile:"
       say "  export PATH=\"$BIN_DIR:\$PATH\"" ;;
  esac
}

main() {
  action=install
  while [ $# -gt 0 ]; do
    case "$1" in
      -v|--version)
        [ $# -ge 2 ] || die "--version needs a value"
        VERSION="$2"
        shift 2 ;;
      --uninstall) action=uninstall; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown option: $1 (try --help)" ;;
    esac
  done

  if [ "$action" = uninstall ]; then
    uninstall
  else
    install
  fi
}

# Everything is defined above, so a half-downloaded script runs nothing.
main "$@"
