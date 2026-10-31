# ============================================================================
# Stage 2 / plus-ext 追加包清单（一行一个，可直接转成 CONFIG_PACKAGE_<name>=y）
# 生成：2026-10-31；每个包名都能在 .build/reports/.packageinfo（官方）或
# .build/inspect/<repo> 文件树（第三方）里找到实证，证据路径见每节注释。
# 安装命令（只装具体包，不要用 -a）：
#   ./scripts/feeds update -a
#   ./scripts/feeds install luci-app-wechatpush luci-app-appfilter luci-app-qos-legacy \
#       luci-app-passwall2 luci-app-lucky lucky luci-i18n-lucky-zh-cn luci-app-partexp \
#       luci-app-store luci-lib-taskd luci-lib-xterm taskd \
#       mihomo geo2txt luci-app-ssr-plus luci-app-mosdns luci-app-nikki luci-app-momo
# 说明：lucky / geo2txt / mihomo 是内核/工具包，通常由 luci-app-* 依赖自动拉入；
#       这里显式列出，便于 verify 脚本逐项确认存在。
# ============================================================================

# ---------------------------------------------------------------------------
# 官方 feeds 的补漏（不新增 feed；第一阶段 config 未选，但官方本来就有）
# 证据：.build/reports/.packageinfo 的 Source-Makefile
# ---------------------------------------------------------------------------
luci-app-wechatpush      # 低风险 | feeds/luci 官方包 v3.6.12，依赖 iputils-arping/curl/jq/bash 均官方已有
luci-app-appfilter       # 低-中 | feeds/luci v6.1.4；核心 appfilter 来自 feeds/packages/open-app-filter 2026.04.20，kmod-oaf 官方已有（内核 6.18 需实编译验证）
luci-app-qos-legacy      # 低 | feeds/luci；依赖 qos-scripts 在主仓库 package/network/config/qos-scripts(1.3.1-r33)，tc 由 tc-tiny/tc-full Provides

# ---------------------------------------------------------------------------
# feed: passwall2  (https://github.com/Openwrt-Passwall/openwrt-passwall2.git ; main)
# 最后提交 2026-10-30；仓库只有 luci-app-passwall2/ 一个包；无重名冲突
# 证据：.build/inspect/passwall2/luci-app-passwall2/Makefile (PKG_VERSION:=26.10.29)
# ---------------------------------------------------------------------------
luci-app-passwall2       # 低-中 | 依赖 coreutils*/curl/ip-full/luci-* /geoview/tcping/lyaml/v2ray-geoip/v2ray-geosite/unzip 全部官方已有；lua CBI 需 luci-compat（已选）

# ---------------------------------------------------------------------------
# feed: lucky  (https://github.com/gdy666/luci-app-lucky.git ; main)
# 最后提交 2026-10-29；仓库根下 luci-app-lucky/ + lucky/ 两个包；无重名冲突
# 证据：.build/inspect/lucky/luci-app-lucky/Makefile, lucky/lucky/Makefile
# ---------------------------------------------------------------------------
luci-app-lucky           # 中 | v3.0.0，纯 JS/Lua UI；依赖 lucky + rpcd-mod-file + lua + libubus-lua + luci-lib-* 均官方已有
lucky                    # 中 | v3.5.0，**预编译二进制**：构建时从 GitHub Releases 下载 lucky_3.5.0_Linux_x86_64.tar.gz，PKG_HASH:=skip（未校验哈希）+ x86_64 映射已确认
luci-i18n-lucky-zh-cn    # 低 | 中文翻译包，luci.mk 自动生成

# ---------------------------------------------------------------------------
# feed: partexp  (https://github.com/sirpdboy/luci-app-partexp.git ; **main**，没有 master 分支)
# 最后提交 2026-10-30；仓库根下 luci-app-partexp/ 一个包；无重名冲突
# 证据：.build/inspect/partexp/luci-app-partexp/Makefile (v2.0.5)
# ---------------------------------------------------------------------------
luci-app-partexp         # 中 | 依赖 fdisk/block-mount/bc/blkid/parted/btrfs-progs/losetup/resize2fs/e2fsprogs/f2fs-tools/kmod-loop 均官方已有；纯脚本+RPC，无 C 代码

# ---------------------------------------------------------------------------
# feed: istore  (https://github.com/istoreos/istore.git ; main)
# 最后提交 2026-09-25；包在仓库 luci/ 子目录下（嵌套一层，仍在 SCAN_DEPTH=5 内）；无重名冲突
# 证据：.build/inspect/istore/luci/{luci-app-store,luci-lib-taskd,luci-lib-xterm,taskd}/Makefile
# ---------------------------------------------------------------------------
luci-app-store           # 中 | v0.2.1-r1；构建时还要下载 linkease/istore-ui 前端 tarball；依赖 curl/tar/libuci-lua/mount-utils/luci-lib-taskd
luci-lib-taskd           # 中 | v1.0.26；LUCI_EXTRA_DEPENDS: taskd (>=1.0.3)
luci-lib-xterm           # 低 | v4.18.0；纯前端资源
taskd                    # 低 | v1.0.3；纯 shell 任务守护（含 opkg/apk 双栈 root 目录）

# ---------------------------------------------------------------------------
# feed: small  (https://github.com/kenzok8/small.git ; master)
# 最后提交 2026-10-31；55 个包目录的聚合 feed；**只取下面 6 个**（其余 31 个与官方重名，见文末冲突清单）
# 证据：.build/inspect/small/<pkg>/Makefile
# ---------------------------------------------------------------------------
mihomo                   # 中 | v1.19.33，Go 编译（官方 go 工具链已有）；nikki 的必需内核；x86_64 支持
luci-app-ssr-plus        # 中-高 | v198；lua/旧版 luci 架构 + luci-compat；依赖 dns2tcp/lua-neturl/microsocks/ipt2socks/lyaml/resolveip/nping 等官方已有；默认 INCLUDE_Mihomo=y 会拉 mihomo
luci-app-mosdns          # 中 | v1.7.15；依赖 mosdns(官方 5.3.3)/uclient-fetch/v2ray-geoip/v2ray-geosite/**geo2txt**/ucode
geo2txt                  # 低 | v1.0.0，官方 feeds 没有这个包（small 独有），是 luci-app-mosdns 的硬依赖；Go 编译
luci-app-nikki           # 低-中 | v1.26.2；依赖 nikki(v2026.10.10) + mihomo + yq/firewall4/kmod-* 官方已有
luci-app-momo            # 低-中 | v1.2.2；依赖 momo(v2026.10.14) + sing-box(官方 1.14.3)/firewall4/kmod-* 官方已有

# ============================================================================
# 冲突清单（务必只看不装）—— 与官方 feeds 同名的包
# ----------------------------------------------------------------------------
# A. kenzok8/small 中与官方同名（一旦 install -a 或把整个 feed 展开就会覆盖/重复）：
#    brook, chinadns-ng, dae, daed, dns2socks, dns2tcp, geoview, gn, hysteria,
#    ipt2socks, lua-neturl, luci-app-openclash, microsocks, mosdns, naiveproxy,
#    redsocks2, shadow-tls, simple-obfs-client, simple-obfs-server, sing-box,
#    sing-box-tiny, tcping, trojan, tuic-client, v2ray-core, v2ray-extra,
#    v2ray-geoip, v2ray-geosite, v2ray-geosite-ir, v2ray-plugin, v2raya,
#    xray-core, xray-plugin                （共 33 个符号，含新增的 dae/daed）
# B. small 内还有与官方/其它 feed 同名的 luci 应用，只选择性安装即不会冲突：
#    luci-app-openclash(官方 luci), luci-app-homeproxy(官方 luci),
#    luci-app-passwall(官方 luci), luci-app-passwall2(本阶段 passwall2 feed)
# C. 跨 feed 重名需注意（本方案已规避）：
#    mihomo —— small 与 helloworld 都有；helloworld 未加入
#    luci-app-ssr-plus —— small 与 helloworld 都有；helloworld 未加入
#    luci-app-passwall2 —— small 与 passwall2 feed 都有；feeds.conf 里 passwall2 排在 small 之前，
#                         选择性安装 luci-app-passwall2 时优先取上游仓
#    luci-app-argon-config —— 官方 luci-theme-argon 以 Provides 形式提供，第三方包不得再装
# ============================================================================
