#!/bin/bash

textcolor='\033[1;36m'
red='\033[1;31m'
clear='\033[0m'

check_root() {
    if [[ $EUID -ne 0 ]]
    then
        echo ""
        echo -e "${red}Error: this script should be run as root, use \"sudo -i\" command first${clear}"
        echo ""
        exit 1
    fi
}

check_sbmanager() {
    if [[ -f /usr/local/bin/sbmanager ]] && [[ ! -f /usr/local/bin/proxylist ]]
    then
        echo ""
        echo -e "${red}Error: this script should be run on the client device, not on the server${clear}"
        echo ""
        exit 1
    fi
}

banner() {
    echo ""
    echo "╔══╗ ╔══╗ ╦══╗"
    echo "║    ║    ║  ║"
    echo "╚══╗ ╚══╗ ╠══╣"
    echo "   ║    ║ ║  ║"
    echo "╚══╝ ╚══╝ ╩══╝ by A-Zuro"
}

enter_language() {
    echo ""
    echo -e "${textcolor}Select the language:${clear}"
    echo "1 - Russian"
    echo "2 - English"
    read -r language
    [[ -n $language ]] && echo ""

    if [[ "$language" == "1" ]]
    then
        language="ru"
    else
        language="en"
    fi
}

install_sing_box() {
    declare -A -g general_message=()
    general_message[1_ru]="${textcolor}Sing-Box не установлен${clear}"
    general_message[2_ru]="${textcolor}[?]${clear} Нажмите ${textcolor}Enter${clear}, чтобы установить, или введите ${textcolor}x${clear}, чтобы выйти:"
    general_message[3_ru]="${textcolor}Установка Sing-Box...${clear}"
    general_message[4_ru]="${textcolor}Sing-Box успешно установлен${clear}"
    general_message[5_ru]="Его можно обновлять командой ${textcolor}apt-get install sing-box -y${clear}"
    general_message[6_ru]="${red}Ошибка: не удалось установить Sing-Box, попробуйте позже${clear}"
    general_message[1_en]="${textcolor}Sing-Box is not installed${clear}"
    general_message[2_en]="${textcolor}[?]${clear} Press ${textcolor}Enter${clear} to install it or enter ${textcolor}x${clear} to exit:"
    general_message[3_en]="${textcolor}Installing Sing-Box...${clear}"
    general_message[4_en]="${textcolor}Sing-Box has been installed successfully${clear}"
    general_message[5_en]="It can be updated with ${textcolor}apt-get install sing-box -y${clear} command"
    general_message[6_en]="${red}Error: failed to install Sing-Box, try again later${clear}"

    touch /usr/local/bin/proxylist

    if ! sing-box version &> /dev/null
    then
        echo ""
        echo -e "${general_message[1_$language]}"
        echo ""
        echo -e "${general_message[2_$language]}"
        read -r sb_install
        [[ -n $sb_install ]] && echo ""
        [[ ${sb_install,,} =~ ^(x|х)$ ]] && exit 0

        echo -e "${general_message[3_$language]}"
        [[ ! -d /etc/apt/keyrings ]] && mkdir -p /etc/apt/keyrings
        curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
        chmod a+r /etc/apt/keyrings/sagernet.asc
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | tee /etc/apt/sources.list.d/sagernet.list > /dev/null
        apt-get update -y && apt-get install sing-box -y
        systemctl disable sing-box.service
        echo ""

        if sing-box version &> /dev/null
        then
            echo -e "${general_message[4_$language]}"
            echo ""
            echo -e "${general_message[5_$language]}"
            echo ""
        else
            echo -e "${general_message[6_$language]}"
            echo ""
            exit 1
        fi
    fi
}

### OPTION 1 - SHOW PROXIES ###

show_proxies() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor}Количество прокси:${clear}"
    info_message[1_en]="${textcolor}Number of proxies:${clear}"

    proxy_num=$(cat /usr/local/bin/proxylist | wc -l)
    echo -e "${info_message[1_$language]} ${proxy_num}"
    sed "s/#//g" /usr/local/bin/proxylist
    echo ""
    main_menu
}

### OPTION 2 - ADD PROXIES ###

exit_add_proxy() {
    if [[ ${link,,} =~ ^(x|х)$ ]]
    then
        link=""
        main_menu
    fi
}

check_link() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: ссылка введена неправильно или сервер недоступен${clear}"
    check_message[2_ru]="${textcolor}[?]${clear} Введите ссылку на ваш клиентский конфиг или введите ${textcolor}x${clear}, чтобы выйти:"
    check_message[1_en]="${red}Error: the link is incorrect or the server is not available${clear}"
    check_message[2_en]="${textcolor}[?]${clear} Enter your client config link or enter ${textcolor}x${clear} to exit:"

    while [[ -z $link ]] || [[ ! $(curl -s "${link}") =~ '"tag": "proxy"' ]]
    do
        if [[ -n $link ]]
        then
            echo -e "${check_message[1_$language]}"
            echo ""
        fi
        echo -e "${check_message[2_$language]}"
        read -r link
        [[ -n $link ]] && echo ""
        exit_add_proxy
    done
}

check_command_add() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: команда должна содержать только английские буквы, цифры, символы _ и -${clear}"
    check_message[2_ru]="${red}Ошибка: эта команда уже существует${clear}"
    check_message[3_ru]="${textcolor}[?]${clear} Введите команду для нового прокси:"
    check_message[1_en]="${red}Error: the command should contain only letters, numbers, _ and - symbols${clear}"
    check_message[2_en]="${red}Error: this command already exists${clear}"
    check_message[3_en]="${textcolor}[?]${clear} Enter the command for the new proxy:"

    while [[ ! $new_comm =~ ^[a-zA-Z0-9_-]+$ ]] || which ${new_comm} &> /dev/null
    do
        if [[ -z $new_comm ]]
        then
            :
        elif [[ ! $new_comm =~ ^[a-zA-Z0-9_-]+$ ]]
        then
            echo -e "${check_message[1_$language]}"
            echo ""
        else
            echo -e "${check_message[2_$language]}"
            echo ""
        fi
        echo -e "${check_message[3_$language]}"
        read -r new_comm
        [[ -n $new_comm ]] && echo ""
    done
}

enter_proxy_data_add() {
    declare -A -g input_message=()
    input_message[1_ru]="${textcolor}[?]${clear} Введите ссылку на ваш клиентский конфиг или введите ${textcolor}x${clear}, чтобы выйти:"
    input_message[2_ru]="${textcolor}[?]${clear} Введите команду для нового прокси:"
    input_message[1_en]="${textcolor}[?]${clear} Enter your client config link or enter ${textcolor}x${clear} to exit:"
    input_message[2_en]="${textcolor}[?]${clear} Enter the command for the new proxy:"

    echo -e "${input_message[1_$language]}"
    read -r link
    [[ -n $link ]] && echo ""
    exit_add_proxy
    check_link
    echo -e "${input_message[2_$language]}"
    read -r new_comm
    [[ -n $new_comm ]] && echo ""
    check_command_add
}

client_script_add() {
    declare -A -g info_message=()
    info_message[1_ru]='${red}Ошибка: эту команду нужно запускать с sudo или от имени root${clear}'
    info_message[2_ru]='${textcolor}Sing-Box запущен${clear}'
    info_message[3_ru]='Не закрывайте это окно, пока Sing-Box работает'
    info_message[4_ru]='Нажмите ${textcolor}Ctrl + C${clear}, чтобы отключиться'
    info_message[5_ru]="Команда ${textcolor}${new_comm}${clear} добавлена в /usr/local/bin/, используйте её для подключения к прокси"
    info_message[1_en]='${red}Error: this command should be run with sudo or as root${clear}'
    info_message[2_en]='${textcolor}Started Sing-Box${clear}'
    info_message[3_en]='Do not close this window while Sing-Box is running'
    info_message[4_en]='Press ${textcolor}Ctrl + C${clear} to disconnect'
    info_message[5_en]="The command ${textcolor}${new_comm}${clear} has been added to /usr/local/bin/, use it to connect to the proxy"

	cat > /usr/local/bin/${new_comm} <<-EOF
	#!/bin/bash

	textcolor='\033[1;36m'
	red='\033[1;31m'
	clear='\033[0m'

	if [[ \$EUID -ne 0 ]]
	then
	    echo ""
	    echo -e "${info_message[1_$language]}"
	    echo ""
	    exit 1
	fi

	echo ""
	echo -e "${info_message[2_$language]}"
	echo "${info_message[3_$language]}"
	echo -e "${info_message[4_$language]}"
	echo ""

	wget -q -O /etc/sing-box/config.json.1 ${link} && mv -f /etc/sing-box/config.json.1 /etc/sing-box/config.json
	sing-box run -c /etc/sing-box/config.json
	EOF

    chmod +x /usr/local/bin/${new_comm}
    echo "#${new_comm}" >> /usr/local/bin/proxylist
    echo -e "${info_message[5_$language]}"
    echo ""
}

add_proxies() {
    while [[ ! ${link,,} =~ ^(x|х)$ ]]
    do
        enter_proxy_data_add
        client_script_add
    done
}

### OPTION 3 - DELETE PROXIES ###

exit_del_proxy() {
    if [[ ${del_comm,,} =~ ^(x|х)$ ]]
    then
        del_comm=""
        main_menu
    fi
}

check_command_del() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: эта команда не существует в /usr/local/bin/${clear}"
    check_message[2_ru]="${textcolor}[?]${clear} Введите удаляемую команду для прокси или введите ${textcolor}x${clear}, чтобы выйти:"
    check_message[1_en]="${red}Error: this command does not exist in /usr/local/bin/${clear}"
    check_message[2_en]="${textcolor}[?]${clear} Enter the proxy command you want to delete or enter ${textcolor}x${clear} to exit:"

    while [[ -z $del_comm ]] || [[ ! -f /usr/local/bin/${del_comm} ]]
    do
        if [[ -n $del_comm ]]
        then
            echo -e "${check_message[1_$language]}"
            echo ""
        fi
        echo -e "${check_message[2_$language]}"
        read -r del_comm
        [[ -n $del_comm ]] && echo ""
        exit_del_proxy
    done
}

enter_proxy_data_del() {
    declare -A -g input_message=()
    input_message[1_ru]="${textcolor}[?]${clear} Введите удаляемую команду для прокси или введите ${textcolor}x${clear}, чтобы выйти:"
    input_message[1_en]="${textcolor}[?]${clear} Enter the proxy command you want to delete or enter ${textcolor}x${clear} to exit:"

    echo -e "${input_message[1_$language]}"
    read -r del_comm
    [[ -n $del_comm ]] && echo ""
    exit_del_proxy
    check_command_del
}

client_script_del() {
    declare -A -g info_message=()
    info_message[1_ru]="Команда ${textcolor}${del_comm}${clear} удалена из /usr/local/bin/"
    info_message[1_en]="The command ${textcolor}${del_comm}${clear} has been deleted from /usr/local/bin/"

    rm -f /usr/local/bin/${del_comm}
    sed -i "/#${del_comm}/d" /usr/local/bin/proxylist
    echo -e "${info_message[1_$language]}"
    echo ""
}

delete_proxies() {
    while [[ ! ${del_comm,,} =~ ^(x|х)$ ]]
    do
        enter_proxy_data_del
        client_script_del
    done
}

### MAIN MENU ###

main_menu() {
    menu_text_ru() {
        echo ""
        echo -e "${textcolor}Выберите действие:${clear}"
        echo "0 - Выйти"
        echo "1 - Вывести список прокси"
        echo "2 - Добавить новый прокси"
        echo "3 - Удалить прокси"
        read -r option
        [[ -n $option ]] && echo ""
    }

    menu_text_en() {
        echo ""
        echo -e "${textcolor}Select an option:${clear}"
        echo "0 - Exit"
        echo "1 - Show the list of proxies"
        echo "2 - Add a new proxy"
        echo "3 - Delete a proxy"
        read -r option
        [[ -n $option ]] && echo ""
    }

    menu_text_${language}

    case $option in
        1)
        show_proxies
        ;;
        2)
        add_proxies
        ;;
        3)
        delete_proxies
        ;;
        *)
        exit 0
    esac
}

check_root
check_sbmanager
banner
enter_language
install_sing_box
main_menu
