#!/bin/bash

rm -rf $0

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "${red}Error:${plain} This script must be run as root!" && exit 1
# install English
english(){
  bash <(curl -Ls https://raw.githubusercontent.com/AikoCute-Offical/THLVN/main/AikoR-en.sh)
}


# install vietnamese
vietnamese(){
   bash <(curl -Ls https://raw.githubusercontent.com/AikoCute-Offical/THLVN/main/AikoR-vi.sh)
}   


show_menu() {
    echo -e "
  ${green}AikoR Backend Management Scripts，${plain}${red}does not work with docker${plain}
--- https://github.com/AikoCute-Offical/AikoR ---
  ${green}0.${plain} Exit Install AikoR
————————————————
  ${green}1.${plain} English
  ${green}2.${plain} Vietnamese
————————————————
 "
    echo && read -p "Please enter an option [0-2]: " num

    case "${num}" in
        0) exit 0
        ;;
        1) english
        ;;
        2) vietnamese
        ;;
        *) echo -e "${red}Please enter the correct number [0-2]${plain}"
        ;;
    esac
}