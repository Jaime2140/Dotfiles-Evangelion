#!/bin/bash

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Iniciando despliegue táctico en el nuevo sistema..."
echo "---------------------------------------------------"

declare -A carpetas=(
    ["fastfetch"]="$HOME/.config/fastfetch"
    ["hypr"]="$HOME/.config/hypr"
    ["kitty"]="$HOME/.config/kitty"
    ["rofi"]="$HOME/.config/rofi"
    ["swaync"]="$HOME/.config/swaync"
    ["waybar"]="$HOME/.config/waybar"
    ["wlogout"]="$HOME/.config/wlogout"
    ["qt5ct"]="$HOME/.config/qt5ct"
    ["qt6ct"]="$HOME/.config/qt6ct"
    ["gtk-theme/Eva"]="$HOME/.themes/Eva"
    ["sddm-theme/eva"]="/usr/share/sddm/themes/eva"
)

for repo_folder in "${!carpetas[@]}"; do
    origen="$REPO_DIR/$repo_folder"
    destino="${carpetas[$repo_folder]}"
    
    if [ -d "$origen" ]; then
        echo "[ OK ] Instalando: $repo_folder -> $destino"
        
        padre="$(dirname "$destino")"
        
        if [[ "$destino" == /usr/share/* ]]; then
            sudo mkdir -p "$padre"
            sudo rsync -a "$origen/" "$destino/"
        else
            mkdir -p "$padre"
            rsync -a "$origen/" "$destino/"
        fi
    else
        echo "[ WARN ] Carpeta no encontrada en el repositorio: $repo_folder"
    fi
done

echo "---------------------------------------------------"
echo "¡Despliegue completado! El entorno MAGI ha sido restaurado."
echo ""
echo "RECORDATORIO TÁCTICO POST-INSTALACIÓN:"
echo "1. Fuentes: sudo pacman -S ttf-jetbrains-mono-nerd"
echo "2. Iconos base: sudo pacman -S papirus-icon-theme"
echo "3. Script de color: yay -S papirus-folders"
echo "4. Aplicar morado: papirus-folders -C violet --theme Papirus-Dark"
echo "5. Entorno Qt: sudo pacman -S qt5ct qt6ct"
echo "---------------------------------------------------"