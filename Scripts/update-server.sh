#!/bin/bash

textcolor='\033[1;36m'
textcolor_light='\033[1;37m'
red='\033[1;31m'
clear='\033[0m'

check_parent() {
    if [[ -z $version ]]
    then
        echo ""
        echo -e "${red}Error: this script should be run from the settings menu, not manually${clear}"
        echo ""
        exit 1
    fi
}

check_update() {
    declare -A -g info_message=()
    info_message[1_ru]="Установлена последняя версия:"
    info_message[2_ru]="Текущая версия:"
    info_message[3_ru]="Доступна новая версия:"
    info_message[1_en]="The latest version is already installed:"
    info_message[2_en]="Current version:"
    info_message[3_en]="New version is available:"

    [[ ! $language =~ ^[a-z]+$ ]] && language="ru"   # Legacy
    new_version="1.4.1"

    if [[ "$version" == "$new_version" ]]
    then
        echo -e "${info_message[1_$language]} ${textcolor}v${version}${clear}"
        echo ""
        exit 0
    else
        echo -e "${info_message[2_$language]} ${textcolor}v${version}${clear}"
        echo -e "${info_message[3_$language]} ${textcolor}v${new_version}${clear}"
    fi
}

extract_values() {
    inbound_num_tr=$(jq '[.inbounds[].tag] | index("trojan-in")' /etc/sing-box/config.json)
    users_tr=$(jq ".inbounds[${inbound_num_tr}].users" /etc/sing-box/config.json)

    if [[ ! -f /etc/haproxy/auth.lua ]]
    then
        inbound_num_vl=$(jq '[.inbounds[].tag] | index("vless-in")' /etc/sing-box/config.json)
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
    inbound_num_tr=$(jq '[.inbounds[].tag] | index("trojan-in")' /etc/sing-box/config.json)
    inbound_num_vl=$(jq '[.inbounds[].tag] | index("vless-in")' /etc/sing-box/config.json)
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

    if [[ -n $chain_outbound ]]
    then
        insert_chain
        rule_sets_add=(telegram)
        rule_sets_del=(google-deepmind openai anthropic xai)
    else
        rule_sets_add=()
        rule_sets_del=()
    fi

    sed -i "s/${temprulesetpath}/${rulesetpath}/g" /etc/sing-box/config.json
    manage_rule_sets
    chmod -R 755 /var/www/${rulesetpath}
}

insert_chain() {
    warp_rule_num=$(jq '[.route.rules[].outbound] | index("warp")' /etc/sing-box/config.json)
    echo "$(jq "del(.route.rules[${warp_rule_num}].domain_keyword, .route.rules[${warp_rule_num}].rule_set)" /etc/sing-box/config.json)" > /etc/sing-box/config.json

    if [[ $(jq 'any(.route.rules[]; .outbound == "direct")' /etc/sing-box/config.json) == "false" ]]
    then
        proxy_rule=$(jq 'limit(1; .route.rules[] | select(.outbound == "proxy"))' /var/www/${subspath}/template.json)
        direct_rule='{"domain_suffix":[".ru",".su",".ru.com",".ru.net"],"domain_keyword":["xn--"],"rule_set":["geoip-ru","category-gov-ru"],"outbound":"direct"}'
        echo "$(jq ".route.rules |= . + [${proxy_rule}, ${direct_rule}]" /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

    chain_rule='{"inbound":["trojan-in","vless-in"],"outbound":"proxy"}'
    [[ -f /etc/haproxy/auth.lua ]] && chain_rule='{"inbound":["trojan-in"],"outbound":"proxy"}'
    echo "$(jq ".outbounds += [${chain_outbound}] | .route.rules += [${chain_rule}]" /etc/sing-box/config.json)" > /etc/sing-box/config.json

    if [[ $(jq 'any(.outbounds[]; .tag == "IPv4")' /etc/sing-box/config.json) == "true" ]]
    then
        echo "$(jq 'del(.outbounds[] | select(.tag == "IPv4"))' /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi

    if [[ $(jq 'any(.route.rules[]; .outbound == "IPv4")' /etc/sing-box/config.json) == "true" ]]
    then
        echo "$(jq 'del(.route.rules[] | select(.outbound == "IPv4"))' /etc/sing-box/config.json)" > /etc/sing-box/config.json
    fi
}

manage_rule_sets() {
    for ruleset_ind in $(seq 0 $(jq '.route.rule_set | length - 1' /etc/sing-box/config.json))
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
}

update_services() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor_light}Обновление пакетов...${clear}"
    info_message[1_en]="${textcolor_light}Updating packages...${clear}"

    echo ""
    echo -e "${info_message[1_$language]}"
    systemctl stop sing-box.service
    systemctl stop warp-svc.service
    systemctl stop nginx.service
    [[ -f /etc/haproxy/auth.lua ]] && systemctl stop haproxy.service
    [[ -f /etc/apt/apt.conf.d/50unattended-upgrades ]] && systemctl stop unattended-upgrades.service

    extract_values
    cp -f /etc/sing-box/config.json /etc/sing-box/config.json.0
    wget -O /etc/sing-box/config.json.1 https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Config-Templates/config.json

    if [[ $? -eq 0 ]]
    then
        mv -f /etc/sing-box/config.json.1 /etc/sing-box/config.json
        insert_values
    fi

    apt-mark unhold sing-box
    apt update -y && apt -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" full-upgrade -y
    apt-mark hold sing-box
    apt autoremove -y; apt autoclean -y
    systemctl daemon-reload

    systemctl start sing-box.service
    systemctl start warp-svc.service
    systemctl start nginx.service
    [[ -f /etc/haproxy/auth.lua ]] && systemctl start haproxy.service
    [[ -f /etc/apt/apt.conf.d/50unattended-upgrades ]] && systemctl start unattended-upgrades.service
    echo ""
}

check_sync_client() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor_light}Синхронизация настроек в клиентских конфигах с GitHub...${clear}"
    info_message[1_en]="${textcolor_light}Syncing settings in client configs with GitHub...${clear}"

    echo -e "${info_message[1_$language]}"
    check_users
    declare -f check_github_template &> /dev/null && check_github_template || validate_template   # Legacy

    if [[ "$stop_sync" != "1" ]]
    then
        sync_template_file="template.json"
        declare -f sync_client_configs_main &> /dev/null && sync_client_configs_main || sync_client_configs_github   # Legacy
    fi
}

update_sub_page() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor_light}Обновление страницы выдачи подписок...${clear}"
    info_message[1_en]="${textcolor_light}Updating subscription page...${clear}"

    echo -e "${info_message[1_$language]}"
    data_vrnt="both"
    [[ -f /etc/haproxy/auth.lua ]] && data_vrnt="novless"
    wget -O /var/www/${subspath}/sub.html https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Subscription-Page/sub.html
    wget -O /var/www/${subspath}/background.jpg https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Subscription-Page/background.jpg
    sed -i -e "s/DOMAIN/${domain}/g" -e "s/SUBSCRIPTION-PATH/${subspath}/g" -e "s/html lang=\"en\" data-vrnt=\"both\"/html lang=\"${language}\" data-vrnt=\"${data_vrnt}\"/g" /var/www/${subspath}/sub.html
}

update_scripts() {
    declare -A -g info_message=()
    info_message[1_ru]="${textcolor_light}Обновление скриптов...${clear}"
    info_message[1_en]="${textcolor_light}Updating scripts...${clear}"

    echo -e "${info_message[1_$language]}"
    wget -O /usr/local/bin/sbmanager https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Scripts/sb-manager.sh
    wget -O /usr/local/bin/rsupdate https://raw.githubusercontent.com/A-Zuro/Secret-Sing-Box/master/Scripts/ruleset-update.sh
    chmod +x /usr/local/bin/sbmanager /usr/local/bin/rsupdate
    grep -q "alias ssb=" /etc/bash.bashrc || echo "alias ssb='/usr/local/bin/sbmanager'" >> /etc/bash.bashrc   # Legacy
    [[ ! $(crontab -l) =~ "PATH=" ]] && crontab -l | sed '1i PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin' | crontab -   # Legacy
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

    final_text_${language}
    echo ""
    echo ""
    sleep 1
    exit 0
}

main_menu() {
    stop_sync="1"
}

update_menu() {
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

    menu_text_${language}

    case $update_option in
        1)
        update_services
        check_sync_client
        update_sub_page
        update_scripts
        final_text
        ;;
        2)
        update_services
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
