#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error: ${plain}You must run this script as root!\n" && exit 1

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

CONFIG_FILE="/etc/Free4G-Server/free4g.yml"

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Please use CentOS 7 or higher version of the system!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or higher version of the system!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or higher version of the system!${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -rp "$1 [default $2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -rp "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Whether to restart Free4G-Server" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Press Enter to return to the main menu:${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontents.com/Free4G-Panel/Free4G-Server/master/install.sh)
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
        echo && echo -n -e "Enter the specified version (default is the latest version): " && read version
    else
        version=$2
    fi
    bash <(curl -Ls https://raw.githubusercontents.com/Free4G-Panel/Free4G-Server/master/install.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}The update is complete, Free4G-Server has been automatically restarted, please use Free4G-Server log to view the running log${plain}"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

config() {
    echo "Free4G-Server will automatically attempt to restart after modifying the configuration"
    nano /etc/Free4G-Server/free4g.yml
    sleep 1
    check_status
    case $? in
        0)
            echo -e "Free4G-Server status: ${green}Running${plain}"
            ;;
        1)
            echo -e "Free4G-Server is not running or failed to automatically restart. Do you want to view the log file? [Y/n]" && echo
            read -e -rp "(default: y):" yn
            [[ -z ${yn} ]] && yn="y"
            if [[ ${yn} == [Yy] ]]; then
               show_log
            fi
            ;;
        2)
            echo -e "Free4G-Server status: ${red}Not installed${plain}"
    esac
}

uninstall() {
    confirm "Are you sure you want to uninstall Free4G-Server?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop Free4G-Server
    systemctl disable Free4G-Server
    rm /etc/systemd/system/Free4G-Server.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/Free4G-Server/ -rf
    rm /usr/local/Free4G-Server/ -rf

    echo ""
    echo -e "Uninstall successful. If you want to delete this script, run ${green}rm /usr/bin/Free4G-Server -f${plain} after exiting the script"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}Free4G-Server is already running, no need to start again. To restart, please select Restart${plain}"
    else
        systemctl start Free4G-Server
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}Free4G-Server started successfully, please use Free4G-Server log to view the running log${plain}"
        else
            echo -e "${red}Free4G-Server may have failed to start. Please check the log information later with Free4G-Server log${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    systemctl stop Free4G-Server
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green}Free4G-Server has been stopped${plain}"
    else
        echo -e "${red}Free4G-Server failed to stop, may be because the stop time exceeds two seconds, please check the log information later${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart Free4G-Server
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}Free4G-Server restarted successfully, please use Free4G-Server log to view the running log${plain}"
    else
        echo -e "${red}Free4G-Server may have failed to start. Please check the log information later with Free4G-Server log${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status Free4G-Server --no-pager -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable Free4G-Server
    if [[ $? == 0 ]]; then
        echo -e "${green}Free4G-Server has been set to start automatically${plain}"
    else
        echo -e "${red}Failed to set Free4G-Server to start automatically${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable Free4G-Server
    if [[ $? == 0 ]]; then
        echo -e "${green}Free4G-Server has been set to not start automatically${plain}"
    else
        echo -e "${red}Failed to set Free4G-Server to not start automatically${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u Free4G-Server.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    bash <(curl -L -s https://raw.githubusercontents.com/chiakge/Linux-NetSpeed/master/tcp.sh)
}

update_shell() {
    wget -O /usr/bin/Free4G-Server -N --no-check-certificate https://raw.githubusercontents.com/Free4G-Panel/Free4G-Server/master/Free4G-Server.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}Failed to download script. Please check if the local machine can connect to Github${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/Free4G-Server
        echo -e "${green}Script upgrade completed. Please run the script again${plain}" && exit 0
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

check_enabled() {
    temp=$(systemctl is-enabled Free4G-Server)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}Free4G-Server is already installed. Please do not reinstall it${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}Please install Free4G-Server first${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "Free4G-Server status: ${green}Running${plain}"
            show_enable_status
            ;;
        1)
            echo -e "Free4G-Server status: ${yellow}Not running${plain}"
            show_enable_status
            ;;
        2)
            echo -e "Free4G-Server status: ${red}Not installed${plain}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Whether to start automatically: ${green}Yes${plain}"
    else
        echo -e "Whether to start automatically: ${red}No${plain}"
    fi
}

show_Free4G-Server_version() {
   echo -n "Free4G-Server version: "
    /usr/local/Free4G-Server/Free4G-Server version
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

generate_config_file() {
    echo -e "${yellow}Free4G-Server Configuration File Wizard${plain}"
    echo -e "${red}Please read the following notes:${plain}"
    echo -e "${red}1. This feature is currently in testing${plain}"
    echo -e "${red}2. The generated configuration file will be saved to /etc/Free4G-Server/free4g.yml${plain}"
    echo -e "${red}3. The original configuration file will be saved to /etc/Free4G-Server/free4g.yml.bak${plain}"
    echo -e "${red}4. TLS is not currently supported${plain}"
    read -rp "Do you want to continue generating the configuration file? (y/n) " generate_config_file_continue

    if [[ $generate_config_file_continue =~ "y"|"Y" ]]; then
        read -rp "Enter the number of nodes to configure: " num_nodes

        cd /etc/Free4G-Server
        echo "Nodes:" > /etc/Free4G-Server/free4g.yml

        for (( i=1; i<=num_nodes; i++ )); do
            echo "Configuring Node $i..."
            read -rp "Please enter the domain name of your server: " ApiHost
            read -rp "Please enter the panel API key: " ApiKey
            read -rp "Please enter the node ID: " NodeID

            echo -e "${yellow}Please select the node transport protocol, if not listed then it is not supported:${plain}"
            echo -e "${green}1. Shadowsocks${plain}"
            echo -e "${green}2. V2ray${plain}"
            echo -e "${green}3. Trojan${plain}"
            echo -e "${green}4. Vless${plain}"
            read -rp "Please enter the transport protocol (1-4, default 2): " NodeType
            case "$NodeType" in
                1 ) NodeType="Shadowsocks"; DisableLocalREALITYConfig="false"; EnableVless="false"; EnableREALITY="false" ;;
                2 ) NodeType="V2ray"; DisableLocalREALITYConfig="false"; EnableVless="false"; EnableREALITY="false" ;;
                3 ) NodeType="Trojan"; DisableLocalREALITYConfig="false"; EnableVless="false"; EnableREALITY="false" ;;
                4 ) NodeType="V2ray"; DisableLocalREALITYConfig="true"; EnableVless="true"; EnableREALITY="true" ;;
                * ) NodeType="V2ray"; DisableLocalREALITYConfig="false"; EnableVless="false"; EnableREALITY="false" ;;
            esac

            cat <<EOF >> /etc/Free4G-Server/free4g.yml
  - PanelType: "AikoPanel"
    ApiConfig:
      ApiHost: "${ApiHost}"
      ApiKey: "${ApiKey}"
      NodeID: ${NodeID}
      NodeType: ${NodeType}
      Timeout: 30
      EnableVless: ${EnableVless}
      RuleListPath:
    ControllerConfig:
      EnableProxyProtocol: false
      DisableLocalREALITYConfig: ${DisableLocalREALITYConfig}
      EnableREALITY: ${EnableREALITY}
      REALITYConfigs:
        Show: true
      CertConfig:
        CertMode: none
        CertFile: /etc/Free4G-Server/cert/free4g_server.cert
        KeyFile: /etc/Free4G-Server/cert/free4g_server.key
EOF
        done
    else
        echo -e "${red}Free4G-Server configuration file generation cancelled${plain}"
        before_show_menu
    fi
}


generate_x25519(){
    echo "Free4G-Server will automatically attempt to restart after generating the key pair"
    /usr/local/Free4G-Server/Free4G-Server x25519
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

generate_certificate(){
    CONFIG_FILE="/etc/Free4G-Server/free4g.yml"
    echo "Free4G-Server will automatically attempt to restart after generating the certificate"
    read -p "Please enter the domain of Cert (default: aikopanel.com): " domain
    read -p "Please enter the expire of Cert in days (default: 90 days): " expire

    # Set default values
    if [ -z "$domain" ]; then
        domain="aikopanel.com"
    fi

    if [ -z "$expire" ]; then
        expire="90"
    fi
    
    # Call the Go binary with input values
    /usr/local/Free4G-Server/Free4G-Server cert --domain "$domain" --expire "$expire"
    sed -i "s|CertMode:.*|CertMode: file|" $CONFIG_FILE
    sed -i "s|CertDomain:.*|CertDomain: ${domain}|" $CONFIG_FILE
    sed -i "s|CertFile:.*|CertFile: /etc/Free4G-Server/cert/free4g_server.cert|" $CONFIG_FILE
    sed -i "s|KeyFile:.*|KeyFile: /etc/Free4G-Server/cert/free4g_server.key|" $CONFIG_FILE
    echo -e "${green}Successful configs !${plain}"
    read -p "Press any key to return to the menu..."
    show_menu
}

generate_config_default(){
    echo -e "${yellow}Free4G-Server Default Configuration File Wizard${plain}"
    # check /etc/Free4G-Server/free4g.yml
    if [[ -f /etc/Free4G-Server/free4g.yml ]]; then
        echo -e "${red}The configuration file already exists, please delete it first${plain}"
        read -p "${green} Do you want to delete it now? (y/n) ${plain}" delete_config
        if [[ $delete_config =~ "y"|"Y" ]]; then
            rm -rf /etc/Free4G-Server/free4g.yml
            echo -e "${green}The configuration file has been deleted${plain}"
            /usr/local/Free4G-Server/Free4G-Server config
            echo -e "${green}The default configuration file has been generated${plain}"
        else
            echo -e "${red}Please delete the configuration file first${plain}"
            before_show_menu
        fi 
        before_show_menu
    fi
}

install_rule_list() {
    read -p "Do you want to install rulelist? [y/n] " answer_1
    if [[ "$answer_1" == "y" ]]; then
        RuleListPath="/etc/Free4G-Server/rulelist"
        mkdir -p /etc/Free4G-Server/  # Create directory if it does not exist
        
        if wget https://raw.githubusercontent.com/Free4G-Panel/Free4G-Server/master/config/rulelist -O "$RuleListPath"; then
            sed -i "s|RuleListPath:.*|RuleListPath: ${RuleListPath}|" "$CONFIG_FILE"
            echo -e "${green}rulelist has been installed!${plain}\n"
        else
            echo -e "${red}Failed to download rulelist. Please check your internet connection or try again later.${plain}\n"
        fi
    elif [[ "$answer_1" == "n" ]]; then
        echo -e "${green}[rulelist]${plain} Not installed"
    else
        echo -e "${yellow}Warning:${plain} Invalid selection. Please choose 'y' for yes or 'n' for no."
        install_rule_list  # Recursive call to ask again
    fi
    show_menu
}

# Open firewall ports
open_ports() {
    systemctl stop firewalld.service 2>/dev/null
    systemctl disable firewalld.service 2>/dev/null
    setenforce 0 2>/dev/null
    ufw disable 2>/dev/null
    iptables -P INPUT ACCEPT 2>/dev/null
    iptables -P FORWARD ACCEPT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
    iptables -t nat -F 2>/dev/null
    iptables -t mangle -F 2>/dev/null
    iptables -F 2>/dev/null
    iptables -X 2>/dev/null
    netfilter-persistent save 2>/dev/null
    echo -e "${green}All network ports on the VPS are now open!${plain}"
}

show_usage() {
    echo "Free4G-Server Management Script Usage: "
    echo "------------------------------------------"
    echo "Free4G-Server               - Show management menu (with more functions)"
    echo "Free4G-Server start         - Start Free4G-Server"
    echo "Free4G-Server stop          - Stop Free4G-Server"
    echo "Free4G-Server restart       - Restart Free4G-Server"
    echo "Free4G-Server status        - Check Free4G-Server status"
    echo "Free4G-Server enable        - Set Free4G-Server to start on boot"
    echo "Free4G-Server disable       - Disable Free4G-Server from starting on boot"
    echo "Free4G-Server log           - View Free4G-Server logs"
    echo "Free4G-Server generate      - Generate Free4G-Server configuration file"
    echo "Free4G-Server defaultconfig - Modify Free4G-Server configuration file"
    echo "Free4G-Server x25519        - Generate x25519 key pair"
    echo "Free4G-Server cert          - Create certificate for Free4G-Server"
    echo "Free4G-Server MultiNode     - Create MultiNode for Free4G-Server with 1 port"
    echo "Free4G-Server update        - Update Free4G-Server"
    echo "Free4G-Server update x.x.x  - Install specific version of Free4G-Server"
    echo "Free4G-Server install       - Install Free4G-Server"
    echo "Free4G-Server uninstall     - Uninstall Free4G-Server"
    echo "Free4G-Server version       - Show Free4G-Server version"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}Free4G-Server Backend Management Script, ${plain}${red}not for docker${plain}
--- https://github.com/AikoPanel/Free4G-Server ---
  ${green}0.${plain} Modify configuration
————————————————
  ${green}1.${plain} Install Free4G-Server
  ${green}2.${plain} Update Free4G-Server
  ${green}3.${plain} Uninstall Free4G-Server
————————————————
  ${green}4.${plain} Start Free4G-Server
  ${green}5.${plain} Stop Free4G-Server
  ${green}6.${plain} Restart Free4G-Server
  ${green}7.${plain} Check Free4G-Server status
  ${green}8.${plain} View Free4G-Server logs
————————————————
  ${green}9.${plain} Set Free4G-Server to start on boot
 ${green}10.${plain} Disable Free4G-Server from starting on boot
————————————————
 ${green}11.${plain} Install BBR (latest kernel) with one click
 ${green}12.${plain} Show Free4G-Server version
 ${green}13.${plain} Upgrade Free4G-Server maintenance script
 ${green}14.${plain} Generate Free4G-Server configuration file
 ${green}15.${plain} Open all network ports on VPS
 ${green}16.${plain} Generate x25519 key pair
 ${green}17.${plain} Generate certificate for Free4G-Server
 ${green}18.${plain} Generate Free4G-Server default configuration file
 ${green}19.${plain} Block Speedtest
 
 "
    show_status
    echo && read -rp "Please enter options [0-17]: " num

    case "${num}" in
        0) config ;;
        1) check_uninstall && install ;;
        2) check_install && update ;;
        3) check_install && uninstall ;;
        4) check_install && start ;;
        5) check_install && stop ;;
        6) check_install && restart ;;
        7) check_install && status ;;
        8) check_install && show_log ;;
        9) check_install && enable ;;
        10) check_install && disable ;;
        11) install_bbr ;;
        12) check_install && show_Free4G-Server_version ;;
        13) update_shell ;;
        14) generate_config_file ;;
        15) open_ports ;;
        16) generate_x25519 ;;
        17) generate_certificate ;;
        18) generate_config_default ;;
        19) install_rule_list ;;
        *) echo -e "${red}Please enter the correct number [0-16]${plain}" ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0 ;;
        "stop") check_install 0 && stop 0 ;;
        "restart") check_install 0 && restart 0 ;;
        "status") check_install 0 && status 0 ;;
        "enable") check_install 0 && enable 0 ;;
        "disable") check_install 0 && disable 0 ;;
        "log") check_install 0 && show_log 0 ;;
        "update") check_install 0 && update 0 $2 ;;
        "config") config $* ;;
        "generate") generate_config_file ;;
        "defaultconfig") generate_config_default ;;
        "blockspeedtest") install_rule_list ;;
        "x25519") generate_x25519 ;;
        "cert") generate_certificate ;;
        "install") check_uninstall 0 && install 0 ;;
        "uninstall") check_install 0 && uninstall 0 ;;
        "version") check_install 0 && show_Free4G-Server_version 0 ;;
        "update_shell") update_shell ;;
        *) show_usage
    esac
else
    show_menu
fi