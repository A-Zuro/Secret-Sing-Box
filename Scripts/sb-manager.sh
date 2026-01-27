#!/bin/bash

textcolor='\033[1;36m'
red='\033[1;31m'
grey='\033[1;30m'
clear='\033[0m'

check_root() {
    if [[ $EUID -ne 0 ]]
    then
        echo ""
        echo -e "${red}Error: this command should be run as root, use \"sudo -i\" command first${clear}"
        echo ""
        exit 1
    fi
}

check_config_json() {
    if [[ ! -s /etc/sing-box/config.json ]] || ! jq empty /etc/sing-box/config.json &> /dev/null
    then
        echo ""
        echo -e "${red}Error: /etc/sing-box/config.json is corrupted, corrections needed${clear}"
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

templates() {
    wget -q -O /var/www/${subspath}/template.json.1 https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Config-Templates/client.json

    if [[ $? -eq 0 ]]
    then
        outbound_num=$(jq '[.outbounds[].tag] | index("proxy")' /var/www/${subspath}/template.json.1)

        if [[ $(jq -r '.inbounds[] | select(.tag == "trojan-in") | .transport.type' /etc/sing-box/config.json) == "ws" ]]
        then
            mv -f /var/www/${subspath}/template.json.1 /var/www/${subspath}/template.json
        elif [[ $(jq -r '.inbounds[] | select(.tag == "trojan-in") | .transport.type' /etc/sing-box/config.json) == "httpupgrade" ]]
        then
            echo "$(jq ".outbounds[${outbound_num}].transport.type = \"httpupgrade\"" /var/www/${subspath}/template.json.1)" > /var/www/${subspath}/template.json
            rm -f /var/www/${subspath}/template.json.1
        else
            echo "$(jq "del(.outbounds[${outbound_num}].transport.type, .outbounds[${outbound_num}].transport.path)" /var/www/${subspath}/template.json.1)" > /var/www/${subspath}/template.json
            rm -f /var/www/${subspath}/template.json.1
        fi
    fi

    if [[ ! -f /var/www/${subspath}/template-loc.json ]] && [[ -s /var/www/${subspath}/template.json ]] && jq empty /var/www/${subspath}/template.json &> /dev/null
    then
        cp /var/www/${subspath}/template.json /var/www/${subspath}/template-loc.json
    fi
}

get_ip() {
    server_ip=$(curl -s https://cloudflare.com/cdn-cgi/trace | grep "ip" | cut -d "=" -f 2)
    [[ ! $server_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && server_ip=$(curl -s ipinfo.io/ip)
    [[ ! $server_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && server_ip=$(curl -s 2ip.io)
}

get_data() {
    if [[ -f /etc/haproxy/auth.lua ]]
    then
        domain=$(grep "/etc/haproxy/certs/" /etc/haproxy/haproxy.cfg | head -n 1 | cut -d "/" -f 5)
        domain=${domain%".pem"*}
    else
        domain=$(grep "ssl_certificate" /etc/nginx/nginx.conf | head -n 1 | cut -d "/" -f 5)
        trojanpath=$(jq -r '.inbounds[] | select(.tag == "trojan-in") | .transport.path' /etc/sing-box/config.json | cut -d "/" -f 2)
        vlesspath=$(jq -r '.inbounds[] | select(.tag == "vless-in") | .transport.path' /etc/sing-box/config.json | cut -d "/" -f 2)
    fi

    subspath=$(grep "location ~ ^/" /etc/nginx/nginx.conf | head -n 1 | cut -d "/" -f 2 | cut -d " " -f 1)
    rulesetpath=$(grep "alias /var/www/" /etc/nginx/nginx.conf | head -n 1 | cut -d "/" -f 4)

    get_ip
    templates

    temprulesetpath=$(jq -r '.route.rule_set[-1].url' /var/www/${subspath}/template.json 2> /dev/null | cut -d "/" -f 4)
    tempdomain=$(jq -r '.outbounds[] | select(.tag == "proxy") | .server' /var/www/${subspath}/template.json 2> /dev/null)
    tempip=$(jq -r '.route.rules[] | select(has("ip_cidr")) | .ip_cidr[0]' /var/www/${subspath}/template.json 2> /dev/null)

    language="en"
    grep -q 'html lang="ru"' /var/www/${subspath}/sub.html &> /dev/null && language="ru"
}

check_github_template() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: не удалось загрузить данные с GitHub, попробуйте позже${clear}"
    check_message[1_en]="${red}Error: failed to download data from GitHub, try again later${clear}"

    if [[ ! -s /var/www/${subspath}/template.json ]] || ! jq empty /var/www/${subspath}/template.json &> /dev/null
    then
        echo -e "${check_message[1_$language]}"
        echo ""
        main_menu
    fi

    return 0
}

check_local_template() {
    declare -A -g general_message=()
    general_message[1_ru]="${red}Ошибка: структура template-loc.json нарушена, требуются исправления${clear}"
    general_message[2_ru]="${textcolor}[?]${clear} Введите ${textcolor}reset${clear}, чтобы сбросить шаблон до исходной версии, или введите ${textcolor}x${clear}, чтобы выйти:"
    general_message[3_ru]="Шаблон сброшен до исходной версии"
    general_message[1_en]="${red}Error: template-loc.json is corrupted, corrections needed${clear}"
    general_message[2_en]="${textcolor}[?]${clear} Enter ${textcolor}reset${clear} to reset the template to default version or enter ${textcolor}x${clear} to exit:"
    general_message[3_en]="The template has been reset to its default version"

    if [[ ! -s /var/www/${subspath}/template-loc.json ]] || ! jq empty /var/www/${subspath}/template-loc.json &> /dev/null || [[ $(jq 'any(.inbounds[]; .tag == "tun-in")' /var/www/${subspath}/template-loc.json) != "true" ]] || [[ $(jq 'any(.outbounds[]; .tag == "proxy")' /var/www/${subspath}/template-loc.json) != "true" ]]
    then
        echo -e "${general_message[1_$language]}"
        echo ""
        echo -e "${general_message[2_$language]}"
        read -r reset_temp
        [[ -n $reset_temp ]] && echo ""

        if [[ "$reset_temp" == "reset" ]]
        then
            check_github_template
            cp -f /var/www/${subspath}/template.json /var/www/${subspath}/template-loc.json
            echo "${general_message[3_$language]}"
            echo ""
        fi

        main_menu
    fi
}

### OPTION 1 - SHOW USERS ###

show_users() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor}Количество пользователей:${clear}"
    info_message[1_en]="${textcolor}Number of users:${clear}"

    user_num=$(ls -A1 /var/www/${subspath} | grep "\-TRJ-CLIENT.json" | wc -l)
    echo -e "${info_message[1_$language]} ${user_num}"
    ls -A1 /var/www/${subspath} | grep "\-CLIENT.json" | sed -e "s/-TRJ-CLIENT\.json//g" -e "s/-VLESS-CLIENT\.json//g" | uniq
    echo ""
    main_menu
}

### OPTION 2 - ADD USERS ###

exit_username() {
    if [[ ${username,,} =~ ^(x|х)$ ]]
    then
        username=""
        main_menu
    fi
}

check_username_add() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: имя пользователя должно содержать только английские буквы, цифры, символы _ и -${clear}"
    check_message[2_ru]="${red}Ошибка: пользователь с таким именем уже существует${clear}"
    check_message[3_ru]="${textcolor}[?]${clear} Введите имя нового пользователя или введите ${textcolor}x${clear}, чтобы закончить:"
    check_message[1_en]="${red}Error: the username should contain only letters, numbers, _ and - symbols${clear}"
    check_message[2_en]="${red}Error: this user already exists${clear}"
    check_message[3_en]="${textcolor}[?]${clear} Enter the name of the new user or enter ${textcolor}x${clear} to exit:"

    while [[ ! $username =~ ^[a-zA-Z0-9_-]+$ ]] || [[ -f /var/www/${subspath}/${username}-TRJ-CLIENT.json ]] || [[ $(jq "any(.inbounds[].users[]; .name == \"${username}\")" /etc/sing-box/config.json) != "false" ]]
    do
        if [[ -z $username ]]
        then
            :
        elif [[ ! $username =~ ^[a-zA-Z0-9_-]+$ ]]
        then
            echo -e "${check_message[1_$language]}"
            echo ""
        else
            echo -e "${check_message[2_$language]}"
            echo ""
        fi
        echo -e "${check_message[3_$language]}"
        read -r username
        [[ -n $username ]] && echo ""
        exit_username
    done
}

check_trjpass() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: пароль Trojan не должен содержать кавычки \"${clear}"
    check_message[2_ru]="${red}Ошибка: этот пароль уже закреплён за другим пользователем${clear}"
    check_message[3_ru]="${textcolor}[?]${clear} Введите пароль для Trojan или оставьте пустым для генерации случайного пароля:"
    check_message[1_en]="${red}Error: Trojan password should not contain quotes \"${clear}"
    check_message[2_en]="${red}Error: this password is already assigned to another user${clear}"
    check_message[3_en]="${textcolor}[?]${clear} Enter the password for Trojan or leave this empty to generate a random password:"

    while ([[ $trjpass =~ '"' ]] || [[ $(jq "any(.inbounds[].users[]; .password == \"${trjpass}\")" /etc/sing-box/config.json) != "false" ]]) && [[ -n $trjpass ]]
    do
        if [[ $trjpass =~ '"' ]]
        then
            echo -e "${check_message[1_$language]}"
        else
            echo -e "${check_message[2_$language]}"
        fi
        echo ""
        echo -e "${check_message[3_$language]}"
        read -r trjpass
        [[ -n $trjpass ]] && echo ""
    done
}

check_uuid() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: введённое значение не является UUID${clear}"
    check_message[2_ru]="${red}Ошибка: этот UUID уже закреплён за другим пользователем${clear}"
    check_message[3_ru]="${textcolor}[?]${clear} Введите UUID для VLESS или оставьте пустым для генерации случайного UUID:"
    check_message[1_en]="${red}Error: this is not an UUID${clear}"
    check_message[2_en]="${red}Error: this UUID is already assigned to another user${clear}"
    check_message[3_en]="${textcolor}[?]${clear} Enter the UUID for VLESS or leave this empty to generate a random UUID:"

    while ([[ ! $uuid =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]] || [[ $(jq "any(.inbounds[].users[]; .uuid == \"${uuid}\")" /etc/sing-box/config.json) != "false" ]]) && [[ -n $uuid ]]
    do
        if [[ ! $uuid =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]]
        then
            echo -e "${check_message[1_$language]}"
        else
            echo -e "${check_message[2_$language]}"
        fi
        echo ""
        echo -e "${check_message[3_$language]}"
        read -r uuid
        [[ -n $uuid ]] && echo ""
    done
}

enter_user_data_add() {
    declare -A -g input_message=()
    input_message[1_ru]="${textcolor}[?]${clear} Введите имя нового пользователя или введите ${textcolor}x${clear}, чтобы закончить:"
    input_message[2_ru]="${textcolor}[?]${clear} Введите пароль для Trojan или оставьте пустым для генерации случайного пароля:"
    input_message[3_ru]="${textcolor}[?]${clear} Введите UUID для VLESS или оставьте пустым для генерации случайного UUID:"
    input_message[1_en]="${textcolor}[?]${clear} Enter the name of the new user or enter ${textcolor}x${clear} to exit:"
    input_message[2_en]="${textcolor}[?]${clear} Enter the password for Trojan or leave this empty to generate a random password:"
    input_message[3_en]="${textcolor}[?]${clear} Enter the UUID for VLESS or leave this empty to generate a random UUID:"

    echo -e "${input_message[1_$language]}"
    read -r username
    [[ -n $username ]] && echo ""
    exit_username
    check_username_add
    echo -e "${input_message[2_$language]}"
    read -r trjpass
    [[ -n $trjpass ]] && echo ""
    check_trjpass
    if [[ ! -f /etc/haproxy/auth.lua ]]
    then
        echo -e "${input_message[3_$language]}"
        read -r uuid
        [[ -n $uuid ]] && echo ""
        check_uuid
    fi
}

generate_pass() {
    [[ -z $trjpass ]] && trjpass=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30)
    [[ -z $uuid ]] && [[ ! -f /etc/haproxy/auth.lua ]] && uuid=$(cat /proc/sys/kernel/random/uuid)
}

add_to_server_conf() {
    for inbound_tag in 'trojan-in' 'vless-in'
    do
        [[ "$inbound_tag" == "vless-in" ]] && [[ -f /etc/haproxy/auth.lua ]] && break
        inbound_num=$(jq "[.inbounds[].tag] | index(\"${inbound_tag}\")" /etc/sing-box/config.json)
        user_cred="{\"name\":\"${username}\",\"password\":\"${trjpass}\"}"
        [[ "$inbound_tag" == "vless-in" ]] && user_cred="{\"name\":\"${username}\",\"uuid\":\"${uuid}\"}"
        echo "$(jq ".inbounds[${inbound_num}].users += [${user_cred}]" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    done

    systemctl reload sing-box.service
}

add_to_client_conf() {
    declare -A -g info_message=()
    info_message[1_ru]="Пользователь ${textcolor}${username}${clear} добавлен:"
    info_message[1_en]="Added user ${textcolor}${username}${clear}:"

    cp -f /var/www/${subspath}/template.json /var/www/${subspath}/${username}-TRJ-CLIENT.json
    sed -i -e "s/${tempdomain}/${domain}/g" -e "s/${tempip}/${server_ip}/g" -e "s/${temprulesetpath}/${rulesetpath}/g" /var/www/${subspath}/${username}-TRJ-CLIENT.json
    outbound_num=$(jq '[.outbounds[].tag] | index("proxy")' /var/www/${subspath}/${username}-TRJ-CLIENT.json)

    if [[ -f /etc/haproxy/auth.lua ]]
    then
        echo "$(jq ".outbounds[${outbound_num}].password = \"${trjpass}\"" /var/www/${subspath}/${username}-TRJ-CLIENT.json)" > /var/www/${subspath}/${username}-TRJ-CLIENT.json
    else
        echo "$(jq ".outbounds[${outbound_num}].password = \"${trjpass}\" | .outbounds[${outbound_num}].transport.path = \"/${trojanpath}\"" /var/www/${subspath}/${username}-TRJ-CLIENT.json)" > /var/www/${subspath}/${username}-TRJ-CLIENT.json
        echo "$(jq ".outbounds[${outbound_num}].type = \"vless\" | .outbounds[${outbound_num}] |= with_entries(.key |= if . == \"password\" then \"uuid\" else . end) | .outbounds[${outbound_num}].uuid = \"${uuid}\" | .outbounds[${outbound_num}].transport.path = \"/${vlesspath}\"" /var/www/${subspath}/${username}-TRJ-CLIENT.json)" > /var/www/${subspath}/${username}-VLESS-CLIENT.json
    fi

    echo -e "${info_message[1_$language]}"
    echo "https://${domain}/${subspath}/${username}-TRJ-CLIENT.json"
    [[ ! -f /etc/haproxy/auth.lua ]] && echo "https://${domain}/${subspath}/${username}-VLESS-CLIENT.json"
    echo ""
}

add_to_auth_lua() {
    if [[ -f /etc/haproxy/auth.lua ]]
    then
        pass_hash=$(echo -n "${trjpass}" | openssl dgst -sha224 | sed 's/.* //')
        sed -i "2i \ \ \ \ [\"${pass_hash}\"] = true," /etc/haproxy/auth.lua
        systemctl reload haproxy.service
    fi
}

add_users() {
    check_github_template

    while [[ ! ${username,,} =~ ^(x|х)$ ]]
    do
        enter_user_data_add
        generate_pass
        add_to_auth_lua
        add_to_server_conf
        add_to_client_conf
    done
}

### OPTION 3 - DELETE USERS ###

check_username_del() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: пользователь с таким именем не существует${clear}"
    check_message[2_ru]="${textcolor}[?]${clear} Введите имя пользователя или введите ${textcolor}x${clear}, чтобы закончить:"
    check_message[1_en]="${red}Error: a user with this name does not exist${clear}"
    check_message[2_en]="${textcolor}[?]${clear} Enter the name of the user or enter ${textcolor}x${clear} to exit:"

    while [[ -z $username ]] || [[ $(jq "any(.inbounds[].users[]; .name == \"${username}\")" /etc/sing-box/config.json) != "true" ]]
    do
        if [[ -n $username ]]
        then
            echo -e "${check_message[1_$language]}"
            echo ""
        fi
        echo -e "${check_message[2_$language]}"
        read -r username
        [[ -n $username ]] && echo ""
        exit_username
    done
}

enter_user_data_del() {
    declare -A -g input_message=()
    input_message[1_ru]="${textcolor}[?]${clear} Введите имя пользователя или введите ${textcolor}x${clear}, чтобы закончить:"
    input_message[1_en]="${textcolor}[?]${clear} Enter the name of the user or enter ${textcolor}x${clear} to exit:"

    echo -e "${input_message[1_$language]}"
    read -r username
    [[ -n $username ]] && echo ""
    exit_username
    check_username_del
}

del_from_conf() {
    declare -A -g info_message=()
    info_message[1_ru]="Пользователь ${textcolor}${username}${clear} удалён"
    info_message[1_en]="Deleted user ${textcolor}${username}${clear}"

    echo "$(jq "del(.inbounds[].users[] | select(.name == \"${username}\"))" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    systemctl reload sing-box.service

    rm -f /var/www/${subspath}/${username}-TRJ-CLIENT.json /var/www/${subspath}/${username}-VLESS-CLIENT.json
    echo -e "${info_message[1_$language]}"
    echo ""
}

del_from_auth_lua() {
    if [[ -f /etc/haproxy/auth.lua ]]
    then
        trjpass=$(jq -r ".inbounds[].users[] | select(.name == \"${username}\") | .password" /etc/sing-box/config.json)
        pass_hash=$(echo -n "${trjpass}" | openssl dgst -sha224 | sed 's/.* //')
        sed -i "/${pass_hash}/d" /etc/haproxy/auth.lua
        systemctl reload haproxy.service
    fi
}

delete_users() {
    while [[ ! ${username,,} =~ ^(x|х)$ ]]
    do
        enter_user_data_del
        del_from_auth_lua
        del_from_conf
    done
}

### OPTION 4 - CHANGE STACK VALUE ###

get_stack_sel() {
    declare -A -g info_message=()
    info_message[1_ru]="[Выбрано]"
    info_message[1_en]="[Selected]"

    stack_sel_1=""; stack_sel_2=""; stack_sel_3=""
    current_stack=$(jq -r '.inbounds[] | select(.tag == "tun-in") | .stack' /var/www/${subspath}/${username}-TRJ-CLIENT.json)

    case $current_stack in
        system)
        stack_sel_1="${info_message[1_$language]}"
        ;;
        gvisor)
        stack_sel_2="${info_message[1_$language]}"
        ;;
        mixed)
        stack_sel_3="${info_message[1_$language]}"
    esac
}

stack_text_ru() {
    echo -e "${textcolor}[?]${clear} Выберите \"stack\" для пользователя ${textcolor}${username}${clear}:"
    echo "0 - Выйти"
    echo "1 - \"system\" (системный стек, лучшая производительность, значение по умолчанию)    ${stack_sel_1}"
    echo "2 - \"gvisor\" (запускается в userspace, рекомендуется, если не работает \"system\")   ${stack_sel_2}"
    echo "3 - \"mixed\" (смешанный вариант: \"system\" для TCP, \"gvisor\" для UDP)                ${stack_sel_3}"
    read -r stack_option
    [[ -n $stack_option ]] && echo ""
}

stack_text_en() {
    echo -e "${textcolor}[?]${clear} Select \"stack\" value for the user ${textcolor}${username}${clear}:"
    echo "0 - Exit"
    echo "1 - \"system\" (system stack, the best performance, default value)             ${stack_sel_1}"
    echo "2 - \"gvisor\" (runs in userspace, is recommended if \"system\" isn't working)   ${stack_sel_2}"
    echo "3 - \"mixed\" (mixed variant: \"system\" for TCP, \"gvisor\" for UDP)              ${stack_sel_3}"
    read -r stack_option
    [[ -n $stack_option ]] && echo ""
}

edit_configs_stack() {
    declare -A -g info_message=()
    info_message[1_ru]="Изменение \"stack\" у пользователя ${textcolor}${username}${clear} завершено, для применения новых настроек обновите конфиг на клиенте"
    info_message[1_en]="The \"stack\" value for the user ${textcolor}${username}${clear} has been changed, update the config on the client app to apply new settings"

    case $stack_option in
        1)
        new_stack="system"
        ;;
        2)
        new_stack="gvisor"
        ;;
        3)
        new_stack="mixed"
        ;;
        *)
        main_menu
    esac

    for protocol in 'TRJ' 'VLESS'
    do
        [[ "$protocol" == "VLESS" ]] && [[ -f /etc/haproxy/auth.lua ]] && break
        inbound_num=$(jq '[.inbounds[].tag] | index("tun-in")' /var/www/${subspath}/${username}-${protocol}-CLIENT.json)
        echo "$(jq ".inbounds[${inbound_num}].stack = \"${new_stack}\"" /var/www/${subspath}/${username}-${protocol}-CLIENT.json)" > /var/www/${subspath}/${username}-${protocol}-CLIENT.json
    done

    echo -e "${info_message[1_$language]}"
    echo ""
}

change_stack() {
    while [[ ! ${username,,} =~ ^(x|х)$ ]]
    do
        enter_user_data_del
        get_stack_sel
        stack_text_${language}
        edit_configs_stack
    done
}

### OPTION 5 - SYNCHRONIZE SETTINGS IN CLIENT CONFIGS ###

exit_sync() {
    if [[ ${sync,,} =~ ^(x|х)$ ]]
    then
        sync=""
        main_menu
    fi
}

check_users() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: пользователи отсутствуют${clear}"
    check_message[1_en]="${red}Error: no users found${clear}"

    if [[ $(ls -A1 /var/www/${subspath} | grep "\-CLIENT.json" | wc -l) -eq 0 ]]
    then
        echo -e "${check_message[1_$language]}"
        echo ""
        main_menu
    fi
}

get_pass() {
    if grep -q ': "trojan"' ${file}
    then
        trjpass=$(jq -r '.outbounds[] | select(.tag == "proxy") | .password' ${file})
        uuid=""
    else
        uuid=$(jq -r '.outbounds[] | select(.tag == "proxy") | .uuid' ${file})
        trjpass=""
    fi

    stack=$(jq -r '.inbounds[] | select(.tag == "tun-in") | .stack' ${file})
    [[ $(jq '.outbounds[] | select(.tag == "proxy") | .transport | has("headers")' ${file}) == "true" ]] && cf_ip=$(jq -r '.outbounds[] | select(.tag == "proxy") | .server' ${file})
}

edit_configs_loop() {
    for file in /var/www/${subspath}/*-CLIENT.json
    do
        get_pass
        cp -f /var/www/${subspath}/${sync_template_file} ${file}

        if [[ "$sync_template_file" == "template.json" ]]
        then
            sed -i -e "s/${tempdomain}/${domain}/g" -e "s/${tempip}/${server_ip}/g" -e "s/${temprulesetpath}/${rulesetpath}/g" ${file}
        else
            sed -i -e "s/${loc_tempdomain}/${domain}/g" -e "s/${loc_tempip}/${server_ip}/g" -e "s/${loc_temprulesetpath}/${rulesetpath}/g" ${file}
        fi

        if [[ -f /etc/haproxy/auth.lua ]]
        then
            echo "$(jq ".inbounds[${inbound_num}].stack = \"${stack}\" | .outbounds[${outbound_num}].password = \"${trjpass}\"" ${file})" > ${file}
        elif [[ ! -f /etc/haproxy/auth.lua ]] && [[ -n $trjpass ]]
        then
            echo "$(jq ".inbounds[${inbound_num}].stack = \"${stack}\" | .outbounds[${outbound_num}].password = \"${trjpass}\" | .outbounds[${outbound_num}].transport.path = \"/${trojanpath}\"" ${file})" > ${file}
        else
            echo "$(jq ".inbounds[${inbound_num}].stack = \"${stack}\" | .outbounds[${outbound_num}].type = \"vless\" | .outbounds[${outbound_num}] |= with_entries(.key |= if . == \"password\" then \"uuid\" else . end) | .outbounds[${outbound_num}].uuid = \"${uuid}\" | .outbounds[${outbound_num}].transport.path = \"/${vlesspath}\"" ${file})" > ${file}
        fi

        [[ -n $cf_ip ]] && echo "$(jq ".outbounds[${outbound_num}].server = \"${cf_ip}\" | .outbounds[${outbound_num}].transport.headers |= {\"Host\":\"${domain}\"} | .route.rule_set[].download_detour = \"proxy\"" ${file})" > ${file}
        cf_ip=""
    done
}

add_rule_sets_loop() {
    for ruleset_ind in $(seq 0 $(jq '.route.rule_set | length - 1' /var/www/${subspath}/${sync_template_file}))
    do
        ruleset=$(jq -r ".route.rule_set[${ruleset_ind}].url" /var/www/${subspath}/${sync_template_file} | cut -d "/" -f 5)
        [[ ! -f /var/www/${rulesetpath}/${ruleset} ]] && wget -q -P /var/www/${rulesetpath} https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/${ruleset}
    done
}

sync_client_configs_main() {
    declare -A -g info_message=()
    info_message[1_ru]="Синхронизация настроек с GitHub завершена"
    info_message[1_en]="Synchronization of the settings with GitHub is completed"

    if [[ "$sync_template_file" == "template-loc.json" ]]
    then
        info_message[1_ru]="Синхронизация настроек с локальным шаблоном завершена"
        info_message[1_en]="Synchronization of the settings with local template is completed"

        loc_temprulesetpath=$(jq -r '.route.rule_set[-1].url // "missing_value"' /var/www/${subspath}/template-loc.json | cut -d "/" -f 4)
        loc_tempdomain=$(jq -r '.outbounds[] | select(.tag == "proxy") | .server' /var/www/${subspath}/template-loc.json)
        loc_tempip=$(jq -r '.route.rules[] | select(has("ip_cidr")) | .ip_cidr[0]' /var/www/${subspath}/template-loc.json)
        [[ -z $loc_tempip ]] && loc_tempip="missing_value"
    fi

    inbound_num=$(jq '[.inbounds[].tag] | index("tun-in")' /var/www/${subspath}/${sync_template_file})
    outbound_num=$(jq '[.outbounds[].tag] | index("proxy")' /var/www/${subspath}/${sync_template_file})
    edit_configs_loop

    if [[ $(jq '.route.rule_set | length' /var/www/${subspath}/${sync_template_file}) =~ ^[1-9][0-9]*$ ]]
    then
        add_rule_sets_loop
        chmod -R 755 /var/www/${rulesetpath}
    fi

    echo "${info_message[1_$language]}"
    echo ""
}

sync_github_text_ru() {
    echo -e "${red}ВНИМАНИЕ!${clear}"
    echo "Настройки в клиентских конфигах всех пользователей будут синхронизированы с последней версией на GitHub:"
    echo "https://github.com/A-Zuro/Secret-Sing-Box/blob/main/Config-Templates/client.json"
    echo ""
    echo -e "${textcolor}[?]${clear} Нажмите ${textcolor}Enter${clear}, чтобы синхронизировать настройки, или введите ${textcolor}x${clear}, чтобы выйти:"
    read -r sync
    [[ -n $sync ]] && echo ""
}

sync_github_text_en() {
    echo -e "${red}ATTENTION!${clear}"
    echo "The settings in client configs of all users will be synchronized with the latest version on GitHub:"
    echo "https://github.com/A-Zuro/Secret-Sing-Box/blob/main/Config-Templates/client.json"
    echo ""
    echo -e "${textcolor}[?]${clear} Press ${textcolor}Enter${clear} to synchronize the settings or enter ${textcolor}x${clear} to exit:"
    read -r sync
    [[ -n $sync ]] && echo ""
}

sync_local_text_ru() {
    echo -e "${red}ВНИМАНИЕ!${clear}"
    echo -e "Вы можете вручную отредактировать настройки в шаблоне ${textcolor}/var/www/${subspath}/template-loc.json${clear}"
    echo "Настройки в этом файле будут применены к клиентским конфигам всех пользователей"
    echo "При редактировании не меняйте значения \"tag\" у \"inbounds\" и \"outbounds\""
    echo ""
    echo -e "${textcolor}[?]${clear} Нажмите ${textcolor}Enter${clear}, чтобы синхронизировать настройки, или введите ${textcolor}x${clear}, чтобы выйти:"
    read -r sync
    [[ -n $sync ]] && echo ""
}

sync_local_text_en() {
    echo -e "${red}ATTENTION!${clear}"
    echo -e "You can manually edit the settings in ${textcolor}/var/www/${subspath}/template-loc.json${clear} template"
    echo "The settings in this file will be applied to client configs of all users"
    echo "Do not change \"tag\" values in \"inbounds\" and \"outbounds\" while editing"
    echo ""
    echo -e "${textcolor}[?]${clear} Press ${textcolor}Enter${clear} to synchronize the settings or enter ${textcolor}x${clear} to exit:"
    read -r sync
    [[ -n $sync ]] && echo ""
}

sync_text_ru() {
    echo -e "${textcolor}Выберите вариант синхронизации:${clear}"
    echo "0 - Выйти"
    echo "1 - Синхронизировать с GitHub"
    echo "2 - Синхронизировать с локальным шаблоном (свои настройки)"
    read -r sync_option
    [[ -n $sync_option ]] && echo ""
}

sync_text_en() {
    echo -e "${textcolor}Select synchronisation option:${clear}"
    echo "0 - Exit"
    echo "1 - Sync with GitHub"
    echo "2 - Sync with local template (custom settings)"
    read -r sync_option
    [[ -n $sync_option ]] && echo ""
}

sync_options() {
    case $sync_option in
        1)
        sync_variant="github"
        sync_template_file="template.json"
        ;;
        2)
        sync_variant="local"
        sync_template_file="template-loc.json"
        ;;
        *)
        main_menu
    esac
}

sync_client_configs() {
    sync_text_${language}
    sync_options
    sync_${sync_variant}_text_${language}
    exit_sync
    check_users
    check_${sync_variant}_template
    sync_client_configs_main
    main_menu
}

### OPTION 6 - SETUP CONNECTION TO CUSTOM CLOUDFLARE IP ###

check_variant() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: этот пункт только для вариантов настройки с транспортом WebSocket или HTTPUpgrade${clear}"
    check_message[1_en]="${red}Error: this option is only available for the setup variants with WebSocket or HTTPUpgrade transport${clear}"

    if [[ -f /etc/haproxy/auth.lua ]]
    then
        echo -e "${check_message[1_$language]}"
        echo ""
        main_menu
    fi
}

check_cf_option() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: IP Cloudflare итак не указан в конфиге этого пользователя${clear}"
    check_message[1_en]="${red}Error: the config file of this user does not contain Cloudflare IP anyway${clear}"

    while [[ "$cf_option" == "2" ]] && [[ $(jq '.outbounds[] | select(.tag == "proxy") | .transport | has("headers")' /var/www/${subspath}/${username}-TRJ-CLIENT.json) != "true" ]]
    do
        echo -e "${check_message[1_$language]}"
        echo ""
        cf_text_${language}
    done
}

check_cf_ip() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: введённое значение не является IP${clear}"
    check_message[2_ru]="${textcolor}[?]${clear} Введите выбранный IP Cloudflare:"
    check_message[1_en]="${red}Error: the entered value is not an IP${clear}"
    check_message[2_en]="${textcolor}[?]${clear} Enter the custom Cloudflare IP:"

    while [[ ! $cf_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
    do
        if [[ -n $cf_ip ]]
        then
            echo -e "${check_message[1_$language]}"
            echo ""
        fi
        echo -e "${check_message[2_$language]}"
        read -r cf_ip
        [[ -n $cf_ip ]] && echo ""
    done
}

enter_cf_ip() {
    declare -A -g input_message=()
    input_message[1_ru]="${textcolor}[?]${clear} Введите выбранный IP Cloudflare:"
    input_message[1_en]="${textcolor}[?]${clear} Enter the custom Cloudflare IP:"

    echo -e "${input_message[1_$language]}"
    read -r cf_ip
    [[ -n $cf_ip ]] && echo ""
    check_cf_ip
}

set_cf_ip() {
    declare -A -g info_message=()
    info_message[1_ru]="Изменение настроек для пользователя ${textcolor}${username}${clear} завершено, установлен IP ${textcolor}${cf_ip}${clear}"
    info_message[1_en]="Changed the settings for the user ${textcolor}${username}${clear}, IP ${textcolor}${cf_ip}${clear} has been set"

    for protocol in 'TRJ' 'VLESS'
    do
        outbound_num=$(jq '[.outbounds[].tag] | index("proxy")' /var/www/${subspath}/${username}-${protocol}-CLIENT.json)
        echo "$(jq ".outbounds[${outbound_num}].server = \"${cf_ip}\" | .outbounds[${outbound_num}].transport.headers |= {\"Host\":\"${domain}\"} | .route.rule_set[].download_detour = \"proxy\"" /var/www/${subspath}/${username}-${protocol}-CLIENT.json)" > /var/www/${subspath}/${username}-${protocol}-CLIENT.json
    done

    echo -e "${info_message[1_$language]}"
    cf_ip=""
    echo ""
}

remove_cf_ip() {
    declare -A -g info_message=()
    info_message[1_ru]="Изменение настроек для пользователя ${textcolor}${username}${clear} завершено, IP Cloudflare убран"
    info_message[1_en]="Changed the settings for the user ${textcolor}${username}${clear}, Cloudflare IP is removed"

    for protocol in 'TRJ' 'VLESS'
    do
        outbound_num=$(jq '[.outbounds[].tag] | index("proxy")' /var/www/${subspath}/${username}-${protocol}-CLIENT.json)
        echo "$(jq ".outbounds[${outbound_num}].server = \"${domain}\" | del(.outbounds[${outbound_num}].transport.headers, .route.rule_set[].download_detour)" /var/www/${subspath}/${username}-${protocol}-CLIENT.json)" > /var/www/${subspath}/${username}-${protocol}-CLIENT.json
    done

    echo -e "${info_message[1_$language]}"
    echo ""
}

get_cf_ip_status() {
    declare -A -g info_message=()
    info_message[1_ru]="[IP Cloudflare не выбран]"
    info_message[2_ru]="Выбрано:"
    info_message[1_en]="[Cloudflare IP is not selected]"
    info_message[2_en]="Selected:"

    sel_cf_ip=$(jq -r '.outbounds[] | select(.tag == "proxy") | .server' /var/www/${subspath}/${username}-TRJ-CLIENT.json)
    cf_ip_status="${info_message[1_$language]}"
    [[ $sel_cf_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && cf_ip_status="[${info_message[2_$language]} ${sel_cf_ip}]"
}

cf_warn_ru() {
    echo -e "${red}ВНИМАНИЕ!${clear}"
    echo "Этот пункт рекомендуется в случае недоступности IP, который Cloudflare выделил вашему домену для проксирования"
    echo "Нужно просканировать диапазоны IP Cloudflare с вашего устройства и самостоятельно выбрать оптимальный IP"
    echo "Инструкция: https://github.com/A-Zuro/Secret-Sing-Box/blob/main/.github/cf-scan-ip-ru.md"
    echo ""
}

cf_warn_en() {
    echo -e "${red}ATTENTION!${clear}"
    echo "This option is recommended in case of unavailability of the IP that Cloudflare allocated to your domain for proxying"
    echo "You need to scan Cloudflare IP ranges from your device and choose the optimal IP by yourself"
    echo "Instruction: https://github.com/A-Zuro/Secret-Sing-Box/blob/main/.github/cf-scan-ip-en.md"
    echo ""
}

cf_text_ru() {
    echo -e "${textcolor}[?]${clear} Выберите опцию для пользователя ${textcolor}${username}${clear}:"
    echo "0 - Выйти"
    echo "1 - Настроить/сменить выбранный IP Cloudflare   ${cf_ip_status}"
    echo "2 - Убрать выбранный IP Cloudflare"
    read -r cf_option
    [[ -n $cf_option ]] && echo ""
}

cf_text_en() {
    echo -e "${textcolor}[?]${clear} Select an option for the user ${textcolor}${username}${clear}:"
    echo "0 - Exit"
    echo "1 - Setup/change custom Cloudflare IP   ${cf_ip_status}"
    echo "2 - Remove custom Cloudflare IP"
    read -r cf_option
    [[ -n $cf_option ]] && echo ""
}

cf_ip_settings() {
    check_variant
    cf_warn_${language}

    while [[ ! ${username,,} =~ ^(x|х)$ ]]
    do
        enter_user_data_del
        get_cf_ip_status
        cf_text_${language}
        check_cf_option

        case $cf_option in
            1)
            enter_cf_ip
            set_cf_ip
            ;;
            2)
            remove_cf_ip
            ;;
            *)
            main_menu
        esac
    done
}

### OPTION 7 - SHOW WARP DOMAINS ###

check_warp() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: в /etc/sing-box/config.json не найдено правил маршрутизации для WARP${clear}"
    check_message[1_en]="${red}Error: no WARP routing rules found in /etc/sing-box/config.json${clear}"

    if [[ $(jq 'any(.route.rules[]; .outbound == "warp")' /etc/sing-box/config.json) != "true" ]]
    then
        echo -e "${check_message[1_$language]}"
        echo ""
        main_menu
    fi
}

show_warp_domains() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor}Список доменов/суффиксов WARP:${clear}"
    info_message[1_en]="${textcolor}List of domains/suffixes routed through WARP:${clear}"

    check_warp
    echo -e "${info_message[1_$language]}"
    jq -r '.route.rules[] | select(.outbound == "warp") | .domain_suffix[]' /etc/sing-box/config.json
    echo ""
    main_menu
}

### OPTION 8 - ADD WARP DOMAINS ###

exit_warp_add() {
    if [[ ${new_warp,,} =~ ^(x|х)$ ]]
    then
        new_warp=""
        main_menu
    fi
}

crop_new_warp() {
    new_warp=${new_warp#*"://"}
    new_warp=$(echo "${new_warp}" | cut -d "/" -f 1)
}

check_domain_warp_add() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: этот домен/суффикс уже добавлен в WARP${clear}"
    check_message[2_ru]="${textcolor}[?]${clear} Введите новый домен/суффикс для WARP или введите ${textcolor}x${clear}, чтобы закончить:"
    check_message[1_en]="${red}Error: this domain/suffix is already added to WARP${clear}"
    check_message[2_en]="${textcolor}[?]${clear} Enter a new domain/suffix for WARP routing or enter ${textcolor}x${clear} to exit:"

    while [[ -z $new_warp ]] || [[ $(jq "any(.route.rules[] | select(.outbound == \"warp\") | .domain_suffix[]; . == \"${new_warp}\")" /etc/sing-box/config.json) != "false" ]]
    do
        if [[ -n $new_warp ]]
        then
            echo -e "${check_message[1_$language]}"
            echo ""
        fi
        echo -e "${check_message[2_$language]}"
        read -r new_warp
        [[ -n $new_warp ]] && echo ""
        exit_warp_add
        crop_new_warp
    done
}

enter_domain_warp_add() {
    declare -A -g input_message=()
    input_message[1_ru]="${textcolor}[?]${clear} Введите новый домен/суффикс для WARP или введите ${textcolor}x${clear}, чтобы закончить:"
    input_message[1_en]="${textcolor}[?]${clear} Enter a new domain/suffix for WARP routing or enter ${textcolor}x${clear} to exit:"

    echo -e "${input_message[1_$language]}"
    read -r new_warp
    [[ -n $new_warp ]] && echo ""
    exit_warp_add
    crop_new_warp
    check_domain_warp_add
}

edit_conf_warp_add() {
    declare -A -g info_message=()
    info_message[1_ru]="Домен/суффикс ${textcolor}${new_warp}${clear} добавлен в WARP"
    info_message[1_en]="Domain/suffix ${textcolor}${new_warp}${clear} is added to WARP routing"

    warp_rule_num=$(jq '[.route.rules[].outbound] | index("warp")' /etc/sing-box/config.json)
    echo "$(jq ".route.rules[${warp_rule_num}].domain_suffix += [\"${new_warp}\"]" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    systemctl reload sing-box.service
    echo -e "${info_message[1_$language]}"
    echo ""
}

add_warp_domains() {
    check_warp

    while [[ ! ${new_warp,,} =~ ^(x|х)$ ]]
    do
        enter_domain_warp_add
        edit_conf_warp_add
    done
}

### OPTION 9 - DELETE WARP DOMAINS ###

exit_warp_del() {
    if [[ ${del_warp,,} =~ ^(x|х)$ ]]
    then
        del_warp=""
        main_menu
    fi
}

crop_del_warp() {
    del_warp=${del_warp#*"://"}
    del_warp=$(echo "${del_warp}" | cut -d "/" -f 1)
}

check_domain_warp_del() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: этот домен/суффикс не добавлен в WARP${clear}"
    check_message[2_ru]="${textcolor}[?]${clear} Введите домен/суффикс для удаления из WARP или введите ${textcolor}x${clear}, чтобы закончить:"
    check_message[1_en]="${red}Error: this domain/suffix is not added to WARP routing${clear}"
    check_message[2_en]="${textcolor}[?]${clear} Enter a domain/suffix to delete from WARP routing or enter ${textcolor}x${clear} to exit:"

    while [[ -z $del_warp ]] || [[ $(jq "any(.route.rules[] | select(.outbound == \"warp\") | .domain_suffix[]; . == \"${del_warp}\")" /etc/sing-box/config.json) != "true" ]]
    do
        if [[ -n $del_warp ]]
        then
            echo -e "${check_message[1_$language]}"
            echo ""
        fi
        echo -e "${check_message[2_$language]}"
        read -r del_warp
        [[ -n $del_warp ]] && echo ""
        exit_warp_del
        crop_del_warp
    done
}

enter_domain_warp_del() {
    declare -A -g input_message=()
    input_message[1_ru]="${textcolor}[?]${clear} Введите домен/суффикс для удаления из WARP или введите ${textcolor}x${clear}, чтобы закончить:"
    input_message[1_en]="${textcolor}[?]${clear} Enter a domain/suffix to delete from WARP routing or enter ${textcolor}x${clear} to exit:"

    echo -e "${input_message[1_$language]}"
    read -r del_warp
    [[ -n $del_warp ]] && echo ""
    exit_warp_del
    crop_del_warp
    check_domain_warp_del
}

edit_conf_warp_del() {
    declare -A -g info_message=()
    info_message[1_ru]="Домен/суффикс ${textcolor}${del_warp}${clear} удалён из WARP"
    info_message[1_en]="Domain/suffix ${textcolor}${del_warp}${clear} is deleted from WARP routing"

    warp_rule_num=$(jq '[.route.rules[].outbound] | index("warp")' /etc/sing-box/config.json)
    echo "$(jq "del(.route.rules[${warp_rule_num}].domain_suffix[] | select(. == \"${del_warp}\"))" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    systemctl reload sing-box.service
    echo -e "${info_message[1_$language]}"
    echo ""
}

delete_warp_domains() {
    check_warp

    while [[ ! ${del_warp,,} =~ ^(x|х)$ ]]
    do
        enter_domain_warp_del
        edit_conf_warp_del
    done
}

### OPTION 10 - SETUP PROXY CHAINS ###

exit_enter_next_link() {
    if [[ ${next_link,,} =~ ^(x|х)$ ]]
    then
        next_link=""
        main_menu
    fi
}

check_chain_option() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: этот сервер уже настроен как конечный в цепочке или единственный${clear}"
    check_message[1_en]="${red}Error: this server is already configured as the end of the chain or the only one${clear}"

    while [[ "$chain_option" == "1" ]] && [[ $(jq 'any(.outbounds[]; .tag == "proxy")' /etc/sing-box/config.json) != "true" ]]
    do
        echo -e "${check_message[1_$language]}"
        echo ""
        chain_text_${language}
    done
}

check_config_temp() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: не удалось загрузить данные с GitHub, попробуйте позже${clear}"
    check_message[1_en]="${red}Error: failed to download data from GitHub, try again later${clear}"

    if [[ -z $config_temp ]] || ! echo "${config_temp}" | jq empty &> /dev/null
    then
        echo -e "${check_message[1_$language]}"
        echo ""
        main_menu
    fi
}

check_next_link() {
    declare -A -g check_message=()
    check_message[1_ru]="${red}Ошибка: неверная ссылка на конфиг или следующий сервер не отвечает${clear}"
    check_message[2_ru]="${textcolor}[?]${clear} Введите ссылку на клиентский конфиг со следующего сервера в цепочке или введите ${textcolor}x${clear}, чтобы выйти:"
    check_message[1_en]="${red}Error: invalid link to client config or the next server does not respond${clear}"
    check_message[2_en]="${textcolor}[?]${clear} Enter the link to client config from the next server in the chain or enter ${textcolor}x${clear} to exit:"

    while [[ -z $next_link ]] || [[ -z $next_config ]] || ! echo "${next_config}" | jq empty &> /dev/null || [[ $(echo "${next_config}" | jq 'any(.outbounds[]; .tag == "proxy")') != "true" ]]
    do
        if [[ -n $next_link ]]
        then
            echo -e "${check_message[1_$language]}"
            echo ""
        fi
        echo -e "${check_message[2_$language]}"
        read -r next_link
        [[ -n $next_link ]] && echo ""
        exit_enter_next_link
        next_config=$(curl -s "${next_link}" 2> /dev/null)
    done
}

enter_chain_data() {
    declare -A -g input_message=()
    input_message[1_ru]="${textcolor}[?]${clear} Введите ссылку на клиентский конфиг со следующего сервера в цепочке или введите ${textcolor}x${clear}, чтобы выйти:"
    input_message[1_en]="${textcolor}[?]${clear} Enter the link to client config from the next server in the chain or enter ${textcolor}x${clear} to exit:"

    echo -e "${input_message[1_$language]}"
    read -r next_link
    [[ -n $next_link ]] && echo ""
    exit_enter_next_link
    next_config=$(curl -s "${next_link}" 2> /dev/null)
    check_next_link
}

manage_rule_sets() {
    for ruleset_tag in "${rule_sets_add[@]}"
    do
        if [[ $(jq "any(.route.rule_set[]; .tag == \"${ruleset_tag}\")" /etc/sing-box/config.json) == "false" ]]
        then
            ruleset_data="{\"tag\":\"${ruleset_tag}\",\"type\":\"local\",\"format\":\"binary\",\"path\":\"/var/www/${rulesetpath}/geosite-${ruleset_tag}.srs\"}"
            echo "$(jq ".route.rule_set += [${ruleset_data}]" /etc/sing-box/config.json)" > /etc/sing-box/config.json
        fi

        if [[ ! -f /var/www/${rulesetpath}/geosite-${ruleset_tag}.srs ]]
        then
            wget -q -P /var/www/${rulesetpath} https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-${ruleset_tag}.srs
        fi
    done

    for ruleset_tag in "${rule_sets_del[@]}"
    do
        if [[ $(jq "any(.route.rule_set[]; .tag == \"${ruleset_tag}\")" /etc/sing-box/config.json) == "true" ]]
        then
            echo "$(jq "del(.route.rule_set[] | select(.tag == \"${ruleset_tag}\"))" /etc/sing-box/config.json)" > /etc/sing-box/config.json
        fi
    done

    chmod -R 755 /var/www/${rulesetpath}
}

chain_end() {
    declare -A -g info_message=()
    info_message[1_ru]="Изменение настроек завершено, этот сервер настроен как конечный в цепочке или единственный"
    info_message[1_en]="Settings changed successfully, this server is configured as the end of the chain or the only one"

    if [[ $(jq 'any(.route.rules[]; .outbound == "warp")' /etc/sing-box/config.json) == "true" ]]
    then
        config_temp=$(curl -s https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Config-Templates/config.json)
        check_config_temp
        warp_rule=$(echo "${config_temp}" | jq '.route.rules[] | select(.outbound == "warp")')
        warp_rule_num=$(jq '[.route.rules[].outbound] | index("warp")' /etc/sing-box/config.json)
        echo "$(jq ".route.rules[${warp_rule_num}] |= ${warp_rule}" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

    echo "$(jq 'del(.outbounds[] | select(.tag == "proxy")) | del(.route.rules[] | select(.outbound == "proxy" or .outbound == "direct"))' /etc/sing-box/config.json)" > /etc/sing-box/config.json

    if [[ $(jq 'any(.outbounds[]; .tag == "IPv4")' /etc/sing-box/config.json) == "false" ]]
    then
        ipv4_outbound='{"type":"direct","tag":"IPv4","domain_resolver":{"server":"dns-main","strategy":"prefer_ipv4"}}'
        echo "$(jq ".outbounds += [${ipv4_outbound}]" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

    if [[ $(jq 'any(.route.rules[]; .outbound == "IPv4")' /etc/sing-box/config.json) == "false" ]]
    then
        ipv4_rule='{"rule_set":["google"],"outbound":"IPv4"}'
        echo "$(jq ".route.rules += [${ipv4_rule}]" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

    rule_sets_add=(google-deepmind openai anthropic xai)
    rule_sets_del=(telegram)
    manage_rule_sets
    systemctl reload sing-box.service
    echo "${info_message[1_$language]}"
    echo ""
    main_menu
}

chain_middle() {
    declare -A -g info_message=()
    info_message[1_ru]="Изменение настроек завершено, этот сервер настроен как промежуточный в цепочке"
    info_message[1_en]="Settings changed successfully, this server is configured as intermediate in the chain"

    if [[ $(jq 'any(.route.rules[]; .outbound == "warp")' /etc/sing-box/config.json) == "true" ]]
    then
        warp_rule='{"domain_suffix":["example.com"],"outbound":"warp"}'
        warp_rule_num=$(jq '[.route.rules[].outbound] | index("warp")' /etc/sing-box/config.json)
        echo "$(jq ".route.rules[${warp_rule_num}] |= ${warp_rule}" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

    chain_outbound=$(echo "${next_config}" | jq '.outbounds[] | select(.tag == "proxy")')
    chain_rule='{"inbound":["trojan-in","vless-in"],"outbound":"proxy"}'
    [[ -f /etc/haproxy/auth.lua ]] && chain_rule='{"inbound":["trojan-in"],"outbound":"proxy"}'

    if [[ $(jq 'any(.outbounds[]; .tag == "proxy")' /etc/sing-box/config.json) == "false" ]]
    then
        if [[ $(jq 'any(.route.rules[]; .outbound == "direct")' /etc/sing-box/config.json) == "false" ]]
        then
            proxy_rule=$(jq 'limit(1; .route.rules[] | select(.outbound == "proxy"))' /var/www/${subspath}/template.json)
            direct_rule='{"domain_suffix":[".ru",".su",".ru.com",".ru.net"],"domain_keyword":["xn--"],"rule_set":["geoip-ru","category-gov-ru"],"outbound":"direct"}'
            echo "$(jq ".route.rules |= . + [${proxy_rule}, ${direct_rule}]" /etc/sing-box/config.json)" > /etc/sing-box/config.json
        fi

        echo "$(jq ".outbounds += [${chain_outbound}] | .route.rules += [${chain_rule}]" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    else
        chain_out_num=$(jq '[.outbounds[].tag] | index("proxy")' /etc/sing-box/config.json)
        chain_rule_num=$(jq '.route.rules | to_entries | map(select(.value.outbound == "proxy")) | last | .key' /etc/sing-box/config.json)
        echo "$(jq ".outbounds[${chain_out_num}] |= ${chain_outbound} | .route.rules[${chain_rule_num}] |= ${chain_rule}" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

    if [[ $(jq 'any(.outbounds[]; .tag == "IPv4")' /etc/sing-box/config.json) == "true" ]]
    then
        echo "$(jq 'del(.outbounds[] | select(.tag == "IPv4"))' /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

    if [[ $(jq 'any(.route.rules[]; .outbound == "IPv4")' /etc/sing-box/config.json) == "true" ]]
    then
        echo "$(jq 'del(.route.rules[] | select(.outbound == "IPv4"))' /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

    rule_sets_add=(telegram)
    rule_sets_del=(google-deepmind openai anthropic xai)
    manage_rule_sets
    systemctl reload sing-box.service
    echo "${info_message[1_$language]}"
    echo ""
    main_menu
}

get_chain_sel() {
    declare -A -g info_message=()
    info_message[1_ru]="Выбрано"
    info_message[1_en]="Selected"

    chain_sel_1=""; chain_sel_2=""

    if [[ $(jq 'any(.outbounds[]; .tag == "proxy")' /etc/sing-box/config.json) != "true" ]]
    then
        chain_sel_1="[${info_message[1_$language]}]"
    else
        chain_sel_2="[${info_message[1_$language]}: $(jq -r '.outbounds[] | select(.tag == "proxy") | .server' /etc/sing-box/config.json)]"
    fi
}

chain_text_ru() {
    echo -e "${textcolor}[?]${clear} Выберите положение сервера в цепочке:"
    echo "0 - Выйти"
    echo "1 - Настроить этот сервер как конечный в цепочке или единственный                     ${chain_sel_1}"
    echo "2 - Настроить этот сервер как промежуточный в цепочке или поменять следующий сервер   ${chain_sel_2}"
    read -r chain_option
    [[ -n $chain_option ]] && echo ""
}

chain_text_en() {
    echo -e "${textcolor}[?]${clear} Select the position of the server in the chain:"
    echo "0 - Exit"
    echo "1 - Configure this server as the end of the chain or the only one                  ${chain_sel_1}"
    echo "2 - Configure this server as intermediate in the chain or change the next server   ${chain_sel_2}"
    read -r chain_option
    [[ -n $chain_option ]] && echo ""
}

chain_setup() {
    get_chain_sel
    chain_text_${language}
    check_chain_option

    case $chain_option in
        1)
        chain_end
        ;;
        2)
        check_github_template
        enter_chain_data
        chain_middle
        ;;
        *)
        main_menu
    esac
}

### OPTION 11 - RENEW CERTIFICATE MANUALLY ###

exit_renew_cert() {
    if [[ ${cert_renew,,} =~ ^(x|х)$ ]]
    then
        cert_renew=""
        main_menu
    fi
}

enter_data_reissue_cert() {
    declare -A -g input_message=()
    input_message[1_ru]="${textcolor}[?]${clear} Введите вашу почту, зарегистрированную на Cloudflare:"
    input_message[1_en]="${textcolor}[?]${clear} Enter your email registered on Cloudflare:"

    if [[ ! -f /etc/letsencrypt/cloudflare.credentials ]]
    then
        input_message[1_ru]="${textcolor}[?]${clear} Введите вашу почту для выпуска сертификата:"
        input_message[1_en]="${textcolor}[?]${clear} Enter your email to issue a certificate:"
    fi

    while [[ -z $email ]]
    do
        echo -e "${input_message[1_$language]}"
        read -r email
        [[ -n $email ]] && echo ""
        email=$(echo "${email}" | sed 's/[[:blank:]]//g')
    done
}

cert_clean_up() {
    warn_file=$(python3 -c "import os, CloudFlare; print(os.path.join(os.path.dirname(CloudFlare.__file__), 'warning_2_20.py'))")
    [[ $(dpkg -s python3-cloudflare | grep -i '^version') =~ "2.20." ]] && sed -i 's/2\.20\./2\.25\./g' ${warn_file} &> /dev/null

    domain_del="${domain}"
    [[ "$option" == "12" ]] && domain_del="${domain_old}"
    certbot delete --cert-name ${domain_del} --quiet &> /dev/null
}

cert_final_text() {
    if [[ $? -ne 0 ]]
    then
        declare -A -g info_message=()
        info_message[1_ru]="${red}Ошибка: не удалось выпустить сертификат, попробуйте позже или смените домен/поддомен с помощью пункта 12${clear}"
        info_message[1_en]="${red}Error: failed to issue the certificate, try again later or change the domain/subdomain with option 12${clear}"

        echo ""
        echo -e "${info_message[1_$language]}"
    fi
}

reissue_cert() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor}Получение сертификата...${clear}"
    info_message[1_en]="${textcolor}Requesting a certificate...${clear}"

    cert_clean_up
    echo -e "${info_message[1_$language]}"

    if [[ -f /etc/letsencrypt/cloudflare.credentials ]]
    then
        certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.credentials --dns-cloudflare-propagation-seconds 35 -d ${domain},*.${domain} --agree-tos -m ${email} --no-eff-email --non-interactive
        cert_final_text
    else
        ufw allow 80 &> /dev/null
        certbot certonly --standalone --preferred-challenges http --agree-tos --email ${email} -d ${domain} --no-eff-email --non-interactive
        cert_final_text
        ufw delete allow 80 &> /dev/null
    fi

    if [[ ! -f /etc/haproxy/auth.lua ]] && [[ -f /etc/letsencrypt/live/${domain}/fullchain.pem ]]
    then
        echo "renew_hook = systemctl reload nginx.service" >> /etc/letsencrypt/renewal/${domain}.conf
        systemctl restart nginx.service
    elif [[ -f /etc/haproxy/auth.lua ]] && [[ -f /etc/letsencrypt/live/${domain}/fullchain.pem ]]
    then
        echo "renew_hook = cat /etc/letsencrypt/live/${domain}/fullchain.pem /etc/letsencrypt/live/${domain}/privkey.pem > /etc/haproxy/certs/${domain}.pem && systemctl reload haproxy.service" >> /etc/letsencrypt/renewal/${domain}.conf
        cat /etc/letsencrypt/live/${domain}/fullchain.pem /etc/letsencrypt/live/${domain}/privkey.pem > /etc/haproxy/certs/${domain}.pem
        systemctl restart haproxy.service
    fi

    echo ""
}

cert_renewal() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor}Обновление сертификата...${clear}"
    info_message[1_en]="${textcolor}Renewing the certificate...${clear}"

    echo -e "${info_message[1_$language]}"
    [[ ! -f /etc/letsencrypt/cloudflare.credentials ]] && ufw allow 80 &> /dev/null
    certbot renew --force-renewal
    cert_final_text
    ufw delete allow 80 &> /dev/null
    echo ""
}

renew_cert_text_ru() {
    echo -e "${red}ВНИМАНИЕ!${clear}"
    echo "В скрипт встроено автоматическое обновление сертификата раз в 2 месяца, и ручное обновление рекомендуется только в случае сбоев"
    echo "При обновлении сертификата более 5 раз в неделю можно достичь лимита Let's Encrypt, что потребует ожидания для следующего обновления"
    echo ""
    echo -e "${textcolor}[?]${clear} Нажмите ${textcolor}Enter${clear}, чтобы обновить сертификат, или введите ${textcolor}x${clear}, чтобы выйти:"
    read -r cert_renew
    [[ -n $cert_renew ]] && echo ""
}

renew_cert_text_en() {
    echo -e "${red}ATTENTION!${clear}"
    echo "The script has a built-in automatic certificate renewal every 2 months, and manual renewal is recommended only in case of failures"
    echo "Renewing a certificate more than 5 times a week can result in reaching the Let's Encrypt limit, requiring you to wait before the next renewal"
    echo ""
    echo -e "${textcolor}[?]${clear} Press ${textcolor}Enter${clear} to renew certificate or enter ${textcolor}x${clear} to exit:"
    read -r cert_renew
    [[ -n $cert_renew ]] && echo ""
}

renew_cert() {
    renew_cert_text_${language}
    exit_renew_cert

    if [[ -f /etc/letsencrypt/live/${domain}/fullchain.pem ]]
    then
        cert_renewal
    else
        email=""
        enter_data_reissue_cert
        reissue_cert
    fi

    main_menu
}

### OPTION 12 - CHANGE DOMAIN ###

exit_change_domain() {
    if [[ ${domain,,} =~ ^(x|х)$ ]]
    then
        domain="${domain_old}"
        main_menu
    fi
}

crop_domain() {
    domain=${domain#*"://"}
    domain=${domain#"www."}
    domain=$(echo "${domain}" | cut -d "/" -f 1 | sed 's/[[:blank:]]//g')
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

enter_domain_data() {
    declare -A -g input_message=()
    input_message[1_ru]="${textcolor}[?]${clear} Введите новый домен или введите ${textcolor}x${clear}, чтобы выйти:"
    input_message[2_ru]="${textcolor}[?]${clear} Введите вашу почту, зарегистрированную на Cloudflare:"
    input_message[3_ru]="${textcolor}[?]${clear} Введите ваш API токен Cloudflare (Edit zone DNS) или Cloudflare global API key:"
    input_message[1_en]="${textcolor}[?]${clear} Enter new domain name or enter ${textcolor}x${clear} to exit:"
    input_message[2_en]="${textcolor}[?]${clear} Enter your email registered on Cloudflare:"
    input_message[3_en]="${textcolor}[?]${clear} Enter your Cloudflare API token (Edit zone DNS) or Cloudflare global API key:"

    if [[ "$validation_type" == "2" ]]
    then
        input_message[2_ru]="${textcolor}[?]${clear} Введите вашу почту для выпуска сертификата:"
        input_message[2_en]="${textcolor}[?]${clear} Enter your email to issue a certificate:"
    fi

    domain=""; email=""; cf_token=""
    echo ""
    while [[ -z $domain ]]
    do
        echo -e "${input_message[1_$language]}"
        read -r domain
        [[ -n $domain ]] && echo ""
    done
    exit_change_domain
    crop_domain
    while [[ -z $email ]]
    do
        echo -e "${input_message[2_$language]}"
        read -r email
        [[ -n $email ]] && echo ""
        email=$(echo "${email}" | sed 's/[[:blank:]]//g')
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

issue_cert_dns_cf() {
    if [[ $cf_token =~ [A-Z] ]]
    then
        echo "dns_cloudflare_api_token = ${cf_token}" > /etc/letsencrypt/cloudflare.credentials
    else
        echo "dns_cloudflare_email = ${email}" > /etc/letsencrypt/cloudflare.credentials
        echo "dns_cloudflare_api_key = ${cf_token}" >> /etc/letsencrypt/cloudflare.credentials
    fi

    chown root:root /etc/letsencrypt/cloudflare.credentials
    chmod 600 /etc/letsencrypt/cloudflare.credentials

    echo -e "${info_message[3_$language]}"
    certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.credentials --dns-cloudflare-propagation-seconds 35 -d ${domain},*.${domain} --agree-tos -m ${email} --no-eff-email --non-interactive

    if [[ $? -ne 0 ]]
    then
        sleep 3
        echo ""
        echo -e "${info_message[4_$language]}"
        certbot delete --cert-name ${domain} --quiet &> /dev/null
        certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.credentials --dns-cloudflare-propagation-seconds 35 -d ${domain},*.${domain} --agree-tos -m ${email} --no-eff-email --non-interactive
    fi

    crontab -l | sed 's/.*certbot -q renew.*/0 2 * * * certbot -q renew/' | crontab -
}

issue_cert_standalone() {
    rm -f /etc/letsencrypt/cloudflare.credentials
    ufw allow 80 &> /dev/null

    echo -e "${info_message[3_$language]}"
    certbot certonly --standalone --preferred-challenges http --agree-tos --email ${email} -d ${domain} --no-eff-email --non-interactive

    if [[ $? -ne 0 ]]
    then
        sleep 3
        echo ""
        echo -e "${info_message[4_$language]}"
        certbot delete --cert-name ${domain} --quiet &> /dev/null
        certbot certonly --standalone --preferred-challenges http --agree-tos --email ${email} -d ${domain} --no-eff-email --non-interactive
    fi

    ufw delete allow 80 &> /dev/null
    crontab -l | sed 's/.*certbot -q renew.*/0 2 * * * ufw allow 80 \&\& certbot -q renew; ufw delete allow 80/' | crontab -
}

manage_frontend() {
    if [[ ! -f /etc/haproxy/auth.lua ]]
    then
        echo "renew_hook = systemctl reload nginx.service" >> /etc/letsencrypt/renewal/${domain}.conf
        sed -i "s/${domain_old}/${domain}/g" /etc/nginx/nginx.conf
        systemctl reload nginx.service || systemctl start nginx.service
    else
        rm -f /etc/haproxy/certs/${domain_old}.pem
        echo "renew_hook = cat /etc/letsencrypt/live/${domain}/fullchain.pem /etc/letsencrypt/live/${domain}/privkey.pem > /etc/haproxy/certs/${domain}.pem && systemctl reload haproxy.service" >> /etc/letsencrypt/renewal/${domain}.conf
        cat /etc/letsencrypt/live/${domain}/fullchain.pem /etc/letsencrypt/live/${domain}/privkey.pem > /etc/haproxy/certs/${domain}.pem
        sed -i "s/${domain_old}/${domain}/g" /etc/haproxy/haproxy.cfg
        systemctl reload haproxy.service || systemctl start haproxy.service
    fi
}

edit_subs_files() {
    declare -A -g info_message=()
    info_message[1_ru]="Домен ${textcolor}${domain_old}${clear} заменён на ${textcolor}${domain}${clear}"
    info_message[1_en]="Domain ${textcolor}${domain_old}${clear} changed to ${textcolor}${domain}${clear}"

    for file in /var/www/${subspath}/*-CLIENT.json
    do
        sed -i "s/${domain_old}/${domain}/g" ${file}
    done

    [[ -f /var/www/${subspath}/sub.html ]] && sed -i "s/${domain_old}/${domain}/g" /var/www/${subspath}/sub.html
    echo ""
    echo -e "${info_message[1_$language]}"
    echo ""
}

get_old_values() {
    domain_old="${domain}"
    validation_old="DNS Cloudflare"
    [[ ! -f /etc/letsencrypt/cloudflare.credentials ]] && validation_old="Standalone"
}

change_domain_text_ru() {
    echo -e "${red}ВНИМАНИЕ!${clear}"
    echo "Не забудьте создать А запись для нового домена и заменить домен в ссылках для клиентов"
    echo ""
    echo -e "Текущий домен: ${textcolor}${domain_old}${clear}"
    echo -e "Метод валидации сертификатов: ${textcolor}${validation_old}${clear}"
    echo ""
    echo -e "${textcolor}[?]${clear} Выберите метод валидации сертификатов для нового домена:"
    echo "0 - Выйти"
    echo "1 - DNS Cloudflare (если ваш домен прикреплён к Cloudflare)"
    echo "2 - Standalone (если ваш домен прикреплён к другому сервису)"
    read -r validation_type
}

change_domain_text_en() {
    echo -e "${red}ATTENTION!${clear}"
    echo "Don't forget to create an A record for the new domain and change the domain in client config links"
    echo ""
    echo -e "Current domain: ${textcolor}${domain_old}${clear}"
    echo -e "Certificate validation method: ${textcolor}${validation_old}${clear}"
    echo ""
    echo -e "${textcolor}[?]${clear} Select a certificate validation method for the new domain:"
    echo "0 - Exit"
    echo "1 - DNS Cloudflare (if your domain is linked to Cloudflare)"
    echo "2 - Standalone (if your domain is linked to another service)"
    read -r validation_type
}

cert_validation_options() {
    declare -A -g info_message=()
    info_message[1_ru]="${red}ВНИМАНИЕ!${clear}"
    info_message[2_ru]="Обязательно проверьте правильность написания домена"
    info_message[3_ru]="${textcolor}Получение сертификата...${clear}"
    info_message[4_ru]="${textcolor}Получение сертификата: 2-я попытка...${clear}"
    info_message[1_en]="${red}ATTENTION!${clear}"
    info_message[2_en]="Be sure to check the spelling of the domain name"
    info_message[3_en]="${textcolor}Requesting a certificate...${clear}"
    info_message[4_en]="${textcolor}Requesting a certificate: 2nd attempt...${clear}"

    case $validation_type in
        1)
        enter_domain_data
        check_cf_token
        cert_clean_up
        issue_cert_dns_cf
        ;;
        2)
        echo ""
        echo -e "${info_message[1_$language]}"
        echo "${info_message[2_$language]}"
        enter_domain_data
        cert_clean_up
        issue_cert_standalone
        ;;
        *)
        [[ -n $validation_type ]] && echo ""
        main_menu
    esac
}

change_domain() {
    get_old_values
    change_domain_text_${language}
    cert_validation_options
    manage_frontend
    edit_subs_files
    main_menu
}

### OPTION 13 - DISABLE IPv6 ###

disable_ipv6() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor}IPv6 отключён:${clear}"
    info_message[1_en]="${textcolor}IPv6 is disabled:${clear}"

    for sysctl_entry in 'net.ipv6.conf.all.disable_ipv6 = 1' 'net.ipv6.conf.default.disable_ipv6 = 1' 'net.ipv6.conf.lo.disable_ipv6 = 1'
    do
        grep -q "${sysctl_entry}" /etc/sysctl.d/99-ssb.conf &> /dev/null || echo "${sysctl_entry}" >> /etc/sysctl.d/99-ssb.conf
    done

    echo -e "${info_message[1_$language]}"
    sysctl --system &> /dev/null
    sysctl net.ipv6.conf.all.disable_ipv6 net.ipv6.conf.default.disable_ipv6 net.ipv6.conf.lo.disable_ipv6
    echo ""
    main_menu
}

### OPTION 14 - ENABLE IPv6 ###

enable_ipv6() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor}IPv6 включён:${clear}"
    info_message[2_ru]="${red}ВНИМАНИЕ!${clear}"
    info_message[3_ru]="Для применения новых настроек рекомендуется перезагрузить сервер командой ${textcolor}reboot${clear}"
    info_message[1_en]="${textcolor}IPv6 is enabled:${clear}"
    info_message[2_en]="${red}ATTENTION!${clear}"
    info_message[3_en]="To apply the new settings, it is recommended to reboot the server with ${textcolor}reboot${clear} command"

    for sysctl_file in '/etc/sysctl.d/99-ssb.conf' '/etc/sysctl.conf'
    do
        sed -i -e "/net.ipv6.conf.all.disable_ipv6 = 1/d" -e "/net.ipv6.conf.default.disable_ipv6 = 1/d" -e "/net.ipv6.conf.lo.disable_ipv6 = 1/d" ${sysctl_file} &> /dev/null
    done

    echo -e "${info_message[1_$language]}"
    sysctl --system &> /dev/null
    sysctl -w net.ipv6.conf.all.disable_ipv6=0 -w net.ipv6.conf.default.disable_ipv6=0 -w net.ipv6.conf.lo.disable_ipv6=0
    echo ""
    echo -e "${info_message[2_$language]}"
    echo -e "${info_message[3_$language]}"
    echo ""
    main_menu
}

### OPTION 15 - SHOW PATHS TO IMPORTANT FILES ###

show_paths_ru() {
    echo -e "${textcolor}Страница выдачи подписок пользователей:${clear}"
    echo -e "https://${domain}/${subspath}/sub.html${grey}?name=$(ls -A1 /var/www/${subspath} | grep "\-CLIENT.json" | sed -e "s/-TRJ-CLIENT\.json//g" -e "s/-VLESS-CLIENT\.json//g" | uniq | tail -n 1)${clear}"
    echo "Серым текстом показан пример автозаполнения поля с именем пользователя"
    echo ""

    echo -e "${textcolor}Конфигурация сервисов:${clear}"
    echo "Конфиг Sing-Box                        /etc/sing-box/config.json"
    echo "Конфиг NGINX                           /etc/nginx/nginx.conf"
    if [[ -f /etc/haproxy/haproxy.cfg ]]
    then
        echo "Конфиг HAProxy                         /etc/haproxy/haproxy.cfg"
        echo "Скрипт, считывающий пароли Trojan      /etc/haproxy/auth.lua"
    fi
    echo ""

    echo -e "${textcolor}Контент, доставляемый с помощью NGINX:${clear}"
    echo "Директория подписки                    /var/www/${subspath}/"
    echo "Директория c наборами правил           /var/www/${rulesetpath}/"
    site_dir=$(grep "/var/www/" /etc/nginx/nginx.conf | head -n 1 | cut -d "/" -f 4 | cut -d ";" -f 1)
    [[ -d /var/www/${site_dir} ]] && echo "Директория cайта                       /var/www/${site_dir}/"
    echo ""

    echo -e "${textcolor}Сертификаты и вспомогательные файлы:${clear}"
    echo "Директория с сертификатами             /etc/letsencrypt/live/${domain}/"
    [[ -f /etc/haproxy/certs/${domain}.pem ]] && echo "Объединённый файл с сертификатами      /etc/haproxy/certs/${domain}.pem"
    echo "Конфиг обновления сертификатов         /etc/letsencrypt/renewal/${domain}.conf"
    [[ -f /etc/letsencrypt/cloudflare.credentials ]] && echo "Файл с API токеном/ключом Cloudflare   /etc/letsencrypt/cloudflare.credentials"
    echo ""

    echo -e "${textcolor}Скрипты:${clear}"
    echo "Этот скрипт (меню настроек)            /usr/local/bin/sbmanager"
    echo "Скрипт, обновляющий наборы правил      /usr/local/bin/rsupdate"
    echo ""
    echo ""
    exit 0
}

show_paths_en() {
    echo -e "${textcolor}Subscription page:${clear}"
    echo -e "https://${domain}/${subspath}/sub.html${grey}?name=$(ls -A1 /var/www/${subspath} | grep "\-CLIENT.json" | sed -e "s/-TRJ-CLIENT\.json//g" -e "s/-VLESS-CLIENT\.json//g" | uniq | tail -n 1)${clear}"
    echo "Grey text shows an example of autofilling the username field"
    echo ""

    echo -e "${textcolor}Configuration of the services:${clear}"
    echo "Sing-Box config                      /etc/sing-box/config.json"
    echo "NGINX config                         /etc/nginx/nginx.conf"
    if [[ -f /etc/haproxy/haproxy.cfg ]]
    then
        echo "HAProxy config                       /etc/haproxy/haproxy.cfg"
        echo "Trojan password reading script       /etc/haproxy/auth.lua"
    fi
    echo ""

    echo -e "${textcolor}Content delivered by NGINX:${clear}"
    echo "Subscription directory               /var/www/${subspath}/"
    echo "Rule set directory                   /var/www/${rulesetpath}/"
    site_dir=$(grep "/var/www/" /etc/nginx/nginx.conf | head -n 1 | cut -d "/" -f 4 | cut -d ";" -f 1)
    [[ -d /var/www/${site_dir} ]] && echo "Site directory                       /var/www/${site_dir}/"
    echo ""

    echo -e "${textcolor}Certificates and accessory files:${clear}"
    echo "Certificate directory                /etc/letsencrypt/live/${domain}/"
    [[ -f /etc/haproxy/certs/${domain}.pem ]] && echo "Combined file with certificates      /etc/haproxy/certs/${domain}.pem"
    echo "Certificate renewal config           /etc/letsencrypt/renewal/${domain}.conf"
    [[ -f /etc/letsencrypt/cloudflare.credentials ]] && echo "File with Cloudflare API token/key   /etc/letsencrypt/cloudflare.credentials"
    echo ""

    echo -e "${textcolor}Scripts:${clear}"
    echo "This script (settings menu)          /usr/local/bin/sbmanager"
    echo "Rule set renewal script              /usr/local/bin/rsupdate"
    echo ""
    echo ""
    exit 0
}

### OPTION 16 - UPDATE SSB ###

update_ssb() {
    declare -A -g info_message=()
    info_message[1_ru]="${red}Ошибка: не удалось загрузить данные с GitHub, попробуйте позже${clear}"
    info_message[1_en]="${red}Error: failed to download data from GitHub, try again later${clear}"

    update_script=$(curl -Ls https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Scripts/update-server.sh)

    if [[ $update_script =~ '#!/bin/bash' ]]
    then
        export version="1.4.2" language
        export -f get_ip templates get_data check_users check_github_template get_pass edit_configs_loop add_rule_sets_loop sync_client_configs_main
        bash <(echo "${update_script}")
        exit 0
    else
        echo -e "${info_message[1_$language]}"
        echo ""
        main_menu
    fi
}

### MAIN MENU ###

main_menu_text_ru() {
    echo ""
    echo -e "${textcolor}Выберите действие:${clear}"
    echo "0 - Выйти"
    echo "1 - Вывести список пользователей"
    echo "2 - Добавить нового пользователя"
    echo "3 - Удалить пользователя"
    echo "---------------------------------"
    echo "4 - Поменять \"stack\" в tun-интерфейсе у пользователя"
    echo "5 - Синхронизировать настройки во всех клиентских конфигах"
    echo "6 - Настроить на клиенте подключение к выбранному IP Cloudflare"
    echo "---------------------------------"
    echo "7 - Вывести список доменов/суффиксов WARP"
    echo "8 - Добавить домен/суффикс в WARP"
    echo "9 - Удалить домен/суффикс из WARP"
    echo "10 - Настроить/убрать цепочку из двух и более серверов"
    echo "---------------------------------"
    echo "11 - Обновить сертификат вручную"
    echo "12 - Сменить домен"
    echo "---------------------------------"
    echo "13 - Отключить IPv6 на сервере"
    echo "14 - Включить IPv6 на сервере"
    echo "---------------------------------"
    echo "15 - Показать пути до конфигов и других значимых файлов"
    echo "16 - Обновить"
    read -r option
    [[ -n $option ]] && echo ""
}

main_menu_text_en() {
    echo ""
    echo -e "${textcolor}Select an option:${clear}"
    echo "0 - Exit"
    echo "1 - Show the list of users"
    echo "2 - Add a new user"
    echo "3 - Delete a user"
    echo "---------------------------------"
    echo "4 - Change \"stack\" in tun interface of the user"
    echo "5 - Sync settings in all client configs"
    echo "6 - Setup connection to custom Cloudflare IP on the client"
    echo "---------------------------------"
    echo "7 - Show the list of domains/suffixes routed through WARP"
    echo "8 - Add a new domain/suffix to WARP routing"
    echo "9 - Delete a domain/suffix from WARP routing"
    echo "10 - Setup/remove a chain of two or more servers"
    echo "---------------------------------"
    echo "11 - Renew certificate manually"
    echo "12 - Change domain"
    echo "---------------------------------"
    echo "13 - Disable IPv6 on the server"
    echo "14 - Enable IPv6 on the server"
    echo "---------------------------------"
    echo "15 - Show paths to configs and other important files"
    echo "16 - Update"
    read -r option
    [[ -n $option ]] && echo ""
}

main_menu() {
    main_menu_text_${language}

    case $option in
        1)
        show_users
        ;;
        2)
        add_users
        ;;
        3)
        delete_users
        ;;
        4)
        change_stack
        ;;
        5)
        sync_client_configs
        ;;
        6)
        cf_ip_settings
        ;;
        7)
        show_warp_domains
        ;;
        8)
        add_warp_domains
        ;;
        9)
        delete_warp_domains
        ;;
        10)
        chain_setup
        ;;
        11)
        renew_cert
        ;;
        12)
        change_domain
        ;;
        13)
        disable_ipv6
        ;;
        14)
        enable_ipv6
        ;;
        15)
        show_paths_${language}
        ;;
        16)
        update_ssb
        ;;
        *)
        exit 0
    esac
}

check_root
check_config_json
banner
get_data
main_menu
