#!/bin/bash
set -o pipefail

textcolor='\033[1;36m'
red='\033[1;31m'
grey='\033[1;30m'
clear='\033[0m'

check_root() {
    if [[ $EUID -ne 0 ]]
    then
        echo -e "${red}Error: this command should be run as root, use \"sudo -i\" command first${clear}"
        exit 1
    fi
}

check_config_json() {
    if [[ ! -s /etc/sing-box/config.json ]] || ! jq empty /etc/sing-box/config.json &> /dev/null
    then
        echo -e "${red}Error: /etc/sing-box/config.json is corrupted, corrections needed${clear}"
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
    wget -q -O "/var/www/${subspath}/template.json.1" -T 30 https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Config-Templates/client.json

    if [[ $? -eq 0 ]]
    then
        local outbound_num=$(jq '[.outbounds[].tag] | index("proxy")' "/var/www/${subspath}/template.json.1")

        if [[ $(jq -r '.inbounds[] | select(.tag == "trojan-in") | .transport.type' /etc/sing-box/config.json) == "ws" ]]
        then
            mv -f "/var/www/${subspath}/template.json.1" "/var/www/${subspath}/template.json"
        elif [[ $(jq -r '.inbounds[] | select(.tag == "trojan-in") | .transport.type' /etc/sing-box/config.json) == "httpupgrade" ]]
        then
            echo "$(jq ".outbounds[${outbound_num}].transport.type = \"httpupgrade\"" "/var/www/${subspath}/template.json.1")" > "/var/www/${subspath}/template.json"
            rm -f "/var/www/${subspath}/template.json.1"
        else
            echo "$(jq "del(.outbounds[${outbound_num}].transport.type, .outbounds[${outbound_num}].transport.path)" "/var/www/${subspath}/template.json.1")" > "/var/www/${subspath}/template.json"
            rm -f "/var/www/${subspath}/template.json.1"
        fi
    fi

    if [[ ! -f /var/www/${subspath}/template-loc.json ]] && [[ -s /var/www/${subspath}/template.json ]] && jq empty "/var/www/${subspath}/template.json" &> /dev/null
    then
        cp "/var/www/${subspath}/template.json" "/var/www/${subspath}/template-loc.json"
    fi
}

get_ip() {
    server_ip=$(curl -s4 -m 15 https://cloudflare.com/cdn-cgi/trace | grep "ip" | cut -d "=" -f 2)
    [[ ! $server_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && server_ip=$(curl -s4 -m 15 ipinfo.io/ip)
    [[ ! $server_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && server_ip=$(curl -s4 -m 15 2ip.io)
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

    subspath=$(grep "location ~ ^/" /etc/nginx/nginx.conf | tail -n 1 | cut -d "/" -f 2 | cut -d " " -f 1)
    rulesetpath=$(grep "alias /var/www/" /etc/nginx/nginx.conf | head -n 1 | cut -d "/" -f 4)

    get_ip
    templates

    language="en"
    grep -q 'html lang="ru"' "/var/www/${subspath}/sub.html" &> /dev/null && language="ru"
}

check_github_template() {
    local -A cgt_message=()
    cgt_message[1_ru]="${red}Ошибка: не удалось загрузить данные с GitHub, попробуйте позже${clear}"
    cgt_message[1_en]="${red}Error: failed to download data from GitHub, try again later${clear}"

    if [[ ! -s /var/www/${subspath}/template.json ]] || ! jq empty "/var/www/${subspath}/template.json" &> /dev/null
    then
        echo -e "${cgt_message[1_$language]}"
        echo ""
        return 111
    fi
}

check_local_template() {
    local -A clt_message=()
    clt_message[1_ru]="${red}Ошибка: структура template-loc.json нарушена, требуются исправления${clear}"
    clt_message[2_ru]="${textcolor}[?]${clear} Введите ${textcolor}reset${clear}, чтобы сбросить шаблон до исходной версии, или введите ${textcolor}x${clear}, чтобы выйти:"
    clt_message[3_ru]="Шаблон сброшен до исходной версии"
    clt_message[1_en]="${red}Error: template-loc.json is corrupted, corrections needed${clear}"
    clt_message[2_en]="${textcolor}[?]${clear} Enter ${textcolor}reset${clear} to reset the template to default version or enter ${textcolor}x${clear} to exit:"
    clt_message[3_en]="The template has been reset to its default version"

    if [[ ! -s /var/www/${subspath}/template-loc.json ]] || ! jq empty "/var/www/${subspath}/template-loc.json" &> /dev/null || [[ $(jq 'any(.inbounds[]; .tag == "tun-in")' "/var/www/${subspath}/template-loc.json") != "true" ]] || [[ $(jq 'any(.outbounds[]; .tag == "proxy")' "/var/www/${subspath}/template-loc.json") != "true" ]]
    then
        echo -e "${clt_message[1_$language]}"
        echo ""
        echo -e "${clt_message[2_$language]}"
        local reset_temp; read -r reset_temp
        [[ -n $reset_temp ]] && echo ""

        if [[ "$reset_temp" == "reset" ]]
        then
            check_github_template; [[ $? -eq 111 ]] && return 111
            cp -f "/var/www/${subspath}/template.json" "/var/www/${subspath}/template-loc.json"
            echo "${clt_message[3_$language]}"
            echo ""
        fi

        return 111
    fi
}

### OPTION 1 - SHOW USERS ###

show_users() {
    local -A su_message=()
    su_message[1_ru]="${textcolor}Количество пользователей:${clear}"
    su_message[1_en]="${textcolor}Number of users:${clear}"

    local user_num=$(ls -A1 "/var/www/${subspath}" | grep -c "\-TRJ-CLIENT.json")
    echo -e "${su_message[1_$language]} ${user_num}"
    ls -A1 "/var/www/${subspath}" | grep "\-CLIENT.json" | sed -e "s/-TRJ-CLIENT\.json//g" -e "s/-VLESS-CLIENT\.json//g" | uniq
    echo ""
}

### OPTION 2 - ADD USERS ###

enter_check_username_add() {
    local -A ecua_message=()
    ecua_message[1_ru]="${textcolor}[?]${clear} Введите имя нового пользователя или введите ${textcolor}x${clear}, чтобы закончить:"
    ecua_message[2_ru]="${red}Ошибка: имя пользователя должно содержать только английские буквы, цифры, символы _ и -${clear}"
    ecua_message[3_ru]="${red}Ошибка: пользователь с таким именем уже существует${clear}"
    ecua_message[1_en]="${textcolor}[?]${clear} Enter the name of the new user or enter ${textcolor}x${clear} to exit:"
    ecua_message[2_en]="${red}Error: the username should contain only letters, numbers, _ and - symbols${clear}"
    ecua_message[3_en]="${red}Error: this user already exists${clear}"

    while true
    do
        echo -e "${ecua_message[1_$language]}"
        read -r username
        [[ -n $username ]] && echo ""

        if [[ ${username,,} =~ ^(x|х)$ ]]
        then
            return 111
        elif [[ ! $username =~ ^[a-zA-Z0-9_-]+$ ]] && [[ -n $username ]]
        then
            echo -e "${ecua_message[2_$language]}"
            echo ""
        elif ([[ -f /var/www/${subspath}/${username}-TRJ-CLIENT.json ]] || [[ $(jq "any(.inbounds[].users[]; .name == \"${username}\")" /etc/sing-box/config.json) != "false" ]]) && [[ -n $username ]]
        then
            echo -e "${ecua_message[3_$language]}"
            echo -e "${red}https://${domain}/${subspath}/${username}-TRJ-CLIENT.json${clear}"
            [[ ! -f /etc/haproxy/auth.lua ]] && echo -e "${red}https://${domain}/${subspath}/${username}-VLESS-CLIENT.json${clear}"
            echo ""
        else
            break
        fi
    done
}

enter_check_trjpass() {
    local -A ect_message=()
    ect_message[1_ru]="${textcolor}[?]${clear} Введите пароль для Trojan или оставьте пустым для генерации случайного пароля:"
    ect_message[2_ru]="${red}Ошибка: пароль Trojan не должен содержать кавычки \"${clear}"
    ect_message[3_ru]="${red}Ошибка: этот пароль уже закреплён за другим пользователем${clear}"
    ect_message[1_en]="${textcolor}[?]${clear} Enter the password for Trojan or leave this empty to generate a random password:"
    ect_message[2_en]="${red}Error: Trojan password should not contain quotes \"${clear}"
    ect_message[3_en]="${red}Error: this password is already assigned to another user${clear}"

    while true
    do
        echo -e "${ect_message[1_$language]}"
        read -r trjpass
        [[ -n $trjpass ]] && echo ""

        if [[ $trjpass =~ '"' ]]
        then
            echo -e "${ect_message[2_$language]}"
            echo ""
        elif [[ $(jq "any(.inbounds[].users[]; .password == \"${trjpass}\")" /etc/sing-box/config.json) != "false" ]] && [[ -n $trjpass ]]
        then
            echo -e "${ect_message[3_$language]}"
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
    ecu_message[3_ru]="${red}Ошибка: этот UUID уже закреплён за другим пользователем${clear}"
    ecu_message[1_en]="${textcolor}[?]${clear} Enter the UUID for VLESS or leave this empty to generate a random UUID:"
    ecu_message[2_en]="${red}Error: this is not an UUID${clear}"
    ecu_message[3_en]="${red}Error: this UUID is already assigned to another user${clear}"

    while true
    do
        echo -e "${ecu_message[1_$language]}"
        read -r uuid
        [[ -n $uuid ]] && echo ""

        if [[ ! $uuid =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]] && [[ -n $uuid ]]
        then
            echo -e "${ecu_message[2_$language]}"
            echo ""
        elif [[ $(jq "any(.inbounds[].users[]; .uuid == \"${uuid}\")" /etc/sing-box/config.json) != "false" ]] && [[ -n $uuid ]]
        then
            echo -e "${ecu_message[3_$language]}"
            echo ""
        else
            break
        fi
    done
}

generate_pass() {
    [[ -z $username ]] && username=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 10)
    [[ -z $trjpass ]] && trjpass=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30)
    [[ -z $uuid ]] && [[ ! -f /etc/haproxy/auth.lua ]] && uuid=$(cat /proc/sys/kernel/random/uuid)
}

add_to_server_conf() {
    local inbound_tag inbound_num user_cred

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
    local -A atcc_message=()
    atcc_message[1_ru]="Пользователь ${textcolor}${username}${clear} добавлен:"
    atcc_message[1_en]="Added user ${textcolor}${username}${clear}:"

    cp -f "/var/www/${subspath}/template.json" "/var/www/${subspath}/${username}-TRJ-CLIENT.json"
    sed -i -e "s/DOMAIN/${domain}/g" -e "s/SERVER-IP/${server_ip}/g" -e "s/RULESETPATH/${rulesetpath}/g" "/var/www/${subspath}/${username}-TRJ-CLIENT.json"
    local outbound_num=$(jq '[.outbounds[].tag] | index("proxy")' "/var/www/${subspath}/${username}-TRJ-CLIENT.json")

    if [[ -f /etc/haproxy/auth.lua ]]
    then
        echo "$(jq ".outbounds[${outbound_num}].password = \"${trjpass}\"" "/var/www/${subspath}/${username}-TRJ-CLIENT.json")" > "/var/www/${subspath}/${username}-TRJ-CLIENT.json"
    else
        echo "$(jq ".outbounds[${outbound_num}].password = \"${trjpass}\" | .outbounds[${outbound_num}].transport.path = \"/${trojanpath}\"" "/var/www/${subspath}/${username}-TRJ-CLIENT.json")" > "/var/www/${subspath}/${username}-TRJ-CLIENT.json"
        echo "$(jq ".outbounds[${outbound_num}].type = \"vless\" | .outbounds[${outbound_num}] |= with_entries(.key |= if . == \"password\" then \"uuid\" else . end) | .outbounds[${outbound_num}].uuid = \"${uuid}\" | .outbounds[${outbound_num}].transport.path = \"/${vlesspath}\"" "/var/www/${subspath}/${username}-TRJ-CLIENT.json")" > "/var/www/${subspath}/${username}-VLESS-CLIENT.json"
    fi

    echo -e "${atcc_message[1_$language]}"
    echo "https://${domain}/${subspath}/${username}-TRJ-CLIENT.json"
    [[ ! -f /etc/haproxy/auth.lua ]] && echo "https://${domain}/${subspath}/${username}-VLESS-CLIENT.json"
    echo ""
}

add_to_auth_lua() {
    if [[ -f /etc/haproxy/auth.lua ]]
    then
        local pass_hash=$(echo -n "${trjpass}" | openssl dgst -sha224 | sed 's/.* //')
        sed -i "2i \ \ \ \ [\"${pass_hash}\"] = true,    -- User '${username}'" /etc/haproxy/auth.lua
        systemctl reload haproxy.service
    fi
}

add_users() {
    local username trjpass uuid
    check_github_template; [[ $? -eq 111 ]] && return 111

    while [[ ! ${username,,} =~ ^(x|х)$ ]]
    do
        enter_check_username_add; [[ $? -eq 111 ]] && return 111
        enter_check_trjpass
        [[ ! -f /etc/haproxy/auth.lua ]] && enter_check_uuid
        generate_pass
        add_to_auth_lua
        add_to_server_conf
        add_to_client_conf
    done
}

### OPTION 3 - DELETE USERS ###

enter_check_username_del() {
    local -A ecud_message=()
    ecud_message[1_ru]="${textcolor}[?]${clear} Введите имя пользователя или введите ${textcolor}x${clear}, чтобы закончить:"
    ecud_message[2_ru]="${red}Ошибка: пользователь с таким именем не существует${clear}"
    ecud_message[1_en]="${textcolor}[?]${clear} Enter the name of the user or enter ${textcolor}x${clear} to exit:"
    ecud_message[2_en]="${red}Error: a user with this name does not exist${clear}"

    while true
    do
        echo -e "${ecud_message[1_$language]}"
        read -r username
        [[ -n $username ]] && echo ""

        if [[ ${username,,} =~ ^(x|х)$ ]]
        then
            return 111
        elif [[ -z $username ]]
        then
            :
        elif [[ $(jq "any(.inbounds[].users[]; .name == \"${username}\")" /etc/sing-box/config.json) != "true" ]]
        then
            echo -e "${ecud_message[2_$language]}"
            echo ""
        else
            break
        fi
    done
}

del_from_conf() {
    local -A dfc_message=()
    dfc_message[1_ru]="Пользователь ${textcolor}${username}${clear} удалён"
    dfc_message[1_en]="Deleted user ${textcolor}${username}${clear}"

    echo "$(jq "del(.inbounds[].users[] | select(.name == \"${username}\"))" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    systemctl reload sing-box.service

    rm -f "/var/www/${subspath}/${username}-TRJ-CLIENT.json" "/var/www/${subspath}/${username}-VLESS-CLIENT.json"
    echo -e "${dfc_message[1_$language]}"
    echo ""
}

del_from_auth_lua() {
    if [[ -f /etc/haproxy/auth.lua ]]
    then
        local trjpass=$(jq -r ".inbounds[].users[] | select(.name == \"${username}\") | .password" /etc/sing-box/config.json)
        local pass_hash=$(echo -n "${trjpass}" | openssl dgst -sha224 | sed 's/.* //')
        sed -i "/${pass_hash}/d" /etc/haproxy/auth.lua
        systemctl reload haproxy.service
    fi
}

delete_users() {
    local username

    while [[ ! ${username,,} =~ ^(x|х)$ ]]
    do
        enter_check_username_del; [[ $? -eq 111 ]] && return 111
        del_from_auth_lua
        del_from_conf
    done
}

### OPTION 4 - CHANGE STACK VALUE ###

get_stack_sel() {
    local -A gss_message=()
    gss_message[1_ru]="[Выбрано]"
    gss_message[1_en]="[Selected]"

    stack_sel_1=""; stack_sel_2=""; stack_sel_3=""
    local current_stack=$(jq -r '.inbounds[] | select(.tag == "tun-in") | .stack' "/var/www/${subspath}/${username}-TRJ-CLIENT.json")

    case "$current_stack" in
        system)
        stack_sel_1="${gss_message[1_$language]}"
        ;;
        gvisor)
        stack_sel_2="${gss_message[1_$language]}"
        ;;
        mixed)
        stack_sel_3="${gss_message[1_$language]}"
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

set_new_stack() {
    case "$stack_option" in
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
        return 111
    esac
}

edit_configs_stack() {
    local -A ecs_message=()
    ecs_message[1_ru]="Изменение \"stack\" у пользователя ${textcolor}${username}${clear} завершено, для применения новых настроек обновите конфиг на клиенте"
    ecs_message[1_en]="The \"stack\" value for the user ${textcolor}${username}${clear} has been changed, update the config on the client app to apply new settings"

    local protocol inbound_num

    for protocol in 'TRJ' 'VLESS'
    do
        [[ "$protocol" == "VLESS" ]] && [[ -f /etc/haproxy/auth.lua ]] && break
        inbound_num=$(jq '[.inbounds[].tag] | index("tun-in")' "/var/www/${subspath}/${username}-${protocol}-CLIENT.json")
        echo "$(jq ".inbounds[${inbound_num}].stack = \"${new_stack}\"" "/var/www/${subspath}/${username}-${protocol}-CLIENT.json")" > "/var/www/${subspath}/${username}-${protocol}-CLIENT.json"
    done

    echo -e "${ecs_message[1_$language]}"
    echo ""
}

change_stack() {
    local username stack_sel_1 stack_sel_2 stack_sel_3 stack_option new_stack

    while [[ ! ${username,,} =~ ^(x|х)$ ]]
    do
        enter_check_username_del; [[ $? -eq 111 ]] && return 111
        get_stack_sel
        "stack_text_${language}"
        set_new_stack; [[ $? -eq 111 ]] && return 111
        edit_configs_stack
    done
}

### OPTION 5 - SYNCHRONIZE SETTINGS IN CLIENT CONFIGS ###

check_users() {
    local -A cu_message=()
    cu_message[1_ru]="${red}Ошибка: пользователи отсутствуют${clear}"
    cu_message[1_en]="${red}Error: no users found${clear}"

    if [[ $(ls -A1 "/var/www/${subspath}" | grep -c "\-CLIENT.json") -eq 0 ]]
    then
        echo -e "${cu_message[1_$language]}"
        echo ""
        return 111
    fi
}

get_pass() {
    trjpass=""; uuid=""; cf_ip=""

    if grep -q ': "trojan"' "${file}"
    then
        trjpass=$(jq -r '.outbounds[] | select(.tag == "proxy") | .password' "${file}")
    else
        uuid=$(jq -r '.outbounds[] | select(.tag == "proxy") | .uuid' "${file}")
    fi

    stack=$(jq -r '.inbounds[] | select(.tag == "tun-in") | .stack' "${file}")

    if [[ $(jq '.outbounds[] | select(.tag == "proxy") | .transport | has("headers")' "${file}") == "true" ]]
    then
        cf_ip=$(jq -r '.outbounds[] | select(.tag == "proxy") | .server' "${file}")
    fi
}

edit_configs_loop() {
    local file trjpass uuid stack cf_ip

    for file in /var/www/"${subspath}"/*-CLIENT.json
    do
        get_pass
        cp -f "/var/www/${subspath}/${sync_template_file}" "${file}"

        if [[ "$sync_template_file" == "template.json" ]]
        then
            sed -i -e "s/DOMAIN/${domain}/g" -e "s/SERVER-IP/${server_ip}/g" -e "s/RULESETPATH/${rulesetpath}/g" "${file}"
        else
            sed -i -e "s/${loc_tempdomain}/${domain}/g" -e "s/${loc_tempip}/${server_ip}/g" -e "s/${loc_temprulesetpath}/${rulesetpath}/g" "${file}"
        fi

        if [[ -f /etc/haproxy/auth.lua ]]
        then
            echo "$(jq ".inbounds[${inbound_num}].stack = \"${stack}\" | .outbounds[${outbound_num}].password = \"${trjpass}\"" "${file}")" > "${file}"
        elif [[ ! -f /etc/haproxy/auth.lua ]] && [[ -n $trjpass ]]
        then
            echo "$(jq ".inbounds[${inbound_num}].stack = \"${stack}\" | .outbounds[${outbound_num}].password = \"${trjpass}\" | .outbounds[${outbound_num}].transport.path = \"/${trojanpath}\"" "${file}")" > "${file}"
        else
            echo "$(jq ".inbounds[${inbound_num}].stack = \"${stack}\" | .outbounds[${outbound_num}].type = \"vless\" | .outbounds[${outbound_num}] |= with_entries(.key |= if . == \"password\" then \"uuid\" else . end) | .outbounds[${outbound_num}].uuid = \"${uuid}\" | .outbounds[${outbound_num}].transport.path = \"/${vlesspath}\"" "${file}")" > "${file}"
        fi

        [[ -n $cf_ip ]] && echo "$(jq ".outbounds[${outbound_num}].server = \"${cf_ip}\" | .outbounds[${outbound_num}].transport.headers |= {\"Host\":\"${domain}\"} | .route.default_http_client = \"http-proxy\"" "${file}")" > "${file}"
    done
}

add_rule_sets_loop() {
    local ruleset_ind ruleset

    for ruleset_ind in $(seq 0 "$(jq '.route.rule_set | length - 1' "/var/www/${subspath}/${sync_template_file}")")
    do
        ruleset=$(jq -r ".route.rule_set[${ruleset_ind}].url" "/var/www/${subspath}/${sync_template_file}" | cut -d "/" -f 5)
        [[ ! -f /var/www/${rulesetpath}/${ruleset} ]] && wget -q -P "/var/www/${rulesetpath}" -T 30 "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/${ruleset}"
    done
}

sync_client_configs_main() {
    local -A sccm_message=()
    sccm_message[1_ru]="Синхронизация настроек с GitHub завершена"
    sccm_message[1_en]="Synchronization of the settings with GitHub is completed"

    if [[ "$sync_template_file" == "template-loc.json" ]]
    then
        sccm_message[1_ru]="Синхронизация настроек с локальным шаблоном завершена"
        sccm_message[1_en]="Synchronization of the settings with local template is completed"

        local loc_temprulesetpath=$(jq -r '.route.rule_set[-1].url // "missing_value"' "/var/www/${subspath}/template-loc.json" | cut -d "/" -f 4)
        local loc_tempdomain=$(jq -r '.outbounds[] | select(.tag == "proxy") | .server' "/var/www/${subspath}/template-loc.json")
        local loc_tempip=$(jq -r '.route.rules[] | select(has("ip_cidr")) | .ip_cidr[0]' "/var/www/${subspath}/template-loc.json")
        [[ -z $loc_tempip ]] && loc_tempip="missing_value"
    fi

    local inbound_num=$(jq '[.inbounds[].tag] | index("tun-in")' "/var/www/${subspath}/${sync_template_file}")
    local outbound_num=$(jq '[.outbounds[].tag] | index("proxy")' "/var/www/${subspath}/${sync_template_file}")
    edit_configs_loop

    if [[ $(jq '.route.rule_set | length' "/var/www/${subspath}/${sync_template_file}") =~ ^[1-9][0-9]*$ ]]
    then
        add_rule_sets_loop
        chmod -R 755 "/var/www/${rulesetpath}"
    fi

    echo "${sccm_message[1_$language]}"
    echo ""
}

sync_github_text_ru() {
    echo -e "${red}ВНИМАНИЕ!${clear}"
    echo "Настройки в клиентских конфигах всех пользователей будут синхронизированы с последней версией на GitHub:"
    echo "https://github.com/A-Zuro/Secret-Sing-Box/blob/main/Config-Templates/client.json"
    echo ""
    echo -e "${textcolor}[?]${clear} Нажмите ${textcolor}Enter${clear}, чтобы синхронизировать настройки, или введите ${textcolor}x${clear}, чтобы выйти:"
    local sync; read -r sync
    [[ -n $sync ]] && echo ""
    [[ ${sync,,} =~ ^(x|х)$ ]] && return 111
}

sync_github_text_en() {
    echo -e "${red}ATTENTION!${clear}"
    echo "The settings in client configs of all users will be synchronized with the latest version on GitHub:"
    echo "https://github.com/A-Zuro/Secret-Sing-Box/blob/main/Config-Templates/client.json"
    echo ""
    echo -e "${textcolor}[?]${clear} Press ${textcolor}Enter${clear} to synchronize the settings or enter ${textcolor}x${clear} to exit:"
    local sync; read -r sync
    [[ -n $sync ]] && echo ""
    [[ ${sync,,} =~ ^(x|х)$ ]] && return 111
}

sync_local_text_ru() {
    echo -e "${red}ВНИМАНИЕ!${clear}"
    echo -e "Вы можете вручную отредактировать настройки в шаблоне ${textcolor}/var/www/${subspath}/template-loc.json${clear}"
    echo "Настройки в этом файле будут применены к клиентским конфигам всех пользователей"
    echo "При редактировании не меняйте значения \"tag\" у \"inbounds\" и \"outbounds\""
    echo ""
    echo -e "${textcolor}[?]${clear} Нажмите ${textcolor}Enter${clear}, чтобы синхронизировать настройки, или введите ${textcolor}x${clear}, чтобы выйти:"
    local sync; read -r sync
    [[ -n $sync ]] && echo ""
    [[ ${sync,,} =~ ^(x|х)$ ]] && return 111
}

sync_local_text_en() {
    echo -e "${red}ATTENTION!${clear}"
    echo -e "You can manually edit the settings in ${textcolor}/var/www/${subspath}/template-loc.json${clear} template"
    echo "The settings in this file will be applied to client configs of all users"
    echo "Do not change \"tag\" values in \"inbounds\" and \"outbounds\" while editing"
    echo ""
    echo -e "${textcolor}[?]${clear} Press ${textcolor}Enter${clear} to synchronize the settings or enter ${textcolor}x${clear} to exit:"
    local sync; read -r sync
    [[ -n $sync ]] && echo ""
    [[ ${sync,,} =~ ^(x|х)$ ]] && return 111
}

sync_options_text_ru() {
    echo -e "${textcolor}[?]${clear} Выберите вариант синхронизации:"
    echo "0 - Выйти"
    echo "1 - Синхронизировать с GitHub"
    echo "2 - Синхронизировать с локальным шаблоном (свои настройки)"
    read -r sync_option
    [[ -n $sync_option ]] && echo ""
}

sync_options_text_en() {
    echo -e "${textcolor}[?]${clear} Select synchronisation option:"
    echo "0 - Exit"
    echo "1 - Sync with GitHub"
    echo "2 - Sync with local template (custom settings)"
    read -r sync_option
    [[ -n $sync_option ]] && echo ""
}

sync_options() {
    case "$sync_option" in
        1)
        sync_variant="github"
        sync_template_file="template.json"
        ;;
        2)
        sync_variant="local"
        sync_template_file="template-loc.json"
        ;;
        *)
        return 111
    esac
}

sync_client_configs() {
    local sync_option sync_variant sync_template_file
    "sync_options_text_${language}"
    sync_options; [[ $? -eq 111 ]] && return 111
    "sync_${sync_variant}_text_${language}"; [[ $? -eq 111 ]] && return 111
    check_users; [[ $? -eq 111 ]] && return 111
    "check_${sync_variant}_template"; [[ $? -eq 111 ]] && return 111
    sync_client_configs_main
}

### OPTION 6 - SETUP CONNECTION TO CUSTOM CLOUDFLARE IP ###

check_variant() {
    local -A cv_message=()
    cv_message[1_ru]="${red}Ошибка: этот пункт только для вариантов настройки с транспортом WebSocket или HTTPUpgrade${clear}"
    cv_message[1_en]="${red}Error: this option is only available for the setup variants with WebSocket or HTTPUpgrade transport${clear}"

    if [[ -f /etc/haproxy/auth.lua ]]
    then
        echo -e "${cv_message[1_$language]}"
        echo ""
        return 111
    fi
}

check_cf_option() {
    local -A cco_message=()
    cco_message[1_ru]="${red}Ошибка: IP Cloudflare итак не указан в конфиге этого пользователя${clear}"
    cco_message[1_en]="${red}Error: the config file of this user does not contain Cloudflare IP anyway${clear}"

    while [[ "$cf_option" == "2" ]] && [[ $(jq '.outbounds[] | select(.tag == "proxy") | .transport | has("headers")' "/var/www/${subspath}/${username}-TRJ-CLIENT.json") != "true" ]]
    do
        echo -e "${cco_message[1_$language]}"
        echo ""
        "cf_text_${language}"
    done
}

enter_check_cf_ip() {
    local -A ecci_message=()
    ecci_message[1_ru]="${textcolor}[?]${clear} Введите выбранный IP Cloudflare:"
    ecci_message[2_ru]="${red}Ошибка: введённое значение не является IP${clear}"
    ecci_message[1_en]="${textcolor}[?]${clear} Enter the custom Cloudflare IP:"
    ecci_message[2_en]="${red}Error: the entered value is not an IP${clear}"

    while true
    do
        echo -e "${ecci_message[1_$language]}"
        read -r cf_ip
        [[ -n $cf_ip ]] && echo ""

        if [[ -z $cf_ip ]]
        then
            :
        elif [[ ! $cf_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
        then
            echo -e "${ecci_message[2_$language]}"
            echo ""
        else
            break
        fi
    done
}

set_cf_ip() {
    local -A sci_message=()
    sci_message[1_ru]="Изменение настроек для пользователя ${textcolor}${username}${clear} завершено, установлен IP ${textcolor}${cf_ip}${clear}"
    sci_message[1_en]="Changed the settings for the user ${textcolor}${username}${clear}, IP ${textcolor}${cf_ip}${clear} has been set"

    local protocol outbound_num

    for protocol in 'TRJ' 'VLESS'
    do
        outbound_num=$(jq '[.outbounds[].tag] | index("proxy")' "/var/www/${subspath}/${username}-${protocol}-CLIENT.json")
        echo "$(jq ".outbounds[${outbound_num}].server = \"${cf_ip}\" | .outbounds[${outbound_num}].transport.headers |= {\"Host\":\"${domain}\"} | .route.default_http_client = \"http-proxy\"" "/var/www/${subspath}/${username}-${protocol}-CLIENT.json")" > "/var/www/${subspath}/${username}-${protocol}-CLIENT.json"
    done

    echo -e "${sci_message[1_$language]}"
    echo ""
}

remove_cf_ip() {
    local -A rci_message=()
    rci_message[1_ru]="Изменение настроек для пользователя ${textcolor}${username}${clear} завершено, IP Cloudflare убран"
    rci_message[1_en]="Changed the settings for the user ${textcolor}${username}${clear}, Cloudflare IP is removed"

    local protocol outbound_num

    for protocol in 'TRJ' 'VLESS'
    do
        outbound_num=$(jq '[.outbounds[].tag] | index("proxy")' "/var/www/${subspath}/${username}-${protocol}-CLIENT.json")
        echo "$(jq ".outbounds[${outbound_num}].server = \"${domain}\" | del(.outbounds[${outbound_num}].transport.headers) | .route.default_http_client = \"http-direct\"" "/var/www/${subspath}/${username}-${protocol}-CLIENT.json")" > "/var/www/${subspath}/${username}-${protocol}-CLIENT.json"
    done

    echo -e "${rci_message[1_$language]}"
    echo ""
}

get_cf_ip_status() {
    local -A gcis_message=()
    gcis_message[1_ru]="[IP Cloudflare не выбран]"
    gcis_message[2_ru]="Выбрано:"
    gcis_message[1_en]="[Cloudflare IP is not selected]"
    gcis_message[2_en]="Selected:"

    local sel_cf_ip=$(jq -r '.outbounds[] | select(.tag == "proxy") | .server' "/var/www/${subspath}/${username}-TRJ-CLIENT.json")
    cf_ip_status="${gcis_message[1_$language]}"
    [[ $sel_cf_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && cf_ip_status="[${gcis_message[2_$language]} ${sel_cf_ip}]"
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

edit_configs_cf_ip() {
    local cf_ip

    case "$cf_option" in
        1)
        enter_check_cf_ip
        set_cf_ip
        ;;
        2)
        remove_cf_ip
        ;;
        *)
        return 111
    esac
}

cf_ip_settings() {
    local username cf_ip_status cf_option
    check_variant; [[ $? -eq 111 ]] && return 111
    "cf_warn_${language}"

    while [[ ! ${username,,} =~ ^(x|х)$ ]]
    do
        enter_check_username_del; [[ $? -eq 111 ]] && return 111
        get_cf_ip_status
        "cf_text_${language}"
        check_cf_option
        edit_configs_cf_ip; [[ $? -eq 111 ]] && return 111
    done
}

### OPTION 7 - SHOW WARP DOMAINS ###

check_warp() {
    local -A cw_message=()
    cw_message[1_ru]="${red}Ошибка: в /etc/sing-box/config.json не найдено правил маршрутизации для WARP${clear}"
    cw_message[1_en]="${red}Error: no WARP routing rules found in /etc/sing-box/config.json${clear}"

    if [[ $(jq 'any(.route.rules[]; .outbound == "warp")' /etc/sing-box/config.json) != "true" ]]
    then
        echo -e "${cw_message[1_$language]}"
        echo ""
        return 111
    fi
}

show_warp_domains() {
    local -A swd_message=()
    swd_message[1_ru]="${textcolor}Список доменов/суффиксов WARP:${clear}"
    swd_message[1_en]="${textcolor}List of domains/suffixes routed through WARP:${clear}"

    check_warp; [[ $? -eq 111 ]] && return 111
    echo -e "${swd_message[1_$language]}"
    jq -r '.route.rules[] | select(.outbound == "warp") | .domain_suffix[]' /etc/sing-box/config.json
    echo ""
}

### OPTION 8 - ADD WARP DOMAINS ###

crop_new_warp() {
    new_warp=${new_warp#*"://"}
    new_warp=$(echo "${new_warp}" | cut -d "/" -f 1)
}

enter_check_domain_warp_add() {
    local -A ecdwa_message=()
    ecdwa_message[1_ru]="${textcolor}[?]${clear} Введите новый домен/суффикс для WARP или введите ${textcolor}x${clear}, чтобы закончить:"
    ecdwa_message[2_ru]="${red}Ошибка: этот домен/суффикс уже добавлен в WARP${clear}"
    ecdwa_message[1_en]="${textcolor}[?]${clear} Enter a new domain/suffix for WARP routing or enter ${textcolor}x${clear} to exit:"
    ecdwa_message[2_en]="${red}Error: this domain/suffix is already added to WARP${clear}"

    while true
    do
        echo -e "${ecdwa_message[1_$language]}"
        read -r new_warp
        [[ -n $new_warp ]] && echo ""
        crop_new_warp

        if [[ ${new_warp,,} =~ ^(x|х)$ ]]
        then
            return 111
        elif [[ -z $new_warp ]]
        then
            :
        elif [[ $(jq "any(.route.rules[] | select(.outbound == \"warp\") | .domain_suffix[]; . == \"${new_warp}\")" /etc/sing-box/config.json) != "false" ]]
        then
            echo -e "${ecdwa_message[2_$language]}"
            echo ""
        else
            break
        fi
    done
}

edit_conf_warp_add() {
    local -A ecwa_message=()
    ecwa_message[1_ru]="Домен/суффикс ${textcolor}${new_warp}${clear} добавлен в WARP"
    ecwa_message[1_en]="Domain/suffix ${textcolor}${new_warp}${clear} is added to WARP routing"

    local warp_rule_num=$(jq '[.route.rules[].outbound] | index("warp")' /etc/sing-box/config.json)
    echo "$(jq ".route.rules[${warp_rule_num}].domain_suffix += [\"${new_warp}\"]" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    systemctl reload sing-box.service
    echo -e "${ecwa_message[1_$language]}"
    echo ""
}

add_warp_domains() {
    local new_warp
    check_warp; [[ $? -eq 111 ]] && return 111

    while [[ ! ${new_warp,,} =~ ^(x|х)$ ]]
    do
        enter_check_domain_warp_add; [[ $? -eq 111 ]] && return 111
        edit_conf_warp_add
    done
}

### OPTION 9 - DELETE WARP DOMAINS ###

crop_del_warp() {
    del_warp=${del_warp#*"://"}
    del_warp=$(echo "${del_warp}" | cut -d "/" -f 1)
}

enter_check_domain_warp_del() {
    local -A ecdwd_message=()
    ecdwd_message[1_ru]="${textcolor}[?]${clear} Введите домен/суффикс для удаления из WARP или введите ${textcolor}x${clear}, чтобы закончить:"
    ecdwd_message[2_ru]="${red}Ошибка: этот домен/суффикс не добавлен в WARP${clear}"
    ecdwd_message[1_en]="${textcolor}[?]${clear} Enter a domain/suffix to delete from WARP routing or enter ${textcolor}x${clear} to exit:"
    ecdwd_message[2_en]="${red}Error: this domain/suffix is not added to WARP routing${clear}"

    while true
    do
        echo -e "${ecdwd_message[1_$language]}"
        read -r del_warp
        [[ -n $del_warp ]] && echo ""
        crop_del_warp

        if [[ ${del_warp,,} =~ ^(x|х)$ ]]
        then
            return 111
        elif [[ -z $del_warp ]]
        then
            :
        elif [[ $(jq "any(.route.rules[] | select(.outbound == \"warp\") | .domain_suffix[]; . == \"${del_warp}\")" /etc/sing-box/config.json) != "true" ]]
        then
            echo -e "${ecdwd_message[2_$language]}"
            echo ""
        else
            break
        fi
    done
}

edit_conf_warp_del() {
    local -A ecwd_message=()
    ecwd_message[1_ru]="Домен/суффикс ${textcolor}${del_warp}${clear} удалён из WARP"
    ecwd_message[1_en]="Domain/suffix ${textcolor}${del_warp}${clear} is deleted from WARP routing"

    local warp_rule_num=$(jq '[.route.rules[].outbound] | index("warp")' /etc/sing-box/config.json)
    echo "$(jq "del(.route.rules[${warp_rule_num}].domain_suffix[] | select(. == \"${del_warp}\"))" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    systemctl reload sing-box.service
    echo -e "${ecwd_message[1_$language]}"
    echo ""
}

delete_warp_domains() {
    local del_warp
    check_warp; [[ $? -eq 111 ]] && return 111

    while [[ ! ${del_warp,,} =~ ^(x|х)$ ]]
    do
        enter_check_domain_warp_del; [[ $? -eq 111 ]] && return 111
        edit_conf_warp_del
    done
}

### OPTION 10 - SETUP PROXY CHAINS ###

check_chain_option() {
    local -A ccho_message=()
    ccho_message[1_ru]="${red}Ошибка: этот сервер уже настроен как конечный в цепочке или единственный${clear}"
    ccho_message[1_en]="${red}Error: this server is already configured as the end of the chain or the only one${clear}"

    while [[ "$chain_option" == "1" ]] && [[ $(jq 'any(.outbounds[]; .tag == "proxy")' /etc/sing-box/config.json) != "true" ]]
    do
        echo -e "${ccho_message[1_$language]}"
        echo ""
        "chain_text_${language}"
    done
}

check_config_temp() {
    local -A cct_message=()
    cct_message[1_ru]="${red}Ошибка: не удалось загрузить данные с GitHub, попробуйте позже${clear}"
    cct_message[1_en]="${red}Error: failed to download data from GitHub, try again later${clear}"

    if [[ -z $config_temp ]] || ! echo "${config_temp}" | jq empty &> /dev/null
    then
        echo -e "${cct_message[1_$language]}"
        echo ""
        return 111
    fi
}

enter_check_next_link() {
    local -A ecnl_message=()
    ecnl_message[1_ru]="${textcolor}[?]${clear} Введите ссылку на клиентский конфиг со следующего сервера в цепочке или введите ${textcolor}x${clear}, чтобы выйти:"
    ecnl_message[2_ru]="${red}Ошибка: неверная ссылка на конфиг или следующий сервер не отвечает${clear}"
    ecnl_message[1_en]="${textcolor}[?]${clear} Enter the link to client config from the next server in the chain or enter ${textcolor}x${clear} to exit:"
    ecnl_message[2_en]="${red}Error: invalid link to client config or the next server does not respond${clear}"

    local next_link

    while true
    do
        echo -e "${ecnl_message[1_$language]}"
        read -r next_link
        [[ -n $next_link ]] && echo ""
        next_link=${next_link#*"://"}

        if [[ ${next_link,,} =~ ^(x|х)$ ]]
        then
            return 111
        elif [[ -z $next_link ]]
        then
            continue
        fi

        next_config=$(curl -s -m 30 "https://${next_link}" 2> /dev/null)

        if [[ -z $next_config ]] || ! echo "${next_config}" | jq empty &> /dev/null || [[ $(echo "${next_config}" | jq 'any(.outbounds[]; .tag == "proxy")') != "true" ]]
        then
            echo -e "${ecnl_message[2_$language]}"
            echo ""
        else
            break
        fi
    done
}

manage_rule_sets() {
    local ruleset_tag ruleset_data

    for ruleset_tag in "${rule_sets_add[@]}"
    do
        if [[ $(jq "any(.route.rule_set[]; .tag == \"${ruleset_tag}\")" /etc/sing-box/config.json) == "false" ]]
        then
            ruleset_data="{\"tag\":\"${ruleset_tag}\",\"type\":\"local\",\"format\":\"binary\",\"path\":\"/var/www/${rulesetpath}/geosite-${ruleset_tag}.srs\"}"
            echo "$(jq ".route.rule_set += [${ruleset_data}]" /etc/sing-box/config.json)" > /etc/sing-box/config.json
        fi

        if [[ ! -f /var/www/${rulesetpath}/geosite-${ruleset_tag}.srs ]]
        then
            wget -q -P "/var/www/${rulesetpath}" -T 30 "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-${ruleset_tag}.srs"
        fi
    done

    for ruleset_tag in "${rule_sets_del[@]}"
    do
        if [[ $(jq "any(.route.rule_set[]; .tag == \"${ruleset_tag}\")" /etc/sing-box/config.json) == "true" ]]
        then
            echo "$(jq "del(.route.rule_set[] | select(.tag == \"${ruleset_tag}\"))" /etc/sing-box/config.json)" > /etc/sing-box/config.json
        fi
    done

    chmod -R 755 "/var/www/${rulesetpath}"
}

chain_end() {
    local -A ce_message=()
    ce_message[1_ru]="Изменение настроек завершено, этот сервер настроен как конечный в цепочке или единственный"
    ce_message[1_en]="Settings changed successfully, this server is configured as the end of the chain or the only one"

    if [[ $(jq 'any(.route.rules[]; .outbound == "warp")' /etc/sing-box/config.json) == "true" ]]
    then
        local config_temp=$(curl -s -m 30 https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Config-Templates/config.json)
        check_config_temp; [[ $? -eq 111 ]] && return 111
        local warp_rule=$(echo "${config_temp}" | jq '.route.rules[] | select(.outbound == "warp")')
        local warp_rule_num=$(jq '[.route.rules[].outbound] | index("warp")' /etc/sing-box/config.json)
        echo "$(jq ".route.rules[${warp_rule_num}] |= ${warp_rule}" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

    echo "$(jq 'del(.outbounds[] | select(.tag == "proxy")) | del(.route.rules[] | select(.outbound == "proxy" or .outbound == "direct"))' /etc/sing-box/config.json)" > /etc/sing-box/config.json

    local rule_sets_add=(openai anthropic xai deviantart)
    local rule_sets_del=(telegram google)
    manage_rule_sets
    systemctl reload sing-box.service
    echo "${ce_message[1_$language]}"
    echo ""
}

chain_middle() {
    local -A cm_message=()
    cm_message[1_ru]="Изменение настроек завершено, этот сервер настроен как промежуточный в цепочке"
    cm_message[1_en]="Settings changed successfully, this server is configured as intermediate in the chain"

    local chain_outbound=$(echo "${next_config}" | jq '.outbounds[] | select(.tag == "proxy")')

    if [[ $(jq 'any(.outbounds[]; .tag == "proxy")' /etc/sing-box/config.json) == "false" ]]
    then
        if [[ $(jq 'any(.route.rules[]; .outbound == "warp")' /etc/sing-box/config.json) == "true" ]]
        then
            local warp_rule='{"domain_suffix":["example.com"],"outbound":"warp"}'
            local warp_rule_num=$(jq '[.route.rules[].outbound] | index("warp")' /etc/sing-box/config.json)
            echo "$(jq ".route.rules[${warp_rule_num}] |= ${warp_rule}" /etc/sing-box/config.json)" > /etc/sing-box/config.json
        fi

        if [[ $(jq 'any(.route.rules[]; .outbound == "direct")' /etc/sing-box/config.json) == "false" ]]
        then
            local proxy_rule=$(jq 'limit(1; .route.rules[] | select(.outbound == "proxy"))' "/var/www/${subspath}/template.json")
            local direct_rule='{"domain_suffix":[".ru",".su",".ru.com",".ru.net"],"domain_keyword":["xn--"],"rule_set":["geoip-ru","category-gov-ru"],"outbound":"direct"}'
            echo "$(jq ".route.rules |= . + [${proxy_rule}, ${direct_rule}]" /etc/sing-box/config.json)" > /etc/sing-box/config.json
        fi

        local chain_rule='{"inbound":["trojan-in","vless-in"],"outbound":"proxy"}'
        [[ -f /etc/haproxy/auth.lua ]] && chain_rule='{"inbound":["trojan-in"],"outbound":"proxy"}'
        echo "$(jq ".outbounds += [${chain_outbound}] | .route.rules += [${chain_rule}]" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    else
        local chain_out_num=$(jq '[.outbounds[].tag] | index("proxy")' /etc/sing-box/config.json)
        echo "$(jq ".outbounds[${chain_out_num}] |= ${chain_outbound}" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

    local rule_sets_add=(telegram google)
    local rule_sets_del=(openai anthropic xai deviantart)
    manage_rule_sets
    systemctl reload sing-box.service
    echo "${cm_message[1_$language]}"
    echo ""
}

get_chain_sel() {
    local -A gcs_message=()
    gcs_message[1_ru]="Выбрано"
    gcs_message[1_en]="Selected"

    chain_sel_1=""; chain_sel_2=""

    if [[ $(jq 'any(.outbounds[]; .tag == "proxy")' /etc/sing-box/config.json) != "true" ]]
    then
        chain_sel_1="[${gcs_message[1_$language]}]"
    else
        chain_sel_2="[${gcs_message[1_$language]}: $(jq -r '.outbounds[] | select(.tag == "proxy") | .server' /etc/sing-box/config.json)]"
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
    local next_config chain_sel_1 chain_sel_2 chain_option
    get_chain_sel
    "chain_text_${language}"
    check_chain_option

    case "$chain_option" in
        1)
        chain_end
        ;;
        2)
        check_github_template; [[ $? -eq 111 ]] && return 111
        enter_check_next_link; [[ $? -eq 111 ]] && return 111
        chain_middle
    esac
}

### OPTION 11 - RENEW CERTIFICATE MANUALLY ###

cert_clean_up() {
    local warn_file=$(python3 -c "import os, CloudFlare; print(os.path.join(os.path.dirname(CloudFlare.__file__), 'warning_2_20.py'))")
    [[ $(dpkg -s python3-cloudflare | grep -i '^version') =~ "2.20." ]] && sed -i 's/2\.20\./2\.25\./g' "${warn_file}" &> /dev/null

    local domain_del="${domain}"
    [[ "$option" == "12" ]] && domain_del="${domain_old}"
    certbot delete --cert-name "${domain_del}" --quiet &> /dev/null
}

cert_final_text() {
    if [[ $? -ne 0 ]]
    then
        local -A cft_message=()
        cft_message[1_ru]="${red}Ошибка: не удалось выпустить сертификат, попробуйте позже или смените домен/поддомен с помощью пункта 12${clear}"
        cft_message[1_en]="${red}Error: failed to issue the certificate, try again later or change the domain/subdomain with option 12${clear}"

        echo ""
        echo -e "${cft_message[1_$language]}"
    fi
}

reissue_cert() {
    local -A rc_message=()
    rc_message[1_ru]="${textcolor}Получение сертификата...${clear}"
    rc_message[1_en]="${textcolor}Requesting a certificate...${clear}"

    echo -e "${rc_message[1_$language]}"

    if [[ -f /etc/letsencrypt/cloudflare.credentials ]]
    then
        certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.credentials --dns-cloudflare-propagation-seconds 35 -d "${domain},*.${domain}" --agree-tos --non-interactive --register-unsafely-without-email
        cert_final_text
    else
        ufw allow 80 &> /dev/null
        certbot certonly --standalone --preferred-challenges http -d "${domain}" --agree-tos --non-interactive --register-unsafely-without-email
        cert_final_text
        ufw delete allow 80 &> /dev/null
    fi

    if [[ ! -f /etc/haproxy/auth.lua ]] && [[ -f /etc/letsencrypt/live/${domain}/fullchain.pem ]]
    then
        echo "renew_hook = systemctl reload nginx.service" >> "/etc/letsencrypt/renewal/${domain}.conf"
        systemctl restart nginx.service
    elif [[ -f /etc/haproxy/auth.lua ]] && [[ -f /etc/letsencrypt/live/${domain}/fullchain.pem ]]
    then
        echo "renew_hook = cat /etc/letsencrypt/live/${domain}/fullchain.pem /etc/letsencrypt/live/${domain}/privkey.pem > /etc/haproxy/certs/${domain}.pem && systemctl reload haproxy.service" >> "/etc/letsencrypt/renewal/${domain}.conf"
        cat "/etc/letsencrypt/live/${domain}/fullchain.pem" "/etc/letsencrypt/live/${domain}/privkey.pem" > "/etc/haproxy/certs/${domain}.pem"
        systemctl restart haproxy.service
    fi

    echo ""
}

cert_renewal() {
    local -A cr_message=()
    cr_message[1_ru]="${textcolor}Обновление сертификата...${clear}"
    cr_message[1_en]="${textcolor}Renewing the certificate...${clear}"

    echo -e "${cr_message[1_$language]}"
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
    local cert_renew; read -r cert_renew
    [[ -n $cert_renew ]] && echo ""
    [[ ${cert_renew,,} =~ ^(x|х)$ ]] && return 111
}

renew_cert_text_en() {
    echo -e "${red}ATTENTION!${clear}"
    echo "The script has a built-in automatic certificate renewal every 2 months, and manual renewal is recommended only in case of failures"
    echo "Renewing a certificate more than 5 times a week can result in reaching the Let's Encrypt limit, requiring you to wait before the next renewal"
    echo ""
    echo -e "${textcolor}[?]${clear} Press ${textcolor}Enter${clear} to renew certificate or enter ${textcolor}x${clear} to exit:"
    local cert_renew; read -r cert_renew
    [[ -n $cert_renew ]] && echo ""
    [[ ${cert_renew,,} =~ ^(x|х)$ ]] && return 111
}

renew_cert() {
    "renew_cert_text_${language}"; [[ $? -eq 111 ]] && return 111

    if [[ -f /etc/letsencrypt/live/${domain}/fullchain.pem ]]
    then
        cert_renewal
    else
        cert_clean_up
        reissue_cert
    fi
}

### OPTION 12 - CHANGE DOMAIN ###

crop_domain() {
    domain=${domain#*"://"}
    domain=$(echo "${domain}" | cut -d "/" -f 1 | sed 's/\.\{2,\}/./g')
    domain=${domain#"www."}
}

enter_domain_data() {
    local -A edd_message=()
    edd_message[1_ru]="${textcolor}[?]${clear} Введите новый домен или введите ${textcolor}x${clear}, чтобы выйти:"
    edd_message[2_ru]="${textcolor}[?]${clear} Введите ваш API токен Cloudflare (Edit zone DNS):"
    edd_message[1_en]="${textcolor}[?]${clear} Enter new domain name or enter ${textcolor}x${clear} to exit:"
    edd_message[2_en]="${textcolor}[?]${clear} Enter your Cloudflare API token (Edit zone DNS):"

    domain=""; cf_token=""
    echo ""

    while [[ -z $domain ]]
    do
        echo -e "${edd_message[1_$language]}"
        read -r domain
        [[ -n $domain ]] && echo ""
    done

    [[ ${domain,,} =~ ^(x|х)$ ]] && domain="${domain_old}" && return 111
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
        enter_domain_data; [[ $? -eq 111 ]] && return 111
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

issue_cert_dns_cf() {
    echo "dns_cloudflare_api_token = ${cf_token}" > /etc/letsencrypt/cloudflare.credentials
    chown root:root /etc/letsencrypt/cloudflare.credentials
    chmod 600 /etc/letsencrypt/cloudflare.credentials

    echo -e "${cvo_message[3_$language]}"
    certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.credentials --dns-cloudflare-propagation-seconds 35 -d "${domain},*.${domain}" --agree-tos --non-interactive --register-unsafely-without-email

    if [[ $? -ne 0 ]]
    then
        sleep 3
        echo ""
        echo -e "${cvo_message[4_$language]}"
        certbot delete --cert-name "${domain}" --quiet &> /dev/null
        certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.credentials --dns-cloudflare-propagation-seconds 35 -d "${domain},*.${domain}" --agree-tos --non-interactive --register-unsafely-without-email
    fi

    crontab -l | sed 's/.*certbot -q renew.*/0 2 * * * certbot -q renew/' | crontab -
}

issue_cert_standalone() {
    rm -f /etc/letsencrypt/cloudflare.credentials
    ufw allow 80 &> /dev/null

    echo -e "${cvo_message[3_$language]}"
    certbot certonly --standalone --preferred-challenges http -d "${domain}" --agree-tos --non-interactive --register-unsafely-without-email

    if [[ $? -ne 0 ]]
    then
        sleep 3
        echo ""
        echo -e "${cvo_message[4_$language]}"
        certbot delete --cert-name "${domain}" --quiet &> /dev/null
        certbot certonly --standalone --preferred-challenges http -d "${domain}" --agree-tos --non-interactive --register-unsafely-without-email
    fi

    ufw delete allow 80 &> /dev/null
    crontab -l | sed 's/.*certbot -q renew.*/0 2 * * * ufw allow 80 \&\& certbot -q renew; ufw delete allow 80/' | crontab -
}

manage_frontend() {
    if [[ ! -f /etc/haproxy/auth.lua ]]
    then
        echo "renew_hook = systemctl reload nginx.service" >> "/etc/letsencrypt/renewal/${domain}.conf"
        sed -i "s/${domain_old}/${domain}/g" /etc/nginx/nginx.conf
        systemctl reload nginx.service || systemctl start nginx.service
    else
        rm -f "/etc/haproxy/certs/${domain_old}.pem"
        echo "renew_hook = cat /etc/letsencrypt/live/${domain}/fullchain.pem /etc/letsencrypt/live/${domain}/privkey.pem > /etc/haproxy/certs/${domain}.pem && systemctl reload haproxy.service" >> "/etc/letsencrypt/renewal/${domain}.conf"
        cat "/etc/letsencrypt/live/${domain}/fullchain.pem" "/etc/letsencrypt/live/${domain}/privkey.pem" > "/etc/haproxy/certs/${domain}.pem"
        sed -i "s/${domain_old}/${domain}/g" /etc/haproxy/haproxy.cfg
        systemctl reload haproxy.service || systemctl start haproxy.service
    fi
}

edit_subs_files() {
    local -A esf_message=()
    esf_message[1_ru]="Домен ${textcolor}${domain_old}${clear} заменён на ${textcolor}${domain}${clear}"
    esf_message[2_ru]="Не забудьте заново добавить конфиги на клиентах:"
    esf_message[1_en]="Domain ${textcolor}${domain_old}${clear} changed to ${textcolor}${domain}${clear}"
    esf_message[2_en]="Don't forget to re-add configs to client apps:"

    local file

    for file in /var/www/"${subspath}"/*-CLIENT.json
    do
        sed -i "s/${domain_old}/${domain}/g" "${file}"
    done

    [[ -f /var/www/${subspath}/sub.html ]] && sed -i "s/${domain_old}/${domain}/g" "/var/www/${subspath}/sub.html"
    echo ""
    echo -e "${esf_message[1_$language]}"
    echo ""
    echo -e "${esf_message[2_$language]}"
    echo "https://${domain}/${subspath}/sub.html"
    echo ""
}

get_old_values() {
    domain_old="${domain}"
    validation_old="DNS Cloudflare"
    [[ ! -f /etc/letsencrypt/cloudflare.credentials ]] && validation_old="Standalone"
}

change_domain_text_ru() {
    echo -e "${red}ВНИМАНИЕ!${clear}"
    echo "Перед тем, как поменять домен, не забудьте создать А запись для нового домена"
    echo "Инструкция: https://github.com/A-Zuro/Secret-Sing-Box/blob/main/.github/cf-settings-ru.md#настройки-dns"
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
    echo "Before changing the domain, don't forget to create an A record for the new domain"
    echo "Instruction: https://github.com/A-Zuro/Secret-Sing-Box/blob/main/.github/cf-settings-en.md#dns-settings"
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
    local -A cvo_message=()
    cvo_message[1_ru]="${red}ВНИМАНИЕ!${clear}"
    cvo_message[2_ru]="Обязательно проверьте правильность написания домена"
    cvo_message[3_ru]="${textcolor}Получение сертификата...${clear}"
    cvo_message[4_ru]="${textcolor}Получение сертификата: 2-я попытка...${clear}"
    cvo_message[1_en]="${red}ATTENTION!${clear}"
    cvo_message[2_en]="Be sure to check the spelling of the domain name"
    cvo_message[3_en]="${textcolor}Requesting a certificate...${clear}"
    cvo_message[4_en]="${textcolor}Requesting a certificate: 2nd attempt...${clear}"

    local cf_token

    case "$validation_type" in
        1)
        enter_check_domain; [[ $? -eq 111 ]] && return 111
        cert_clean_up
        issue_cert_dns_cf
        ;;
        2)
        echo ""
        echo -e "${cvo_message[1_$language]}"
        echo "${cvo_message[2_$language]}"
        enter_check_domain; [[ $? -eq 111 ]] && return 111
        cert_clean_up
        issue_cert_standalone
        ;;
        *)
        [[ -n $validation_type ]] && echo ""
        return 111
    esac
}

change_domain() {
    local domain_old validation_old validation_type
    get_old_values
    "change_domain_text_${language}"
    cert_validation_options; [[ $? -eq 111 ]] && return 111
    manage_frontend
    edit_subs_files
}

### OPTION 13 - CHANGE PATHS ###

change_paths_text_ru() {
    echo -e "${red}ВНИМАНИЕ!${clear}"
    echo "Здесь вы можете поменять пути, если они были скомпрометированы"
    echo "После этого старые пути перестанут работать"
    echo ""
    echo -e "${textcolor}[?]${clear} Нажмите ${textcolor}Enter${clear}, чтобы продолжить, или введите ${textcolor}x${clear}, чтобы выйти:"
    local paths_change; read -r paths_change
    [[ -n $paths_change ]] && echo ""
    [[ ${paths_change,,} =~ ^(x|х)$ ]] && return 111
}

change_paths_text_en() {
    echo -e "${red}ATTENTION!${clear}"
    echo "Here you can change the paths if they were compromised"
    echo "After this, the old paths will stop working"
    echo ""
    echo -e "${textcolor}[?]${clear} Press ${textcolor}Enter${clear} to continue or enter ${textcolor}x${clear} to exit:"
    local paths_change; read -r paths_change
    [[ -n $paths_change ]] && echo ""
    [[ ${paths_change,,} =~ ^(x|х)$ ]] && return 111
}

old_paths() {
    trojanpath_old="${trojanpath}"
    vlesspath_old="${vlesspath}"
    subspath_old="${subspath}"
    rulesetpath_old="${rulesetpath}"
    old_paths_list=("$trojanpath_old" "$vlesspath_old" "$subspath_old" "$rulesetpath_old")
}

enter_check_trojan_path() {
    local -A ectp_message=()
    ectp_message[1_ru]="${textcolor}[?]${clear} Введите путь для Trojan или оставьте пустым для генерации случайного пути:"
    ectp_message[2_ru]="${red}Ошибка: путь должен содержать только английские буквы, цифры, символы _ и -${clear}"
    ectp_message[3_ru]="${red}Ошибка: новый путь не должен совпадать ни с одним из старых путей${clear}"
    ectp_message[1_en]="${textcolor}[?]${clear} Enter your path for Trojan or leave this empty to generate a random path:"
    ectp_message[2_en]="${red}Error: the path should contain only letters, numbers, _ and - symbols${clear}"
    ectp_message[3_en]="${red}Error: the new path should not match with any of the old paths${clear}"

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
        elif printf '%s\n' "${old_paths_list[@]}" | grep -xFq "${trojanpath}" && [[ -n $trojanpath ]]
        then
            echo -e "${ectp_message[3_$language]}"
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
    ecvp_message[4_ru]="${red}Ошибка: новый путь не должен совпадать ни с одним из старых путей${clear}"
    ecvp_message[1_en]="${textcolor}[?]${clear} Enter your path for VLESS or leave this empty to generate a random path:"
    ecvp_message[2_en]="${red}Error: the path should contain only letters, numbers, _ and - symbols${clear}"
    ecvp_message[3_en]="${red}Error: paths for Trojan and VLESS must be different${clear}"
    ecvp_message[4_en]="${red}Error: the new path should not match with any of the old paths${clear}"

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
        elif printf '%s\n' "${old_paths_list[@]}" | grep -xFq "${vlesspath}" && [[ -n $vlesspath ]]
        then
            echo -e "${ecvp_message[4_$language]}"
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
    ecsp_message[4_ru]="${red}Ошибка: новый путь не должен совпадать ни с одним из старых путей${clear}"
    ecsp_message[1_en]="${textcolor}[?]${clear} Enter your subscription path or leave this empty to generate a random path:"
    ecsp_message[2_en]="${red}Error: the path should contain only letters, numbers, _ and - symbols${clear}"
    ecsp_message[3_en]="${red}Error: paths for Trojan, VLESS and subscription must be different${clear}"
    ecsp_message[4_en]="${red}Error: the new path should not match with any of the old paths${clear}"

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
        elif printf '%s\n' "${old_paths_list[@]}" | grep -xFq "${subspath}" && [[ -n $subspath ]]
        then
            echo -e "${ecsp_message[4_$language]}"
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
    ecrp_message[3_ru]="${red}Ошибка: пути для ${paths_to_change}подписки и наборов правил должны быть разными${clear}"
    ecrp_message[4_ru]="${red}Ошибка: новый путь не должен совпадать ни с одним из старых путей${clear}"
    ecrp_message[1_en]="${textcolor}[?]${clear} Enter your path for rule sets or leave this empty to generate a random path:"
    ecrp_message[2_en]="${red}Error: the path should contain only letters, numbers, _ and - symbols${clear}"
    ecrp_message[3_en]="${red}Error: paths for ${paths_to_change}subscription and rule sets must be different${clear}"
    ecrp_message[4_en]="${red}Error: the new path should not match with any of the old paths${clear}"

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
        elif printf '%s\n' "${old_paths_list[@]}" | grep -xFq "${rulesetpath}" && [[ -n $rulesetpath ]]
        then
            echo -e "${ecrp_message[4_$language]}"
            echo ""
        else
            break
        fi
    done
}

generate_paths() {
    [[ -z $trojanpath ]] && [[ ! -f /etc/haproxy/auth.lua ]] && trojanpath=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30)
    [[ -z $vlesspath ]] && [[ ! -f /etc/haproxy/auth.lua ]] && vlesspath=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30)
    [[ -z $subspath ]] && subspath=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30)
    [[ -z $rulesetpath ]] && rulesetpath=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 30)
}

edit_configs_with_paths() {
    local -A ecwp_message=()
    ecwp_message[1_ru]="Старые пути для ${paths_to_change}подписки и наборов правил заменены на новые"
    ecwp_message[2_ru]="Не забудьте заново добавить конфиги на клиентах:"
    ecwp_message[1_en]="Old paths for ${paths_to_change}subscription and rule sets were changed to new ones"
    ecwp_message[2_en]="Don't forget to re-add configs to client apps:"

    sed -i "s/${rulesetpath_old}/${rulesetpath}/g" /etc/sing-box/config.json
    sed -i -e "s/${subspath_old}/${subspath}/g" -e "s/${rulesetpath_old}/${rulesetpath}/g" /etc/nginx/nginx.conf

    if [[ -f /etc/haproxy/haproxy.cfg ]]
    then
        sed -i -e "s/${subspath_old}/${subspath}/g" -e "s/${rulesetpath_old}/${rulesetpath}/g" /etc/haproxy/haproxy.cfg
    else
        local inbound_num_tr=$(jq '[.inbounds[].tag] | index("trojan-in")' /etc/sing-box/config.json)
        local inbound_num_vl=$(jq '[.inbounds[].tag] | index("vless-in")' /etc/sing-box/config.json)
        echo "$(jq ".inbounds[${inbound_num_tr}].transport.path = \"/${trojanpath}\" | .inbounds[${inbound_num_vl}].transport.path = \"/${vlesspath}\"" /etc/sing-box/config.json)" > /etc/sing-box/config.json
        sed -i -e "s/${trojanpath_old}/${trojanpath}/g" -e "s/${vlesspath_old}/${vlesspath}/g" /etc/nginx/nginx.conf
    fi

    local file outbound_num new_path

    for file in /var/www/"${subspath_old}"/*-CLIENT.json
    do
        sed -i "s/${rulesetpath_old}/${rulesetpath}/g" "${file}"
        [[ -f /etc/haproxy/auth.lua ]] && continue
        outbound_num=$(jq '[.outbounds[].tag] | index("proxy")' "${file}")
        new_path="/${trojanpath}"
        [[ $(jq -r ".outbounds[${outbound_num}].type" "${file}") == "vless" ]] && new_path="/${vlesspath}"
        echo "$(jq ".outbounds[${outbound_num}].transport.path = \"${new_path}\"" "${file}")" > "${file}"
    done

    sed -i "s/${subspath_old}/${subspath}/g" "/var/www/${subspath_old}/sub.html"
    mv -f "/var/www/${subspath_old}" "/var/www/${subspath}"
    mv -f "/var/www/${rulesetpath_old}" "/var/www/${rulesetpath}"
    systemctl reload sing-box.service nginx.service
    [[ -f /etc/haproxy/auth.lua ]] && systemctl reload haproxy.service

    echo "${ecwp_message[1_$language]}"
    echo ""
    echo "${ecwp_message[2_$language]}"
    echo "https://${domain}/${subspath}/sub.html"
    echo ""
}

change_paths() {
    local trojanpath_old vlesspath_old subspath_old rulesetpath_old old_paths_list
    "change_paths_text_${language}"; [[ $? -eq 111 ]] && return 111
    old_paths

    if [[ ! -f /etc/haproxy/auth.lua ]]
    then
        enter_check_trojan_path
        enter_check_vless_path
    fi

    enter_check_subs_path
    enter_check_ruleset_path
    generate_paths
    edit_configs_with_paths
}

### OPTION 14 - DISABLE IPv6 ###

disable_ipv6() {
    local -A dip6_message=()
    dip6_message[1_ru]="${textcolor}IPv6 отключён:${clear}"
    dip6_message[1_en]="${textcolor}IPv6 is disabled:${clear}"

    local sysctl_entry

    for sysctl_entry in 'net.ipv6.conf.all.disable_ipv6 = 1' 'net.ipv6.conf.default.disable_ipv6 = 1' 'net.ipv6.conf.lo.disable_ipv6 = 1'
    do
        grep -q "${sysctl_entry}" /etc/sysctl.d/99-ssb.conf &> /dev/null || echo "${sysctl_entry}" >> /etc/sysctl.d/99-ssb.conf
    done

    echo -e "${dip6_message[1_$language]}"
    sysctl --system &> /dev/null
    sysctl net.ipv6.conf.all.disable_ipv6 net.ipv6.conf.default.disable_ipv6 net.ipv6.conf.lo.disable_ipv6
    echo ""
}

### OPTION 15 - ENABLE IPv6 ###

enable_ipv6() {
    local -A eip6_message=()
    eip6_message[1_ru]="${textcolor}IPv6 включён:${clear}"
    eip6_message[2_ru]="${red}ВНИМАНИЕ!${clear}"
    eip6_message[3_ru]="Для применения новых настроек рекомендуется перезагрузить сервер командой ${textcolor}reboot${clear}"
    eip6_message[1_en]="${textcolor}IPv6 is enabled:${clear}"
    eip6_message[2_en]="${red}ATTENTION!${clear}"
    eip6_message[3_en]="To apply the new settings, it is recommended to reboot the server with ${textcolor}reboot${clear} command"

    local sysctl_file

    for sysctl_file in '/etc/sysctl.d/99-ssb.conf' '/etc/sysctl.conf'
    do
        sed -i -e "/net.ipv6.conf.all.disable_ipv6 = 1/d" -e "/net.ipv6.conf.default.disable_ipv6 = 1/d" -e "/net.ipv6.conf.lo.disable_ipv6 = 1/d" "${sysctl_file}" &> /dev/null
    done

    echo -e "${eip6_message[1_$language]}"
    sysctl --system &> /dev/null
    sysctl -w net.ipv6.conf.all.disable_ipv6=0 -w net.ipv6.conf.default.disable_ipv6=0 -w net.ipv6.conf.lo.disable_ipv6=0
    echo ""
    echo -e "${eip6_message[2_$language]}"
    echo -e "${eip6_message[3_$language]}"
    echo ""
}

### OPTION 16 - SHOW PATHS TO IMPORTANT FILES ###

show_paths_ru() {
    echo -e "${textcolor}Страница выдачи подписок пользователей:${clear}"
    local username=$(ls -A1 "/var/www/${subspath}" | grep "\-CLIENT.json" | sed -e "s/-TRJ-CLIENT\.json//g" -e "s/-VLESS-CLIENT\.json//g" | uniq | tail -n 1)
    echo -e "https://${domain}/${subspath}/sub.html${grey}?name=${username}${clear}"
    echo "Серым текстом показан пример автозаполнения поля с именем пользователя"
    echo ""

    echo -e "${textcolor}Конфигурация сервисов:${clear}"
    echo "Конфиг Sing-Box                     /etc/sing-box/config.json"
    echo "Конфиг NGINX                        /etc/nginx/nginx.conf"

    if [[ -f /etc/haproxy/haproxy.cfg ]]
    then
        echo "Конфиг HAProxy                      /etc/haproxy/haproxy.cfg"
        echo "Скрипт, считывающий пароли Trojan   /etc/haproxy/auth.lua"
    fi

    echo ""
    echo -e "${textcolor}Контент, доставляемый с помощью NGINX:${clear}"
    echo "Директория подписки                 /var/www/${subspath}/"
    echo "Директория c наборами правил        /var/www/${rulesetpath}/"
    local site_dir=$(grep "/var/www/" /etc/nginx/nginx.conf | head -n 1 | cut -d "/" -f 4 | cut -d ";" -f 1)
    [[ -d /var/www/${site_dir} ]] && echo "Директория cайта                    /var/www/${site_dir}/"
    echo ""

    echo -e "${textcolor}Сертификаты и вспомогательные файлы:${clear}"
    echo "Директория с сертификатами          /etc/letsencrypt/live/${domain}/"
    [[ -f /etc/haproxy/certs/${domain}.pem ]] && echo "Объединённый файл с сертификатами   /etc/haproxy/certs/${domain}.pem"
    echo "Конфиг обновления сертификатов      /etc/letsencrypt/renewal/${domain}.conf"
    [[ -f /etc/letsencrypt/cloudflare.credentials ]] && echo "Файл с API токеном Cloudflare       /etc/letsencrypt/cloudflare.credentials"
    echo ""

    echo -e "${textcolor}Скрипты:${clear}"
    echo "Этот скрипт (меню настроек)         /usr/local/bin/sbmanager"
    echo "Скрипт, обновляющий наборы правил   /usr/local/bin/rsupdate"
    echo ""
    echo ""
    exit 0
}

show_paths_en() {
    echo -e "${textcolor}Subscription page:${clear}"
    local username=$(ls -A1 "/var/www/${subspath}" | grep "\-CLIENT.json" | sed -e "s/-TRJ-CLIENT\.json//g" -e "s/-VLESS-CLIENT\.json//g" | uniq | tail -n 1)
    echo -e "https://${domain}/${subspath}/sub.html${grey}?name=${username}${clear}"
    echo "Grey text shows an example of autofilling the username field"
    echo ""

    echo -e "${textcolor}Configuration of the services:${clear}"
    echo "Sing-Box config                   /etc/sing-box/config.json"
    echo "NGINX config                      /etc/nginx/nginx.conf"

    if [[ -f /etc/haproxy/haproxy.cfg ]]
    then
        echo "HAProxy config                    /etc/haproxy/haproxy.cfg"
        echo "Trojan password reading script    /etc/haproxy/auth.lua"
    fi

    echo ""
    echo -e "${textcolor}Content delivered by NGINX:${clear}"
    echo "Subscription directory            /var/www/${subspath}/"
    echo "Rule set directory                /var/www/${rulesetpath}/"
    local site_dir=$(grep "/var/www/" /etc/nginx/nginx.conf | head -n 1 | cut -d "/" -f 4 | cut -d ";" -f 1)
    [[ -d /var/www/${site_dir} ]] && echo "Site directory                    /var/www/${site_dir}/"
    echo ""

    echo -e "${textcolor}Certificates and accessory files:${clear}"
    echo "Certificate directory             /etc/letsencrypt/live/${domain}/"
    [[ -f /etc/haproxy/certs/${domain}.pem ]] && echo "Combined file with certificates   /etc/haproxy/certs/${domain}.pem"
    echo "Certificate renewal config        /etc/letsencrypt/renewal/${domain}.conf"
    [[ -f /etc/letsencrypt/cloudflare.credentials ]] && echo "File with Cloudflare API token    /etc/letsencrypt/cloudflare.credentials"
    echo ""

    echo -e "${textcolor}Scripts:${clear}"
    echo "This script (settings menu)       /usr/local/bin/sbmanager"
    echo "Rule set renewal script           /usr/local/bin/rsupdate"
    echo ""
    echo ""
    exit 0
}

### OPTION 17 - UPDATE SSB ###

update_ssb() {
    local -A us_message=()
    us_message[1_ru]="${red}Ошибка: не удалось загрузить данные с GitHub, попробуйте позже${clear}"
    us_message[1_en]="${red}Error: failed to download data from GitHub, try again later${clear}"

    local update_script=$(curl -Ls -m 30 https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Scripts/update-server.sh)

    if [[ $update_script =~ '#!/bin/bash' ]]
    then
        export version="1.5.5" language
        export -f get_ip templates get_data check_users check_github_template get_pass edit_configs_loop add_rule_sets_loop sync_client_configs_main
        bash <(echo "${update_script}")
        exit 0
    else
        echo -e "${us_message[1_$language]}"
        echo ""
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
    echo "13 - Поменять пути для ${paths_to_change}подписки и наборов правил"
    echo "---------------------------------"
    echo "14 - Отключить IPv6 на сервере"
    echo "15 - Включить IPv6 на сервере"
    echo "---------------------------------"
    echo "16 - Показать пути до конфигов и других значимых файлов"
    echo "17 - Обновить"
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
    echo "13 - Change paths for ${paths_to_change}subscription and rule sets"
    echo "---------------------------------"
    echo "14 - Disable IPv6 on the server"
    echo "15 - Enable IPv6 on the server"
    echo "---------------------------------"
    echo "16 - Show paths to configs and other important files"
    echo "17 - Update"
    read -r option
    [[ -n $option ]] && echo ""
}

main_menu() {
    while true
    do
        [[ ! -f /etc/haproxy/auth.lua ]] && paths_to_change="Trojan, VLESS, "
        "main_menu_text_${language}"

        case "$option" in
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
            change_paths
            ;;
            14)
            disable_ipv6
            ;;
            15)
            enable_ipv6
            ;;
            16)
            "show_paths_${language}"
            ;;
            17)
            update_ssb
            ;;
            *)
            exit 0
        esac
    done
}

check_root
check_config_json
banner
get_data
main_menu
