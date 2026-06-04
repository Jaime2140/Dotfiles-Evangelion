#!/bin/bash

THEMES_DIR="$HOME/.config/themes"

if [ -z "$1" ]; then
    opciones=$(find "$THEMES_DIR" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort)
    SELECTOR_ACTIVO=$(ls "$HOME/.config/rofi/"*Selector.rasi 2>/dev/null | head -n 1)
    [ -z "$SELECTOR_ACTIVO" ] && SELECTOR_ACTIVO="$HOME/.config/themes/Eva01/rofi/Eva01Selector.rasi"
    TEMA_ELEGIDO=$(echo -e "$opciones" | rofi -dmenu -i -p "Seleccionar Tema" -theme "$SELECTOR_ACTIVO")
    [ -z "$TEMA_ELEGIDO" ] && exit 0
    TEMA="$TEMA_ELEGIDO"
else
    TEMA="$1"
fi

case "$TEMA" in
    *Eva02*) COLOR_ICONOS="red";    CURSOR="catppuccin-mocha-red-cursors" ;;
    *)       COLOR_ICONOS="violet"; CURSOR="catppuccin-mocha-mauve-cursors" ;;
esac

sudo papirus-folders -C "$COLOR_ICONOS" --theme Papirus-Dark

apps_espejo=("fastfetch" "kitty" "qt5ct" "qt6ct" "rofi" "swaync" "waybar" "wlogout")
for app in "${apps_espejo[@]}"; do
    rm -rf "$HOME/.config/$app"
    [ -d "$THEMES_DIR/$TEMA/$app" ] && ln -s "$THEMES_DIR/$TEMA/$app" "$HOME/.config/$app"
done

ln -sf "$THEMES_DIR/$TEMA/colors.conf" "$HOME/.config/hypr/colors.conf"
ln -sf "$THEMES_DIR/$TEMA/hyprpaper.conf" "$HOME/.config/hypr/hyprpaper.conf"

rm -f "$HOME/.config/gtk-4.0/gtk.css"
rm -rf "$HOME/.config/gtk-4.0/assets"
[ -f "$HOME/.themes/$TEMA/gtk-4.0/gtk.css" ] && ln -s "$HOME/.themes/$TEMA/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
[ -d "$HOME/.themes/$TEMA/gtk-4.0/assets" ] && ln -s "$HOME/.themes/$TEMA/gtk-4.0/assets" "$HOME/.config/gtk-4.0/assets"

for v in 3.0 4.0; do
    [ -f "$HOME/.config/gtk-$v/settings.ini" ] && sed -i "s/gtk-theme-name=.*/gtk-theme-name=$TEMA/" "$HOME/.config/gtk-$v/settings.ini"
done

gsettings set org.gnome.desktop.interface gtk-theme "$TEMA"
gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR"
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"

hyprctl setcursor "$CURSOR" 24

hyprctl reload
killall waybar && waybar > /dev/null 2>&1 &
swaync-client -rs
killall hyprpaper && nohup hyprpaper -c "$HOME/.config/hypr/hyprpaper.conf" > /dev/null 2>&1 &
pkill -USR1 kitty
nautilus -q

IMG_SDDM_ORIGEN="$THEMES_DIR/$TEMA/background.jpg"
IMG_SDDM_DESTINO="/usr/share/sddm/themes/eva/assets/background.jpg"

if [ -f "$IMG_SDDM_ORIGEN" ]; then
    cp -f "$IMG_SDDM_ORIGEN" "$IMG_SDDM_DESTINO"
    
    chmod 644 "$IMG_SDDM_DESTINO"
fi

echo "[ OK ] Tema: $TEMA | Sistema actualizado."