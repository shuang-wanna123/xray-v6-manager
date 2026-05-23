python3 <<'PY'
from pathlib import Path
import sys

p = Path("xray-v4v6s5.sh")
if not p.exists():
    raise SystemExit("找不到 xray-v4v6s5.sh")

s = p.read_text(encoding="utf-8")

if 'SOCKS5_V4_ENABLED="' in s or 'SOCKS5_V6_ENABLED="' in s:
    raise SystemExit("脚本里已经存在 SOCKS5_V4/SOCKS5_V6，避免重复修改。")

def replace_once(old, new, label):
    global s
    if old not in s:
        raise SystemExit(f"找不到待替换片段：{label}")
    s = s.replace(old, new, 1)

def replace_all(old, new, label):
    global s
    n = s.count(old)
    if n == 0:
        raise SystemExit(f"找不到待替换片段：{label}")
    s = s.replace(old, new)

replace_once(
r'''SOCKS5_P6_ENABLED="false" SOCKS5_P6_PORT="" SOCKS5_P6_USER="" SOCKS5_P6_PASS=""
VLESS_V4_ENABLED="false" VLESS_V4_PORT="" VLESS_V4_PATH=""''',
r'''SOCKS5_P6_ENABLED="false" SOCKS5_P6_PORT="" SOCKS5_P6_USER="" SOCKS5_P6_PASS=""
SOCKS5_V4_ENABLED="false" SOCKS5_V4_PORT="" SOCKS5_V4_USER="" SOCKS5_V4_PASS=""
SOCKS5_V6_ENABLED="false" SOCKS5_V6_PORT="" SOCKS5_V6_USER="" SOCKS5_V6_PASS=""
VLESS_V4_ENABLED="false" VLESS_V4_PORT="" VLESS_V4_PATH=""''',
"新增全局 SOCKS5 v4/v6 变量"
)

replace_all(
r'''url_encode_path() { echo "$1" | sed 's/\//%2F/g'; }''',
r'''url_encode_path() { echo "$1" | sed 's/\//%2F/g'; }
format_url_host() { [[ "$1" == *:* ]] && echo "[$1]" || echo "$1"; }''',
"新增 IPv6 URL 地址格式化函数"
)

replace_all(
r'''SOCKS5_P6_ENABLED="${SOCKS5_P6_ENABLED}" SOCKS5_P6_PORT="${SOCKS5_P6_PORT}"
SOCKS5_P6_USER="${SOCKS5_P6_USER}" SOCKS5_P6_PASS="${SOCKS5_P6_PASS}"
VLESS_V4_ENABLED="${VLESS_V4_ENABLED}" VLESS_V4_PORT="${VLESS_V4_PORT}" VLESS_V4_PATH="${VLESS_V4_PATH}"''',
r'''SOCKS5_P6_ENABLED="${SOCKS5_P6_ENABLED}" SOCKS5_P6_PORT="${SOCKS5_P6_PORT}"
SOCKS5_P6_USER="${SOCKS5_P6_USER}" SOCKS5_P6_PASS="${SOCKS5_P6_PASS}"
SOCKS5_V4_ENABLED="${SOCKS5_V4_ENABLED}" SOCKS5_V4_PORT="${SOCKS5_V4_PORT}"
SOCKS5_V4_USER="${SOCKS5_V4_USER}" SOCKS5_V4_PASS="${SOCKS5_V4_PASS}"
SOCKS5_V6_ENABLED="${SOCKS5_V6_ENABLED}" SOCKS5_V6_PORT="${SOCKS5_V6_PORT}"
SOCKS5_V6_USER="${SOCKS5_V6_USER}" SOCKS5_V6_PASS="${SOCKS5_V6_PASS}"
VLESS_V4_ENABLED="${VLESS_V4_ENABLED}" VLESS_V4_PORT="${VLESS_V4_PORT}" VLESS_V4_PATH="${VLESS_V4_PATH}"''',
"保存 SOCKS5 v4/v6 参数"
)

replace_once(
r'''show_menu() {
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
}''',
r'''show_menu() {
    clear; load_params 2>/dev/null
    local enabled=0
    [ "$SOCKS5_P6_ENABLED" = "true" ] && ((enabled++))
    [ "$SOCKS5_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && ((enabled++))
    [ "$SOCKS5_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && ((enabled++))
    [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && ((enabled++))
    [ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && ((enabled++))
    [ "$VLESS_P6_ENABLED" = "true" ] && ((enabled++))
    
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗"
    echo "║            Xray 多节点代理 管理面板 v${SCRIPT_VERSION}                     ║"
    echo -e "╚═══════════════════════════════════════════════════════════════╝${NC}"
    systemctl is-active --quiet $SERVICE 2>/dev/null && echo -e "  服务: ${GREEN}● 运行中${NC}" || echo -e "  服务: ${RED}● 已停止${NC}"
    echo -e "  节点: ${YELLOW}${enabled}/6${NC}  UUID: ${YELLOW}${UUID:0:8}...${NC}  WebRTC: ${GREEN}✅${NC}"

    echo -e "\n${CYAN}─── 服务 ───${NC}"
    echo "  1. 查看信息"
    echo "  2. 启动服务"
    echo "  3. 停止服务"
    echo "  4. 重启服务"
    echo "  5. 查看状态"
    echo "  6. 查看日志"

    echo -e "\n${CYAN}─── 节点 ───${NC}"
    echo "  7. 节点状态"
    echo "  8. 节点开关"
    echo "  9. 修改节点"
    echo "  10. 新增节点"
    echo "  11. 删除节点"

    echo -e "\n${CYAN}─── 配置 ───${NC}"
    echo "  12. 修改 UUID"
    echo "  13. 修改 CDN"
    echo "  14. 编辑配置"
    echo "  15. 测试配置"
    echo "  16. 更新 Xray"
    echo -e "  ${RED}17. 卸载${NC}"
    echo "  0. 退出"
    echo ""
}''',
"主菜单竖列显示"
)

replace_once(
r'''show_node_status() {
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
}''',
r'''show_node_status() {
    clear; load_params
    echo -e "${CYAN}═══════════════════ 节点状态 ═══════════════════${NC}\n"
    local s1="❌" s2="❌" s3="❌" s4="❌" s5="❌" s6="❌"
    [ "$SOCKS5_P6_ENABLED" = "true" ] && s1="✅"
    [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && s2="✅"
    [ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && s3="✅"
    [ "$VLESS_P6_ENABLED" = "true" ] && s4="✅"
    [ "$SOCKS5_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && s5="✅"
    [ "$SOCKS5_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && s6="✅"
    echo "  1. SOCKS5-优先IPv6 [$s1] 端口:${SOCKS5_P6_PORT:-未设置}"
    echo "  2. VLESS-强制IPv4  [$s2] 端口:${VLESS_V4_PORT:-未设置} $([ "$HAS_IPV4" != "true" ] && echo "(无IPv4)")"
    echo "  3. VLESS-强制IPv6  [$s3] 端口:${VLESS_V6_PORT:-未设置} $([ "$HAS_IPV6" != "true" ] && echo "(无IPv6)")"
    echo "  4. VLESS-优先IPv6  [$s4] 端口:${VLESS_P6_PORT:-未设置}"
    echo "  5. SOCKS5-仅IPv4  [$s5] 端口:${SOCKS5_V4_PORT:-未设置} $([ "$HAS_IPV4" != "true" ] && echo "(无IPv4)")"
    echo "  6. SOCKS5-仅IPv6  [$s6] 端口:${SOCKS5_V6_PORT:-未设置} $([ "$HAS_IPV6" != "true" ] && echo "(无IPv6)")"
    echo -e "\n${YELLOW}按回车返回...${NC}"; read -r
}''',
"节点状态新增 SOCKS5 v4/v6"
)

replace_once(
r'''toggle_node() {
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
}''',
r'''toggle_node() {
    load_params; echo ""
    echo "  1. SOCKS5-优先IPv6 [$([ "$SOCKS5_P6_ENABLED" = "true" ] && echo "✅" || echo "❌")]"
    echo "  2. VLESS-强制IPv4  [$([ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && echo "✅" || echo "❌")]$([ "$HAS_IPV4" != "true" ] && echo " (无IPv4)")"
    echo "  3. VLESS-强制IPv6  [$([ "$VLESS_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && echo "✅" || echo "❌")]$([ "$HAS_IPV6" != "true" ] && echo " (无IPv6)")"
    echo "  4. VLESS-优先IPv6  [$([ "$VLESS_P6_ENABLED" = "true" ] && echo "✅" || echo "❌")]"
    echo "  5. SOCKS5-仅IPv4  [$([ "$SOCKS5_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && echo "✅" || echo "❌")]$([ "$HAS_IPV4" != "true" ] && echo " (无IPv4)")"
    echo "  6. SOCKS5-仅IPv6  [$([ "$SOCKS5_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && echo "✅" || echo "❌")]$([ "$HAS_IPV6" != "true" ] && echo " (无IPv6)")"
    echo "  0. 返回"; echo ""; echo -n "选择: "; read -r c
    case $c in
        0) return;; 1) [ "$SOCKS5_P6_ENABLED" = "true" ] && SOCKS5_P6_ENABLED="false" || SOCKS5_P6_ENABLED="true";;
        2) [ "$HAS_IPV4" != "true" ] && { echo -e "${RED}无IPv4${NC}"; sleep 2; return; }; [ "$VLESS_V4_ENABLED" = "true" ] && VLESS_V4_ENABLED="false" || VLESS_V4_ENABLED="true";;
        3) [ "$HAS_IPV6" != "true" ] && { echo -e "${RED}无IPv6${NC}"; sleep 2; return; }; [ "$VLESS_V6_ENABLED" = "true" ] && VLESS_V6_ENABLED="false" || VLESS_V6_ENABLED="true";;
        4) [ "$VLESS_P6_ENABLED" = "true" ] && VLESS_P6_ENABLED="false" || VLESS_P6_ENABLED="true";;
        5) [ "$HAS_IPV4" != "true" ] && { echo -e "${RED}无IPv4${NC}"; sleep 2; return; }
           if [ "$SOCKS5_V4_ENABLED" = "true" ]; then SOCKS5_V4_ENABLED="false"; else
               [ -z "$SOCKS5_V4_PORT" ] && SOCKS5_V4_PORT=$(get_random_port 20000 30000)
               [ -z "$SOCKS5_V4_USER" ] && SOCKS5_V4_USER=$(random_string 10)
               [ -z "$SOCKS5_V4_PASS" ] && SOCKS5_V4_PASS=$(random_password 12)
               SOCKS5_V4_ENABLED="true"
           fi;;
        6) [ "$HAS_IPV6" != "true" ] && { echo -e "${RED}无IPv6${NC}"; sleep 2; return; }
           if [ "$SOCKS5_V6_ENABLED" = "true" ]; then SOCKS5_V6_ENABLED="false"; else
               [ -z "$SOCKS5_V6_PORT" ] && SOCKS5_V6_PORT=$(get_random_port 20000 30000)
               [ -z "$SOCKS5_V6_USER" ] && SOCKS5_V6_USER=$(random_string 10)
               [ -z "$SOCKS5_V6_PASS" ] && SOCKS5_V6_PASS=$(random_password 12)
               SOCKS5_V6_ENABLED="true"
           fi;;
        *) echo -e "${RED}无效${NC}"; sleep 1; return;;
    esac
    save_params; regenerate_all && { echo -n -e "${YELLOW}重启？(y/n): ${NC}"; read -r r; [ "$r" = "y" ] && restart_service; }; sleep 2
}''',
"节点开关新增 SOCKS5 v4/v6"
)

replace_once(
r'''modify_node() {
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
}''',
r'''modify_node() {
    load_params; echo ""
    echo "  1. SOCKS5-优先IPv6 端口:${SOCKS5_P6_PORT}"
    echo "  2. VLESS-v4       端口:${VLESS_V4_PORT} 路径:${VLESS_V4_PATH}"
    echo "  3. VLESS-v6       端口:${VLESS_V6_PORT} 路径:${VLESS_V6_PATH}"
    echo "  4. VLESS-p6       端口:${VLESS_P6_PORT} 路径:${VLESS_P6_PATH}"
    echo "  5. SOCKS5-仅IPv4  端口:${SOCKS5_V4_PORT}"
    echo "  6. SOCKS5-仅IPv6  端口:${SOCKS5_V6_PORT}"
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
        5) echo -n "端口($SOCKS5_V4_PORT): "; read -r p; [ -n "$p" ] && SOCKS5_V4_PORT="$p"
           echo -n "用户名($SOCKS5_V4_USER): "; read -r u; [ -n "$u" ] && SOCKS5_V4_USER="$u"
           echo -n "密码($SOCKS5_V4_PASS): "; read -r w; [ -n "$w" ] && SOCKS5_V4_PASS="$w";;
        6) echo -n "端口($SOCKS5_V6_PORT): "; read -r p; [ -n "$p" ] && SOCKS5_V6_PORT="$p"
           echo -n "用户名($SOCKS5_V6_USER): "; read -r u; [ -n "$u" ] && SOCKS5_V6_USER="$u"
           echo -n "密码($SOCKS5_V6_PASS): "; read -r w; [ -n "$w" ] && SOCKS5_V6_PASS="$w";;
        *) echo -e "${RED}无效${NC}"; sleep 1; return;;
    esac
    save_params; regenerate_all && { echo -n -e "${YELLOW}重启？(y/n): ${NC}"; read -r r; [ "$r" = "y" ] && restart_service; }; sleep 2
}''',
"修改节点菜单竖列并新增 SOCKS5 v4/v6"
)

replace_once(
r'''add_node() {
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
}''',
r'''add_node() {
    load_params; echo -e "\n${CYAN}═══ 新增节点 ═══${NC}"
    echo "  1. SOCKS5-优先IPv6 $([ "$SOCKS5_P6_ENABLED" = "true" ] && echo "(已启用)")"
    echo "  2. VLESS-v4 $([ "$VLESS_V4_ENABLED" = "true" ] && echo "(已启用)")$([ "$HAS_IPV4" != "true" ] && echo " [无IPv4]")"
    echo "  3. VLESS-v6 $([ "$VLESS_V6_ENABLED" = "true" ] && echo "(已启用)")$([ "$HAS_IPV6" != "true" ] && echo " [无IPv6]")"
    echo "  4. VLESS-p6 $([ "$VLESS_P6_ENABLED" = "true" ] && echo "(已启用)")"
    echo "  5. SOCKS5-仅IPv4 $([ "$SOCKS5_V4_ENABLED" = "true" ] && echo "(已启用)")$([ "$HAS_IPV4" != "true" ] && echo " [无IPv4]")"
    echo "  6. SOCKS5-仅IPv6 $([ "$SOCKS5_V6_ENABLED" = "true" ] && echo "(已启用)")$([ "$HAS_IPV6" != "true" ] && echo " [无IPv6]")"
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
        5) [ "$HAS_IPV4" != "true" ] && { echo -e "${RED}无IPv4${NC}"; sleep 2; return; }
           [ "$SOCKS5_V4_ENABLED" = "true" ] && { echo -e "${YELLOW}已启用${NC}"; sleep 2; return; }
           echo -n "端口(随机): "; read -r p; [ -z "$p" ] && p=$(get_random_port 20000 30000); SOCKS5_V4_PORT="$p"
           echo -n "用户名(随机): "; read -r u; [ -z "$u" ] && u=$(random_string 10); SOCKS5_V4_USER="$u"
           echo -n "密码(随机): "; read -r w; [ -z "$w" ] && w=$(random_password 12); SOCKS5_V4_PASS="$w"; SOCKS5_V4_ENABLED="true";;
        6) [ "$HAS_IPV6" != "true" ] && { echo -e "${RED}无IPv6${NC}"; sleep 2; return; }
           [ "$SOCKS5_V6_ENABLED" = "true" ] && { echo -e "${YELLOW}已启用${NC}"; sleep 2; return; }
           echo -n "端口(随机): "; read -r p; [ -z "$p" ] && p=$(get_random_port 20000 30000); SOCKS5_V6_PORT="$p"
           echo -n "用户名(随机): "; read -r u; [ -z "$u" ] && u=$(random_string 10); SOCKS5_V6_USER="$u"
           echo -n "密码(随机): "; read -r w; [ -z "$w" ] && w=$(random_password 12); SOCKS5_V6_PASS="$w"; SOCKS5_V6_ENABLED="true";;
        *) echo -e "${RED}无效${NC}"; sleep 1; return;;
    esac
    save_params; echo -e "${GREEN}已添加${NC}"; regenerate_all && { echo -n -e "${YELLOW}重启？(y/n): ${NC}"; read -r r; [ "$r" = "y" ] && restart_service; }; sleep 2
}''',
"新增节点菜单加入 SOCKS5 v4/v6"
)

replace_once(
r'''delete_node() {
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
}''',
r'''delete_node() {
    load_params; echo -e "\n${CYAN}═══ 删除节点 ═══${NC}"
    echo "  1. SOCKS5-优先IPv6 [$([ "$SOCKS5_P6_ENABLED" = "true" ] && echo "✅" || echo "❌")]"
    echo "  2. VLESS-v4 [$([ "$VLESS_V4_ENABLED" = "true" ] && echo "✅" || echo "❌")]"
    echo "  3. VLESS-v6 [$([ "$VLESS_V6_ENABLED" = "true" ] && echo "✅" || echo "❌")]"
    echo "  4. VLESS-p6 [$([ "$VLESS_P6_ENABLED" = "true" ] && echo "✅" || echo "❌")]"
    echo "  5. SOCKS5-仅IPv4 [$([ "$SOCKS5_V4_ENABLED" = "true" ] && echo "✅" || echo "❌")]"
    echo "  6. SOCKS5-仅IPv6 [$([ "$SOCKS5_V6_ENABLED" = "true" ] && echo "✅" || echo "❌")]"
    echo "  0. 返回"; echo -n "选择删除: "; read -r c
    case $c in
        0) return;; 1) SOCKS5_P6_ENABLED="false"; SOCKS5_P6_PORT=""; SOCKS5_P6_USER=""; SOCKS5_P6_PASS="";;
        2) VLESS_V4_ENABLED="false"; VLESS_V4_PORT=""; VLESS_V4_PATH="";;
        3) VLESS_V6_ENABLED="false"; VLESS_V6_PORT=""; VLESS_V6_PATH="";;
        4) VLESS_P6_ENABLED="false"; VLESS_P6_PORT=""; VLESS_P6_PATH="";;
        5) SOCKS5_V4_ENABLED="false"; SOCKS5_V4_PORT=""; SOCKS5_V4_USER=""; SOCKS5_V4_PASS="";;
        6) SOCKS5_V6_ENABLED="false"; SOCKS5_V6_PORT=""; SOCKS5_V6_USER=""; SOCKS5_V6_PASS="";;
        *) echo -e "${RED}无效${NC}"; sleep 1; return;;
    esac
    save_params; echo -e "${GREEN}已删除${NC}"; regenerate_all && { echo -n -e "${YELLOW}重启？(y/n): ${NC}"; read -r r; [ "$r" = "y" ] && restart_service; }; sleep 2
}''',
"删除节点菜单加入 SOCKS5 v4/v6"
)

replace_once(
r'''    [ "$SOCKS5_P6_ENABLED" = "true" ] && ((enabled_count++))
    [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && ((enabled_count++))''',
r'''    [ "$SOCKS5_P6_ENABLED" = "true" ] && ((enabled_count++))
    [ "$SOCKS5_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && ((enabled_count++))
    [ "$SOCKS5_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && ((enabled_count++))
    [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && ((enabled_count++))''',
"主配置启用节点计数"
)

replace_all(
r'''    [ "$SOCKS5_P6_ENABLED" = "true" ] && ((enabled++))
    [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && ((enabled++))''',
r'''    [ "$SOCKS5_P6_ENABLED" = "true" ] && ((enabled++))
    [ "$SOCKS5_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && ((enabled++))
    [ "$SOCKS5_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && ((enabled++))
    [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && ((enabled++))''',
"信息和管理脚本启用节点计数"
)

replace_once(
r'''    if [ "$SOCKS5_P6_ENABLED" = "true" ]; then
        [ "$first_inbound" = "false" ] && inbounds+=","
        inbounds+='{"tag":"socks-p6-in","listen":"::","port":'"$SOCKS5_P6_PORT"',"protocol":"socks","settings":{"auth":"password","accounts":[{"user":"'"$SOCKS5_P6_USER"'","pass":"'"$SOCKS5_P6_PASS"'"}],"udp":true}}'
        first_inbound=false
    fi
    
    if [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ]; then''',
r'''    if [ "$SOCKS5_P6_ENABLED" = "true" ]; then
        [ "$first_inbound" = "false" ] && inbounds+=","
        inbounds+='{"tag":"socks-p6-in","listen":"::","port":'"$SOCKS5_P6_PORT"',"protocol":"socks","settings":{"auth":"password","accounts":[{"user":"'"$SOCKS5_P6_USER"'","pass":"'"$SOCKS5_P6_PASS"'"}],"udp":true}}'
        first_inbound=false
    fi
    
    if [ "$SOCKS5_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ]; then
        [ "$first_inbound" = "false" ] && inbounds+=","
        inbounds+='{"tag":"socks-v4-in","listen":"::","port":'"$SOCKS5_V4_PORT"',"protocol":"socks","settings":{"auth":"password","accounts":[{"user":"'"$SOCKS5_V4_USER"'","pass":"'"$SOCKS5_V4_PASS"'"}],"udp":true}}'
        first_inbound=false
    fi
    
    if [ "$SOCKS5_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ]; then
        [ "$first_inbound" = "false" ] && inbounds+=","
        inbounds+='{"tag":"socks-v6-in","listen":"::","port":'"$SOCKS5_V6_PORT"',"protocol":"socks","settings":{"auth":"password","accounts":[{"user":"'"$SOCKS5_V6_USER"'","pass":"'"$SOCKS5_V6_PASS"'"}],"udp":true}}'
        first_inbound=false
    fi
    
    if [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ]; then''',
"主配置新增 SOCKS5 v4/v6 inbound"
)

replace_once(
r'''    [ "$SOCKS5_P6_ENABLED" = "true" ] && { [ "$first" = "false" ] && inbounds+=","; inbounds+='{"tag":"socks-p6-in","listen":"::","port":'$SOCKS5_P6_PORT',"protocol":"socks","settings":{"auth":"password","accounts":[{"user":"'$SOCKS5_P6_USER'","pass":"'$SOCKS5_P6_PASS'"}],"udp":true}}'; first=false; }
    [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && { [ "$first" = "false" ] && inbounds+=","; inbounds+='{"tag":"vless-v4-in","listen":"::","port":'$VLESS_V4_PORT',"protocol":"vless","settings":{"clients":[{"id":"'$UUID'"}],"decryption":"none"},"streamSettings":{"network":"ws","security":"tls","tlsSettings":{"certificates":[{"certificateFile":"'$DIR'/cert/fullchain.crt","keyFile":"'$DIR'/cert/private.key"}]},"wsSettings":{"path":"'$VLESS_V4_PATH'"}}}'; first=false; }''',
r'''    [ "$SOCKS5_P6_ENABLED" = "true" ] && { [ "$first" = "false" ] && inbounds+=","; inbounds+='{"tag":"socks-p6-in","listen":"::","port":'$SOCKS5_P6_PORT',"protocol":"socks","settings":{"auth":"password","accounts":[{"user":"'$SOCKS5_P6_USER'","pass":"'$SOCKS5_P6_PASS'"}],"udp":true}}'; first=false; }
    [ "$SOCKS5_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && { [ "$first" = "false" ] && inbounds+=","; inbounds+='{"tag":"socks-v4-in","listen":"::","port":'$SOCKS5_V4_PORT',"protocol":"socks","settings":{"auth":"password","accounts":[{"user":"'$SOCKS5_V4_USER'","pass":"'$SOCKS5_V4_PASS'"}],"udp":true}}'; first=false; }
    [ "$SOCKS5_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && { [ "$first" = "false" ] && inbounds+=","; inbounds+='{"tag":"socks-v6-in","listen":"::","port":'$SOCKS5_V6_PORT',"protocol":"socks","settings":{"auth":"password","accounts":[{"user":"'$SOCKS5_V6_USER'","pass":"'$SOCKS5_V6_PASS'"}],"udp":true}}'; first=false; }
    [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && { [ "$first" = "false" ] && inbounds+=","; inbounds+='{"tag":"vless-v4-in","listen":"::","port":'$VLESS_V4_PORT',"protocol":"vless","settings":{"clients":[{"id":"'$UUID'"}],"decryption":"none"},"streamSettings":{"network":"ws","security":"tls","tlsSettings":{"certificates":[{"certificateFile":"'$DIR'/cert/fullchain.crt","keyFile":"'$DIR'/cert/private.key"}]},"wsSettings":{"path":"'$VLESS_V4_PATH'"}}}'; first=false; }''',
"管理脚本新增 SOCKS5 v4/v6 inbound"
)

replace_all(
r'''    [ "$SOCKS5_P6_ENABLED" = "true" ] && rules+=',{"type":"field","inboundTag":["socks-p6-in"],"outboundTag":"IPv6v4-out"}'
    [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && rules+=',{"type":"field","inboundTag":["vless-v4-in"],"outboundTag":"IPv4-out"}' ''',
r'''    [ "$SOCKS5_P6_ENABLED" = "true" ] && rules+=',{"type":"field","inboundTag":["socks-p6-in"],"outboundTag":"IPv6v4-out"}'
    [ "$SOCKS5_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && rules+=',{"type":"field","inboundTag":["socks-v4-in"],"outboundTag":"IPv4-out"}'
    [ "$SOCKS5_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && rules+=',{"type":"field","inboundTag":["socks-v6-in"],"outboundTag":"IPv6-out"}'
    [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && rules+=',{"type":"field","inboundTag":["vless-v4-in"],"outboundTag":"IPv4-out"}' ''',
"新增 SOCKS5 v4/v6 路由规则"
)

replace_once(
r'''        echo "  优选地址: $CDN_HOST  |  启用节点: ${enabled}/4  |  WebRTC拦截: ✅"''',
r'''        echo "  优选地址: $CDN_HOST  |  启用节点: ${enabled}/6  |  WebRTC拦截: ✅"''',
"安装信息节点总数改为 6"
)

replace_once(
r'''        if [ "$SOCKS5_P6_ENABLED" = "true" ]; then
            local cip="${VPS_IP:-$IPV6_ADDR}"
            echo -e "\n  节点 ${node_num}: SOCKS5（端口 ${SOCKS5_P6_PORT}）出站: 优先IPv6"
            echo "  socks5://${SOCKS5_P6_USER}:${SOCKS5_P6_PASS}@${cip}:${SOCKS5_P6_PORT}#SOCKS5-${node_num}"
            ((node_num++))
        fi''',
r'''        if [ "$SOCKS5_P6_ENABLED" = "true" ]; then
            local cip; cip=$(format_url_host "${VPS_IP:-$IPV6_ADDR}")
            echo -e "\n  节点 ${node_num}: SOCKS5（端口 ${SOCKS5_P6_PORT}）出站: 优先IPv6"
            echo "  socks5://${SOCKS5_P6_USER}:${SOCKS5_P6_PASS}@${cip}:${SOCKS5_P6_PORT}#SOCKS5-${node_num}"
            ((node_num++))
        fi''',
"安装信息 SOCKS5 地址支持 IPv6 方括号"
)

replace_once(
r'''        if [ "$VLESS_P6_ENABLED" = "true" ]; then
            echo -e "\n  节点 ${node_num}: VLESS-优先IPv6（端口 ${VLESS_P6_PORT}）出站: 优先IPv6"
            echo "  vless://${UUID}@${CDN_HOST}:${VLESS_P6_PORT}?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=${ep_p6}#IPv4%26IPv6-CDN-${node_num}"
            ((node_num++))
        fi
        
        echo -e "\n═══════════════════════════════════════════════════════════════════════════════"''',
r'''        if [ "$VLESS_P6_ENABLED" = "true" ]; then
            echo -e "\n  节点 ${node_num}: VLESS-优先IPv6（端口 ${VLESS_P6_PORT}）出站: 优先IPv6"
            echo "  vless://${UUID}@${CDN_HOST}:${VLESS_P6_PORT}?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=${ep_p6}#IPv4%26IPv6-CDN-${node_num}"
            ((node_num++))
        fi
        
        if [ "$SOCKS5_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ]; then
            local cip; cip=$(format_url_host "$VPS_IP")
            echo -e "\n  节点 ${node_num}: SOCKS5-仅IPv4（端口 ${SOCKS5_V4_PORT}）出站: 强制IPv4 → ${VPS_IP}"
            echo "  socks5://${SOCKS5_V4_USER}:${SOCKS5_V4_PASS}@${cip}:${SOCKS5_V4_PORT}#SOCKS5-IPv4-${node_num}"
            ((node_num++))
        fi
        
        if [ "$SOCKS5_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ]; then
            local cip; cip=$(format_url_host "${VPS_IP:-$IPV6_ADDR}")
            echo -e "\n  节点 ${node_num}: SOCKS5-仅IPv6（端口 ${SOCKS5_V6_PORT}）出站: 强制IPv6 → ${IPV6_ADDR}"
            echo "  socks5://${SOCKS5_V6_USER}:${SOCKS5_V6_PASS}@${cip}:${SOCKS5_V6_PORT}#SOCKS5-IPv6-${node_num}"
            ((node_num++))
        fi
        
        echo -e "\n═══════════════════════════════════════════════════════════════════════════════"''',
"安装信息输出 SOCKS5 v4/v6 节点"
)

replace_once(
r'''        [ "$SOCKS5_P6_ENABLED" = "true" ] && echo "    ufw allow $SOCKS5_P6_PORT/tcp"
        [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && echo "    ufw allow $VLESS_V4_PORT/tcp"''',
r'''        [ "$SOCKS5_P6_ENABLED" = "true" ] && echo "    ufw allow $SOCKS5_P6_PORT/tcp"
        [ "$SOCKS5_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && echo "    ufw allow $SOCKS5_V4_PORT/tcp"
        [ "$SOCKS5_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && echo "    ufw allow $SOCKS5_V6_PORT/tcp"
        [ "$VLESS_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && echo "    ufw allow $VLESS_V4_PORT/tcp"''',
"防火墙提示加入 SOCKS5 v4/v6"
)

replace_once(
r'''        [ "$SOCKS5_P6_ENABLED" = "true" ] && { local cip="${VPS_IP:-$IPV6_ADDR}"; echo -e "\n  节点 ${node_num}: SOCKS5（端口 ${SOCKS5_P6_PORT}）"; echo "  socks5://${SOCKS5_P6_USER}:${SOCKS5_P6_PASS}@${cip}:${SOCKS5_P6_PORT}#SOCKS5-${node_num}"; ((node_num++)); }''',
r'''        [ "$SOCKS5_P6_ENABLED" = "true" ] && { local cip; cip=$(format_url_host "${VPS_IP:-$IPV6_ADDR}"); echo -e "\n  节点 ${node_num}: SOCKS5（端口 ${SOCKS5_P6_PORT}）"; echo "  socks5://${SOCKS5_P6_USER}:${SOCKS5_P6_PASS}@${cip}:${SOCKS5_P6_PORT}#SOCKS5-${node_num}"; ((node_num++)); }''',
"管理脚本信息 SOCKS5 地址支持 IPv6 方括号"
)

replace_once(
r'''        [ "$VLESS_P6_ENABLED" = "true" ] && { echo -e "\n  节点 ${node_num}: VLESS-优先IPv6（端口 ${VLESS_P6_PORT}）"; echo "  vless://${UUID}@${CDN_HOST}:${VLESS_P6_PORT}?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=${ep_p6}#IPv4%26IPv6-CDN-${node_num}"; ((node_num++)); }
        echo ""''',
r'''        [ "$VLESS_P6_ENABLED" = "true" ] && { echo -e "\n  节点 ${node_num}: VLESS-优先IPv6（端口 ${VLESS_P6_PORT}）"; echo "  vless://${UUID}@${CDN_HOST}:${VLESS_P6_PORT}?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=${ep_p6}#IPv4%26IPv6-CDN-${node_num}"; ((node_num++)); }
        [ "$SOCKS5_V4_ENABLED" = "true" ] && [ "$HAS_IPV4" = "true" ] && { local cip; cip=$(format_url_host "$VPS_IP"); echo -e "\n  节点 ${node_num}: SOCKS5-仅IPv4（端口 ${SOCKS5_V4_PORT}）出站: 强制IPv4 → ${VPS_IP}"; echo "  socks5://${SOCKS5_V4_USER}:${SOCKS5_V4_PASS}@${cip}:${SOCKS5_V4_PORT}#SOCKS5-IPv4-${node_num}"; ((node_num++)); }
        [ "$SOCKS5_V6_ENABLED" = "true" ] && [ "$HAS_IPV6" = "true" ] && { local cip; cip=$(format_url_host "${VPS_IP:-$IPV6_ADDR}"); echo -e "\n  节点 ${node_num}: SOCKS5-仅IPv6（端口 ${SOCKS5_V6_PORT}）出站: 强制IPv6 → ${IPV6_ADDR}"; echo "  socks5://${SOCKS5_V6_USER}:${SOCKS5_V6_PASS}@${cip}:${SOCKS5_V6_PORT}#SOCKS5-IPv6-${node_num}"; ((node_num++)); }
        echo ""''',
"管理脚本信息输出 SOCKS5 v4/v6 节点"
)

bak = p.with_name(p.name + ".bak")
bak.write_text(s if False else p.read_text(encoding="utf-8"), encoding="utf-8")
p.write_text(s, encoding="utf-8")
print(f"修改完成，已备份：{bak}")
PY
