#!/bin/bash
set -o pipefail

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
    local -A csb_message=()
    csb_message[1_ru]="${textcolor}Sing-Box успешно скачан${clear}"
    csb_message[2_ru]="Его можно обновить, удалив файл ${textcolor}${HOME}/sing-box-dir/sing-box${clear} и запустив этот скрипт ещё раз"
    csb_message[3_ru]="${red}Ошибка: не удалось скачать Sing-Box, попробуйте позже${clear}"
    csb_message[1_en]="${textcolor}Sing-Box has been downloaded successfully${clear}"
    csb_message[2_en]="It can be updated by deleting the ${textcolor}${HOME}/sing-box-dir/sing-box${clear} file and running this script again"
    csb_message[3_en]="${red}Error: failed to download Sing-Box, try again later${clear}"

    if "${HOME}/sing-box-dir/sing-box" version &> /dev/null
    then
        echo -e "${csb_message[1_$language]}"
        echo ""
        echo -e "${csb_message[2_$language]}"
        echo ""
    else
        echo ""
        echo -e "${csb_message[3_$language]}"
        echo ""
        exit 1
    fi
}

download_sing_box() {
    local -A dsb_message=()
    dsb_message[1_ru]="${textcolor}Sing-Box не найден в ${HOME}/sing-box-dir/${clear}"
    dsb_message[2_ru]="${textcolor}[?]${clear} Нажмите ${textcolor}Enter${clear}, чтобы скачать, или введите ${textcolor}x${clear}, чтобы выйти:"
    dsb_message[3_ru]="${textcolor}Скачивание Sing-Box...${clear}"
    dsb_message[1_en]="${textcolor}Sing-Box was not found in ${HOME}/sing-box-dir/${clear}"
    dsb_message[2_en]="${textcolor}[?]${clear} Press ${textcolor}Enter${clear} to download it or enter ${textcolor}x${clear} to exit:"
    dsb_message[3_en]="${textcolor}Downloading Sing-Box...${clear}"

    if [[ ! -f ${HOME}/sing-box-dir/sing-box ]]
    then
        echo ""
        echo -e "${dsb_message[1_$language]}"
        echo ""
        echo -e "${dsb_message[2_$language]}"
        local sb_download; read -r sb_download
        [[ -n $sb_download ]] && echo ""
        [[ ${sb_download,,} =~ ^(x|х)$ ]] && exit 0

        echo -e "${dsb_message[3_$language]}"
        [[ ! -d ${HOME}/sing-box-dir ]] && mkdir "${HOME}/sing-box-dir"
        local proc_arch="amd64"
        [[ $(uname -m) == "aarch64" || $(uname -m) == "arm64" ]] && proc_arch="arm64"
        local zip_url=$(curl -Ls -m 60 https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep "browser_download_url.*linux-${proc_arch}.tar.gz" | head -n 1 | cut -d '"' -f 4)
        wget -O "${HOME}/sing-box-dir/sing-box.tar.gz" -T 300 "${zip_url}"
        tar -xf "${HOME}/sing-box-dir/sing-box.tar.gz" --strip-components=1 -C "${HOME}/sing-box-dir"
        rm -f "${HOME}/sing-box-dir/sing-box.tar.gz"
        chmod +x "${HOME}/sing-box-dir/sing-box"
        check_sing_box
    fi
}

### OPTION 1 - SHOW PROXIES ###

show_proxies() {
    local -A sp_message=()
    sp_message[1_ru]="${textcolor}Количество прокси:${clear}"
    sp_message[1_en]="${textcolor}Number of proxies:${clear}"

    local proxy_num=$(ls -A1 "${HOME}/sing-box-dir" | grep -c ".sh")
    echo -e "${sp_message[1_$language]} ${proxy_num}"
    ls -A1 "${HOME}/sing-box-dir" | grep ".sh" | sed "s/\.sh//g"
    echo ""
}

### OPTION 2 - ADD PROXIES ###

enter_check_link() {
    local -A ecl_message=()
    ecl_message[1_ru]="${textcolor}[?]${clear} Введите ссылку на ваш клиентский конфиг или введите ${textcolor}x${clear}, чтобы выйти:"
    ecl_message[2_ru]="${red}Ошибка: ссылка введена неправильно или сервер недоступен${clear}"
    ecl_message[1_en]="${textcolor}[?]${clear} Enter your client config link or enter ${textcolor}x${clear} to exit:"
    ecl_message[2_en]="${red}Error: the link is incorrect or the server is not available${clear}"

    while true
    do
        echo -e "${ecl_message[1_$language]}"
        read -r link
        [[ -n $link ]] && echo ""
        link=${link#*"://"}

        if [[ ${link,,} =~ ^(x|х)$ ]]
        then
            return 111
        elif [[ -z $link ]]
        then
            :
        elif [[ ! $(curl -s -m 60 "https://${link}" 2> /dev/null) =~ '"tag": "proxy"' ]]
        then
            echo -e "${ecl_message[2_$language]}"
            echo ""
        else
            break
        fi
    done
}

enter_check_command_add() {
    local -A ecca_message=()
    ecca_message[1_ru]="${textcolor}[?]${clear} Введите команду для нового прокси:"
    ecca_message[2_ru]="${red}Ошибка: команда должна содержать только английские буквы, цифры, символы _ и -${clear}"
    ecca_message[3_ru]="${red}Ошибка: эта команда уже существует${clear}"
    ecca_message[1_en]="${textcolor}[?]${clear} Enter the command for the new proxy:"
    ecca_message[2_en]="${red}Error: the command should contain only letters, numbers, _ and - symbols${clear}"
    ecca_message[3_en]="${red}Error: this command already exists${clear}"

    while true
    do
        echo -e "${ecca_message[1_$language]}"
        read -r new_comm
        [[ -n $new_comm ]] && echo ""

        if [[ -z $new_comm ]]
        then
            :
        elif [[ ! $new_comm =~ ^[a-zA-Z0-9_-]+$ ]]
        then
            echo -e "${ecca_message[2_$language]}"
            echo ""
        elif [[ -f ${HOME}/sing-box-dir/${new_comm}.sh ]] || type "${new_comm}" &> /dev/null
        then
            echo -e "${ecca_message[3_$language]}"
            echo ""
        else
            break
        fi
    done
}

client_script_add() {
    local -A csa_message=()
    csa_message[1_ru]='${red}Ошибка: эту команду нужно запускать с sudo (требуется для запуска tun интерфейса)${clear}'
    csa_message[2_ru]='${textcolor}Sing-Box запущен${clear}'
    csa_message[3_ru]='Не закрывайте это окно, пока Sing-Box работает'
    csa_message[4_ru]='Нажмите ${textcolor}Ctrl + C${clear}, чтобы отключиться'
    csa_message[5_ru]="Команда ${textcolor}${new_comm}${clear} добавлена в ${HOME}/sing-box-dir/, используйте её для подключения к прокси"
    csa_message[1_en]='${red}Error: this command should be run with sudo (required to start tun interface)${clear}'
    csa_message[2_en]='${textcolor}Started Sing-Box${clear}'
    csa_message[3_en]='Do not close this window while Sing-Box is running'
    csa_message[4_en]='Press ${textcolor}Ctrl + C${clear} to disconnect'
    csa_message[5_en]="Command ${textcolor}${new_comm}${clear} has been added to ${HOME}/sing-box-dir/, use it to connect to the proxy"

	cat > "${HOME}/sing-box-dir/${new_comm}.sh" <<-EOF
	#!/bin/bash

	textcolor='\033[1;36m'
	red='\033[1;31m'
	clear='\033[0m'

	if [[ \$EUID -ne 0 ]]
	then
	    echo -e "${csa_message[1_$language]}"
	    exit 1
	fi

	echo ""
	echo -e "${csa_message[2_$language]}"
	echo "${csa_message[3_$language]}"
	echo -e "${csa_message[4_$language]}"
	echo ""

	link="https://${link}"
	cd "${HOME}/sing-box-dir" || exit 1
	wget -q -O client.json.1 -T 60 "\${link}" && mv -f client.json.1 client.json
	./sing-box run -c client.json
	EOF

    chmod +x "${HOME}/sing-box-dir/${new_comm}.sh"
    grep -q "alias sudo=" "${HOME}/.bashrc" || echo "alias sudo='sudo '" >> "${HOME}/.bashrc"
    echo "alias ${new_comm}='${HOME}/sing-box-dir/${new_comm}.sh'" >> "${HOME}/.bashrc"
    echo -e "${csa_message[5_$language]}"
    echo ""
}

add_proxies() {
    local link new_comm

    while [[ ! ${link,,} =~ ^(x|х)$ ]]
    do
        enter_check_link; [[ $? -eq 111 ]] && return 111
        enter_check_command_add
        client_script_add
    done
}

### OPTION 3 - DELETE PROXIES ###

enter_check_command_del() {
    local -A eccd_message=()
    eccd_message[1_ru]="${textcolor}[?]${clear} Введите удаляемую команду для прокси или введите ${textcolor}x${clear}, чтобы выйти:"
    eccd_message[2_ru]="${red}Ошибка: эта команда не существует в ${HOME}/sing-box-dir/${clear}"
    eccd_message[1_en]="${textcolor}[?]${clear} Enter the proxy command you want to delete or enter ${textcolor}x${clear} to exit:"
    eccd_message[2_en]="${red}Error: this command does not exist in ${HOME}/sing-box-dir/${clear}"

    while true
    do
        echo -e "${eccd_message[1_$language]}"
        read -r del_comm
        [[ -n $del_comm ]] && echo ""

        if [[ ${del_comm,,} =~ ^(x|х)$ ]]
        then
            return 111
        elif [[ -z $del_comm ]]
        then
            :
        elif [[ ! -f ${HOME}/sing-box-dir/${del_comm}.sh ]]
        then
            echo -e "${eccd_message[2_$language]}"
            echo ""
        else
            break
        fi
    done
}

client_script_del() {
    local -A csd_message=()
    csd_message[1_ru]="Команда ${textcolor}${del_comm}${clear} удалена из ${HOME}/sing-box-dir/"
    csd_message[1_en]="Command ${textcolor}${del_comm}${clear} has been deleted from ${HOME}/sing-box-dir/"

    rm -f "${HOME}/sing-box-dir/${del_comm}.sh"
    sed -i "/alias ${del_comm}=/d" "${HOME}/.bashrc"
    echo -e "${csd_message[1_$language]}"
    echo ""
}

delete_proxies() {
    local del_comm

    while [[ ! ${del_comm,,} =~ ^(x|х)$ ]]
    do
        enter_check_command_del; [[ $? -eq 111 ]] && return 111
        client_script_del
    done
}

### MAIN MENU ###

main_menu_text_ru() {
    echo ""
    echo -e "${textcolor}Выберите действие:${clear}"
    echo "0 - Выйти"
    echo "1 - Вывести список прокси"
    echo "2 - Добавить новый прокси"
    echo "3 - Удалить прокси"
    read -r option
    [[ -n $option ]] && echo ""
}

main_menu_text_en() {
    echo ""
    echo -e "${textcolor}Select an option:${clear}"
    echo "0 - Exit"
    echo "1 - Show the list of proxies"
    echo "2 - Add a new proxy"
    echo "3 - Delete a proxy"
    read -r option
    [[ -n $option ]] && echo ""
}

main_menu() {
    while true
    do
        "main_menu_text_${language}"

        case "$option" in
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
    done
}

banner
enter_language
download_sing_box
main_menu
