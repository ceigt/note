#!/bin/bash

# 函数-运行前检查
check_before_running() {

    # 判断脚本是否由 root 用户运行，若不是，则报错并退出
    [ "$(whoami)" == "root" ] || { echo -e "ERROR: This script must be run by root, please run \"sudo su\" before running this script.\n" ; exit 1 ; }

    # 判断文件是否存在，若不存在，则报错并退出
    [ -f "/var/lib/cloudflare-warp/conf.json" ] || { echo -e "ERROR: File /var/lib/cloudflare-warp/conf.json does not exist.\n" ; exit 1 ; }
    [ -f "/var/lib/cloudflare-warp/reg.json" ] || { echo -e "ERROR: File /var/lib/cloudflare-warp/reg.json does not exist.\n" ; exit 1 ; }

    # 检查依赖
    which jq > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"jq\".\n" ; exit 1 ; }
    which nft > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"nft\".\n" ; exit 1 ; }
    which which > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"which\".\n" ; exit 1 ; }
    which wg-quick > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"wg-quick\".\n" ; exit 1 ; }
    which warp-cli > /dev/null 2>&1 || { echo -e "ERROR: Cannot found command \"warp-cli\".\n" ; exit 1 ; }

}

# 函数-询问参数
ask_config() {

    # 询问 endpoint 使用 IPv4 或者 IPv6 或者指定 IP 地址
    read -p "Endpoint use IPv4 or IPv6 or specify? (4/6/specify):" endpoint_ip_addr_ver
    echo -e "\n"

    # 判断参数是否合法，若不合法则报错并退出
    [ "${endpoint_ip_addr_ver}" != "4" -a "${endpoint_ip_addr_ver}" != "6" -a "${endpoint_ip_addr_ver}" != "specify" ] && \
    { echo -e "ERROR: Unexpected value.\n" ; echo -e "You can run this script again.\n" ; exit 1 ; }

    # 若选择指定 IP 地址，则……
    if [ "${endpoint_ip_addr_ver}" == "specify" ]; then

        # 询问指定的 endpoint IP 地址
        read -p "Please specify an endpoint IP address, IPv6 address must have [] :" spec_endpoint_ip_addr
        echo -e "\n"

        # 显示参数
        echo "Specified endpoint IP address is :"
        echo "Start-->${spec_endpoint_ip_addr}<--End"
        echo -e "\n"

        # 询问参数是否正确，若不正确则报错并退出
        read -p "Endpoint IP address is correct? (Y/N):" check_spec_endpoint_ip_addr
        echo -e "\n"
        [ "${check_spec_endpoint_ip_addr}" == "y" -o "${check_spec_endpoint_ip_addr}" == "Y" ] || \
        { echo -e "You can run this script again.\n" ; exit 1 ; }

    fi

    # 询问是否将 WireGuard 设为默认网关
    read -p "Set WireGuard as the default gateway? (Y/N)(Default:N)" set_wg_as_default_gw
    echo -e "\n"
    [ "${set_wg_as_default_gw}" == "y" ] && set_wg_as_default_gw="Y"

    # 如果要将 WireGuard 设为默认网关，则询问指定的 fwmark 值，默认值为 39375（0x99cf）
    if [ "${set_wg_as_default_gw}" == "Y" ]; then
        read -p "Please specify the fwmark value (256 < fwmark < 65536)(Default:39375):" fwmark_value
        echo -e "\n"
    fi
    [ -z "${fwmark_value}" ] && fwmark_value="39375"

    # 判断参数是否合法，若不合法则报错并退出
    [ "${fwmark_value}" -gt "256" -a "${fwmark_value}" -lt "65536" ] &> /dev/null || \
    { echo -e "ERROR: Out of range.\n" ; echo -e "You can run this script again.\n" ; exit 1 ; }

    # 询问配置名称
    read -p "Please specify the config name (Default:wgcf):" config_name
    echo -e "\n"
    [ -z "${config_name}" ] && config_name="wgcf"

    # 若参数不是默认值，则询问用户进行确认
    if [ "${config_name}" != "wgcf" ]; then

        # 显示参数
        echo "Config name is :"
        echo "Start-->${config_name}<--End"
        echo -e "\n"

        # 询问参数是否正确，若不正确则报错并退出
        read -p "Config name is correct? (Y/N):" check_config_name
        echo -e "\n"
        [ "${check_config_name}" == "y" -o "${check_config_name}" == "Y" ] || \
        { echo -e "You can run this script again.\n" ; exit 1 ; }

    fi

    # 检查
    [ -f "/etc/wireguard/${config_name}.conf" ] && { echo -e "ERROR: File /etc/wireguard/${config_name}.conf already exists.\n" ; exit 1 ; }
    [ -f "/etc/wireguard/${config_name}.nft" ] && { echo -e "ERROR: File /etc/wireguard/${config_name}.nft already exists.\n" ; exit 1 ; }

}

# 函数-读取配置
read_config() {

    # 读取 WARP 分配给本机的 IP 地址
    warp_local_ip_addr_4="$(cat /var/lib/cloudflare-warp/conf.json | jq -r '.interface.v4')"
    warp_local_ip_addr_6="$(cat /var/lib/cloudflare-warp/conf.json | jq -r '.interface.v6')"

    # 检查
    [ -z "${warp_local_ip_addr_4}" ] && { echo -e "ERROR: Read warp_local_ip_addr_4 failed.\n" ; exit 1 ; }
    [ -z "${warp_local_ip_addr_6}" ] && { echo -e "ERROR: Read warp_local_ip_addr_6 failed.\n" ; exit 1 ; }

    # 读取 WARP 分配给本机的 routing_id 数组
    warp_routing_id=($(cat /var/lib/cloudflare-warp/conf.json | jq -r '.routing_id[]'))

    # 检查
    [ -z "${warp_routing_id[0]}" ] && { echo -e "ERROR: Read warp_routing_id failed.\n" ; exit 1 ; }
    [ -z "${warp_routing_id[1]}" ] && { echo -e "ERROR: Read warp_routing_id failed.\n" ; exit 1 ; }
    [ -z "${warp_routing_id[2]}" ] && { echo -e "ERROR: Read warp_routing_id failed.\n" ; exit 1 ; }

    # 读取 WARP 分配给本机的私钥
    warp_private_key="$(cat /var/lib/cloudflare-warp/reg.json | jq -r '.secret_key')"

    # 检查
    [ -z "${warp_private_key}" ] && { echo -e "ERROR: Read warp_private_key failed.\n" ; exit 1 ; }

    # 读取 WARP 分配给本机的 endpoint
    [ "${endpoint_ip_addr_ver}" == "4" ] && warp_endpoint="$(cat /var/lib/cloudflare-warp/conf.json | jq -r '.endpoints[0].v4')"
    [ "${endpoint_ip_addr_ver}" == "6" ] && warp_endpoint="$(cat /var/lib/cloudflare-warp/conf.json | jq -r '.endpoints[0].v6')"

    # 读取指定的 endpoint
    [ "${endpoint_ip_addr_ver}" == "specify" ] && warp_endpoint="${spec_endpoint_ip_addr}:2408"

    # 检查
    [ -z "${warp_endpoint}" ] && { echo -e "ERROR: Read warp_endpoint failed.\n" ; exit 1 ; }

    # 判断 endpoint 的 IP 版本，然后截取出 endpoint 的 IP 地址
    if echo "${warp_endpoint}" | grep ']' > /dev/null 2>&1; then
        endpoint_ip_addr_ver="6"
        endpoint_ip_addr="$(echo "${warp_endpoint}" | awk -F ']' '{print $1}' | sed 's|\[||g')"
    else
        endpoint_ip_addr_ver="4"
        endpoint_ip_addr="$(echo "${warp_endpoint}" | awk -F ':' '{print $1}')"
    fi

    # 检查
    [ -z "${endpoint_ip_addr}" ] && { echo -e "ERROR: Read endpoint_ip_addr failed.\n" ; exit 1 ; }

    # 截取出 endpoint 的端口
    endpoint_port="$(echo "${warp_endpoint}" | awk -F ':' '{print $NF}')"

    # 检查
    [ -z "${endpoint_port}" ] && { echo -e "ERROR: Read endpoint_port failed.\n" ; exit 1 ; }

    # 根据 IP 版本选择对应的命令
    [ "${endpoint_ip_addr_ver}" == "4" ] && nft_ip_cmd="ip"
    [ "${endpoint_ip_addr_ver}" == "6" ] && nft_ip_cmd="ip6"

    # 检查
    [ -z "${nft_ip_cmd}" ] && { echo -e "ERROR: Set nft_ip_cmd failed.\n" ; exit 1 ; }

}

# 函数-生成 WireGuard 配置文件
create_wg_conf() {

    # 如果要将 WireGuard 设为默认网关，则生成对应的配置文件
    if [ "${set_wg_as_default_gw}" == "Y" ]; then
        cat << EOFWG > /etc/wireguard/${config_name}.conf
[Interface]
PrivateKey = ${warp_private_key}
Address = ${warp_local_ip_addr_4}/32
Address = ${warp_local_ip_addr_6}/128
DNS = 1.1.1.1, 1.0.0.1
MTU = 1280
FwMark = ${fwmark_value}
PostUp = $(which nft) -f /etc/wireguard/${config_name}.nft
PostDown = $(which nft) delete table inet ${config_name}

[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
AllowedIPs = 0.0.0.0/0
AllowedIPs = ::/0
Endpoint = ${warp_endpoint}

EOFWG
    fi

    # 如果不要将 WireGuard 设为默认网关，则生成对应的配置文件
    if [ "${set_wg_as_default_gw}" != "Y" ]; then
        cat << EOFWG > /etc/wireguard/${config_name}.conf
[Interface]
PrivateKey = ${warp_private_key}
Address = ${warp_local_ip_addr_4}/32
Address = ${warp_local_ip_addr_6}/128
DNS = 1.1.1.1, 1.0.0.1
MTU = 1280
PostUp = $(which nft) -f /etc/wireguard/${config_name}.nft
PostDown = $(which nft) delete table inet ${config_name}
Table = 500
PreUp = ip rule add to 1.0.0.1 lookup 500
PreUp = ip rule add to 1.1.1.1 lookup 500
PreUp = ip rule add from ${warp_local_ip_addr_4}/32 lookup 500
PreUp = ip -6 rule add from ${warp_local_ip_addr_6}/128 lookup 500
PostDown = ip rule del to 1.0.0.1 lookup 500
PostDown = ip rule del to 1.1.1.1 lookup 500
PostDown = ip rule del from ${warp_local_ip_addr_4}/32 lookup 500
PostDown = ip -6 rule del from ${warp_local_ip_addr_6}/128 lookup 500

[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
AllowedIPs = 0.0.0.0/0
AllowedIPs = ::/0
Endpoint = ${warp_endpoint}

EOFWG
    fi

}

# 函数-生成 nftables 配置文件
create_nft_conf() {

    # 如果要将 WireGuard 设为默认网关，则生成对应的配置文件
    if [ "${set_wg_as_default_gw}" == "Y" ]; then
        cat << EOFNFT > /etc/wireguard/${config_name}.nft
add table inet ${config_name}
flush table inet ${config_name}
define routing_id = $(( ${warp_routing_id[0]}*16**4 + ${warp_routing_id[1]}*16**2 + ${warp_routing_id[2]} ))
table inet ${config_name} {
    chain output {
        type filter hook output priority mangle -1; policy accept;
        ${nft_ip_cmd} daddr ${endpoint_ip_addr} udp dport ${endpoint_port} mark ${fwmark_value} @th,72,24 set \$routing_id counter;
    }

    chain routing {
        type route hook output priority mangle; policy accept;
        ip saddr != ${warp_local_ip_addr_4} fib saddr type local mark != ${fwmark_value} counter meta mark set ${fwmark_value};
        ip6 saddr != ${warp_local_ip_addr_6} fib saddr type local mark != ${fwmark_value} counter meta mark set ${fwmark_value};
    }

    chain input {
        type filter hook input priority mangle; policy accept;
        ${nft_ip_cmd} saddr ${endpoint_ip_addr} udp sport ${endpoint_port} @th,72,24 \$routing_id @th,72,24 set 0 counter;
    }
}

EOFNFT
    fi

    # 如果不要将 WireGuard 设为默认网关，则生成对应的配置文件
    if [ "${set_wg_as_default_gw}" != "Y" ]; then
        cat << EOFNFT > /etc/wireguard/${config_name}.nft
add table inet ${config_name}
flush table inet ${config_name}
define routing_id = $(( ${warp_routing_id[0]}*16**4 + ${warp_routing_id[1]}*16**2 + ${warp_routing_id[2]} ))
table inet ${config_name} {
    chain output {
        type filter hook output priority mangle -1; policy accept;
        ${nft_ip_cmd} daddr ${endpoint_ip_addr} udp dport ${endpoint_port} @th,72,24 set \$routing_id counter;
    }

    chain input {
        type filter hook input priority mangle; policy accept;
        ${nft_ip_cmd} saddr ${endpoint_ip_addr} udp sport ${endpoint_port} @th,72,24 \$routing_id @th,72,24 set 0 counter;
    }
}

EOFNFT
    fi

}

# 函数-主函数
main() {

    # 为显示内容做好准备
    echo -e "\n"

    # 运行“函数-运行前检查”
    check_before_running

    # 运行“函数-询问参数”
    ask_config

    # 运行“函数-读取配置”
    read_config

    # 运行“函数-生成 WireGuard 配置文件”
    create_wg_conf

    # 运行“函数-生成 nftables 配置文件”
    create_nft_conf

    # 提示运行完毕
    echo "Finish!"
    echo -e "\n"

}

# 运行“函数-主函数”
main

