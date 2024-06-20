#!/bin/sh

TMPDIR=$(mktemp -d) || exit 1
google_status=$(curl -I -4 -m 3 -o /dev/null -s -w %{http_code} http://www.google.com/generate_204)
[ "$google_status" -ne "204" ] && mirror="https://ghproxy.com/"
# cn
echo -e "\e[1;32mDownloading "$mirror"https://raw.githubusercontent.com/Loyalsoldier/geoip/release/text/cn.txt\e[0m"
curl --connect-timeout 60 -m 900 --ipv4 -kfSLo "$TMPDIR/cn.txt" ""$mirror"https://raw.githubusercontent.com/Loyalsoldier/geoip/release/text/cn.txt"
[ $? -ne 0 ] && rm -rf "$TMPDIR" && exit 1

# reject
echo -e "\e[1;32mDownloading "$mirror"https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/reject-list.txt\e[0m"
curl --connect-timeout 60 -m 900 --ipv4 -kfSLo "$TMPDIR/reject-list.txt" ""$mirror"https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/reject-list.txt"
[ $? -ne 0 ] && rm -rf "$TMPDIR" && exit 1

# direct
echo -e "\e[1;32mDownloading "$mirror"https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/direct-list.txt\e[0m"
curl --connect-timeout 60 -m 900 --ipv4 -kfSLo "$TMPDIR/direct-list.txt" ""$mirror"https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/direct-list.txt"
[ $? -ne 0 ] && rm -rf "$TMPDIR" && exit 1

# proxy
echo -e "\e[1;32mDownloading "$mirror"https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/proxy-list.txt\e[0m"
curl --connect-timeout 60 -m 900 --ipv4 -kfSLo "$TMPDIR/proxy-list.txt" ""$mirror"https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/proxy-list.txt"
[ $? -ne 0 ] && rm -rf "$TMPDIR" && exit 1

cp -f "$TMPDIR"/* /etc/mosdns/
rm -rf "$TMPDIR"

systemctl restart mosdns
