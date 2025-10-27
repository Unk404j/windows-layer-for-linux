---

## Installation et configuration de Proton sans Steam

*(Ubuntu 22.04 — compatibilité Windows via Proton-GE)*

---

### 1. Création de l’arborescence système Windows simulée

```bash
sudo mkdir -p /Windows/Proton/{runners,fake-steam,system/pfx/dosdevices}
sudo mkdir -p /Windows/drive_c/{Program\ Files,Program\ Files\ \(x86\),Users}
sudo chown -R $USER:$USER /Windows

# Lien symbolique de l’utilisateur Windows vers le compte Linux
sudo ln -s /home/julien /Windows/drive_c/Users/julien
mkdir -p /Windows/drive_c/Users/julien/AppData/{Local,Roaming,Temp}
```

---

### 2. Installation de Proton-GE (version GE-Proton10-22)

```bash
wget https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton10-22/GE-Proton10-22.tar.gz
tar -xvf GE-Proton10-22.tar.gz
rm GE-Proton10-22.tar.gz
```

---

### 3. Initialisation de Proton

```bash
export STEAM_COMPAT_DATA_PATH=/Windows/Proton/system
export STEAM_COMPAT_CLIENT_INSTALL_PATH=/Windows/Proton/fake-steam
```

Configuration possible (au choix) :

```bash
/Windows/Proton/runners/GE-Proton10-22/proton run winecfg
# ou
/Windows/Proton/runners/GE-Proton10-22/proton run wineboot -i
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

# Nettoyage du chemin envoyé par Nautilus
if [ -n "$1" ]; then
    FILEPATH=$(echo "$1" | sed "s/^'//;s/'$//")
    FILEPATH=$(realpath "$FILEPATH")
    FILEDIR=$(dirname "$FILEPATH")
    cd "$FILEDIR" || exit 1
fi

"$PROTON_RUNNER" run "$@"
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
sudo apt update && sudo apt upgrade -y
```

---

### 7. Création de l’entrée de menu et association `.exe`

Créer le lanceur :

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

Enregistrer le gestionnaire MIME :

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

### 8. Utilisation

* **Double-clique** sur n’importe quel `.exe` → il se lancera automatiquement via Proton-GE.
* **Clic droit → Ouvrir avec** fonctionne aussi.
* Le script passe par `bash -lc` pour bénéficier d’un environnement complet (évite les erreurs d’affichage ou de cache de polices).

---
