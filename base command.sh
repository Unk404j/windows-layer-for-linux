---

## Installation et configuration de Proton sans Steam

*(Ubuntu 22.04 — compatibilité Windows via Proton-GE)*

---

### 1. Création de l’arborescence système Windows simulée

```bash
WIN_USER=${SUDO_USER:-$USER}

sudo mkdir -p /Windows/Proton/{runners,fake-steam,system/pfx/dosdevices}
sudo mkdir -p /Windows/drive_c/{Program\ Files,Program\ Files\ \(x86\),Users}
sudo chown -R "$WIN_USER:$WIN_USER" /Windows

# Lien symbolique de l’utilisateur Windows vers le compte Linux
sudo ln -s "/home/${WIN_USER}" "/Windows/drive_c/Users/${WIN_USER}"
sudo -u "$WIN_USER" mkdir -p "/Windows/drive_c/Users/${WIN_USER}/AppData"/{Local,Roaming,Temp}
```

---

### 2. Installation de Proton-GE (version GE-Proton10-22)

```bash
wget https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton10-22/GE-Proton10-22.tar.gz

# Optionnel mais recommandé : vérifier l’archive (remplacez <sha256> par la valeur officielle).
echo "<sha256>  GE-Proton10-22.tar.gz" | sha256sum -c -

tar -xvf GE-Proton10-22.tar.gz
rm GE-Proton10-22.tar.gz

# Créer/mettre à jour un lien stable vers le runner actif
ln -sfn /Windows/Proton/runners/GE-Proton10-22 /Windows/Proton/runners/current
```

---

### 3. Initialisation de Proton

```bash
export STEAM_COMPAT_DATA_PATH=/Windows/Proton/system
export STEAM_COMPAT_CLIENT_INSTALL_PATH=/Windows/Proton/fake-steam
```

Configuration possible (au choix) :

```bash
/Windows/Proton/runners/current/proton run winecfg
# ou
/Windows/Proton/runners/current/proton run wineboot -i
```

---

### 4. Script `winrun` — Lanceur universel Proton

Créer le script :

```bash
sudo nano /usr/local/bin/winrun
```

Contenu :

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

# Nettoyage du chemin envoyé par Nautilus
if [[ -n "$1" ]]; then
    FILEPATH=$(echo "$1" | sed "s/^'//;s/'$//")
    FILEPATH=$(realpath -- "$FILEPATH")
    FILEDIR=$(dirname -- "$FILEPATH")
    cd "$FILEDIR" || exit 1
fi

exec "$PROTON_RUNNER" run "$@"
```

Rendre le script exécutable :

```bash
sudo chmod +x /usr/local/bin/winrun
```

---

### 5. Réorganisation du préfixe Proton

```bash
rm -rf /Windows/Proton/system/pfx/drive_c/users/
mv /Windows/Proton/system/pfx/drive_c/* /Windows/drive_c/
rm -rf /Windows/Proton/system/pfx/drive_c/
ln -s /Windows/drive_c /Windows/Proton/system/pfx/drive_c
```

---

### 6. Installation des bibliothèques 32 bits nécessaires

Activation du support multi-architecture :

```bash
sudo dpkg --add-architecture i386
sudo apt update
```

Installation des bibliothèques essentielles :

```bash
# Librairies système de base
sudo apt install -y libc6:i386 libstdc++6:i386 libgcc-s1:i386

# Librairies X11 / affichage graphique
sudo apt install -y libx11-6:i386 libxext6:i386 libxrender1:i386 libxrandr2:i386 libxi6:i386 libxfixes3:i386

# Librairies OpenGL / rendu 3D
sudo apt install -y libgl1:i386 libglu1-mesa:i386 libvulkan1:i386 mesa-vulkan-drivers:i386

# Librairies de polices et rendu texte
sudo apt install -y libfreetype6:i386 libfreetype6:amd64 libfontconfig1:i386 libfontconfig1:amd64

# Librairies audio et multimédia
sudo apt install -y libasound2-plugins:i386 libpulse0:i386 libopenal1:i386 libvorbis0a:i386 libogg0:i386

# Librairies réseau et compression
sudo apt install -y libkrb5-3:i386 libgnutls30:i386 libpng16-16:i386 zlib1g:i386

# (Optionnel) Compatibilité maximale avec Wine 32 bits
sudo apt install -y wine32:i386

# (Optionnel) Runtime graphique complémentaire
sudo apt install -y libdrm2:i386 libxcb1:i386 libxcomposite1:i386 libxinerama1:i386 libxcursor1:i386

# Mise à jour finale
sudo apt update
# Optionnel : lancer la mise à niveau complète après revue des paquets
# sudo apt upgrade -y
```

---

### 7. Création de l’entrée de menu et association `.exe`

Créer le lanceur :

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

Enregistrer le gestionnaire MIME :

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

### 8. Utilisation

* **Double-cliquez** sur n’importe quel `.exe` → lancement automatique via Proton-GE, même si le fichier conserve son bit exécutable.
* **Clic droit → Ouvrir avec → Windows Application** fonctionne aussi.
* Les chemins comportant espaces, accents, parenthèses ou des URI `file://` sont nettoyés automatiquement avant l’exécution.

---

### 9. Désinstallation / nettoyage

```bash
sudo rm -f /usr/share/applications/winrun.desktop
rm -f ~/.local/share/applications/winrun.desktop
sudo rm -f /usr/local/bin/winrun
sudo rm -rf /Windows
sed -i '/winrun.desktop/d' ~/.config/mimeapps.list 2>/dev/null || true
sudo update-desktop-database /usr/share/applications 2>/dev/null || true
update-desktop-database ~/.local/share/applications 2>/dev/null || true
```

Ces commandes retirent Proton, le lanceur et les associations `.exe` pour revenir au comportement initial de votre environnement de bureau.

---
