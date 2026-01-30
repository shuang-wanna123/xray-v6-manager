#!/bin/bash

#===============================================================================
# VLESS + SOCKS5 四合一安装脚本 v8.1
# 1. SOCKS5 - 仅 IPv4 出站
# 2. SOCKS5 - 仅 IPv6 出站
# 3. VLESS  - 仅 IPv4 出站（CF CDN）
# 4. VLESS  - 仅 IPv6 出站（CF CDN）
# 所有入站支持 IPv4/IPv6 双栈接入
# 管理命令: xray-v6
#===============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="/root/xray"
SERVICE_NAME="xray-v6"
PARAMS_FILE="$INSTALL_DIR/params.conf"
CDN_HOST="visa.com"

# 全局变量
OS=""
ARCH=""
XRAY_ARCH=""
VPS_IP=""
IPV6_ADDR=""
HAS_IPV6="false"
DOMAIN=""
EMAIL=""
UUID=""

# 节点参数
SOCKS5_V4_ENABLED=""
SOCKS5_V4_PORT=""
SOCKS5_V4_USER=""
SOCKS5_V4_PASS=""

SOCKS5_V6_ENABLED=""
SOCKS5_V6_PORT=""
SOCKS5_V6_USER=""
SOCKS5_V6_PASS=""

VLESS_V4_ENABLED=""
VLESS_V4_PORT=""
VLESS_V4_PATH=""

VLESS_V6_ENABLED=""
VLESS_V6_PORT=""
VLESS_V6_PATH=""

#===============================================================================
# 工具函数
#===============================================================================

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

#===============================================================================
# 参数管理
#===============================================================================

save_params() {
    mkdir -p "$INSTALL_DIR"
    cat > "$PARAMS_FILE" << EOF
# Xray 配置参数 v8.1 - $(date)
DOMAIN="$DOMAIN"
EMAIL="$EMAIL"
UUID="$UUID"
VPS_IP="$VPS_IP"
IPV6_ADDR="$IPV6_ADDR"
HAS_IPV6="$HAS_IPV6"

# SOCKS5-IPv4
SOCKS5_V4_ENABLED="$SOCKS5_V4_ENABLED"
SOCKS5_V4_PORT="$SOCKS5_V4_PORT"
SOCKS5_V4_USER="$SOCKS5_V4_USER"
SOCKS5_V4_PASS="$SOCKS5_V4_PASS"

# SOCKS5-IPv6
SOCKS5_V6_ENABLED="$SOCKS5_V6_ENABLED"
SOCKS5_V6_PORT="$SOCKS5_V6_PORT"
SOCKS5_V6_USER="$SOCKS5_V6_USER"
SOCKS5_V6_PASS="$SOCKS5_V6_PASS"

# VLESS-IPv4
VLESS_V4_ENABLED="$VLESS_V4_ENABLED"
VLESS_V4_PORT="$VLESS_V4_PORT"
VLESS_V4_PATH="$VLESS_V4_PATH"

# VLESS-IPv6
VLESS_V6_ENABLED="$VLESS_V6_ENABLED"
VLESS_V6_PORT="$VLESS_V6_PORT"
VLESS_V6_PATH="$VLESS_V6_PATH"
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
    local inbounds=""
    local first=true
    
    # SOCKS5-IPv4
    if [ "$SOCKS5_V4_ENABLED" = "true" ]; then
        [ "$first" = "false" ] && inbounds+=","
        inbounds+='
    {
      "tag": "socks-v4-in",
      "listen": "::",
      "port": '$SOCKS5_V4_PORT',
      "protocol": "socks",
      "settings": {
        "auth": "password",
        "accounts": [{"user": "'"$SOCKS5_V4_USER"'", "pass": "'"$SOCKS5_V4_PASS"'"}],
        "udp": true
      }
    }'
        first=false
    fi
    
    # SOCKS5-IPv6
    if [ "$SOCKS5_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ]; then
        [ "$first" = "false" ] && inbounds+=","
        inbounds+='
    {
      "tag": "socks-v6-in",
      "listen": "::",
      "port": '$SOCKS5_V6_PORT',
      "protocol": "socks",
      "settings": {
        "auth": "password",
        "accounts": [{"user": "'"$SOCKS5_V6_USER"'", "pass": "'"$SOCKS5_V6_PASS"'"}],
        "udp": true
      }
    }'
        first=false
    fi
    
    # VLESS-IPv4
    if [ "$VLESS_V4_ENABLED" = "true" ]; then
        [ "$first" = "false" ] && inbounds+=","
        inbounds+='
    {
      "tag": "vless-v4-in",
      "listen": "::",
      "port": '$VLESS_V4_PORT',
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
        first=false
    fi
    
    # VLESS-IPv6
    if [ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ]; then
        [ "$first" = "false" ] && inbounds+=","
        inbounds+='
    {
      "tag": "vless-v6-in",
      "listen": "::",
      "port": '$VLESS_V6_PORT',
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
        first=false
    fi
    
    # Outbounds
    local outbounds='{"tag":"IPv4-out","protocol":"freedom","settings":{"domainStrategy":"UseIPv4"},"sendThrough":"'$VPS_IP'"}'
    
    if [ "$HAS_IPV6" = "true" ]; then
        outbounds+=',{"tag":"IPv6-out","protocol":"freedom","settings":{"domainStrategy":"UseIPv6"},"sendThrough":"'$IPV6_ADDR'"}'
    fi
    
    outbounds+=',{"tag":"direct","protocol":"freedom"},{"tag":"block","protocol":"blackhole"}'
    
    # Routing rules
    local v4_tags="" v6_tags=""
    [ "$SOCKS5_V4_ENABLED" = "true" ] && v4_tags='"socks-v4-in"'
    [ "$VLESS_V4_ENABLED" = "true" ] && { [ -n "$v4_tags" ] && v4_tags+=","; v4_tags+='"vless-v4-in"'; }
    
    if [ "$HAS_IPV6" = "true" ]; then
        [ "$SOCKS5_V6_ENABLED" = "true" ] && v6_tags='"socks-v6-in"'
        [ "$VLESS_V6_ENABLED" = "true" ] && { [ -n "$v6_tags" ] && v6_tags+=","; v6_tags+='"vless-v6-in"'; }
    fi
    
    local rules=""
    first=true
    [ -n "$v4_tags" ] && { rules='{"type":"field","inboundTag":['$v4_tags'],"outboundTag":"IPv4-out"}'; first=false; }
    [ -n "$v6_tags" ] && { [ "$first" = "false" ] && rules+=","; rules+='{"type":"field","inboundTag":['$v6_tags'],"outboundTag":"IPv6-out"}'; first=false; }
    [ "$first" = "false" ] && rules+=","
    rules+='{"type":"field","outboundTag":"block","protocol":["bittorrent"]}'
    
    # 写入配置文件
    cat > "$config_file" << EOFCONFIG
{
  "log": {
    "loglevel": "warning",
    "access": "$INSTALL_DIR/log/access.log",
    "error": "$INSTALL_DIR/log/error.log"
  },
  "inbounds": [$inbounds
  ],
  "outbounds": [$outbounds],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [$rules]
  }
}
EOFCONFIG

    # 验证配置
    "$INSTALL_DIR/bin/xray" run -test -c "$config_file" >/dev/null 2>&1
    return $?
}

generate_info() {
    local info_file="$INSTALL_DIR/info.txt"
    local ep4=$(echo "$VLESS_V4_PATH" | sed 's/\//%2F/g')
    local ep6=$(echo "$VLESS_V6_PATH" | sed 's/\//%2F/g')
    
    cat > "$info_file" << EOF

╔═══════════════════════════════════════════════════════════════════════════════╗
║                      四合一代理节点配置信息 v8.1                              ║
║                     所有入站支持 IPv4/IPv6 双栈接入                           ║
╚═══════════════════════════════════════════════════════════════════════════════╝

═══════════════════════════════════════════════════════════════════════════════
                                 基本信息
═══════════════════════════════════════════════════════════════════════════════
  VPS IPv4:   $VPS_IP
  VPS IPv6:   ${IPV6_ADDR:-无}
  域名:       $DOMAIN
  UUID:       $UUID
  优选地址:   $CDN_HOST
  管理命令:   xray-v6

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
        echo "═══════════════════════════════════════════════════════════════════════════════" >> "$info_file"
        echo "        节点 1: SOCKS5-IPv4 ❌ 已禁用" >> "$info_file"
        echo "═══════════════════════════════════════════════════════════════════════════════" >> "$info_file"
        echo "" >> "$info_file"
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
            echo "═══════════════════════════════════════════════════════════════════════════════" >> "$info_file"
            echo "        节点 2: SOCKS5-IPv6 ❌ 已禁用" >> "$info_file"
            echo "═══════════════════════════════════════════════════════════════════════════════" >> "$info_file"
            echo "" >> "$info_file"
        fi
    else
        echo "═══════════════════════════════════════════════════════════════════════════════" >> "$info_file"
        echo "        节点 2: SOCKS5-IPv6 ⚠️ 不可用（VPS 无 IPv6）" >> "$info_file"
        echo "═══════════════════════════════════════════════════════════════════════════════" >> "$info_file"
        echo "" >> "$info_file"
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
        echo "═══════════════════════════════════════════════════════════════════════════════" >> "$info_file"
        echo "        节点 3: VLESS-IPv4 ❌ 已禁用" >> "$info_file"
        echo "═══════════════════════════════════════════════════════════════════════════════" >> "$info_file"
        echo "" >> "$info_file"
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
            echo "═══════════════════════════════════════════════════════════════════════════════" >> "$info_file"
            echo "        节点 4: VLESS-IPv6 ❌ 已禁用" >> "$info_file"
            echo "═══════════════════════════════════════════════════════════════════════════════" >> "$info_file"
            echo "" >> "$info_file"
        fi
    else
        echo "═══════════════════════════════════════════════════════════════════════════════" >> "$info_file"
        echo "        节点 4: VLESS-IPv6 ⚠️ 不可用（VPS 无 IPv6）" >> "$info_file"
        echo "═══════════════════════════════════════════════════════════════════════════════" >> "$info_file"
        echo "" >> "$info_file"
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

    echo "" >> "$info_file"
    echo "═══════════════════════════════════════════════════════════════════════════════" >> "$info_file"
    echo "" >> "$info_file"
}

#===============================================================================
# 管理脚本生成
#===============================================================================

create_management() {
    cat > "$INSTALL_DIR/manage.sh" << 'EOFMANAGE'
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
CDN_HOST="visa.com"

# 加载参数
load_params() {
    if [ -f "$PARAMS_FILE" ]; then
        source "$PARAMS_FILE"
        return 0
    fi
    return 1
}

# 保存参数
save_params() {
    cat > "$PARAMS_FILE" << EOF
DOMAIN="$DOMAIN"
EMAIL="$EMAIL"
UUID="$UUID"
VPS_IP="$VPS_IP"
IPV6_ADDR="$IPV6_ADDR"
HAS_IPV6="$HAS_IPV6"
SOCKS5_V4_ENABLED="$SOCKS5_V4_ENABLED"
SOCKS5_V4_PORT="$SOCKS5_V4_PORT"
SOCKS5_V4_USER="$SOCKS5_V4_USER"
SOCKS5_V4_PASS="$SOCKS5_V4_PASS"
SOCKS5_V6_ENABLED="$SOCKS5_V6_ENABLED"
SOCKS5_V6_PORT="$SOCKS5_V6_PORT"
SOCKS5_V6_USER="$SOCKS5_V6_USER"
SOCKS5_V6_PASS="$SOCKS5_V6_PASS"
VLESS_V4_ENABLED="$VLESS_V4_ENABLED"
VLESS_V4_PORT="$VLESS_V4_PORT"
VLESS_V4_PATH="$VLESS_V4_PATH"
VLESS_V6_ENABLED="$VLESS_V6_ENABLED"
VLESS_V6_PORT="$VLESS_V6_PORT"
VLESS_V6_PATH="$VLESS_V6_PATH"
EOF
    chmod 600 "$PARAMS_FILE"
}

# 重新生成所有配置
regenerate_all() {
    load_params
    
    if [ -z "$UUID" ]; then
        echo -e "${RED}错误: UUID 为空${NC}"
        return 1
    fi
    
    # ========== 生成 config.json ==========
    local inbounds="" first=true
    
    if [ "$SOCKS5_V4_ENABLED" = "true" ]; then
        [ "$first" = "false" ] && inbounds+=","
        inbounds+='{"tag":"socks-v4-in","listen":"::","port":'$SOCKS5_V4_PORT',"protocol":"socks","settings":{"auth":"password","accounts":[{"user":"'$SOCKS5_V4_USER'","pass":"'$SOCKS5_V4_PASS'"}],"udp":true}}'
        first=false
    fi
    
    if [ "$SOCKS5_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ]; then
        [ "$first" = "false" ] && inbounds+=","
        inbounds+='{"tag":"socks-v6-in","listen":"::","port":'$SOCKS5_V6_PORT',"protocol":"socks","settings":{"auth":"password","accounts":[{"user":"'$SOCKS5_V6_USER'","pass":"'$SOCKS5_V6_PASS'"}],"udp":true}}'
        first=false
    fi
    
    if [ "$VLESS_V4_ENABLED" = "true" ]; then
        [ "$first" = "false" ] && inbounds+=","
        inbounds+='{"tag":"vless-v4-in","listen":"::","port":'$VLESS_V4_PORT',"protocol":"vless","settings":{"clients":[{"id":"'$UUID'"}],"decryption":"none"},"streamSettings":{"network":"ws","security":"tls","tlsSettings":{"certificates":[{"certificateFile":"'$DIR'/cert/fullchain.crt","keyFile":"'$DIR'/cert/private.key"}]},"wsSettings":{"path":"'$VLESS_V4_PATH'"}}}'
        first=false
    fi
    
    if [ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ]; then
        [ "$first" = "false" ] && inbounds+=","
        inbounds+='{"tag":"vless-v6-in","listen":"::","port":'$VLESS_V6_PORT',"protocol":"vless","settings":{"clients":[{"id":"'$UUID'"}],"decryption":"none"},"streamSettings":{"network":"ws","security":"tls","tlsSettings":{"certificates":[{"certificateFile":"'$DIR'/cert/fullchain.crt","keyFile":"'$DIR'/cert/private.key"}]},"wsSettings":{"path":"'$VLESS_V6_PATH'"}}}'
        first=false
    fi
    
    local outbounds='{"tag":"IPv4-out","protocol":"freedom","settings":{"domainStrategy":"UseIPv4"},"sendThrough":"'$VPS_IP'"}'
    [ "$HAS_IPV6" = "true" ] && outbounds+=',{"tag":"IPv6-out","protocol":"freedom","settings":{"domainStrategy":"UseIPv6"},"sendThrough":"'$IPV6_ADDR'"}'
    outbounds+=',{"tag":"direct","protocol":"freedom"},{"tag":"block","protocol":"blackhole"}'
    
    local v4="" v6=""
    [ "$SOCKS5_V4_ENABLED" = "true" ] && v4='"socks-v4-in"'
    [ "$VLESS_V4_ENABLED" = "true" ] && { [ -n "$v4" ] && v4+=","; v4+='"vless-v4-in"'; }
    [ "$SOCKS5_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && v6='"socks-v6-in"'
    [ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && { [ -n "$v6" ] && v6+=","; v6+='"vless-v6-in"'; }
    
    local rules="" first=true
    [ -n "$v4" ] && { rules='{"type":"field","inboundTag":['$v4'],"outboundTag":"IPv4-out"}'; first=false; }
    [ -n "$v6" ] && { [ "$first" = "false" ] && rules+=","; rules+='{"type":"field","inboundTag":['$v6'],"outboundTag":"IPv6-out"}'; first=false; }
    [ "$first" = "false" ] && rules+=","
    rules+='{"type":"field","outboundTag":"block","protocol":["bittorrent"]}'
    
    cat > "$DIR/config/config.json" << EOFCFG
{"log":{"loglevel":"warning","access":"$DIR/log/access.log","error":"$DIR/log/error.log"},"inbounds":[$inbounds],"outbounds":[$outbounds],"routing":{"domainStrategy":"AsIs","rules":[$rules]}}
EOFCFG

    # ========== 生成 info.txt ==========
    local ep4=$(echo "$VLESS_V4_PATH" | sed 's/\//%2F/g')
    local ep6=$(echo "$VLESS_V6_PATH" | sed 's/\//%2F/g')
    
    cat > "$DIR/info.txt" << EOFINFO

╔═══════════════════════════════════════════════════════════════════════════════╗
║                      四合一代理节点配置信息 v8.1                              ║
╚═══════════════════════════════════════════════════════════════════════════════╝

═══════════════════════════════════════════════════════════════════════════════
                                 基本信息
═══════════════════════════════════════════════════════════════════════════════
  VPS IPv4:   $VPS_IP
  VPS IPv6:   ${IPV6_ADDR:-无}
  域名:       $DOMAIN
  UUID:       $UUID
  优选地址:   $CDN_HOST
  管理命令:   xray-v6

EOFINFO

    if [ "$SOCKS5_V4_ENABLED" = "true" ]; then
        cat >> "$DIR/info.txt" << EOFINFO
═══════════════════════════════════════════════════════════════════════════════
        节点 1: SOCKS5-IPv4（端口 $SOCKS5_V4_PORT） ✅
═══════════════════════════════════════════════════════════════════════════════
  出站: 强制 IPv4 → $VPS_IP
  链接: socks5://${SOCKS5_V4_USER}:${SOCKS5_V4_PASS}@${VPS_IP}:${SOCKS5_V4_PORT}

EOFINFO
    fi

    if [ "$SOCKS5_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ]; then
        cat >> "$DIR/info.txt" << EOFINFO
═══════════════════════════════════════════════════════════════════════════════
        节点 2: SOCKS5-IPv6（端口 $SOCKS5_V6_PORT） ✅
═══════════════════════════════════════════════════════════════════════════════
  出站: 强制 IPv6 → $IPV6_ADDR
  链接: socks5://${SOCKS5_V6_USER}:${SOCKS5_V6_PASS}@${VPS_IP}:${SOCKS5_V6_PORT}

EOFINFO
    fi

    if [ "$VLESS_V4_ENABLED" = "true" ]; then
        cat >> "$DIR/info.txt" << EOFINFO
═══════════════════════════════════════════════════════════════════════════════
        节点 3: VLESS-IPv4（端口 $VLESS_V4_PORT） ✅
═══════════════════════════════════════════════════════════════════════════════
  出站: 强制 IPv4 → $VPS_IP
  链接: vless://${UUID}@${CDN_HOST}:${VLESS_V4_PORT}?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=${ep4}#VLESS-IPv4

EOFINFO
    fi

    if [ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ]; then
        cat >> "$DIR/info.txt" << EOFINFO
═══════════════════════════════════════════════════════════════════════════════
        节点 4: VLESS-IPv6（端口 $VLESS_V6_PORT） ✅
═══════════════════════════════════════════════════════════════════════════════
  出站: 强制 IPv6 → $IPV6_ADDR
  链接: vless://${UUID}@${CDN_HOST}:${VLESS_V6_PORT}?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=${ep6}#VLESS-IPv6

EOFINFO
    fi

    echo "═══════════════════════════════════════════════════════════════════════════════" >> "$DIR/info.txt"
    
    return 0
}

# 显示菜单
show_menu() {
    clear
    load_params
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║            Xray 四合一代理 管理面板 v8.1                     ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    if systemctl is-active --quiet $SERVICE; then
        echo -e "  服务状态: ${GREEN}● 运行中${NC}"
    else
        echo -e "  服务状态: ${RED}● 已停止${NC}"
    fi
    
    echo -e "  UUID: ${YELLOW}${UUID:0:8}...${UUID: -4}${NC}"
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

show_info() {
    clear
    [ -f "$DIR/info.txt" ] && cat "$DIR/info.txt" || echo -e "${RED}配置信息不存在${NC}"
    echo -e "\n${YELLOW}按回车返回...${NC}"
    read
}

start_service() {
    systemctl start $SERVICE
    sleep 1
    systemctl is-active --quiet $SERVICE && echo -e "${GREEN}启动成功${NC}" || echo -e "${RED}启动失败${NC}"
    sleep 2
}

stop_service() {
    systemctl stop $SERVICE
    echo -e "${GREEN}已停止${NC}"
    sleep 2
}

restart_service() {
    systemctl restart $SERVICE
    sleep 2
    systemctl is-active --quiet $SERVICE && echo -e "${GREEN}重启成功${NC}" || echo -e "${RED}重启失败${NC}"
    sleep 2
}

show_status() {
    clear
    systemctl status $SERVICE --no-pager
    echo ""
    ss -tlnp | grep xray
    echo -e "\n${YELLOW}按回车返回...${NC}"
    read
}

show_log() {
    clear
    echo -e "${YELLOW}按 Ctrl+C 退出${NC}\n"
    tail -f "$DIR/log/error.log"
}

modify_uuid() {
    load_params
    echo -e "\n当前 UUID: ${YELLOW}$UUID${NC}"
    echo -n -e "输入新 UUID (回车生成随机): "
    read new_uuid
    
    if [ -z "$new_uuid" ]; then
        new_uuid=$("$DIR/bin/xray" uuid)
    fi
    
    UUID="$new_uuid"
    save_params
    regenerate_all
    
    echo -e "${GREEN}UUID 已更新: $UUID${NC}"
    echo -n -e "${YELLOW}是否重启服务？(y/n): ${NC}"
    read r
    [ "$r" = "y" ] && restart_service
    sleep 2
}

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
    
    echo -n "输入新端口: "
    read new_port
    
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
    regenerate_all
    
    echo -e "${GREEN}端口已更新${NC}"
    echo -n -e "${YELLOW}是否重启服务？(y/n): ${NC}"
    read r
    [ "$r" = "y" ] && restart_service
    sleep 2
}

toggle_node() {
    load_params
    echo ""
    echo -e "  ${GREEN}1.${NC} SOCKS5-IPv4 [$([ "$SOCKS5_V4_ENABLED" = "true" ] && echo "✅" || echo "❌")]"
    echo -e "  ${GREEN}2.${NC} SOCKS5-IPv6 [$([ "$SOCKS5_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && echo "✅" || echo "❌")]"
    echo -e "  ${GREEN}3.${NC} VLESS-IPv4  [$([ "$VLESS_V4_ENABLED" = "true" ] && echo "✅" || echo "❌")]"
    echo -e "  ${GREEN}4.${NC} VLESS-IPv6  [$([ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && echo "✅" || echo "❌")]"
    echo -e "  ${GREEN}0.${NC} 返回"
    echo ""
    echo -n "选择切换: "
    read choice
    
    case $choice in
        1) [ "$SOCKS5_V4_ENABLED" = "true" ] && SOCKS5_V4_ENABLED="false" || SOCKS5_V4_ENABLED="true" ;;
        2) 
            if [ "$HAS_IPV6" != "true" ]; then
                echo -e "${RED}VPS 无 IPv6${NC}"
                sleep 2
                return
            fi
            [ "$SOCKS5_V6_ENABLED" = "true" ] && SOCKS5_V6_ENABLED="false" || SOCKS5_V6_ENABLED="true"
            ;;
        3) [ "$VLESS_V4_ENABLED" = "true" ] && VLESS_V4_ENABLED="false" || VLESS_V4_ENABLED="true" ;;
        4)
            if [ "$HAS_IPV6" != "true" ]; then
                echo -e "${RED}VPS 无 IPv6${NC}"
                sleep 2
                return
            fi
            [ "$VLESS_V6_ENABLED" = "true" ] && VLESS_V6_ENABLED="false" || VLESS_V6_ENABLED="true"
            ;;
        0) return ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 2; return ;;
    esac
    
    save_params
    regenerate_all
    
    echo -e "${GREEN}状态已更新${NC}"
    echo -n -e "${YELLOW}是否重启服务？(y/n): ${NC}"
    read r
    [ "$r" = "y" ] && restart_service
    sleep 2
}

edit_config() {
    if command -v nano &>/dev/null; then
        nano "$DIR/config/config.json"
    else
        vi "$DIR/config/config.json"
    fi
    echo -n -e "${YELLOW}是否重启服务？(y/n): ${NC}"
    read r
    [ "$r" = "y" ] && restart_service
}

test_config() {
    clear
    "$DIR/bin/xray" run -test -c "$DIR/config/config.json"
    echo -e "\n${YELLOW}按回车返回...${NC}"
    read
}

update_xray() {
    clear
    local current=$("$DIR/bin/xray" version 2>/dev/null | head -1 | awk '{print $2}')
    local latest=$(curl -sL https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name"' | head -1 | cut -d'"' -f4)
    
    echo -e "当前: ${YELLOW}$current${NC}"
    echo -e "最新: ${GREEN}$latest${NC}"
    
    if [ "$current" = "$latest" ]; then
        echo -e "${GREEN}已是最新${NC}"
    else
        echo -n -e "${YELLOW}是否更新？(y/n): ${NC}"
        read u
        if [ "$u" = "y" ]; then
            local arch=$(uname -m)
            case "$arch" in
                x86_64) arch="64" ;;
                aarch64) arch="arm64-v8a" ;;
            esac
            
            cd "$DIR"
            wget -q --show-progress -O xray.zip "https://github.com/XTLS/Xray-core/releases/download/${latest}/Xray-linux-${arch}.zip"
            
            if [ $? -eq 0 ]; then
                systemctl stop $SERVICE
                unzip -o xray.zip -d bin/ >/dev/null 2>&1
                rm -f xray.zip
                chmod +x bin/xray
                systemctl start $SERVICE
                echo -e "${GREEN}更新成功${NC}"
            else
                echo -e "${RED}下载失败${NC}"
            fi
        fi
    fi
    sleep 3
}

uninstall() {
    clear
    echo -e "${RED}警告：将删除所有配置！${NC}"
    echo -n "输入 yes 确认: "
    read c
    
    if [ "$c" = "yes" ]; then
        systemctl stop $SERVICE
        systemctl disable $SERVICE
        rm -f /etc/systemd/system/${SERVICE}.service
        rm -rf "$DIR"
        rm -f /usr/local/bin/xray-v6
        systemctl daemon-reload
        echo -e "${GREEN}卸载完成${NC}"
        exit 0
    fi
    sleep 2
}

# 主循环
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
        0) clear; exit 0 ;;
        *) echo -e "${RED}无效选项${NC}"; sleep 1 ;;
    esac
done
EOFMANAGE

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
    echo "║          VLESS + SOCKS5 四合一安装脚本 v8.1                  ║"
    echo "╠═══════════════════════════════════════════════════════════════╣"
    echo "║  1. SOCKS5 - 仅 IPv4 出站                                    ║"
    echo "║  2. SOCKS5 - 仅 IPv6 出站                                    ║"
    echo "║  3. VLESS  - 仅 IPv4 出站（CF CDN）                          ║"
    echo "║  4. VLESS  - 仅 IPv6 出站（CF CDN）                          ║"
    echo "║                                                               ║"
    echo "║  所有入站支持 IPv4/IPv6 双栈接入                             ║"
    echo "║  安装后使用 xray-v6 命令管理                                 ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    [ "$(id -u)" != "0" ] && { print_error "请使用 root 运行"; exit 1; }
    print_success "Root 权限检查通过"
}

check_system() {
    print_info "检测系统..."
    [ -f /etc/os-release ] && source /etc/os-release && OS="$ID" || OS="unknown"
    
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  XRAY_ARCH="64" ;;
        aarch64) XRAY_ARCH="arm64-v8a" ;;
        *)       print_error "不支持: $ARCH"; exit 1 ;;
    esac
    
    print_success "系统: $OS | 架构: $ARCH"
}

check_network() {
    print_info "检测网络..."
    
    VPS_IP=$(curl -4 -s --max-time 5 ip.sb || curl -4 -s --max-time 5 ifconfig.me)
    [ -z "$VPS_IP" ] && { print_error "无法获取 IPv4"; exit 1; }
    print_success "IPv4: $VPS_IP"
    
    IPV6_ADDR=$(ip -6 addr show scope global 2>/dev/null | grep -oP '(?<=inet6\s)[\da-f:]+' | head -1)
    if [ -n "$IPV6_ADDR" ]; then
        print_success "IPv6: $IPV6_ADDR"
        HAS_IPV6="true"
    else
        print_warning "IPv6: 无"
        HAS_IPV6="false"
    fi
}

install_deps() {
    print_info "安装依赖..."
    if command -v apt-get &>/dev/null; then
        apt-get update -y >/dev/null 2>&1
        apt-get install -y curl wget unzip socat cron openssl >/dev/null 2>&1
    else
        yum install -y curl wget unzip socat cronie openssl >/dev/null 2>&1
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
        cp "$INSTALL_DIR/cert/fullchain.crt" "$cert_backup/"
        cp "$INSTALL_DIR/cert/private.key" "$cert_backup/"
        print_info "已备份现有证书"
    fi
    
    systemctl stop $SERVICE_NAME >/dev/null 2>&1
    systemctl disable $SERVICE_NAME >/dev/null 2>&1
    rm -f /etc/systemd/system/${SERVICE_NAME}.service
    rm -rf "$INSTALL_DIR"
    rm -f /usr/local/bin/xray-v6
    systemctl daemon-reload
    
    # 恢复证书
    if [ -n "$cert_backup" ] && [ -d "$cert_backup" ]; then
        mkdir -p "$INSTALL_DIR/cert"
        cp "$cert_backup/fullchain.crt" "$INSTALL_DIR/cert/"
        cp "$cert_backup/private.key" "$INSTALL_DIR/cert/"
        rm -rf "$cert_backup"
        print_info "已恢复证书"
    fi
    
    print_success "清理完成"
}

get_user_input() {
    echo ""
    while [ -z "$DOMAIN" ]; do
        echo -n -e "${YELLOW}请输入域名: ${NC}"
        read DOMAIN
    done
    
    echo -n -e "请输入邮箱 (回车默认): "
    read EMAIL
    [ -z "$EMAIL" ] && EMAIL="admin@$DOMAIN"
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "  域名:      ${YELLOW}$DOMAIN${NC}"
    echo -e "  IPv4:      ${YELLOW}$VPS_IP${NC}"
    echo -e "  IPv6:      ${YELLOW}${IPV6_ADDR:-无}${NC}"
    echo -e "  优选地址:  ${YELLOW}$CDN_HOST${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -n "确认安装？(y/n): "
    read c
    [ "$c" != "y" ] && [ "$c" != "Y" ] && exit 0
}

create_dirs() {
    print_info "创建目录..."
    mkdir -p "$INSTALL_DIR"/{bin,config,cert,log,data}
    touch "$INSTALL_DIR/log/"{access,error}.log
    print_success "目录创建完成"
}

download_xray() {
    print_info "下载 Xray..."
    cd "$INSTALL_DIR"
    
    LATEST=$(curl -sL https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name"' | head -1 | cut -d'"' -f4)
    [ -z "$LATEST" ] && LATEST="v24.11.21"
    
    print_info "版本: $LATEST"
    
    wget -q --show-progress -O xray.zip "https://github.com/XTLS/Xray-core/releases/download/${LATEST}/Xray-linux-${XRAY_ARCH}.zip"
    [ $? -ne 0 ] && { print_error "下载失败"; exit 1; }
    
    unzip -o xray.zip -d bin/ >/dev/null 2>&1
    rm -f xray.zip
    chmod +x bin/xray
    
    # 生成 UUID
    UUID=$("$INSTALL_DIR/bin/xray" uuid)
    print_success "UUID: $UUID"
    
    # 下载规则文件
    print_info "下载规则文件..."
    wget -q -O data/geoip.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat" 2>/dev/null
    wget -q -O data/geosite.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat" 2>/dev/null
    
    print_success "Xray 下载完成"
}

install_cert() {
    print_info "检查 SSL 证书..."
    
    # 1. 检查本地已有证书
    if [ -f "$INSTALL_DIR/cert/fullchain.crt" ] && [ -f "$INSTALL_DIR/cert/private.key" ]; then
        print_success "使用已有证书"
        return 0
    fi
    
    # 2. 检查 acme.sh ECC 证书
    if [ -f ~/.acme.sh/${DOMAIN}_ecc/fullchain.cer ] && [ -f ~/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.key ]; then
        print_info "发现 acme.sh 已有证书，直接安装..."
        mkdir -p "$INSTALL_DIR/cert"
        cp ~/.acme.sh/${DOMAIN}_ecc/fullchain.cer "$INSTALL_DIR/cert/fullchain.crt"
        cp ~/.acme.sh/${DOMAIN}_ecc/${DOMAIN}.key "$INSTALL_DIR/cert/private.key"
        
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
    
    fuser -k 80/tcp >/dev/null 2>&1
    sleep 1
    
    if [ ! -f ~/.acme.sh/acme.sh ]; then
        curl -sL https://get.acme.sh | sh -s email="$EMAIL" >/dev/null 2>&1
    fi
    
    [ ! -f ~/.acme.sh/acme.sh ] && { print_error "acme.sh 安装失败"; exit 1; }
    
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt >/dev/null 2>&1
    
    print_warning "请确保: 域名已解析到 $VPS_IP 且 CF 代理已关闭"
    
    ~/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone --keylength ec-256 --force
    
    [ $? -ne 0 ] && { print_error "证书申请失败"; exit 1; }
    
    mkdir -p "$INSTALL_DIR/cert"
    ~/.acme.sh/acme.sh --install-cert -d "$DOMAIN" --ecc \
        --key-file "$INSTALL_DIR/cert/private.key" \
        --fullchain-file "$INSTALL_DIR/cert/fullchain.crt" \
        --reloadcmd "systemctl restart $SERVICE_NAME"
    
    [ ! -f "$INSTALL_DIR/cert/fullchain.crt" ] && { print_error "证书安装失败"; exit 1; }
    
    print_success "证书申请成功"
}

init_params() {
    print_info "初始化参数..."
    
    # SOCKS5-IPv4
    SOCKS5_V4_ENABLED="true"
    SOCKS5_V4_PORT=$((RANDOM % 10000 + 15000))
    SOCKS5_V4_USER=$(head /dev/urandom | tr -dc 'a-z0-9' | head -c 10)
    SOCKS5_V4_PASS=$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 12)
    
    # SOCKS5-IPv6
    SOCKS5_V6_ENABLED="$HAS_IPV6"
    SOCKS5_V6_PORT=$((RANDOM % 10000 + 25000))
    SOCKS5_V6_USER=$(head /dev/urandom | tr -dc 'a-z0-9' | head -c 10)
    SOCKS5_V6_PASS=$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 12)
    
    # VLESS-IPv4
    VLESS_V4_ENABLED="true"
    VLESS_V4_PORT=2053
    VLESS_V4_PATH="/$(head /dev/urandom | tr -dc 'a-z0-9' | head -c 8)"
    
    # VLESS-IPv6
    VLESS_V6_ENABLED="$HAS_IPV6"
    VLESS_V6_PORT=2083
    VLESS_V6_PATH="/$(head /dev/urandom | tr -dc 'a-z0-9' | head -c 8)"
    
    # 确保 UUID 存在
    if [ -z "$UUID" ]; then
        UUID=$("$INSTALL_DIR/bin/xray" uuid)
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

    systemctl daemon-reload
    systemctl enable $SERVICE_NAME >/dev/null 2>&1
    
    print_success "服务创建完成"
}

show_result() {
    clear
    cat "$INSTALL_DIR/info.txt"
    
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    ✅ 安装完成！                              ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  管理命令: ${CYAN}xray-v6${NC}"
    echo ""
}

#===============================================================================
# 主函数
#===============================================================================

main() {
    print_banner
    check_root
    check_system
    check_network
    get_user_input
    
    echo ""
    print_info "========== 开始安装 =========="
    echo ""
    
    install_deps
    cleanup_old
    create_dirs
    download_xray
    install_cert
    init_params
    
    # 生成配置（此时所有变量都已在内存中）
    print_info "生成配置文件..."
    generate_xray_config || { print_error "配置生成失败"; exit 1; }
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
    sleep 2
    
    if systemctl is-active --quiet $SERVICE_NAME; then
        print_success "服务启动成功"
    else
        print_error "服务启动失败"
        journalctl -u $SERVICE_NAME --no-pager -n 10
    fi
    
    show_result
}

main "$@"
