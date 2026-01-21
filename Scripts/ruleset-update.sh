#!/bin/bash

rulesetpath=$(grep "alias /var/www/" /etc/nginx/nginx.conf | head -n 1 | cut -d "/" -f 4)
ruleset_list=$(ls -A1 /var/www/${rulesetpath} | grep -v ".1")

for ruleset_num in $(seq 1 $(echo "${ruleset_list}" | wc -l))
do
    ruleset=$(echo "${ruleset_list}" | sed -n "${ruleset_num}p")
    wget -q -O /var/www/${rulesetpath}/${ruleset}.1 https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/${ruleset} && mv -f /var/www/${rulesetpath}/${ruleset}.1 /var/www/${rulesetpath}/${ruleset}
done

wget -q -O /var/www/${rulesetpath}/torrent-clients.json.1 https://raw.githubusercontent.com/FPPweb3/sb-rule-sets/main/torrent-clients.json && mv -f /var/www/${rulesetpath}/torrent-clients.json.1 /var/www/${rulesetpath}/torrent-clients.json
wget -q -O /var/www/${rulesetpath}/geoip-ru.srs.1 https://raw.githubusercontent.com/SagerNet/sing-geoip/rule-set/geoip-ru.srs && mv -f /var/www/${rulesetpath}/geoip-ru.srs.1 /var/www/${rulesetpath}/geoip-ru.srs
chmod -R 755 /var/www/${rulesetpath}

# Additional optimization:
journalctl --vacuum-time=7days &> /dev/null
[[ $(systemctl is-active warp-svc.service) == "active" ]] && systemctl restart warp-svc.service
