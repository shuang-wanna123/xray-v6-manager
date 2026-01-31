
# Xray-V6-Manager

一键安装 Xray 多协议代理服务，支持 IPv4/IPv6 双栈入站，强制指定 IP 协议出站。

[![GitHub release](https://img.shields.io/github/v/release/shuang-wanna123/xray-v6-manager)](https://github.com/shuang-wanna123/xray-v6-manager/releases)
[![License](https://img.shields.io/github/license/shuang-wanna123/xray-v6-manager)](LICENSE)

## ✨ 功能特性

- 🚀 **四合一代理**：同时部署 SOCKS5 和 VLESS 协议
- 🌐 **双栈入站**：所有节点同时支持 IPv4/IPv6 客户端接入
- 🎯 **强制出站**：精确控制每个节点的出站 IP 协议（IPv4 或 IPv6）
- ☁️ **CF CDN 支持**：VLESS 节点支持 Cloudflare CDN 中转
- 🔧 **交互式管理**：运行 `xray-v6` 进入可视化管理面板
- 📝 **动态配置**：在线修改 UUID、端口、启用/禁用节点
- 🔄 **证书复用**：自动检测并复用已有 SSL 证书
- 📦 **一键更新**：内置 Xray 内核更新功能

## 📋 节点列表

| 节点 | 协议 | 端口 | 入站 | 出站 |
|------|------|------|------|------|
| 节点1 | SOCKS5 | 随机 | IPv4/IPv6 双栈 | 强制 IPv4 |
| 节点2 | SOCKS5 | 随机 | IPv4/IPv6 双栈 | 强制 IPv6 |
| 节点3 | VLESS+WS+TLS | 2053 | IPv4/IPv6 双栈 | 强制 IPv4 |
| 节点4 | VLESS+WS+TLS | 2083 | IPv4/IPv6 双栈 | 强制 IPv6 |

## 🔧 环境要求

- 系统：Debian 9+ / Ubuntu 18.04+ / CentOS 7+
- 权限：root
- 网络：IPv4 必需，IPv6 可选
- 域名：需托管到 Cloudflare 并解析到 VPS

## 📥 一键安装

```bash
bash <(curl -sL https://raw.githubusercontent.com/shuang-wanna123/xray-v6-manager/main/xray-v4v6s5.sh)
```

或

```bash
wget -O install.sh https://raw.githubusercontent.com/shuang-wanna123/xray-v6-manager/main/install.sh && bash xray-v4v6s5.sh
```

## 🎛️ 管理命令

安装完成后，使用 `xray-v6` 命令进入管理面板：

```bash
xray-v6
```


## ☁️ Cloudflare 设置

使用 CF CDN 时需要以下设置：

1. **DNS 代理**：开启（橙色云朵）
2. **SSL/TLS 模式**：完全（严格）
3. **网络 → WebSockets**：开启

## 📁 文件结构

```
/root/xray/
├── bin/
│   └── xray              # Xray 主程序
├── config/
│   └── config.json       # 运行配置
├── cert/
│   ├── fullchain.crt     # SSL 证书
│   └── private.key       # SSL 私钥
├── log/
│   ├── access.log        # 访问日志
│   └── error.log         # 错误日志
├── data/
│   ├── geoip.dat         # IP 规则库
│   └── geosite.dat       # 域名规则库
├── params.conf           # 节点参数配置
├── info.txt              # 节点信息
└── manage.sh             # 管理脚本
```

## 🔥 防火墙设置

```bash
# UFW
ufw allow 2053/tcp
ufw allow 2083/tcp
ufw allow <SOCKS5端口>/tcp

# Firewalld
firewall-cmd --add-port=2053/tcp --permanent
firewall-cmd --add-port=2083/tcp --permanent
firewall-cmd --reload
```

## ❓ 常见问题

<details>
<summary><b>Q: 为什么需要强制 IPv6 出站？</b></summary>

某些流媒体（如 Netflix、YouTube）会根据 IP 地址判断地区。部分 VPS 的 IPv6 地址可能解锁更多内容。

</details>

<details>
<summary><b>Q: 没有 IPv6 能用吗？</b></summary>

可以，IPv6 相关节点会自动禁用，IPv4 节点正常使用。

</details>

<details>
<summary><b>Q: 证书申请失败怎么办？</b></summary>

1. 确保域名已正确解析到 VPS IP
2. 确保 Cloudflare 代理已关闭（灰色云朵）
3. 确保 80 端口未被占用

</details>

<details>
<summary><b>Q: 如何更换优选 IP？</b></summary>

VLESS 链接中的 `visa.com` 可以替换为任意 Cloudflare 优选 IP 或域名：
- `time.cloudflare.com`
- `icook.hk`
- 或自行测速获取的优选 IP

</details>

## 📄 许可证

[MIT License](LICENSE)

## 🙏 致谢

- [Xray-core](https://github.com/XTLS/Xray-core)
- [acme.sh](https://github.com/acmesh-official/acme.sh)
- [Loyalsoldier/v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat)

## ⭐ Star History

如果这个项目对你有帮助，请给个 Star ⭐


**免责声明**：本项目仅供学习交流使用，请遵守当地法律法规。
