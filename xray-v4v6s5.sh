#!/bin/bash

#===============================================================================
# VLESS + SOCKS5 四合一安装脚本 v8.3
# 1. SOCKS5 - 仅 IPv4 出站
# 2. SOCKS5 - 仅 IPv6 出站
# 3. VLESS  - 仅 IPv4 出站（CF CDN）
# 4. VLESS  - 仅 IPv6 出站（CF CDN）
# 特性：
#   - 所有入站支持 IPv4/IPv6 双栈接入
#   - 内置 WebRTC/STUN 拦截防止 IP 泄露
# 管理命令: xray-v6
#===============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="/root/xray"
SERVICE_NAME="xray-v6"
PARAMS_FILE="$INSTALL_DIR/params.conf"
SCRIPT_VERSION="8.3"

# 全局变量（安装时设置）
OS=""
ARCH=""
XRAY_ARCH=""
VPS_IP=""
IPV6_ADDR=""
HAS_IPV6="false"
DOMAIN=""
EMAIL=""
UUID=""
CDN_HOST="visa.com"

# 节点参数
SOCKS5_V4_ENABLED="true"
SOCKS5_V4_PORT=""
SOCKS5_V4_USER=""
SOCKS5_V4_PASS=""

SOCKS5_V6_ENABLED="false"
SOCKS5_V6_PORT=""
SOCKS5_V6_USER=""
SOCKS5_V6_PASS=""

VLESS_V4_ENABLED="true"
VLESS_V4_PORT="2053"
VLESS_V4_PATH=""

VLESS_V6_ENABLED="false"
VLESS_V6_PORT="2083"
VLESS_V6_PATH=""

#===============================================================================
# 工具函数
#===============================================================================

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查端口是否被占用
check_port() {
    local port=$1
    if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
        return 1
    fi
    return 0
}

# 生成随机可用端口
get_random_port() {
    local min=$1
    local max=$2
    local port
    for i in {1..100}; do
        port=$((RANDOM % (max - min + 1) + min))
        if check_port $port; then
            echo $port
            return 0
        fi
    done
    # 如果找不到可用端口，返回随机端口
    echo $((RANDOM % (max - min + 1) + min))
}

# 生成随机字符串
random_string() {
    local length=$1
    head /dev/urandom | tr -dc 'a-z0-9' | head -c "$length"
}

# 生成随机密码
random_password() {
    local length=$1
    head /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c "$length"
}

#===============================================================================
# 参数管理
#===============================================================================

save_params() {
    mkdir -p "$INSTALL_DIR"
    cat > "$PARAMS_FILE" << EOF
# Xray 配置参数 v${SCRIPT_VERSION}
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

# 基本信息
DOMAIN="${DOMAIN}"
EMAIL="${EMAIL}"
UUID="${UUID}"
VPS_IP="${VPS_IP}"
IPV6_ADDR="${IPV6_ADDR}"
HAS_IPV6="${HAS_IPV6}"
CDN_HOST="${CDN_HOST}"

# SOCKS5-IPv4
SOCKS5_V4_ENABLED="${SOCKS5_V4_ENABLED}"
SOCKS5_V4_PORT="${SOCKS5_V4_PORT}"
SOCKS5_V4_USER="${SOCKS5_V4_USER}"
SOCKS5_V4_PASS="${SOCKS5_V4_PASS}"

# SOCKS5-IPv6
SOCKS5_V6_ENABLED="${SOCKS5_V6_ENABLED}"
SOCKS5_V6_PORT="${SOCKS5_V6_PORT}"
SOCKS5_V6_USER="${SOCKS5_V6_USER}"
SOCKS5_V6_PASS="${SOCKS5_V6_PASS}"

# VLESS-IPv4
VLESS_V4_ENABLED="${VLESS_V4_ENABLED}"
VLESS_V4_PORT="${VLESS_V4_PORT}"
VLESS_V4_PATH="${VLESS_V4_PATH}"

# VLESS-IPv6
VLESS_V6_ENABLED="${VLESS_V6_ENABLED}"
VLESS_V6_PORT="${VLESS_V6_PORT}"
VLESS_V6_PATH="${VLESS_V6_PATH}"
EOF
    chmod 600 "$PARAMS_FILE"
}

load_params() {
    if [ -f "$PARAMS_FILE" ]; then
        source "$PARAMS_FILE"
        return 0
    fi
    return 1
}

#===============================================================================
# 配置生成
#===============================================================================

generate_xray_config() {
    local config_file="$INSTALL_DIR/config/config.json"
    
    # 验证必要变量
    if [ -z "$UUID" ]; then
        print_error "UUID 为空，无法生成配置"
        return 1
    fi
    
    if [ -z "$VPS_IP" ]; then
        print_error "VPS_IP 为空，无法生成配置"
        return 1
    fi
    
    # ==================== 构建 Inbounds ====================
    local inbounds=""
    local first_inbound=true
    
    # SOCKS5-IPv4
    if [ "$SOCKS5_V4_ENABLED" = "true" ]; then
        [ "$first_inbound" = "false" ] && inbounds+=","
        inbounds+='
    {
      "tag": "socks-v4-in",
      "listen": "::",
      "port": '"$SOCKS5_V4_PORT"',
      "protocol": "socks",
      "settings": {
        "auth": "password",
        "accounts": [{"user": "'"$SOCKS5_V4_USER"'", "pass": "'"$SOCKS5_V4_PASS"'"}],
        "udp": true
      }
    }'
        first_inbound=false
    fi
    
    # SOCKS5-IPv6
    if [ "$SOCKS5_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ]; then
        [ "$first_inbound" = "false" ] && inbounds+=","
        inbounds+='
    {
      "tag": "socks-v6-in",
      "listen": "::",
      "port": '"$SOCKS5_V6_PORT"',
      "protocol": "socks",
      "settings": {
        "auth": "password",
        "accounts": [{"user": "'"$SOCKS5_V6_USER"'", "pass": "'"$SOCKS5_V6_PASS"'"}],
        "udp": true
      }
    }'
        first_inbound=false
    fi
    
    # VLESS-IPv4
    if [ "$VLESS_V4_ENABLED" = "true" ]; then
        [ "$first_inbound" = "false" ] && inbounds+=","
        inbounds+='
    {
      "tag": "vless-v4-in",
      "listen": "::",
      "port": '"$VLESS_V4_PORT"',
      "protocol": "vless",
      "settings": {
        "clients": [{"id": "'"$UUID"'"}],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [{
            "certificateFile": "'"$INSTALL_DIR"'/cert/fullchain.crt",
            "keyFile": "'"$INSTALL_DIR"'/cert/private.key"
          }]
        },
        "wsSettings": {"path": "'"$VLESS_V4_PATH"'"}
      }
    }'
        first_inbound=false
    fi
    
    # VLESS-IPv6
    if [ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ]; then
        [ "$first_inbound" = "false" ] && inbounds+=","
        inbounds+='
    {
      "tag": "vless-v6-in",
      "listen": "::",
      "port": '"$VLESS_V6_PORT"',
      "protocol": "vless",
      "settings": {
        "clients": [{"id": "'"$UUID"'"}],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [{
            "certificateFile": "'"$INSTALL_DIR"'/cert/fullchain.crt",
            "keyFile": "'"$INSTALL_DIR"'/cert/private.key"
          }]
        },
        "wsSettings": {"path": "'"$VLESS_V6_PATH"'"}
      }
    }'
        first_inbound=false
    fi
    
    # 检查是否有启用的入站
    if [ "$first_inbound" = "true" ]; then
        print_error "没有启用任何节点，无法生成配置"
        return 1
    fi
    
    # ==================== 构建 Outbounds ====================
    local outbounds='{
      "tag": "IPv4-out",
      "protocol": "freedom",
      "settings": {"domainStrategy": "UseIPv4"},
      "sendThrough": "'"$VPS_IP"'"
    }'
    
    if [ "$HAS_IPV6" = "true" ] && [ -n "$IPV6_ADDR" ]; then
        outbounds+=',
    {
      "tag": "IPv6-out",
      "protocol": "freedom",
      "settings": {"domainStrategy": "UseIPv6"},
      "sendThrough": "'"$IPV6_ADDR"'"
    }'
    fi
    
    outbounds+=',
    {"tag": "direct", "protocol": "freedom"},
    {"tag": "block", "protocol": "blackhole"}'
    
    # ==================== 构建路由规则 ====================
    local v4_tags=""
    local v6_tags=""
    
    [ "$SOCKS5_V4_ENABLED" = "true" ] && v4_tags='"socks-v4-in"'
    [ "$VLESS_V4_ENABLED" = "true" ] && { [ -n "$v4_tags" ] && v4_tags+=","; v4_tags+='"vless-v4-in"'; }
    
    if [ "$HAS_IPV6" = "true" ]; then
        [ "$SOCKS5_V6_ENABLED" = "true" ] && v6_tags='"socks-v6-in"'
        [ "$VLESS_V6_ENABLED" = "true" ] && { [ -n "$v6_tags" ] && v6_tags+=","; v6_tags+='"vless-v6-in"'; }
    fi
    
    # 规则1: WebRTC/STUN 拦截（防止 IP 泄露）- 放在最前面
    local rules='{
        "type": "field",
        "domain": [
          "keyword:stun",
          "keyword:turn",
          "domain:stun.l.google.com",
          "domain:stun1.l.google.com",
          "domain:stun2.l.google.com",
          "domain:stun3.l.google.com",
          "domain:stun4.l.google.com",
          "domain:stun.ekiga.net",
          "domain:stun.ideasip.com",
          "domain:stun.schlund.de",
          "domain:stun.stunprotocol.org",
          "domain:stun.voiparound.com",
          "domain:stun.voipbuster.com",
          "domain:stun.voipstunt.com",
          "domain:stun.counterpath.com",
          "domain:stun.counterpath.net",
          "domain:stun.qq.com",
          "domain:stun.miwifi.com",
          "domain:stun.chat.bilibili.com",
          "domain:stun.hitv.com",
          "domain:stun.syncthing.net"
        ],
        "outboundTag": "block"
      }'
    
    # 规则2: IPv4 入站路由
    if [ -n "$v4_tags" ]; then
        rules+=',
      {
        "type": "field",
        "inboundTag": ['"$v4_tags"'],
        "outboundTag": "IPv4-out"
      }'
    fi
    
    # 规则3: IPv6 入站路由
    if [ -n "$v6_tags" ]; then
        rules+=',
      {
        "type": "field",
        "inboundTag": ['"$v6_tags"'],
        "outboundTag": "IPv6-out"
      }'
    fi
    
    # 规则4: 阻止 BT
    rules+=',
      {
        "type": "field",
        "protocol": ["bittorrent"],
        "outboundTag": "block"
      }'
    
    # ==================== 写入配置文件 ====================
    cat > "$config_file" << EOFCONFIG
{
  "log": {
    "loglevel": "warning",
    "access": "$INSTALL_DIR/log/access.log",
    "error": "$INSTALL_DIR/log/error.log"
  },
  "inbounds": [$inbounds
  ],
  "outbounds": [
    $outbounds
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      $rules
    ]
  }
}
EOFCONFIG

    # 验证配置
    if ! "$INSTALL_DIR/bin/xray" run -test -c "$config_file" >/dev/null 2>&1; then
        print_error "配置验证失败"
        "$INSTALL_DIR/bin/xray" run -test -c "$config_file"
        return 1
    fi
    
    return 0
}

#===============================================================================
# 信息生成
#===============================================================================

generate_info() {
    local info_file="$INSTALL_DIR/info.txt"
    
    # URL 编码路径
    local ep4=$(echo "$VLESS_V4_PATH" | sed 's/\//%2F/g')
    local ep6=$(echo "$VLESS_V6_PATH" | sed 's/\//%2F/g')
    
    # 生成信息文件
    cat > "$info_file" << EOF

╔═══════════════════════════════════════════════════════════════════════════════╗
║                      四合一代理节点配置信息 v${SCRIPT_VERSION}                            ║
║                     所有入站支持 IPv4/IPv6 双栈接入                           ║
║                     已启用 WebRTC/STUN 拦截防止泄露                           ║
╚═══════════════════════════════════════════════════════════════════════════════╝

═══════════════════════════════════════════════════════════════════════════════
                                 基本信息
═══════════════════════════════════════════════════════════════════════════════
  VPS IPv4:    $VPS_IP
  VPS IPv6:    ${IPV6_ADDR:-无}
  域名:        $DOMAIN
  UUID:        $UUID
  优选地址:    $CDN_HOST
  管理命令:    xray-v6
  WebRTC拦截:  ✅ 已启用

EOF

    # SOCKS5-IPv4
    if [ "$SOCKS5_V4_ENABLED" = "true" ]; then
        cat >> "$info_file" << EOF
═══════════════════════════════════════════════════════════════════════════════
        节点 1: SOCKS5-IPv4（端口 $SOCKS5_V4_PORT） ✅ 已启用
═══════════════════════════════════════════════════════════════════════════════
  出站: 强制 IPv4 → $VPS_IP

  链接:
socks5://${SOCKS5_V4_USER}:${SOCKS5_V4_PASS}@${VPS_IP}:${SOCKS5_V4_PORT}

EOF
    else
        cat >> "$info_file" << EOF
═══════════════════════════════════════════════════════════════════════════════
        节点 1: SOCKS5-IPv4 ❌ 已禁用
═══════════════════════════════════════════════════════════════════════════════

EOF
    fi

    # SOCKS5-IPv6
    if [ "$HAS_IPV6" = "true" ]; then
        if [ "$SOCKS5_V6_ENABLED" = "true" ]; then
            cat >> "$info_file" << EOF
═══════════════════════════════════════════════════════════════════════════════
        节点 2: SOCKS5-IPv6（端口 $SOCKS5_V6_PORT） ✅ 已启用
═══════════════════════════════════════════════════════════════════════════════
  出站: 强制 IPv6 → $IPV6_ADDR

  链接:
socks5://${SOCKS5_V6_USER}:${SOCKS5_V6_PASS}@${VPS_IP}:${SOCKS5_V6_PORT}

EOF
        else
            cat >> "$info_file" << EOF
═══════════════════════════════════════════════════════════════════════════════
        节点 2: SOCKS5-IPv6 ❌ 已禁用
═══════════════════════════════════════════════════════════════════════════════

EOF
        fi
    else
        cat >> "$info_file" << EOF
═══════════════════════════════════════════════════════════════════════════════
        节点 2: SOCKS5-IPv6 ⚠️ 不可用（VPS 无 IPv6）
═══════════════════════════════════════════════════════════════════════════════

EOF
    fi

    # VLESS-IPv4
    if [ "$VLESS_V4_ENABLED" = "true" ]; then
        cat >> "$info_file" << EOF
═══════════════════════════════════════════════════════════════════════════════
        节点 3: VLESS-IPv4（端口 $VLESS_V4_PORT） ✅ 已启用
═══════════════════════════════════════════════════════════════════════════════
  出站: 强制 IPv4 → $VPS_IP

  CF CDN 链接:
vless://${UUID}@${CDN_HOST}:${VLESS_V4_PORT}?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=${ep4}#VLESS-IPv4

EOF
    else
        cat >> "$info_file" << EOF
═══════════════════════════════════════════════════════════════════════════════
        节点 3: VLESS-IPv4 ❌ 已禁用
═══════════════════════════════════════════════════════════════════════════════

EOF
    fi

    # VLESS-IPv6
    if [ "$HAS_IPV6" = "true" ]; then
        if [ "$VLESS_V6_ENABLED" = "true" ]; then
            cat >> "$info_file" << EOF
═══════════════════════════════════════════════════════════════════════════════
        节点 4: VLESS-IPv6（端口 $VLESS_V6_PORT） ✅ 已启用
═══════════════════════════════════════════════════════════════════════════════
  出站: 强制 IPv6 → $IPV6_ADDR

  CF CDN 链接:
vless://${UUID}@${CDN_HOST}:${VLESS_V6_PORT}?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=${ep6}#VLESS-IPv6

EOF
        else
            cat >> "$info_file" << EOF
═══════════════════════════════════════════════════════════════════════════════
        节点 4: VLESS-IPv6 ❌ 已禁用
═══════════════════════════════════════════════════════════════════════════════

EOF
        fi
    else
        cat >> "$info_file" << EOF
═══════════════════════════════════════════════════════════════════════════════
        节点 4: VLESS-IPv6 ⚠️ 不可用（VPS 无 IPv6）
═══════════════════════════════════════════════════════════════════════════════

EOF
    fi

    # 使用说明
    cat >> "$info_file" << EOF
═══════════════════════════════════════════════════════════════════════════════
                              使用说明
═══════════════════════════════════════════════════════════════════════════════

  Cloudflare 设置:
    - DNS 代理: 开启 (橙色云)
    - SSL/TLS: 完全（严格）
    - 网络 → WebSockets: 开启

  防火墙放行:
EOF

    [ "$SOCKS5_V4_ENABLED" = "true" ] && echo "    ufw allow $SOCKS5_V4_PORT/tcp" >> "$info_file"
    [ "$SOCKS5_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && echo "    ufw allow $SOCKS5_V6_PORT/tcp" >> "$info_file"
    [ "$VLESS_V4_ENABLED" = "true" ] && echo "    ufw allow $VLESS_V4_PORT/tcp" >> "$info_file"
    [ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && echo "    ufw allow $VLESS_V6_PORT/tcp" >> "$info_file"

    cat >> "$info_file" << EOF

═══════════════════════════════════════════════════════════════════════════════
                          WebRTC 防泄露说明
═══════════════════════════════════════════════════════════════════════════════

  服务端已拦截常见 STUN 服务器，建议额外配置浏览器:

  Firefox:
    地址栏输入 about:config
    搜索 media.peerconnection.enabled 设为 false

  Chrome:
    安装插件 "WebRTC Leak Prevent"
    设置为 "Disable non-proxied UDP"

  测试是否泄露:
    https://browserleaks.com/webrtc
    https://ipleak.net

═══════════════════════════════════════════════════════════════════════════════
EOF
}

#===============================================================================
# 管理脚本生成
#===============================================================================

create_management() {
    print_info "创建管理脚本..."
    
    cat > "$INSTALL_DIR/manage.sh" << 'MANAGE_SCRIPT'
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

DIR="/root/xray"
SERVICE="xray-v6"
PARAMS_FILE="$DIR/params.conf"
SCRIPT_VERSION="8.3"

# 加载参数
load_params() {
    if [ -f "$PARAMS_FILE" ]; then
        source "$PARAMS_FILE"
        return 0
    fi
    echo -e "${RED}参数文件不存在: $PARAMS_FILE${NC}"
    return 1
}

# 保存参数
save_params() {
    cat > "$PARAMS_FILE" << EOF
# Xray 配置参数 v${SCRIPT_VERSION}
# 更新时间: $(date '+%Y-%m-%d %H:%M:%S')

DOMAIN="${DOMAIN}"
EMAIL="${EMAIL}"
UUID="${UUID}"
VPS_IP="${VPS_IP}"
IPV6_ADDR="${IPV6_ADDR}"
HAS_IPV6="${HAS_IPV6}"
CDN_HOST="${CDN_HOST}"

SOCKS5_V4_ENABLED="${SOCKS5_V4_ENABLED}"
SOCKS5_V4_PORT="${SOCKS5_V4_PORT}"
SOCKS5_V4_USER="${SOCKS5_V4_USER}"
SOCKS5_V4_PASS="${SOCKS5_V4_PASS}"

SOCKS5_V6_ENABLED="${SOCKS5_V6_ENABLED}"
SOCKS5_V6_PORT="${SOCKS5_V6_PORT}"
SOCKS5_V6_USER="${SOCKS5_V6_USER}"
SOCKS5_V6_PASS="${SOCKS5_V6_PASS}"

VLESS_V4_ENABLED="${VLESS_V4_ENABLED}"
VLESS_V4_PORT="${VLESS_V4_PORT}"
VLESS_V4_PATH="${VLESS_V4_PATH}"

VLESS_V6_ENABLED="${VLESS_V6_ENABLED}"
VLESS_V6_PORT="${VLESS_V6_PORT}"
VLESS_V6_PATH="${VLESS_V6_PATH}"
EOF
    chmod 600 "$PARAMS_FILE"
}

# 重新生成配置和信息
regenerate_all() {
    load_params || return 1
    
    if [ -z "$UUID" ]; then
        echo -e "${RED}错误: UUID 为空${NC}"
        return 1
    fi
    
    # ==================== 生成 config.json ====================
    local inbounds=""
    local first=true
    
    # SOCKS5-IPv4
    if [ "$SOCKS5_V4_ENABLED" = "true" ]; then
        [ "$first" = "false" ] && inbounds+=","
        inbounds+='{"tag":"socks-v4-in","listen":"::","port":'$SOCKS5_V4_PORT',"protocol":"socks","settings":{"auth":"password","accounts":[{"user":"'$SOCKS5_V4_USER'","pass":"'$SOCKS5_V4_PASS'"}],"udp":true}}'
        first=false
    fi
    
    # SOCKS5-IPv6
    if [ "$SOCKS5_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ]; then
        [ "$first" = "false" ] && inbounds+=","
        inbounds+='{"tag":"socks-v6-in","listen":"::","port":'$SOCKS5_V6_PORT',"protocol":"socks","settings":{"auth":"password","accounts":[{"user":"'$SOCKS5_V6_USER'","pass":"'$SOCKS5_V6_PASS'"}],"udp":true}}'
        first=false
    fi
    
    # VLESS-IPv4
    if [ "$VLESS_V4_ENABLED" = "true" ]; then
        [ "$first" = "false" ] && inbounds+=","
        inbounds+='{"tag":"vless-v4-in","listen":"::","port":'$VLESS_V4_PORT',"protocol":"vless","settings":{"clients":[{"id":"'$UUID'"}],"decryption":"none"},"streamSettings":{"network":"ws","security":"tls","tlsSettings":{"certificates":[{"certificateFile":"'$DIR'/cert/fullchain.crt","keyFile":"'$DIR'/cert/private.key"}]},"wsSettings":{"path":"'$VLESS_V4_PATH'"}}}'
        first=false
    fi
    
    # VLESS-IPv6
    if [ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ]; then
        [ "$first" = "false" ] && inbounds+=","
        inbounds+='{"tag":"vless-v6-in","listen":"::","port":'$VLESS_V6_PORT',"protocol":"vless","settings":{"clients":[{"id":"'$UUID'"}],"decryption":"none"},"streamSettings":{"network":"ws","security":"tls","tlsSettings":{"certificates":[{"certificateFile":"'$DIR'/cert/fullchain.crt","keyFile":"'$DIR'/cert/private.key"}]},"wsSettings":{"path":"'$VLESS_V6_PATH'"}}}'
        first=false
    fi
    
    if [ "$first" = "true" ]; then
        echo -e "${RED}没有启用任何节点${NC}"
        return 1
    fi
    
    # Outbounds
    local outbounds='{"tag":"IPv4-out","protocol":"freedom","settings":{"domainStrategy":"UseIPv4"},"sendThrough":"'$VPS_IP'"}'
    [ "$HAS_IPV6" = "true" ] && outbounds+=',{"tag":"IPv6-out","protocol":"freedom","settings":{"domainStrategy":"UseIPv6"},"sendThrough":"'$IPV6_ADDR'"}'
    outbounds+=',{"tag":"direct","protocol":"freedom"},{"tag":"block","protocol":"blackhole"}'
    
    # Routing tags
    local v4="" v6=""
    [ "$SOCKS5_V4_ENABLED" = "true" ] && v4='"socks-v4-in"'
    [ "$VLESS_V4_ENABLED" = "true" ] && { [ -n "$v4" ] && v4+=","; v4+='"vless-v4-in"'; }
    [ "$SOCKS5_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && v6='"socks-v6-in"'
    [ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && { [ -n "$v6" ] && v6+=","; v6+='"vless-v6-in"'; }
    
    # WebRTC/STUN 拦截规则（放在最前面）
    local rules='{"type":"field","domain":["keyword:stun","keyword:turn","domain:stun.l.google.com","domain:stun1.l.google.com","domain:stun2.l.google.com","domain:stun3.l.google.com","domain:stun4.l.google.com","domain:stun.ekiga.net","domain:stun.ideasip.com","domain:stun.schlund.de","domain:stun.stunprotocol.org","domain:stun.voiparound.com","domain:stun.voipbuster.com","domain:stun.voipstunt.com","domain:stun.qq.com","domain:stun.miwifi.com","domain:stun.chat.bilibili.com","domain:stun.syncthing.net"],"outboundTag":"block"}'
    
    # IPv4/IPv6 路由规则
    [ -n "$v4" ] && rules+=',{"type":"field","inboundTag":['$v4'],"outboundTag":"IPv4-out"}'
    [ -n "$v6" ] && rules+=',{"type":"field","inboundTag":['$v6'],"outboundTag":"IPv6-out"}'
    rules+=',{"type":"field","protocol":["bittorrent"],"outboundTag":"block"}'
    
    # 写入配置文件
    echo '{"log":{"loglevel":"warning","access":"'$DIR'/log/access.log","error":"'$DIR'/log/error.log"},"inbounds":['$inbounds'],"outbounds":['$outbounds'],"routing":{"domainStrategy":"AsIs","rules":['$rules']}}' > "$DIR/config/config.json"
    
    # 验证配置
    if ! "$DIR/bin/xray" run -test -c "$DIR/config/config.json" >/dev/null 2>&1; then
        echo -e "${RED}配置验证失败${NC}"
        "$DIR/bin/xray" run -test -c "$DIR/config/config.json"
        return 1
    fi
    
    # ==================== 生成 info.txt ====================
    local ep4=$(echo "$VLESS_V4_PATH" | sed 's/\//%2F/g')
    local ep6=$(echo "$VLESS_V6_PATH" | sed 's/\//%2F/g')
    
    {
        echo ""
        echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
        echo "║                      四合一代理节点配置信息 v${SCRIPT_VERSION}                            ║"
        echo "║                     已启用 WebRTC/STUN 拦截防止泄露                           ║"
        echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo "                                 基本信息"
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo "  VPS IPv4:    $VPS_IP"
        echo "  VPS IPv6:    ${IPV6_ADDR:-无}"
        echo "  域名:        $DOMAIN"
        echo "  UUID:        $UUID"
        echo "  优选地址:    $CDN_HOST"
        echo "  WebRTC拦截:  ✅ 已启用"
        echo ""
        
        if [ "$SOCKS5_V4_ENABLED" = "true" ]; then
            echo "═══════════════════════════════════════════════════════════════════════════════"
            echo "        节点 1: SOCKS5-IPv4（端口 $SOCKS5_V4_PORT） ✅"
            echo "═══════════════════════════════════════════════════════════════════════════════"
            echo "  出站: 强制 IPv4 → $VPS_IP"
            echo "  链接: socks5://${SOCKS5_V4_USER}:${SOCKS5_V4_PASS}@${VPS_IP}:${SOCKS5_V4_PORT}"
            echo ""
        fi
        
        if [ "$SOCKS5_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ]; then
            echo "═══════════════════════════════════════════════════════════════════════════════"
            echo "        节点 2: SOCKS5-IPv6（端口 $SOCKS5_V6_PORT） ✅"
            echo "═══════════════════════════════════════════════════════════════════════════════"
            echo "  出站: 强制 IPv6 → $IPV6_ADDR"
            echo "  链接: socks5://${SOCKS5_V6_USER}:${SOCKS5_V6_PASS}@${VPS_IP}:${SOCKS5_V6_PORT}"
            echo ""
        fi
        
        if [ "$VLESS_V4_ENABLED" = "true" ]; then
            echo "═══════════════════════════════════════════════════════════════════════════════"
            echo "        节点 3: VLESS-IPv4（端口 $VLESS_V4_PORT） ✅"
            echo "═══════════════════════════════════════════════════════════════════════════════"
            echo "  出站: 强制 IPv4 → $VPS_IP"
            echo "  链接: vless://${UUID}@${CDN_HOST}:${VLESS_V4_PORT}?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=${ep4}#VLESS-IPv4"
            echo ""
        fi
        
        if [ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ]; then
            echo "═══════════════════════════════════════════════════════════════════════════════"
            echo "        节点 4: VLESS-IPv6（端口 $VLESS_V6_PORT） ✅"
            echo "═══════════════════════════════════════════════════════════════════════════════"
            echo "  出站: 强制 IPv6 → $IPV6_ADDR"
            echo "  链接: vless://${UUID}@${CDN_HOST}:${VLESS_V6_PORT}?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=${ep6}#VLESS-IPv6"
            echo ""
        fi
        
        echo "═══════════════════════════════════════════════════════════════════════════════"
        echo "  浏览器防 WebRTC 泄露:"
        echo "    Firefox: about:config → media.peerconnection.enabled → false"
        echo "    Chrome:  安装 WebRTC Leak Prevent 插件"
        echo "  测试: https://browserleaks.com/webrtc"
        echo "═══════════════════════════════════════════════════════════════════════════════"
    } > "$DIR/info.txt"
    
    echo -e "${GREEN}配置已更新${NC}"
    return 0
}

# 显示菜单
show_menu() {
    clear
    load_params 2>/dev/null
    
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║            Xray 四合一代理 管理面板 v${SCRIPT_VERSION}                     ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # 服务状态
    if systemctl is-active --quiet $SERVICE 2>/dev/null; then
        echo -e "  服务状态: ${GREEN}● 运行中${NC}"
    else
        echo -e "  服务状态: ${RED}● 已停止${NC}"
    fi
    
    # UUID 显示
    if [ -n "$UUID" ]; then
        echo -e "  UUID: ${YELLOW}${UUID:0:8}...${UUID: -4}${NC}"
    fi
    
    echo -e "  WebRTC拦截: ${GREEN}✅ 已启用${NC}"
    
    echo ""
    echo -e "${CYAN}─────────────────── 服务管理 ───────────────────${NC}"
    echo -e "  ${GREEN}1.${NC} 查看节点信息"
    echo -e "  ${GREEN}2.${NC} 启动服务"
    echo -e "  ${GREEN}3.${NC} 停止服务"
    echo -e "  ${GREEN}4.${NC} 重启服务"
    echo -e "  ${GREEN}5.${NC} 查看运行状态"
    echo -e "  ${GREEN}6.${NC} 查看实时日志"
    echo -e "${CYAN}─────────────────── 节点管理 ───────────────────${NC}"
    echo -e "  ${GREEN}7.${NC} 修改 UUID"
    echo -e "  ${GREEN}8.${NC} 修改端口"
    echo -e "  ${GREEN}9.${NC} 启用/禁用节点"
    echo -e "${CYAN}─────────────────── 系统管理 ───────────────────${NC}"
    echo -e "  ${GREEN}10.${NC} 编辑配置文件"
    echo -e "  ${GREEN}11.${NC} 测试配置文件"
    echo -e "  ${GREEN}12.${NC} 更新 Xray 内核"
    echo -e "  ${RED}13.${NC} 卸载服务"
    echo -e "  ${GREEN}0.${NC} 退出"
    echo -e "${CYAN}─────────────────────────────────────────────────${NC}"
    echo ""
}

# 查看节点信息
show_info() {
    clear
    if [ -f "$DIR/info.txt" ]; then
        cat "$DIR/info.txt"
    else
        echo -e "${RED}配置信息文件不存在${NC}"
    fi
    echo ""
    echo -e "${YELLOW}按回车键返回菜单...${NC}"
    read
}

# 启动服务
start_service() {
    echo -e "${BLUE}正在启动服务...${NC}"
    systemctl start $SERVICE
    sleep 2
    if systemctl is-active --quiet $SERVICE; then
        echo -e "${GREEN}服务启动成功${NC}"
    else
        echo -e "${RED}服务启动失败${NC}"
        journalctl -u $SERVICE --no-pager -n 5
    fi
    sleep 2
}

# 停止服务
stop_service() {
    echo -e "${BLUE}正在停止服务...${NC}"
    systemctl stop $SERVICE
    echo -e "${GREEN}服务已停止${NC}"
    sleep 2
}

# 重启服务
restart_service() {
    echo -e "${BLUE}正在重启服务...${NC}"
    systemctl restart $SERVICE
    sleep 2
    if systemctl is-active --quiet $SERVICE; then
        echo -e "${GREEN}服务重启成功${NC}"
    else
        echo -e "${RED}服务重启失败${NC}"
        journalctl -u $SERVICE --no-pager -n 5
    fi
    sleep 2
}

# 查看运行状态
show_status() {
    clear
    echo -e "${CYAN}═══════════════════ 服务状态 ═══════════════════${NC}"
    echo ""
    systemctl status $SERVICE --no-pager
    echo ""
    echo -e "${CYAN}═══════════════════ 端口监听 ═══════════════════${NC}"
    echo ""
    ss -tlnp 2>/dev/null | grep -E "xray|$SOCKS5_V4_PORT|$SOCKS5_V6_PORT|$VLESS_V4_PORT|$VLESS_V6_PORT" || echo "未找到监听端口"
    echo ""
    echo -e "${YELLOW}按回车键返回菜单...${NC}"
    read
}

# 查看实时日志
show_log() {
    clear
    echo -e "${CYAN}═══════════════════ 实时日志 ═══════════════════${NC}"
    echo -e "${YELLOW}按 Ctrl+C 退出日志查看${NC}"
    echo ""
    tail -f "$DIR/log/error.log" 2>/dev/null || tail -f "$DIR/log/access.log" 2>/dev/null || echo "日志文件不存在"
}

# 修改 UUID
modify_uuid() {
    load_params
    echo ""
    echo -e "当前 UUID: ${YELLOW}$UUID${NC}"
    echo -n -e "输入新 UUID (回车随机生成): "
    read new_uuid
    
    if [ -z "$new_uuid" ]; then
        new_uuid=$("$DIR/bin/xray" uuid 2>/dev/null)
        if [ -z "$new_uuid" ]; then
            new_uuid=$(cat /proc/sys/kernel/random/uuid)
        fi
    fi
    
    UUID="$new_uuid"
    save_params
    
    if regenerate_all; then
        echo -e "${GREEN}UUID 已更新: $UUID${NC}"
        echo -n -e "${YELLOW}是否重启服务？(y/n): ${NC}"
        read r
        if [ "$r" = "y" ] || [ "$r" = "Y" ]; then
            restart_service
        fi
    fi
    sleep 2
}

# 修改端口
modify_port() {
    load_params
    echo ""
    echo -e "  ${GREEN}1.${NC} SOCKS5-IPv4 (当前: $SOCKS5_V4_PORT)"
    echo -e "  ${GREEN}2.${NC} SOCKS5-IPv6 (当前: $SOCKS5_V6_PORT)"
    echo -e "  ${GREEN}3.${NC} VLESS-IPv4  (当前: $VLESS_V4_PORT)"
    echo -e "  ${GREEN}4.${NC} VLESS-IPv6  (当前: $VLESS_V6_PORT)"
    echo -e "  ${GREEN}0.${NC} 返回"
    echo ""
    echo -n "选择节点: "
    read choice
    
    [ "$choice" = "0" ] && return
    
    echo -n "输入新端口 (1-65535): "
    read new_port
    
    # 验证端口
    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
        echo -e "${RED}无效端口${NC}"
        sleep 2
        return
    fi
    
    case $choice in
        1) SOCKS5_V4_PORT=$new_port ;;
        2) SOCKS5_V6_PORT=$new_port ;;
        3) VLESS_V4_PORT=$new_port ;;
        4) VLESS_V6_PORT=$new_port ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 2; return ;;
    esac
    
    save_params
    
    if regenerate_all; then
        echo -e "${GREEN}端口已更新${NC}"
        echo -n -e "${YELLOW}是否重启服务？(y/n): ${NC}"
        read r
        if [ "$r" = "y" ] || [ "$r" = "Y" ]; then
            restart_service
        fi
    fi
    sleep 2
}

# 启用/禁用节点
toggle_node() {
    load_params
    echo ""
    echo -e "  ${GREEN}1.${NC} SOCKS5-IPv4 [$([ "$SOCKS5_V4_ENABLED" = "true" ] && echo -e "${GREEN}✅${NC}" || echo -e "${RED}❌${NC}")]"
    echo -e "  ${GREEN}2.${NC} SOCKS5-IPv6 [$([ "$SOCKS5_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && echo -e "${GREEN}✅${NC}" || echo -e "${RED}❌${NC}")]$([ "$HAS_IPV6" != "true" ] && echo " (无IPv6)")"
    echo -e "  ${GREEN}3.${NC} VLESS-IPv4  [$([ "$VLESS_V4_ENABLED" = "true" ] && echo -e "${GREEN}✅${NC}" || echo -e "${RED}❌${NC}")]"
    echo -e "  ${GREEN}4.${NC} VLESS-IPv6  [$([ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && echo -e "${GREEN}✅${NC}" || echo -e "${RED}❌${NC}")]$([ "$HAS_IPV6" != "true" ] && echo " (无IPv6)")"
    echo -e "  ${GREEN}0.${NC} 返回"
    echo ""
    echo -n "选择切换: "
    read choice
    
    case $choice in
        0) return ;;
        1) [ "$SOCKS5_V4_ENABLED" = "true" ] && SOCKS5_V4_ENABLED="false" || SOCKS5_V4_ENABLED="true" ;;
        2)
            if [ "$HAS_IPV6" != "true" ]; then
                echo -e "${RED}VPS 无 IPv6，无法启用${NC}"
                sleep 2
                return
            fi
            [ "$SOCKS5_V6_ENABLED" = "true" ] && SOCKS5_V6_ENABLED="false" || SOCKS5_V6_ENABLED="true"
            ;;
        3) [ "$VLESS_V4_ENABLED" = "true" ] && VLESS_V4_ENABLED="false" || VLESS_V4_ENABLED="true" ;;
        4)
            if [ "$HAS_IPV6" != "true" ]; then
                echo -e "${RED}VPS 无 IPv6，无法启用${NC}"
                sleep 2
                return
            fi
            [ "$VLESS_V6_ENABLED" = "true" ] && VLESS_V6_ENABLED="false" || VLESS_V6_ENABLED="true"
            ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 2; return ;;
    esac
    
    save_params
    
    if regenerate_all; then
        echo -e "${GREEN}状态已更新${NC}"
        echo -n -e "${YELLOW}是否重启服务？(y/n): ${NC}"
        read r
        if [ "$r" = "y" ] || [ "$r" = "Y" ]; then
            restart_service
        fi
    fi
    sleep 2
}

# 编辑配置文件
edit_config() {
    if command -v nano &>/dev/null; then
        nano "$DIR/config/config.json"
    elif command -v vim &>/dev/null; then
        vim "$DIR/config/config.json"
    else
        vi "$DIR/config/config.json"
    fi
    echo ""
    echo -n -e "${YELLOW}是否重启服务？(y/n): ${NC}"
    read r
    if [ "$r" = "y" ] || [ "$r" = "Y" ]; then
        restart_service
    fi
}

# 测试配置文件
test_config() {
    clear
    echo -e "${CYAN}═══════════════════ 配置测试 ═══════════════════${NC}"
    echo ""
    "$DIR/bin/xray" run -test -c "$DIR/config/config.json"
    echo ""
    echo -e "${YELLOW}按回车键返回菜单...${NC}"
    read
}

# 更新 Xray 内核
update_xray() {
    clear
    echo -e "${CYAN}═══════════════════ 更新 Xray ═══════════════════${NC}"
    echo ""
    
    local current=$("$DIR/bin/xray" version 2>/dev/null | head -1 | awk '{print $2}')
    local latest=$(curl -sL --max-time 10 https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name"' | head -1 | cut -d'"' -f4)
    
    echo -e "当前版本: ${YELLOW}${current:-未知}${NC}"
    echo -e "最新版本: ${GREEN}${latest:-获取失败}${NC}"
    echo ""
    
    if [ -z "$latest" ]; then
        echo -e "${RED}无法获取最新版本信息${NC}"
        sleep 3
        return
    fi
    
    if [ "$current" = "$latest" ]; then
        echo -e "${GREEN}已是最新版本${NC}"
        sleep 3
        return
    fi
    
    echo -n -e "${YELLOW}是否更新？(y/n): ${NC}"
    read u
    
    if [ "$u" = "y" ] || [ "$u" = "Y" ]; then
        local arch=$(uname -m)
        case "$arch" in
            x86_64) arch="64" ;;
            aarch64) arch="arm64-v8a" ;;
            armv7l) arch="arm32-v7a" ;;
            *) echo -e "${RED}不支持的架构: $arch${NC}"; sleep 3; return ;;
        esac
        
        echo -e "${BLUE}正在下载...${NC}"
        cd "$DIR"
        
        if wget -q --show-progress -O xray.zip "https://github.com/XTLS/Xray-core/releases/download/${latest}/Xray-linux-${arch}.zip"; then
            systemctl stop $SERVICE 2>/dev/null
            unzip -o xray.zip -d bin/ >/dev/null 2>&1
            rm -f xray.zip
            chmod +x bin/xray
            systemctl start $SERVICE
            echo -e "${GREEN}更新成功${NC}"
        else
            echo -e "${RED}下载失败${NC}"
        fi
    fi
    sleep 3
}

# 卸载服务
uninstall() {
    clear
    echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                    ⚠️ 卸载警告                                ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}此操作将删除所有配置、证书和数据！${NC}"
    echo ""
    echo -n "输入 'yes' 确认卸载: "
    read confirm
    
    if [ "$confirm" = "yes" ]; then
        echo ""
        echo -e "${BLUE}正在卸载...${NC}"
        
        systemctl stop $SERVICE 2>/dev/null
        systemctl disable $SERVICE 2>/dev/null
        rm -f /etc/systemd/system/${SERVICE}.service
        rm -rf "$DIR"
        rm -f /usr/local/bin/xray-v6
        systemctl daemon-reload
        
        echo -e "${GREEN}卸载完成${NC}"
        exit 0
    else
        echo -e "${GREEN}已取消卸载${NC}"
    fi
    sleep 2
}

# 主循环
main() {
    while true; do
        show_menu
        echo -n "请选择 [0-13]: "
        read choice
        
        case $choice in
            1) show_info ;;
            2) start_service ;;
            3) stop_service ;;
            4) restart_service ;;
            5) show_status ;;
            6) show_log ;;
            7) modify_uuid ;;
            8) modify_port ;;
            9) toggle_node ;;
            10) edit_config ;;
            11) test_config ;;
            12) update_xray ;;
            13) uninstall ;;
            0) clear; echo -e "${GREEN}再见！${NC}"; exit 0 ;;
            *) echo -e "${RED}无效选项${NC}"; sleep 1 ;;
        esac
    done
}

main
MANAGE_SCRIPT

    chmod +x "$INSTALL_DIR/manage.sh"
    ln -sf "$INSTALL_DIR/manage.sh" /usr/local/bin/xray-v6
    
    print_success "管理脚本创建完成"
}

#===============================================================================
# 安装流程
#===============================================================================

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║          VLESS + SOCKS5 四合一安装脚本 v${SCRIPT_VERSION}                  ║"
    echo "╠═══════════════════════════════════════════════════════════════╣"
    echo "║  1. SOCKS5 - 仅 IPv4 出站                                    ║"
    echo "║  2. SOCKS5 - 仅 IPv6 出站                                    ║"
    echo "║  3. VLESS  - 仅 IPv4 出站（CF CDN）                          ║"
    echo "║  4. VLESS  - 仅 IPv6 出站（CF CDN）                          ║"
    echo "║                                                               ║"
    echo "║  ✅ 所有入站支持 IPv4/IPv6 双栈接入                          ║"
    echo "║  ✅ 内置 WebRTC/STUN 拦截防止 IP 泄露                        ║"
    echo "║  安装后使用 xray-v6 命令管理                                 ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    if [ "$(id -u)" != "0" ]; then
        print_error "请使用 root 用户运行此脚本"
        exit 1
    fi
    print_success "Root 权限检查通过"
}

check_system() {
    print_info "检测系统环境..."
    
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        OS="$ID"
    else
        OS="unknown"
    fi
    
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  XRAY_ARCH="64" ;;
        aarch64) XRAY_ARCH="arm64-v8a" ;;
        armv7l)  XRAY_ARCH="arm32-v7a" ;;
        *)
            print_error "不支持的架构: $ARCH"
            exit 1
            ;;
    esac
    
    print_success "系统: $OS | 架构: $ARCH"
}

check_network() {
    print_info "检测网络环境..."
    
    # 获取 IPv4
    VPS_IP=$(curl -4 -s --max-time 10 ip.sb 2>/dev/null)
    if [ -z "$VPS_IP" ]; then
        VPS_IP=$(curl -4 -s --max-time 10 ifconfig.me 2>/dev/null)
    fi
    if [ -z "$VPS_IP" ]; then
        VPS_IP=$(curl -4 -s --max-time 10 icanhazip.com 2>/dev/null)
    fi
    
    if [ -z "$VPS_IP" ]; then
        print_error "无法自动获取 VPS IPv4 地址"
        echo -n "请手动输入 VPS IPv4: "
        read VPS_IP
        [ -z "$VPS_IP" ] && exit 1
    fi
    print_success "IPv4: $VPS_IP"
    
    # 获取 IPv6
    IPV6_ADDR=$(ip -6 addr show scope global 2>/dev/null | grep -oP '(?<=inet6\s)[\da-f:]+' | head -1)
    
    if [ -n "$IPV6_ADDR" ]; then
        print_success "IPv6: $IPV6_ADDR"
        HAS_IPV6="true"
    else
        print_warning "IPv6: 未检测到"
        HAS_IPV6="false"
    fi
}

install_deps() {
    print_info "安装依赖包..."
    
    if command -v apt-get &>/dev/null; then
        apt-get update -y >/dev/null 2>&1
        apt-get install -y curl wget unzip socat cron openssl >/dev/null 2>&1
    elif command -v yum &>/dev/null; then
        yum install -y curl wget unzip socat cronie openssl >/dev/null 2>&1
    elif command -v dnf &>/dev/null; then
        dnf install -y curl wget unzip socat cronie openssl >/dev/null 2>&1
    else
        print_warning "未知包管理器，请确保已安装: curl wget unzip socat openssl"
    fi
    
    print_success "依赖安装完成"
}

cleanup_old() {
    print_info "清理旧安装..."
    
    # 备份证书
    local cert_backup=""
    if [ -f "$INSTALL_DIR/cert/fullchain.crt" ] && [ -f "$INSTALL_DIR/cert/private.key" ]; then
        cert_backup="/tmp/xray_cert_backup_$$"
        mkdir -p "$cert_backup"
        cp "$INSTALL_DIR/cert/fullchain.crt" "$cert_backup/" 2>/dev/null
        cp "$INSTALL_DIR/cert/private.key" "$cert_backup/" 2>/dev/null
        print_info "已备份现有证书"
    fi
    
    # 停止并删除旧服务
    systemctl stop $SERVICE_NAME >/dev/null 2>&1
    systemctl disable $SERVICE_NAME >/dev/null 2>&1
    rm -f /etc/systemd/system/${SERVICE_NAME}.service
    rm -rf "$INSTALL_DIR"
    rm -f /usr/local/bin/xray-v6
    systemctl daemon-reload >/dev/null 2>&1
    
    # 恢复证书
    if [ -n "$cert_backup" ] && [ -d "$cert_backup" ]; then
        mkdir -p "$INSTALL_DIR/cert"
        cp "$cert_backup/fullchain.crt" "$INSTALL_DIR/cert/" 2>/dev/null
        cp "$cert_backup/private.key" "$INSTALL_DIR/cert/" 2>/dev/null
        rm -rf "$cert_backup"
        print_info "已恢复证书"
    fi
    
    print_success "清理完成"
}

get_user_input() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  请输入配置信息${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    while [ -z "$DOMAIN" ]; do
        echo -n -e "请输入域名 (已解析到此VPS): "
        read DOMAIN
        if [ -z "$DOMAIN" ]; then
            print_error "域名不能为空"
        fi
    done
    
    echo -n -e "请输入邮箱 (用于证书申请，回车使用默认): "
    read EMAIL
    [ -z "$EMAIL" ] && EMAIL="admin@$DOMAIN"
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "  域名:       ${YELLOW}$DOMAIN${NC}"
    echo -e "  邮箱:       ${YELLOW}$EMAIL${NC}"
    echo -e "  IPv4:       ${YELLOW}$VPS_IP${NC}"
    echo -e "  IPv6:       ${YELLOW}${IPV6_ADDR:-无}${NC}"
    echo -e "  优选地址:   ${YELLOW}$CDN_HOST${NC}"
    echo -e "  WebRTC拦截: ${GREEN}✅ 将自动启用${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -n "确认安装？(y/n): "
    read confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "已取消安装"
        exit 0
    fi
}

create_dirs() {
    print_info "创建目录结构..."
    mkdir -p "$INSTALL_DIR"/{bin,config,cert,log,data}
    touch "$INSTALL_DIR/log/access.log"
    touch "$INSTALL_DIR/log/error.log"
    print_success "目录创建完成"
}

download_xray() {
    print_info "下载 Xray..."
    cd "$INSTALL_DIR"
    
    # 获取最新版本
    LATEST=$(curl -sL --max-time 15 https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name"' | head -1 | cut -d'"' -f4)
    [ -z "$LATEST" ] && LATEST="v24.11.21"
    
    print_info "版本: $LATEST"
    
    # 下载
    if ! wget -q --show-progress -O xray.zip "https://github.com/XTLS/Xray-core/releases/download/${LATEST}/Xray-linux-${XRAY_ARCH}.zip"; then
        print_error "下载 Xray 失败"
        exit 1
    fi
    
    # 解压
    unzip -o xray.zip -d bin/ >/dev/null 2>&1
    rm -f xray.zip
    chmod +x bin/xray
    
    # 生成 UUID
    UUID=$("$INSTALL_DIR/bin/xray" uuid)
    if [ -z "$UUID" ]; then
        UUID=$(cat /proc/sys/kernel/random/uuid)
    fi
    print_success "UUID: $UUID"
    
    # 下载规则文件
    print_info "下载规则文件..."
    wget -q -O data/geoip.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat" 2>/dev/null || true
    wget -q -O data/geosite.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat" 2>/dev/null || true
    
    print_success "Xray 下载完成"
}

install_cert() {
    print_info "检查 SSL 证书..."
    
    # 1. 检查本地已有证书
    if [ -f "$INSTALL_DIR/cert/fullchain.crt" ] && [ -f "$INSTALL_DIR/cert/private.key" ]; then
        # 验证证书是否有效（未过期）
        if openssl x509 -checkend 86400 -noout -in "$INSTALL_DIR/cert/fullchain.crt" 2>/dev/null; then
            print_success "使用已有证书"
            return 0
        else
            print_warning "现有证书已过期或即将过期，将重新申请"
            rm -f "$INSTALL_DIR/cert/fullchain.crt" "$INSTALL_DIR/cert/private.key"
        fi
    fi
    
    # 2. 检查 acme.sh ECC 证书
    if [ -f ~/.acme.sh/${DOMAIN}_ecc/fullchain.cer ] && [ -f ~/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.key ]; then
        print_info "发现 acme.sh 已有 ECC 证书，直接安装..."
        mkdir -p "$INSTALL_DIR/cert"
        cp ~/.acme.sh/${DOMAIN}_ecc/fullchain.cer "$INSTALL_DIR/cert/fullchain.crt"
        cp ~/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.key "$INSTALL_DIR/cert/private.key"
        
        # 设置自动续期
        ~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" --ecc \
            --key-file "$INSTALL_DIR/cert/private.key" \
            --fullchain-file "$INSTALL_DIR/cert/fullchain.crt" \
            --reloadcmd "systemctl restart $SERVICE_NAME" >/dev/null 2>&1
        
        print_success "证书安装完成"
        return 0
    fi
    
    # 3. 检查 acme.sh RSA 证书
    if [ -f ~/.acme.sh/${DOMAIN}/fullchain.cer ] && [ -f ~/.acme.sh/${DOMAIN}/${DOMAIN}.key ]; then
        print_info "发现 acme.sh RSA 证书..."
        mkdir -p "$INSTALL_DIR/cert"
        cp ~/.acme.sh/${DOMAIN}/fullchain.cer "$INSTALL_DIR/cert/fullchain.crt"
        cp ~/.acme.sh/${DOMAIN}/${DOMAIN}.key "$INSTALL_DIR/cert/private.key"
        print_success "证书安装完成"
        return 0
    fi
    
    # 4. 申请新证书
    print_info "申请新证书..."
    
    # 释放 80 端口
    fuser -k 80/tcp >/dev/null 2>&1
    sleep 2
    
    # 安装 acme.sh
    if [ ! -f ~/.acme.sh/acme.sh ]; then
        print_info "安装 acme.sh..."
        curl -sL https://get.acme.sh | sh -s email="$EMAIL" >/dev/null 2>&1
    fi
    
    if [ ! -f ~/.acme.sh/acme.sh ]; then
        print_error "acme.sh 安装失败"
        exit 1
    fi
    
    # 设置默认 CA
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt >/dev/null 2>&1
    
    print_warning "请确保: 域名 $DOMAIN 已解析到 $VPS_IP 且 Cloudflare 代理已关闭"
    echo ""
    
    # 申请证书
    if ! ~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone --keylength ec-256 --force; then
        print_error "证书申请失败"
        echo "请检查: 1.域名解析 2.80端口是否被占用 3.防火墙设置"
        exit 1
    fi
    
    # 安装证书
    mkdir -p "$INSTALL_DIR/cert"
    ~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" --ecc \
        --key-file "$INSTALL_DIR/cert/private.key" \
        --fullchain-file "$INSTALL_DIR/cert/fullchain.crt" \
        --reloadcmd "systemctl restart $SERVICE_NAME"
    
    if [ ! -f "$INSTALL_DIR/cert/fullchain.crt" ]; then
        print_error "证书安装失败"
        exit 1
    fi
    
    print_success "证书申请成功"
}

init_params() {
    print_info "初始化节点参数..."
    
    # SOCKS5-IPv4
    SOCKS5_V4_ENABLED="true"
    SOCKS5_V4_PORT=$(get_random_port 15000 20000)
    SOCKS5_V4_USER=$(random_string 10)
    SOCKS5_V4_PASS=$(random_password 12)
    
    # SOCKS5-IPv6
    if [ "$HAS_IPV6" = "true" ]; then
        SOCKS5_V6_ENABLED="true"
    else
        SOCKS5_V6_ENABLED="false"
    fi
    SOCKS5_V6_PORT=$(get_random_port 25000 30000)
    SOCKS5_V6_USER=$(random_string 10)
    SOCKS5_V6_PASS=$(random_password 12)
    
    # VLESS-IPv4
    VLESS_V4_ENABLED="true"
    VLESS_V4_PORT="2053"
    VLESS_V4_PATH="/$(random_string 8)"
    
    # VLESS-IPv6
    if [ "$HAS_IPV6" = "true" ]; then
        VLESS_V6_ENABLED="true"
    else
        VLESS_V6_ENABLED="false"
    fi
    VLESS_V6_PORT="2083"
    VLESS_V6_PATH="/$(random_string 8)"
    
    # 确保 UUID 存在
    if [ -z "$UUID" ]; then
        UUID=$("$INSTALL_DIR/bin/xray" uuid 2>/dev/null)
        [ -z "$UUID" ] && UUID=$(cat /proc/sys/kernel/random/uuid)
        print_warning "重新生成 UUID: $UUID"
    fi
    
    # 保存参数
    save_params
    
    print_success "参数初始化完成"
}

create_service() {
    print_info "创建系统服务..."
    
    cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=Xray Service
Documentation=https://github.com/XTLS/Xray-core
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
Environment=XRAY_LOCATION_ASSET=$INSTALL_DIR/data
ExecStart=$INSTALL_DIR/bin/xray run -c $INSTALL_DIR/config/config.json
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable $SERVICE_NAME >/dev/null 2>&1
    
    print_success "服务创建完成"
}

show_result() {
    clear
    
    if [ -f "$INSTALL_DIR/info.txt" ]; then
        cat "$INSTALL_DIR/info.txt"
    fi
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    ✅ 安装完成！                              ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  管理命令: ${CYAN}xray-v6${NC}"
    echo ""
    
    # 显示需要放行的端口
    echo -e "${YELLOW}  请放行以下防火墙端口:${NC}"
    [ "$SOCKS5_V4_ENABLED" = "true" ] && echo -e "    - $SOCKS5_V4_PORT/tcp (SOCKS5-IPv4)"
    [ "$SOCKS5_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && echo -e "    - $SOCKS5_V6_PORT/tcp (SOCKS5-IPv6)"
    [ "$VLESS_V4_ENABLED" = "true" ] && echo -e "    - $VLESS_V4_PORT/tcp (VLESS-IPv4)"
    [ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && echo -e "    - $VLESS_V6_PORT/tcp (VLESS-IPv6)"
    echo ""
}

#===============================================================================
# 主函数
#===============================================================================

main() {
    # 取消 set -e，改用手动错误处理
    set +e
    
    print_banner
    check_root
    check_system
    check_network
    get_user_input
    
    echo ""
    print_info "==================== 开始安装 ===================="
    echo ""
    
    install_deps
    cleanup_old
    create_dirs
    download_xray
    install_cert
    init_params
    
    # 生成配置
    print_info "生成 Xray 配置..."
    if ! generate_xray_config; then
        print_error "配置生成失败，请检查参数"
        exit 1
    fi
    print_success "配置生成完成"
    
    # 生成信息文件
    print_info "生成节点信息..."
    generate_info
    print_success "信息生成完成"
    
    create_service
    create_management
    
    # 启动服务
    print_info "启动服务..."
    systemctl start $SERVICE_NAME
    sleep 3
    
    if systemctl is-active --quiet $SERVICE_NAME; then
        print_success "服务启动成功"
    else
        print_error "服务启动失败"
        echo ""
        echo "错误日志:"
        journalctl -u $SERVICE_NAME --no-pager -n 10
        echo ""
        echo "配置验证:"
        "$INSTALL_DIR/bin/xray" run -test -c "$INSTALL_DIR/config/config.json"
        exit 1
    fi
    
    echo ""
    print_info "==================== 安装完成 ===================="
    echo ""
    
    show_result
}

# 执行主函数
main "$@"
