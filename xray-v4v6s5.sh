#!/bin/bash

#===============================================================================
# VLESS + SOCKS5 多节点安装脚本 v9.1
#===============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

INSTALL_DIR="/root/xray"
SERVICE_NAME="xray-v6"
PARAMS_FILE="$INSTALL_DIR/params.conf"
SCRIPT_VERSION="9.1"

OS="" ARCH="" XRAY_ARCH="" VPS_IP="" IPV6_ADDR=""
HAS_IPV4="false" HAS_IPV6="false"
DOMAIN="" EMAIL="" UUID="" CDN_HOST="visa.com"

SOCKS5_P6_ENABLED="false" SOCKS5_P6_PORT="" SOCKS5_P6_USER="" SOCKS5_P6_PASS=""
VLESS_V4_ENABLED="false" VLESS_V4_PORT="" VLESS_V4_PATH=""
VLESS_V6_ENABLED="false" VLESS_V6_PORT="" VLESS_V6_PATH=""
VLESS_P6_ENABLED="false" VLESS_P6_PORT="" VLESS_P6_PATH=""

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_port_available() { [ -z "$1" ] && return 1; ss -tlnp 2>/dev/null | grep -q ":$1 " && return 1; return 0; }

get_random_port() {
    local min=$1 max=$2
    for _ in {1..100}; do
        local port=$((RANDOM % (max - min + 1) + min))
        check_port_available "$port" && echo "$port" && return 0
    done
    echo $((RANDOM % (max - min + 1) + min))
}

random_string() { tr -dc 'a-z0-9' < /dev/urandom 2>/dev/null | head -c "$1"; }
random_password() { tr -dc 'a-zA-Z0-9' < /dev/urandom 2>/dev/null | head -c "$1"; }
generate_uuid() { cat /proc/sys/kernel/random/uuid; }
url_encode_path() { echo "$1" | sed 's/\//%2F/g'; }

save_params() {
    mkdir -p "$INSTALL_DIR"
    cat > "$PARAMS_FILE" << EOF
DOMAIN="${DOMAIN}" EMAIL="${EMAIL}" UUID="${UUID}"
VPS_IP="${VPS_IP}" IPV6_ADDR="${IPV6_ADDR}"
HAS_IPV4="${HAS_IPV4}" HAS_IPV6="${HAS_IPV6}" CDN_HOST="${CDN_HOST}"
SOCKS5_P6_ENABLED="${SOCKS5_P6_ENABLED}" SOCKS5_P6_PORT="${SOCKS5_P6_PORT}"
SOCKS5_P6_USER="${SOCKS5_P6_USER}" SOCKS5_P6_PASS="${SOCKS5_P6_PASS}"
VLESS_V4_ENABLED="${VLESS_V4_ENABLED}" VLESS_V4_PORT="${VLESS_V4_PORT}" VLESS_V4_PATH="${VLESS_V4_PATH}"
VLESS_V6_ENABLED="${VLESS_V6_ENABLED}" VLESS_V6_PORT="${VLESS_V6_PORT}" VLESS_V6_PATH="${VLESS_V6_PATH}"
VLESS_P6_ENABLED="${VLESS_P6_ENABLED}" VLESS_P6_PORT="${VLESS_P6_PORT}" VLESS_P6_PATH="${VLESS_P6_PATH}"
EOF
    chmod 600 "$PARAMS_FILE"
}

load_params() { [ -f "$PARAMS_FILE" ] && source "$PARAMS_FILE" && return 0; return 1; }

generate_xray_config() {
    local config_file="$INSTALL_DIR/config/config.json"
    [ -z "$UUID" ] && { print_error "UUID 为空"; return 1; }
    
    local enabled_count=0
    [ "$SOCKS5_P6_ENABLED" = "true" ] && ((enabled_count++))
    [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && ((enabled_count++))
    [ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && ((enabled_count++))
    [ "$VLESS_P6_ENABLED" = "true" ] && ((enabled_count++))
    [ "$enabled_count" -eq 0 ] && { print_error "没有启用任何节点"; return 1; }
    
    local inbounds="" first_inbound=true
    
    if [ "$SOCKS5_P6_ENABLED" = "true" ]; then
        [ "$first_inbound" = "false" ] && inbounds+=","
        inbounds+='{"tag":"socks-p6-in","listen":"::","port":'"$SOCKS5_P6_PORT"',"protocol":"socks","settings":{"auth":"password","accounts":[{"user":"'"$SOCKS5_P6_USER"'","pass":"'"$SOCKS5_P6_PASS"'"}],"udp":true}}'
        first_inbound=false
    fi
    
    if [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ]; then
        [ "$first_inbound" = "false" ] && inbounds+=","
        inbounds+='{"tag":"vless-v4-in","listen":"::","port":'"$VLESS_V4_PORT"',"protocol":"vless","settings":{"clients":[{"id":"'"$UUID"'"}],"decryption":"none"},"streamSettings":{"network":"ws","security":"tls","tlsSettings":{"certificates":[{"certificateFile":"'"$INSTALL_DIR"'/cert/fullchain.crt","keyFile":"'"$INSTALL_DIR"'/cert/private.key"}]},"wsSettings":{"path":"'"$VLESS_V4_PATH"'"}}}'
        first_inbound=false
    fi
    
    if [ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ]; then
        [ "$first_inbound" = "false" ] && inbounds+=","
        inbounds+='{"tag":"vless-v6-in","listen":"::","port":'"$VLESS_V6_PORT"',"protocol":"vless","settings":{"clients":[{"id":"'"$UUID"'"}],"decryption":"none"},"streamSettings":{"network":"ws","security":"tls","tlsSettings":{"certificates":[{"certificateFile":"'"$INSTALL_DIR"'/cert/fullchain.crt","keyFile":"'"$INSTALL_DIR"'/cert/private.key"}]},"wsSettings":{"path":"'"$VLESS_V6_PATH"'"}}}'
        first_inbound=false
    fi
    
    if [ "$VLESS_P6_ENABLED" = "true" ]; then
        [ "$first_inbound" = "false" ] && inbounds+=","
        inbounds+='{"tag":"vless-p6-in","listen":"::","port":'"$VLESS_P6_PORT"',"protocol":"vless","settings":{"clients":[{"id":"'"$UUID"'"}],"decryption":"none"},"streamSettings":{"network":"ws","security":"tls","tlsSettings":{"certificates":[{"certificateFile":"'"$INSTALL_DIR"'/cert/fullchain.crt","keyFile":"'"$INSTALL_DIR"'/cert/private.key"}]},"wsSettings":{"path":"'"$VLESS_P6_PATH"'"}}}'
        first_inbound=false
    fi
    
    local outbounds="" first_outbound=true
    [ "$HAS_IPV4" = "true" ] && { outbounds+='{"tag":"IPv4-out","protocol":"freedom","settings":{"domainStrategy":"UseIPv4"}}'; first_outbound=false; }
    [ "$HAS_IPV6" = "true" ] && { [ "$first_outbound" = "false" ] && outbounds+=","; outbounds+='{"tag":"IPv6-out","protocol":"freedom","settings":{"domainStrategy":"UseIPv6"}}'; first_outbound=false; }
    
    # 根据VPS环境选择优先策略
    local prefer_strategy="UseIPv4"
    [ "$HAS_IPV6" = "true" ] && prefer_strategy="UseIPv6v4"
    [ "$HAS_IPV4" = "false" ] && prefer_strategy="UseIPv6"
    
    [ "$first_outbound" = "false" ] && outbounds+=","
    outbounds+='{"tag":"IPv6v4-out","protocol":"freedom","settings":{"domainStrategy":"'"$prefer_strategy"'"}}'
    outbounds+=',{"tag":"direct","protocol":"freedom"},{"tag":"block","protocol":"blackhole"}'
    
    local rules='{"type":"field","domain":["keyword:stun","keyword:turn","domain:stun.l.google.com","domain:stun1.l.google.com","domain:stun2.l.google.com","domain:stun3.l.google.com","domain:stun4.l.google.com","domain:stun.qq.com","domain:stun.miwifi.com","domain:stun.chat.bilibili.com","domain:stun.syncthing.net"],"outboundTag":"block"}'
    [ "$SOCKS5_P6_ENABLED" = "true" ] && rules+=',{"type":"field","inboundTag":["socks-p6-in"],"outboundTag":"IPv6v4-out"}'
    [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && rules+=',{"type":"field","inboundTag":["vless-v4-in"],"outboundTag":"IPv4-out"}'
    [ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && rules+=',{"type":"field","inboundTag":["vless-v6-in"],"outboundTag":"IPv6-out"}'
    [ "$VLESS_P6_ENABLED" = "true" ] && rules+=',{"type":"field","inboundTag":["vless-p6-in"],"outboundTag":"IPv6v4-out"}'
    rules+=',{"type":"field","protocol":["bittorrent"],"outboundTag":"block"}'
    
    mkdir -p "$INSTALL_DIR/config"
    echo '{"log":{"loglevel":"warning","access":"'"$INSTALL_DIR"'/log/access.log","error":"'"$INSTALL_DIR"'/log/error.log"},"inbounds":['"$inbounds"'],"outbounds":['"$outbounds"'],"routing":{"domainStrategy":"AsIs","rules":['"$rules"']}}' > "$config_file"
    
    "$INSTALL_DIR/bin/xray" run -test -c "$config_file" >/dev/null 2>&1 || { print_error "配置验证失败"; "$INSTALL_DIR/bin/xray" run -test -c "$config_file"; return 1; }
    return 0
}

generate_info() {
    local info_file="$INSTALL_DIR/info.txt"
    local enabled=0
    [ "$SOCKS5_P6_ENABLED" = "true" ] && ((enabled++))
    [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && ((enabled++))
    [ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && ((enabled++))
    [ "$VLESS_P6_ENABLED" = "true" ] && ((enabled++))
    
    local ep_v4=$(url_encode_path "$VLESS_V4_PATH") ep_v6=$(url_encode_path "$VLESS_V6_PATH") ep_p6=$(url_encode_path "$VLESS_P6_PATH")
    local node_num=1
    
    {
        echo -e "\n╔═══════════════════════════════════════════════════════════════════════════════╗"
        echo "║                      多节点代理配置信息 v${SCRIPT_VERSION}                              ║"
        echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
        echo -e "\n═══════════════════════════════════════════════════════════════════════════════"
        echo "  VPS IPv4: ${VPS_IP:-无}  |  VPS IPv6: ${IPV6_ADDR:-无}"
        echo "  域名: $DOMAIN  |  UUID: $UUID"
        echo "  优选地址: $CDN_HOST  |  启用节点: ${enabled}/4  |  WebRTC拦截: ✅"
        echo "═══════════════════════════════════════════════════════════════════════════════"
        
        if [ "$SOCKS5_P6_ENABLED" = "true" ]; then
            local cip="${VPS_IP:-$IPV6_ADDR}"
            echo -e "\n  节点 ${node_num}: SOCKS5（端口 ${SOCKS5_P6_PORT}）出站: 优先IPv6"
            echo "  socks5://${SOCKS5_P6_USER}:${SOCKS5_P6_PASS}@${cip}:${SOCKS5_P6_PORT}#SOCKS5-${node_num}"
            ((node_num++))
        fi
        
        if [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ]; then
            echo -e "\n  节点 ${node_num}: VLESS-IPv4（端口 ${VLESS_V4_PORT}）出站: 强制IPv4"
            echo "  vless://${UUID}@${CDN_HOST}:${VLESS_V4_PORT}?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=${ep_v4}#IPv4-CDN-${node_num}"
            ((node_num++))
        fi
        
        if [ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ]; then
            echo -e "\n  节点 ${node_num}: VLESS-IPv6（端口 ${VLESS_V6_PORT}）出站: 强制IPv6"
            echo "  vless://${UUID}@${CDN_HOST}:${VLESS_V6_PORT}?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=${ep_v6}#IPv6-CDN-${node_num}"
            ((node_num++))
        fi
        
        if [ "$VLESS_P6_ENABLED" = "true" ]; then
            echo -e "\n  节点 ${node_num}: VLESS-优先IPv6（端口 ${VLESS_P6_PORT}）出站: 优先IPv6"
            echo "  vless://${UUID}@${CDN_HOST}:${VLESS_P6_PORT}?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=${ep_p6}#IPv4%26IPv6-CDN-${node_num}"
            ((node_num++))
        fi
        
        echo -e "\n═══════════════════════════════════════════════════════════════════════════════"
        echo "  防火墙放行:"
        [ "$SOCKS5_P6_ENABLED" = "true" ] && echo "    ufw allow $SOCKS5_P6_PORT/tcp"
        [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && echo "    ufw allow $VLESS_V4_PORT/tcp"
        [ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && echo "    ufw allow $VLESS_V6_PORT/tcp"
        [ "$VLESS_P6_ENABLED" = "true" ] && echo "    ufw allow $VLESS_P6_PORT/tcp"
        echo "═══════════════════════════════════════════════════════════════════════════════"
    } > "$info_file"
}

create_management() {
    print_info "创建管理脚本..."
    cat > "$INSTALL_DIR/manage.sh" << 'MANAGE_EOF'
#!/bin/bash
RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[0;33m' BLUE='\033[0;34m' CYAN='\033[0;36m' NC='\033[0m'
DIR="/root/xray" SERVICE="xray-v6" PARAMS_FILE="$DIR/params.conf" SCRIPT_VERSION="9.1"

load_params() { [ -f "$PARAMS_FILE" ] && source "$PARAMS_FILE" && return 0; echo -e "${RED}参数文件不存在${NC}"; return 1; }
save_params() {
    cat > "$PARAMS_FILE" << EOF
DOMAIN="${DOMAIN}" EMAIL="${EMAIL}" UUID="${UUID}"
VPS_IP="${VPS_IP}" IPV6_ADDR="${IPV6_ADDR}"
HAS_IPV4="${HAS_IPV4}" HAS_IPV6="${HAS_IPV6}" CDN_HOST="${CDN_HOST}"
SOCKS5_P6_ENABLED="${SOCKS5_P6_ENABLED}" SOCKS5_P6_PORT="${SOCKS5_P6_PORT}"
SOCKS5_P6_USER="${SOCKS5_P6_USER}" SOCKS5_P6_PASS="${SOCKS5_P6_PASS}"
VLESS_V4_ENABLED="${VLESS_V4_ENABLED}" VLESS_V4_PORT="${VLESS_V4_PORT}" VLESS_V4_PATH="${VLESS_V4_PATH}"
VLESS_V6_ENABLED="${VLESS_V6_ENABLED}" VLESS_V6_PORT="${VLESS_V6_PORT}" VLESS_V6_PATH="${VLESS_V6_PATH}"
VLESS_P6_ENABLED="${VLESS_P6_ENABLED}" VLESS_P6_PORT="${VLESS_P6_PORT}" VLESS_P6_PATH="${VLESS_P6_PATH}"
EOF
    chmod 600 "$PARAMS_FILE"
}
check_port_available() { [ -z "$1" ] && return 1; ss -tlnp 2>/dev/null | grep -q ":$1 " && return 1; return 0; }
get_random_port() { for _ in {1..100}; do local p=$((RANDOM % ($2 - $1 + 1) + $1)); check_port_available "$p" && echo "$p" && return 0; done; echo $((RANDOM % ($2 - $1 + 1) + $1)); }
random_string() { tr -dc 'a-z0-9' < /dev/urandom 2>/dev/null | head -c "$1"; }
random_password() { tr -dc 'a-zA-Z0-9' < /dev/urandom 2>/dev/null | head -c "$1"; }
url_encode_path() { echo "$1" | sed 's/\//%2F/g'; }

regenerate_all() {
    load_params || return 1
    [ -z "$UUID" ] && { echo -e "${RED}UUID 为空${NC}"; return 1; }
    local enabled=0
    [ "$SOCKS5_P6_ENABLED" = "true" ] && ((enabled++))
    [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && ((enabled++))
    [ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && ((enabled++))
    [ "$VLESS_P6_ENABLED" = "true" ] && ((enabled++))
    [ "$enabled" -eq 0 ] && { echo -e "${RED}没有启用任何节点${NC}"; return 1; }
    
    local inbounds="" first=true
    [ "$SOCKS5_P6_ENABLED" = "true" ] && { [ "$first" = "false" ] && inbounds+=","; inbounds+='{"tag":"socks-p6-in","listen":"::","port":'$SOCKS5_P6_PORT',"protocol":"socks","settings":{"auth":"password","accounts":[{"user":"'$SOCKS5_P6_USER'","pass":"'$SOCKS5_P6_PASS'"}],"udp":true}}'; first=false; }
    [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && { [ "$first" = "false" ] && inbounds+=","; inbounds+='{"tag":"vless-v4-in","listen":"::","port":'$VLESS_V4_PORT',"protocol":"vless","settings":{"clients":[{"id":"'$UUID'"}],"decryption":"none"},"streamSettings":{"network":"ws","security":"tls","tlsSettings":{"certificates":[{"certificateFile":"'$DIR'/cert/fullchain.crt","keyFile":"'$DIR'/cert/private.key"}]},"wsSettings":{"path":"'$VLESS_V4_PATH'"}}}'; first=false; }
    [ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && { [ "$first" = "false" ] && inbounds+=","; inbounds+='{"tag":"vless-v6-in","listen":"::","port":'$VLESS_V6_PORT',"protocol":"vless","settings":{"clients":[{"id":"'$UUID'"}],"decryption":"none"},"streamSettings":{"network":"ws","security":"tls","tlsSettings":{"certificates":[{"certificateFile":"'$DIR'/cert/fullchain.crt","keyFile":"'$DIR'/cert/private.key"}]},"wsSettings":{"path":"'$VLESS_V6_PATH'"}}}'; first=false; }
    [ "$VLESS_P6_ENABLED" = "true" ] && { [ "$first" = "false" ] && inbounds+=","; inbounds+='{"tag":"vless-p6-in","listen":"::","port":'$VLESS_P6_PORT',"protocol":"vless","settings":{"clients":[{"id":"'$UUID'"}],"decryption":"none"},"streamSettings":{"network":"ws","security":"tls","tlsSettings":{"certificates":[{"certificateFile":"'$DIR'/cert/fullchain.crt","keyFile":"'$DIR'/cert/private.key"}]},"wsSettings":{"path":"'$VLESS_P6_PATH'"}}}'; first=false; }
    
    local outbounds="" first=true
    [ "$HAS_IPV4" = "true" ] && { outbounds+='{"tag":"IPv4-out","protocol":"freedom","settings":{"domainStrategy":"UseIPv4"}}'; first=false; }
    [ "$HAS_IPV6" = "true" ] && { [ "$first" = "false" ] && outbounds+=","; outbounds+='{"tag":"IPv6-out","protocol":"freedom","settings":{"domainStrategy":"UseIPv6"}}'; first=false; }
    
    # 根据VPS环境选择优先策略
    local ps="UseIPv4"
    [ "$HAS_IPV6" = "true" ] && ps="UseIPv6v4"
    [ "$HAS_IPV4" = "false" ] && ps="UseIPv6"
    
    [ "$first" = "false" ] && outbounds+=","
    outbounds+='{"tag":"IPv6v4-out","protocol":"freedom","settings":{"domainStrategy":"'$ps'"}}'
    outbounds+=',{"tag":"direct","protocol":"freedom"},{"tag":"block","protocol":"blackhole"}'
    
    local rules='{"type":"field","domain":["keyword:stun","keyword:turn","domain:stun.l.google.com","domain:stun1.l.google.com","domain:stun2.l.google.com","domain:stun3.l.google.com","domain:stun4.l.google.com","domain:stun.qq.com","domain:stun.miwifi.com","domain:stun.chat.bilibili.com","domain:stun.syncthing.net"],"outboundTag":"block"}'
    [ "$SOCKS5_P6_ENABLED" = "true" ] && rules+=',{"type":"field","inboundTag":["socks-p6-in"],"outboundTag":"IPv6v4-out"}'
    [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && rules+=',{"type":"field","inboundTag":["vless-v4-in"],"outboundTag":"IPv4-out"}'
    [ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && rules+=',{"type":"field","inboundTag":["vless-v6-in"],"outboundTag":"IPv6-out"}'
    [ "$VLESS_P6_ENABLED" = "true" ] && rules+=',{"type":"field","inboundTag":["vless-p6-in"],"outboundTag":"IPv6v4-out"}'
    rules+=',{"type":"field","protocol":["bittorrent"],"outboundTag":"block"}'
    
    echo '{"log":{"loglevel":"warning","access":"'$DIR'/log/access.log","error":"'$DIR'/log/error.log"},"inbounds":['$inbounds'],"outbounds":['$outbounds'],"routing":{"domainStrategy":"AsIs","rules":['$rules']}}' > "$DIR/config/config.json"
    "$DIR/bin/xray" run -test -c "$DIR/config/config.json" >/dev/null 2>&1 || { echo -e "${RED}配置验证失败${NC}"; "$DIR/bin/xray" run -test -c "$DIR/config/config.json"; return 1; }
    
    local ep_v4=$(url_encode_path "$VLESS_V4_PATH") ep_v6=$(url_encode_path "$VLESS_V6_PATH") ep_p6=$(url_encode_path "$VLESS_P6_PATH") node_num=1
    {
        echo -e "\n╔═══════════════════════════════════════════════════════════════════════════════╗"
        echo "║                      多节点代理配置信息 v${SCRIPT_VERSION}                              ║"
        echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
        echo -e "\n  VPS IPv4: ${VPS_IP:-无}  |  VPS IPv6: ${IPV6_ADDR:-无}"
        echo "  域名: $DOMAIN  |  UUID: $UUID  |  优选地址: $CDN_HOST"
        
        [ "$SOCKS5_P6_ENABLED" = "true" ] && { local cip="${VPS_IP:-$IPV6_ADDR}"; echo -e "\n  节点 ${node_num}: SOCKS5（端口 ${SOCKS5_P6_PORT}）"; echo "  socks5://${SOCKS5_P6_USER}:${SOCKS5_P6_PASS}@${cip}:${SOCKS5_P6_PORT}#SOCKS5-${node_num}"; ((node_num++)); }
        [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && { echo -e "\n  节点 ${node_num}: VLESS-IPv4（端口 ${VLESS_V4_PORT}）"; echo "  vless://${UUID}@${CDN_HOST}:${VLESS_V4_PORT}?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=${ep_v4}#IPv4-CDN-${node_num}"; ((node_num++)); }
        [ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && { echo -e "\n  节点 ${node_num}: VLESS-IPv6（端口 ${VLESS_V6_PORT}）"; echo "  vless://${UUID}@${CDN_HOST}:${VLESS_V6_PORT}?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=${ep_v6}#IPv6-CDN-${node_num}"; ((node_num++)); }
        [ "$VLESS_P6_ENABLED" = "true" ] && { echo -e "\n  节点 ${node_num}: VLESS-优先IPv6（端口 ${VLESS_P6_PORT}）"; echo "  vless://${UUID}@${CDN_HOST}:${VLESS_P6_PORT}?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=${ep_p6}#IPv4%26IPv6-CDN-${node_num}"; ((node_num++)); }
        echo ""
    } > "$DIR/info.txt"
    echo -e "${GREEN}配置已更新${NC}"; return 0
}

show_menu() {
    clear; load_params 2>/dev/null
    local enabled=0
    [ "$SOCKS5_P6_ENABLED" = "true" ] && ((enabled++))
    [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && ((enabled++))
    [ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && ((enabled++))
    [ "$VLESS_P6_ENABLED" = "true" ] && ((enabled++))
    
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗"
    echo "║            Xray 多节点代理 管理面板 v${SCRIPT_VERSION}                     ║"
    echo -e "╚═══════════════════════════════════════════════════════════════╝${NC}"
    systemctl is-active --quiet $SERVICE 2>/dev/null && echo -e "  服务: ${GREEN}● 运行中${NC}" || echo -e "  服务: ${RED}● 已停止${NC}"
    echo -e "  节点: ${YELLOW}${enabled}/4${NC}  UUID: ${YELLOW}${UUID:0:8}...${NC}  WebRTC: ${GREEN}✅${NC}"
    echo -e "\n${CYAN}─── 服务 ───${NC}  1.查看信息 2.启动 3.停止 4.重启 5.状态 6.日志"
    echo -e "${CYAN}─── 节点 ───${NC}  7.状态 8.开关 9.修改 10.新增 11.删除"
    echo -e "${CYAN}─── 配置 ───${NC}  12.UUID 13.CDN 14.编辑 15.测试 16.更新 ${RED}17.卸载${NC} 0.退出\n"
}

show_info() { clear; [ -f "$DIR/info.txt" ] && cat "$DIR/info.txt" || echo -e "${RED}信息文件不存在${NC}"; echo -e "\n${YELLOW}按回车返回...${NC}"; read -r; }
start_service() { echo -e "${BLUE}启动...${NC}"; systemctl start $SERVICE; sleep 2; systemctl is-active --quiet $SERVICE && echo -e "${GREEN}成功${NC}" || { echo -e "${RED}失败${NC}"; journalctl -u $SERVICE --no-pager -n 5; }; sleep 2; }
stop_service() { systemctl stop $SERVICE; echo -e "${GREEN}已停止${NC}"; sleep 2; }
restart_service() { echo -e "${BLUE}重启...${NC}"; systemctl restart $SERVICE; sleep 2; systemctl is-active --quiet $SERVICE && echo -e "${GREEN}成功${NC}" || { echo -e "${RED}失败${NC}"; journalctl -u $SERVICE --no-pager -n 5; }; sleep 2; }
show_status() { clear; systemctl status $SERVICE --no-pager; echo ""; ss -tlnp 2>/dev/null | grep xray; echo -e "\n${YELLOW}按回车返回...${NC}"; read -r; }
show_log() { clear; echo -e "${YELLOW}Ctrl+C 退出${NC}\n"; tail -f "$DIR/log/error.log" 2>/dev/null; }

show_node_status() {
    clear; load_params
    echo -e "${CYAN}═══════════════════ 节点状态 ═══════════════════${NC}\n"
    local s1="❌" s2="❌" s3="❌" s4="❌"
    [ "$SOCKS5_P6_ENABLED" = "true" ] && s1="✅"
    [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && s2="✅"
    [ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && s3="✅"
    [ "$VLESS_P6_ENABLED" = "true" ] && s4="✅"
    echo "  1. SOCKS5-优先IPv6 [$s1] 端口:${SOCKS5_P6_PORT:-未设置}"
    echo "  2. VLESS-强制IPv4  [$s2] 端口:${VLESS_V4_PORT:-未设置} $([ "$HAS_IPV4" != "true" ] && echo "(无IPv4)")"
    echo "  3. VLESS-强制IPv6  [$s3] 端口:${VLESS_V6_PORT:-未设置} $([ "$HAS_IPV6" != "true" ] && echo "(无IPv6)")"
    echo "  4. VLESS-优先IPv6  [$s4] 端口:${VLESS_P6_PORT:-未设置}"
    echo -e "\n${YELLOW}按回车返回...${NC}"; read -r
}

toggle_node() {
    load_params; echo ""
    echo "  1. SOCKS5-优先IPv6 [$([ "$SOCKS5_P6_ENABLED" = "true" ] && echo "✅" || echo "❌")]"
    echo "  2. VLESS-强制IPv4  [$([ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && echo "✅" || echo "❌")]$([ "$HAS_IPV4" != "true" ] && echo " (无IPv4)")"
    echo "  3. VLESS-强制IPv6  [$([ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && echo "✅" || echo "❌")]$([ "$HAS_IPV6" != "true" ] && echo " (无IPv6)")"
    echo "  4. VLESS-优先IPv6  [$([ "$VLESS_P6_ENABLED" = "true" ] && echo "✅" || echo "❌")]"
    echo "  0. 返回"; echo ""; echo -n "选择: "; read -r c
    case $c in
        0) return;; 1) [ "$SOCKS5_P6_ENABLED" = "true" ] && SOCKS5_P6_ENABLED="false" || SOCKS5_P6_ENABLED="true";;
        2) [ "$HAS_IPV4" != "true" ] && { echo -e "${RED}无IPv4${NC}"; sleep 2; return; }; [ "$VLESS_V4_ENABLED" = "true" ] && VLESS_V4_ENABLED="false" || VLESS_V4_ENABLED="true";;
        3) [ "$HAS_IPV6" != "true" ] && { echo -e "${RED}无IPv6${NC}"; sleep 2; return; }; [ "$VLESS_V6_ENABLED" = "true" ] && VLESS_V6_ENABLED="false" || VLESS_V6_ENABLED="true";;
        4) [ "$VLESS_P6_ENABLED" = "true" ] && VLESS_P6_ENABLED="false" || VLESS_P6_ENABLED="true";;
        *) echo -e "${RED}无效${NC}"; sleep 1; return;;
    esac
    save_params; regenerate_all && { echo -n -e "${YELLOW}重启？(y/n): ${NC}"; read -r r; [ "$r" = "y" ] && restart_service; }; sleep 2
}

modify_node() {
    load_params; echo ""
    echo "  1. SOCKS5 端口:${SOCKS5_P6_PORT}  2. VLESS-v4 端口:${VLESS_V4_PORT} 路径:${VLESS_V4_PATH}"
    echo "  3. VLESS-v6 端口:${VLESS_V6_PORT} 路径:${VLESS_V6_PATH}  4. VLESS-p6 端口:${VLESS_P6_PORT} 路径:${VLESS_P6_PATH}"
    echo "  0. 返回"; echo -n "选择: "; read -r c
    case $c in
        0) return;;
        1) echo -n "端口($SOCKS5_P6_PORT): "; read -r p; [ -n "$p" ] && SOCKS5_P6_PORT="$p"
           echo -n "用户名($SOCKS5_P6_USER): "; read -r u; [ -n "$u" ] && SOCKS5_P6_USER="$u"
           echo -n "密码($SOCKS5_P6_PASS): "; read -r w; [ -n "$w" ] && SOCKS5_P6_PASS="$w";;
        2) echo -n "端口($VLESS_V4_PORT): "; read -r p; [ -n "$p" ] && VLESS_V4_PORT="$p"
           echo -n "路径($VLESS_V4_PATH): "; read -r t; [ -n "$t" ] && VLESS_V4_PATH="$t";;
        3) echo -n "端口($VLESS_V6_PORT): "; read -r p; [ -n "$p" ] && VLESS_V6_PORT="$p"
           echo -n "路径($VLESS_V6_PATH): "; read -r t; [ -n "$t" ] && VLESS_V6_PATH="$t";;
        4) echo -n "端口($VLESS_P6_PORT): "; read -r p; [ -n "$p" ] && VLESS_P6_PORT="$p"
           echo -n "路径($VLESS_P6_PATH): "; read -r t; [ -n "$t" ] && VLESS_P6_PATH="$t";;
        *) echo -e "${RED}无效${NC}"; sleep 1; return;;
    esac
    save_params; regenerate_all && { echo -n -e "${YELLOW}重启？(y/n): ${NC}"; read -r r; [ "$r" = "y" ] && restart_service; }; sleep 2
}

add_node() {
    load_params; echo -e "\n${CYAN}═══ 新增节点 ═══${NC}"
    echo "  1. SOCKS5 $([ "$SOCKS5_P6_ENABLED" = "true" ] && echo "(已启用)")"
    echo "  2. VLESS-v4 $([ "$VLESS_V4_ENABLED" = "true" ] && echo "(已启用)")$([ "$HAS_IPV4" != "true" ] && echo " [无IPv4]")"
    echo "  3. VLESS-v6 $([ "$VLESS_V6_ENABLED" = "true" ] && echo "(已启用)")$([ "$HAS_IPV6" != "true" ] && echo " [无IPv6]")"
    echo "  4. VLESS-p6 $([ "$VLESS_P6_ENABLED" = "true" ] && echo "(已启用)")"
    echo "  0. 返回"; echo -n "选择: "; read -r c
    case $c in
        0) return;;
        1) [ "$SOCKS5_P6_ENABLED" = "true" ] && { echo -e "${YELLOW}已启用${NC}"; sleep 2; return; }
           echo -n "端口(随机): "; read -r p; [ -z "$p" ] && p=$(get_random_port 20000 30000); SOCKS5_P6_PORT="$p"
           echo -n "用户名(随机): "; read -r u; [ -z "$u" ] && u=$(random_string 10); SOCKS5_P6_USER="$u"
           echo -n "密码(随机): "; read -r w; [ -z "$w" ] && w=$(random_password 12); SOCKS5_P6_PASS="$w"; SOCKS5_P6_ENABLED="true";;
        2) [ "$HAS_IPV4" != "true" ] && { echo -e "${RED}无IPv4${NC}"; sleep 2; return; }
           [ "$VLESS_V4_ENABLED" = "true" ] && { echo -e "${YELLOW}已启用${NC}"; sleep 2; return; }
           echo -n "端口(2053): "; read -r p; [ -z "$p" ] && p="2053"; VLESS_V4_PORT="$p"
           echo -n "路径(随机): "; read -r t; [ -z "$t" ] && t="/$(random_string 8)"; VLESS_V4_PATH="$t"; VLESS_V4_ENABLED="true";;
        3) [ "$HAS_IPV6" != "true" ] && { echo -e "${RED}无IPv6${NC}"; sleep 2; return; }
           [ "$VLESS_V6_ENABLED" = "true" ] && { echo -e "${YELLOW}已启用${NC}"; sleep 2; return; }
           echo -n "端口(2083): "; read -r p; [ -z "$p" ] && p="2083"; VLESS_V6_PORT="$p"
           echo -n "路径(随机): "; read -r t; [ -z "$t" ] && t="/$(random_string 8)"; VLESS_V6_PATH="$t"; VLESS_V6_ENABLED="true";;
        4) [ "$VLESS_P6_ENABLED" = "true" ] && { echo -e "${YELLOW}已启用${NC}"; sleep 2; return; }
           echo -n "端口(2087): "; read -r p; [ -z "$p" ] && p="2087"; VLESS_P6_PORT="$p"
           echo -n "路径(随机): "; read -r t; [ -z "$t" ] && t="/$(random_string 8)"; VLESS_P6_PATH="$t"; VLESS_P6_ENABLED="true";;
        *) echo -e "${RED}无效${NC}"; sleep 1; return;;
    esac
    save_params; echo -e "${GREEN}已添加${NC}"; regenerate_all && { echo -n -e "${YELLOW}重启？(y/n): ${NC}"; read -r r; [ "$r" = "y" ] && restart_service; }; sleep 2
}

delete_node() {
    load_params; echo -e "\n${CYAN}═══ 删除节点 ═══${NC}"
    echo "  1. SOCKS5 [$([ "$SOCKS5_P6_ENABLED" = "true" ] && echo "✅" || echo "❌")]"
    echo "  2. VLESS-v4 [$([ "$VLESS_V4_ENABLED" = "true" ] && echo "✅" || echo "❌")]"
    echo "  3. VLESS-v6 [$([ "$VLESS_V6_ENABLED" = "true" ] && echo "✅" || echo "❌")]"
    echo "  4. VLESS-p6 [$([ "$VLESS_P6_ENABLED" = "true" ] && echo "✅" || echo "❌")]"
    echo "  0. 返回"; echo -n "选择删除: "; read -r c
    case $c in
        0) return;; 1) SOCKS5_P6_ENABLED="false"; SOCKS5_P6_PORT=""; SOCKS5_P6_USER=""; SOCKS5_P6_PASS="";;
        2) VLESS_V4_ENABLED="false"; VLESS_V4_PORT=""; VLESS_V4_PATH="";;
        3) VLESS_V6_ENABLED="false"; VLESS_V6_PORT=""; VLESS_V6_PATH="";;
        4) VLESS_P6_ENABLED="false"; VLESS_P6_PORT=""; VLESS_P6_PATH="";;
        *) echo -e "${RED}无效${NC}"; sleep 1; return;;
    esac
    save_params; echo -e "${GREEN}已删除${NC}"; regenerate_all && { echo -n -e "${YELLOW}重启？(y/n): ${NC}"; read -r r; [ "$r" = "y" ] && restart_service; }; sleep 2
}

modify_uuid() {
    load_params; echo -e "\n当前UUID: ${YELLOW}$UUID${NC}"; echo -n "新UUID(回车随机): "; read -r u
    [ -z "$u" ] && u=$("$DIR/bin/xray" uuid 2>/dev/null || cat /proc/sys/kernel/random/uuid)
    UUID="$u"; save_params; echo -e "${GREEN}已更新: $UUID${NC}"
    regenerate_all && { echo -n -e "${YELLOW}重启？(y/n): ${NC}"; read -r r; [ "$r" = "y" ] && restart_service; }; sleep 2
}

modify_cdn() {
    load_params; echo -e "\n当前CDN: ${YELLOW}$CDN_HOST${NC}"; echo -n "新CDN: "; read -r c
    [ -n "$c" ] && CDN_HOST="$c"; save_params; echo -e "${GREEN}已更新: $CDN_HOST${NC}"; regenerate_all; sleep 2
}

edit_config() { command -v nano &>/dev/null && nano "$DIR/config/config.json" || vi "$DIR/config/config.json"; echo -n -e "${YELLOW}重启？(y/n): ${NC}"; read -r r; [ "$r" = "y" ] && restart_service; }
test_config() { clear; echo -e "${CYAN}═══ 配置测试 ═══${NC}"; "$DIR/bin/xray" run -test -c "$DIR/config/config.json"; echo -e "\n${YELLOW}按回车返回...${NC}"; read -r; }

update_xray() {
    clear; local cur=$("$DIR/bin/xray" version 2>/dev/null | head -1 | awk '{print $2}')
    local lat=$(curl -sL --max-time 15 "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4)
    echo -e "当前: ${YELLOW}${cur:-未知}${NC}  最新: ${GREEN}${lat:-获取失败}${NC}"
    [ -z "$lat" ] && { echo -e "${RED}无法获取${NC}"; sleep 3; return; }
    [ "$cur" = "$lat" ] && { echo -e "${GREEN}已是最新${NC}"; sleep 3; return; }
    echo -n -e "${YELLOW}更新？(y/n): ${NC}"; read -r u; [ "$u" != "y" ] && return
    local arch=$(uname -m); case "$arch" in x86_64) arch="64";; aarch64) arch="arm64-v8a";; esac
    cd "$DIR"; wget -q --show-progress -O xray.zip "https://github.com/XTLS/Xray-core/releases/download/${lat}/Xray-linux-${arch}.zip" && {
        systemctl stop $SERVICE; unzip -o xray.zip -d bin/ >/dev/null 2>&1; rm -f xray.zip; chmod +x bin/xray; systemctl start $SERVICE; echo -e "${GREEN}成功${NC}"
    } || echo -e "${RED}失败${NC}"; sleep 3
}

uninstall() {
    clear; echo -e "${RED}警告：删除所有配置！${NC}"; echo -n "输入yes确认: "; read -r c
    [ "$c" = "yes" ] && { systemctl stop $SERVICE; systemctl disable $SERVICE; rm -f /etc/systemd/system/${SERVICE}.service; rm -rf "$DIR"; rm -f /usr/local/bin/xray-v6; systemctl daemon-reload; echo -e "${GREEN}完成${NC}"; exit 0; }; sleep 2
}

main() {
    while true; do
        show_menu; echo -n "选择[0-17]: "; read -r c
        case $c in
            1) show_info;; 2) start_service;; 3) stop_service;; 4) restart_service;; 5) show_status;; 6) show_log;;
            7) show_node_status;; 8) toggle_node;; 9) modify_node;; 10) add_node;; 11) delete_node;;
            12) modify_uuid;; 13) modify_cdn;; 14) edit_config;; 15) test_config;; 16) update_xray;; 17) uninstall;;
            0) clear; exit 0;; *) echo -e "${RED}无效${NC}"; sleep 1;;
        esac
    done
}
main
MANAGE_EOF
    chmod +x "$INSTALL_DIR/manage.sh"
    ln -sf "$INSTALL_DIR/manage.sh" /usr/local/bin/xray-v6
    print_success "管理脚本创建完成"
}

print_banner() {
    clear; echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║          Xray 多节点安装脚本 v${SCRIPT_VERSION}                          ║"
    echo "║  • SOCKS5/VLESS 优先IPv6  • VLESS 强制IPv4/IPv6              ║"
    echo "║  ✅ 双栈接入 ✅ 快速部署 ✅ WebRTC拦截                        ║"
    echo -e "╚═══════════════════════════════════════════════════════════════╝${NC}"
}

check_root() { [ "$(id -u)" != "0" ] && { print_error "请用root运行"; exit 1; }; print_success "Root权限通过"; }

check_system() {
    print_info "检测系统..."
    [ -f /etc/os-release ] && source /etc/os-release && OS="$ID" || OS="unknown"
    ARCH=$(uname -m)
    case "$ARCH" in x86_64) XRAY_ARCH="64";; aarch64) XRAY_ARCH="arm64-v8a";; armv7l) XRAY_ARCH="arm32-v7a";; *) print_error "不支持: $ARCH"; exit 1;; esac
    print_success "系统: $OS | 架构: $ARCH"
}

check_network() {
    print_info "检测网络..."
    VPS_IP=$(curl -4 -s --max-time 10 ip.sb 2>/dev/null || curl -4 -s --max-time 10 ifconfig.me 2>/dev/null)
    [ -n "$VPS_IP" ] && { HAS_IPV4="true"; print_success "IPv4: $VPS_IP"; } || { HAS_IPV4="false"; print_warning "IPv4: 未检测到"; }
    IPV6_ADDR=$(ip -6 addr show scope global 2>/dev/null | grep -oP '(?<=inet6\s)[\da-f:]+' | head -1)
    [ -n "$IPV6_ADDR" ] && { HAS_IPV6="true"; print_success "IPv6: $IPV6_ADDR"; } || { HAS_IPV6="false"; print_warning "IPv6: 未检测到"; }
    [ "$HAS_IPV4" = "false" ] && [ "$HAS_IPV6" = "false" ] && { print_error "无可用IP"; exit 1; }
}

get_user_input() {
    echo -e "\n${CYAN}╔═══════════════════════════════════════════════════════════════╗"
    echo -e "║                    快速配置向导                              ║"
    echo -e "╚═══════════════════════════════════════════════════════════════╝${NC}\n"
    while [ -z "$DOMAIN" ]; do echo -n -e "${YELLOW}请输入域名: ${NC}"; read -r DOMAIN; [ -z "$DOMAIN" ] && echo -e "${RED}不能为空${NC}"; done
    EMAIL="admin@$DOMAIN"; UUID=$(generate_uuid); CDN_HOST="visa.com"
    
    SOCKS5_P6_ENABLED="true"; SOCKS5_P6_PORT=$(get_random_port 20000 30000); SOCKS5_P6_USER=$(random_string 10); SOCKS5_P6_PASS=$(random_password 12)
    [ "$HAS_IPV4" = "true" ] && { VLESS_V4_ENABLED="true"; VLESS_V4_PORT="2053"; VLESS_V4_PATH="/$(random_string 8)"; } || VLESS_V4_ENABLED="false"
    [ "$HAS_IPV6" = "true" ] && { VLESS_V6_ENABLED="true"; VLESS_V6_PORT="2083"; VLESS_V6_PATH="/$(random_string 8)"; } || VLESS_V6_ENABLED="false"
    VLESS_P6_ENABLED="true"; VLESS_P6_PORT="2087"; VLESS_P6_PATH="/$(random_string 8)"
    
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "  域名: ${YELLOW}$DOMAIN${NC}  UUID: ${YELLOW}${UUID:0:8}...${NC}  CDN: ${YELLOW}$CDN_HOST${NC}"
    echo -e "  IPv4: ${YELLOW}${VPS_IP:-无}${NC}  IPv6: ${YELLOW}${IPV6_ADDR:-无}${NC}"
    echo -e "  节点:"
    [ "$SOCKS5_P6_ENABLED" = "true" ] && echo -e "    ${GREEN}✓${NC} SOCKS5-优先v6 :$SOCKS5_P6_PORT"
    [ "$VLESS_V4_ENABLED" = "true" ] && echo -e "    ${GREEN}✓${NC} VLESS-强制v4 :$VLESS_V4_PORT"
    [ "$VLESS_V6_ENABLED" = "true" ] && echo -e "    ${GREEN}✓${NC} VLESS-强制v6 :$VLESS_V6_PORT"
    [ "$VLESS_P6_ENABLED" = "true" ] && echo -e "    ${GREEN}✓${NC} VLESS-优先v6 :$VLESS_P6_PORT"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}\n"
    echo -n -e "${YELLOW}确认安装？(Y/n): ${NC}"; read -r c; [ "$c" = "n" ] || [ "$c" = "N" ] && exit 0
}

install_deps() { print_info "安装依赖..."; command -v apt-get &>/dev/null && apt-get update -y >/dev/null 2>&1 && apt-get install -y curl wget unzip socat cron openssl >/dev/null 2>&1; command -v yum &>/dev/null && yum install -y curl wget unzip socat cronie openssl >/dev/null 2>&1; print_success "依赖完成"; }

cleanup_old() {
    print_info "清理旧安装..."
    local bak=""; [ -f "$INSTALL_DIR/cert/fullchain.crt" ] && [ -f "$INSTALL_DIR/cert/private.key" ] && { bak="/tmp/xray_cert_$$"; mkdir -p "$bak"; cp "$INSTALL_DIR/cert/"* "$bak/" 2>/dev/null; print_info "已备份证书"; }
    systemctl stop $SERVICE_NAME >/dev/null 2>&1; systemctl disable $SERVICE_NAME >/dev/null 2>&1
    rm -f /etc/systemd/system/${SERVICE_NAME}.service; rm -rf "$INSTALL_DIR"; rm -f /usr/local/bin/xray-v6; systemctl daemon-reload >/dev/null 2>&1
    [ -n "$bak" ] && [ -d "$bak" ] && { mkdir -p "$INSTALL_DIR/cert"; cp "$bak/"* "$INSTALL_DIR/cert/" 2>/dev/null; rm -rf "$bak"; print_info "已恢复证书"; }
    print_success "清理完成"
}

create_dirs() { print_info "创建目录..."; mkdir -p "$INSTALL_DIR"/{bin,config,cert,log,data}; touch "$INSTALL_DIR/log/"{access,error}.log; print_success "目录完成"; }

download_xray() {
    print_info "下载Xray..."; cd "$INSTALL_DIR"
    local lat=$(curl -sL --max-time 15 "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4)
    [ -z "$lat" ] || [[ ! "$lat" =~ ^v[0-9] ]] && { lat="v24.12.18"; print_warning "使用备用版本: $lat"; } || print_info "版本: $lat"
    wget -q --show-progress -O xray.zip "https://github.com/XTLS/Xray-core/releases/download/${lat}/Xray-linux-${XRAY_ARCH}.zip" || { print_error "下载失败"; exit 1; }
    unzip -o xray.zip -d bin/ >/dev/null 2>&1; rm -f xray.zip; chmod +x bin/xray
    print_info "下载规则..."; wget -q -O data/geoip.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat" 2>/dev/null
    wget -q -O data/geosite.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat" 2>/dev/null
    print_success "Xray完成"
}

install_cert() {
    print_info "检查证书..."
    [ -f "$INSTALL_DIR/cert/fullchain.crt" ] && [ -f "$INSTALL_DIR/cert/private.key" ] && openssl x509 -checkend 86400 -noout -in "$INSTALL_DIR/cert/fullchain.crt" 2>/dev/null && { print_success "使用已有证书"; return 0; }
    [ -f ~/.acme.sh/${DOMAIN}_ecc/fullchain.cer ] && { print_info "使用acme.sh证书..."; mkdir -p "$INSTALL_DIR/cert"; cp ~/.acme.sh/${DOMAIN}_ecc/fullchain.cer "$INSTALL_DIR/cert/fullchain.crt"; cp ~/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.key "$INSTALL_DIR/cert/private.key"; ~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" --ecc --key-file "$INSTALL_DIR/cert/private.key" --fullchain-file "$INSTALL_DIR/cert/fullchain.crt" --reloadcmd "systemctl restart $SERVICE_NAME" >/dev/null 2>&1; print_success "证书完成"; return 0; }
    print_info "申请证书..."; fuser -k 80/tcp >/dev/null 2>&1; sleep 2
    [ ! -f ~/.acme.sh/acme.sh ] && curl -sL https://get.acme.sh | sh -s email="$EMAIL" >/dev/null 2>&1
    [ ! -f ~/.acme.sh/acme.sh ] && { print_error "acme.sh安装失败"; exit 1; }
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt >/dev/null 2>&1
    print_warning "确保域名 $DOMAIN 已解析到此VPS"
    ~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone --keylength ec-256 --force || { print_error "证书申请失败"; exit 1; }
    mkdir -p "$INSTALL_DIR/cert"
    ~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" --ecc --key-file "$INSTALL_DIR/cert/private.key" --fullchain-file "$INSTALL_DIR/cert/fullchain.crt" --reloadcmd "systemctl restart $SERVICE_NAME"
    [ ! -f "$INSTALL_DIR/cert/fullchain.crt" ] && { print_error "证书安装失败"; exit 1; }
    print_success "证书申请成功"
}

create_service() {
    print_info "创建服务..."
    cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=Xray Service
After=network.target
[Service]
Type=simple
User=root
Environment=XRAY_LOCATION_ASSET=$INSTALL_DIR/data
ExecStart=$INSTALL_DIR/bin/xray run -c $INSTALL_DIR/config/config.json
Restart=on-failure
RestartSec=3
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload; systemctl enable $SERVICE_NAME >/dev/null 2>&1
    print_success "服务完成"
}

show_result() { clear; [ -f "$INSTALL_DIR/info.txt" ] && cat "$INSTALL_DIR/info.txt"; echo -e "\n${GREEN}✅ 安装完成！管理命令: ${CYAN}xray-v6${NC}\n"; }

main() {
    print_banner; check_root; check_system; check_network; get_user_input
    echo -e "\n"; print_info "========== 开始安装 =========="; echo ""
    install_deps; cleanup_old; create_dirs; download_xray; save_params; install_cert
    print_info "生成配置..."; generate_xray_config || { print_error "配置失败"; exit 1; }; print_success "配置完成"
    print_info "生成信息..."; generate_info; print_success "信息完成"
    create_service; create_management
    print_info "启动服务..."; systemctl start $SERVICE_NAME; sleep 3
    systemctl is-active --quiet $SERVICE_NAME && print_success "启动成功" || { print_error "启动失败"; journalctl -u $SERVICE_NAME --no-pager -n 10; exit 1; }
    echo -e "\n"; print_info "========== 安装完成 =========="; echo ""; show_result
}
main "$@"
