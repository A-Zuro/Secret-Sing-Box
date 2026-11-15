#!/bin/bash
set -o pipefail

textcolor='\033[1;36m'
textcolor_light='\033[1;37m'
red='\033[1;31m'
clear='\033[0m'

check_parent() {
    if [[ -z $version ]]
    then
        echo -e "${red}Error: this script should be run from the settings menu, not manually${clear}"
        exit 1
    fi
}

check_update() {
    local -A cu_message=()
    cu_message[1_ru]="Установлена последняя версия:"
    cu_message[2_ru]="Текущая версия:"
    cu_message[3_ru]="Доступна новая версия:"
    cu_message[1_en]="The latest version is already installed:"
    cu_message[2_en]="Current version:"
    cu_message[3_en]="New version is available:"

    new_version="1.5.5"

    if [[ "$version" == "$new_version" ]]
    then
        echo -e "${cu_message[1_$language]} ${textcolor}v${version}${clear}"
        echo ""
        exit 0
    else
        echo -e "${cu_message[2_$language]} ${textcolor}v${version}${clear}"
        echo -e "${cu_message[3_$language]} ${textcolor}v${new_version}${clear}"
    fi
}

extract_values() {
    local inbound_num_tr=$(jq '[.inbounds[].tag] | index("trojan-in")' /etc/sing-box/config.json)
    users_tr=$(jq ".inbounds[${inbound_num_tr}].users" /etc/sing-box/config.json)

    if [[ ! -f /etc/haproxy/auth.lua ]]
    then
        local inbound_num_vl=$(jq '[.inbounds[].tag] | index("vless-in")' /etc/sing-box/config.json)
        users_vl=$(jq ".inbounds[${inbound_num_vl}].users" /etc/sing-box/config.json)
        transport=$(jq -r '.inbounds[] | select(.tag == "trojan-in") | .transport.type' /etc/sing-box/config.json)
    fi

    if [[ $(jq 'any(.route.rules[]; .outbound == "warp")' /etc/sing-box/config.json) == "true" ]]
    then
        warp_domain_suffix=$(jq '.route.rules[] | select(.outbound == "warp") | .domain_suffix' /etc/sing-box/config.json)
    fi

    if [[ $(jq 'any(.outbounds[]; .tag == "proxy")' /etc/sing-box/config.json) == "true" ]]
    then
        chain_outbound=$(jq '.outbounds[] | select(.tag == "proxy")' /etc/sing-box/config.json)
    fi
}

insert_values() {
    local inbound_num_tr=$(jq '[.inbounds[].tag] | index("trojan-in")' /etc/sing-box/config.json)
    local inbound_num_vl=$(jq '[.inbounds[].tag] | index("vless-in")' /etc/sing-box/config.json)
    echo "$(jq ".inbounds[${inbound_num_tr}].users |= ${users_tr} | .inbounds[${inbound_num_tr}].transport.path = \"/${trojanpath}\"" /etc/sing-box/config.json)" > /etc/sing-box/config.json

    if [[ ! -f /etc/haproxy/auth.lua ]]
    then
        echo "$(jq ".inbounds[${inbound_num_vl}].users |= ${users_vl} | .inbounds[${inbound_num_vl}].transport.path = \"/${vlesspath}\"" /etc/sing-box/config.json)" > /etc/sing-box/config.json
        [[ "$transport" == "httpupgrade" ]] && echo "$(jq '.inbounds[].transport.type = "httpupgrade"' /etc/sing-box/config.json)" > /etc/sing-box/config.json
    else
        echo "$(jq "del(.inbounds[${inbound_num_tr}].transport.type, .inbounds[${inbound_num_tr}].transport.path, .inbounds[${inbound_num_vl}])" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

    if [[ -n $warp_domain_suffix ]]
    then
        warp_rule_num=$(jq '[.route.rules[].outbound] | index("warp")' /etc/sing-box/config.json)
        echo "$(jq ".route.rules[${warp_rule_num}].domain_suffix |= ${warp_domain_suffix}" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

    local rule_sets_add=() rule_sets_del=()

    if [[ -n $chain_outbound ]] && check_github_template &> /dev/null
    then
        insert_chain
        rule_sets_add=(telegram google)
        rule_sets_del=(openai anthropic xai deviantart)
    fi

    sed -i "s/RULESETPATH/${rulesetpath}/g" /etc/sing-box/config.json
    manage_rule_sets
    chmod -R 755 "/var/www/${rulesetpath}"
}

insert_chain() {
    warp_rule_num=$(jq '[.route.rules[].outbound] | index("warp")' /etc/sing-box/config.json)
    echo "$(jq "del(.route.rules[${warp_rule_num}].domain_keyword, .route.rules[${warp_rule_num}].rule_set)" /etc/sing-box/config.json)" > /etc/sing-box/config.json

    if [[ $(jq 'any(.route.rules[]; .outbound == "direct")' /etc/sing-box/config.json) == "false" ]]
    then
        local proxy_rule=$(jq 'limit(1; .route.rules[] | select(.outbound == "proxy"))' "/var/www/${subspath}/template.json")
        local direct_rule='{"domain_suffix":[".ru",".su",".ru.com",".ru.net"],"domain_keyword":["xn--"],"rule_set":["geoip-ru","category-gov-ru"],"outbound":"direct"}'
        echo "$(jq ".route.rules |= . + [${proxy_rule}, ${direct_rule}]" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

    local chain_rule='{"inbound":["trojan-in","vless-in"],"outbound":"proxy"}'
    [[ -f /etc/haproxy/auth.lua ]] && chain_rule='{"inbound":["trojan-in"],"outbound":"proxy"}'
    echo "$(jq ".outbounds += [${chain_outbound}] | .route.rules += [${chain_rule}]" /etc/sing-box/config.json)" > /etc/sing-box/config.json
}

manage_rule_sets() {
    [[ ! -f /var/www/${rulesetpath}/bypass-apps.json ]] && wget -q -P "/var/www/${rulesetpath}" -T 30 https://raw.githubusercontent.com/FPPweb3/sb-rule-sets/main/bypass-apps.json   # Legacy v1.5.5
    local ruleset_ind ruleset_link ruleset ruleset_tag ruleset_data

    for ruleset_ind in $(seq 0 "$(jq '.route.rule_set | length - 1' /etc/sing-box/config.json)")
    do
        ruleset_link=$(jq -r ".route.rule_set[${ruleset_ind}].path" /etc/sing-box/config.json)
        [[ ! $ruleset_link =~ "geosite-" ]] && continue
        ruleset=${ruleset_link#"/var/www/${rulesetpath}/geosite-"}
        ruleset=${ruleset%".srs"}
        rule_sets_add+=("$ruleset")
    done

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
}

manage_sb_config() {
    local users_tr users_vl transport warp_domain_suffix chain_outbound warp_rule_num

    extract_values
    cp -f /etc/sing-box/config.json /etc/sing-box/config.json.0
    wget -O /etc/sing-box/config.json.1 -T 30 https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Config-Templates/config.json

    if [[ $? -eq 0 ]]
    then
        mv -f /etc/sing-box/config.json.1 /etc/sing-box/config.json
        insert_values
    fi
}

update_keys() {
    curl -fsSL -o /etc/apt/keyrings/sagernet.asc -m 30 https://deb.sagernet.org/gpg.key && chmod a+r /etc/apt/keyrings/sagernet.asc
    curl -fsSL -m 30 https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg > /dev/null
    curl -fsSL -m 30 https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    gpg --dry-run --quiet --no-keyring --import --import-options import-show /etc/apt/keyrings/sagernet.asc /usr/share/keyrings/nginx-archive-keyring.gpg /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
}

update_restart_services() {
    local -A urs_message=()
    urs_message[1_ru]="${textcolor_light}Обновление пакетов...${clear}"
    urs_message[1_en]="${textcolor_light}Updating packages...${clear}"

    echo ""
    echo -e "${urs_message[1_$language]}"
    systemctl stop sing-box.service warp-svc.service nginx.service
    [[ -f /etc/haproxy/auth.lua ]] && systemctl stop haproxy.service
    [[ -f /etc/apt/apt.conf.d/50unattended-upgrades ]] && systemctl stop unattended-upgrades.service

    manage_sb_config
    update_keys

    apt-mark unhold sing-box
    apt update -y; apt -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" full-upgrade -y
    apt-mark hold sing-box
    apt autoremove -y; apt autoclean -y
    systemctl daemon-reload
    echo ""

    systemctl start sing-box.service warp-svc.service nginx.service
    systemctl status sing-box.service warp-svc.service nginx.service --no-pager -l -n 5
    echo ""

    if [[ -f /etc/haproxy/auth.lua ]]
    then
        systemctl start haproxy.service
        systemctl status haproxy.service --no-pager -l -n 5
        echo ""
    fi

    if [[ -f /etc/apt/apt.conf.d/50unattended-upgrades ]]
    then
        systemctl start unattended-upgrades.service
        systemctl status unattended-upgrades.service --no-pager -l -n 5
        echo ""
    fi
}

check_sync_client() {
    local -A csc_message=()
    csc_message[1_ru]="${textcolor_light}Синхронизация настроек в клиентских конфигах с GitHub...${clear}"
    csc_message[1_en]="${textcolor_light}Syncing settings in client configs with GitHub...${clear}"

    echo -e "${csc_message[1_$language]}"
    check_users; [[ $? -eq 111 ]] && return 111
    check_github_template; [[ $? -eq 111 ]] && return 111
    local sync_template_file="template.json"
    sync_client_configs_main
}

update_sub_page() {
    local -A usp_message=()
    usp_message[1_ru]="${textcolor_light}Обновление страницы выдачи подписок...${clear}"
    usp_message[1_en]="${textcolor_light}Updating subscription page...${clear}"

    echo -e "${usp_message[1_$language]}"
    local data_vrnt="both"
    [[ -f /etc/haproxy/auth.lua ]] && data_vrnt="novless"
    wget -O "/var/www/${subspath}/sub.html" -T 30 https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Subscription-Page/sub.html
    wget -O "/var/www/${subspath}/background.jpg" -T 30 https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Subscription-Page/background.jpg
    sed -i -e "s/DOMAIN/${domain}/g" -e "s/SUBSCRIPTION-PATH/${subspath}/g" -e "s/html lang=\"en\" data-vrnt=\"both\"/html lang=\"${language}\" data-vrnt=\"${data_vrnt}\"/g" "/var/www/${subspath}/sub.html"
}

update_scripts() {
    local -A us_message=()
    us_message[1_ru]="${textcolor_light}Обновление скриптов...${clear}"
    us_message[1_en]="${textcolor_light}Updating scripts...${clear}"

    echo -e "${us_message[1_$language]}"
    wget -O /usr/local/bin/sbmanager -T 30 https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Scripts/sb-manager.sh
    wget -O /usr/local/bin/rsupdate -T 30 https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Scripts/ruleset-update.sh
    chmod +x /usr/local/bin/sbmanager /usr/local/bin/rsupdate
    echo ""
}

final_text() {
    final_text_ru() {
        echo -e "${textcolor}Установка обновления v${new_version} завершена!${clear}"
        echo "Перезагружать сервер не обязательно"
        echo ""
        echo "При проблемах с Sing-Box запустите команду:"
        echo "cp -f /etc/sing-box/config.json.0 /etc/sing-box/config.json && systemctl restart sing-box.service"
    }

    final_text_en() {
        echo -e "${textcolor}The update v${new_version} has been installed!${clear}"
        echo "It is not necessary to reboot the server"
        echo ""
        echo "If you are having problems with Sing-Box, run this command:"
        echo "cp -f /etc/sing-box/config.json.0 /etc/sing-box/config.json && systemctl restart sing-box.service"
    }

    "final_text_${language}"
    echo ""
    echo ""
    sleep 1
    exit 0
}

menu_text_ru() {
    echo ""
    echo -e "${textcolor}[?]${clear} Выберите вариант обновления:"
    echo "0 - Выйти"
    echo "1 - Обновить всё"
    echo "2 - Обновить без синхронизации клиентских конфигов с GitHub"
    read -r update_option
    [[ -n $update_option ]] && echo ""
}

menu_text_en() {
    echo ""
    echo -e "${textcolor}[?]${clear} Select an update option:"
    echo "0 - Exit"
    echo "1 - Update everything"
    echo "2 - Update without syncing client configs with GitHub"
    read -r update_option
    [[ -n $update_option ]] && echo ""
}

update_menu() {
    "menu_text_${language}"

    case "$update_option" in
        1)
        update_restart_services
        check_sync_client
        update_sub_page
        update_scripts
        final_text
        ;;
        2)
        update_restart_services
        update_sub_page
        update_scripts
        final_text
        ;;
        *)
        exit 0
    esac
}

check_parent
check_update
get_data
update_menu
