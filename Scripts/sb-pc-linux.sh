#!/bin/bash

textcolor='\033[1;36m'
red='\033[1;31m'
clear='\033[0m'

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

check_sing_box() {
    declare -A -g check_message=()
    check_message[1_ru]="${textcolor}Sing-Box успешно скачан${clear}"
    check_message[2_ru]="Его можно обновить, удалив файл ${textcolor}${HOME}/sing-box-dir/sing-box${clear} и запустив этот скрипт ещё раз"
    check_message[3_ru]="${red}Ошибка: не удалось скачать Sing-Box, попробуйте позже${clear}"
    check_message[1_en]="${textcolor}Sing-Box has been downloaded successfully${clear}"
    check_message[2_en]="It can be updated by deleting the ${textcolor}${HOME}/sing-box-dir/sing-box${clear} file and running this script again"
    check_message[3_en]="${red}Error: failed to download Sing-Box, try again later${clear}"

    if ~/sing-box-dir/sing-box version &> /dev/null
    then
        echo -e "${check_message[1_$language]}"
        echo ""
        echo -e "${check_message[2_$language]}"
        echo ""
    else
        echo ""
        echo -e "${check_message[3_$language]}"
        echo ""
        exit 1
    fi
}

download_sing_box() {
    declare -A -g general_message=()
    general_message[1_ru]="${textcolor}Sing-Box не найден в ${HOME}/sing-box-dir/${clear}"
    general_message[2_ru]="${textcolor}[?]${clear} Нажмите ${textcolor}Enter${clear}, чтобы скачать, или введите ${textcolor}x${clear}, чтобы выйти:"
    general_message[3_ru]="${textcolor}Скачивание Sing-Box...${clear}"
    general_message[1_en]="${textcolor}Sing-Box was not found in ${HOME}/sing-box-dir/${clear}"
    general_message[2_en]="${textcolor}[?]${clear} Press ${textcolor}Enter${clear} to download it or enter ${textcolor}x${clear} to exit:"
    general_message[3_en]="${textcolor}Downloading Sing-Box...${clear}"

    if [[ ! -f ~/sing-box-dir/sing-box ]]
    then
        echo ""
        echo -e "${general_message[1_$language]}"
        echo ""
        echo -e "${general_message[2_$language]}"
        read -r sb_download
        [[ -n $sb_download ]] && echo ""
        [[ ${sb_download,,} =~ ^(x|х)$ ]] && exit 0

        echo -e "${general_message[3_$language]}"
        [[ ! -d ~/sing-box-dir ]] && mkdir ~/sing-box-dir
        proc_arch="amd64"
        [[ $(uname -m) == "aarch64" || $(uname -m) == "arm64" ]] && proc_arch="arm64"
        zip_url=$(curl -Ls https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep "browser_download_url.*linux-${proc_arch}.tar.gz" | head -n 1 | cut -d '"' -f 4)
        wget -O ~/sing-box-dir/sing-box.tar.gz "${zip_url}"
        tar -xf ~/sing-box-dir/sing-box.tar.gz --strip-components=1 -C ~/sing-box-dir
        rm -f ~/sing-box-dir/sing-box.tar.gz
        chmod +x ~/sing-box-dir/sing-box
        check_sing_box
    fi
}

### OPTION 1 - SHOW PROXIES ###

show_proxies() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor}Количество прокси:${clear}"
    info_message[1_en]="${textcolor}Number of proxies:${clear}"

    proxy_num=$(ls -A1 ~/sing-box-dir | grep ".sh" | wc -l)
    echo -e "${info_message[1_$language]} ${proxy_num}"
    ls -A1 ~/sing-box-dir | grep ".sh" | sed "s/\.sh//g"
    echo ""
    main_menu
}

### OPTION 2 - ADD PROXIES ###

enter_check_link() {
    declare -A -g check_message=()
    check_message[1_ru]="${textcolor}[?]${clear} Введите ссылку на ваш клиентский конфиг или введите ${textcolor}x${clear}, чтобы выйти:"
    check_message[2_ru]="${red}Ошибка: ссылка введена неправильно или сервер недоступен${clear}"
    check_message[1_en]="${textcolor}[?]${clear} Enter your client config link or enter ${textcolor}x${clear} to exit:"
    check_message[2_en]="${red}Error: the link is incorrect or the server is not available${clear}"

    while true
    do
        echo -e "${check_message[1_$language]}"
        read -r link
        [[ -n $link ]] && echo ""
        link=${link#*"://"}

        if [[ ${link,,} =~ ^(x|х)$ ]]
        then
            link=""
            main_menu
        elif [[ -z $link ]]
        then
            :
        elif [[ ! $(curl -s "https://${link}" 2> /dev/null) =~ '"tag": "proxy"' ]]
        then
            echo -e "${check_message[2_$language]}"
            echo ""
        else
            break
        fi
    done
}

enter_check_command_add() {
    declare -A -g check_message=()
    check_message[1_ru]="${textcolor}[?]${clear} Введите команду для нового прокси:"
    check_message[2_ru]="${red}Ошибка: команда должна содержать только английские буквы, цифры, символы _ и -${clear}"
    check_message[3_ru]="${red}Ошибка: эта команда уже существует${clear}"
    check_message[1_en]="${textcolor}[?]${clear} Enter the command for the new proxy:"
    check_message[2_en]="${red}Error: the command should contain only letters, numbers, _ and - symbols${clear}"
    check_message[3_en]="${red}Error: this command already exists${clear}"

    while true
    do
        echo -e "${check_message[1_$language]}"
        read -r new_comm
        [[ -n $new_comm ]] && echo ""

        if [[ -z $new_comm ]]
        then
            :
        elif [[ ! $new_comm =~ ^[a-zA-Z0-9_-]+$ ]]
        then
            echo -e "${check_message[2_$language]}"
            echo ""
        elif [[ -f ~/sing-box-dir/${new_comm}.sh ]] || type ${new_comm} &> /dev/null
        then
            echo -e "${check_message[3_$language]}"
            echo ""
        else
            break
        fi
    done
}

client_script_add() {
    declare -A -g info_message=()
    info_message[1_ru]='${red}Ошибка: эту команду нужно запускать с sudo (требуется для запуска tun интерфейса)${clear}'
    info_message[2_ru]='${textcolor}Sing-Box запущен${clear}'
    info_message[3_ru]='Не закрывайте это окно, пока Sing-Box работает'
    info_message[4_ru]='Нажмите ${textcolor}Ctrl + C${clear}, чтобы отключиться'
    info_message[5_ru]="Команда ${textcolor}${new_comm}${clear} добавлена в ${HOME}/sing-box-dir/, используйте её для подключения к прокси"
    info_message[1_en]='${red}Error: this command should be run with sudo (required to start tun interface)${clear}'
    info_message[2_en]='${textcolor}Started Sing-Box${clear}'
    info_message[3_en]='Do not close this window while Sing-Box is running'
    info_message[4_en]='Press ${textcolor}Ctrl + C${clear} to disconnect'
    info_message[5_en]="The command ${textcolor}${new_comm}${clear} has been added to ${HOME}/sing-box-dir/, use it to connect to the proxy"

	cat > ~/sing-box-dir/${new_comm}.sh <<-EOF
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

	link="https://${link}"
	cd "${HOME}/sing-box-dir" || exit 1
	wget -q -O client.json.1 "\${link}" && mv -f client.json.1 client.json
	./sing-box run -c client.json
	EOF

    chmod +x ~/sing-box-dir/${new_comm}.sh
    grep -q "alias sudo=" ~/.bashrc || echo "alias sudo='sudo '" >> ~/.bashrc
    echo "alias ${new_comm}='${HOME}/sing-box-dir/${new_comm}.sh'" >> ~/.bashrc
    echo -e "${info_message[5_$language]}"
    echo ""
}

add_proxies() {
    while [[ ! ${link,,} =~ ^(x|х)$ ]]
    do
        enter_check_link
        enter_check_command_add
        client_script_add
    done
}

### OPTION 3 - DELETE PROXIES ###

enter_check_command_del() {
    declare -A -g check_message=()
    check_message[1_ru]="${textcolor}[?]${clear} Введите удаляемую команду для прокси или введите ${textcolor}x${clear}, чтобы выйти:"
    check_message[2_ru]="${red}Ошибка: эта команда не существует в ${HOME}/sing-box-dir/${clear}"
    check_message[1_en]="${textcolor}[?]${clear} Enter the proxy command you want to delete or enter ${textcolor}x${clear} to exit:"
    check_message[2_en]="${red}Error: this command does not exist in ${HOME}/sing-box-dir/${clear}"

    while true
    do
        echo -e "${check_message[1_$language]}"
        read -r del_comm
        [[ -n $del_comm ]] && echo ""

        if [[ ${del_comm,,} =~ ^(x|х)$ ]]
        then
            del_comm=""
            main_menu
        elif [[ -z $del_comm ]]
        then
            :
        elif [[ ! -f ~/sing-box-dir/${del_comm}.sh ]]
        then
            echo -e "${check_message[2_$language]}"
            echo ""
        else
            break
        fi
    done
}

client_script_del() {
    declare -A -g info_message=()
    info_message[1_ru]="Команда ${textcolor}${del_comm}${clear} удалена из ${HOME}/sing-box-dir/"
    info_message[1_en]="The command ${textcolor}${del_comm}${clear} has been deleted from ${HOME}/sing-box-dir/"

    rm -f ~/sing-box-dir/${del_comm}.sh
    sed -i "/alias ${del_comm}=/d" ~/.bashrc
    echo -e "${info_message[1_$language]}"
    echo ""
}

delete_proxies() {
    while [[ ! ${del_comm,,} =~ ^(x|х)$ ]]
    do
        enter_check_command_del
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

banner
enter_language
download_sing_box
main_menu
