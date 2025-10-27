#!/usr/bin/env bash
set -euo pipefail

# ====== Config (editable) =====================================================
PROTON_GE_VER="GE-Proton10-22"
PROTON_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_GE_VER}/${PROTON_GE_VER}.tar.gz"

WINROOT="/Windows"
RUNNERS_DIR="${WINROOT}/Proton/runners"
FAKE_STEAM="${WINROOT}/Proton/fake-steam"
PREFIX_DIR="${WINROOT}/Proton/system"

WIN_C="${WINROOT}/drive_c"
WIN_USER_LINUX="${SUDO_USER:-$USER}"    # Actual user if running with sudo
LINUX_HOME="$(getent passwd "${WIN_USER_LINUX}" | cut -d: -f6)"
WIN_USER_DIR="${WIN_C}/Users/${WIN_USER_LINUX}"

WINRUN_PATH="/usr/local/bin/winrun"
DESKTOP_SYS="/usr/share/applications/winrun.desktop"
DESKTOP_USER="${LINUX_HOME}/.local/share/applications/winrun.desktop"

# Required packages (adjust if needed)
PKGS_I386=(
  libc6:i386 libstdc++6:i386 libgcc-s1:i386
  libx11-6:i386 libxext6:i386 libxrender1:i386 libxrandr2:i386 libxi6:i386 libxfixes3:i386
  libgl1:i386 libglu1-mesa:i386 libvulkan1:i386 mesa-vulkan-drivers:i386
  libfreetype6:i386 libfontconfig1:i386
  libasound2-plugins:i386 libpulse0:i386 libopenal1:i386 libvorbis0a:i386 libogg0:i386
  libkrb5-3:i386 libgnutls30:i386 libpng16-16:i386 zlib1g:i386
  # Optional:
  wine32:i386 libdrm2:i386 libxcb1:i386 libxcomposite1:i386 libxinerama1:i386 libxcursor1:i386
)
PKGS_MISC=(wget tar xdg-utils desktop-file-utils)

# ====== Utility functions =====================================================
info()  { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()   { printf '\033[1;31m[✗]\033[0m %s\n' "$*"; exit 1; }

need_root() {
  if [[ $EUID -ne 0 ]]; then
    die "Please run as root (sudo)."
  fi
}

ensure_owner() {
  chown -R "${WIN_USER_LINUX}:${WIN_USER_LINUX}" "$1"
}

# ====== Pre-flight checks =====================================================
need_root

for p in "${PKGS_MISC[@]}"; do
  dpkg -s "$p" >/dev/null 2>&1 || MISSING_MISC=1
done
if [[ -n "${MISSING_MISC:-}" ]]; then
  info "Installing helper tools (wget, tar, xdg-utils, desktop-file-utils)…"
  apt-get update
  apt-get install -y "${PKGS_MISC[@]}"
fi

# ====== 1) Create Windows/Proton structure ====================================
info "Creating Windows-like directory structure under ${WINROOT}…"
mkdir -p "${WINROOT}/Proton"{/runners,/fake-steam,/system/pfx/dosdevices}
mkdir -p "${WIN_C}"/{Program\ Files,Program\ Files\ \(x86\),Users}
ensure_owner "${WINROOT}"

if [[ ! -e "${WIN_USER_DIR}" ]]; then
  ln -s "${LINUX_HOME}" "${WIN_USER_DIR}"
fi
sudo -u "${WIN_USER_LINUX}" mkdir -p "${WIN_USER_DIR}/AppData"/{Local,Roaming,Temp}

# ====== 2) Download Proton-GE ================================================
info "Downloading Proton-GE ${PROTON_GE_VER} if missing…"
mkdir -p "${RUNNERS_DIR}"
if [[ ! -d "${RUNNERS_DIR}/${PROTON_GE_VER}" ]]; then
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  wget -O "${TMP_DIR}/${PROTON_GE_VER}.tar.gz" "${PROTON_URL}"
  tar -C "${TMP_DIR}" -xvf "${TMP_DIR}/${PROTON_GE_VER}.tar.gz"
  # The archive extracts to ${PROTON_GE_VER}
  mv "${TMP_DIR}/${PROTON_GE_VER}" "${RUNNERS_DIR}/"
fi
ensure_owner "${RUNNERS_DIR}"

# ====== 3) winrun script ======================================================
info "Installing ${WINRUN_PATH} launcher…"
cat > "${WINRUN_PATH}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

PROTON_RUNNER=/Windows/Proton/runners/GE-Proton10-22/proton
FAKE_STEAM=/Windows/Proton/fake-steam
PREFIX_DIR=/Windows/Proton/system

# Locale & X11 session
export LANG=fr_FR.UTF-8
export LC_ALL=fr_FR.UTF-8
export DISPLAY=${DISPLAY:-:0}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}

# Proton/Steam environment
export STEAM_COMPAT_DATA_PATH="$PREFIX_DIR"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$FAKE_STEAM"

# Optional tweaks
export PROTON_NO_ESYNC=0
export PROTON_NO_FSYNC=0
export DXVK_ASYNC=1

# Nautilus may wrap the file path in single quotes; clean and cd into its directory
if [[ $# -ge 1 ]]; then
  CLEAN="$1"
  CLEAN="${CLEAN#\'}"; CLEAN="${CLEAN%\'}"
  FILEPATH="$(realpath -- "$CLEAN")"
  FILEDIR="$(dirname -- "$FILEPATH")"
  cd "$FILEDIR"
fi

exec "$PROTON_RUNNER" run "$@"
EOF
chmod +x "${WINRUN_PATH}"

# ====== 4) Proton prefix reorganization ======================================
info "Linking Proton prefix drive_c to ${WIN_C}…"
if [[ -d "${PREFIX_DIR}/pfx/drive_c" && ! -L "${PREFIX_DIR}/pfx/drive_c" ]]; then
  # Minimal recovery if already present
  rm -rf "${PREFIX_DIR}/pfx/drive_c/users/" || true
  mv -f "${PREFIX_DIR}/pfx/drive_c/"* "${WIN_C}/" || true
  rm -rf "${PREFIX_DIR}/pfx/drive_c"
fi
ln -sf "${WIN_C}" "${PREFIX_DIR}/pfx/drive_c"
ensure_owner "${PREFIX_DIR}"

# ====== 5) i386 dependencies ==================================================
info "Enabling i386 architecture and installing 32-bit dependencies…"
dpkg --print-foreign-architectures | grep -q '^i386$' || dpkg --add-architecture i386
apt-get update
apt-get install -y "${PKGS_I386[@]}"
apt-get -y upgrade

# ====== 6) .desktop + MIME association ========================================
info "Installing desktop entry and MIME associations…"
install -d "$(dirname "${DESKTOP_USER}")"
tee "${DESKTOP_SYS}" > /dev/null <<'E0F'
[Desktop Entry]
Name=Windows Application
Comment=Run Windows executables via Proton
Exec=bash -lc '/usr/local/bin/winrun "%f"'
Type=Application
MimeType=application/x-ms-dos-executable;application/x-msdownload;
Icon=application-x-msdownload
Categories=Utility;
StartupNotify=true
NoDisplay=false
Terminal=false
E0F

# Copy for the user (GNOME often loads from this location first)
cp -f "${DESKTOP_SYS}" "${DESKTOP_USER}"
chmod +x "${DESKTOP_USER}"
chown "${WIN_USER_LINUX}:${WIN_USER_LINUX}" "${DESKTOP_USER}"

# Register MIME associations
xdg-mime install --novendor "${DESKTOP_SYS}" || true
xdg-mime default winrun.desktop application/x-ms-dos-executable
xdg-mime default winrun.desktop application/x-msdownload

# Refresh desktop databases
sudo -u "${WIN_USER_LINUX}" update-desktop-database "$(dirname "${DESKTOP_USER}")" || true
update-desktop-database /usr/share/applications/ || true

info "Installation complete."

cat <<'TIP'

Tips:
- If a downloaded .exe has the executable bit set, Nautilus may try to run it as a native ELF binary.
  You can clear it so the MIME handler is used:
      chmod -x /path/to/file.exe

- Test from terminal:
      xdg-open /path/to/file.exe
  Then try double-clicking it in the file manager.

- Optional: configure Proton manually
      /Windows/Proton/runners/GE-Proton10-22/proton run winecfg
      /Windows/Proton/runners/GE-Proton10-22/proton run wineboot -i

TIP
