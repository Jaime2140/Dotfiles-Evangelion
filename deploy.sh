#!/bin/bash

echo "Iniciando despliegue táctico: Automatizando entorno MAGI..."
echo "---------------------------------------------------"

sudo pacman -S --noconfirm base-devel git ttf-jetbrains-mono-nerd papirus-icon-theme qt5ct qt6ct hyprpaper swaync waybar rofi-wayland kitty fastfetch rsync

if ! command -v yay &> /dev/null; then
    echo "[ OK ] Instalando YAY..."
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm
    cd - > /dev/null
fi

echo "[ OK ] Instalando cursores y librerías de color..."
yay -S --noconfirm catppuccin-cursors-mocha papirus-folders

echo "[ OK ] Configurando bypass de contraseña para cambio de iconos..."
echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/papirus-folders" | sudo tee /etc/sudoers.d/papirus-folders > /dev/null
sudo chmod 0440 /etc/sudoers.d/papirus-folders

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

declare -A carpetas=(
    ["hypr"]="$HOME/.config/hypr"
    ["themes"]="$HOME/.config/themes"
    ["gtk-theme"]="$HOME/.themes"
    ["sddm-theme/eva"]="/usr/share/sddm/themes/eva"
)

for repo_folder in "${!carpetas[@]}"; do
    origen="$REPO_DIR/$repo_folder"
    destino="${carpetas[$repo_folder]}"
    if [ -d "$origen" ]; then
        padre="$(dirname "$destino")"
        if [[ "$destino" == /usr/share/* ]]; then
            sudo mkdir -p "$padre"
            sudo rsync -a "$origen/" "$destino/"
        else
            mkdir -p "$padre"
            rsync -a "$origen/" "$destino/"
        fi
    fi
done

if [ -d "/usr/share/sddm/themes/eva/assets" ]; then
    sudo chown -R $USER:$USER /usr/share/sddm/themes/eva/assets
fi

TEMA="Eva01"
CURSOR="catppuccin-mocha-mauve-cursors"

apps_espejo=("fastfetch" "kitty" "qt5ct" "qt6ct" "rofi" "swaync" "waybar" "wlogout")
for app in "${apps_espejo[@]}"; do
    rm -rf "$HOME/.config/$app"
    [ -d "$HOME/.config/themes/$TEMA/$app" ] && ln -s "$HOME/.config/themes/$TEMA/$app" "$HOME/.config/$app"
done

ln -sf "$HOME/.config/themes/$TEMA/colors.conf" "$HOME/.config/hypr/colors.conf"
ln -sf "$HOME/.config/themes/$TEMA/hyprpaper.conf" "$HOME/.config/hypr/hyprpaper.conf"

mkdir -p "$HOME/.config/gtk-4.0"
rm -f "$HOME/.config/gtk-4.0/gtk.css"
rm -rf "$HOME/.config/gtk-4.0/assets"
[ -f "$HOME/.themes/$TEMA/gtk-4.0/gtk.css" ] && ln -s "$HOME/.themes/$TEMA/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
[ -d "$HOME/.themes/$TEMA/gtk-4.0/assets" ] && ln -s "$HOME/.themes/$TEMA/gtk-4.0/assets" "$HOME/.config/gtk-4.0/assets"

mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
cat <<EOF > "$HOME/.config/gtk-3.0/settings.ini"
[Settings]
gtk-theme-name=$TEMA
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=JetBrainsMono Nerd Font 11
gtk-cursor-theme-name=$CURSOR
gtk-application-prefer-dark-theme=1
EOF
cp "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"

sudo papirus-folders -C violet --theme Papirus-Dark

mkdir -p ~/.icons/default
echo -e "[Icon Theme]\nInherits=$CURSOR" > ~/.icons/default/index.theme

gsettings set org.gnome.desktop.interface gtk-theme "$TEMA"
gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR"
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"

if [ -f "$HOME/.config/themes/$TEMA/background.jpg" ]; then
    cp -f "$HOME/.config/themes/$TEMA/background.jpg" "/usr/share/sddm/themes/eva/assets/background.jpg"
    chmod 644 "/usr/share/sddm/themes/eva/assets/background.jpg"
fi

echo "---------------------------------------------------"
echo "¡Despliegue completado! Sistema MAGI inicializado."
echo "Reinicia la computadora o inicia Hyprland para ver los resultados."