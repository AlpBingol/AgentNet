#!/usr/bin/env bash
# AgentNet Alpha installer for Ubuntu-based Linux (Ubuntu 22.04 / 24.04, Linux Mint, Pop!_OS).
#
#   install.sh             install AgentNet and what it needs; asks how (system, user only, or show me the commands)
#   install.sh doctor      check every prerequisite, the Claude sign-in and the daemon
#   install.sh update      install the newest release, verify it and restart the service
#   install.sh uninstall   remove what this script installed; your data stays unless you add --purge
#
# Run it as yourself, never as root: it asks for sudo when a step needs it. Every download is pinned and checked, and
# your shell rc files are only touched if you say yes.
#
# The in-app Update button calls: install.sh update --archive <verified.tar.gz> --version X.Y.Z --yes --no-restart
# Overrides (environment): AGENTNET_VERSION=<tag> (pin a release), AGENTNET_RELEASE_URL (a mirror laid out as
# <url>/latest and <url>/<tag>/<asset>), AGENTNET_HOME, AGENTNET_PORT, AGENTNET_INSTALL_MODE=system|user|commands.
set -euo pipefail

# ---------------------------------------------------------------------------------------------------------------------
# Pins. Every download is pinned and checked against a SHA-256 written here, or (AgentNet itself) against the
# release's SHA256SUMS, which is signed with the admin's Ed25519 key.
RELEASE_REPO="AlpBingol/AgentNet" # the public releases repo (FEEDBACK_REPO in packages/shared/src/feedback.ts)

# Release signing keys: base64 of the raw 32-byte Ed25519 public keys. scripts/release/build-alpha.sh copies them from
# ADMIN_PUBLIC_KEYS in packages/daemon/src/admin/signing.ts into the install.sh it ships, so keep them there. Then a
# release must carry SHA256SUMS.sig or manifest.json.sig; with both keys empty only the SHA-256 sums are checked.
ADMIN_PUBKEY_MAIN="IF1Z7sgIQklcTt/qvAQE8M/Vj30R2IsHmz96dpK5Tow="
ADMIN_PUBKEY_BACKUP="LpAnldYSigNSPJuga8NdUsmsp7xR4R1MbsvhVm4Z1C4="

UV_VERSION="0.13.1"
declare -A UV_SHA256=(
  [x64]="eadd9d27c134ab5ac1ffd4473b97a741407f3ea238288f03121fc4deddf90220"
  [arm64]="9041c73c99fdc5892cf128140beb354eca9231d502068cc36e6cb53a8e59ad14"
)
BD_VERSION="1.3.1"
declare -A BD_SHA256=(
  [x64]="3219443a9734b89b93fb16ee8d65844759fa1b3cd3cf139c606b7353cfb0715c"
  [arm64]="c3b32c71a6c0cd6358a12c28272b17e6818db991da192f87df52339c222e423a"
)
AGENT_MAIL_REPO="https://github.com/Dicklesworthstone/mcp_agent_mail"
AGENT_MAIL_COMMIT="3fad5ec672869f81d2ca0a4c525dde004ac96f45" # full hash: git checks the content against it

# Anthropic's official installer. It verifies the claude binary against Anthropic's own manifest; we pin the installer.
CLAUDE_INSTALLER_URL="https://claude.ai/install.sh"
CLAUDE_INSTALLER_SHA256="3a68d3406cf674e17bed1733a4dcf37805e2e47d87417700007d7e1aa766a944"
# ---------------------------------------------------------------------------------------------------------------------

BIN_DIR="$HOME/.local/bin"
SHARE="${XDG_DATA_HOME:-$HOME/.local/share}"
OWN="$SHARE/agentnet"                    # releases, the current link, installer state; owned by you in every mode
STATE="$OWN/install-state"
DL="$OWN/download"
DATA="${AGENTNET_HOME:-$HOME/.agentnet}" # your AgentNet data: never removed without --purge
PORT="${AGENTNET_PORT:-7420}"
APPARMOR_PROFILE=/etc/apparmor.d/agentnet-bwrap
RC_MARK="# added by the AgentNet installer"
SERVICE=agentnetd
MAIL_DIR="$DATA/tools/mcp_agent_mail"
NATS_BIN="$DATA/tools/nats-server/nats-server"
ORIG_PATH="$PATH"
export PATH="$BIN_DIR:$PATH"

# ---- output ---------------------------------------------------------------------------------------------------------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  B=$'\e[1m' D=$'\e[2m' R=$'\e[31m' G=$'\e[32m' Y=$'\e[33m' C=$'\e[36m' N=$'\e[0m'
else
  B="" D="" R="" G="" Y="" C="" N=""
fi
say() { printf '%s\n' "$*"; }
info() { printf '%s•%s %s\n' "$C" "$N" "$*"; }
ok() { printf '%s✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s!%s %s\n' "$Y" "$N" "$*"; }
bad() { printf '%s✗%s %s\n' "$R" "$N" "$*"; }
die() {
  bad "$*" >&2
  exit 1
}
head1() { printf '\n%s== %s ==%s\n' "$B" "$*" "$N"; }
show_cmds() { # a command block to copy and paste: not indented, so heredocs in it still work when pasted
  printf '%s-----8<----- copy from here%s\n%s\n%s----->8----- to here%s\n' "$D" "$N" "$1" "$D" "$N"
}

# ---- input: reads the terminal, so `curl … | bash` works too --------------------------------------------------------
if [[ -t 0 ]]; then
  exec 3<&0
elif ! { exec 3</dev/tty; } 2>/dev/null; then
  exec 3<&0
fi
YES=0 # --yes: never ask (update from the app)
ask() { # ask "question" → $REPLY; fails when the input is closed
  ((YES)) && die "Needs an answer, but --yes was given: $1"
  printf '%s?%s %s ' "$B" "$N" "$1"
  if ! IFS= read -r REPLY <&3; then
    REPLY=""
    say ""
    return 1
  fi
}
yes_no() { # yes_no "question" y|n   (the default is the capital letter)
  local d=${2:-n} hint="[y/N]"
  [[ $d == y ]] && hint="[Y/n]"
  while true; do
    ask "$1 $hint" || {
      info "No input: taking the default (${d^^})."
      [[ $d == y ]]
      return
    }
    case "${REPLY,,}" in
      "") [[ $d == y ]] && return 0 || return 1 ;;
      y | yes) return 0 ;;
      n | no) return 1 ;;
    esac
  done
}
pause() { ask "${1:-Press Enter when done.}" || die "No input (closed). Run the installer again in a terminal."; }

# ---- small helpers --------------------------------------------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }
TMP="" SUDO_KEEPALIVE=""
cleanup() {
  [[ -n "$TMP" ]] && rm -rf "$TMP"
  [[ -n "$SUDO_KEEPALIVE" ]] && kill "$SUDO_KEEPALIVE" 2>/dev/null
  return 0
}
trap cleanup EXIT
tmpdir() { [[ -n "$TMP" ]] || TMP=$(mktemp -d); }
q() { printf '%q' "$1"; } # shell-quote for printed commands
run_snippet() { bash -euo pipefail -c "$1" </dev/null; } # never eats the answers on stdin

state_get() { [[ -f "$STATE" ]] && sed -n "s/^$1=//p" "$STATE" | tail -n1 || true; }
state_set() {
  mkdir -p "$OWN"
  touch "$STATE"
  sed -i "/^$1=/d" "$STATE"
  printf '%s=%s\n' "$1" "$2" >>"$STATE"
}
mark_installed() { state_set "installed_$1" yes; } # this script put it there, so uninstall may remove it
was_installed() { [[ "$(state_get "installed_$1")" == yes ]]; }

# ---- platform -------------------------------------------------------------------------------------------------------
detect_platform() {
  local f=/etc/os-release
  OS_ID="" OS_LIKE="" OS_NAME="$(uname -s)" BASE_CODENAME=""
  if [[ -r $f ]]; then
    OS_ID=$(sed -n 's/^ID=//p' $f | tr -d '"')
    OS_LIKE=$(sed -n 's/^ID_LIKE=//p' $f | tr -d '"')
    OS_NAME=$(sed -n 's/^PRETTY_NAME=//p' $f | tr -d '"')
    BASE_CODENAME=$(sed -n 's/^UBUNTU_CODENAME=//p' $f | tr -d '"')
    [[ -n "$BASE_CODENAME" || $OS_ID != ubuntu ]] || BASE_CODENAME=$(sed -n 's/^VERSION_CODENAME=//p' $f | tr -d '"')
  fi
  UBUNTU_BASED=0
  [[ "$OS_ID" == ubuntu || " $OS_LIKE " == *" ubuntu "* ]] && UBUNTU_BASED=1
  case "$BASE_CODENAME" in
    jammy) BASE_VER=22.04 ;;
    noble) BASE_VER=24.04 ;;
    *) BASE_VER="" ;;
  esac
  case "$(uname -m)" in
    x86_64 | amd64) ARCH=x64 DEB_ARCH=amd64 GNU_ARCH=x86_64 ;;
    aarch64 | arm64) ARCH=arm64 DEB_ARCH=arm64 GNU_ARCH=aarch64 ;;
    *) ARCH="" DEB_ARCH="" GNU_ARCH="" ;;
  esac
}
graphical() { [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; }

# Ubuntu 23.10+ restricts unprivileged user namespaces with AppArmor: docs/spikes/ubuntu-apparmor-bwrap.md.
userns_restricted() { [[ "$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns 2>/dev/null)" == 1 ]]; }
bwrap_works() { bwrap --ro-bind / / --dev /dev --proc /proc true >/dev/null 2>&1; } # the daemon's own probe

# ---- the release ----------------------------------------------------------------------------------------------------
asset_url() { # asset_url <file>
  if [[ -n "${AGENTNET_RELEASE_URL:-}" ]]; then
    printf '%s/%s/%s' "${AGENTNET_RELEASE_URL%/}" "$TAG" "$1"
  else
    printf 'https://github.com/%s/releases/download/%s/%s' "$RELEASE_REPO" "$TAG" "$1"
  fi
}
latest_tag() {
  local t
  if [[ -n "${AGENTNET_VERSION:-}" ]]; then
    t="$AGENTNET_VERSION"
  elif [[ -n "${AGENTNET_RELEASE_URL:-}" ]]; then
    t=$(curl -fsSL "${AGENTNET_RELEASE_URL%/}/latest") || die "Can't reach $AGENTNET_RELEASE_URL"
  else
    t=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$RELEASE_REPO/releases/latest") ||
      die "Can't reach github.com/$RELEASE_REPO"
    t="${t##*/}"
  fi
  t=$(tr -d '[:space:]' <<<"$t")
  [[ "$t" =~ ^[0-9A-Za-z][0-9A-Za-z._+-]*$ ]] || die "Could not find the latest AgentNet release (got '$t')."
  printf '%s' "$t"
}

# SPKI PEM for a raw 32-byte Ed25519 key given in base64.
pubkey_pem() {
  printf -- '-----BEGIN PUBLIC KEY-----\n'
  { printf '\x30\x2a\x30\x05\x06\x03\x2b\x65\x70\x03\x21\x00' && base64 -d <<<"$1"; } | base64 -w0
  printf '\n-----END PUBLIC KEY-----\n'
}
# sig_ok <dir> <file>: <file>.sig is a valid signature of <file> by the main or the backup key.
sig_ok() {
  local d=$1 f=$2 k i=0 r=1
  [[ -s "$d/$f" && -s "$d/$f.sig" ]] || return 1
  base64 -d "$d/$f.sig" >"$d/sig.bin" 2>/dev/null || return 1
  for k in "$ADMIN_PUBKEY_MAIN" "$ADMIN_PUBKEY_BACKUP"; do
    [[ -n "$k" ]] || continue
    i=$((i + 1))
    pubkey_pem "$k" >"$d/key$i.pem"
    if openssl pkeyutl -verify -pubin -inkey "$d/key$i.pem" -rawin -in "$d/$f" -sigfile "$d/sig.bin" >/dev/null 2>&1; then
      r=0
      break
    fi
  done
  rm -f "$d/sig.bin" "$d"/key*.pem
  return $r
}
# sums_from_manifest <dir>: SHA256SUMS lines from the signed manifest.json (sign.mjs manifest: assets[].name/.sha256).
sums_from_manifest() {
  awk -F'"' '$2 == "name" { n = $4 } $2 == "sha256" && n != "" { print $4 "  " n; n = "" }' "$1/manifest.json" >"$1/SHA256SUMS"
  [[ -s "$1/SHA256SUMS" ]]
}
# verify_release <dir>: trust SHA256SUMS only if it, or the manifest.json it is made from, carries a valid signature.
verify_release() {
  local d=$1
  if [[ -z "$ADMIN_PUBKEY_MAIN$ADMIN_PUBKEY_BACKUP" ]]; then
    warn "Release signature not checked: no signing key in this installer. SHA-256 sums only."
    [[ -s "$d/SHA256SUMS" ]] || sums_from_manifest "$d" || die "The release has neither SHA256SUMS nor manifest.json."
    return 0
  fi
  have openssl || die "openssl is needed to check the release signature: sudo apt-get install -y openssl"
  if sig_ok "$d" SHA256SUMS; then
    ok "Release signature is valid (SHA256SUMS)"
  elif sig_ok "$d" manifest.json && sums_from_manifest "$d"; then
    ok "Release signature is valid (manifest.json)"
  else
    die "The release has no valid signature from AgentNet's signing key (SHA256SUMS.sig or manifest.json.sig). Not installing it."
  fi
}
# resolve_release: find the newest (or pinned) release, fetch and verify its checksums, name its assets.
resolve_release() {
  local f
  [[ -n "${TAG:-}" ]] && return 0
  TAG=$(latest_tag)
  REL_DIR="$DL/$TAG"
  mkdir -p "$REL_DIR"
  for f in SHA256SUMS SHA256SUMS.sig manifest.json manifest.json.sig; do
    curl -fsSL -o "$REL_DIR/$f" "$(asset_url "$f")" 2>/dev/null || rm -f "${REL_DIR:?}/$f"
  done
  [[ -f "$REL_DIR/SHA256SUMS" || -f "$REL_DIR/manifest.json" ]] || die "Can't download the checksums of release $TAG."
  verify_release "$REL_DIR"
  TARBALL=$(grep -oE "agentnet-[A-Za-z0-9._+-]*-linux-$ARCH\.tar\.gz\$" "$REL_DIR/SHA256SUMS" | head -n1 || true)
  [[ -n "$TARBALL" ]] || die "Release $TAG has no build for $(uname -m) yet (Alpha ships x86_64 only)."
  VER=${TARBALL%-linux-"$ARCH".tar.gz}
  VER=${VER##*-}
  DESKTOP_DEB=$(grep -oE "[A-Za-z0-9._+-]+_[0-9][A-Za-z0-9.~+-]*_$DEB_ARCH\.deb\$" "$REL_DIR/SHA256SUMS" | head -n1 || true)
}
# Commands that download one release asset and check it against the (already verified) SHA256SUMS.
cmds_fetch() { # cmds_fetch <file>
  cat <<EOF
cd $(q "$REL_DIR")
curl -fsSL -o $(q "$1") $(q "$(asset_url "$1")")
grep -E '[ *]$(q "$1")\$' SHA256SUMS | sha256sum -c -
EOF
}

installed_version() {
  [[ -f "$OWN/current/VERSION" ]] && tr -d '[:space:]' <"$OWN/current/VERSION"
  return 0
}
installer_copy() { # keep install.sh where the in-app Update button finds it
  if [[ -f "$OWN/current/scripts/install.sh" ]]; then
    ln -sfn current/scripts/install.sh "$OWN/install.sh"
  elif [[ -f "${BASH_SOURCE[0]:-}" && "$(readlink -f "${BASH_SOURCE[0]}")" != "$(readlink -f "$OWN/install.sh" 2>/dev/null)" ]]; then
    install -m755 "${BASH_SOURCE[0]}" "$OWN/install.sh.new" && mv -f "$OWN/install.sh.new" "$OWN/install.sh"
  fi
  return 0
}
# replace_release <archive> <version>: unpack next to the current release, then switch `current` atomically.
replace_release() {
  local a=$1 v=$2 rel="$OWN/releases" prev
  [[ "$v" =~ ^[0-9A-Za-z][0-9A-Za-z._+-]*$ ]] || die "Bad version: $v"
  mkdir -p "$rel" "$BIN_DIR"
  rm -rf "$rel/.new-$v"
  mkdir "$rel/.new-$v"
  tar -xzf "$a" --no-same-owner --strip-components=1 -C "$rel/.new-$v" || {
    rm -rf "$rel/.new-$v"
    die "Can't unpack $a"
  }
  [[ -x "$rel/.new-$v/bin/agentnetd" ]] || {
    rm -rf "$rel/.new-$v"
    die "$a is not an AgentNet release (no bin/agentnetd)."
  }
  prev=""
  [[ -L "$OWN/current" ]] && prev=$(readlink -f "$OWN/current")
  if [[ "$prev" == "$rel/$v" ]]; then # reinstalling the running version: move it aside first
    rm -rf "$rel/.old-$v" && mv "$rel/$v" "$rel/.old-$v" && prev="$rel/.old-$v"
    ln -sfn "$prev" "$OWN/current.new" && mv -Tf "$OWN/current.new" "$OWN/current"
  else
    rm -rf "${rel:?}/$v"
  fi
  mv "$rel/.new-$v" "$rel/$v"
  ln -sfn "$rel/$v" "$OWN/current.new" && mv -Tf "$OWN/current.new" "$OWN/current"
  [[ -n "$prev" && "$prev" != "$rel/$v" ]] && state_set previous_release "$prev"
  local b old keep
  for b in agentnetd agentnet; do ln -sfn "$OWN/current/bin/$b" "$BIN_DIR/$b"; done
  installer_copy
  keep=$(state_get previous_release)
  for old in "$rel"/* "$rel"/.old-*; do # keep the current and the previous release, for a rollback
    [[ -e "$old" && "$old" != "$rel/$v" && "$old" != "$keep" ]] && rm -rf "$old"
  done
  return 0
}

# ---- steps ----------------------------------------------------------------------------------------------------------
# A step <id> has check_<id> (0 = already there) and cmds_<id> (the shell commands that do it), and optionally
# before_<id> (ask / explain; non-zero = skip) and after_<id>. Root steps' commands use sudo.
guided() { # guided <id> <title> <root:0|1>
  local id=$1 title=$2 root=$3
  head1 "$title"
  if [[ $root == 1 ]]; then info "These commands need root (they use sudo). Run them in another terminal:"; else
    info "Run these commands in another terminal:"
  fi
  show_cmds "$("cmds_$id")"
  while true; do
    pause "Press Enter when done (s = skip, q = quit)."
    case "${REPLY,,}" in
      q) die "Stopped. Run the installer again to continue where you left off." ;;
      s)
        warn "Skipped: $title"
        return 1
        ;;
    esac
    if "check_$id"; then
      declare -F "after_$id" >/dev/null && "after_$id"
      ok "$title"
      return 0
    fi
    bad "Not done yet: $title. Look at the commands' output, then press Enter to check again."
  done
}
step() { # step <id> <title> <root:0|1>
  local id=$1 title=$2 root=$3
  if "check_$id"; then
    ok "$title: already there"
    return 0
  fi
  if declare -F "before_$id" >/dev/null && ! "before_$id"; then
    warn "Skipped: $title"
    return 0
  fi
  if [[ $MODE == commands || ($MODE == user && $root == 1) ]]; then
    guided "$id" "$title" "$root" || true
    return 0
  fi
  head1 "$title"
  if run_snippet "$("cmds_$id")" && "check_$id"; then
    declare -F "after_$id" >/dev/null && "after_$id"
    ok "$title"
  else
    bad "$title failed."
    yes_no "Continue with the next step anyway?" n || die "Stopped. Fix the problem above and run the installer again."
  fi
}

# Root: packages.
missing_pkgs() {
  local out=()
  have git || out+=(git)
  have curl || out+=(curl)
  have bwrap || out+=(bubblewrap)
  [[ -z "$ADMIN_PUBKEY_MAIN$ADMIN_PUBKEY_BACKUP" ]] || have openssl || out+=(openssl)
  printf '%s' "${out[*]}"
}
check_pkgs() { [[ -z "$(missing_pkgs)" ]]; }
cmds_pkgs() {
  if [[ $UBUNTU_BASED == 1 ]]; then
    printf 'sudo apt-get update -qq\nsudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq %s\n' "$(missing_pkgs)"
  else
    printf '# Install these with your system'\''s package manager:  %s\n' "$(missing_pkgs)"
  fi
}

# Root: AppArmor profile so bwrap may create its user namespace (only where Ubuntu restricts them and bwrap fails).
apparmor_needed() { userns_restricted && ! bwrap_works; }
check_apparmor() { ! have bwrap || ! apparmor_needed; }
cmds_apparmor() {
  cat <<EOF
sudo tee $APPARMOR_PROFILE >/dev/null <<'PROFILE'
# AgentNet: let bubblewrap create unprivileged user namespaces (restricted on Ubuntu 23.10+).
abi <abi/4.0>,
include <tunables/global>

profile agentnet-bwrap /usr/bin/bwrap flags=(unconfined) {
  userns,

  include if exists <local/agentnet-bwrap>
}
PROFILE
sudo apparmor_parser -r $APPARMOR_PROFILE
EOF
}
after_apparmor() { mark_installed apparmor; }

# AgentNet itself: the release tarball in ~/.local/share/agentnet (every mode, so updates never need root).
check_app() { [[ "$(installed_version)" == "$VER" && -x "$OWN/current/bin/agentnetd" && -L "$BIN_DIR/agentnetd" ]]; }
cmds_app() {
  cmds_fetch "$TARBALL"
  if [[ $MODE == commands ]]; then
    # The same as replace_release, spelled out.
    cat <<EOF
mkdir -p $(q "$OWN/releases/$VER") $(q "$BIN_DIR")
tar -xzf $(q "$TARBALL") --no-same-owner --strip-components=1 -C $(q "$OWN/releases/$VER")
ln -sfn $(q "$OWN/releases/$VER") $(q "$OWN/current")
ln -sfn $(q "$OWN/current/bin/agentnetd") $(q "$BIN_DIR/agentnetd")
ln -sfn $(q "$OWN/current/bin/agentnet") $(q "$BIN_DIR/agentnet")
rm -f $(q "$TARBALL")
EOF
  fi
}
do_app() { # system and user modes: download, check, then replace_release
  run_snippet "$(cmds_app)" || return 1
  replace_release "$REL_DIR/$TARBALL" "$VER"
  rm -f "${REL_DIR:?}/$TARBALL"
}
before_app() {
  local b
  for b in agentnetd agentnet; do
    if [[ -e "$BIN_DIR/$b" && "$(readlink -f "$BIN_DIR/$b")" != "$OWN"/* ]]; then
      warn "$BIN_DIR/$b already exists and isn't from this installer ($(readlink -f "$BIN_DIR/$b"))."
      yes_no "Replace it with AgentNet $VER?" n || return 1
    fi
  done
}
after_app() {
  mark_installed app
  installer_copy
}

# The desktop window (the release's .deb). System mode: apt installs it with its libraries. User mode: unpacked into
# ~/.local; its libraries (WebKitGTK) are a root step.
DESK_DIR="$OWN/desktop"
desktop_pkg() { # the package name, from the state or the downloaded .deb
  local p
  p=$(state_get desktop_pkg)
  [[ -n "$p" ]] || p=$(dpkg-deb -f "$REL_DIR/$DESKTOP_DEB" Package 2>/dev/null || true)
  printf '%s' "$p"
}
check_desktop() {
  [[ -n "$DESKTOP_DEB" ]] || return 1
  if [[ $MODE == system ]]; then
    local pkg
    pkg=$(desktop_pkg)
    [[ -n "$pkg" ]] && dpkg-query -W -f='${Status} ${Version}' "$pkg" 2>/dev/null | grep -q "ok installed $VER"
  else
    [[ -x "$BIN_DIR/agentnet-desktop" && -f "$DESK_DIR/VERSION" && "$(cat "$DESK_DIR/VERSION")" == "$VER" ]]
  fi
}
cmds_desktop() {
  cmds_fetch "$DESKTOP_DEB"
  if [[ $MODE == system ]]; then
    printf 'chmod 644 %s && chmod o+x %s %s %s\n' "$(q "$DESKTOP_DEB")" "$(q "$OWN")" "$(q "$DL")" "$(q "$REL_DIR")"
    printf 'sudo apt-get install -y ./%s\n' "$(q "$DESKTOP_DEB")"
    return 0
  else
    local apps="$SHARE/applications"
    cat <<EOF
rm -rf $(q "$DESK_DIR") && mkdir -p $(q "$DESK_DIR") $(q "$apps") $(q "$SHARE/icons")
dpkg-deb -x $(q "$DESKTOP_DEB") $(q "$DESK_DIR")
echo $(q "$VER") > $(q "$DESK_DIR/VERSION")
exe=\$(ls $(q "$DESK_DIR")/usr/bin/* | head -n1)
ln -sfn "\$exe" $(q "$BIN_DIR/agentnet-desktop")
cp -r $(q "$DESK_DIR")/usr/share/icons/. $(q "$SHARE/icons")/ 2>/dev/null || true
for f in $(q "$DESK_DIR")/usr/share/applications/*.desktop; do
  sed "s|^Exec=.*|Exec=$BIN_DIR/agentnet-desktop|" "\$f" > $(q "$apps/agentnet.desktop")
done
command -v update-desktop-database >/dev/null && update-desktop-database $(q "$apps") >/dev/null 2>&1 || true
EOF
  fi
  printf 'rm -f %s\n' "$(q "$DESKTOP_DEB")"
}
before_desktop() {
  [[ -n "$DESKTOP_DEB" ]] || return 1
  graphical || {
    info "No graphical session here: skipping the desktop window. Open AgentNet in a browser instead."
    return 1
  }
  yes_no "Install the AgentNet desktop window too?" y
}
after_desktop() {
  if [[ $MODE == system ]]; then
    state_set desktop_pkg "$(desktop_pkg)"
    rm -f "${REL_DIR:?}/$DESKTOP_DEB"
  fi
  mark_installed desktop
}
check_desktoplibs() { ldconfig -p 2>/dev/null | grep -q 'libwebkit2gtk-4.1.so.0'; }
cmds_desktoplibs() { printf 'sudo apt-get install -y libwebkit2gtk-4.1-0 libgtk-3-0\n'; }

claude_signed_in() { have claude && claude auth status 2>/dev/null | grep -q '"loggedIn": *true'; }
check_claude() { have claude; }
cmds_claude() {
  cat <<EOF
mkdir -p $(q "$DL") && cd $(q "$DL")
curl -fsSL -o claude-install.sh $CLAUDE_INSTALLER_URL
echo '$CLAUDE_INSTALLER_SHA256  claude-install.sh' | sha256sum -c -
bash claude-install.sh stable
rm -f claude-install.sh
EOF
}
before_claude() {
  info "Claude Code comes from Anthropic's official installer, pinned by its SHA-256. It checks the claude binary"
  info "against Anthropic's own manifest and puts it in ~/.local/bin. You sign in yourself."
  tmpdir
  if curl -fsSL -o "$TMP/claude-install.sh" "$CLAUDE_INSTALLER_URL" &&
    ! echo "$CLAUDE_INSTALLER_SHA256  $TMP/claude-install.sh" | sha256sum -c --quiet - >/dev/null 2>&1; then
    warn "Anthropic's installer changed since this script was released (its SHA-256 no longer matches the pin)."
    info "Install Claude Code yourself, as https://code.claude.com/docs says, then run this installer again:"
    show_cmds "curl -fsSL $CLAUDE_INSTALLER_URL | bash"
    return 1
  fi
}
after_claude() { mark_installed claude; }

check_uv() { have uv; }
cmds_uv() {
  local f="uv-$GNU_ARCH-unknown-linux-gnu.tar.gz"
  cat <<EOF
mkdir -p $(q "$DL") $(q "$BIN_DIR") && cd $(q "$DL")
curl -fsSL -o $f https://github.com/astral-sh/uv/releases/download/$UV_VERSION/$f
echo '${UV_SHA256[$ARCH]}  $f' | sha256sum -c -
tar -xzf $f --no-same-owner
install -m755 uv-$GNU_ARCH-unknown-linux-gnu/uv uv-$GNU_ARCH-unknown-linux-gnu/uvx $(q "$BIN_DIR")/
rm -rf $f uv-$GNU_ARCH-unknown-linux-gnu
EOF
}
after_uv() { mark_installed uv; }

release_script() { printf '%s' "$OWN/current/scripts/$1"; }
check_mail() { [[ -x "$MAIL_DIR/.venv/bin/python" ]] && "$MAIL_DIR/.venv/bin/python" -c 'import mcp_agent_mail' 2>/dev/null; }
cmds_mail() {
  # PATH: a terminal opened before ~/.local/bin existed doesn't have it yet, and setup-mail.sh needs uv from there.
  # shellcheck disable=SC2016 # $HOME and $PATH expand in the user's shell
  printf 'PATH="$HOME/.local/bin:$PATH" AGENTNET_HOME=%s AGENT_MAIL_COMMIT=%s bash %s\n' "$(q "$DATA")" "$AGENT_MAIL_COMMIT" "$(q "$(release_script setup-mail.sh)")"
}
before_mail() { # D-032: installed by default under the author's written permission; a licence note, no prompt
  info "MCP Agent Mail is third-party software (MIT License with an OpenAI/Anthropic rider), installed unmodified with"
  info "its author's permission: $AGENT_MAIL_REPO/blob/$AGENT_MAIL_COMMIT/LICENSE"
  [[ -f "$(release_script setup-mail.sh)" ]] || {
    bad "This release has no scripts/setup-mail.sh."
    return 1
  }
  [[ $MODE == commands ]] || check_uv || {
    bad "uv is missing, and Agent Mail needs it."
    return 1
  }
}
after_mail() { mark_installed mail; }

check_bd() { have bd; }
cmds_bd() {
  local f="beads_${BD_VERSION}_linux_$DEB_ARCH.tar.gz"
  cat <<EOF
mkdir -p $(q "$DL/bd") $(q "$BIN_DIR") && cd $(q "$DL/bd")
curl -fsSL -o $f https://github.com/gastownhall/beads/releases/download/v$BD_VERSION/$f
echo '${BD_SHA256[$ARCH]}  $f' | sha256sum -c -
tar -xzf $f --no-same-owner
install -m755 bd $(q "$BIN_DIR")/bd
cd .. && rm -rf bd
EOF
}
after_bd() { mark_installed bd; }

check_nats() { [[ -x "$NATS_BIN" ]]; }
cmds_nats() { printf 'AGENTNET_HOME=%s bash %s\n' "$(q "$DATA")" "$(q "$(release_script setup-nats.sh)")"; }
before_nats() {
  info "nats-server is optional: a faster message bus between AgentNet's parts (off unless you set AGENTNET_BUS=nats)."
  yes_no "Install nats-server?" n || return 1
  [[ -f "$(release_script setup-nats.sh)" ]] || {
    bad "This release has no scripts/setup-nats.sh."
    return 1
  }
}
after_nats() { mark_installed nats; }

has_user_systemd() { systemctl --user show-environment >/dev/null 2>&1; }
check_service() { systemctl --user is-enabled "$SERVICE.service" >/dev/null 2>&1; }
cmds_service() {
  local env=""
  [[ -n "${AGENTNET_HOME:-}" ]] && env+="--home $(q "$AGENTNET_HOME") "
  [[ -n "${AGENTNET_PORT:-}" ]] && env+="--port $(q "$AGENTNET_PORT") "
  printf 'bash %s install %s--exec %s\n' "$(q "$(release_script install-service.sh)")" "$env" "$(q "$OWN/current/bin/agentnetd")"
}
before_service() {
  has_user_systemd || {
    warn "No systemd user session here, so AgentNet can't run as a service. Start it yourself with: agentnetd"
    return 1
  }
  info "The user service starts AgentNet when you log in and keeps it running when you close the window."
  yes_no "Install the AgentNet user service?" y || return 1
  [[ -f "$(release_script install-service.sh)" ]] || {
    bad "This release has no scripts/install-service.sh."
    return 1
  }
}
after_service() { mark_installed service; }

login_step() {
  have claude || return 0
  if claude_signed_in; then
    ok "Claude Code: signed in"
    return 0
  fi
  head1 "Sign in to Claude Code"
  info "Sign in yourself; AgentNet never sees your Claude credentials. In another terminal, run:"
  show_cmds "claude"
  info "Log in when it asks (or type /login), then leave it with /exit."
  while ! claude_signed_in; do
    pause "Press Enter when you're signed in (s = later)."
    if [[ "${REPLY,,}" == s ]]; then
      warn "Not signed in yet. Agents can't start until you sign in to Claude Code."
      return 0
    fi
    claude_signed_in || bad "Still not signed in (claude auth status says so)."
  done
  ok "Claude Code: signed in"
}

path_has_bin() { [[ ":$ORIG_PATH:" == *":$BIN_DIR:"* ]]; }
path_step() {
  path_has_bin && return 0
  head1 "PATH"
  warn "$BIN_DIR is not on your PATH yet, so terminals won't find agentnet, claude, bd or uv."
  info "Ubuntu adds it by itself at your next login, now that the folder exists. Or I can add this line to ~/.bashrc:"
  show_cmds "export PATH=\"\$HOME/.local/bin:\$PATH\" $RC_MARK"
  if yes_no "Add it to ~/.bashrc?" n; then
    # shellcheck disable=SC2016 # expands later, in your shell
    printf '\nexport PATH="$HOME/.local/bin:$PATH" %s\n' "$RC_MARK" >>"$HOME/.bashrc"
    state_set rc_edited yes
    ok "Added. Open a new terminal to use it."
  else
    info "Your shell files are unchanged. Log out and in again, or use the full paths in $BIN_DIR."
  fi
}

# ---- doctor ---------------------------------------------------------------------------------------------------------
daemon_up() { curl -fs -o /dev/null --max-time 3 "http://127.0.0.1:$PORT/"; }
wait_for_daemon() {
  local i
  for i in $(seq 1 45); do
    daemon_up && return 0
    sleep 1
  done
  return 1
}
doctor() {
  detect_platform
  local fails=0 v
  check() { # check <required:1|0> <label> <command…>
    local req=$1 label=$2
    shift 2
    if "$@"; then
      ok "$label"
    elif [[ $req == 1 ]]; then
      bad "$label"
      fails=$((fails + 1))
    else
      warn "$label: no (optional)"
    fi
  }
  head1 "AgentNet doctor"
  if [[ $UBUNTU_BASED == 1 ]]; then
    ok "System: $OS_NAME${BASE_VER:+ (Ubuntu $BASE_VER base)}, $(uname -m)"
  else
    warn "System: $OS_NAME, $(uname -m): not Ubuntu-based, unsupported in Alpha"
  fi
  check 1 "git" have git
  check 1 "curl" have curl
  check 1 "bubblewrap (bwrap)" have bwrap
  if have bwrap; then
    check 1 "bwrap can build the agents' sandbox$(userns_restricted && echo ' (user namespaces restricted by AppArmor here)')" bwrap_works
  fi
  v=$(installed_version)
  check 1 "AgentNet ${v:-not installed}${v:+ ($OWN/current)}" test -n "$v"
  check 1 "agentnetd on the command line ($BIN_DIR)" have agentnetd
  if was_installed desktop; then check 0 "desktop window" have_desktop; fi
  check 1 "Claude Code ($(claude --version 2>/dev/null | head -n1 || echo 'not installed'))" have claude
  check 1 "Claude Code signed in" claude_signed_in
  check 1 "uv" have uv
  check 1 "MCP Agent Mail ($MAIL_DIR)" check_mail
  check 1 "Beads ($(bd --version 2>/dev/null | head -n1 || echo 'bd not installed'))" have bd
  check 0 "nats-server" check_nats
  if has_user_systemd; then
    check 0 "user service $SERVICE ($(systemctl --user is-active "$SERVICE.service" 2>/dev/null || true))" \
      systemctl --user is-active --quiet "$SERVICE.service"
  fi
  check 1 "daemon reachable at http://127.0.0.1:$PORT" daemon_up
  check 0 "$BIN_DIR on your PATH" path_has_bin
  say ""
  if ((fails)); then
    bad "$fails problem(s). Running the installer again fixes what it can."
    return 1
  fi
  ok "Everything AgentNet needs is in place."
}
have_desktop() { have agentnet-desktop || [[ -n "$(state_get desktop_pkg)" ]]; }

how_to_open() {
  local tok="$DATA/nets/default/token"
  head1 "Open AgentNet"
  if ! daemon_up; then
    say "  • Start the daemon first: ${B}agentnetd${N} (or log in again if you installed the service)."
  fi
  if was_installed desktop; then say "  • Start ${B}AgentNet${N} from your applications menu."; fi
  if [[ -f "$tok" ]]; then
    say "  • Or in a browser: ${B}http://127.0.0.1:$PORT/#token=$(cat "$tok")${N}"
  else
    say "  • Or in a browser: http://127.0.0.1:$PORT/ (the link with your token is in $tok once it has started)"
  fi
  say "  • From a terminal: agentnet status"
  say "  • Check everything again: bash $OWN/install.sh doctor"
}

# ---- install --------------------------------------------------------------------------------------------------------
choose_mode() {
  if [[ -n "${AGENTNET_INSTALL_MODE:-}" ]]; then
    MODE="$AGENTNET_INSTALL_MODE"
    [[ $MODE == system || $MODE == user || $MODE == commands ]] || die "AGENTNET_INSTALL_MODE must be system, user or commands."
    [[ $UBUNTU_BASED == 1 || $MODE == commands ]] || die "Only the commands mode is offered on this system."
    return 0
  fi
  head1 "How should AgentNet be installed?"
  if [[ $UBUNTU_BASED == 1 ]]; then
    say "  1) ${B}System${N} (sudo): installs the system packages for you; asks for your password once."
    say "  2) ${B}User only${N}: no sudo. Everything goes in ~/.local; you run the few root commands yourself."
    say "  3) ${B}Show me the commands${N}: every step printed for you to copy and paste, checked after each."
  else
    say "  3) ${B}Show me the commands${N}: every step printed, to adapt to your system, copy and paste."
  fi
  say "  q) Quit"
  while true; do
    ask "Your choice:" || die "No input (closed). Run the installer in a terminal."
    case "$REPLY" in
      1) [[ $UBUNTU_BASED == 1 ]] && MODE=system && break ;;
      2) [[ $UBUNTU_BASED == 1 ]] && MODE=user && break ;;
      3) MODE=commands && break ;;
      q | Q) exit 0 ;;
    esac
  done
}

system_root_part() {
  local todo=() i all=""
  check_pkgs || todo+=(pkgs)
  # Without bwrap yet, judge by the sysctl; checked again once bwrap is installed.
  if userns_restricted && { ! have bwrap || ! bwrap_works; }; then todo+=(apparmor); fi
  if ((${#todo[@]} == 0)); then
    ok "Nothing needs root"
    return 0
  fi
  head1 "Root commands"
  info "Only these commands run as root:"
  for i in "${todo[@]}"; do
    case $i in
      pkgs) all+="$(cmds_pkgs)"$'\n' ;;
      apparmor) all+="# only if bwrap still can't build its sandbox after that:"$'\n'"$(cmds_apparmor)"$'\n' ;;
    esac
  done
  show_cmds "${all%$'\n'}"
  yes_no "Run them now? sudo asks for your password once." y || die "Nothing was changed. Pick another mode to run them yourself."
  sudo -n true 2>/dev/null || sudo -v || die "sudo failed."
  (while sleep 50; do sudo -n -v 2>/dev/null || exit; done) &
  SUDO_KEEPALIVE=$!
  for i in "${todo[@]}"; do
    case $i in
      pkgs) { run_snippet "$(cmds_pkgs)" && check_pkgs; } || die "Installing the packages failed." ;;
      apparmor)
        if apparmor_needed; then
          { run_snippet "$(cmds_apparmor)" && bwrap_works; } || die "bwrap still can't build its sandbox."
          after_apparmor
          ok "AppArmor profile for bwrap installed"
        else
          ok "bwrap works without an AppArmor profile"
        fi
        ;;
    esac
  done
  ok "Root part done"
}

install_main() {
  detect_platform
  head1 "AgentNet Alpha installer"
  [[ -n "$ARCH" ]] || die "Unsupported CPU: $(uname -m)."
  info "System: $OS_NAME ($(uname -m))"
  if [[ $UBUNTU_BASED == 0 ]]; then
    warn "$OS_NAME is not Ubuntu-based. AgentNet Alpha supports only Ubuntu-based Linux (Ubuntu, Mint, Pop!_OS)."
    info "The \"show me the commands\" mode still works: adapt the package commands to your system."
  elif [[ -z "$BASE_VER" ]]; then
    warn "Ubuntu base \"$BASE_CODENAME\" is not one we test (22.04 jammy, 24.04 noble). It will probably work."
  fi
  have curl || die "curl is needed: sudo apt-get install -y curl"
  choose_mode
  resolve_release
  info "AgentNet $VER (release $TAG from ${AGENTNET_RELEASE_URL:-github.com/$RELEASE_REPO})"
  state_set mode "$MODE"

  if [[ $MODE == system ]]; then
    system_root_part
  else
    step pkgs "Packages: git, curl, bubblewrap" 1
    step apparmor "AppArmor profile for bubblewrap" 1
  fi
  if [[ $MODE == commands ]]; then
    step app "AgentNet $VER" 0
  elif check_app; then
    ok "AgentNet $VER: already there"
  elif before_app; then
    head1 "AgentNet $VER"
    do_app || die "Download, check or unpacking of AgentNet failed."
    after_app
    ok "AgentNet $VER in $OWN/current"
  fi
  step desktop "AgentNet desktop window" "$([[ $MODE == system ]] && echo 1 || echo 0)"
  if [[ $MODE != system ]] && was_installed desktop; then
    step desktoplibs "Libraries for the desktop window (WebKitGTK)" 1
  fi
  step claude "Claude Code" 0
  step uv "uv $UV_VERSION" 0
  step mail "MCP Agent Mail (commit ${AGENT_MAIL_COMMIT:0:7})" 0
  step bd "Beads (bd $BD_VERSION)" 0
  step nats "nats-server (optional)" 0
  step service "AgentNet user service (optional)" 0
  login_step
  path_step
  if check_service && [[ $MODE != commands ]]; then
    systemctl --user restart "$SERVICE.service" || true
    wait_for_daemon || warn "The service isn't answering on port $PORT yet. See: journalctl --user -u $SERVICE"
  fi
  doctor || true
  how_to_open
}

# ---- update ---------------------------------------------------------------------------------------------------------
restart_service() { # restart_service <previous release>: restart, and roll back if the new one doesn't come up
  check_service || return 0
  systemctl --user restart "$SERVICE.service"
  wait_for_daemon && return 0
  if [[ -n "$1" && -d "$1" ]]; then
    bad "The new version didn't start; going back to $(basename "$1")."
    ln -sfn "$1" "$OWN/current.new" && mv -Tf "$OWN/current.new" "$OWN/current"
    systemctl --user restart "$SERVICE.service"
    wait_for_daemon || true
  fi
  exit 2
}
update_main() {
  local archive="" version="" restart=1 force=0 cur prev
  while (($#)); do
    case "$1" in
      --archive) archive=$2 && shift ;;
      --version) version=$2 && shift ;;
      --yes) YES=1 ;;
      --no-restart) restart=0 ;;
      --force) force=1 ;;
      *) die "update: unknown option $1" ;;
    esac
    shift
  done
  detect_platform
  MODE=$(state_get mode)
  MODE=${MODE:-user}
  [[ -x "$OWN/current/bin/agentnetd" ]] || die "AgentNet wasn't installed by this script ($OWN/current is missing)."
  cur=$(installed_version)
  prev=$(readlink -f "$OWN/current")
  if [[ -n "$archive" ]]; then
    # From the app: the daemon already checked the archive against the signed manifest.
    [[ -f "$archive" && -n "$version" ]] || die "update --archive needs an existing file and --version."
    replace_release "$archive" "$version"
    ok "AgentNet $cur → $version (files replaced)"
  else
    resolve_release
    if [[ "$cur" == "$VER" ]] && ((!force)); then
      ok "AgentNet $cur is the newest release."
      return 0
    fi
    head1 "Update AgentNet ${cur:-?} → $VER"
    do_app || die "Download, check or unpacking failed; AgentNet ${cur:-} is unchanged."
    ok "Installed AgentNet $VER"
    if [[ -n "$DESKTOP_DEB" && -n "$(state_get desktop_pkg)" ]]; then
      MODE=system
      info "The desktop window is a system package. To update it too, run:"
      show_cmds "$(cmds_desktop)"
    elif [[ -n "$DESKTOP_DEB" ]] && was_installed desktop; then
      MODE=user
      run_snippet "$(cmds_desktop)" && ok "Desktop window updated"
    fi
  fi
  if ((restart)); then restart_service "$prev"; fi
  return 0
}

# ---- uninstall ------------------------------------------------------------------------------------------------------
uninstall_main() {
  local purge=0 b list="AgentNet" pkg
  [[ "${1:-}" == --purge ]] && purge=1
  detect_platform
  head1 "Uninstall AgentNet"
  if was_installed service; then list+=", the user service"; fi
  if was_installed desktop; then list+=", the desktop window"; fi
  if was_installed uv; then list+=", uv"; fi
  if was_installed bd; then list+=", bd"; fi
  if was_installed mail; then list+=", MCP Agent Mail"; fi
  if was_installed nats; then list+=", nats-server"; fi
  say "This removes what the installer put in place: $list."
  say "Claude Code, git, curl and bubblewrap stay (other programs may use them)."
  if ((purge)); then
    warn "--purge: your AgentNet data in $DATA (projects list, history, agents' mail) is deleted too."
  else
    info "Your data in $DATA stays. (Add --purge to delete it too.)"
  fi
  yes_no "Go ahead?" n || exit 0

  if [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/$SERVICE.service" ]]; then
    systemctl --user disable --now "$SERVICE.service" 2>/dev/null || true
    rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/$SERVICE.service"
    systemctl --user daemon-reload 2>/dev/null || true
    ok "Removed the user service"
  fi
  for b in agentnetd agentnet agentnet-desktop; do
    if [[ -L "$BIN_DIR/$b" && "$(readlink "$BIN_DIR/$b")" == "$OWN"/* ]]; then rm -f "$BIN_DIR/$b"; fi
  done
  pkg=$(state_get desktop_pkg)
  if [[ -n "$pkg" ]] && dpkg-query -W "$pkg" >/dev/null 2>&1; then
    info "The desktop window is a system package; removing it needs root:"
    show_cmds "sudo apt-get remove -y $pkg"
    if yes_no "Run that now?" y; then sudo apt-get remove -y "$pkg" && ok "Removed $pkg"; fi
  fi
  if was_installed desktop; then
    rm -f "$SHARE/applications/agentnet.desktop"
    find "$SHARE/icons/hicolor" -name 'agentnet*.png' -delete 2>/dev/null || true
  fi
  if was_installed apparmor && [[ -f "$APPARMOR_PROFILE" ]]; then
    info "$APPARMOR_PROFILE lets bubblewrap work for every program, not only AgentNet."
    if yes_no "Remove it? (needs sudo)" n; then
      sudo apparmor_parser -R "$APPARMOR_PROFILE" 2>/dev/null || true
      sudo rm -f "$APPARMOR_PROFILE" && ok "Removed the AppArmor profile"
    fi
  fi
  if was_installed uv; then rm -f "$BIN_DIR/uv" "$BIN_DIR/uvx" && ok "Removed uv"; fi
  if was_installed bd; then rm -f "$BIN_DIR/bd" && ok "Removed bd"; fi
  if was_installed mail; then rm -rf "$MAIL_DIR" && ok "Removed MCP Agent Mail"; fi
  if was_installed nats; then rm -rf "$(dirname "$NATS_BIN")" && ok "Removed nats-server"; fi
  rmdir "$DATA/tools" 2>/dev/null || true
  if [[ "$(state_get rc_edited)" == yes && -f "$HOME/.bashrc" ]]; then
    sed -i "/$RC_MARK\$/d" "$HOME/.bashrc" && ok "Removed the PATH line from ~/.bashrc"
  fi
  rm -rf "$OWN"
  ok "Removed AgentNet ($OWN)"
  if ((purge)); then rm -rf "$DATA" && ok "Deleted $DATA"; fi
  ok "AgentNet is uninstalled."
}

# ---- main -----------------------------------------------------------------------------------------------------------
if [[ "$(id -u)" -eq 0 ]]; then
  die "Don't run this script as root or with sudo. Run it as yourself; it asks for sudo only where needed."
fi
cmd="${1:-install}"
(($#)) && shift
case "$cmd" in
  install) install_main ;;
  doctor) doctor ;;
  update) update_main "$@" ;;
  uninstall) uninstall_main "$@" ;;
  -h | --help | help) sed -n '2,15p' "${BASH_SOURCE[0]:-install.sh}" | sed 's/^# \{0,1\}//' ;;
  *) die "Unknown command: $cmd (use install, doctor, update or uninstall)" ;;
esac
