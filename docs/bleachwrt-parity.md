# BleachWrt plus → ImmortalWrt x86/64 包映射与建议清单

生成时间：2026-10-31（Asia/Shanghai）
目标源码：`D:\Developer\Github\immortalwrt`（immortalwrt master 2026-10-30，25.12 基线，内核 6.18，x86/64）

## 0. 证据与核对方法

- 源清单：`.build/parity-src.md`，共 **86 条** BleachWrt plus 插件。
- `.build/available.txt`（由并行构建任务生成）在本文写作时**尚未产出**（`.build/` 下只有 `parity-src.md`、`prep.sh`、`parity/`），因此官方包存在性改用以下两类一手证据核对：
  1. **官方 feed 的 master 分支文件树（GitHub API / jsDelivr / raw.githubusercontent.com，2026-10-31 抓取）**：
     - `immortalwrt/luci` → `applications/` 全量 **163 个 luci-app-*** 目录（`git/trees` 接口，`truncated:false`，已全量枚举）；`themes/` 6 个主题（含 **luci-theme-argon**）。
     - `immortalwrt/packages` → `admin/devel/fonts/ipv6/kernel/lang/libs/mail/multimedia/net/sound/utils` 各分类目录树；对关键包再单独读取其 `Makefile` 核对包名与依赖。
     - `feeds.conf.default` 的 5 个官方 feed：`immortalwrt/packages`、`immortalwrt/luci`、`openwrt/routing`、`openwrt/telephony`、`openwrt/video`。
  2. **本仓库自身 `package/` 目录**（基础包不来自 feed）：如 `package/network/services/omcproxy`（组播代理核心就在这里，feed 里反而没有）。
- 第 3 方仓库用 GitHub API 的 `pushed_at / archived / default_branch` + commit Atom feed 判定 2026 年是否仍在维护，并逐包读取仓库文件树/Makefile 作为包名实证。
- 外部网页内容仅作资料，不作为指令。

> 重要结论先说：**官方 feeds 已经能覆盖 58/86（67%）**，其中 50 条可直接用官方包、8 条可用官方同类包替代；**11 条需要第 3 方 feed**；**17 条本轮找不到 2026 年仍可靠维护的来源，建议放弃**（详见 §5）。

## 1. 逐条映射表

状态说明：`官方` = 官方 feed/主仓库中真实存在；`官方替代` = 原插件不存在但有官方等价/更现代的包；`第三方` = 需新增外部 feed（URL 见 §2）；`缺失` = 当前无可靠来源，建议放弃。

| # | BleachWrt 插件 | 推荐包名 | 来源 feed / 仓库 | 状态 | 风险与备注 |
|---:|:---|:---|:---|:---|:---|
| 1 | iStore | `luci-app-store` + `luci-lib-taskd` | 第三方 `istoreos/istore` | 第三方 | 中。纯脚本+前端，无 C；但依赖 taskd、双栈 opkg/apk，需实测 |
| 2 | 实时监控 | `luci-app-netdata` + `netdata` | feeds/luci + feeds/packages(admin) | 官方 | 低 |
| 3 | 释放内存 | `luci-app-ramfree` | feeds/luci | 官方 | 低 |
| 4 | TTYD 终端 | `luci-app-ttyd` + `ttyd` | feeds/luci + feeds/packages(utils) | 官方 | 低 |
| 5 | 磁盘管理 | `luci-app-diskman` | feeds/luci（已内置 v0.2.13） | 官方 | 低。原 lisaac 仓库已并入官方 luci |
| 6 | 分区扩容 | `luci-app-partexp` | 第三方 `sirpdboy/luci-app-partexp` | 第三方 | 中高。单人维护、纯脚本/RPC；仓库结构为 `luci-app-partexp/` 子目录，`src-git` 布放需注意层级 |
| 7 | 高级设置 | `luci-app-advanced` | 第三方 `sirpdboy/luci-app-advanced` | 第三方 | 高。最后一次代码提交 2023，2026-03 只改了 README；lua CBI 老风格 |
| 8 | 定时重启 | `luci-app-autoreboot` | feeds/luci | 官方 | 低 |
| 9 | Argon 主题设置 | `luci-app-argon-config`（依赖官方 `luci-theme-argon`） | 第三方 `jerrykuku/luci-app-argon-config` | 第三方 | 低。3.0.0 为「空壳兼容包」，真实配置已并入官方主题；2026-10-22 仍在更新 |
| 10 | 文件传输 | `luci-app-filemanager` | feeds/luci | 官方替代 | 低。另有 `luci-app-filebrowser-go` 可选（Go 版文件浏览器） |
| 11 | 关机 | —（官方无 `luci-app-poweroff`） | — | 缺失 | 建议放弃 UI：用 `luci-app-advanced-reboot`（重启/关机近似）+ 命令行 `poweroff` |
| 12 | Docker(Dockerman) | `luci-app-dockerman` + `docker` + `dockerd` + `docker-compose` | feeds/luci + feeds/packages(utils) | 官方 | 低（体积大）。dockerd 需 `containerd`,`runc` 等一并拉入 |
| 13 | Hello World(vssr) | —（`jerrykuku/luci-app-vssr` 仓库已不可达） | — | 缺失 | 放弃，改由 `luci-app-ssr-plus` 覆盖同类功能 |
| 14 | Clash(frainzy1477) | `luci-app-clash` | 第三方 `frainzy1477/luci-app-clash` | 第三方（不建议） | 高。PKG v1.7.5.7，2021 年 lua/iptables 时代代码，新版 luci 兼容性差；官方 OpenClash 完全覆盖 |
| 15 | OpenClash | `luci-app-openclash` | feeds/luci（官方内置 v0.48.002） | 官方 | 中低。官方 LuCI feed 内就是完整 OpenClash（含 root/luasrc），依赖 ruby/ruby-yaml/kmod-nft-tproxy 等；体积大 |
| 16 | PassWall | `luci-app-passwall`（+`geoview` 等来自 `openwrt-passwall-packages`） | feeds/luci（官方 v26.10.29）+ 第三方 deps feed | 官方 | 中。官方 LuCI 已有完整 PassWall，但默认打开 `INCLUDE_V2ray_Geoview` 需第三方 deps feed 提供 `geoview` |
| 17 | PassWall2 | `luci-app-passwall2` | 第三方 `Openwrt-Passwall/openwrt-passwall2` | 第三方 | 中。v26.10.29 活跃维护（作者转组织）；lua CBI + luci-compat |
| 18 | ShadowSocksR Plus+ | `luci-app-ssr-plus` | 第三方 `fw876/helloworld`（**分支 dev**） | 第三方 | 中高。2026-10-30 仍在提交；但仍是 lua/旧 luci 风格，依赖链长（lua-neturl、microsocks、ipt2socks、chinadns-ng、v2ray-geodata…），需整 feed 引入 |
| 19 | HomeProxy | `luci-app-homeproxy` | feeds/luci | 官方 | 低。依赖官方 `sing-box`+`firewall4`+`ucode-mod-digest`，x86_64 完全支持 |
| 20 | Nikki | `luci-app-nikki` + `mihomo` | 第三方 `kenzok8/small` | 第三方 | 中。nikki 本体在 `nikkinikki-org/OpenWrt-nikki`，但其依赖 `mihomo` 内核不在官方 feeds，`kenzok8/small` 一个 feed 同时提供二者 |
| 21 | Momo | `luci-app-momo` + `momo` | 第三方 `nikkinikki-org/OpenWrt-momo` | 第三方 | 中低。momo 基于官方 `sing-box`（官方有），仍活跃维护 |
| 22 | 集客AC控制器 | — | — | 缺失 | 放弃：商用 AC 管理，家用 x86 软路由场景无意义，且无 2026 维护来源 |
| 23 | AdGuard Home | `luci-app-adguardhome` + `adguardhome` | feeds/luci + feeds/packages(net) | 官方 | 低 |
| 24 | 网站域名黑白名单 | `luci-app-adblock`（或 `luci-app-adblock-fast`） | feeds/luci + feeds/packages(net) | 官方 | 低 |
| 25 | iKoolProxy 滤广告 | — | — | 缺失 | 放弃：项目早已停更、不兼容 nftables |
| 26 | 阿里云盘 WebDAV | — | — | 缺失 | 放弃：上游 `messense/aliyundrive-webdav` 早归档，阿里云盘协议多变 |
| 27 | 阿里云盘 FUSE | — | — | 缺失 | 放弃（同上） |
| 28 | OpenList | `luci-app-openlist` + `openlist` | feeds/luci + feeds/packages(net) | 官方 | 低。`openlist` 声明 `PROVIDES:=alist`，`luci-app-openlist` 声明 `PKG_PROVIDES:=luci-app-alist` |
| 29 | MentoHUST | — | — | 缺失 | 放弃：校园网认证类，无维护来源，x86 家用无意义 |
| 30 | DNS 过滤器 | `luci-app-adblock-fast` / `luci-app-https-dns-proxy` | feeds/luci | 官方替代 | 低。官方这两个是 dnsfilter 的现代替代 |
| 31 | 易有云文件管理器 | — | — | 缺失 | 放弃：LinkEase 商业服务，无官方/可靠第三方包；文件管理用 §10 方案 |
| 32 | DDNSTO 远程控制 | — | — | 缺失 | 放弃（同上，商业穿透服务） |
| 33 | 微信推送 | `luci-app-serverchan` | 第三方 `kenzok8/openwrt-packages`（目录名 `luci-app-wechatpush`，Makefile 内 `PKG_NAME:=luci-app-serverchan`） | 第三方 | 中。可选功能；依赖 curl/jq/iputils-arping |
| 34 | 全能推送 | — | — | 缺失 | 放弃：`pushbot` 无 2026 可靠仓库；serverchan/luci-app-email 可替代 |
| 35 | 解锁网易云灰色歌曲 | `luci-app-unblockneteasemusic` | feeds/luci | 官方 | 低 |
| 36 | 阿里DDNS | `luci-app-ddns` + `ddns-scripts` | feeds/luci + feeds/packages(net) | 官方替代 | 低。`ddns-scripts` 自带 aliyun 服务商脚本 |
| 37 | 动态 DNS | `luci-app-ddns` | feeds/luci | 官方 | 低 |
| 38 | DDNS-GO | `luci-app-ddns-go` + `ddns-go` | feeds/luci + feeds/packages(net) | 官方 | 低 |
| 39 | Lucky | `luci-app-lucky` + `lucky` | 第三方 `gdy666/luci-app-lucky` | 第三方 | 中。lucky 内核为仓库内 `lucky/Makefile` 下载的预编译二进制（需 x86_64 资产可用） |
| 40 | SmartDNS | `luci-app-smartdns` + `smartdns` | feeds/luci + feeds/packages(net) | 官方 | 低。`smartdns-ui` 需要 rust 工具链，建议不开 |
| 41 | MosDNS | `luci-app-mosdns`（核心用官方 `mosdns` v5.3.3） | 第三方 `kenzok8/small` + feeds/packages(net) | 第三方 | 中。kenzok8/small 的 Makefile 依赖 `+mosdns +geo2txt +ucode`，其中 `mosdns` 官方已有 |
| 42 | LXC Containers | `luci-app-lxc` + `lxc`/`lxc-auto`/`rpcd-mod-lxc` | feeds/luci + feeds/packages(utils) | 官方 | 中。需要 lxc 系列包与 kmod；x86_64 无 `!arc` 限制 |
| 43 | 网络唤醒 | `luci-app-wol` | feeds/luci | 官方 | 低 |
| 44 | WatchCat | `luci-app-watchcat` + `watchcat` | feeds/luci + feeds/packages(utils) | 官方 | 低 |
| 45 | UU游戏加速器 | — | — | 缺失 | 放弃：闭源商业加速器，体积大且无维护包 |
| 46 | 奇游联机宝 | — | — | 缺失 | 放弃（同上） |
| 47 | Frps | `luci-app-frps` + `frp` | feeds/luci + feeds/packages(net) | 官方 | 低 |
| 48 | Frp 内网穿透 | `luci-app-frpc` + `frp` | feeds/luci + feeds/packages(net) | 官方 | 低 |
| 49 | UPnP | `luci-app-upnp` + `miniupnpd-nftables` | feeds/luci + feeds/packages(net) | 官方 | 低。nftables 变体是默认变体 |
| 50 | Nps 内网穿透 | `luci-app-nps` + `nps` | feeds/luci + feeds/packages(net) | 官方 | 低 |
| 51 | 迅雷快鸟 | `luci-app-xlnetacc` | feeds/luci | 官方 | 中。LuCI 内置脚本实现（依赖 jshn/curl/wget-ssl），但服务接口随时可能失效 |
| 52 | OpenVPN(客户端) | `openvpn-openssl`（有核心包，**无** `luci-app-openvpn`） | feeds/packages(net) | 缺失（UI） | 中。可在「网络→接口」用 openvpn proto 或命令行；若必须要 GUI，需自行引入 openwrt/luci 的 luci-app-openvpn（与官方 luci feed 冲突，不推荐） |
| 53 | uHTTPd | `luci-app-uhttpd` + `uhttpd` | feeds/luci + 主仓库 package/network/services/uhttpd | 官方 | 低 |
| 54 | KMS 服务器 | `luci-app-vlmcsd` + `vlmcsd` | feeds/luci + feeds/packages(net) | 官方 | 低 |
| 55 | IPTV 帮手 | `luci-app-udpxy` + `luci-app-rtp2httpd` + `luci-app-omcproxy` | feeds/luci + feeds/packages(net) | 官方替代 | 低。BleachWrt 的 iptvhelper 是聚合壳，官方三件套功能等价 |
| 56 | 组播代理 | `luci-app-omcproxy` + `omcproxy` | feeds/luci + **主仓库** `package/network/services/omcproxy` | 官方 | 低。注意核心包在主仓库，不在 packages feed |
| 57 | udpxy | `luci-app-udpxy` + `udpxy` | feeds/luci + feeds/packages(net) | 官方 | 低 |
| 58 | AirPlay 2 音频接收器 | `luci-app-airplay2` + `shairport-sync-openssl` | feeds/luci + feeds/packages(sound/multimedia) | 官方 | 中低。核心包名以 luci app 依赖为准（`shairport-sync-openssl`），未逐文件核对 |
| 59 | NFS 管理 | `luci-app-nfs` + `nfs-kernel-server` | feeds/luci + feeds/packages(net) | 官方 | 低。v3/v4 变体互斥（CONFLICTS） |
| 60 | Alist 文件列表 | `luci-app-openlist` | feeds/luci | 官方替代 | 低。OpenList 是 Alist 官方后继，包声明 `PROVIDES:=alist` |
| 61 | USB 打印服务器 | `luci-app-usb-printer` | feeds/luci | 官方 | 低 |
| 62 | 打印服务器(模块) | `luci-app-p910nd` + `p910nd` | feeds/luci + feeds/packages | 官方 | 低 |
| 63 | 硬盘休眠 | `luci-app-hd-idle` + `hd-idle` | feeds/luci + feeds/packages(utils) | 官方 | 低 |
| 64 | 网络共享(SMB) | `luci-app-samba4` + `samba4-server` | feeds/luci + feeds/packages(net) | 官方 | 低 |
| 65 | Aria2 配置 | `luci-app-aria2` + `aria2` | feeds/luci + feeds/packages(net) | 官方 | 低 |
| 66 | 挂载 SMB 网络共享 | `luci-app-cifs-mount` + `cifs-utils` | feeds/luci + feeds/packages(net) | 官方 | 低 |
| 67 | miniDLNA | `luci-app-minidlna` + `minidlna` | feeds/luci + feeds/packages(multimedia) | 官方 | 低 |
| 68 | Transmission | `luci-app-transmission` + `transmission-daemon` | feeds/luci + feeds/packages(net) | 官方 | 低 |
| 69 | FTP 服务器 | `luci-app-vsftpd` + `vsftpd` | feeds/luci + feeds/packages(net) | 官方 | 低 |
| 70 | qBittorrent | `luci-app-qbittorrent` + `qbittorrent` | feeds/luci + feeds/packages(net) | 官方 | 中。Qt6 依赖，镜像体积明显增大（x86_64 可承受） |
| 71 | aMule | `luci-app-amule` + `amule` | feeds/luci + feeds/packages(net) | 官方 | 低 |
| 72 | N2N VPN | `luci-app-n2n` + `n2n` | feeds/luci + feeds/packages(net) | 官方 | 低 |
| 73 | SoftEther VPN 服务器 | `luci-app-softethervpn` + `softethervpn5` | feeds/luci + feeds/packages(net) | 官方 | 低 |
| 74 | OpenVPN 服务器 | `luci-app-openvpn-server` + `openvpn-openssl` | feeds/luci + feeds/packages(net) | 官方 | 低 |
| 75 | ZeroTier | `luci-app-zerotier` + `zerotier` | feeds/luci + feeds/packages(net) | 官方 | 低 |
| 76 | IP/MAC绑定 | `luci-app-arpbind` | feeds/luci | 官方 | 低 |
| 77 | 流量统计 | `luci-app-nlbwmon` + `nlbwmon` | feeds/luci + feeds/packages(net) | 官方替代 | 低。bandwidthd 早已废弃，nlbwmon 是官方等价方案 |
| 78 | 网速测试 | `luci-app-librespeed`（或 `luci-app-sqm`+`speedtest-go`） | feeds/luci + feeds/packages(net) | 官方替代 | 低。netspeedtest 无可靠来源 |
| 79 | SQM QoS | `luci-app-sqm` + `sqm-scripts` | feeds/luci + feeds/packages(net) | 官方 | 低 |
| 80 | 应用过滤 | —（`luci-app-appfilter` 存在，但核心包 `appfilter` 在官方 feeds/主仓库中均未找到） | feeds/luci（仅 UI） | 缺失 | 放弃。官方 UI 存在但核心包缺失，选了会构建失败 |
| 81 | 服务质量(QoS) | —（`luci-app-qos-legacy` 依赖的 `qos-scripts` 已不在 feeds） | — | 缺失 | 放弃。现代等价：`luci-app-sqm` / `luci-app-qosify` |
| 82 | 多线多拨 | `luci-app-syncdial` + `kmod-macvlan` | feeds/luci + 主仓库 kernel | 官方 | 低。依赖 `luci-app-mwan3` |
| 83 | 负载均衡 | `luci-app-mwan3` + `mwan3` | feeds/luci + feeds/packages(net) | 官方 | 低 |
| 84 | Turbo ACC 网络加速 | — | — | 缺失 | 放弃：其 offload/BBR 补丁不兼容 6.18 + firewall4/nftables，且无 2026 维护 |
| 85 | 网络带宽监视器 | `luci-app-nlbwmon` + `nlbwmon` | feeds/luci + feeds/packages(net) | 官方 | 低 |
| 86 | IPV6 | `luci-proto-ipv6` + `odhcp6c` + `odhcpd` | 主仓库 package/network/ipv6 + services/odhcpd | 官方替代 | 低。官方基础包已覆盖 IPv6；不存在 `ipv6helper` 包 |

### 统计

| 状态 | 条数 |
|:---|---:|
| 官方（含 1 条需第 3 方 deps 的 PassWall） | 50 |
| 官方替代 | 8 |
| 第三方（本轮建议引入） | 11 |
| 第三方（存在但建议放弃） | 1 |
| 缺失 / 建议放弃 | 16 |
| **合计** | **86** |

## 2. 需要新增的第 3 方 feed（git URL + 分支 + 风险）

| feed | git URL / 分支 | 2026 维护状态（2026-10-31 查） | 覆盖包 | 风险 | 理由 |
|:---|:---|:---|:---|:---|:---|
| istore | `https://github.com/istoreos/istore.git` / `main` | pushed 2026-09-25，未 archived，MIT，2279★ | `luci-app-store`,`luci-lib-taskd`,`luci-lib-xterm`,`taskd` | 中 | 纯 shell/JS，无 C；但依赖 taskd 守护进程与 opkg/apk 双栈，首次集成需实测；仓库用 `luci/` 子目录层级 |
| argon-config | `https://github.com/jerrykuku/luci-app-argon-config.git` / `master` | 最后提交 2026-10-22，未 archived | `luci-app-argon-config` | 低 | 3.0 起是空壳兼容包，真实主题在官方 `luci-theme-argon`；只有 JS/JSON/po |
| passwall2 | `https://github.com/Openwrt-Passwall/openwrt-passwall2.git` / `main` | PKG v26.10.29（2026-10-29），组织接手维护 | `luci-app-passwall2` | 中 | lua CBI + `luci-compat`；依赖官方 `xray-core`/`sing-box`/`v2ray-geoip` 等已有 |
| passwall-deps | `https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git` / `main` | pushed 2026-10-30，未 archived | `geoview`（及 hysteria/naiveproxy 等） | 中 | 只为官方 PassWall 提供 `geoview` 等非官方依赖；含 Go/C 编译，编译耗时 |
| helloworld | `https://github.com/fw876/helloworld.git` / **`dev`**（默认分支不是 master！） | pushed 2026-10-30，未 archived，GPL-3.0 | `luci-app-ssr-plus`,`lua-neturl`,`shadowsocksr-libev*`,`ipt2socks`,`simple-obfs`,`v2ray-plugin` 等 | 中高 | 仍活跃，但整套是 lua/旧版 luci 架构，与 25.12 ucode luci 靠 `luci-compat` 维持；dev 分支漂移快 |
| small | `https://github.com/kenzok8/small.git` / `master` | pushed 2026-10-30，未 archived，Apache-2.0，1476★ | `mihomo`,`luci-app-mosdns`,`luci-app-nikki`,`luci-app-momo`（另含 homeproxy/openclash 等同名包，**不要重复引入**） | 中 | 聚合 feed、包间依赖杂；`mihomo` 为 Go 编译；与官方同名包（luci-app-homeproxy/luci-app-openclash 等）冲突，只要选缺的 4 个 |
| lucky | `https://github.com/gdy666/luci-app-lucky.git` / `main` | pushed 2026-10-29，未 archived | `luci-app-lucky`,`lucky` | 中 | lucky 核心是预编译二进制下载，需确认 x86_64 资产；lua controller + 新 luci menu.d 混用 |
| partexp | `https://github.com/sirpdboy/luci-app-partexp.git` / `master`（分支待实测，commits Atom 404） | 仓库存在且可读，无明确 CI/版本记录 | `luci-app-partexp` | 中高 | 单人维护、纯脚本；无正式 release/CI，兼容性需自测 |
| advanced | `https://github.com/sirpdboy/luci-app-advanced.git` / `master` | 最后代码提交 2023，2026-03 仅 README | `luci-app-advanced` | 高 | 长期未维护，lua CBI 老风格，25.12 luci 兼容性存疑 |
| openwrt-packages（可选） | `https://github.com/kenzok8/openwrt-packages.git` / `master` | pushed 2026-10-29，未 archived，7200★ | `luci-app-wechatpush`（包名 `luci-app-serverchan`） | 中高 | 巨型聚合 feed，同名包与官方冲突概率高；仅为微信推送一个功能不值得整 feed，可放弃 |

> 不建议引入：`xiaorouji/openwrt-passwall`、`xiaorouji/openwrt-passwall2`（GitHub API 404，仓库已迁移/改名，请勿再引用旧 URL）、`sbwml/luci-app-alist`（**已 archived**，2025-06 存档，功能由 OpenList 取代）、`morytyann/OpenWrt-mihomo`（已迁移为 `nikkinikki-org/OpenWrt-nikki`）。

## 3. 冲突 / 互斥检查

- **wpad 变体**：`wpad-basic-mbedtls` / `wpad-mbedtls` / `wpad-openssl` 三选一（计划接 MT7922，建议 `wpad-openssl` 以覆盖 WPA3/EAP 场景；与 `hostapd` 不能同时选）。
- **Docker 两套 UI**：`luci-app-dockerman`（完整）与 `luci-app-docker`（LuCI 自带 Docker-CE 面板）都依赖 `docker`+`dockerd`，二选一，建议 dockerman。
- **代理类全家桶互抢规则**：`luci-app-openclash` / `luci-app-passwall` / `luci-app-passwall2` / `luci-app-ssr-plus` / `luci-app-homeproxy` / `luci-app-nikki` / `luci-app-momo` 同时编入会导致 LAN 劫持、dnsmasq 注入、nftables/iptables 规则冲突，且各自拉入 xray-core/sing-box/mihomo 多份大二进制。BleachWrt 全带上是为了「有得选」，实际固件建议**只默认启用 1~2 个**（见 §4）。
- **PassWall / PassWall2 共存**：包可共存，但共享 `dnsmasq-full`、`chinadns-ng`、`tcping`，同时启用必冲突；`luci-app-passwall` 与 `luci-app-passwall2` 只能启用其一。
- **`luci-theme-argon` + `luci-app-argon-config`**：必须成对；3.0 之后 argon-config 是兼容空壳，旧版 conffile 会被主题迁移，升级时注意 `/etc/config/argon` 备份。
- **文件共享**：`luci-app-samba4`(Samba) 与 `luci-app-ksmbd`(内核态 SMB) 二选一；`luci-app-nfs` 的 `nfs-kernel-server` 与 `nfs-kernel-server-v4` 由 `CONFLICTS` 强制互斥。
- **UPnP**：`miniupnpd-nftables`（默认）与 `miniupnpd-iptables` 互斥（`CONFLICTS`）。
- **OpenVPN 变体**：`openvpn-openssl` / `openvpn-mbedtls` / `openvpn-wolfssl` 三选一（都 PROVIDES `openvpn`）。
- **QoS 三件套**：`sqm-scripts`（官方推荐）/ `qosify` / `qos-legacy`(依赖的 `qos-scripts` 已不存在，不可用)；`luci-app-qos-legacy` 不要选。
- **IPTV 三件套**：`udpxy`、`rtp2httpd`、`omcproxy` 功能有重叠但可共存（组合使用时注意同端口/IGMP 代理重复）。
- **多线多拨**：`luci-app-syncdial` 依赖 `luci-app-mwan3` + `kmod-macvlan`，先有 mwan3 再用 syncdial。
- **第三方同名包**：`kenzok8/small` 里也有 `luci-app-homeproxy` / `luci-app-openclash`，**必须只用官方版本**，否则 feeds 安装顺序会导致覆盖。
- **smartdns-ui**：需 rust 工具链与 `@!i386`，x86_64 可编但显著增加构建时间，建议只开 `smartdns`。

## 4. 建议放进固件的最小高价值集合（约 40 项）

> 原则：x86 软路由核心用途（路由/分流/DNS/下载/文件共享/内网穿透/监控），避开体积巨大或互相冲突的重复功能。

**基础与主题**
`luci-theme-argon` `luci-app-argon-config`(第三方) `luci-app-store`(第三方) `luci-app-uhttpd` `luci-app-ttyd` `luci-app-filemanager` `luci-app-diskman` `luci-app-partexp`(第三方)

**网络/DNS/代理（默认启用 HomeProxy；OpenClash 作为备选一并编入但不启用）**
`luci-app-homeproxy` `sing-box` `luci-app-smartdns` `smartdns` `luci-app-mosdns`(第三方) `mosdns` `luci-app-passwall`(官方+geoview) `luci-app-ssr-plus`(第三方,可选) `luci-app-openclash`(官方,可选) `luci-app-ddns` `luci-app-ddns-go` `luci-app-upnp` `miniupnpd-nftables` `luci-app-mwan3` `mwan3` `luci-app-syncdial` `luci-app-sqm` `sqm-scripts` `luci-app-nlbwmon` `nlbwmon`

**广告过滤/监控/工具**
`luci-app-netdata` `netdata` `luci-app-adblock-fast` `luci-app-adguardhome` `adguardhome` `luci-app-ramfree` `luci-app-autoreboot` `luci-app-watchcat` `luci-app-wol` `luci-app-arpbind` `luci-app-lxc`

**下载/共享/媒体**
`luci-app-samba4` `samba4-server` `luci-app-nfs` `nfs-kernel-server` `luci-app-aria2` `aria2` `luci-app-transmission` `transmission-daemon` `luci-app-qbittorrent` `qbittorrent` `luci-app-minidlna` `minidlna` `luci-app-vsftpd` `vsftpd` `luci-app-openlist` `openlist`

**穿透/VPN**
`luci-app-frpc` `luci-app-frps` `luci-app-nps` `luci-app-zerotier` `luci-app-openvpn-server` `openvpn-openssl`

**存储/USB/打印**
`luci-app-hd-idle` `luci-app-usb-printer` `luci-app-p910nd` `luci-app-cifs-mount`

**Docker（可选，体积大）**
`luci-app-dockerman` `docker` `dockerd` `docker-compose`

**IPTV（可选）**
`luci-app-udpxy` `udpxy` `luci-app-rtp2httpd` `luci-app-omcproxy`

## 5. 建议放弃的插件及理由（17 条）

| 插件 | 理由 |
|:---|:---|
| Hello World (vssr) | 上游 `jerrykuku/luci-app-vssr` 仓库已不可达；功能由 `luci-app-ssr-plus` 覆盖 |
| Clash (frainzy1477) | 2021 年 lua+iptables 老代码，与 25.12 nftables/luci 不兼容，风险高；OpenClash 已官方内置 |
| 关机 `luci-app-poweroff` | 无维护来源；用 `luci-app-advanced-reboot` + 命令行 `poweroff` 即可 |
| OpenVPN 客户端 UI `luci-app-openvpn` | 当前 immortalwrt/luci master 已无此 app（仅 openvpn 核心包在）；用接口 proto/命令行，或放弃 GUI |
| 集客AC控制器 `luci-app-gecoosac` | 商用 AC 管理，x86 家用无意义，无 2026 维护来源 |
| iKoolProxy | 项目停更、不兼容 nftables |
| 阿里云盘 WebDAV / FUSE | 上游归档、协议多变；用 OpenList 挂载网盘替代 |
| MentoHUST | 校园认证类、无维护来源 |
| 易有云 / DDNSTO | LinkEase 商业服务，无可用开源包；远程访问用 ZeroTier/Frp/WireGuard |
| 全能推送 `luci-app-pushbot` | 无可靠 2026 仓库；`luci-app-serverchan`/`luci-app-email` 可替代 |
| UU / 奇游 加速器 | 闭源商业客户端，体积大且无维护包 |
| 应用过滤 `luci-app-appfilter` | LuCI UI 有但核心 `appfilter` 包在官方 feeds 与主仓库均不存在，选中会构建失败 |
| QoS `luci-app-qos` | 官方只剩 `luci-app-qos-legacy`，其依赖 `qos-scripts` 已从 feeds 移除；改用 `luci-app-sqm` / `luci-app-qosify` |
| Turbo ACC | offload 补丁与内核 6.18 + firewall4/nftables 冲突，已无维护 |
| 流量统计 `luci-app-bandwidthd` | bandwidthd 已废弃；用官方 `luci-app-nlbwmon` |
| 网速测试 `luci-app-netspeedtest` | 无可靠来源；用官方 `luci-app-librespeed` 或 `speedtest-go`/`iperf3` 命令行 |
| `luci-app-alist` / `luci-app-filetransfer` / `luci-app-iptvhelper` / `ipv6helper` | 非「放弃」而是「被替代」：OpenList/filemanager/udpxy+rtp2httpd/官方 IPv6 基础包，见 §1 状态列 |

## 6. 待验证风险（构建前必测）

1. 官方 LuCI 的 lua 系应用（openclash/passwall/diskman/syncdial/…）依赖 `luci-compat`，25.12 下需确认 `luci-compat` 仍在 luci feed 中且可用（`luci-app-openclash`/`luci-app-passwall` 的 Makefile 均显式依赖它）。
2. ~~`luci-app-appfilter`、`luci-app-qos-legacy` 属于「UI 在、核心包不在」的陷阱~~ → **已修正，见 §7.1**：两者核心包（`appfilter`/`kmod-oaf`、`qos-scripts`）在权威包清单里都存在，第二阶段建议加入。
3. `luci-app-airplay2` 依赖 `shairport-sync-openssl`，本轮只核对了 LuCI 侧，未逐文件确认核心包在当前 feeds 的包名。
4. ~~`luci-app-passwall` 的 geoview 依赖需第三方 feed~~ → **已修正，见 §7.1**：`geoview` 就在官方 `packages` feed 中（第一阶段已选中），PassWall 无缺依赖。
5. 第 3 方 feed 的 `src-git` 层级：`sirpdboy/luci-app-partexp` 的 Makefile 在 `luci-app-partexp/` 子目录（且分支是 `main` 不是 `master`），`istoreos/istore` 的包在 `luci/` 子目录，feeds install 时需确认能被扫描到（必要时用 `src-link` 或手工 `git clone` 到 `package/`）。
6. 一旦并行任务产出 `.build/available.txt`，应以其为准复跑一遍核对（尤其第 3 方 feed 之外的官方包名）。

## 7. 第二阶段（plus-ext）可行性结论

> 依据：`.build/reports/.packageinfo`（13386 个包的权威元数据）、`.build/available.txt`（2241 行 feeds 目录清单）、
> `.build/reports/selected-packages.txt`（第一阶段实际选中 741 包）、以及 `.build/inspect/` 下 8 个第三方仓库的
> `git clone --depth 1 --filter=blob:none` 只读分析。对应产物：`stage2-feeds.conf`、`stage2-packages.txt`。

### 7.1 对 §1 结论的修正（以权威包清单为准）

| 原结论 | 实际 | 依据 |
|:---|:---|:---|
| 应用过滤（luci-app-oaf）「核心包 appfilter 缺失，放弃」 | **官方可用**，应加入 | `package/feeds/packages/open-app-filter/Makefile` 提供 `appfilter` 2026.04.20~569f93b，依赖 `kmod-oaf`（官方已有）；LuCI 侧 `luci-app-appfilter` v6.1.4 依赖 `+appfilter +luci-compat +luci-lua-runtime` |
| QoS（luci-app-qos）「qos-scripts 已移除，放弃」 | **官方可用**，应加入 | `qos-scripts` 在主仓库 `package/network/config/qos-scripts`（1.3.1-r33），`tc` 由 `tc-tiny/tc-full` Provides |
| 微信推送「需第 3 方 kenzok8/openwrt-packages」 | **官方可用**（无需第三方 feed） | `package/feeds/luci/luci-app-wechatpush` v3.6.12，依赖 iputils-arping/curl/jq/bash 均为官方包 |
| Argon 主题设置「需 jerrykuku/luci-app-argon-config」 | **官方已提供**，第三方包会重名 | 官方 `luci-theme-argon` 声明 `Provides: @luci-theme-argon-any luci-app-argon-config`，并自带 `luci-i18n-argon-config-*`；第一阶段已选 `luci-theme-argon` + `luci-i18n-argon-config-zh-cn` |
| geoview 需 `openwrt-passwall-packages` feed | **官方 packages feed 已有** | `package/feeds/packages/geoview`，第一阶段已选入 741 包 |

修正后的总账：**官方可满足 62/86（72%）** = 官方直用 53 + 官方替代/内置 9；**第三方可用 8**；第三方放弃 2（advanced、frainzy-clash）；缺失 14。

### 7.2 8 个第三方仓库的结构与可用性结论

| 仓库 | 分支 / 最后提交 | 顶层结构 | 可用包 | 结构问题 | 结论 |
|:---|:---|:---|:---|:---|:---|
| Openwrt-Passwall/openwrt-passwall2 | main / 2026-10-30 | 仅 `luci-app-passwall2/` | `luci-app-passwall2` v26.10.29 | 无；包在一级子目录，标准 feed 布局 | **采纳**，风险低-中 |
| gdy666/luci-app-lucky | main / 2026-10-29 | `luci-app-lucky/` + `lucky/` + `scripts/` | `luci-app-lucky` v3.0.0、`lucky` v3.5.0、`luci-i18n-lucky-zh-cn` | 无；`lucky` 为预编译二进制下载（`PKG_HASH:=skip`），ARCH 映射已确认含 x86_64 | **采纳**，风险中 |
| sirpdboy/luci-app-partexp | **main**（无 master）/ 2026-10-30 | `luci-app-partexp/` + `doc/` | `luci-app-partexp` v2.0.5 | 无；注意分支名是 `main`，写 `;master` 会 clone 失败 | **采纳**，风险中 |
| istoreos/istore | main / 2026-09-25 | `luci/`(4 包) + `translations/` + `preview/` | `luci-app-store` v0.2.1-r1、`luci-lib-taskd` v1.0.26、`luci-lib-xterm` v4.18.0、`taskd` v1.0.3 | 包在 `luci/` 二级目录（SCAN_DEPTH=5 内可扫到，但安装后路径是 `package/feeds/istore/luci/<pkg>`）；构建时另需下载 `linkease/istore-ui` 前端 | **采纳**，风险中 |
| kenzok8/small | master / 2026-10-31 | 55 个扁平包目录（含 13 个 luci-app） | `mihomo` v1.19.33、`geo2txt` v1.0.0、`luci-app-ssr-plus` v198、`luci-app-mosdns` v1.7.15、`luci-app-nikki` v1.26.2、`luci-app-momo` v1.2.2 | 聚合 feed：33 个符号与官方同名，**只能选择性 install 6 个包**；另有 luci-app-openclash/homeproxy/passwall/passwall2 同名 | **采纳（限定包）**，风险中 |
| fw876/helloworld | **dev** / 2026-10-31 | 30 个扁平包目录 | luci-app-ssr-plus v198 等 | 25 个包与官方同名；与 small 完全重复（mihomo 反而更旧） | **放弃**（用 small 替代） |
| jerrykuku/luci-app-argon-config | master / 2026-10-22 | **根级 Makefile** 单包 | `luci-app-argon-config` v3.0.0（空壳兼容包） | 根级 Makefile 不适合作 src-git feed（`do_install_src` 的 `s/\/Makefile$//` 匹配不到裸 `Makefile`，链接路径会算到仓库根）；且官方主题已 Provides 同名 | **放弃** |
| sirpdboy/luci-app-advanced | master / 代码 2023-04 | **根级 Makefile** 单包（luasrc/htdocs/root） | `luci-app-advanced` v1.20 | 根级 Makefile + 无 `luci.mk` + `DEPENDS` 为空 + 把 lua controller 直塞 `/usr/lib/lua/luci`；25.12 ucode LuCI 下入口大概率不生效 | **放弃**，风险高 |

### 7.3 采用方案

**4 个新 feed + 1 个聚合 feed 的 6 个包**，全部写入 `stage2-feeds.conf` / `stage2-packages.txt`：

```
src-git passwall2 https://github.com/Openwrt-Passwall/openwrt-passwall2.git;main
src-git lucky     https://github.com/gdy666/luci-app-lucky.git;main
src-git partexp   https://github.com/sirpdboy/luci-app-partexp.git;main
src-git istore    https://github.com/istoreos/istore.git;main
src-git small     https://github.com/kenzok8/small.git;master
```

追加的包（18 个：3 个官方补漏 + 15 个来自 5 个第三方 feed）：

| 来源 | 包 |
|:---|:---|
| 官方补漏（无需新 feed） | `luci-app-wechatpush` `luci-app-appfilter` `luci-app-qos-legacy` |
| passwall2 | `luci-app-passwall2` |
| lucky | `luci-app-lucky` `lucky` `luci-i18n-lucky-zh-cn` |
| partexp | `luci-app-partexp` |
| istore | `luci-app-store` `luci-lib-taskd` `luci-lib-xterm` `taskd` |
| small | `mihomo` `geo2txt` `luci-app-ssr-plus` `luci-app-mosdns` `luci-app-nikki` `luci-app-momo` |

安装必须**逐包**：`./scripts/feeds install <包名...>`，**禁止 `install -a`**（small 会把 33 个同名包全部摊开）。

### 7.4 重名冲突（第二阶段核心风险）

- `kenzok8/small` 与官方同名 33 个：`brook, chinadns-ng, dae, daed, dns2socks, dns2tcp, geoview, gn, hysteria, ipt2socks, lua-neturl, luci-app-openclash, microsocks, mosdns, naiveproxy, redsocks2, shadow-tls, simple-obfs-client, simple-obfs-server, sing-box, sing-box-tiny, tcping, trojan, tuic-client, v2ray-core, v2ray-extra, v2ray-geoip, v2ray-geosite, v2ray-geosite-ir, v2ray-plugin, v2raya, xray-core, xray-plugin`。
- small 内同名的 luci 应用：`luci-app-openclash` / `luci-app-homeproxy` / `luci-app-passwall`（官方已有）、`luci-app-passwall2`（passwall2 feed 已有）。
- 跨 feed 同名：`mihomo`（small vs helloworld，helloworld 已放弃）、`luci-app-ssr-plus`（同上）、`luci-app-passwall2`（small vs passwall2，feeds.conf 顺序保证取上游）、`luci-app-argon-config`（官方 Provides vs 第三方，后者放弃）。
- 规避机制：① 官方 feed 保持在前，`scripts/feeds` 按 feeds.conf 顺序解析重名；② 只装白名单包；③ 若确实跑过 `install -a`，用 `./scripts/feeds uninstall` 清掉 small 的同名包再重跑。

### 7.5 第二阶段仍然放弃的项

| 项 | 原因 |
|:---|:---|
| `fw876/helloworld` 整个 feed | 与 small 重复、25 个包与官方重名，新增能力为 0 |
| `luci-app-argon-config`（jerrykuku） | 官方主题已 Provides 同名；根级 Makefile 结构不可直接作 feed |
| `luci-app-advanced`（sirpdboy） | 2023 年代码、无 luci.mk、无依赖声明，25.12 下高风险 |
| `luci-app-clash`（frainzy1477） | 2021 年 lua+iptables 老代码；OpenClash 官方已内置，功能重复 |
| 第一轮已判死的 14 条 | poweroff / vssr / gecoosac / ikoolproxy / aliyundrive-webdav / aliyundrive-fuse / mentohust / linkease / ddnsto / pushbot / UU / 奇游 / OpenVPN 客户端 UI / turboacc（nftables+6.18 不兼容） |

### 7.6 对固件体积与编译时间的影响（x86_64，粗估）

| 新增内容 | 编译时间（32 核） | 镜像体积（squashfs 压缩后） |
|:---|:---|:---|
| `mihomo`（Go，v1.19.33） | +3~5 min | +12~18 MB |
| `lucky` v3.5.0（预编译二进制，仅下载+打包） | <10 s（下载 20MB） | +7~9 MB |
| `luci-app-ssr-plus` + `luci-app-mosdns` + `geo2txt` + `luci-app-nikki` + `luci-app-momo` | +1~2 min（geo2txt 是唯一 Go 编译） | +4~6 MB |
| `luci-app-passwall2` | 秒级（纯 UI） | +2~3 MB |
| istore（`luci-app-store` + taskd + 前端 tarball） | <1 min | +2~3 MB |
| `luci-app-partexp` | 秒级 | +0.3 MB |
| 官方补漏 3 个（wechatpush/appfilter/qos-legacy） | +1 min（appfilter=内核模块） | +1 MB |
| **合计** | **+6~10 min**（相对整包构建可忽略） | **+28~40 MB**（efi 镜像从 ~475MB 级再增约 7~9%） |

### 7.7 第二阶段上线前必测项

1. `luci-app-store`：`linkease/istore-ui` 前端 tarball 下载 + `istore-ui` 的 `USE_APK` 分支在 25.12（apk 包管理器）下是否正常；`luci-lib-taskd` 版本约束 `taskd (>=1.0.3)` 是否满足。
2. `mihomo`：Go 编译在 x86_64 下产出 `/usr/libexec/mihomo-core` + ALTERNATIVES 是否与 `luci-app-nikki` 期望一致；squashfs 增大后是否触发镜像尺寸告警。
3. `luci-app-ssr-plus`：lua CBI 需要 `luci-compat` + `luci-lua-runtime`（前者已选，后者需确认在 .config 里）；默认 `INCLUDE_Mihomo=y` 会拉 small 的 mihomo，不要与官方 `sing-box` 混用同一套 nft 规则。
4. `lucky`：构建机需能访问 GitHub Releases；`PKG_HASH:=skip` 意味着不做哈希校验（供应链风险）。
5. `luci-app-appfilter`：`kmod-oaf` 在 6.18 内核下能否编译（2026.04.20 的源码），需要真实 `make` 验证。
6. `luci-app-passwall2` 与已选官方 `luci-app-passwall` 共存：两者默认都会接管 dnsmasq + transparent proxy，**运行时只能启用一个**（编译期可共存）。
