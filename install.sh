#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error:${plain} This script must be run as root user!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
else
    echo -e "${red}System version not detected, please contact the script author!${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="64"
    echo -e "${red}Architecture detection failed, using default architecture: ${arch}${plain}"
fi

echo "Architecture: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "This software is not supported on 32-bit systems (x86), please use 64-bit systems (x86_64). If there is an error in detection, please contact the author."
    exit 2
fi


# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Please use CentOS 7 or higher system!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or higher system!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or higher system!${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
    else
        apt-get update -y
        apt install wget curl unzip tar cron socat -y
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/Free4G-Server.service ]]; then
        return 2
    fi
    temp=$(systemctl status Free4G-Server | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_Free4G-Server() {
    if [[ -e /usr/local/Free4G-Server/ ]]; then
        rm -rf /usr/local/Free4G-Server/
    fi

    mkdir /usr/local/Free4G-Server/ -p
    cd /usr/local/Free4G-Server/

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/Free4G-Panel/Free4G-Server/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Failed to check Free4G-Server version. It may be due to exceeding the Github API limit. Please try again later or manually specify the Free4G-Server version for installation.${plain}"
            exit 1
        fi
        echo -e "Detected the latest version of Free4G-Server: ${last_version}, starting installation"
        wget -q -N --no-check-certificate -O /usr/local/Free4G-Server/Free4G-Server-linux.zip https://github.com/Free4G-Panel/Free4G-Server/releases/download/${last_version}/Free4G-Server-linux-${arch}.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Failed to download Free4G-Server. Please make sure your server can download files from Github.${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/Free4G-Panel/Free4G-Server/releases/download/${last_version}/Free4G-Server-linux-${arch}.zip"
        echo -e "Starting installation of Free4G-Server v$1"
        wget -q -N --no-check-certificate -O /usr/local/Free4G-Server/Free4G-Server-linux.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Failed to download Free4G-Server v$1. Please make sure the version exists.${plain}"
            exit 1
        fi
    fi

    unzip Free4G-Server-linux.zip
    rm Free4G-Server-linux.zip -f
    chmod +x Free4G-Server
    mkdir /etc/Free4G-Server/ -p
    rm /etc/systemd/system/Free4G-Server.service -f
    file="https://github.com/Free4G-Panel/Free4G-Server/raw/master/Free4G-Server.service"
    wget -q -N --no-check-certificate -O /etc/systemd/system/Free4G-Server.service ${file}
    #cp -f Free4G-Server.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl stop Free4G-Server
    systemctl enable Free4G-Server
    echo -e "${green}Free4G-Server ${last_version}${plain} installation completed and set to start on boot"
    cp geoip.dat /etc/Free4G-Server/
    cp geosite.dat /etc/Free4G-Server/

    if [[ ! -f /etc/Free4G-Server/Free4G.yml ]]; then
        cp Free4G.yml /etc/Free4G-Server/
        echo -e ""
        echo -e "For a fresh installation, please refer to the tutorial: https://github.com/Free4G-Panel/Free4G-Server and configure the necessary content"
    else
        systemctl start Free4G-Server
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}Free4G-Server restarted successfully${plain}"
        else
            echo -e "${red}Free4G-Server may have failed to start, please use Free4G-Server log to view log information. If it cannot be started, it may have changed the configuration format, please go to the wiki for more information: https://github.com/Free4G-Server-project/Free4G-Server/wiki${plain}"
        fi
    fi

    if [[ ! -f /etc/Free4G-Server/dns.json ]]; then
        cp dns.json /etc/Free4G-Server/
    fi
    if [[ ! -f /etc/Free4G-Server/route.json ]]; then
        cp route.json /etc/Free4G-Server/
    fi
    if [[ ! -f /etc/Free4G-Server/custom_outbound.json ]]; then
        cp custom_outbound.json /etc/Free4G-Server/
    fi
    if [[ ! -f /etc/Free4G-Server/custom_inbound.json ]]; then
        cp custom_inbound.json /etc/Free4G-Server/
    fi
    if [[ ! -f /etc/Free4G-Server/AikoBlock ]]; then
        cp AikoBlock /etc/Free4G-Server/
    fi
    curl -o /usr/bin/Free4G-Server -Ls https://raw.githubusercontent.com/Free4G-Panel/Free4G-Server/master/Free4G-Server.sh
    chmod +x /usr/bin/Free4G-Server
    ln -s /usr/bin/Free4G-Server /usr/bin/Free4G-Server # compatible lowercase
    chmod +x /usr/bin/Free4G-Server
    cd $cur_dir
    rm -f install.sh
    echo -e ""
    echo "Usage of Free4G-Server management script (compatible with Free4G-Server execution, case-insensitive):"
    echo "------------------------------------------"
    echo "Free4G-Server              - Show management menu (more functions)"
    echo "Free4G-Server start        - Start Free4G-Server"
    echo "Free4G-Server stop         - Stop Free4G-Server"
    echo "Free4G-Server restart      - Restart Free4G-Server"
    echo "Free4G-Server status       - Check Free4G-Server status"
    echo "Free4G-Server enable       - Set Free4G-Server to start on boot"
    echo "Free4G-Server disable      - Disable Free4G-Server to start on boot"
    echo "Free4G-Server log          - Check Free4G-Server logs"
    echo "Free4G-Server generate     - Generate Free4G-Server configuration file"
    echo "Free4G-Server update       - Update Free4G-Server"
    echo "Free4G-Server update x.x.x - Update Free4G-Server to specified version"
    echo "Free4G-Server install      - Install Free4G-Server"
    echo "Free4G-Server uninstall    - Uninstall Free4G-Server"
    echo "Free4G-Server version      - Check Free4G-Server version"
    echo "------------------------------------------"
}

echo -e "${green}Starting installation${plain}"
install_base
install_Free4G-Server $1
