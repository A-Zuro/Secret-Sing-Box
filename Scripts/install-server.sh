#!/bin/bash

textcolor='\033[1;36m'
textcolor_light='\033[1;37m'
red='\033[1;31m'
clear='\033[0m'

check_os() {
    if ! grep -q -e "bullseye" -e "bookworm" -e "trixie" -e "jammy" -e "noble" /etc/os-release
    then
        echo ""
        echo -e "${red}Error: only Debian 11/12/13 and Ubuntu 22.04/24.04 are supported${clear}"
        echo ""
        exit 1
    fi
}

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
    if [[ -f /usr/local/bin/sbmanager ]]
    then
        echo ""
        echo -e "${red}Error: the script has already been run, no need to run it again${clear}"
        echo ""
        exit 1
    fi
}

banner() {
    echo ""
    echo ""
    echo "╔══╗ ╔═══ ╔══╗ ╦══╗ ╔═══ ══╦══"
    echo "║    ║    ║    ║  ║ ║      ║  "
    echo "╚══╗ ╠═══ ║    ╠╦═╝ ╠═══   ║  "
    echo "   ║ ║    ║    ║╚╗  ║      ║  "
    echo "╚══╝ ╚═══ ╚══╝ ╩ ╚═ ╚═══   ╩  "
    echo ""
    echo "╔══╗ ╦ ╦╗  ╦ ╔══╗    ╦══╗ ╔══╗ ═╗  ╔"
    echo "║    ║ ║╚╗ ║ ║       ║  ║ ║  ║  ╚╗╔╝"
    echo "╚══╗ ║ ║ ║ ║ ║ ═╗ ══ ╠══╣ ║  ║  ╔╬╝ "
    echo "   ║ ║ ║ ╚╗║ ║  ║    ║  ║ ║  ║ ╔╝╚╗ "
    echo "╚══╝ ╩ ╩  ╚╩ ╚══╝    ╩══╝ ╚══╝ ╝  ╚═"
    echo ""
    echo ""
}

enter_language() {
    echo -e "${textcolor}Select the language:${clear}"
    echo "1 - Russian"
    echo "2 - English"
    read -r language
    [[ -n $language ]] && echo ""
    echo ""

    if [[ "$language" == "1" ]]
    then
        language="ru"
    else
        language="en"
    fi
}

start_text_ru() {
    echo -e "${red}ВНИМАНИЕ!${clear}"
    echo "Запускайте скрипт на чистой системе"
    echo ""
    echo "Перед запуском скрипта нужно выполнить следующие действия:"
    echo -e "1) Обновить систему на сервере командой ${textcolor}apt update -y && apt full-upgrade -y${clear}"
    echo -e "2) Перезагрузить сервер командой ${textcolor}reboot${clear}"
    echo ""
    echo -e "Если это сделано, то нажмите ${textcolor}Enter${clear}, чтобы продолжить"
    echo -e "В противном случае нажмите ${textcolor}Ctrl + C${clear} для завершения работы скрипта"
    read -r big_red_button
    [[ -n $big_red_button ]] && echo ""
    echo ""
}

start_text_en() {
    echo -e "${red}ATTENTION!${clear}"
    echo "Run the script on a newly installed system"
    echo ""
    echo "Before running the script, it's necessary to do the following:"
    echo -e "1) Update the system on the server (${textcolor}apt update -y && apt full-upgrade -y${clear})"
    echo -e "2) Reboot the server (${textcolor}reboot${clear})"
    echo ""
    echo -e "If it's done, then press ${textcolor}Enter${clear} to continue"
    echo -e "If not, then press ${textcolor}Ctrl + C${clear} to exit the script"
    read -r big_red_button
    [[ -n $big_red_button ]] && echo ""
    echo ""
}

update_and_reboot() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor}Обновление системы завершено${clear}"
    info_message[2_ru]="${textcolor}Через минуту снова подключитесь к серверу по SSH и ещё раз запустите скрипт${clear}"
    info_message[1_en]="${textcolor}The system update is complete${clear}"
    info_message[2_en]="${textcolor}In a minute, reconnect to the server via SSH and run the script again${clear}"

    if [[ "$system_updated" == "1" ]]
    then
        apt update -y && apt full-upgrade -y
        sleep 1.5
        echo ""
        echo -e "${info_message[1_$language]}"
        echo -e "${info_message[2_$language]}"
        echo ""
        reboot
        exit 0
    fi
}

get_ip() {
    grep -q '^precedence \+::ffff:0:0/96 ' /etc/gai.conf &> /dev/null || echo "precedence ::ffff:0:0/96 100" >> /etc/gai.conf
    server_ip=$(curl -s https://cloudflare.com/cdn-cgi/trace | grep "ip" | cut -d "=" -f 2)
    [[ ! $server_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && server_ip=$(curl -s ipinfo.io/ip)
    [[ ! $server_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && server_ip=$(curl -s 2ip.io)
}

crop_domain() {
    domain=${domain#*"://"}
    domain=${domain#"www."}
    domain=$(echo "${domain}" | cut -d "/" -f 1)
}

crop_redirect_domain() {
    redirect=${redirect#*"://"}
    redirect=${redirect#"www."}
    redirect=$(echo "${redirect}" | cut -d "/" -f 1)
}

edit_index_path() {
    [[ "$index_path" != "/"* ]] && index_path="/${index_path}"
    index_path=${index_path%"/"}
}

get_test_response() {
    test_domain=$(echo "${domain}" | rev | cut -d "." -f 1-2 | rev)

    if [[ $cf_token =~ [A-Z] ]]
    then
        test_response=$(curl -s --request GET --url https://api.cloudflare.com/client/v4/zones --header "Authorization: Bearer ${cf_token}" --header "Content-Type: application/json")
    else
        test_response=$(curl -s --request GET --url https://api.cloudflare.com/client/v4/zones --header "X-Auth-Key: ${cf_token}" --header "X-Auth-Email: ${email}" --header "Content-Type: application/json")
    fi
}

check_cf_token() {
    declare -A -g check_message=()
    check_message[1_ru]="Проверка домена, API токена/ключа и почты..."
    check_message[2_ru]="${red}Ошибка: неправильно введён домен, API токен/ключ или почта${clear}"
    check_message[3_ru]="${red}Инструкция: https://github.com/A-Zuro/Secret-Sing-Box/blob/main/.github/cf-settings-ru.md#получение-api-токена-cloudflare${clear}"
    check_message[4_ru]="Успешно!"
    check_message[1_en]="Checking domain name, API token/key and email..."
    check_message[2_en]="${red}Error: invalid domain name, API token/key or email${clear}"
    check_message[3_en]="${red}Instruction: https://github.com/A-Zuro/Secret-Sing-Box/blob/main/.github/cf-settings-en.md#getting-cloudflare-api-token${clear}"
    check_message[4_en]="Success!"

    echo "${check_message[1_$language]}"
    get_test_response

    while [[ $domain =~ ".." ]] || [[ ! $test_response =~ "\"$test_domain\"" ]] || [[ ! $test_response =~ "#dns_records:edit" ]] || [[ ! $test_response =~ "#dns_records:read" ]] || [[ ! $test_response =~ "#zone:read" ]]
    do
        echo ""
        echo -e "${check_message[2_$language]}"
        echo -e "${check_message[3_$language]}"
        enter_domain_data
        echo "${check_message[1_$language]}"
        get_test_response
    done

    echo "${check_message[4_$language]}"
    echo ""
}

check_trjpass() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: пароль Trojan не должен содержать кавычки \"${clear}"
    check_message[2_ru]="${textcolor}[?]${clear} Введите пароль для Trojan или оставьте пустым для генерации случайного пароля:"
    check_message[1_en]="${red}Error: Trojan password should not contain quotes \"${clear}"
    check_message[2_en]="${textcolor}[?]${clear} Enter your password for Trojan or leave this empty to generate a random password:"

    while [[ $trjpass =~ '"' ]]
    do
        echo -e "${check_message[1_$language]}"
        echo ""
        echo -e "${check_message[2_$language]}"
        read -r trjpass
        [[ -n $trjpass ]] && echo ""
    done
}

check_uuid() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: введённое значение не является UUID${clear}"
    check_message[2_ru]="${textcolor}[?]${clear} Введите UUID для VLESS или оставьте пустым для генерации случайного UUID:"
    check_message[1_en]="${red}Error: this is not an UUID${clear}"
    check_message[2_en]="${textcolor}[?]${clear} Enter your UUID for VLESS or leave this empty to generate a random UUID:"

    while [[ ! $uuid =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]] && [[ -n $uuid ]]
    do
        echo -e "${check_message[1_$language]}"
        echo ""
        echo -e "${check_message[2_$language]}"
        read -r uuid
        [[ -n $uuid ]] && echo ""
    done
}

check_trojan_path() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: путь должен содержать только английские буквы, цифры, символы _ и -${clear}"
    check_message[2_ru]="${textcolor}[?]${clear} Введите путь для Trojan или оставьте пустым для генерации случайного пути:"
    check_message[1_en]="${red}Error: the path should contain only letters, numbers, _ and - symbols${clear}"
    check_message[2_en]="${textcolor}[?]${clear} Enter your path for Trojan or leave this empty to generate a random path:"

    while [[ ! $trojanpath =~ ^[a-zA-Z0-9_-]+$ ]] && [[ -n $trojanpath ]]
    do
        echo -e "${check_message[1_$language]}"
        echo ""
        echo -e "${check_message[2_$language]}"
        read -r trojanpath
        [[ -n $trojanpath ]] && echo ""
        trojanpath=${trojanpath#"/"}
    done
}

check_vless_path() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: путь должен содержать только английские буквы, цифры, символы _ и -${clear}"
    check_message[2_ru]="${red}Ошибка: пути для Trojan и VLESS должны быть разными${clear}"
    check_message[3_ru]="${textcolor}[?]${clear} Введите путь для VLESS или оставьте пустым для генерации случайного пути:"
    check_message[1_en]="${red}Error: the path should contain only letters, numbers, _ and - symbols${clear}"
    check_message[2_en]="${red}Error: paths for Trojan and VLESS must be different${clear}"
    check_message[3_en]="${textcolor}[?]${clear} Enter your path for VLESS or leave this empty to generate a random path:"

    while ([[ ! $vlesspath =~ ^[a-zA-Z0-9_-]+$ ]] || [[ "$vlesspath" == "$trojanpath" ]]) && [[ -n $vlesspath ]]
    do
        if [[ ! $vlesspath =~ ^[a-zA-Z0-9_-]+$ ]]
        then
            echo -e "${check_message[1_$language]}"
        else
            echo -e "${check_message[2_$language]}"
        fi
        echo ""
        echo -e "${check_message[3_$language]}"
        read -r vlesspath
        [[ -n $vlesspath ]] && echo ""
        vlesspath=${vlesspath#"/"}
    done
}

check_subscription_path() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: путь должен содержать только английские буквы, цифры, символы _ и -${clear}"
    check_message[2_ru]="${red}Ошибка: пути для Trojan, VLESS и подписки должны быть разными${clear}"
    check_message[3_ru]="${textcolor}[?]${clear} Введите путь для подписки или оставьте пустым для генерации случайного пути:"
    check_message[1_en]="${red}Error: the path should contain only letters, numbers, _ and - symbols${clear}"
    check_message[2_en]="${red}Error: paths for Trojan, VLESS and subscription must be different${clear}"
    check_message[3_en]="${textcolor}[?]${clear} Enter your subscription path or leave this empty to generate a random path:"

    while ([[ ! $subspath =~ ^[a-zA-Z0-9_-]+$ ]] || [[ "$subspath" == "$trojanpath" ]] || [[ "$subspath" == "$vlesspath" ]]) && [[ -n $subspath ]]
    do
        if [[ ! $subspath =~ ^[a-zA-Z0-9_-]+$ ]]
        then
            echo -e "${check_message[1_$language]}"
        else
            echo -e "${check_message[2_$language]}"
        fi
        echo ""
        echo -e "${check_message[3_$language]}"
        read -r subspath
        [[ -n $subspath ]] && echo ""
        subspath=${subspath#"/"}
    done
}

check_rulesetpath() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: путь должен содержать только английские буквы, цифры, символы _ и -${clear}"
    check_message[2_ru]="${red}Ошибка: пути для Trojan, VLESS, подписки и наборов правил должны быть разными${clear}"
    check_message[3_ru]="${textcolor}[?]${clear} Введите путь для наборов правил (rule sets) или оставьте пустым для генерации случайного пути:"
    check_message[1_en]="${red}Error: the path should contain only letters, numbers, _ and - symbols${clear}"
    check_message[2_en]="${red}Error: paths for Trojan, VLESS, subscription and rule sets must be different${clear}"
    check_message[3_en]="${textcolor}[?]${clear} Enter your path for rule sets or leave this empty to generate a random path:"

    while ([[ ! $rulesetpath =~ ^[a-zA-Z0-9_-]+$ ]] || [[ "$rulesetpath" == "$trojanpath" ]] || [[ "$rulesetpath" == "$vlesspath" ]] || [[ "$rulesetpath" == "$subspath" ]]) && [[ -n $rulesetpath ]]
    do
        if [[ ! $rulesetpath =~ ^[a-zA-Z0-9_-]+$ ]]
        then
            echo -e "${check_message[1_$language]}"
        else
            echo -e "${check_message[2_$language]}"
        fi
        echo ""
        echo -e "${check_message[3_$language]}"
        read -r rulesetpath
        [[ -n $rulesetpath ]] && echo ""
        rulesetpath=${rulesetpath#"/"}
    done
}

check_ssh_port() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: номер порта должен быть целым положительным числом${clear}"
    check_message[2_ru]="${red}Ошибка: номер порта не может быть больше 65535${clear}"
    check_message[3_ru]="${red}Ошибка: порты 80, 443, 10443, 11443 и 40000 будут заняты${clear}"
    check_message[4_ru]="${textcolor}[?]${clear} Введите новый номер порта SSH или 22 (рекомендуется номер более 1024):"
    check_message[1_en]="${red}Error: the port number must be a positive integer${clear}"
    check_message[2_en]="${red}Error: the port number can't be greater than 65535${clear}"
    check_message[3_en]="${red}Error: the ports 80, 443, 10443, 11443 and 40000 will be taken${clear}"
    check_message[4_en]="${textcolor}[?]${clear} Enter new SSH port number or 22 (number above 1024 is recommended):"

    while [[ ! $ssh_port =~ ^[1-9][0-9]*$ ]] || [[ $ssh_port -gt 65535 ]] || [[ $ssh_port -eq 80 ]] || [[ $ssh_port -eq 443 ]] || [[ $ssh_port -eq 10443 ]] || [[ $ssh_port -eq 11443 ]] || [[ $ssh_port -eq 40000 ]]
    do
        if [[ -z $ssh_port ]]
        then
            :
        elif [[ ! $ssh_port =~ ^[1-9][0-9]*$ ]]
        then
            echo -e "${check_message[1_$language]}"
            echo ""
        elif [[ $ssh_port -gt 65535 ]]
        then
            echo -e "${check_message[2_$language]}"
            echo ""
        else
            echo -e "${check_message[3_$language]}"
            echo ""
        fi
        echo -e "${check_message[4_$language]}"
        read -r ssh_port
        [[ -n $ssh_port ]] && echo ""
    done
}

check_username() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: имя пользователя должно содержать только английские строчные буквы, цифры, символы _ и -, а также начинаться со строчной буквы${clear}"
    check_message[2_ru]="${textcolor}[?]${clear} Введите имя нового пользователя или root (рекомендуется не root):"
    check_message[1_en]="${red}Error: the username should contain only lowercase letters, numbers, _ and - symbols, and must start with a lowercase letter${clear}"
    check_message[2_en]="${textcolor}[?]${clear} Enter your username or root (non-root user is recommended):"

    while [[ ! $username =~ ^[a-z][-a-z0-9_]*\$?$ ]]
    do
        if [[ -n $username ]]
        then
            echo -e "${check_message[1_$language]}"
            echo ""
        fi
        echo -e "${check_message[2_$language]}"
        read -r username
        [[ -n $username ]] && echo ""
    done
}

check_password() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: пароль не должен содержать кавычки \"${clear}"
    check_message[2_ru]="${textcolor}[?]${clear} Введите пароль SSH для нового пользователя (рекомендуется сложный пароль):"
    check_message[1_en]="${red}Error: the password should not contain quotes \"${clear}"
    check_message[2_en]="${textcolor}[?]${clear} Enter SSH password for the new user (a complex password is recommended):"

    while [[ -z $password ]] || [[ $password =~ '"' ]]
    do
        if [[ -n $password ]]
        then
            echo -e "${check_message[1_$language]}"
            echo ""
        fi
        echo -e "${check_message[2_$language]}"
        read -r password
        [[ -n $password ]] && echo ""
    done
}

check_redirect_domain() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: домен введён неправильно или не имеет HTTPS, выберите другой домен${clear}"
    check_message[2_ru]="${textcolor}[?]${clear} Введите домен, на который будет идти перенаправление:"
    check_message[1_en]="${red}Error: this domain is invalid or does not have HTTPS, select another domain${clear}"
    check_message[2_en]="${textcolor}[?]${clear} Enter the domain to which requests will be redirected:"

    while [[ -z $redirect ]] || [[ $redirect =~ " " ]] || [[ $(curl -s -o /dev/null -w "%{http_code}" https://${redirect}) == "000" ]]
    do
        if [[ -n $redirect ]]
        then
            echo -e "${check_message[1_$language]}"
            echo ""
        fi
        echo -e "${check_message[2_$language]}"
        read -r redirect
        [[ -n $redirect ]] && echo ""
        crop_redirect_domain
    done
}

check_site_link() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: сайт недоступен по данной ссылке или не имеет HTTPS, выберите другой сайт${clear}"
    check_message[2_ru]="${textcolor}[?]${clear} Введите ссылку на главную страницу выбранного сайта:"
    check_message[1_en]="${red}Error: the website is not available or does not have HTTPS, select another website${clear}"
    check_message[2_en]="${textcolor}[?]${clear} Enter the link to the main page of the selected website:"

    apt install wget -y &> /dev/null

    while [[ -z $site_link ]] || [[ $site_link =~ " " ]] || [[ $(curl -s -o /dev/null -w "%{http_code}" https://${site_link}) == "000" ]] || ! wget -q -O /dev/null https://${site_link}
    do
        if [[ -n $site_link ]]
        then
            echo -e "${check_message[1_$language]}"
            echo ""
        fi
        echo -e "${check_message[2_$language]}"
        read -r site_link
        [[ -n $site_link ]] && echo ""
        site_link=${site_link#*"://"}
    done
}

check_index_path() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: файл"
    check_message[2_ru]="не существует, проверьте, загружена ли папка вашего сайта в /root директорию сервера${clear}"
    check_message[3_ru]="${textcolor}[?]${clear} Введите путь до index файла внутри папки вашего сайта (например, /site_folder/index.html):"
    check_message[1_en]="${red}Error: the file"
    check_message[2_en]="doesn't exist, check if the folder of your website is uploaded to the /root directory of the server${clear}"
    check_message[3_en]="${textcolor}[?]${clear} Enter the path to the index file inside the folder of your website (e. g., /site_folder/index.html):"

    while [[ -z $index_path ]] || [[ $index_path =~ " " ]] || [[ ! -f /root${index_path} ]]
    do
        if [[ -n $index_path ]]
        then
            echo -e "${check_message[1_$language]} /root${index_path} ${check_message[2_$language]}"
            echo ""
        fi
        echo -e "${check_message[3_$language]}"
        read -r index_path
        [[ -n $index_path ]] && echo ""
        edit_index_path
    done
}

nginx_login() {
    comment_1="#"; comment_2=""; comment_3=""
    redirect="example.com"   # Dummy, will be commented
    site_dir="html"
    index="index.html index.htm"
}

nginx_redirect() {
    declare -A -g input_message=()
    input_message[1_ru]="${textcolor}[?]${clear} Введите домен, на который будет идти перенаправление:"
    input_message[1_en]="${textcolor}[?]${clear} Enter the domain to which requests will be redirected:"

    comment_1=""; comment_2="#"; comment_3=""
    site_dir="html"
    index="index.html index.htm"

    echo -e "${input_message[1_$language]}"
    read -r redirect
    [[ -n $redirect ]] && echo ""
    crop_redirect_domain
    check_redirect_domain
}

nginx_copy_site() {
    comment_1=""; comment_2=""; comment_3="#"
    redirect="example.com"   # Dummy, will be commented

    nginx_copy_site_text_ru() {
        echo -e "${red}ВНИМАНИЕ!${clear}"
        echo "Некоторые сайты могут содержать большие файлы или большое число страниц, которые могут занять много места на диске"
        echo "Функционал некоторых сайтов может быть частично утрачен"
        echo "Вы выбираете какой-либо сайт на свой страх и риск"
        echo ""
        echo -e "${textcolor}[?]${clear} Введите ссылку на главную страницу выбранного сайта:"
        read -r site_link
        [[ -n $site_link ]] && echo ""
    }

    nginx_copy_site_text_en() {
        echo -e "${red}ATTENTION!${clear}"
        echo "Some websites might contain large files or large number of pages, which may take a lot of disk space"
        echo "Some websites may partially lose their functionality"
        echo "You choose the website at your own risk"
        echo ""
        echo -e "${textcolor}[?]${clear} Enter the link to the main page of the selected website:"
        read -r site_link
        [[ -n $site_link ]] && echo ""
    }

    nginx_copy_site_text_${language}
    site_link=${site_link#*"://"}
    check_site_link
}

nginx_site() {
    comment_1=""; comment_2=""; comment_3="#"
    redirect="example.com"   # Dummy, will be commented

    nginx_site_text_ru() {
        echo -e "${red}ВНИМАНИЕ!${clear}"
        echo -e "Сначала загрузите папку с файлами вашего сайта в ${textcolor}/root${clear} директорию сервера"
        echo "Вы можете сделать это с помощью SFTP или SCP через другое окно, не прерывая работу скрипта"
        echo ""
        echo -e "${textcolor}[?]${clear} Введите путь до index файла внутри папки вашего сайта (например, /site_folder/index.html):"
        read -r index_path
        [[ -n $index_path ]] && echo ""
    }

    nginx_site_text_en() {
        echo -e "${red}ATTENTION!${clear}"
        echo -e "First, upload the folder with the contents of your website to the ${textcolor}/root${clear} directory of the server"
        echo "You can do this via SFTP or SCP in another window without interrupting the script"
        echo ""
        echo -e "${textcolor}[?]${clear} Enter the path to the index file inside the folder of your website (e. g., /site_folder/index.html):"
        read -r index_path
        [[ -n $index_path ]] && echo ""
    }

    nginx_site_text_${language}
    edit_index_path
    check_index_path
}

nginx_options() {
    case $option in
        2)
        nginx_redirect
        ;;
        3)
        nginx_copy_site
        ;;
        4)
        nginx_site
        ;;
        *)
        nginx_login
    esac
}

enter_domain_data() {
    declare -A -g input_message=()
    input_message[1_ru]="${textcolor}[?]${clear} Введите ваш домен:"
    input_message[2_ru]="${textcolor}[?]${clear} Введите вашу почту${email_text}:"
    input_message[3_ru]="${textcolor}[?]${clear} Введите ваш API токен Cloudflare (Edit zone DNS) или Cloudflare global API key:"
    input_message[1_en]="${textcolor}[?]${clear} Enter your domain name:"
    input_message[2_en]="${textcolor}[?]${clear} Enter your email${email_text}:"
    input_message[3_en]="${textcolor}[?]${clear} Enter your Cloudflare API token (Edit zone DNS) or Cloudflare global API key:"

    domain=""; email=""; cf_token=""
    echo ""
    while [[ -z $domain ]]
    do
        echo -e "${input_message[1_$language]}"
        read -r domain
        [[ -n $domain ]] && echo ""
    done
    crop_domain
    while [[ -z $email ]]
    do
        echo -e "${input_message[2_$language]}"
        read -r email
        [[ -n $email ]] && echo ""
    done
    if [[ "$validation_type" == "1" ]]
    then
        while [[ -z $cf_token ]]
        do
            echo -e "${input_message[3_$language]}"
            read -r cf_token
            [[ -n $cf_token ]] && echo ""
        done
    fi
}

enter_data_ru() {
    echo -e "${textcolor}[?]${clear} Вы точно обновили систему и перезагрузили сервер перед запуском скрипта?"
    echo "1 - Обновить и перезагрузить сейчас"
    echo "2 - Продолжить (система была обновлена и перезагружена)"
    read -r system_updated
    [[ -n $system_updated ]] && echo ""
    update_and_reboot
    echo -e "${textcolor}[?]${clear} Выберите метод валидации сертификатов:"
    echo "1 - DNS Cloudflare (если ваш домен прикреплён к Cloudflare)"
    echo "2 - Standalone (если ваш домен прикреплён к другому сервису)"
    read -r validation_type
    if [[ "$validation_type" == "1" ]]
    then
        email_text=", зарегистрированную на Cloudflare"
        enter_domain_data
        check_cf_token
    else
        email_text=" для выпуска сертификата"
        [[ -n $validation_type ]] && echo ""
        echo -e "${red}ВНИМАНИЕ!${clear}"
        echo "Обязательно проверьте правильность написания домена"
        enter_domain_data
    fi
    echo -e "${textcolor}[?]${clear} Выберите вариант настройки прокси:"
    echo "1 - Терминирование TLS на NGINX, протоколы Trojan и VLESS, транспорт WebSocket или HTTPUpgrade"
    echo "2 - Терминирование TLS на HAProxy, протокол Trojan, выбор бэкенда Sing-Box или NGINX по паролю Trojan"
    read -r variant
    [[ -n $variant ]] && echo ""
    if [[ "$variant" == "1" ]]
    then
        echo -e "${textcolor}[?]${clear} Выберите транспорт:"
        echo "1 - WebSocket"
        echo "2 - HTTPUpgrade"
        read -r transport
        [[ -n $transport ]] && echo ""
    fi
    echo -e "${textcolor}[?]${clear} Выберите вариант настройки NGINX/HAProxy:"
    echo "1 - Будет спрашивать логин и пароль вместо сайта, 401 Unauthorized"
    echo "2 - Будет перенаправлять на другой домен, 301 Moved Permanently"
    echo "3 - Скопировать чужой сайт на этот сервер, тестовая опция"
    echo "4 - Загрузить свой сайт (при наличии), тестовая опция"
    read -r option
    [[ -n $option ]] && echo ""
    nginx_options
    echo -e "${textcolor}[?]${clear} Введите пароль для Trojan или оставьте пустым для генерации случайного пароля:"
    read -r trjpass
    [[ -n $trjpass ]] && echo ""
    check_trjpass
    if [[ "$variant" == "1" ]]
    then
        echo -e "${textcolor}[?]${clear} Введите путь для Trojan или оставьте пустым для генерации случайного пути:"
        read -r trojanpath
        [[ -n $trojanpath ]] && echo ""
        trojanpath=${trojanpath#"/"}
        check_trojan_path
        echo -e "${textcolor}[?]${clear} Введите UUID для VLESS или оставьте пустым для генерации случайного UUID:"
        read -r uuid
        [[ -n $uuid ]] && echo ""
        check_uuid
        echo -e "${textcolor}[?]${clear} Введите путь для VLESS или оставьте пустым для генерации случайного пути:"
        read -r vlesspath
        [[ -n $vlesspath ]] && echo ""
        vlesspath=${vlesspath#"/"}
        check_vless_path
    fi
    echo -e "${textcolor}[?]${clear} Введите путь для подписки или оставьте пустым для генерации случайного пути:"
    read -r subspath
    [[ -n $subspath ]] && echo ""
    subspath=${subspath#"/"}
    check_subscription_path
    echo -e "${textcolor}[?]${clear} Введите путь для наборов правил (rule sets) или оставьте пустым для генерации случайного пути:"
    read -r rulesetpath
    [[ -n $rulesetpath ]] && echo ""
    rulesetpath=${rulesetpath#"/"}
    check_rulesetpath
    echo -e "${textcolor}[?]${clear} Нужна ли настройка безопасности (SSH, UFW и unattended-upgrades)?"
    echo "1 - Да (в редких случаях при нестандартных настройках у хостера можно потерять доступ к серверу)"
    echo "2 - Нет (тогда рекомендуется выполнить настройку самостоятельно после завершения работы скрипта)"
    read -r ssh_ufw
    [[ -n $ssh_ufw ]] && echo ""
    if [[ "$ssh_ufw" != "2" ]]
    then
        echo -e "${textcolor}[?]${clear} Введите новый номер порта SSH или 22 (рекомендуется номер более 1024):"
        read -r ssh_port
        [[ -n $ssh_port ]] && echo ""
        check_ssh_port
        echo -e "${textcolor}[?]${clear} Введите имя нового пользователя или root (рекомендуется не root):"
        read -r username
        [[ -n $username ]] && echo ""
        check_username
        echo -e "${textcolor}[?]${clear} Введите пароль SSH для нового пользователя (рекомендуется сложный пароль):"
        read -r password
        [[ -n $password ]] && echo ""
        check_password
    fi
    echo ""
    echo ""
}

enter_data_en() {
    echo -e "${textcolor}[?]${clear} Are you sure you have updated the system and rebooted the server before running the script?"
    echo "1 - Update and reboot now"
    echo "2 - Continue (the system has been updated and rebooted)"
    read -r system_updated
    [[ -n $system_updated ]] && echo ""
    update_and_reboot
    echo -e "${textcolor}[?]${clear} Select a certificate validation method:"
    echo "1 - DNS Cloudflare (if your domain is linked to Cloudflare)"
    echo "2 - Standalone (if your domain is linked to another service)"
    read -r validation_type
    if [[ "$validation_type" == "1" ]]
    then
        email_text=" registered on Cloudflare"
        enter_domain_data
        check_cf_token
    else
        email_text=" to issue a certificate"
        [[ -n $validation_type ]] && echo ""
        echo -e "${red}ATTENTION!${clear}"
        echo "Be sure to check the spelling of the domain name"
        enter_domain_data
    fi
    echo -e "${textcolor}[?]${clear} Select a proxy setup option:"
    echo "1 - TLS termination on NGINX, Trojan and VLESS protocols, WebSocket or HTTPUpgrade transport"
    echo "2 - TLS termination on HAProxy, Trojan protocol, Sing-Box or NGINX backend selection based on Trojan passwords"
    read -r variant
    [[ -n $variant ]] && echo ""
    if [[ "$variant" == "1" ]]
    then
        echo -e "${textcolor}[?]${clear} Select transport:"
        echo "1 - WebSocket"
        echo "2 - HTTPUpgrade"
        read -r transport
        [[ -n $transport ]] && echo ""
    fi
    echo -e "${textcolor}[?]${clear} Select NGINX/HAProxy setup option:"
    echo "1 - Will show a login popup asking for username and password, 401 Unauthorized"
    echo "2 - Will redirect to another domain, 301 Moved Permanently"
    echo "3 - Copy someone else's website to this server, experimental option"
    echo "4 - Upload your own website (if you have one), experimental option"
    read -r option
    [[ -n $option ]] && echo ""
    nginx_options
    echo -e "${textcolor}[?]${clear} Enter your password for Trojan or leave this empty to generate a random password:"
    read -r trjpass
    [[ -n $trjpass ]] && echo ""
    check_trjpass
    if [[ "$variant" == "1" ]]
    then
        echo -e "${textcolor}[?]${clear} Enter your path for Trojan or leave this empty to generate a random path:"
        read -r trojanpath
        [[ -n $trojanpath ]] && echo ""
        trojanpath=${trojanpath#"/"}
        check_trojan_path
        echo -e "${textcolor}[?]${clear} Enter your UUID for VLESS or leave this empty to generate a random UUID:"
        read -r uuid
        [[ -n $uuid ]] && echo ""
        check_uuid
        echo -e "${textcolor}[?]${clear} Enter your path for VLESS or leave this empty to generate a random path:"
        read -r vlesspath
        [[ -n $vlesspath ]] && echo ""
        vlesspath=${vlesspath#"/"}
        check_vless_path
    fi
    echo -e "${textcolor}[?]${clear} Enter your subscription path or leave this empty to generate a random path:"
    read -r subspath
    [[ -n $subspath ]] && echo ""
    subspath=${subspath#"/"}
    check_subscription_path
    echo -e "${textcolor}[?]${clear} Enter your path for rule sets or leave this empty to generate a random path:"
    read -r rulesetpath
    [[ -n $rulesetpath ]] && echo ""
    rulesetpath=${rulesetpath#"/"}
    check_rulesetpath
    echo -e "${textcolor}[?]${clear} Do you need security setup (SSH, UFW and unattended-upgrades)?"
    echo "1 - Yes (in rare cases of hoster's non-standard settings, access to the server might be lost)"
    echo "2 - No (then it is recommended to perform the setup manually after the script finishes running)"
    read -r ssh_ufw
    [[ -n $ssh_ufw ]] && echo ""
    if [[ "$ssh_ufw" != "2" ]]
    then
        echo -e "${textcolor}[?]${clear} Enter new SSH port number or 22 (number above 1024 is recommended):"
        read -r ssh_port
        [[ -n $ssh_port ]] && echo ""
        check_ssh_port
        echo -e "${textcolor}[?]${clear} Enter your username or root (non-root user is recommended):"
        read -r username
        [[ -n $username ]] && echo ""
        check_username
        echo -e "${textcolor}[?]${clear} Enter SSH password for the new user (a complex password is recommended):"
        read -r password
        [[ -n $password ]] && echo ""
        check_password
    fi
    echo ""
    echo ""
}

enable_bbr() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor_light}Настройка BBR...${clear}"
    info_message[1_en]="${textcolor_light}Setting up BBR...${clear}"

    echo -e "${info_message[1_$language]}"
    touch /etc/sysctl.conf
    [[ $(sysctl net.core.default_qdisc) != *"= fq" ]] && echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
    [[ $(sysctl net.ipv4.tcp_congestion_control) != *"bbr" ]] && echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
    sysctl -p
    echo ""
}

downgrade_nasty_warp() {
    # Because some WARP releases are buggy...
    warp_version="2025.6.1335.0"
    proc_arch="amd64"
    [[ $(uname -m) == "aarch64" || $(uname -m) == "arm64" ]] && proc_arch="arm64"
    wget -q https://pkg.cloudflareclient.com/pool/${os_codename}/main/c/cloudflare-warp/cloudflare-warp_${warp_version}_${proc_arch}.deb

    if [[ $? -eq 0 ]]
    then
        dpkg -i cloudflare-warp_${warp_version}_${proc_arch}.deb
        rm -f ./cloudflare-warp_${warp_version}_${proc_arch}.deb
        apt-mark hold cloudflare-warp
    fi
}

install_packages() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor_light}Установка необходимых пакетов...${clear}"
    info_message[1_en]="${textcolor_light}Installing the required packages...${clear}"

    echo -e "${info_message[1_$language]}"
    apt install sudo coreutils nano wget ufw certbot python3-certbot-dns-cloudflare cron gnupg2 ca-certificates openssl sed jq net-tools htop -y
    [[ "$ssh_ufw" != "2" ]] && apt install unattended-upgrades -y
    os_codename=$(grep "VERSION_CODENAME=" /etc/os-release | cut -d "=" -f 2)

    if grep -q -e "bullseye" -e "bookworm" -e "trixie" /etc/os-release
    then
        apt install debian-archive-keyring -y
        server_os="debian"
    else
        apt install ubuntu-keyring -y
        server_os="ubuntu"
    fi

    [[ ! -d /usr/share/keyrings ]] && mkdir -p /usr/share/keyrings
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ ${os_codename} main" | tee /etc/apt/sources.list.d/cloudflare-client.list
    apt-get update -y && apt-get install cloudflare-warp -y
    #downgrade_nasty_warp

    [[ ! -d /etc/apt/keyrings ]] && mkdir -p /etc/apt/keyrings
    curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
    chmod a+r /etc/apt/keyrings/sagernet.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | tee /etc/apt/sources.list.d/sagernet.list > /dev/null
    apt-get update -y && apt-get install sing-box -y
    apt-mark hold sing-box

    curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg > /dev/null
    gpg --dry-run --quiet --no-keyring --import --import-options import-show /usr/share/keyrings/nginx-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/${server_os} ${os_codename} nginx" | tee /etc/apt/sources.list.d/nginx.list
    echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" | tee /etc/apt/preferences.d/99nginx
    apt update -y && apt install nginx -y
    [[ ! -d /var/www ]] && mkdir -p /var/www

    [[ "$variant" != "1" ]] && apt install haproxy -y
    apt autoremove -y; apt autoclean -y
    echo ""
}

create_user() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor_light}Создание пользователя ${username}...${clear}"
    info_message[1_en]="${textcolor_light}Creating user ${username}...${clear}"

    if [[ "$username" != "root" ]]
    then
        echo -e "${info_message[1_$language]}"
        useradd -m -s $(which bash) -G sudo ${username}
    fi

    echo "${username}:$(openssl passwd -6 "${password}")" | chpasswd -e
    echo ""
}

setup_ssh() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor_light}Изменение настроек SSH...${clear}"
    info_message[1_en]="${textcolor_light}Changing SSH settings...${clear}"

    if [[ "$username" == "root" ]]
    then
        [[ $ssh_port -ne 22 ]] && echo -e "${info_message[1_$language]}"
        sed -i -e "s/.*Port .*/Port ${ssh_port}/g" -e "s/.*PermitRootLogin no.*/PermitRootLogin yes/g" -e "s/.*#PermitRootLogin .*/PermitRootLogin yes/g" -e "s/.*PasswordAuthentication no.*/PasswordAuthentication yes/g" -e "s/.*#PasswordAuthentication .*/PasswordAuthentication yes/g" /etc/ssh/sshd_config
        [[ ! -d /root/.ssh ]] && mkdir -p /root/.ssh
    else
        echo -e "${info_message[1_$language]}"
        sed -i -e "s/.*Port .*/Port ${ssh_port}/g" -e "s/.*PermitRootLogin yes.*/PermitRootLogin no/g" -e "s/.*#PermitRootLogin .*/PermitRootLogin no/g" -e "s/.*PasswordAuthentication no.*/PasswordAuthentication yes/g" -e "s/.*#PasswordAuthentication .*/PasswordAuthentication yes/g" /etc/ssh/sshd_config
        [[ ! -d /home/${username}/.ssh ]] && mkdir -p /home/${username}/.ssh
        chown ${username}:sudo /home/${username}/.ssh
        chmod 700 /home/${username}/.ssh
    fi

    if grep -q "noble" /etc/os-release
    then
        sed -i "s/.*ListenStream.*/ListenStream=${ssh_port}/g" /lib/systemd/system/ssh.socket
        systemctl daemon-reload
        systemctl restart ssh.socket
    fi

    grep -q "PasswordAuthentication yes" /etc/ssh/sshd_config.d/50-cloud-init.conf &> /dev/null && rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf
    systemctl restart ssh.service
    echo ""
}

setup_ufw() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor_light}Настройка UFW...${clear}"
    info_message[1_en]="${textcolor_light}Setting up UFW...${clear}"

    echo -e "${info_message[1_$language]}"
    ufw allow ${ssh_port}/tcp
    ufw allow 443/tcp
    # Protection from incoming Reality requests:
    ufw insert 1 deny from ${server_ip}/22 &> /dev/null
    echo ""
    ufw --force enable
    echo ""
    ufw status
}

unattended_upgrades() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor_light}Настройка unattended-upgrades...${clear}"
    info_message[1_en]="${textcolor_light}Setting up unattended upgrades...${clear}"

    echo -e "${info_message[1_$language]}"
    echo 'Unattended-Upgrade::Mail "root";' >> /etc/apt/apt.conf.d/50unattended-upgrades
    echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
    dpkg-reconfigure -f noninteractive unattended-upgrades
    systemctl restart unattended-upgrades.service
    systemctl enable unattended-upgrades.service
    echo ""
}

setup_general_security() {
    if [[ "$ssh_ufw" != "2" ]]
    then
        create_user
        setup_ssh
        setup_ufw
        unattended_upgrades
    fi
}

cert_dns_cf() {
    if [[ $cf_token =~ [A-Z] ]]
    then
        echo "dns_cloudflare_api_token = ${cf_token}" >> /etc/letsencrypt/cloudflare.credentials
    else
        echo "dns_cloudflare_email = ${email}" >> /etc/letsencrypt/cloudflare.credentials
        echo "dns_cloudflare_api_key = ${cf_token}" >> /etc/letsencrypt/cloudflare.credentials
    fi

    chown root:root /etc/letsencrypt/cloudflare.credentials
    chmod 600 /etc/letsencrypt/cloudflare.credentials
    certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.credentials --dns-cloudflare-propagation-seconds 35 -d ${domain},*.${domain} --agree-tos -m ${email} --no-eff-email --non-interactive

    if [[ $? -ne 0 ]]
    then
        sleep 3
        echo ""
        echo -e "${info_message[2_$language]}"
        certbot delete --cert-name ${domain} --quiet &> /dev/null
        certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.credentials --dns-cloudflare-propagation-seconds 35 -d ${domain},*.${domain} --agree-tos -m ${email} --no-eff-email --non-interactive
    fi

    echo "0 2 * * * certbot -q renew" | crontab -
}

cert_standalone() {
    ufw allow 80 &> /dev/null
    certbot certonly --standalone --preferred-challenges http --agree-tos --email ${email} -d ${domain} --no-eff-email --non-interactive

    if [[ $? -ne 0 ]]
    then
        sleep 3
        echo ""
        echo -e "${info_message[2_$language]}"
        certbot delete --cert-name ${domain} --quiet &> /dev/null
        certbot certonly --standalone --preferred-challenges http --agree-tos --email ${email} -d ${domain} --no-eff-email --non-interactive
    fi

    ufw delete allow 80 &> /dev/null
    echo "0 2 * * * ufw allow 80 && certbot -q renew; ufw delete allow 80" | crontab -
}

certificates() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor_light}Получение сертификата...${clear}"
    info_message[2_ru]="${textcolor_light}Получение сертификата: 2-я попытка...${clear}"
    info_message[1_en]="${textcolor_light}Requesting a certificate...${clear}"
    info_message[2_en]="${textcolor_light}Requesting a certificate: 2nd attempt...${clear}"

    echo -e "${info_message[1_$language]}"
    warn_file=$(python3 -c "import os, CloudFlare; print(os.path.join(os.path.dirname(CloudFlare.__file__), 'warning_2_20.py'))")
    [[ $(dpkg -s python3-cloudflare | grep -i '^version') =~ "2.20." ]] && sed -i 's/2\.20\./2\.25\./g' ${warn_file} &> /dev/null

    if [[ "$validation_type" == "1" ]]
    then
        cert_dns_cf
    else
        cert_standalone
    fi

    if [[ "$variant" == "1" ]]
    then
        echo "renew_hook = systemctl reload nginx.service" >> /etc/letsencrypt/renewal/${domain}.conf
        echo ""
        openssl dhparam -out /etc/nginx/dhparam.pem 2048
    else
        echo "renew_hook = cat /etc/letsencrypt/live/${domain}/fullchain.pem /etc/letsencrypt/live/${domain}/privkey.pem > /etc/haproxy/certs/${domain}.pem && systemctl reload haproxy.service" >> /etc/letsencrypt/renewal/${domain}.conf
        echo ""
        openssl dhparam -out /etc/haproxy/dhparam.pem 2048
    fi

    echo ""
}

setup_warp() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor_light}Настройка WARP...${clear}"
    info_message[1_en]="${textcolor_light}Setting up WARP...${clear}"

    echo -e "${info_message[1_$language]}"
    warp-cli -V
    echo ""
    yes | warp-cli registration new
    warp-cli mode proxy
    warp-cli proxy port 40000
    warp-cli connect
    mkdir -p /etc/systemd/system/warp-svc.service.d
    echo -e "[Service]\nLogLevelMax=3\nCPUQuota=20%\nMemoryHigh=128M" >> /etc/systemd/system/warp-svc.service.d/override.conf
    systemctl daemon-reload
    systemctl restart warp-svc.service
    systemctl enable warp-svc.service
    echo ""
}

generate_pass() {
    [[ -z $trjpass ]] && trjpass=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30)
    [[ -z $trojanpath ]] && [[ "$variant" == "1" ]] && trojanpath=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30)
    [[ -z $uuid ]] && [[ "$variant" == "1" ]] && uuid=$(cat /proc/sys/kernel/random/uuid)
    [[ -z $vlesspath ]] && [[ "$variant" == "1" ]] && vlesspath=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30)
    [[ -z $subspath ]] && subspath=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30)
    [[ -z $rulesetpath ]] && rulesetpath=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30)
    user_key="1$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 9)"
}

download_rule_sets() {
    mkdir -p /var/www/${rulesetpath}
    wget -P /var/www/${rulesetpath} https://raw.githubusercontent.com/FPPweb3/sb-rule-sets/main/torrent-clients.json
    wget -P /var/www/${rulesetpath} https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-ru.srs

    for ruleset_ind in $(seq 0 $(jq '.route.rule_set | length - 1' /var/www/${subspath}/${user_key}-TRJ-CLIENT.json))
    do
        ruleset=$(jq -r ".route.rule_set[${ruleset_ind}].url" /var/www/${subspath}/${user_key}-TRJ-CLIENT.json | cut -d "/" -f 5)
        [[ "$ruleset" == "geoip-ru.srs" || "$ruleset" == "torrent-clients.json" ]] && continue
        wget -P /var/www/${rulesetpath} https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/${ruleset}
    done

    for ruleset_ind in $(seq 0 $(jq '.route.rule_set | length - 1' /etc/sing-box/config.json))
    do
        ruleset=$(jq -r ".route.rule_set[${ruleset_ind}].path" /etc/sing-box/config.json | cut -d "/" -f 5)
        [[ ! -f /var/www/${rulesetpath}/${ruleset} ]] && wget -P /var/www/${rulesetpath} https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/${ruleset}
    done

    chmod -R 755 /var/www/${rulesetpath}
    wget -O /usr/local/bin/rsupdate https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Scripts/ruleset-update.sh
    chmod +x /usr/local/bin/rsupdate
    { echo "PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"; crontab -l; echo "10 2 * * * rsupdate"; } | crontab -
}

sb_server_config() {
cat > /etc/sing-box/config.json <<EOF
{
  "log": {
    "level": "fatal",
    "output": "box.log",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "type": "local",
        "tag": "dns-main"
      }
    ],
    "rules": [
      {
        "rule_set": [
          "category-ads-all"
        ],
        "action": "predefined",
        "rcode": "NOERROR"
      }
    ],
    "final": "dns-main"
  },
  "inbounds": [
    {
      "type": "trojan",
      "tag": "trojan-in",
      "listen": "127.0.0.1",
      "listen_port": 10443,
      "users": [
        {
          "name": "${user_key}",
          "password": "${trjpass}"
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/${trojanpath}"
      },
      "multiplex": {
        "enabled": true,
        "padding": true
      }
    },
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "127.0.0.1",
      "listen_port": 11443,
      "users": [
        {
          "name": "${user_key}",
          "uuid": "${uuid}"
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/${vlesspath}"
      },
      "multiplex": {
        "enabled": true,
        "padding": true
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "socks",
      "tag": "warp",
      "server": "127.0.0.1",
      "server_port": 40000
    },
    {
      "type": "direct",
      "tag": "IPv4",
      "domain_resolver": {
        "server": "dns-main",
        "strategy": "prefer_ipv4"
      }
    }
  ],
  "route": {
    "rules": [
      {
        "action": "sniff"
      },
      {
        "protocol": "dns",
        "action": "hijack-dns"
      },
      {
        "rule_set": [
          "category-ads-all"
        ],
        "action": "reject",
        "method": "drop"
      },
      {
        "domain_suffix": [
          ".ru",
          ".su",
          ".ru.com",
          ".ru.net",
          "habr.com",
          "ntc.party",
          "canva.com"
        ],
        "domain_keyword": [
          "xn--",
          "rutracker"
        ],
        "rule_set": [
          "geoip-ru",
          "category-gov-ru",
          "google-deepmind",
          "openai",
          "anthropic",
          "xai"
        ],
        "outbound": "warp"
      },
      {
        "rule_set": [
          "google"
        ],
        "outbound": "IPv4"
      }
    ],
    "rule_set": [
      {
        "tag": "geoip-ru",
        "type": "local",
        "format": "binary",
        "path": "/var/www/${rulesetpath}/geoip-ru.srs"
      },
      {
        "tag": "category-gov-ru",
        "type": "local",
        "format": "binary",
        "path": "/var/www/${rulesetpath}/geosite-category-gov-ru.srs"
      },
      {
        "tag": "category-ads-all",
        "type": "local",
        "format": "binary",
        "path": "/var/www/${rulesetpath}/geosite-category-ads-all.srs"
      },
      {
        "tag": "google",
        "type": "local",
        "format": "binary",
        "path": "/var/www/${rulesetpath}/geosite-google.srs"
      },
      {
        "tag": "google-deepmind",
        "type": "local",
        "format": "binary",
        "path": "/var/www/${rulesetpath}/geosite-google-deepmind.srs"
      },
      {
        "tag": "openai",
        "type": "local",
        "format": "binary",
        "path": "/var/www/${rulesetpath}/geosite-openai.srs"
      },
      {
        "tag": "anthropic",
        "type": "local",
        "format": "binary",
        "path": "/var/www/${rulesetpath}/geosite-anthropic.srs"
      },
      {
        "tag": "xai",
        "type": "local",
        "format": "binary",
        "path": "/var/www/${rulesetpath}/geosite-xai.srs"
      }
    ]
  },
  "experimental": {
    "cache_file": {
      "enabled": true
    }
  }
}
EOF
}

sb_client_config() {
cat > /var/www/${subspath}/${user_key}-TRJ-CLIENT.json <<EOF
{
  "log": {
    "level": "fatal",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "dns-remote",
        "address": "tls://1.1.1.1",
        "detour": "proxy"
      },
      {
        "tag": "dns-local",
        "address": "195.208.4.1"
      },
      {
        "tag": "dns-block",
        "address": "rcode://success"
      }
    ],
    "rules": [
      {
        "rule_set": [
          "category-ads-all"
        ],
        "server": "dns-block",
        "disable_cache": true
      },
      {
        "domain_suffix": [
          "habr.com",
          "kemono.su",
          "jut.su",
          "kara.su",
          "theins.ru",
          "tvrain.ru",
          "echo.msk.ru",
          "the-village.ru",
          "snob.ru",
          "novayagazeta.ru",
          "moscowtimes.ru"
        ],
        "domain_keyword": [
          "animego",
          "yummyanime",
          "yummy-anime",
          "animeportal",
          "anime-portal",
          "animedub",
          "anidub",
          "animelib",
          "ikianime",
          "anilibria"
        ],
        "rule_set": [
          "telegram",
          "google"
        ],
        "server": "dns-remote"
      },
      {
        "domain_suffix": [
          ".ru",
          ".su",
          ".ru.com",
          ".ru.net",
          "${domain}",
          "wikipedia.org",
          "kudago.com",
          "kinescope.io",
          "redheadsound.studio",
          "plplayer.online",
          "lomont.site",
          "remanga.org",
          "shopstory.live"
        ],
        "domain_keyword": [
          "xn--",
          "miradres",
          "premier",
          "shutterstock",
          "2gis",
          "diginetica",
          "kinescopecdn",
          "researchgate",
          "nextcloud",
          "wiki",
          "kaspersky",
          "stepik",
          "likee",
          "yappy",
          "pikabu",
          "okko",
          "wink",
          "kion",
          "wildberries",
          "aliexpress"
        ],
        "rule_set": [
          "category-gov-ru",
          "yandex",
          "vk",
          "mailru",
          "ozon",
          "zoom",
          "reddit",
          "twitch",
          "tumblr",
          "pinterest",
          "deviantart",
          "duckduckgo",
          "yahoo",
          "mozilla",
          "samsung",
          "huawei",
          "apple",
          "nvidia",
          "xiaomi",
          "hp",
          "asus",
          "lenovo",
          "lg",
          "oracle",
          "adobe",
          "blender",
          "drweb",
          "gitlab",
          "debian",
          "canonical",
          "python",
          "doi",
          "springer",
          "elsevier",
          "sciencedirect",
          "clarivate",
          "sci-hub",
          "duolingo",
          "aljazeera",
          "torrent-clients"
        ],
        "server": "dns-local"
      },
      {
        "inbound": [
          "tun-in"
        ],
        "server": "dns-remote"
      }
    ],
    "final": "dns-local"
  },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "tun0",
      "stack": "system",
      "address": [
        "172.19.0.1/28",
        "fdfe:dcba:9876::1/126"
      ],
      "auto_route": true,
      "strict_route": true,
      "sniff_override_destination": true
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "trojan",
      "tag": "proxy",
      "server": "${domain}",
      "server_port": 443,
      "password": "${trjpass}",
      "tls": {
        "enabled": true,
        "server_name": "${domain}",
        "utls": {
          "enabled": true,
          "fingerprint": "randomized"
        }
      },
      "transport": {
        "type": "ws",
        "path": "/${trojanpath}"
      },
      "multiplex": {
        "enabled": true,
        "padding": true
      }
    }
  ],
  "route": {
    "auto_detect_interface": true,
    "rules": [
      {
        "action": "sniff"
      },
      {
        "protocol": "dns",
        "action": "hijack-dns"
      },
      {
        "ip_is_private": true,
        "outbound": "direct"
      },
      {
        "rule_set": [
          "category-ads-all"
        ],
        "action": "reject",
        "method": "drop"
      },
      {
        "domain_suffix": [
          "habr.com",
          "kemono.su",
          "jut.su",
          "kara.su",
          "theins.ru",
          "tvrain.ru",
          "echo.msk.ru",
          "the-village.ru",
          "snob.ru",
          "novayagazeta.ru",
          "moscowtimes.ru"
        ],
        "domain_keyword": [
          "animego",
          "yummyanime",
          "yummy-anime",
          "animeportal",
          "anime-portal",
          "animedub",
          "anidub",
          "animelib",
          "ikianime",
          "anilibria"
        ],
        "rule_set": [
          "telegram",
          "google"
        ],
        "outbound": "proxy"
      },
      {
        "domain_suffix": [
          ".ru",
          ".su",
          ".ru.com",
          ".ru.net",
          "${domain}",
          "wikipedia.org",
          "kudago.com",
          "kinescope.io",
          "redheadsound.studio",
          "plplayer.online",
          "lomont.site",
          "remanga.org",
          "shopstory.live"
        ],
        "domain_keyword": [
          "xn--",
          "miradres",
          "premier",
          "shutterstock",
          "2gis",
          "diginetica",
          "kinescopecdn",
          "researchgate",
          "nextcloud",
          "wiki",
          "kaspersky",
          "stepik",
          "likee",
          "yappy",
          "pikabu",
          "okko",
          "wink",
          "kion",
          "wildberries",
          "aliexpress"
        ],
        "ip_cidr": [
          "${server_ip}"
        ],
        "rule_set": [
          "category-gov-ru",
          "yandex",
          "vk",
          "mailru",
          "ozon",
          "zoom",
          "reddit",
          "twitch",
          "tumblr",
          "pinterest",
          "deviantart",
          "duckduckgo",
          "yahoo",
          "mozilla",
          "samsung",
          "huawei",
          "apple",
          "nvidia",
          "xiaomi",
          "hp",
          "asus",
          "lenovo",
          "lg",
          "oracle",
          "adobe",
          "blender",
          "drweb",
          "gitlab",
          "debian",
          "canonical",
          "python",
          "doi",
          "springer",
          "elsevier",
          "sciencedirect",
          "clarivate",
          "sci-hub",
          "duolingo",
          "aljazeera",
          "torrent-clients"
        ],
        "outbound": "direct"
      },
      {
        "action": "resolve",
        "strategy": "prefer_ipv4"
      },
      {
        "rule_set": [
          "geoip-ru"
        ],
        "outbound": "direct"
      },
      {
        "inbound": [
          "tun-in"
        ],
        "outbound": "proxy"
      }
    ],
    "rule_set": [
      {
        "tag": "torrent-clients",
        "type": "remote",
        "format": "source",
        "url": "https://${domain}/${rulesetpath}/torrent-clients.json"
      },
      {
        "tag": "geoip-ru",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geoip-ru.srs"
      },
      {
        "tag": "category-gov-ru",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-category-gov-ru.srs"
      },
      {
        "tag": "yandex",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-yandex.srs"
      },
      {
        "tag": "google",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-google.srs"
      },
      {
        "tag": "telegram",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-telegram.srs"
      },
      {
        "tag": "vk",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-vk.srs"
      },
      {
        "tag": "mailru",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-mailru.srs"
      },
      {
        "tag": "ozon",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-ozon.srs"
      },
      {
        "tag": "zoom",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-zoom.srs"
      },
      {
        "tag": "reddit",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-reddit.srs"
      },
      {
        "tag": "twitch",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-twitch.srs"
      },
      {
        "tag": "tumblr",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-tumblr.srs"
      },
      {
        "tag": "4chan",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-4chan.srs"
      },
      {
        "tag": "pinterest",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-pinterest.srs"
      },
      {
        "tag": "deviantart",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-deviantart.srs"
      },
      {
        "tag": "duckduckgo",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-duckduckgo.srs"
      },
      {
        "tag": "yahoo",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-yahoo.srs"
      },
      {
        "tag": "mozilla",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-mozilla.srs"
      },
      {
        "tag": "samsung",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-samsung.srs"
      },
      {
        "tag": "huawei",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-huawei.srs"
      },
      {
        "tag": "apple",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-apple.srs"
      },
      {
        "tag": "nvidia",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-nvidia.srs"
      },
      {
        "tag": "xiaomi",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-xiaomi.srs"
      },
      {
        "tag": "hp",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-hp.srs"
      },
      {
        "tag": "asus",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-asus.srs"
      },
      {
        "tag": "lenovo",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-lenovo.srs"
      },
      {
        "tag": "lg",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-lg.srs"
      },
      {
        "tag": "oracle",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-oracle.srs"
      },
      {
        "tag": "adobe",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-adobe.srs"
      },
      {
        "tag": "blender",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-blender.srs"
      },
      {
        "tag": "drweb",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-drweb.srs"
      },
      {
        "tag": "gitlab",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-gitlab.srs"
      },
      {
        "tag": "debian",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-debian.srs"
      },
      {
        "tag": "canonical",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-canonical.srs"
      },
      {
        "tag": "python",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-python.srs"
      },
      {
        "tag": "doi",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-doi.srs"
      },
      {
        "tag": "springer",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-springer.srs"
      },
      {
        "tag": "elsevier",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-elsevier.srs"
      },
      {
        "tag": "sciencedirect",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-sciencedirect.srs"
      },
      {
        "tag": "clarivate",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-clarivate.srs"
      },
      {
        "tag": "sci-hub",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-sci-hub.srs"
      },
      {
        "tag": "duolingo",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-duolingo.srs"
      },
      {
        "tag": "aljazeera",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-aljazeera.srs"
      },
      {
        "tag": "category-ads-all",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-category-ads-all.srs"
      }
    ]
  },
  "experimental": {
    "cache_file": {
      "enabled": true
    }
  }
}
EOF
}

setup_sing_box() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor_light}Настройка Sing-Box...${clear}"
    info_message[1_en]="${textcolor_light}Setting up Sing-Box...${clear}"

    echo -e "${info_message[1_$language]}"
    generate_pass
    mkdir -p /var/www/${subspath}
    sb_server_config
    sb_client_config
    outbound_num=$(jq '[.outbounds[].tag] | index("proxy")' /var/www/${subspath}/${user_key}-TRJ-CLIENT.json)

    if [[ "$transport" == "2" ]]
    then
        echo "$(jq '.inbounds[].transport.type = "httpupgrade"' /etc/sing-box/config.json)" > /etc/sing-box/config.json
        echo "$(jq ".outbounds[${outbound_num}].transport.type = \"httpupgrade\"" /var/www/${subspath}/${user_key}-TRJ-CLIENT.json)" > /var/www/${subspath}/${user_key}-TRJ-CLIENT.json
    fi

    if [[ "$variant" == "1" ]]
    then
        echo "$(jq ".outbounds[${outbound_num}].type = \"vless\" | .outbounds[${outbound_num}] |= with_entries(.key |= if . == \"password\" then \"uuid\" else . end) | .outbounds[${outbound_num}].uuid = \"${uuid}\" | .outbounds[${outbound_num}].transport.path = \"/${vlesspath}\"" /var/www/${subspath}/${user_key}-TRJ-CLIENT.json)" > /var/www/${subspath}/${user_key}-VLESS-CLIENT.json
    else
        inbound_num_tr=$(jq '[.inbounds[].tag] | index("trojan-in")' /etc/sing-box/config.json)
        inbound_num_vl=$(jq '[.inbounds[].tag] | index("vless-in")' /etc/sing-box/config.json)
        echo "$(jq "del(.inbounds[${inbound_num_tr}].transport.type, .inbounds[${inbound_num_tr}].transport.path, .inbounds[${inbound_num_vl}])" /etc/sing-box/config.json)" > /etc/sing-box/config.json
        echo "$(jq "del(.outbounds[${outbound_num}].transport.type, .outbounds[${outbound_num}].transport.path)" /var/www/${subspath}/${user_key}-TRJ-CLIENT.json)" > /var/www/${subspath}/${user_key}-TRJ-CLIENT.json
    fi

    download_rule_sets
    systemctl restart sing-box.service
    systemctl enable sing-box.service
    echo ""
}

for_nginx_options() {
    if [[ "$variant" == "1" ]] && [[ ! $option =~ ^(2|3|4)$ ]]
    then
        touch /etc/nginx/.htpasswd
    fi

    if [[ "$option" == "3" ]]
    then
        wget -P /var/www --mirror --convert-links --adjust-extension --page-requisites --no-parent https://${site_link}
        site_dir_root=$(echo "${site_link}" | cut -d "/" -f 1)
        chmod -R 755 /var/www/${site_dir_root}
        mkdir ./testdir
        wget -q -P ./testdir https://${site_link}
        index=$(ls ./testdir)
        rm -rf ./testdir

        for search_name in "$index" '*.htm*'
        do
            index_path=$(find /var/www/${site_dir_root} -name "${search_name}" -type f -printf "%d %p\n" | sort -n | head -n 1 | cut -d " " -f 2-)
            [[ -n $index_path ]] && [[ "$search_name" == "$index" ]] && break
            index=$(echo "${index_path}" | rev | cut -d "/" -f 1 | rev)
        done

        site_dir=${index_path%"/${index}"}
        site_dir=${site_dir#"/var/www/"}
        echo ""
    fi

    if [[ "$option" == "4" ]]
    then
        site_dir_root=$(echo "${index_path}" | cut -d "/" -f 2)
        mv -f /root/${site_dir_root} /var/www
        chmod -R 755 /var/www/${site_dir_root}
        index=$(echo "${index_path}" | rev | cut -d "/" -f 1 | rev)
        site_dir=${index_path%"/${index}"}
        site_dir=${site_dir#"/"}
    fi
}

nginx_config_1() {
cat > /etc/nginx/nginx.conf <<EOF
user                 www-data;
pid                  /run/nginx.pid;
worker_processes     auto;
worker_rlimit_nofile 65535;

# Load modules
include              /etc/nginx/modules-enabled/*.conf;

events {
    multi_accept       on;
    worker_connections 65535;
}

http {
    sendfile                  on;
    tcp_nopush                on;
    tcp_nodelay               on;
    server_tokens             off;
    types_hash_max_size       2048;
    types_hash_bucket_size    64;
    client_max_body_size      16M;

    # Timeout
    keepalive_timeout         60s;
    keepalive_requests        1000;
    reset_timedout_connection on;

    # Rate limit for the subscription path
    limit_req_zone            \$binary_remote_addr zone=limit_sub:1m rate=60r/m;

    # MIME
    include                   mime.types;
    default_type              application/octet-stream;

    # Logging
    access_log                off;
    error_log                 off;

    # SSL
    ssl_session_timeout       1d;
    ssl_session_cache         shared:SSL:10m;
    ssl_session_tickets       off;

    # Mozilla Intermediate configuration
    ssl_protocols             TLSv1.2 TLSv1.3;
    ssl_ciphers               TLS13_AES_128_GCM_SHA256:TLS13_AES_256_GCM_SHA384:TLS13_CHACHA20_POLY1305_SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305;

    # Connection header for WebSocket reverse proxy
    map \$http_upgrade \$connection_upgrade {
        default upgrade;
        ""      close;
    }

    map \$remote_addr \$proxy_forwarded_elem {

        # IPv4 addresses can be sent as-is
        ~^[0-9.]+$        "for=\$remote_addr";

        # IPv6 addresses need to be bracketed and quoted
        ~^[0-9A-Fa-f:.]+$ "for=\"[\$remote_addr]\"";

        # Unix domain socket names cannot be represented in RFC 7239 syntax
        default           "for=unknown";
    }

    map \$http_forwarded \$proxy_add_forwarded {

        # If the incoming Forwarded header is syntactically valid, append to it
        "${append}" "\$http_forwarded, \$proxy_forwarded_elem";

        # Otherwise, replace it
        default "\$proxy_forwarded_elem";
    }

    # Disable access via IP or wrong domain name
    server {
        listen                443 ssl default_server;
        listen                [::]:443 ssl default_server;
        http2                 on;
        server_name           _;

        ssl_certificate       /etc/letsencrypt/live/${domain}/fullchain.pem;
        ssl_certificate_key   /etc/letsencrypt/live/${domain}/privkey.pem;
        ssl_dhparam           /etc/nginx/dhparam.pem;

        return                403;
    }

    # Site
    server {
        listen                               443 ssl;
        listen                               [::]:443 ssl;
        http2                                on;
        server_name                          ${domain} *.${domain};
        ${comment_1}${comment_2}root                                 /var/www/${site_dir};
        ${comment_1}${comment_2}index                                ${index};

        # SSL
        ssl_certificate                      /etc/letsencrypt/live/${domain}/fullchain.pem;
        ssl_certificate_key                  /etc/letsencrypt/live/${domain}/privkey.pem;

        # Diffie-Hellman parameter for DHE ciphersuites
        ssl_dhparam                          /etc/nginx/dhparam.pem;

        # Security headers
        add_header X-XSS-Protection          "1; mode=block" always;
        add_header X-Content-Type-Options    "nosniff" always;
        add_header Referrer-Policy           "no-referrer-when-downgrade" always;
        add_header Content-Security-Policy   "default-src 'self' http: https: ws: wss: data: blob: 'unsafe-inline'; frame-ancestors 'self';" always;
        add_header Permissions-Policy        "interest-cohort=()" always;
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        proxy_hide_header X-Powered-By;

        # . files
        location ~ /\.(?!well-known) {
            deny all;
        }

        # Main location
        ${comment_3}location / {
            ${comment_2}${comment_3}auth_basic "Restricted Content";
            ${comment_2}${comment_3}auth_basic_user_file /etc/nginx/.htpasswd;
            ${comment_1}${comment_3}return 301 https://${redirect}\$request_uri;
        ${comment_3}}

        # Subsciption
        location ~ ^/${subspath}/ {
            limit_req zone=limit_sub burst=20 nodelay;
            default_type application/json;
            root /var/www;
        }

        # Rule sets
        location /${rulesetpath}/ {
            alias /var/www/${rulesetpath}/;
            add_header Content-disposition "attachment";
        }

        # Trojan
        location = /${trojanpath} {
            set \$ws_port 10443;
            try_files "" @ws_proxy;
        }

        # VLESS
        location = /${vlesspath} {
            set \$ws_port 11443;
            try_files "" @ws_proxy;
        }

        # Reverse proxy
        location @ws_proxy {
            if (\$http_upgrade != "websocket") {
                return 404;
            }

            proxy_pass                         http://127.0.0.1:\$ws_port;
            proxy_set_header Host              \$host;
            proxy_http_version                 1.1;
            proxy_cache_bypass                 \$http_upgrade;

            # Proxy SSL
            proxy_ssl_server_name              on;

            # Proxy headers
            proxy_set_header Upgrade           \$http_upgrade;
            proxy_set_header Connection        \$connection_upgrade;
            proxy_set_header X-Real-IP         \$remote_addr;
            proxy_set_header Forwarded         \$proxy_add_forwarded;
            proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header X-Forwarded-Host  \$host;
            proxy_set_header X-Forwarded-Port  \$server_port;

            # Proxy timeouts
            proxy_connect_timeout              60s;
            proxy_send_timeout                 60s;
            proxy_read_timeout                 60s;
        }

        # gzip
        gzip            on;
        gzip_vary       on;
        gzip_proxied    any;
        gzip_comp_level 6;
        gzip_types      text/plain text/css text/xml application/json application/javascript application/rss+xml application/atom+xml image/svg+xml;
    }
}
EOF
}

nginx_config_2() {
cat > /etc/nginx/nginx.conf <<EOF
user                 www-data;
pid                  /run/nginx.pid;
worker_processes     auto;
worker_rlimit_nofile 65535;

# Load modules
include              /etc/nginx/modules-enabled/*.conf;

events {
    multi_accept       on;
    worker_connections 65535;
}

http {
    sendfile                  on;
    tcp_nopush                on;
    tcp_nodelay               on;
    server_tokens             off;
    types_hash_max_size       2048;
    types_hash_bucket_size    64;
    client_max_body_size      16M;

    # Timeout
    keepalive_timeout         60s;
    keepalive_requests        1000;
    reset_timedout_connection on;

    # Rate limit for the subscription path
    limit_req_zone            \$binary_remote_addr zone=limit_sub:1m rate=60r/m;

    # MIME
    include                   mime.types;
    default_type              application/octet-stream;

    # Logging
    access_log                off;
    error_log                 off;

    # Site
    server {
        listen                               127.0.0.1:11443 default_server;
        server_name                          _;
        ${comment_1}${comment_2}root                                 /var/www/${site_dir};
        ${comment_1}${comment_2}index                                ${index};

        # Security headers
        add_header X-XSS-Protection          "1; mode=block" always;
        add_header X-Content-Type-Options    "nosniff" always;
        add_header Referrer-Policy           "no-referrer-when-downgrade" always;
        add_header Content-Security-Policy   "default-src 'self' http: https: ws: wss: data: blob: 'unsafe-inline'; frame-ancestors 'self';" always;
        add_header Permissions-Policy        "interest-cohort=()" always;
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        proxy_hide_header X-Powered-By;

        # . files
        location ~ /\.(?!well-known) {
            deny all;
        }

        # Subsciption
        location ~ ^/${subspath}/ {
            limit_req zone=limit_sub burst=20 nodelay;
            default_type application/json;
            root /var/www;
        }

        # Rule sets
        location /${rulesetpath}/ {
            alias /var/www/${rulesetpath}/;
            add_header Content-disposition "attachment";
        }

        # gzip
        gzip            on;
        gzip_vary       on;
        gzip_proxied    any;
        gzip_comp_level 6;
        gzip_types      text/plain text/css text/xml application/json application/javascript application/rss+xml application/atom+xml image/svg+xml;
    }
}
EOF
}

setup_nginx() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor_light}Настройка NGINX...${clear}"
    info_message[1_en]="${textcolor_light}Setting up NGINX...${clear}"

    echo -e "${info_message[1_$language]}"
    for_nginx_options

    if [[ "$variant" == "1" ]]
    then
        append='~^(,[ \\t]*)*([!#$%&'\''*+.^_`|~0-9A-Za-z-]+=([!#$%&'\''*+.^_`|~0-9A-Za-z-]+|\"([\\t \\x21\\x23-\\x5B\\x5D-\\x7E\\x80-\\xFF]|\\\\[\\t \\x21-\\x7E\\x80-\\xFF])*\"))?(;([!#$%&'\''*+.^_`|~0-9A-Za-z-]+=([!#$%&'\''*+.^_`|~0-9A-Za-z-]+|\"([\\t \\x21\\x23-\\x5B\\x5D-\\x7E\\x80-\\xFF]|\\\\[\\t \\x21-\\x7E\\x80-\\xFF])*\"))?)*([ \\t]*,([ \\t]*([!#$%&'\''*+.^_`|~0-9A-Za-z-]+=([!#$%&'\''*+.^_`|~0-9A-Za-z-]+|\"([\\t \\x21\\x23-\\x5B\\x5D-\\x7E\\x80-\\xFF]|\\\\[\\t \\x21-\\x7E\\x80-\\xFF])*\"))?(;([!#$%&'\''*+.^_`|~0-9A-Za-z-]+=([!#$%&'\''*+.^_`|~0-9A-Za-z-]+|\"([\\t \\x21\\x23-\\x5B\\x5D-\\x7E\\x80-\\xFF]|\\\\[\\t \\x21-\\x7E\\x80-\\xFF])*\"))?)*)?)*$'
        nginx_config_1
    else
        nginx_config_2
    fi

    systemctl enable nginx.service
    nginx -t
    systemctl restart nginx.service
    echo ""
}

auth_lua() {
cat > /etc/haproxy/auth.lua <<EOF
local passwords = {
    ["${pass_hash}"] = true,
    ["${placeholder}"] = false        -- Placeholder (do not remove)
}

function trojan_auth(txn)
    local status, data = pcall(function() return txn.req:dup() end)
    if status and data then
        -- Uncomment to enable logging of all received data
        -- core.Info("Received data from client: " .. data)
        local sniffed_password = string.sub(data, 1, 56)
        -- Uncomment to enable logging of sniffed password hashes
        -- core.Info("Sniffed password: " .. sniffed_password)
        if passwords[sniffed_password] then
            return "trojan"
        end
    end
    return "http"
end

core.register_fetches("trojan_auth", trojan_auth)
EOF
}

haproxy_config() {
cat > /etc/haproxy/haproxy.cfg <<EOF
global
        # Uncomment to enable system logging
        # log /dev/log local0
        # log /dev/log local1 notice
        log /dev/log local2 warning
        lua-load /etc/haproxy/auth.lua
        chroot /var/lib/haproxy
        stats socket /run/haproxy/admin.sock mode 660 level admin
        stats timeout 30s
        user haproxy
        group haproxy
        daemon

        # Mozilla Intermediate
        # ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305
        # ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        # ssl-default-bind-options prefer-client-ciphers no-sslv3 no-tlsv10 no-tlsv11 no-tls-tickets
        # ssl-default-server-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305
        # ssl-default-server-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        # ssl-default-server-options no-sslv3 no-tlsv10 no-tlsv11 no-tls-tickets

        # Mozilla Modern
        ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        ssl-default-bind-options prefer-client-ciphers no-sslv3 no-tlsv10 no-tlsv11 no-tls-tickets
        ssl-default-server-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        ssl-default-server-options no-sslv3 no-tlsv10 no-tlsv11 no-tls-tickets

        # DH parameters
        ssl-dh-param-file /etc/haproxy/dhparam.pem

defaults
        mode http
        log global
        option tcplog
        option  dontlognull
        timeout connect 5000
        timeout client  50000
        timeout server  50000

frontend haproxy-tls
        mode tcp
        timeout client 1h
        bind :::443 v4v6 ssl crt /etc/haproxy/certs/${domain}.pem alpn h2,http/1.1
        tcp-request inspect-delay 5s
        tcp-request content accept if { req_ssl_hello_type 1 }

        # Backend rules
        use_backend reject if !{ ssl_fc_sni -i ${domain} } !{ ssl_fc_sni -m end .${domain} }
        ${comment_3}use_backend http-sub if { path_beg /${subspath}/ } || { path_beg /${rulesetpath}/ }
        use_backend %[lua.trojan_auth]
        default_backend http-main

backend trojan
        mode tcp
        timeout server 1h
        server sing-box 127.0.0.1:10443

backend http-main
        mode http
        timeout server 1h
        ${comment_2}${comment_3}http-request auth unless { http_auth(mycredentials) }
        ${comment_1}${comment_3}http-request redirect code 301 location https://${redirect}%[capture.req.uri]
        ${comment_1}${comment_2}server nginx 127.0.0.1:11443

${comment_3}backend http-sub
        ${comment_3}mode http
        ${comment_3}timeout server 1h
        ${comment_3}server nginx 127.0.0.1:11443

backend reject
        mode http
        timeout server 1h
        http-request deny

${comment_2}${comment_3}userlist mycredentials
EOF
}

setup_haproxy() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor_light}Настройка HAProxy...${clear}"
    info_message[1_en]="${textcolor_light}Setting up HAProxy...${clear}"

    if [[ "$variant" != "1" ]]
    then
        echo -e "${info_message[1_$language]}"
        pass_hash=$(echo -n "${trjpass}" | openssl dgst -sha224 | sed 's/.* //')
        placeholder=$(openssl rand -hex 28)
        auth_lua

        mkdir -p /etc/haproxy/certs
        cat /etc/letsencrypt/live/${domain}/fullchain.pem /etc/letsencrypt/live/${domain}/privkey.pem > /etc/haproxy/certs/${domain}.pem
        haproxy_config

        systemctl enable haproxy.service
        haproxy -f /etc/haproxy/haproxy.cfg -c
        systemctl restart haproxy.service
        echo ""
    fi
}

add_sbmanager() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor_light}Добавление меню настроек...${clear}"
    info_message[1_en]="${textcolor_light}Adding settings menu...${clear}"

    echo -e "${info_message[1_$language]}"
    wget -O /usr/local/bin/sbmanager https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Scripts/sb-manager.sh
    chmod +x /usr/local/bin/sbmanager
    echo "alias ssb='/usr/local/bin/sbmanager'" >> /etc/bash.bashrc
}

add_sub_page() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor_light}Добавление страницы подписок...${clear}"
    info_message[1_en]="${textcolor_light}Adding subscription page...${clear}"

    echo -e "${info_message[1_$language]}"
    data_vrnt="both"
    [[ "$variant" != "1" ]] && data_vrnt="novless"
    wget -P /var/www/${subspath} https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Subscription-Page/sub.html
    wget -P /var/www/${subspath} https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Subscription-Page/background.jpg
    sed -i -e "s/DOMAIN/${domain}/g" -e "s/SUBSCRIPTION-PATH/${subspath}/g" -e "s/html lang=\"en\" data-vrnt=\"both\"/html lang=\"${language}\" data-vrnt=\"${data_vrnt}\"/g" /var/www/${subspath}/sub.html
}

final_text_ru() {
    echo ""
    echo ""
    echo -e "${textcolor}Если выше не возникло ошибок, то настройка завершена! Сохраните текст внизу!${clear}"
    echo ""
    if [[ "$ssh_ufw" != "2" ]]
    then
        echo -e "${red}ВНИМАНИЕ!${clear}"
        echo "Для повышения безопасности сервера рекомендуется выполнить следующие действия:"
        echo -e "1) Отключиться от сервера, нажав ${textcolor}Ctrl + D${clear}"
        echo -e "2) Если нет ключей SSH, то сгенерировать их на своём ПК командой ${textcolor}ssh-keygen -t rsa -b 4096${clear}"
        echo "3) Отправить публичный ключ на сервер"
        echo -e "   Команда для Linux и macOS: ${textcolor}ssh-copy-id -p ${ssh_port} ${username}@${server_ip}${clear}"
        echo -e "   Команда для Windows: ${textcolor}type \$env:USERPROFILE\.ssh\id_rsa.pub | ssh -p ${ssh_port} ${username}@${server_ip} \"cat >> ~/.ssh/authorized_keys\"${clear}"
        echo -e "4) Подключиться к серверу ещё раз командой ${textcolor}ssh -p ${ssh_port} ${username}@${server_ip}${clear}"
        echo -e "5) Отключить вход по паролю командой ${textcolor}sudo sed -i \"s/.*PasswordAuthentication yes.*/PasswordAuthentication no/g\" /etc/ssh/sshd_config${clear}"
        echo -e "6) Перезапустить SSH командой ${textcolor}sudo systemctl restart ssh.service${clear}"
    else
        echo -e "${red}ВНИМАНИЕ!${clear}"
        echo "Вы пропустили настройку безопасности, настоятельно рекомендуется выполнить её самостоятельно"
        echo "При этом порты 443 и SSH нужно оставить открытыми для TCP"
    fi
    echo ""
    echo -e "${red}ВАЖНО:${clear}"
    echo -e "Для начала работы прокси может потребоваться перезагрузка сервера командой ${textcolor}sudo reboot${clear}"
    if [[ "$variant" == "1" ]]
    then
        echo ""
        echo -e "${textcolor}Конфиги для клиента доступны по ссылкам:${clear}"
        echo "https://${domain}/${subspath}/${user_key}-TRJ-CLIENT.json"
        echo "https://${domain}/${subspath}/${user_key}-VLESS-CLIENT.json"
    else
        echo "Чтобы этот вариант настройки работал, проксирование через CDN должно быть отключено"
        echo ""
        echo -e "${textcolor}Конфиг для клиента доступен по ссылке:${clear}"
        echo "https://${domain}/${subspath}/${user_key}-TRJ-CLIENT.json"
    fi
    echo ""
    echo -e "${textcolor}Страница выдачи подписок пользователей:${clear}"
    echo "https://${domain}/${subspath}/sub.html"
    echo -e "Ваше имя пользователя - ${textcolor}${user_key}${clear}"
    echo ""
    echo -e "Для вывода меню настроек используйте команду ${textcolor}ssb${clear}"
    if [[ ! -f /etc/letsencrypt/live/${domain}/fullchain.pem ]]
    then
        echo ""
        echo -e "${red}Ошибка: не удалось выпустить сертификат, введите команду \"ssb\" и выберите пункт 11 или 12${clear}"
    fi
    echo ""
    echo ""
}

final_text_en() {
    echo ""
    echo ""
    echo -e "${textcolor}If there are no errors above then the setup is complete! Save the text below!${clear}"
    echo ""
    if [[ "$ssh_ufw" != "2" ]]
    then
        echo -e "${red}ATTENTION!${clear}"
        echo "To increase the security of the server it's recommended to do the following:"
        echo -e "1) Disconnect from the server by pressing ${textcolor}Ctrl + D${clear}"
        echo -e "2) If you don't have SSH keys then generate them on your PC (${textcolor}ssh-keygen -t rsa -b 4096${clear})"
        echo "3) Send the public key to the server"
        echo -e "   Command for Linux and macOS: ${textcolor}ssh-copy-id -p ${ssh_port} ${username}@${server_ip}${clear}"
        echo -e "   Command for Windows: ${textcolor}type \$env:USERPROFILE\.ssh\id_rsa.pub | ssh -p ${ssh_port} ${username}@${server_ip} \"cat >> ~/.ssh/authorized_keys\"${clear}"
        echo -e "4) Connect to the server again (${textcolor}ssh -p ${ssh_port} ${username}@${server_ip}${clear})"
        echo -e "5) Disable password authentication (${textcolor}sudo sed -i \"s/.*PasswordAuthentication yes.*/PasswordAuthentication no/g\" /etc/ssh/sshd_config${clear})"
        echo -e "6) Restart SSH (${textcolor}sudo systemctl restart ssh.service${clear})"
    else
        echo -e "${red}ATTENTION!${clear}"
        echo "You have skipped security setup, it is highly recommended to configure it yourself"
        echo "Ports 443 and SSH must be left open for TCP"
    fi
    echo ""
    echo -e "${red}IMPORTANT:${clear}"
    echo -e "It might be required to reboot the server for the proxy to start working (${textcolor}sudo reboot${clear})"
    if [[ "$variant" == "1" ]]
    then
        echo ""
        echo -e "${textcolor}Client configs are available here:${clear}"
        echo "https://${domain}/${subspath}/${user_key}-TRJ-CLIENT.json"
        echo "https://${domain}/${subspath}/${user_key}-VLESS-CLIENT.json"
    else
        echo "For this setup method to work, the traffic should not be proxied through CDN"
        echo ""
        echo -e "${textcolor}Client config is available here:${clear}"
        echo "https://${domain}/${subspath}/${user_key}-TRJ-CLIENT.json"
    fi
    echo ""
    echo -e "${textcolor}Subscription page:${clear}"
    echo "https://${domain}/${subspath}/sub.html"
    echo -e "Your username is ${textcolor}${user_key}${clear}"
    echo ""
    echo -e "To display the settings menu, run ${textcolor}ssb${clear} command"
    if [[ ! -f /etc/letsencrypt/live/${domain}/fullchain.pem ]]
    then
        echo ""
        echo -e "${red}Error: failed to issue the certificate, enter \"ssb\" command and select option 11 or 12${clear}"
    fi
    echo ""
    echo ""
}

check_os
check_root
check_sbmanager
banner
enter_language
start_text_${language}
get_ip
enter_data_${language}
enable_bbr
install_packages
setup_general_security
certificates
setup_warp
setup_sing_box
setup_nginx
setup_haproxy
add_sbmanager
add_sub_page
final_text_${language}
