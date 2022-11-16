#!/bin/bash

rm -rf $0

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error：${plain} This script must be run as root user!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}System version not detected, please contact script author!${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
  arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
  arch="arm64-v8a"
else
  arch="64"
  echo -e "${red}No schema detected, use default schema: ${arch}${plain}"
fi

echo "Architecture System: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "This software does not support 32-bit (x86) system, please use 64-bit (x86_64) system, if found wrong, please contact the author"
    exit 2
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Please use CentOS 7 or later!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or higher!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or later!${plain}\n" && exit 1
    fi
fi


install() {
    bash <(curl -Ls https://raw.githubusercontent.com/Github-Aiko/AikoR-install/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    if [[ $# == 0 ]]; then
        echo && echo -n -e "Enter the specified version (default latest version) (eg: v0.0.1): " && read version
    else
        version=$2
    fi

    bash <(curl -ls https://raw.githubusercontent.com/Github-Aiko/AikoR-install/master/install.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}Update is complete, AikoR has been restarted automatically${plain}"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

uninstall() {
    confirm "Are you sure you want to uninstall AikoR?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop AikoR
    systemctl disable AikoR
    rm /etc/systemd/system/AikoR.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/AikoR/ -rf
    rm /usr/local/AikoR/ -rf
    rm /usr/bin/AikoR -f

    echo ""
    echo -e "${green}Uninstall successful, Completely uninstalled from the system${plain}"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green} AikoR is already running ${plain}"
    else
        systemctl start AikoR
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green} AikoR has successfully started ${plain}"
        else
            echo -e "${red} AikoR boot failed, AikoR logs to check for errors${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

config() {
    echo "AikoR will automatically restart after configuration modification"
    nano /etc/AikoR/aiko.yml
    sleep 2
    check_status
    case $? in
        0)
            echo -e "AikoR status: ${green} Running ${plain}"
            ;;
        1)
            echo -e "It is detected that you do not start AikoR or AikoR does not restart by itself, check the log？[Y/n]" && echo
            read -e -p "(yes or no):" yn
            [[ -z ${yn} ]] && yn="y"
            if [[ ${yn} == [Yy] ]]; then
               show_log
            fi
            ;;
        2)
            echo -e "AikoR status: ${red} Not installed ${plain}"
    esac
}

stop() {
    systemctl stop AikoR
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green} AikoR has stopped successfully ${plain}"
    else
        echo -e "${red} AikoR cannot be stopped, it may be due to the stopping time exceeding two seconds, please check the Logs to see the cause ${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

update_shell() {
    wget -O /usr/bin/AikoR -N --no-check-certificate https://raw.githubusercontent.com/Github-Aiko/AikoR-install/master/AikoR.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}Script failed to download, please check if machine can connect to Github${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/AikoR
        echo -e "${green} Script upgrade successful, please run the script again ${plain}" && exit 0
    fi
}

show_log() {
    journalctl -u AikoR.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

check_status() {
    if [[ ! -f /etc/systemd/system/AikoR.service ]]; then
        return 2
    fi
    temp=$(systemctl status AikoR | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

show_AikoR_version() {
    echo -n "AikoR version："
    /usr/local/AikoR/AikoR -version
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red} Please install AikoR first ${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

status() {
    systemctl status AikoR --no-pager -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_menu() {
    echo -e "
  ${green}AikoR Các tập lệnh quản lý phụ trợ，${plain}${red}không hoạt động với docker${plain}
--- https://github.com/Github-Aiko/AikoR ---
  ${green}0.${plain} Cấu hình AikoR
————————————————
  ${green}1.${plain} Cài Đặt AikoR
  ${green}2.${plain} Cập nhật AikoR
  ${green}3.${plain} Gỡ cài AikoR
————————————————
  ${green}4.${plain} Khởi động AikoR
  ${green}5.${plain} Dừng AikoR
  ${green}6.${plain} View AikoR logs
————————————————
  ${green}7.${plain} Update AikoR shell
 "
 # Cập nhật tiếp theo có thể được thêm vào chuỗi trên
    echo && read -p "Vui lòng chọn [0-7]: " num

    case "${num}" in
        0) config
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && update
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && start
        ;;
        5) check_install && stop
        ;;
        6) check_install && show_log
        ;;
        7) update_shell
        ;;
        *) echo -e "${red}Please enter the correct number [0-7]${plain}"
        ;;
    esac
}

show_menu