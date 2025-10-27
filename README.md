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
sudo mkdir -p /Windows/Proton/{runners,fake-steam,system/pfx/dosdevices}
sudo mkdir -p /Windows/drive_c/{Program\ Files,Program\ Files\ \(x86\),Users}
sudo chown -R $USER:$USER /Windows

# Link Linux home directory as Windows user
sudo ln -s /home/julien /Windows/drive_c/Users/julien
mkdir -p /Windows/drive_c/Users/julien/AppData/{Local,Roaming,Temp}
```

---

## 2 – Install Proton-GE

```bash
wget https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton10-22/GE-Proton10-22.tar.gz
tar -xvf GE-Proton10-22.tar.gz
rm GE-Proton10-22.tar.gz
```

---

## 3 – Initialize the Proton Environment

```bash
export STEAM_COMPAT_DATA_PATH=/Windows/Proton/system
export STEAM_COMPAT_CLIENT_INSTALL_PATH=/Windows/Proton/fake-steam
```

To configure Proton manually:

```bash
/Windows/Proton/runners/GE-Proton10-22/proton run winecfg
# or
/Windows/Proton/runners/GE-Proton10-22/proton run wineboot -i
```

---

## 4 – Create the Universal Launcher Script (`winrun`)

```bash
sudo nano /usr/local/bin/winrun
```

Paste:

```bash
#!/bin/bash
PROTON_RUNNER=/Windows/Proton/runners/GE-Proton10-22/proton
FAKE_STEAM=/Windows/Proton/fake-steam
PREFIX_DIR=/Windows/Proton/system

export LANG=fr_FR.UTF-8
export LC_ALL=fr_FR.UTF-8
export DISPLAY=${DISPLAY:-:0}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export STEAM_COMPAT_DATA_PATH="$PREFIX_DIR"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$FAKE_STEAM"
export PROTON_NO_ESYNC=0
export PROTON_NO_FSYNC=0
export DXVK_ASYNC=1

# Clean Nautilus-provided path and change directory
if [ -n "$1" ]; then
    FILEPATH=$(echo "$1" | sed "s/^'//;s/'$//")
    FILEPATH=$(realpath "$FILEPATH")
    FILEDIR=$(dirname "$FILEPATH")
    cd "$FILEDIR" || exit 1
fi

"$PROTON_RUNNER" run "$@"
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

sudo apt update && sudo apt upgrade -y
```

---

## 7 – Create the `.desktop` Launcher

```bash
sudo tee /usr/share/applications/winrun.desktop > /dev/null << 'E0F'
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
```

Register MIME handlers:

```bash
xdg-mime install --novendor /usr/share/applications/winrun.desktop
xdg-mime default winrun.desktop application/x-ms-dos-executable
xdg-mime default winrun.desktop application/x-msdownload

mkdir -p ~/.local/share/applications
cp /usr/share/applications/winrun.desktop ~/.local/share/applications/
chmod +x ~/.local/share/applications/winrun.desktop
update-desktop-database ~/.local/share/applications/
sudo update-desktop-database /usr/share/applications/
```

---

## 8 – Usage

* **Double-click** any `.exe` → launches automatically via Proton-GE.
* **Right-click → Open With → Windows Application** also works.
* The `bash -lc` wrapper ensures a full login environment, avoiding missing variables like `$DISPLAY` or `$XDG_RUNTIME_DIR`.

---

## Troubleshooting

If nothing happens when double-clicking an `.exe`:

1. Ensure the file is **not executable** as a native binary:

   ```bash
   chmod -x file.exe
   ```
2. Check logs with:

   ```bash
   journalctl --user -f
   ```
3. Verify that `bash -lc` exists in your `.desktop` entry.

---

## License

This project is released under the [MIT License](LICENSE).

---

## Credits

* **Proton-GE** by [GloriousEggroll](https://github.com/GloriousEggroll)
* Script and integration by **Julien Pablo**
* Thanks to *markp-fuso* on SuperUser for valuable suggestions about `.desktop` execution contexts.

---
