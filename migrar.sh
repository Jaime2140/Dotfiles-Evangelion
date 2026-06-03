#!/bin/bash

echo "Iniciando construcción de la Bodega Táctica (Tema: Eva)..."
echo "---------------------------------------------------"

BODEGA="$HOME/.config/themes/Eva"
mkdir -p "$BODEGA"

# Lista exacta de tus carpetas visuales en .config (Excluyendo hypr)
carpetas_visuales=("fastfetch" "kitty" "qt5ct" "qt6ct" "rofi" "swaync" "waybar" "wlogout")

for app in "${carpetas_visuales[@]}"; do
    ORIGEN="$HOME/.config/$app"
    
    # Comprueba si la carpeta existe y NO es ya un enlace simbólico
    if [ -d "$ORIGEN" ] && [ ! -L "$ORIGEN" ]; then
        echo "[ OK ] Extrayendo ADN: $app -> $BODEGA/"
        mv "$ORIGEN" "$BODEGA/"
        
        echo "[ OK ] Creando espejo (Symlink) para: $app"
        ln -s "$BODEGA/$app" "$ORIGEN"
    else
        echo "[ WARN ] Omitiendo $app (No existe o ya es un espejo)."
    fi
done

echo "---------------------------------------------------"
echo "¡Migración completada! Tu sistema ahora es modular."