#!/bin/bash
set -o pipefail

textcolor='\033[1;36m'
textcolor_light='\033[1;37m'
red='\033[1;31m'
clear='\033[0m'

check_os() {
    if ! grep -q -e "bookworm" -e "trixie" -e "jammy" -e "noble" -e "resolute" /etc/os-release
    then
        echo -e "${red}Error: only Debian 12/13 and Ubuntu 22.04/24.04/26.04 are supported${clear}"
        exit 1
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]]
    then
        echo -e "${red}Error: this script should be run as root, use \"sudo -i\" command first${clear}"
        exit 1
    fi
}

check_sbmanager() {
    if [[ -f /usr/local/bin/sbmanager ]]
    then
        echo -e "${red}Error: the script has already been run, use \"ssb\" command for updates${clear}"
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
    echo "3) Выполнить настройку домена (https://github.com/A-Zuro/Secret-Sing-Box/blob/main/.github/cf-settings-ru.md)"
    echo ""
    echo -e "Если это сделано, то нажмите ${textcolor}Enter${clear}, чтобы продолжить"
    echo -e "В противном случае нажмите ${textcolor}Ctrl + C${clear} для завершения работы скрипта"
    local big_red_button; read -r big_red_button
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
    echo "3) Configure your domain (https://github.com/A-Zuro/Secret-Sing-Box/blob/main/.github/cf-settings-en.md)"
    echo ""
    echo -e "If it's done, then press ${textcolor}Enter${clear} to continue"
    echo -e "If not, then press ${textcolor}Ctrl + C${clear} to exit the script"
    local big_red_button; read -r big_red_button
    [[ -n $big_red_button ]] && echo ""
    echo ""
}

update_and_reboot() {
    local -A uar_message=()
    uar_message[1_ru]="${textcolor}Обновление системы завершено${clear}"
    uar_message[2_ru]="${textcolor}Через минуту снова подключитесь к серверу по SSH и ещё раз запустите скрипт${clear}"
    uar_message[1_en]="${textcolor}The system update is complete${clear}"
    uar_message[2_en]="${textcolor}In a minute, reconnect to the server via SSH and run the script again${clear}"

    if [[ "$system_updated" == "1" ]]
    then
        apt update -y && apt full-upgrade -y
        sleep 1.5
        echo ""
        echo -e "${uar_message[1_$language]}"
        echo -e "${uar_message[2_$language]}"
        echo ""
        reboot
        exit 0
    fi
}

get_ip() {
    grep -q '^precedence \+::ffff:0:0/96 ' /etc/gai.conf &> /dev/null || echo "precedence ::ffff:0:0/96 100" >> /etc/gai.conf
    dpkg -s ca-certificates &> /dev/null || apt install ca-certificates -y &> /dev/null
    server_ip=$(curl -s4 -m 15 https://cloudflare.com/cdn-cgi/trace | grep "ip" | cut -d "=" -f 2)
    [[ ! $server_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && server_ip=$(curl -s4 -m 15 ipinfo.io/ip)
    [[ ! $server_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && server_ip=$(curl -s4 -m 15 2ip.io)
}

crop_domain() {
    domain=${domain#*"://"}
    domain=$(echo "${domain}" | cut -d "/" -f 1 | sed 's/\.\{2,\}/./g')
    domain=${domain#"www."}
}

enter_domain_data() {
    local -A edd_message=()
    edd_message[1_ru]="${textcolor}[?]${clear} Введите ваш домен:"
    edd_message[2_ru]="${textcolor}[?]${clear} Введите ваш API токен Cloudflare (Edit zone DNS):"
    edd_message[1_en]="${textcolor}[?]${clear} Enter your domain name:"
    edd_message[2_en]="${textcolor}[?]${clear} Enter your Cloudflare API token (Edit zone DNS):"

    domain=""; cf_token=""
    echo ""

    while [[ -z $domain ]]
    do
        echo -e "${edd_message[1_$language]}"
        read -r domain
        [[ -n $domain ]] && echo ""
    done

    crop_domain

    if [[ "$validation_type" == "1" ]]
    then
        while [[ -z $cf_token ]]
        do
            echo -e "${edd_message[2_$language]}"
            read -r cf_token
            [[ -n $cf_token ]] && echo ""
        done
    fi
}

enter_check_domain() {
    local -A ecd_message=()
    ecd_message[1_ru]="Проверка домена и API токена..."
    ecd_message[2_ru]="${red}Ошибка: неправильно введён домен или API токен${clear}"
    ecd_message[3_ru]="${red}Ошибка: API токен имеет недостаточно прав${clear}"
    ecd_message[4_ru]="${red}Инструкция: https://github.com/A-Zuro/Secret-Sing-Box/blob/main/.github/cf-settings-ru.md#получение-api-токена-cloudflare${clear}"
    ecd_message[5_ru]="Успешно!"
    ecd_message[1_en]="Checking domain name and API token..."
    ecd_message[2_en]="${red}Error: invalid domain name or API token${clear}"
    ecd_message[3_en]="${red}Error: the API token has insufficient permissions${clear}"
    ecd_message[4_en]="${red}Instruction: https://github.com/A-Zuro/Secret-Sing-Box/blob/main/.github/cf-settings-en.md#getting-cloudflare-api-token${clear}"
    ecd_message[5_en]="Success!"

    local test_domain test_response

    while true
    do
        enter_domain_data
        [[ "$validation_type" != "1" ]] && break
        echo "${ecd_message[1_$language]}"
        test_domain=$(echo "${domain}" | rev | cut -d "." -f 1-2 | rev)
        test_response=$(curl -s -m 30 --request GET --url https://api.cloudflare.com/client/v4/zones --header "Authorization: Bearer ${cf_token}" --header "Content-Type: application/json")

        if [[ ! $test_response =~ "\"$test_domain\"" ]]
        then
            echo ""
            echo -e "${ecd_message[2_$language]}"
            echo -e "${ecd_message[4_$language]}"
        elif [[ ! $test_response =~ "#dns_records:edit" ]] || [[ ! $test_response =~ "#dns_records:read" ]] || [[ ! $test_response =~ "#zone:read" ]]
        then
            echo ""
            echo -e "${ecd_message[3_$language]}"
            echo -e "${ecd_message[4_$language]}"
        else
            echo "${ecd_message[5_$language]}"
            echo ""
            break
        fi
    done
}

enter_check_trjpass() {
    local -A ect_message=()
    ect_message[1_ru]="${textcolor}[?]${clear} Введите пароль для Trojan или оставьте пустым для генерации случайного пароля:"
    ect_message[2_ru]="${red}Ошибка: пароль Trojan не должен содержать кавычки \"${clear}"
    ect_message[1_en]="${textcolor}[?]${clear} Enter your password for Trojan or leave this empty to generate a random password:"
    ect_message[2_en]="${red}Error: Trojan password should not contain quotes \"${clear}"

    while true
    do
        echo -e "${ect_message[1_$language]}"
        read -r trjpass
        [[ -n $trjpass ]] && echo ""

        if [[ $trjpass =~ '"' ]]
        then
            echo -e "${ect_message[2_$language]}"
            echo ""
        else
            break
        fi
    done
}

enter_check_uuid() {
    local -A ecu_message=()
    ecu_message[1_ru]="${textcolor}[?]${clear} Введите UUID для VLESS или оставьте пустым для генерации случайного UUID:"
    ecu_message[2_ru]="${red}Ошибка: введённое значение не является UUID${clear}"
    ecu_message[1_en]="${textcolor}[?]${clear} Enter your UUID for VLESS or leave this empty to generate a random UUID:"
    ecu_message[2_en]="${red}Error: this is not an UUID${clear}"

    while true
    do
        echo -e "${ecu_message[1_$language]}"
        read -r uuid
        [[ -n $uuid ]] && echo ""

        if [[ ! $uuid =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]] && [[ -n $uuid ]]
        then
            echo -e "${ecu_message[2_$language]}"
            echo ""
        else
            break
        fi
    done
}

enter_check_trojan_path() {
    local -A ectp_message=()
    ectp_message[1_ru]="${textcolor}[?]${clear} Введите путь для Trojan или оставьте пустым для генерации случайного пути:"
    ectp_message[2_ru]="${red}Ошибка: путь должен содержать только английские буквы, цифры, символы _ и -${clear}"
    ectp_message[1_en]="${textcolor}[?]${clear} Enter your path for Trojan or leave this empty to generate a random path:"
    ectp_message[2_en]="${red}Error: the path should contain only letters, numbers, _ and - symbols${clear}"

    while true
    do
        echo -e "${ectp_message[1_$language]}"
        read -r trojanpath
        [[ -n $trojanpath ]] && echo ""
        trojanpath=${trojanpath#"/"}

        if [[ ! $trojanpath =~ ^[a-zA-Z0-9_-]+$ ]] && [[ -n $trojanpath ]]
        then
            echo -e "${ectp_message[2_$language]}"
            echo ""
        else
            break
        fi
    done
}

enter_check_vless_path() {
    local -A ecvp_message=()
    ecvp_message[1_ru]="${textcolor}[?]${clear} Введите путь для VLESS или оставьте пустым для генерации случайного пути:"
    ecvp_message[2_ru]="${red}Ошибка: путь должен содержать только английские буквы, цифры, символы _ и -${clear}"
    ecvp_message[3_ru]="${red}Ошибка: пути для Trojan и VLESS должны быть разными${clear}"
    ecvp_message[1_en]="${textcolor}[?]${clear} Enter your path for VLESS or leave this empty to generate a random path:"
    ecvp_message[2_en]="${red}Error: the path should contain only letters, numbers, _ and - symbols${clear}"
    ecvp_message[3_en]="${red}Error: paths for Trojan and VLESS must be different${clear}"

    while true
    do
        echo -e "${ecvp_message[1_$language]}"
        read -r vlesspath
        [[ -n $vlesspath ]] && echo ""
        vlesspath=${vlesspath#"/"}

        if [[ ! $vlesspath =~ ^[a-zA-Z0-9_-]+$ ]] && [[ -n $vlesspath ]]
        then
            echo -e "${ecvp_message[2_$language]}"
            echo ""
        elif [[ "$vlesspath" == "$trojanpath" ]] && [[ -n $vlesspath ]]
        then
            echo -e "${ecvp_message[3_$language]}"
            echo ""
        else
            break
        fi
    done
}

enter_check_subs_path() {
    local -A ecsp_message=()
    ecsp_message[1_ru]="${textcolor}[?]${clear} Введите путь для подписки или оставьте пустым для генерации случайного пути:"
    ecsp_message[2_ru]="${red}Ошибка: путь должен содержать только английские буквы, цифры, символы _ и -${clear}"
    ecsp_message[3_ru]="${red}Ошибка: пути для Trojan, VLESS и подписки должны быть разными${clear}"
    ecsp_message[1_en]="${textcolor}[?]${clear} Enter your subscription path or leave this empty to generate a random path:"
    ecsp_message[2_en]="${red}Error: the path should contain only letters, numbers, _ and - symbols${clear}"
    ecsp_message[3_en]="${red}Error: paths for Trojan, VLESS and subscription must be different${clear}"

    while true
    do
        echo -e "${ecsp_message[1_$language]}"
        read -r subspath
        [[ -n $subspath ]] && echo ""
        subspath=${subspath#"/"}

        if [[ ! $subspath =~ ^[a-zA-Z0-9_-]+$ ]] && [[ -n $subspath ]]
        then
            echo -e "${ecsp_message[2_$language]}"
            echo ""
        elif ([[ "$subspath" == "$trojanpath" ]] || [[ "$subspath" == "$vlesspath" ]]) && [[ -n $subspath ]]
        then
            echo -e "${ecsp_message[3_$language]}"
            echo ""
        else
            break
        fi
    done
}

enter_check_ruleset_path() {
    local -A ecrp_message=()
    ecrp_message[1_ru]="${textcolor}[?]${clear} Введите путь для наборов правил (rule sets) или оставьте пустым для генерации случайного пути:"
    ecrp_message[2_ru]="${red}Ошибка: путь должен содержать только английские буквы, цифры, символы _ и -${clear}"
    ecrp_message[3_ru]="${red}Ошибка: пути для Trojan, VLESS, подписки и наборов правил должны быть разными${clear}"
    ecrp_message[1_en]="${textcolor}[?]${clear} Enter your path for rule sets or leave this empty to generate a random path:"
    ecrp_message[2_en]="${red}Error: the path should contain only letters, numbers, _ and - symbols${clear}"
    ecrp_message[3_en]="${red}Error: paths for Trojan, VLESS, subscription and rule sets must be different${clear}"

    while true
    do
        echo -e "${ecrp_message[1_$language]}"
        read -r rulesetpath
        [[ -n $rulesetpath ]] && echo ""
        rulesetpath=${rulesetpath#"/"}

        if [[ ! $rulesetpath =~ ^[a-zA-Z0-9_-]+$ ]] && [[ -n $rulesetpath ]]
        then
            echo -e "${ecrp_message[2_$language]}"
            echo ""
        elif ([[ "$rulesetpath" == "$trojanpath" ]] || [[ "$rulesetpath" == "$vlesspath" ]] || [[ "$rulesetpath" == "$subspath" ]]) && [[ -n $rulesetpath ]]
        then
            echo -e "${ecrp_message[3_$language]}"
            echo ""
        else
            break
        fi
    done
}

enter_check_ssh_port() {
    local -A ecspo_message=()
    ecspo_message[1_ru]="${textcolor}[?]${clear} Введите новый номер порта SSH или 22 (рекомендуется номер более 1024):"
    ecspo_message[2_ru]="${red}Ошибка: номер порта должен быть целым положительным числом${clear}"
    ecspo_message[3_ru]="${red}Ошибка: номер порта не может быть больше 65535${clear}"
    ecspo_message[4_ru]="${red}Ошибка: порты 80, 443, 10443, 11443 и 40000 будут заняты${clear}"
    ecspo_message[1_en]="${textcolor}[?]${clear} Enter new SSH port number or 22 (number above 1024 is recommended):"
    ecspo_message[2_en]="${red}Error: the port number must be a positive integer${clear}"
    ecspo_message[3_en]="${red}Error: the port number can't be greater than 65535${clear}"
    ecspo_message[4_en]="${red}Error: the ports 80, 443, 10443, 11443 and 40000 will be taken${clear}"

    while true
    do
        echo -e "${ecspo_message[1_$language]}"
        read -r ssh_port
        [[ -n $ssh_port ]] && echo ""

        if [[ -z $ssh_port ]]
        then
            :
        elif [[ ! $ssh_port =~ ^[1-9][0-9]*$ ]]
        then
            echo -e "${ecspo_message[2_$language]}"
            echo ""
        elif [[ $ssh_port -gt 65535 ]]
        then
            echo -e "${ecspo_message[3_$language]}"
            echo ""
        elif [[ $ssh_port =~ ^(80|443|10443|11443|40000)$ ]]
        then
            echo -e "${ecspo_message[4_$language]}"
            echo ""
        else
            break
        fi
    done
}

enter_check_username() {
    local -A ecus_message=()
    ecus_message[1_ru]="${textcolor}[?]${clear} Введите имя нового пользователя или root (рекомендуется не root):"
    ecus_message[2_ru]="${red}Ошибка: имя пользователя должно содержать только английские строчные буквы, цифры, символы _ и -, а также начинаться со строчной буквы${clear}"
    ecus_message[1_en]="${textcolor}[?]${clear} Enter your new username or root (non-root user is recommended):"
    ecus_message[2_en]="${red}Error: the username should contain only lowercase letters, numbers, _ and - symbols, and must start with a lowercase letter${clear}"

    while true
    do
        echo -e "${ecus_message[1_$language]}"
        read -r username
        [[ -n $username ]] && echo ""

        if [[ -z $username ]]
        then
            :
        elif [[ ! $username =~ ^[a-z][-a-z0-9_]*\$?$ ]]
        then
            echo -e "${ecus_message[2_$language]}"
            echo ""
        else
            break
        fi
    done
}

enter_check_password() {
    local -A ecp_message=()
    ecp_message[1_ru]="${textcolor}[?]${clear} Введите пароль SSH для нового пользователя (рекомендуется сложный пароль):"
    ecp_message[2_ru]="${red}Ошибка: пароль не должен содержать кавычки \"${clear}"
    ecp_message[1_en]="${textcolor}[?]${clear} Enter SSH password for the new user (a complex password is recommended):"
    ecp_message[2_en]="${red}Error: the password should not contain quotes \"${clear}"

    while true
    do
        echo -e "${ecp_message[1_$language]}"
        read -r password
        [[ -n $password ]] && echo ""

        if [[ -z $password ]]
        then
            :
        elif [[ $password =~ '"' ]]
        then
            echo -e "${ecp_message[2_$language]}"
            echo ""
        else
            break
        fi
    done
}

crop_redirect_domain() {
    redirect=${redirect#*"://"}
    redirect=$(echo "${redirect}" | cut -d "/" -f 1)
    redirect=${redirect#"www."}
}

enter_check_redirect_domain() {
    local -A ecrd_message=()
    ecrd_message[1_ru]="${textcolor}[?]${clear} Введите домен, на который будет идти перенаправление:"
    ecrd_message[2_ru]="${red}Ошибка: домен введён неправильно или не имеет HTTPS, выберите другой домен${clear}"
    ecrd_message[1_en]="${textcolor}[?]${clear} Enter the domain to which requests will be redirected:"
    ecrd_message[2_en]="${red}Error: this domain is invalid or does not have HTTPS, select another domain${clear}"

    while true
    do
        echo -e "${ecrd_message[1_$language]}"
        read -r redirect
        [[ -n $redirect ]] && echo ""
        crop_redirect_domain

        if [[ -z $redirect ]]
        then
            :
        elif [[ $(curl -s -o /dev/null -w "%{http_code}" -m 30 "https://${redirect}") == "000" ]]
        then
            echo -e "${ecrd_message[2_$language]}"
            echo ""
        else
            break
        fi
    done
}

enter_check_site_link() {
    local -A ecsl_message=()
    ecsl_message[1_ru]="${textcolor}[?]${clear} Введите ссылку на главную страницу выбранного сайта:"
    ecsl_message[2_ru]="${red}Ошибка: сайт недоступен по данной ссылке или не имеет HTTPS, выберите другой сайт${clear}"
    ecsl_message[1_en]="${textcolor}[?]${clear} Enter the link to the main page of the selected website:"
    ecsl_message[2_en]="${red}Error: the website is not available or does not have HTTPS, select another website${clear}"

    dpkg -s wget &> /dev/null || apt install wget -y &> /dev/null

    while true
    do
        echo -e "${ecsl_message[1_$language]}"
        read -r site_link
        [[ -n $site_link ]] && echo ""
        site_link=${site_link#*"://"}

        if [[ -z $site_link ]]
        then
            :
        elif [[ $(curl -s -o /dev/null -w "%{http_code}" -m 30 "https://${site_link}") == "000" ]] || ! wget -q -O /dev/null -T 30 "https://${site_link}"
        then
            echo -e "${ecsl_message[2_$language]}"
            echo ""
        else
            break
        fi
    done
}

edit_index_path() {
    [[ "$index_path" != "/"* ]] && index_path="/${index_path}"
    index_path=${index_path%"/"}
}

enter_check_index_path() {
    local -A ecip_message=()
    ecip_message[1_ru]="${textcolor}[?]${clear} Введите путь до index файла внутри папки вашего сайта (например, /site_folder/index.html):"
    ecip_message[2_ru]="${red}Ошибка: файл"
    ecip_message[3_ru]="не существует, проверьте, загружена ли папка вашего сайта в /root директорию сервера${clear}"
    ecip_message[1_en]="${textcolor}[?]${clear} Enter the path to the index file inside the folder of your website (e. g., /site_folder/index.html):"
    ecip_message[2_en]="${red}Error: the file"
    ecip_message[3_en]="doesn't exist, check if the folder of your website is uploaded to the /root directory of the server${clear}"

    while true
    do
        echo -e "${ecip_message[1_$language]}"
        read -r index_path
        [[ -n $index_path ]] && echo ""
        edit_index_path

        if [[ -z $index_path ]]
        then
            :
        elif [[ ! -f /root${index_path} ]]
        then
            echo -e "${ecip_message[2_$language]} /root${index_path} ${ecip_message[3_$language]}"
            echo ""
        else
            break
        fi
    done
}

nginx_login() {
    comment_1="# "; comment_2=""; comment_3=""
    redirect="example.com"   # Dummy, will be commented
    site_dir="html"
    index="index.html index.htm"
}

nginx_redirect() {
    comment_1=""; comment_2="# "; comment_3=""
    site_dir="html"
    index="index.html index.htm"
    enter_check_redirect_domain
}

nginx_copy_site() {
    comment_1=""; comment_2=""; comment_3="# "
    redirect="example.com"   # Dummy, will be commented

    nginx_copy_site_text_ru() {
        echo -e "${red}ВНИМАНИЕ!${clear}"
        echo "Некоторые сайты могут содержать большие файлы или большое число страниц, которые могут занять много места на диске"
        echo "Функционал некоторых сайтов может быть частично утрачен"
        echo "Вы выбираете какой-либо сайт на свой страх и риск"
        echo ""
    }

    nginx_copy_site_text_en() {
        echo -e "${red}ATTENTION!${clear}"
        echo "Some websites might contain large files or large number of pages, which may take a lot of disk space"
        echo "Some websites may partially lose their functionality"
        echo "You choose the website at your own risk"
        echo ""
    }

    "nginx_copy_site_text_${language}"
    enter_check_site_link
}

nginx_site() {
    comment_1=""; comment_2=""; comment_3="# "
    redirect="example.com"   # Dummy, will be commented

    nginx_site_text_ru() {
        echo -e "${red}ВНИМАНИЕ!${clear}"
        echo -e "Сначала загрузите папку с файлами вашего сайта в ${textcolor}/root${clear} директорию сервера"
        echo "Вы можете сделать это с помощью SFTP или SCP через другое окно, не прерывая работу скрипта"
        echo "Поддерживаются только статические сайты (HTML, CSS и JavaScript)"
        echo ""
    }

    nginx_site_text_en() {
        echo -e "${red}ATTENTION!${clear}"
        echo -e "First, upload the folder with the contents of your website to the ${textcolor}/root${clear} directory of the server"
        echo "You can do this via SFTP or SCP in another window without interrupting the script"
        echo "Only static websites are supported (HTML, CSS and JavaScript)"
        echo ""
    }

    "nginx_site_text_${language}"
    enter_check_index_path
}

nginx_options() {
    case "$option" in
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

enter_data_ru() {
    echo -e "${textcolor}[?]${clear} Вы точно обновили систему и перезагрузили сервер перед запуском скрипта?"
    echo "1 - Обновить и перезагрузить сейчас"
    echo "2 - Продолжить (система была обновлена и перезагружена)"
    local system_updated; read -r system_updated
    [[ -n $system_updated ]] && echo ""
    update_and_reboot

    echo -e "${textcolor}[?]${clear} Выберите метод валидации сертификатов:"
    echo "1 - DNS Cloudflare (если ваш домен прикреплён к Cloudflare)"
    echo "2 - Standalone (если ваш домен прикреплён к другому сервису)"
    read -r validation_type

    if [[ "$validation_type" != "1" ]]
    then
        [[ -n $validation_type ]] && echo ""
        echo -e "${red}ВНИМАНИЕ!${clear}"
        echo "Обязательно проверьте правильность написания домена"
    fi

    enter_check_domain
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

    echo -e "${textcolor}[?]${clear} Выберите вариант настройки сайта-заглушки:"
    echo "1 - Будет спрашивать логин и пароль вместо сайта, 401 Unauthorized"
    echo "2 - Будет перенаправлять на другой домен, 301 Moved Permanently"
    echo "3 - Скопировать чужой сайт на этот сервер, тестовая опция"
    echo "4 - Загрузить свой сайт (при наличии), тестовая опция"
    read -r option
    [[ -n $option ]] && echo ""
    nginx_options
    enter_check_trjpass

    if [[ "$variant" == "1" ]]
    then
        enter_check_trojan_path
        enter_check_uuid
        enter_check_vless_path
    fi

    enter_check_subs_path
    enter_check_ruleset_path

    echo -e "${textcolor}[?]${clear} Нужна ли настройка безопасности (SSH, UFW и unattended-upgrades)?"
    echo "1 - Да (в редких случаях при нестандартных настройках у хостера можно потерять доступ к серверу)"
    echo "2 - Нет (тогда рекомендуется выполнить настройку самостоятельно после завершения работы скрипта)"
    read -r ssh_ufw
    [[ -n $ssh_ufw ]] && echo ""

    if [[ "$ssh_ufw" != "2" ]]
    then
        enter_check_ssh_port
        enter_check_username
        enter_check_password
    fi

    echo ""
    echo ""
}

enter_data_en() {
    echo -e "${textcolor}[?]${clear} Are you sure you have updated the system and rebooted the server before running the script?"
    echo "1 - Update and reboot now"
    echo "2 - Continue (the system has been updated and rebooted)"
    local system_updated; read -r system_updated
    [[ -n $system_updated ]] && echo ""
    update_and_reboot

    echo -e "${textcolor}[?]${clear} Select a certificate validation method:"
    echo "1 - DNS Cloudflare (if your domain is linked to Cloudflare)"
    echo "2 - Standalone (if your domain is linked to another service)"
    read -r validation_type

    if [[ "$validation_type" != "1" ]]
    then
        [[ -n $validation_type ]] && echo ""
        echo -e "${red}ATTENTION!${clear}"
        echo "Be sure to check the spelling of the domain name"
    fi

    enter_check_domain
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

    echo -e "${textcolor}[?]${clear} Select a setup option for the dummy website:"
    echo "1 - Will show a login popup asking for username and password, 401 Unauthorized"
    echo "2 - Will redirect to another domain, 301 Moved Permanently"
    echo "3 - Copy someone else's website to this server, experimental option"
    echo "4 - Upload your own website (if you have one), experimental option"
    read -r option
    [[ -n $option ]] && echo ""
    nginx_options
    enter_check_trjpass

    if [[ "$variant" == "1" ]]
    then
        enter_check_trojan_path
        enter_check_uuid
        enter_check_vless_path
    fi

    enter_check_subs_path
    enter_check_ruleset_path

    echo -e "${textcolor}[?]${clear} Do you need security setup (SSH, UFW and unattended-upgrades)?"
    echo "1 - Yes (in rare cases of hoster's non-standard settings, access to the server might be lost)"
    echo "2 - No (then it is recommended to perform the setup manually after the script finishes running)"
    read -r ssh_ufw
    [[ -n $ssh_ufw ]] && echo ""

    if [[ "$ssh_ufw" != "2" ]]
    then
        enter_check_ssh_port
        enter_check_username
        enter_check_password
    fi

    echo ""
    echo ""
}

enable_bbr() {
    local -A eb_message=()
    eb_message[1_ru]="${textcolor_light}Настройка BBR...${clear}"
    eb_message[1_en]="${textcolor_light}Setting up BBR...${clear}"

    echo -e "${eb_message[1_$language]}"
    echo "net.core.default_qdisc = fq" >> /etc/sysctl.d/99-ssb.conf
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.d/99-ssb.conf
    sysctl --system &> /dev/null
    sysctl net.core.default_qdisc net.ipv4.tcp_congestion_control
    echo ""
}

install_packages() {
    local -A ip_message=()
    ip_message[1_ru]="${textcolor_light}Установка необходимых пакетов...${clear}"
    ip_message[1_en]="${textcolor_light}Installing the required packages...${clear}"

    echo -e "${ip_message[1_$language]}"
    apt install sudo coreutils nano whiptail wget ufw certbot python3-certbot-dns-cloudflare cron gnupg2 openssl sed jq net-tools htop -y
    [[ "$ssh_ufw" != "2" ]] && apt install unattended-upgrades -y
    [[ ! -d /root/.gnupg ]] && mkdir -m 700 /root/.gnupg
    local os_codename=$(grep "VERSION_CODENAME=" /etc/os-release | cut -d "=" -f 2)

    if grep -q -e "bookworm" -e "trixie" /etc/os-release
    then
        apt install debian-archive-keyring -y
        local server_os="debian"
    else
        apt install ubuntu-keyring -y
        local server_os="ubuntu"
    fi

    echo ""
    [[ ! -d /etc/apt/keyrings ]] && mkdir -p /etc/apt/keyrings
    wget -q -O /etc/apt/keyrings/sagernet.asc -T 30 https://deb.sagernet.org/gpg.key && chmod a+r /etc/apt/keyrings/sagernet.asc
    gpg --dry-run --quiet --no-keyring --import --import-options import-show /etc/apt/keyrings/sagernet.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | tee /etc/apt/sources.list.d/sagernet.list > /dev/null
    apt-get update -y; apt-get install sing-box -y
    apt-mark hold sing-box

    echo ""
    [[ ! -d /var/www ]] && mkdir -p /var/www
    [[ ! -d /usr/share/keyrings ]] && mkdir -p /usr/share/keyrings
    wget -q -O - -T 30 https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg > /dev/null
    gpg --dry-run --quiet --no-keyring --import --import-options import-show /usr/share/keyrings/nginx-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/${server_os} ${os_codename} nginx" | tee /etc/apt/sources.list.d/nginx.list
    echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" | tee /etc/apt/preferences.d/99nginx
    apt update -y; apt install nginx -y

    echo ""
    wget -q -O - -T 30 https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    gpg --dry-run --quiet --no-keyring --import --import-options import-show /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ ${os_codename} main" | tee /etc/apt/sources.list.d/cloudflare-client.list
    #apt-get update -y; apt-get install cloudflare-warp -y
    downgrade_nasty_warp

    [[ "$variant" != "1" ]] && apt install haproxy -y
    apt autoremove -y; apt autoclean -y
    echo ""
}

downgrade_nasty_warp() {
    # Because some WARP releases are buggy...
    local warp_version="2026.3.846.0" proc_arch="amd64"
    [[ $(uname -m) == "aarch64" || $(uname -m) == "arm64" ]] && proc_arch="arm64"
    [[ "$os_codename" == "resolute" ]] && os_codename="noble"
    echo ""
    wget -P /tmp -T 150 "https://pkg.cloudflareclient.com/pool/${os_codename}/main/c/cloudflare-warp/cloudflare-warp_${warp_version}_${proc_arch}.deb"

    if [[ $? -eq 0 ]]
    then
        apt install "/tmp/cloudflare-warp_${warp_version}_${proc_arch}.deb" -y
        rm -f "/tmp/cloudflare-warp_${warp_version}_${proc_arch}.deb"
        apt-mark hold cloudflare-warp
    fi
}

create_user() {
    local -A cu_message=()
    cu_message[1_ru]="${textcolor_light}Создание пользователя ${username}...${clear}"
    cu_message[1_en]="${textcolor_light}Creating user ${username}...${clear}"

    if [[ "$username" != "root" ]]
    then
        echo -e "${cu_message[1_$language]}"
        useradd -m -s "$(which bash)" -G sudo "${username}"
    fi

    echo "${username}:$(openssl passwd -6 "${password}")" | chpasswd -e
    echo ""
}

setup_ssh() {
    local -A ss_message=()
    ss_message[1_ru]="${textcolor_light}Изменение настроек SSH...${clear}"
    ss_message[1_en]="${textcolor_light}Changing SSH settings...${clear}"

    echo -e "${ss_message[1_$language]}"

    if [[ "$username" == "root" ]]
    then
        sed -i -e "s/.*Port .*/Port ${ssh_port}/g" -e "s/.*PermitRootLogin no.*/PermitRootLogin yes/g" -e "s/.*#PermitRootLogin .*/PermitRootLogin yes/g" -e "s/.*PasswordAuthentication no.*/PasswordAuthentication yes/g" -e "s/.*#PasswordAuthentication .*/PasswordAuthentication yes/g" /etc/ssh/sshd_config
        [[ ! -d /root/.ssh ]] && mkdir -p /root/.ssh
    else
        sed -i -e "s/.*Port .*/Port ${ssh_port}/g" -e "s/.*PermitRootLogin yes.*/PermitRootLogin no/g" -e "s/.*#PermitRootLogin .*/PermitRootLogin no/g" -e "s/.*PasswordAuthentication no.*/PasswordAuthentication yes/g" -e "s/.*#PasswordAuthentication .*/PasswordAuthentication yes/g" /etc/ssh/sshd_config
        [[ ! -d /home/${username}/.ssh ]] && mkdir -p "/home/${username}/.ssh"
        chown "${username}:sudo" "/home/${username}/.ssh"
        chmod 700 "/home/${username}/.ssh"
    fi

    if grep -q -e "noble" -e "resolute" /etc/os-release
    then
        systemctl disable --now ssh.socket
        systemctl mask ssh.socket
        systemctl enable --now ssh.service
        echo ""
    fi

    grep -q "PasswordAuthentication yes" /etc/ssh/sshd_config.d/50-cloud-init.conf &> /dev/null && rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf
    systemctl restart ssh.service
    systemctl status ssh.service --no-pager -l -n 5
    echo ""
}

setup_ufw() {
    local -A su_message=()
    su_message[1_ru]="${textcolor_light}Настройка UFW...${clear}"
    su_message[1_en]="${textcolor_light}Setting up UFW...${clear}"

    echo -e "${su_message[1_$language]}"
    ufw allow "${ssh_port}/tcp"
    ufw allow 443/tcp
    # Protection from incoming Reality requests:
    ufw insert 1 deny from "${server_ip}/22" &> /dev/null
    echo ""
    ufw --force enable
    echo ""
    ufw status
}

unattended_upgrades() {
    local -A uu_message=()
    uu_message[1_ru]="${textcolor_light}Настройка unattended-upgrades...${clear}"
    uu_message[1_en]="${textcolor_light}Setting up unattended upgrades...${clear}"

    echo -e "${uu_message[1_$language]}"
    echo 'Unattended-Upgrade::Mail "root";' >> /etc/apt/apt.conf.d/50unattended-upgrades
    echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
    dpkg-reconfigure -f noninteractive unattended-upgrades
    systemctl restart unattended-upgrades.service
    systemctl enable unattended-upgrades.service
    echo ""
    systemctl status unattended-upgrades.service --no-pager -l -n 5
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
    echo "dns_cloudflare_api_token = ${cf_token}" >> /etc/letsencrypt/cloudflare.credentials
    chown root:root /etc/letsencrypt/cloudflare.credentials
    chmod 600 /etc/letsencrypt/cloudflare.credentials
    certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.credentials --dns-cloudflare-propagation-seconds 35 -d "${domain},*.${domain}" --agree-tos --non-interactive --register-unsafely-without-email

    if [[ $? -ne 0 ]]
    then
        sleep 3
        echo ""
        echo -e "${cert_message[2_$language]}"
        certbot delete --cert-name "${domain}" --quiet &> /dev/null
        certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.credentials --dns-cloudflare-propagation-seconds 35 -d "${domain},*.${domain}" --agree-tos --non-interactive --register-unsafely-without-email
    fi
}

cert_standalone() {
    ufw allow 80 &> /dev/null
    certbot certonly --standalone --preferred-challenges http -d "${domain}" --agree-tos --non-interactive --register-unsafely-without-email

    if [[ $? -ne 0 ]]
    then
        sleep 3
        echo ""
        echo -e "${cert_message[2_$language]}"
        certbot delete --cert-name "${domain}" --quiet &> /dev/null
        certbot certonly --standalone --preferred-challenges http -d "${domain}" --agree-tos --non-interactive --register-unsafely-without-email
    fi

    ufw delete allow 80 &> /dev/null
}

certificates() {
    local -A cert_message=()
    cert_message[1_ru]="${textcolor_light}Получение сертификата...${clear}"
    cert_message[2_ru]="${textcolor_light}Получение сертификата: 2-я попытка...${clear}"
    cert_message[1_en]="${textcolor_light}Requesting a certificate...${clear}"
    cert_message[2_en]="${textcolor_light}Requesting a certificate: 2nd attempt...${clear}"

    echo -e "${cert_message[1_$language]}"
    local warn_file=$(python3 -c "import os, CloudFlare; print(os.path.join(os.path.dirname(CloudFlare.__file__), 'warning_2_20.py'))")
    [[ $(dpkg -s python3-cloudflare | grep -i '^version') =~ "2.20." ]] && sed -i 's/2\.20\./2\.25\./g' "${warn_file}" &> /dev/null

    if [[ "$validation_type" == "1" ]]
    then
        cert_dns_cf
    else
        cert_standalone
    fi

    if [[ "$variant" == "1" ]]
    then
        echo "renew_hook = systemctl reload nginx.service" >> "/etc/letsencrypt/renewal/${domain}.conf"
        echo ""
        openssl dhparam -out /etc/nginx/dhparam.pem 2048
    else
        echo "renew_hook = cat /etc/letsencrypt/live/${domain}/fullchain.pem /etc/letsencrypt/live/${domain}/privkey.pem > /etc/haproxy/certs/${domain}.pem && systemctl reload haproxy.service" >> "/etc/letsencrypt/renewal/${domain}.conf"
        echo ""
        openssl dhparam -out /etc/haproxy/dhparam.pem 2048
    fi

    echo ""
}

setup_warp() {
    local -A sw_message=()
    sw_message[1_ru]="${textcolor_light}Настройка WARP...${clear}"
    sw_message[1_en]="${textcolor_light}Setting up WARP...${clear}"

    echo -e "${sw_message[1_$language]}"
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
    systemctl status warp-svc.service --no-pager -l -n 5
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
    mkdir -p "/var/www/${rulesetpath}"
    wget -P "/var/www/${rulesetpath}" -T 30 https://raw.githubusercontent.com/FPPweb3/sb-rule-sets/main/torrent-clients.json
    wget -P "/var/www/${rulesetpath}" -T 30 https://raw.githubusercontent.com/FPPweb3/sb-rule-sets/main/bypass-apps.json
    wget -P "/var/www/${rulesetpath}" -T 30 https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-ru.srs
    local ruleset_ind ruleset

    for ruleset_ind in $(seq 0 "$(jq '.route.rule_set | length - 1' "/var/www/${subspath}/${user_key}-TRJ-CLIENT.json")")
    do
        ruleset=$(jq -r ".route.rule_set[${ruleset_ind}].url" "/var/www/${subspath}/${user_key}-TRJ-CLIENT.json" | cut -d "/" -f 5)
        [[ "$ruleset" == "torrent-clients.json" || "$ruleset" == "bypass-apps.json" || "$ruleset" == "geoip-ru.srs" ]] && continue
        wget -P "/var/www/${rulesetpath}" -T 30 "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/${ruleset}"
    done

    for ruleset_ind in $(seq 0 "$(jq '.route.rule_set | length - 1' /etc/sing-box/config.json)")
    do
        ruleset=$(jq -r ".route.rule_set[${ruleset_ind}].path" /etc/sing-box/config.json | cut -d "/" -f 5)
        [[ ! -f /var/www/${rulesetpath}/${ruleset} ]] && wget -P "/var/www/${rulesetpath}" -T 30 "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/${ruleset}"
    done

    chmod -R 755 "/var/www/${rulesetpath}"
    wget -O /usr/local/bin/rsupdate -T 30 https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Scripts/ruleset-update.sh
    chmod +x /usr/local/bin/rsupdate
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
    ]
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
          "ntc.party",
          "canva.com"
        ],
        "domain_keyword": [
          "xn--",
          "habr",
          "rutracker"
        ],
        "rule_set": [
          "geoip-ru",
          "category-gov-ru",
          "openai",
          "anthropic",
          "xai",
          "deviantart"
        ],
        "outbound": "warp"
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
      },
      {
        "tag": "deviantart",
        "type": "local",
        "format": "binary",
        "path": "/var/www/${rulesetpath}/geosite-deviantart.srs"
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
cat > "/var/www/${subspath}/${user_key}-TRJ-CLIENT.json" <<EOF
{
  "log": {
    "level": "fatal",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "type": "local",
        "tag": "dns-local"
      },
      {
        "type": "tls",
        "tag": "dns-remote",
        "server": "1.1.1.1",
        "tls": {
          "enabled": true,
          "server_name": "one.one.one.one"
        },
        "detour": "proxy"
      }
    ],
    "rules": [
      {
        "rule_set": [
          "category-ads-all"
        ],
        "action": "predefined",
        "rcode": "NOERROR"
      },
      {
        "process_name": [
          "max.exe",
          "max-service.exe",
          "crashpad_handler.exe"
        ],
        "server": "dns-local"
      },
      {
        "rule_set": [
          "torrent-clients",
          "bypass-apps"
        ],
        "server": "dns-local"
      },
      {
        "domain_suffix": [
          "kemono.su",
          "jut.su",
          "kara.su",
          "smods.ru",
          "theins.ru",
          "tvrain.ru",
          "echo.msk.ru",
          "the-village.ru",
          "snob.ru",
          "novayagazeta.ru",
          "moscowtimes.ru",
          "lesswrong.ru"
        ],
        "domain_keyword": [
          "habr",
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
          "pinterest",
          "duckduckgo",
          "yahoo",
          "oracle",
          "blender",
          "drweb",
          "debian",
          "canonical",
          "python",
          "doi",
          "springer",
          "elsevier",
          "sciencedirect",
          "sci-hub",
          "duolingo"
        ],
        "server": "dns-local"
      },
      {
        "inbound": [
          "tun-in"
        ],
        "server": "dns-remote"
      }
    ]
  },
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "tun0",
      "stack": "system",
      "address": [
        "172.19.0.1/28"
      ],
      "auto_route": true,
      "strict_route": true
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
        "server_name": "${domain}"
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
  "http_clients": [
    {
      "tag": "http-direct"
    },
    {
      "tag": "http-proxy",
      "detour": "proxy"
    }
  ],
  "route": {
    "auto_detect_interface": true,
    "default_http_client": "http-direct",
    "default_domain_resolver": {
      "server": "dns-local",
      "strategy": "prefer_ipv4"
    },
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
        "process_name": [
          "max.exe",
          "max-service.exe",
          "crashpad_handler.exe"
        ],
        "outbound": "direct"
      },
      {
        "rule_set": [
          "torrent-clients",
          "bypass-apps"
        ],
        "outbound": "direct"
      },
      {
        "domain_suffix": [
          "kemono.su",
          "jut.su",
          "kara.su",
          "smods.ru",
          "theins.ru",
          "tvrain.ru",
          "echo.msk.ru",
          "the-village.ru",
          "snob.ru",
          "novayagazeta.ru",
          "moscowtimes.ru",
          "lesswrong.ru"
        ],
        "domain_keyword": [
          "habr",
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
          "pinterest",
          "duckduckgo",
          "yahoo",
          "oracle",
          "blender",
          "drweb",
          "debian",
          "canonical",
          "python",
          "doi",
          "springer",
          "elsevier",
          "sciencedirect",
          "sci-hub",
          "duolingo"
        ],
        "outbound": "direct"
      },
      {
        "action": "resolve"
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
        "tag": "bypass-apps",
        "type": "remote",
        "format": "source",
        "url": "https://${domain}/${rulesetpath}/bypass-apps.json"
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
        "tag": "pinterest",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-pinterest.srs"
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
        "tag": "oracle",
        "type": "remote",
        "format": "binary",
        "url": "https://${domain}/${rulesetpath}/geosite-oracle.srs"
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
    local -A ssb_message=()
    ssb_message[1_ru]="${textcolor_light}Настройка Sing-Box...${clear}"
    ssb_message[1_en]="${textcolor_light}Setting up Sing-Box...${clear}"

    echo -e "${ssb_message[1_$language]}"
    generate_pass
    mkdir -p "/var/www/${subspath}"
    sb_server_config
    sb_client_config
    local outbound_num=$(jq '[.outbounds[].tag] | index("proxy")' "/var/www/${subspath}/${user_key}-TRJ-CLIENT.json")

    if [[ "$transport" == "2" ]]
    then
        echo "$(jq '.inbounds[].transport.type = "httpupgrade"' /etc/sing-box/config.json)" > /etc/sing-box/config.json
        echo "$(jq ".outbounds[${outbound_num}].transport.type = \"httpupgrade\"" "/var/www/${subspath}/${user_key}-TRJ-CLIENT.json")" > "/var/www/${subspath}/${user_key}-TRJ-CLIENT.json"
    fi

    if [[ "$variant" == "1" ]]
    then
        echo "$(jq ".outbounds[${outbound_num}].type = \"vless\" | .outbounds[${outbound_num}] |= with_entries(.key |= if . == \"password\" then \"uuid\" else . end) | .outbounds[${outbound_num}].uuid = \"${uuid}\" | .outbounds[${outbound_num}].transport.path = \"/${vlesspath}\"" "/var/www/${subspath}/${user_key}-TRJ-CLIENT.json")" > "/var/www/${subspath}/${user_key}-VLESS-CLIENT.json"
    else
        local inbound_num_tr=$(jq '[.inbounds[].tag] | index("trojan-in")' /etc/sing-box/config.json)
        local inbound_num_vl=$(jq '[.inbounds[].tag] | index("vless-in")' /etc/sing-box/config.json)
        echo "$(jq "del(.inbounds[${inbound_num_tr}].transport.type, .inbounds[${inbound_num_tr}].transport.path, .inbounds[${inbound_num_vl}])" /etc/sing-box/config.json)" > /etc/sing-box/config.json
        echo "$(jq "del(.outbounds[${outbound_num}].transport.type, .outbounds[${outbound_num}].transport.path)" "/var/www/${subspath}/${user_key}-TRJ-CLIENT.json")" > "/var/www/${subspath}/${user_key}-TRJ-CLIENT.json"
    fi

    download_rule_sets
    systemctl restart sing-box.service
    systemctl enable sing-box.service
    echo ""
    systemctl status sing-box.service --no-pager -l -n 5
    echo ""
}

for_nginx_options() {
    if [[ "$variant" == "1" ]] && [[ ! $option =~ ^(2|3|4)$ ]]
    then
        touch /etc/nginx/.htpasswd
    fi

    if [[ "$option" == "3" ]]
    then
        wget -P /var/www --mirror --convert-links --adjust-extension --page-requisites --no-parent -T 1500 "https://${site_link}"
        local site_dir_root=$(echo "${site_link}" | cut -d "/" -f 1)
        chmod -R 755 "/var/www/${site_dir_root}"
        mkdir ./testdir
        wget -q -P ./testdir -T 30 "https://${site_link}"
        index=$(ls ./testdir)
        rm -rf ./testdir
        local search_name found_index_path

        for search_name in "$index" '*.htm*'
        do
            found_index_path=$(find "/var/www/${site_dir_root}" -name "${search_name}" -type f -printf "%d %p\n" | sort -n | head -n 1 | cut -d " " -f 2-)
            [[ -n $found_index_path ]] && [[ "$search_name" == "$index" ]] && break
            index=$(echo "${found_index_path}" | rev | cut -d "/" -f 1 | rev)
        done

        [[ -z $found_index_path ]] && found_index_path="/var/www/${site_dir_root}/index.html"
        [[ -z $index ]] && index="index.html"
        site_dir=${found_index_path%"/${index}"}
        site_dir=${site_dir#"/var/www/"}
        echo ""
    fi

    if [[ "$option" == "4" ]]
    then
        local site_dir_root=$(echo "${index_path}" | cut -d "/" -f 2)
        mv -f "/root/${site_dir_root}" /var/www
        chmod -R 755 "/var/www/${site_dir_root}"
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
worker_rlimit_nofile 131070;

# Load modules
include              /etc/nginx/modules-enabled/*.conf;

events {
    multi_accept       on;
    worker_connections 65535;
}

http {
    sendfile                      on;
    tcp_nopush                    on;
    tcp_nodelay                   on;
    server_tokens                 off;
    types_hash_max_size           2048;
    types_hash_bucket_size        64;
    server_names_hash_bucket_size 128;
    client_max_body_size          16M;

    # Timeout
    keepalive_timeout             60s;
    keepalive_requests            1000;
    reset_timedout_connection     on;

    # Rate limit for the subscription path
    limit_req_zone                \$binary_remote_addr zone=limit_sub:1m rate=60r/m;

    # MIME
    include                       mime.types;
    default_type                  application/octet-stream;

    # Logging
    access_log                    off;
    error_log                     /dev/null;

    # File cache
    open_file_cache               max=10000 inactive=60s;
    open_file_cache_valid         120s;
    open_file_cache_min_uses      2;
    open_file_cache_errors        on;

    # SSL
    ssl_session_timeout           1d;
    ssl_session_cache             shared:SSL:10m;
    ssl_session_tickets           off;

    # Mozilla Intermediate configuration
    ssl_protocols                 TLSv1.2 TLSv1.3;
    ssl_ciphers                   TLS13_AES_128_GCM_SHA256:TLS13_AES_256_GCM_SHA384:TLS13_CHACHA20_POLY1305_SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305;

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
        add_header_inherit merge;
        proxy_hide_header X-Powered-By;

        # . files
        location ~ ^/\.(?!well-known) {
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
worker_rlimit_nofile 131070;

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
    error_log                 /dev/null;

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
        add_header_inherit merge;
        proxy_hide_header X-Powered-By;

        # . files
        location ~ ^/\.(?!well-known) {
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
    local -A sn_message=()
    sn_message[1_ru]="${textcolor_light}Настройка NGINX...${clear}"
    sn_message[1_en]="${textcolor_light}Setting up NGINX...${clear}"

    echo -e "${sn_message[1_$language]}"
    for_nginx_options

    if [[ "$variant" == "1" ]]
    then
        local append='~^(,[ \\t]*)*([!#$%&'\''*+.^_`|~0-9A-Za-z-]+=([!#$%&'\''*+.^_`|~0-9A-Za-z-]+|\"([\\t \\x21\\x23-\\x5B\\x5D-\\x7E\\x80-\\xFF]|\\\\[\\t \\x21-\\x7E\\x80-\\xFF])*\"))?(;([!#$%&'\''*+.^_`|~0-9A-Za-z-]+=([!#$%&'\''*+.^_`|~0-9A-Za-z-]+|\"([\\t \\x21\\x23-\\x5B\\x5D-\\x7E\\x80-\\xFF]|\\\\[\\t \\x21-\\x7E\\x80-\\xFF])*\"))?)*([ \\t]*,([ \\t]*([!#$%&'\''*+.^_`|~0-9A-Za-z-]+=([!#$%&'\''*+.^_`|~0-9A-Za-z-]+|\"([\\t \\x21\\x23-\\x5B\\x5D-\\x7E\\x80-\\xFF]|\\\\[\\t \\x21-\\x7E\\x80-\\xFF])*\"))?(;([!#$%&'\''*+.^_`|~0-9A-Za-z-]+=([!#$%&'\''*+.^_`|~0-9A-Za-z-]+|\"([\\t \\x21\\x23-\\x5B\\x5D-\\x7E\\x80-\\xFF]|\\\\[\\t \\x21-\\x7E\\x80-\\xFF])*\"))?)*)?)*$'
        nginx_config_1
    else
        nginx_config_2
    fi

    nginx -t
    systemctl restart nginx.service
    systemctl enable nginx.service
    echo ""
    systemctl status nginx.service --no-pager -l -n 5
    echo ""
}

auth_lua() {
cat > /etc/haproxy/auth.lua <<EOF
local passwords = {
    ["${pass_hash}"] = true,    -- User '${user_key}'
    ["${placeholder}"] = false    -- Placeholder (do not remove)
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
        ${comment_0}tune.lua.bool-sample-conversion normal
        lua-load /etc/haproxy/auth.lua
        chroot /var/lib/haproxy
        stats socket /run/haproxy/admin.sock mode 660 level admin
        stats timeout 30s
        maxconn 5000
        user haproxy
        group haproxy
        daemon

        # Mozilla Intermediate
        ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305
        ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        ssl-default-bind-options prefer-client-ciphers no-sslv3 no-tlsv10 no-tlsv11 no-tls-tickets
        ssl-default-server-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305
        ssl-default-server-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        ssl-default-server-options no-sslv3 no-tlsv10 no-tlsv11 no-tls-tickets

        # Mozilla Modern
        # ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        # ssl-default-bind-options prefer-client-ciphers no-sslv3 no-tlsv10 no-tlsv11 no-tlsv12 no-tls-tickets
        # ssl-default-server-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        # ssl-default-server-options no-sslv3 no-tlsv10 no-tlsv11 no-tlsv12 no-tls-tickets

        # DH parameters
        ssl-dh-param-file /etc/haproxy/dhparam.pem

defaults
        mode http
        log global
        option tcplog
        option dontlognull
        timeout connect 5s
        timeout client  50s
        timeout server  50s

frontend haproxy-tls
        mode tcp
        timeout client 1h
        bind :::443 v4v6 ssl crt /etc/haproxy/certs/${domain}.pem alpn h2,http/1.1
        tcp-request inspect-delay 5s
        tcp-request content accept if { req_ssl_hello_type 1 }
        tcp-request content set-var(txn.trojan_backend) lua.trojan_auth

        # Backend rules
        use_backend reject if !{ ssl_fc_has_sni }
        use_backend reject if !{ ssl_fc_sni -i ${domain} } !{ ssl_fc_sni -m end .${domain} }
        use_backend trojan if { var(txn.trojan_backend) -m str trojan }
        ${comment_3}use_backend http-sub if { path_beg /${subspath}/ } || { path_beg /${rulesetpath}/ }
        default_backend http-main

backend trojan
        mode tcp
        timeout server 1h
        server sing-box 127.0.0.1:10443

backend http-main
        mode http
        ${comment_2}${comment_3}http-request auth unless { http_auth(mycredentials) }
        ${comment_1}${comment_3}http-request redirect code 301 location https://${redirect}%[path]
        ${comment_1}${comment_2}server nginx 127.0.0.1:11443

${comment_3}backend http-sub
        ${comment_3}mode http
        ${comment_3}server nginx 127.0.0.1:11443

backend reject
        mode http
        http-request deny

${comment_2}${comment_3}userlist mycredentials
EOF
}

setup_haproxy() {
    local -A sh_message=()
    sh_message[1_ru]="${textcolor_light}Настройка HAProxy...${clear}"
    sh_message[1_en]="${textcolor_light}Setting up HAProxy...${clear}"

    if [[ "$variant" != "1" ]]
    then
        echo -e "${sh_message[1_$language]}"
        local pass_hash=$(echo -n "${trjpass}" | openssl dgst -sha224 | sed 's/.* //')
        local placeholder=$(openssl rand -hex 28)
        auth_lua

        mkdir -p /etc/haproxy/certs
        cat "/etc/letsencrypt/live/${domain}/fullchain.pem" "/etc/letsencrypt/live/${domain}/privkey.pem" > "/etc/haproxy/certs/${domain}.pem"
        local haproxy_ver=$(haproxy -v | head -n 1 | cut -d " " -f 3)
        [[ $(echo -e "${haproxy_ver}\n3.2" | sort -V | head -n 1) != "3.2" ]] && local comment_0="# "
        haproxy_config

        haproxy -f /etc/haproxy/haproxy.cfg -c
        systemctl restart haproxy.service
        systemctl enable haproxy.service
        echo ""
        systemctl status haproxy.service --no-pager -l -n 5
        echo ""
    fi
}

setup_crontab() {
    local -A sc_message=()
    sc_message[1_ru]="${textcolor_light}Настройка crontab...${clear}"
    sc_message[1_en]="${textcolor_light}Setting up crontab...${clear}"

    echo -e "${sc_message[1_$language]}"
    local certbot_command="ufw allow 80 && certbot -q renew; ufw delete allow 80"
    [[ "$validation_type" == "1" ]] && certbot_command="certbot -q renew"

	crontab - <<-EOF
	PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
	@reboot sleep 5 && sysctl --system
	0 2 * * * ${certbot_command}
	10 2 * * * rsupdate
	EOF

    crontab -l
    echo ""
}

add_sbmanager() {
    local -A as_message=()
    as_message[1_ru]="${textcolor_light}Добавление меню настроек...${clear}"
    as_message[1_en]="${textcolor_light}Adding settings menu...${clear}"

    echo -e "${as_message[1_$language]}"
    wget -O /usr/local/bin/sbmanager -T 30 https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Scripts/sb-manager.sh
    chmod +x /usr/local/bin/sbmanager
    echo "alias ssb='/usr/local/bin/sbmanager'" >> /etc/bash.bashrc
    echo "alias sudo='sudo '" >> /etc/bash.bashrc
}

add_sub_page() {
    local -A asp_message=()
    asp_message[1_ru]="${textcolor_light}Добавление страницы подписок...${clear}"
    asp_message[1_en]="${textcolor_light}Adding subscription page...${clear}"

    echo -e "${asp_message[1_$language]}"
    local data_vrnt="both"
    [[ "$variant" != "1" ]] && data_vrnt="novless"
    wget -P "/var/www/${subspath}" -T 30 https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Subscription-Page/sub.html
    wget -P "/var/www/${subspath}" -T 30 https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Subscription-Page/background.jpg
    sed -i -e "s/DOMAIN/${domain}/g" -e "s/SUBSCRIPTION-PATH/${subspath}/g" -e "s/html lang=\"en\" data-vrnt=\"both\"/html lang=\"${language}\" data-vrnt=\"${data_vrnt}\"/g" "/var/www/${subspath}/sub.html"
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
"start_text_${language}"
get_ip
"enter_data_${language}"
enable_bbr
install_packages
setup_general_security
certificates
setup_warp
setup_sing_box
setup_nginx
setup_haproxy
setup_crontab
add_sbmanager
add_sub_page
"final_text_${language}"
