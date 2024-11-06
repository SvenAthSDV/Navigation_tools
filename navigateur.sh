#!/bin/bash

# Couleurs pour un meilleur affichage
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Variables globales
current_path=$(pwd)
selected_index=0
items=()

# Fonction pour récupérer l'utilisation CPU
get_cpu_usage() {
    local cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}')
    # Vérifier si cpu_idle est un nombre valide
    if [[ "$cpu_idle" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        local cpu_usage=$(echo "100 - $cpu_idle" | bc)
        echo "${cpu_usage}%"
    else
        echo "N/A"  # Affiche "N/A" si la valeur de cpu_idle est inattendue
    fi
}

# Fonction pour récupérer l'utilisation RAM
get_ram_usage() {
    local ram_info=$(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2 }')
    echo "$ram_info"
}

# Fonction pour récupérer l'espace disque disponible dans le répertoire actuel
get_disk_usage() {
    local disk_usage=$(df -h "$current_path" | awk 'NR==2 {print $4}')
    echo "$disk_usage"
}

# Fonction pour afficher la barre d'information système en haut à droite
display_system_info() {
    local cpu_usage=$(get_cpu_usage)
    local ram_usage=$(get_ram_usage)
    local disk_usage=$(get_disk_usage)

    # Positionnement en haut à droite
    tput sc                 # Sauvegarder la position actuelle du curseur
    tput cup 0 $(($(tput cols) - 40))  # Placer le curseur à la première ligne, 40 caractères avant la fin
    echo -e "${YELLOW}CPU: ${GREEN}$cpu_usage${NC}  ${YELLOW}RAM: ${GREEN}$ram_usage${NC}  ${YELLOW}Disque: ${GREEN}$disk_usage${NC}"
    tput rc                 # Restaurer la position du curseur
}

create_directory() {
    clear_screen
    echo -e "${YELLOW}Entrez le nom du nouveau dossier:${NC}"
    read -r folder_name
    if [ -n "$folder_name" ]; then
        if mkdir "$current_path/$folder_name"; then
            echo -e "${GREEN}Dossier $folder_name créé avec succès.${NC}"
        else
            echo -e "${RED}Échec de la création du dossier $folder_name.${NC}"
        fi
        read -n 1 -s -r -p "Appuyez sur une touche pour continuer..."
    fi
}

create_file() {
    clear_screen
    echo -e "${YELLOW}Entrez le nom du nouveau fichier:${NC}"
    read -r file_name
    if [ -n "$file_name" ]; then
        if touch "$current_path/$file_name"; then
            echo -e "${GREEN}Fichier $file_name créé avec succès.${NC}"
        else
            echo -e "${RED}Échec de la création du fichier $file_name.${NC}"
        fi
        read -n 1 -s -r -p "Appuyez sur une touche pour continuer..."
    fi
}
# Fonction pour supprimer un fichier ou dossier
delete_item() {
    if [ ${#items[@]} -gt 0 ]; then
        local selected_item="${items[$selected_index]}"
        local full_path="$current_path/$selected_item"
        
        # Confirmation de la suppression
        clear_screen
        echo -e "${RED}Voulez-vous vraiment supprimer ${YELLOW}$selected_item${RED} ? (o/n)${NC}"
        read -n 1 -r confirm
        echo ""
        
        if [[ $confirm =~ ^[Oo]$ ]]; then
            # Suppression du fichier ou du dossier
            if rm -rf "$full_path"; then
                echo -e "${GREEN}$selected_item supprimé avec succès.${NC}"
            else
                echo -e "${RED}Échec de la suppression de $selected_item.${NC}"
            fi
        else
            echo -e "${YELLOW}Suppression annulée.${NC}"
        fi
        read -n 1 -s -r -p "Appuyez sur une touche pour continuer..."
    fi
}


# Fonction pour formater le chemin actuel comme dans zsh
format_path() {
    local home_path="$HOME"
    if [[ "$current_path" == "$home_path"* ]]; then
        echo -e "~${current_path#$home_path}"
    elif [[ "$current_path" == "/" ]]; then
        echo "/"
    else
        local shortened_path=$(echo "$current_path" | sed -E 's|^(/[^/]+/[^/]+).*|\1/...|')
        echo -e "$shortened_path"
    fi
}

# Fonction pour effacer l'écran et afficher le chemin actuel formaté
clear_screen() {
    clear
    echo -e "${GREEN}$(format_path)${NC}"
    echo "----------------------------------------"
}

# Fonction pour lister les fichiers et dossiers
list_items() {
    items=()
    if [ "$current_path" != "/" ]; then
        items+=("..")
    fi
    for item in "$current_path"/*; do
        if [ -e "$item" ]; then
            items+=("$(basename "$item")")
        fi
    done
}

# Fonction pour afficher le menu avec icônes
display_menu() {
    local i=0
    for item in "${items[@]}"; do
        local icon=$(get_icon "$current_path/$item")
        if [ $i -eq $selected_index ]; then
            echo -e "> $icon   ${GREEN}$item${NC}"  # Trois espaces après l'icône pour espacer
        else
            echo -e "  $icon   $item"               # Trois espaces pour l'alignement
        fi
        echo ""  # Ligne vide pour espacer les éléments
        ((i++))
    done
}
# Fonction pour afficher les options de fichier
open_file_options() {
    local file="$1"
    clear_screen
    echo -e "${YELLOW}Options pour le fichier: ${GREEN}$file${NC}"
    echo "1) Afficher le contenu (cat)"
    echo "2) Ouvrir avec Vim"
    echo "3) VS Code"
    echo -e "Choisissez une option (ou appuyez sur Entrée pour annuler): "
    
    read -n 1 -r option
    echo ""
    case $option in
        1) cat "$file";;
        2) vim "$file";;
        3) code "$file";;
        *) echo -e "${RED}Action annulée.${NC}";;
    esac
    read -n 1 -s -r -p "Appuyez sur une touche pour revenir au menu..."
}

# Fonction pour afficher les propriétés du fichier ou dossier
display_file_properties() {
    if [ ${#items[@]} -gt 0 ]; then
        local selected_item="${items[$selected_index]}"
        local full_path="$current_path/$selected_item"
        
        clear_screen
        echo -e "${YELLOW}Propriétés de ${GREEN}$selected_item${NC}"
        echo -e "Chemin complet : $full_path"
        echo -e "Type : $(file -b "$full_path")"
        echo -e "Taille : $(du -sh "$full_path" | awk '{print $1}')"
        echo -e "Permissions : $(stat -c '%A' "$full_path")"
        echo -e "Propriétaire : $(stat -c '%U' "$full_path")"
        echo -e "Dernière modification : $(stat -c '%y' "$full_path")"
        
        read -n 1 -s -r -p "Appuyez sur une touche pour continuer..."
    fi
}

# Fonction pour afficher l'aide
display_help() {
    clear_screen
    echo -e "${YELLOW}Guide d'utilisation:${NC}"
    echo -e "${GREEN}↑${NC} - Monter dans la liste"
    echo -e "${GREEN}↓${NC} - Descendre dans la liste"
    echo -e "${GREEN}→${NC} - Entrer dans un dossier"
    echo -e "${GREEN}←${NC} - Retourner au dossier parent"
    echo -e "${GREEN}f${NC} - Créer un nouveau fichier"
    echo -e "${GREEN}d${NC} - Créer un nouveau dossier"
    echo -e "${GREEN}s${NC} - Afficher l'espace disque disponible"
    echo -e "${GREEN}p${NC} - Afficher les propriétés du fichier ou dossier sélectionné"
    echo -e "${GREEN}?${NC} - Afficher l'aide"
    echo -e "${GREEN}q${NC} - Quitter"
    echo ""
    read -n 1 -s -r -p "Appuyez sur une touche pour continuer..."
}

# Fonction pour déterminer l'icône en fonction du type de fichier
get_icon() {
    local file="$1"
    if [ -d "$file" ]; then
        echo -e "\uF115"  # Icône dossier
    else
        case "$file" in
            *.json) echo -e "\uF4C2" ;;  # Icône JSON
            *.py) echo -e "\uE235" ;;     # Icône Python
            *.csv) echo -e "\uF1C3" ;;    # Icône CSV
            *.md) echo -e "\uF48A" ;;     # Icône Markdown
            *.txt) echo -e "\uF15C" ;;    # Icône texte
            *.sh) echo -e "\uF489" ;;     # Icône Script Bash
            *.js) echo -e "\uE74E" ;;     # Icône JavaScript
            *.html) echo -e "\uF13B" ;;   # Icône HTML
            *.css) echo -e "\uF13C" ;;    # Icône CSS
            *) echo -e "\uF016" ;;        # Icône fichier générique
        esac
    fi
}

# Fonction pour entrer dans un dossier ou ouvrir un fichier avec options
enter_item() {
    if [ ${#items[@]} -gt 0 ]; then
        local selected_item="${items[$selected_index]}"
        if [ "$selected_item" = ".." ]; then
            current_path=$(dirname "$current_path")
        elif [ -d "$current_path/$selected_item" ]; then
            current_path="$current_path/$selected_item"
        elif [ -f "$current_path/$selected_item" ]; then
            open_file_options "$current_path/$selected_item"
        fi
        selected_index=0
    fi
}

# Fonction pour remonter d'un niveau
go_back() {
    if [ "$current_path" != "/" ]; then
        current_path=$(dirname "$current_path")
        selected_index=0
    fi
}

# Boucle principale
while true; do
    clear_screen
    display_system_info    # Afficher les infos CPU, RAM, et espace disque en haut à droite
    list_items
    display_menu
    
    # Placer les instructions de navigation en bas du terminal
    tput cup $(($(tput lines) - 4)) 0
    echo -e "\n${YELLOW}↑↓ Se déplacer | → ← Entrer/Sortir du dossier${NC}"
    echo -e "${YELLOW}f: Créer un fichier | d: Créer un dossier | r: Supprimer | p: Propriétés | ?: Aide | q: Quitter${NC}"

    read -rsn1 mode
    if [[ $mode == $'\x1b' ]]; then
        read -rsn2 mod
        case $mod in
            '[A') ((selected_index--)); ((selected_index < 0)) && selected_index=$((${#items[@]} - 1)) ;;
            '[B') ((selected_index++)); ((selected_index >= ${#items[@]})) && selected_index=0 ;;
            '[C') enter_item ;;
            '[D') go_back ;;
        esac
    else
        case $mode in
            q) break ;;
            "?") display_help ;;
            f) create_file ;;
            d) create_directory ;;
            r) delete_item ;;    # Appel de la fonction delete_item pour supprimer un fichier/dossier
            p) display_file_properties ;;
        esac
    fi
done


