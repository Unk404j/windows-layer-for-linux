# Windows-Layer-For-Linux (Proton based) — Run Windows Executables Without Steam

*(Ubuntu 24.04.3 LTS – Proton-GE Compatibility Layer)*

---

## Overview

**Proton Layer** provides a lightweight, Steam-free Proton-GE environment that allows `.exe` files to be executed directly on Ubuntu by double-clicking them — just like on Windows.
It uses the same compatibility stack as Steam Play (Proton GE) but runs completely standalone.

---

## Features

* Run any `.exe` directly from Nautilus or another file manager
* No Steam dependency
* Fully isolated environment under `/Windows`
* Works with both 32-bit and 64-bit software
* Optional Wine configuration (`winecfg`, `wineboot`)
* Clean uninstall and MIME integration

---

## 1 – Create the Windows-like Directory Structure

```bash
WIN_USER=${SUDO_USER:-$USER}

sudo mkdir -p /Windows/Proton/{runners,fake-steam,system/pfx/dosdevices}
sudo mkdir -p /Windows/drive_c/{Program\ Files,Program\ Files\ \(x86\),Users}
sudo chown -R "$WIN_USER:$WIN_USER" /Windows

# Link Linux home directory as Windows user
sudo ln -s "/home/${WIN_USER}" "/Windows/drive_c/Users/${WIN_USER}"
sudo -u "$WIN_USER" mkdir -p "/Windows/drive_c/Users/${WIN_USER}/AppData"/{Local,Roaming,Temp}
```

---

## 2 – Install Proton-GE

```bash
wget https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton10-22/GE-Proton10-22.tar.gz

# Optional but recommended: verify the archive (replace <sha256> with the value from GitHub).
echo "<sha256>  GE-Proton10-22.tar.gz" | sha256sum -c -

tar -xvf GE-Proton10-22.tar.gz
rm GE-Proton10-22.tar.gz

# Create/refresh a stable pointer to the active Proton runner
ln -sfn /Windows/Proton/runners/GE-Proton10-22 /Windows/Proton/runners/current
```

---

## 3 – Initialize the Proton Environment

```bash
export STEAM_COMPAT_DATA_PATH=/Windows/Proton/system
export STEAM_COMPAT_CLIENT_INSTALL_PATH=/Windows/Proton/fake-steam
```

To configure Proton manually:

```bash
/Windows/Proton/runners/current/proton run winecfg
# or
/Windows/Proton/runners/current/proton run wineboot -i
```

---

## 4 – Create the Universal Launcher Script (`winrun`)

```bash
sudo nano /usr/local/bin/winrun
```

Paste:

```bash
#!/bin/bash
set -euo pipefail

PROTON_ROOT=/Windows/Proton
PROTON_RUNNER="${PROTON_ROOT}/runners/current/proton"
FAKE_STEAM="${PROTON_ROOT}/fake-steam"
PREFIX_DIR="${PROTON_ROOT}/system"

if [[ -z "${LANG:-}" ]]; then
    export LANG=C.UTF-8
fi
export DISPLAY="${DISPLAY:-:0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export STEAM_COMPAT_DATA_PATH="$PREFIX_DIR"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$FAKE_STEAM"
export PROTON_NO_ESYNC=0
export PROTON_NO_FSYNC=0
export DXVK_ASYNC=1

# Clean Nautilus-provided path and change directory
if [[ -n "$1" ]]; then
    FILEPATH=$(echo "$1" | sed "s/^'//;s/'$//")
    FILEPATH=$(realpath -- "$FILEPATH")
    FILEDIR=$(dirname -- "$FILEPATH")
    cd "$FILEDIR" || exit 1
fi

exec "$PROTON_RUNNER" run "$@"
```

Then make it executable:

```bash
sudo chmod +x /usr/local/bin/winrun
```

---

## 5 – Reorganize Proton Prefix

```bash
rm -rf /Windows/Proton/system/pfx/drive_c/users/
mv /Windows/Proton/system/pfx/drive_c/* /Windows/drive_c/
rm -rf /Windows/Proton/system/pfx/drive_c/
ln -s /Windows/drive_c /Windows/Proton/system/pfx/drive_c
```

---

## 6 – Install Required 32-bit Libraries

Enable multi-architecture support:

```bash
sudo dpkg --add-architecture i386
sudo apt update
```

Install dependencies:

```bash
# Core system libraries
sudo apt install -y libc6:i386 libstdc++6:i386 libgcc-s1:i386

# X11 / display
sudo apt install -y libx11-6:i386 libxext6:i386 libxrender1:i386 libxrandr2:i386 libxi6:i386 libxfixes3:i386

# OpenGL / 3D
sudo apt install -y libgl1:i386 libglu1-mesa:i386 libvulkan1:i386 mesa-vulkan-drivers:i386

# Fonts and text rendering
sudo apt install -y libfreetype6:i386 libfreetype6:amd64 libfontconfig1:i386 libfontconfig1:amd64

# Audio and multimedia
sudo apt install -y libasound2-plugins:i386 libpulse0:i386 libopenal1:i386 libvorbis0a:i386 libogg0:i386

# Networking and compression
sudo apt install -y libkrb5-3:i386 libgnutls30:i386 libpng16-16:i386 zlib1g:i386

# Optional: maximum Wine compatibility
sudo apt install -y wine32:i386

# Optional: additional graphics runtimes
sudo apt install -y libdrm2:i386 libxcb1:i386 libxcomposite1:i386 libxinerama1:i386 libxcursor1:i386

sudo apt update
# Optional: perform a full upgrade once you reviewed the changes
# sudo apt upgrade -y
```

---

## 7 – Create the `.desktop` Launcher

```bash
sudo tee /usr/share/applications/winrun.desktop > /dev/null << 'E0F'
[Desktop Entry]
Name=Windows Application
Comment=Run Windows executables via Proton
Exec=/usr/local/bin/winrun %F
TryExec=/usr/local/bin/winrun
Type=Application
MimeType=application/x-ms-dos-executable;application/x-msdownload;application/vnd.microsoft.portable-executable;application/x-msi;
Icon=application-x-msdownload
Categories=Utility;
StartupNotify=true
NoDisplay=false
Terminal=false
E0F
```

Register MIME handlers:

```bash
xdg-mime install --novendor /usr/share/applications/winrun.desktop
xdg-mime default winrun.desktop application/x-ms-dos-executable
xdg-mime default winrun.desktop application/x-msdownload

mkdir -p ~/.local/share/applications
cp /usr/share/applications/winrun.desktop ~/.local/share/applications/
chmod +x ~/.local/share/applications/winrun.desktop
xdg-mime install --novendor ~/.local/share/applications/winrun.desktop
xdg-mime default winrun.desktop application/vnd.microsoft.portable-executable
xdg-mime default winrun.desktop application/x-msi
update-desktop-database ~/.local/share/applications/
sudo update-desktop-database /usr/share/applications/
```

---

## 8 – Usage

* **Double-click** any `.exe` → launches automatically via Proton-GE, even if the file keeps its executable bit.
* **Right-click → Open With → Windows Application** also works.
* Paths with spaces, accents, parentheses, or `file://` URIs are cleaned automatically before Proton runs.

---

## Troubleshooting

If nothing happens when double-clicking an `.exe`:

1. Confirm that `winrun.desktop` is listed as the default handler:

   ```bash
   xdg-mime query default application/x-ms-dos-executable
   xdg-mime query default application/x-msdownload
   ```
   Both commands should return `winrun.desktop`. If not, rerun the MIME registration commands above **as your desktop user**.
2. Check logs with:

   ```bash
   journalctl --user -f
   ```
3. Inspect `/usr/local/bin/winrun` and ensure it is executable (`chmod +x /usr/local/bin/winrun`).

---

## Uninstall / Cleanup

To remove the layer completely:

```bash
sudo rm -f /usr/share/applications/winrun.desktop
rm -f ~/.local/share/applications/winrun.desktop
sudo rm -f /usr/local/bin/winrun
sudo rm -rf /Windows
sed -i '/winrun.desktop/d' ~/.config/mimeapps.list 2>/dev/null || true
sudo update-desktop-database /usr/share/applications 2>/dev/null || true
update-desktop-database ~/.local/share/applications 2>/dev/null || true
```

This removes the launcher, MIME associations, and Proton files so `.exe` files revert to the desktop’s default handler.

---

## License

This project is released under the [MIT License](LICENSE).

---

## Credits

* **Proton-GE** by [GloriousEggroll](https://github.com/GloriousEggroll)
* Script and integration by **Julien Pablo**
* Thanks to *markp-fuso* on SuperUser for valuable suggestions about `.desktop` execution contexts.

---
