# MT7922 (Wi-Fi 6E) + ImmortalWrt x86/64 无线支持核实报告

核实对象：本仓库（immortalwrt 2026-10-30 master，25.12 基线，内核 6.18，`target/linux/x86`，
`SUBTARGETS=64 generic legacy geode`）。
结论全部来自本仓库源码（`文件:行号`），外部资料在文末单列 URL，并标注「外部」。
配套可直接使用的配置片段：`.build/wifi/config-wifi.conf`。

---

## 0. 结论摘要（TL;DR）

1. **一条 `CONFIG_PACKAGE_kmod-mt7921e=y` 就能带全依赖链**：kmod-mt7921e → kmod-mt7921-common →
   kmod-mt792x-common → kmod-mt76-connac → kmod-mt76-core → kmod-mac80211 → kmod-cfg80211 →
   (iw / wifi-scripts / wireless-regdb)，并自动带上 **mt7922 固件**、11AC/11AX 支持、hwmon、
   `KERNEL_PAGE_POOL`。**mt7922 不需要也不可能单靠 `kmod-mt7922-firmware` 工作**，它只是固件包。
2. **x86 默认不装 wpad、也不装任何无线驱动**（`target/linux/x86/Makefile:19-25`），
   必须显式选 `CONFIG_PACKAGE_wpad-openssl=y`（推荐）或其它唯一变体；
   变体之间互斥（`hostapd/Makefile:285-288`）。
3. **hostapd 的 11ax 编译开关由 `CONFIG_DRIVER_11AX_SUPPORT` 决定**
   （`hostapd/Makefile:88-90,105-112`），而该符号由 mt76 依赖 `select` 自动置 y
   （`scripts/package-metadata.pl:160-221`），因此**选了 mt7921e 就等于给 wpad 打开了 6GHz 所需的 11ax**。
4. **6GHz AP 的硬限制**：6G 只允许 WPA3-SAE / OWE（`wifi/iface.uc:12-27`）；
   **驱动同一时刻只上报 1 个 AP 接口**（mt76@0936617 `mt792x_core.c` 的 `if_limits`/`if_comb`），
   所以「2.4G+5G+6G 三个 AP 同时开」不可行，只能选一个频段做 AP（或 CNM 固件下 AP+STA 跨信道并发，需实机验证）。
5. **必须设 country**：自动生成的 6G 设备默认 country 为 `'00'`（世界域，6GHz 不可用）
   （`wifi-scripts/files/lib/wifi/mac80211.uc:103-105`），需在 LuCI 里改成允许 6GHz 的国家码。
6. **镜像**：EFI + BIOS 默认都会生成；最终文件
   `bin/targets/x86/64/immortalwrt-x86-64-generic-squashfs-combined-efi.img.gz`（EFI，推荐）
   与 `...-combined.img.gz`（BIOS）。
   **默认 `ROOTFS_PARTSIZE=160` 太小**，装「高大全」插件集建议 `2048`（2 GiB）。

---

## 1. MT7922 驱动/固件依赖链（逐行实证）

### 1.1 依赖链

| 环节 | 源码依据 |
| :--- | :--- |
| `kmod-mt7921e` 依赖 `kmod-mt7921-common`、PCI 支持 | `package/kernel/mt76/Makefile:314-320`（`:317` = `@PCI_SUPPORT +kmod-mt7921-common`），模块 `mt7921e.ko` + `AutoProbe,mt7921e`（`:318-319`） |
| `kmod-mt7921-common` 依赖 **两个固件包** + 11AX + hwmon | `package/kernel/mt76/Makefile:290-296`（`:294` = `+kmod-mt792x-common +kmod-mt7921-firmware +kmod-mt7922-firmware +@DRIVER_11AX_SUPPORT +kmod-hwmon-core`） |
| `kmod-mt792x-common` 依赖 connac + 11AX | `package/kernel/mt76/Makefile:274-280`（`:278`） |
| `kmod-mt76-connac` 依赖 `kmod-mt76-core` | `package/kernel/mt76/Makefile:149-155`（`:153`） |
| `mt76-default` 模板：`+kmod-mac80211 +@DRIVER_11AC_SUPPORT +@KERNEL_PAGE_POOL` | `package/kernel/mt76/Makefile:39-46`（`:42,:43,:44`） |
| `kmod-mac80211` 依赖 cfg80211 + crypto(cmac/ccm/gcm) + hostapd-common | `package/kernel/mac80211/Makefile:132-142`（`:136`） |
| `kmod-cfg80211` 依赖 `+iw +wifi-scripts +wireless-regdb`，并在非 ucode 模式加 `iwinfo` | `package/kernel/mac80211/Makefile:104-112`（`:107`） |

**结论**：`CONFIG_PACKAGE_kmod-mt7921e=y` 是唯一必须的驱动行；`kmod-mt7922-firmware`
会被 `mt7921-common` 自动选中，无需额外配置（但显式写出无害，见 config 文件第 3 节）。

### 1.2 固件文件与 PCI ID

- mt7922 固件安装到 `/lib/firmware/mediatek/`：
  `WIFI_MT7922_patch_mcu_1_1_hdr.bin` + `WIFI_RAM_CODE_MT7922_1.bin`
  —— `package/kernel/mt76/Makefile:658-664`（包定义 `:269-272`，eval `:776`）。
- 驱动按 chip id 选固件名，`0x7922` 对应上面两个文件；PCI ID **0x0616 与 0x7922 都映射到
  MT7922 固件**，0x7961 映射 MT7921 —— `mt76@0936617` 的 `mt7921/pci.c` 设备表与 `mt792x.h`
  的 `MT7922_FIRMWARE_WM` / `MT7922_ROM_PATCH`（外部源码，版本号与
  `package/kernel/mt76/Makefile:11-12` 的 `PKG_SOURCE_DATE/VERSION` 一致）。
- MT7922 的 PCI 标识是 **14c3:0616**（`14c3:7922` 也出现在驱动表中）——外部核对：
  Ubuntu certified MT7922 页面标识 `14c3:0616`（见文末 URL）。
- **坑**：`package/firmware/linux-firmware/mediatek.mk:63-70` 里的 `mt7922bt-firmware`
  只有**蓝牙**固件；WiFi 固件只来自 `kmod-mt7922-firmware`，不要以为装了 linux-firmware 就有。

### 1.3 Kconfig 的 `select` 机制（为什么隐藏符号不需要手填）

`+@SYMBOL` 形式的依赖会被 `scripts/package-metadata.pl:160-221` 翻译成 Kconfig 的
`select SYMBOL`（`:182` 起 `if ($flags =~ /\+/)` → `$m="select"`；`:221` `$flags =~ /@/ or ...`
使符号保持原名、不加 `PACKAGE_` 前缀）。因此：

- `CONFIG_PACKAGE_kmod-mt7921e=y` ⇒ **select `DRIVER_11AX_SUPPORT`** ⇒ hostapd 编入
  `CONFIG_IEEE80211AX=y`（`hostapd/Makefile:88-90` + `:105-112` 的 `DRIVER_MAKEOPTS`；
  变体配置文件里 11ax 默认关闭：`hostapd/files/hostapd-full.config:171` 的 `#CONFIG_IEEE80211AX=y`）。
- 同一机制也 select `DRIVER_11AC_SUPPORT`（`package/kernel/mt76/Makefile:43`）与
  `KERNEL_PAGE_POOL`（`:44`）。`KERNEL_PAGE_POOL` 是 `def_bool n` 的隐藏符号
  （`config/Config-kernel.in:1362-1363`），置 y 后由
  `include/kernel-defaults.mk:118-119` 转成内核 `CONFIG_PAGE_POOL=y`
  （x86 内核配置本就有 `CONFIG_PAGE_POOL=y`：`target/linux/x86/config-6.18:339`）。
- PCI 支持：`@PCI_SUPPORT` 由 x86 的 `CONFIG_PCI=y`（`target/linux/x86/config-6.18:346`）
  经 `include/target.mk:322-324` 自动加入 target FEATURES。
- crypto 内核模块由 `kmod-mac80211` 自动拉取（`package/kernel/mac80211/Makefile:136`）：
  `kmod-crypto-cmac`、`kmod-crypto-ccm`、`kmod-crypto-gcm`（包定义分别见
  `package/kernel/linux/modules/crypto.mk:132-141`、`:105-114`、`:289-298`）。
  x86 通用内核配置里 AES/CCM/GCM 等核心算法本就 `=y`
  （`target/linux/generic/config-6.18:1145,1177,1253`），不存在“WPA2 装不成”的缺 crypto 风险。
- `kmod-nf-nathelper` **与无线无关**（NAT helper），只是 x86 曾经的 `DEFAULT_PACKAGES.tweak`
  里的一项且该 tweak 默认关闭（`include/target.mk:62-68`，`:114-115` 被注释掉），不需要选。

---

## 2. wpad 变体选择（理由 + 源码依据）

### 2.1 x86 默认没有任何 wpad/hostapd

- `target/linux/x86/Makefile:19-25` 的 `DEFAULT_PACKAGES` 只有有线网卡驱动、fdisk、automount 等，
  **不含 wpad**；全局默认包 `include/target.mk:21-35` 也没有。
- 因此不显式选一个 wpad（或 hostapd）变体，镜像里就没有 `/usr/sbin/hostapd`，
  LuCI 里会出现无线设备但 AP 起不来。

### 2.2 三个候选变体的源码差异

| 包 | VARIANT（hostapd/Makefile） | TLS 后端 | SAE(WPA3) | OWE | AP/MESH 编译项 | DPP/SUITEB192/EAP_PWD | 额外依赖 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `wpad-openssl` | `wpad-full-openssl`（`:302-307`） | openssl（`:115-117`） | y（`:116`） | y（`:125-127`） | y（同左） | y（同左） | `libopenssl` + `libopenssl-legacy`（`:103`） |
| `wpad-mbedtls` | `wpad-full-mbedtls`（`:320-325`） | mbedtls（`:145-147`） | y（`:146`） | y（`:155-157`） | y | y | `libmbedtls` |
| `wpad-basic-mbedtls` | `wpad-basic-mbedtls`（`:361-366`） | mbedtls（`:145-147`） | y（`:146`） | y（`:149-151`） | **n**（无 `CONFIG_AP/MESH`） | **n** | `libmbedtls` |

补充依据：

- `DRIVER_11AX_SUPPORT` 是 `select WPA_MBO_SUPPORT`（`hostapd/Config.in:38-41`），MBO 默认 y
  （`hostapd/Config.in:57-60`）；11AC/11AX/11BE 都是无 prompt 的隐藏 bool（`hostapd/Config.in:34-45`）。
- wpad 变体 `PROVIDES:=hostapd wpa-supplicant` 且互相 `CONFLICTS`（`hostapd/Makefile:276-289`），
  **只能选一个**；同时选两个会在构建时报冲突。
- `DEFAULT_VARIANT` 只标在 `hostapd-basic-mbedtls`（`:258`）和 `eapol-test`（`:554`）上，
  **wpad 系列没有默认变体**，x86 也不会自动带入任何一个。

### 2.3 结论：选 `CONFIG_PACKAGE_wpad-openssl=y`

理由：

1. **full 变体才有完整 AP 特性集**：`CONFIG_AP`/`CONFIG_MESH`/`OWE`/`SUITEB192`/`EAP_PWD`/`DPP`/`DPP2`
   （`hostapd/Makefile:125-127`），6GHz AP + WPA3、OWE transition、企业级 EAP 都覆盖。
2. **openssl 后端对 WPA-Enterprise/EAP-TLS 更完整**（mbedtls 变体缺少部分 EAP 方法/证书链能力），
   且 x86 空间足够，多出的 `libopenssl(+legacy)`（`hostapd/Makefile:103`）不是问题。
3. **符合 ImmortalWrt 有线 WiFi target 的惯例**：多个 target 的 `DEFAULT_PACKAGES` 都写死
   `wpad-openssl`，例如 `target/linux/ath79/generic/target.mk:3`、
   `target/linux/mediatek/filogic/target.mk:5`。
4. 若极端在意镜像体积可退而用 `wpad-basic-mbedtls`（SAE/OWE 已够 6GHz WPA3），
   但会失去 DPP、Mesh、企业级 EAP 以及 wpa_supplicant 客户端能力——「高大全」场景不建议。

---

## 3. 无线用户态：wifi-scripts / iwinfo / iw / wireless-regdb

### 3.1 识别方式：**没有白名单**，MT7922 自动识别

- `wifi-scripts` 包：`package/network/config/wifi-scripts/Makefile:20-26`；
  `WIFI_SCRIPTS_UCODE` 默认 y（`wifi-scripts/Config.in:1-3`），装 ucode 版脚本
  （`wifi-scripts/Makefile:45-54`，`:48-50` 覆盖 `files-ucode/`）。
- 运行时 `wifi config` 的流程：先跑 `wifi-detect.uc` 探测 phy，再由
  `/lib/wifi/mac80211.uc | uci -q batch` 生成 `/etc/config/wireless`
  —— `wifi-scripts/files/sbin/wifi:64-76`。
- 探测完全基于 nl80211 与 `/sys`，**不匹配任何网卡型号/白名单**：
  `wifi-scripts/files/usr/share/hostap/wifi-detect.uc:88-141`（`GET_WIPHY` dump；按频率判定
  `>5900 → 6G`、`>4000 → 5G`、`>2000 → 2G`，`:131-140`）。
- 自动生成 wifi-device 段：`wifi-scripts/files/lib/wifi/mac80211.uc:55-146`；
  多 radio 的 phy 会按 radio 拆成 `radio0/radio1...` 并写 `radio='N'`（`:60-64`、`:121-122`），
  band 取该 radio 支持的首个频段（`:69`），channel/htmode 由能力推导（`:75-87`），
  radio 数量>1 时写 `option radio`（schema 见下）。
- wifi-device 支持 `band` 枚举含 `6g`、`phy`、`radio`（“multi-radio PHYs 的 radio 索引”）、
  `country/country_code`、`he_6ghz_reg_pwr_type`
  —— `wifi-scripts/files-ucode/usr/share/schema/wireless.wifi-device.json:44-53`、`:588-606`、
  `:121-132`、`:311-317`。

### 3.2 iwinfo / iw

- 默认 ucode 模式下，**legacy `iwinfo` 包不可选**：`iwinfo` 的依赖为
  `+@!WIFI_SCRIPTS_UCODE:libiwinfo`（`package/network/utils/iwinfo/Makefile:62-67`），
  且 `WIFI_SCRIPTS_UCODE` 打开时它的 install 为空（`:114-123`）。
- `/usr/bin/iwinfo` 由 wifi-scripts 的 ucode 版提供：
  `wifi-scripts/files-ucode/usr/bin/iwinfo:1-7`（`#!/usr/bin/ucode` + `import * as iwinfo`）。
- LuCI 的无线信息/扫描走 rpcd 的 iwinfo ubus 对象：`package/system/rpcd/Makefile:106`
  （`rpcd-mod-iwinfo`，依赖 `libiwinfo`）——建议显式装 `CONFIG_PACKAGE_rpcd-mod-iwinfo=y`
  （OpenWrt 官方 LuCI 镜像同样包含它，外部核对其 `config.buildinfo`，见文末 URL）。
- `iw` 由 `kmod-cfg80211` 自动依赖安装（`package/kernel/mac80211/Makefile:107`）；
  脚本运行时会调用 `iw reg set <country>`（`wifi-scripts/files-ucode/lib/netifd/wireless/mac80211.sh:73-76`），
  所以镜像里必须有 `iw`（自动满足）。`iw` 包默认 tiny 变体、`iw-full` 为另一变体
  （`package/network/utils/iw/Makefile:27-46`，`iw` 为 `DEFAULT_VARIANT`）。
- 硬件名字表没收录 MT7922：`wifi-scripts/files-ucode/usr/share/wifi_devices.json` 的 PCI 段
  （`:182-194`）没有 `14c3:0616`（MT7922），也没有 `14c3:7961`（MT7921e）——`iwinfo` 匹配不到时
  回退为 `Generic MAC80211`（`wifi-scripts/files-ucode/usr/share/ucode/iwinfo.uc:55-81`）。
  **纯显示问题，不影响识别/AP**；要显示成 “MediaTek MT7922” 需自行在该 json 的 pci 段加一行。

### 3.3 wireless-regdb

- 包在本仓库：`package/firmware/wireless-regdb/Makefile:3-32`，版本 `2026.09.03`
  （`:4`），安装 `/lib/firmware/regulatory.db`（`:29-32`）。
- 由 `kmod-cfg80211` 自动依赖（`package/kernel/mac80211/Makefile:107`），
  显式写 `CONFIG_PACKAGE_wireless-regdb=y` 只是让 defconfig 更自解释。

### 3.4 LuCI 侧的验证边界（风险）

- 本仓库**没有 feeds**（`feeds.conf.default` 只有源地址；工作区无 `feeds/` 目录、无 `package/luci`），
  因此 `luci-mod-network` 等 feed 包对 `iwinfo/wpad/wifi-scripts` 的具体依赖**无法在本仓库源码内核实**。
- 本仓库能保证的是底层链路：`wpad` + `wifi-scripts` + `netifd` + `iw` + `wireless-regdb`
  + `rpcd-mod-iwinfo` + ucode `iwinfo`。LuCI 的无线页面在 25.x 里由 `luci-mod-network` 提供，
  依赖 ubus `network.wireless`（netifd/wifi-scripts）与 `iwinfo` ubus（rpcd-mod-iwinfo）。
  上机验证时如 LuCI 无线页报 “iwinfo not found”，优先检查 `rpcd-mod-iwinfo` 是否进镜像。

---

## 4. x86/64 镜像与分区参数

### 4.1 平台/profile 符号

- `target/linux/x86/Makefile:7-15`：`ARCH:=i386`、`BOARD:=x86`、
  `FEATURES:=squashfs ext4 legacy-sdcard qcow2 vdi vmdk vhdx pcmcia targz fpu boot-part rootfs-part`
  （`:10`）、`SUBTARGETS:=64 generic legacy geode`（`:11`）、`KERNEL_PATCHVER:=6.18`（`:13`）、
  `KERNELNAME:=bzImage`（`:15`）。
- `target/linux/x86/64/target.mk:1-6`（`ARCH:=x86_64`）；`target/linux/x86/image/64.mk:1-9`
  定义唯一设备 `Device/generic`（`DEVICE_MODEL := x86/64`，`GRUB2_VARIANT := generic`）。
- profile 符号推导：`scripts/target-metadata.pl:238,257` 生成
  `TARGET_<conf>_<profile id>`；`include/image.mk:887` 把 device 的 profile id 写成
  `DEVICE_$(1)`，`scripts/metadata.pm:31-35` 把 `x86/64` 变成 `x86_64`。
  因此单 profile 构建用 **`CONFIG_TARGET_x86_64_DEVICE_generic=y`**；
  若 `CONFIG_TARGET_MULTI_PROFILE=y`（buildbot 风格）则改用
  `CONFIG_TARGET_DEVICE_x86_64_DEVICE_generic=y`（`scripts/target-metadata.pl:316`）。
- 注意：**`target/linux/x86` 下没有 `Config-images.in`**，镜像选项在顶层
  `config/Config-images.in`（`:232-384`），镜像规则在 `target/linux/x86/image/Makefile`。

### 4.2 EFI + BIOS 双启动

- `CONFIG_GRUB_IMAGES` 默认 y（`config/Config-images.in:232-238`）→ 生成 BIOS 的
  `combined.img(.gz)`；`CONFIG_GRUB_EFI_IMAGES` 默认 y（`:240-250`）→ 生成
  `combined-efi.img(.gz)`，并自动 `select PACKAGE_grub2-efi`、`grub2-bios-setup`、
  `kmod-fs-vfat`（`:244-249`）。
- 组图逻辑：`target/linux/x86/image/Makefile:37-53`（`Build/combined`）：
  EFI 时额外放 `/efi/boot/bootx64.efi`（`:43-46`），kernel 分区用 FAT 格式化，
  BIOS 时 kernel 分区是 ext4 带 grub core.img（`scripts/gen_image_generic.sh:52-58`）。
- 镜像清单：`target/linux/x86/image/Makefile:129-155`：
  BIOS = `IMAGE/combined.img`（`:131-136` 及 qcow2/vdi/vmdk/vhdx），
  EFI = `IMAGE/combined-efi.img`（`:140-145`），
  gzip 开关按 `CONFIG_TARGET_IMAGES_GZIP`（`:147-155`，默认 y 见 `config/Config-images.in:344-347`）。
- ISO 默认**不**生成：`ISO_IMAGES` 只在 BUILDBOT 下默认 y（`config/Config-images.in:289-293`）；
  若手动开启，产物名是 `...-generic-image.iso` / `...-generic-image-efi.iso`
  （`target/linux/x86/image/Makefile:130,139`；命名规则 `include/image.mk:809-821`）。

### 4.3 分区大小

- kernel 分区：`CONFIG_TARGET_KERNEL_PARTSIZE` 默认 **32 MiB**（`config/Config-images.in:354-361`），
  x86 有 `boot-part` feature（`target/linux/x86/Makefile:10` →
  `scripts/target-metadata.pl:13` select `USES_BOOT_PART`），32 MiB 足够放 bzImage+grub。
- rootfs 分区：`CONFIG_TARGET_ROOTFS_PARTSIZE` 默认 **160 MiB**（非 buildbot；BUILDBOT 为 300）
  —— `config/Config-images.in:363-369`；该值以 MiB 为单位传给
  `scripts/gen_image_generic.sh`（`target/linux/x86/image/Makefile:50-52`），
  脚本 `dd` 填充到整块 rootfs 分区（`scripts/gen_image_generic.sh:49-50`）；
  squashfs 镜像的剩余空间由 fstools 首次启动时做 overlay 使用。
- **建议 `CONFIG_TARGET_ROOTFS_PARTSIZE=2048`**：
  - 「高大全」基线镜像 BleachWrt plus 的 `...squashfs-combined-efi.img.gz` 就有
    475.75 MB（`.build/parity-src.md:6`）——默认 160 MiB 明显不够；
  - squashfs 固定部分 + overlay（装插件、Docker 镜像、配置备份）合计，1 GiB 偏紧，
    2 GiB 舒适；跑 Docker/大量插件建议 2048–4096。
- `FEATURES` 含 `ext4`（`target/linux/x86/Makefile:10`）→ `USES_EXT4` 为 y
  （`scripts/target-metadata.pl:20`）→ `TARGET_ROOTFS_EXT4FS` 默认 y
  （`config/Config-images.in:108-112`），所以默认会同时生成 squashfs 与 ext4 两套镜像；
  只需 squashfs 可在 defconfig 里显式 `# CONFIG_TARGET_ROOTFS_EXT4FS is not set`（本任务不建议）。

### 4.4 最终镜像文件名

镜像前缀：`VERSION_DIST_SANITIZED`（默认 `immortalwrt`，`include/version.mk:38-40`）
`- <版本号> - <board>-<subtarget> - <device> - <文件系统> - <image 名>`
（`include/image.mk:47-53`、`:466-468`）。
版本号只有在 `VERSIONOPT`（默认 n，`package/base-files/image-config.in:161-163`）里打开
`CONFIG_VERSION_FILENAMES`（默认 y，`:272-279`）才会写进文件名，本仓库默认构建名不带版本号。
（外部核对：OpenWrt 24.10.4 官方 x86/64 目录即 `openwrt-24.10.4-x86-64-generic-squashfs-combined-efi.img.gz` 这种形态；
本仓库发行名默认 ImmortalWrt → `immortalwrt-...`。）

默认（`CONFIG_TARGET_ROOTFS_PARTSIZE=2048`、GZIP=y、不带 VERSIONOPT）产出：

```
bin/targets/x86/64/immortalwrt-x86-64-generic-squashfs-combined-efi.img.gz   ← EFI 启动（推荐）
bin/targets/x86/64/immortalwrt-x86-64-generic-squashfs-combined.img.gz       ← 传统 BIOS 启动
bin/targets/x86/64/immortalwrt-x86-64-generic-squashfs-rootfs.img.gz
bin/targets/x86/64/immortalwrt-x86-64-generic-kernel.bin
# 默认还会并发生成 ext4 系列（同前缀 -ext4-...）
```

---

## 5. 6GHz / AP 相关限制与已知坑

### 5.1 6GHz 只允许 WPA3-SAE / OWE

`wifi-scripts/files-ucode/usr/share/ucode/wifi/iface.uc:12-27` 的 `encryption_6g` 映射表：
`psk2/psk-mixed → sae`、`wpa2 → wpa3`、`none → owe`，注释引用
IEEE 802.11-2024 12.12.2 与 WPA3 Spec v3.5 11.2（`:12-15`）。
**所以“6G 用 WPA2（纯 PSK）”做不到**；2.4G/5G 可以 WPA2 或 WPA2/WPA3 混合（`psk-sae`）。
WPA3 需要 hostapd 的 `CONFIG_SAE`——三个 TLS 变体都带（`hostapd/Makefile:116,131,146`）。

### 5.2 6GHz AP 必须 HE（11ax），且脚本会自动关掉 ac

- hostapd 11ax 编译项仅当 `CONFIG_DRIVER_11AX_SUPPORT` 才打开（`hostapd/Makefile:88-90`），
  该符号被 `kmod-mt7921e` 自动 select（见 1.3）。
- 运行时脚本在 htmode 为 `HE*/EHT*` 时写 `ieee80211ax=1`（`wifi/hostapd.uc:384-389`）；
  6G 时强制 `ieee80211ac=0`、写 `op_class` 与 `he_6ghz_reg_pwr_type`
  （`wifi/hostapd.uc:260-305`、`:403-406`）。
- 自动生成的 htmode 上限 80 MHz（`files/lib/wifi/mac80211.uc:77-87`），
  想跑 HE160 需要在 LuCI 里手动改；MT7922 支持 5G/6G 160MHz
  （mt76@0936617 `mt7921/main.c` 中对 `is_mt7922` 才置 160MHz 能力位）。
- 6GHz 需要 `he_6ghz_reg_pwr_type`（LPI/SP/VLP，schema
  `wireless.wifi-device.json:311-317`，hostapd 侧 `wifi/hostapd.uc:403-406,561-563`）；
  驱动按 vif 的 power_type 下发（mt76@0936617 `mt7921/main.c` 的
  `mt7921_regd_set_6ghz_power_type`）。

### 5.3 必须设置 country（否则 6GHz 直接没有可用信道）

- 自动配置给 6G 的默认 country 是 `'00'`（world），加密默认 owe
  —— `wifi-scripts/files/lib/wifi/mac80211.uc:103-108`；`country='00'` 下 6G 不可用。
- 正确做法：LuCI → 网络/无线 → 设备配置里把“国家代码”改成允许 6GHz 的国家码
  （美国等；**中国大陆是否开放 6GHz 需按 wireless-regdb 2026.09.03 与当地法规核实**），
  等价于 `/etc/config/wireless` 里 `option country 'US'`（字段见
  `wireless.wifi-device.json:121-132`）。
- 设置后：netifd 侧执行 `iw reg set <cc>`（`wifi-scripts/files-ucode/lib/netifd/wireless/mac80211.sh:73-76`），
  hostapd 侧写 `country_code`/`ieee80211d`（`wifi/hostapd.uc:68-85`、`:520`）。
- 6GHz 是否可用还取决于卡的 EEPROM/regdb 组合；OpenWrt 上“6GHz + country”问题可参考
  外部 issue（见文末 URL）。

### 5.4 **驱动只允许 1 个 AP 接口**（三频同时 AP 不可行）

本仓库的 mt76 版本固定在 `package/kernel/mt76/Makefile:11-12`
（`PKG_SOURCE_DATE:=2026-10-28`, `PKG_SOURCE_VERSION:=0936617dc5...`）。该版本
`mt792x_core.c` 中：

- `if_limits[]`：STATION 最多 `MT792x_MAX_INTERFACES(=4)`，**AP 最多 1**；
- `if_comb`：`max_interfaces=4`，**`num_different_channels=1`**；
- 若固件带 `MT792x_FW_CAP_CNM`，改用 `if_comb_chanctx_base`：
  `num_different_channels=2`（MCC，AP 仍最多 1 个）。

含义：

- **同一时刻只能起 1 个 AP BSS**（因此“2.4G、5G、6G 各开一个 AP 同时工作”与驱动上报的
  interface combination 冲突；需要多频段同时 AP 时只能用多张卡/另一个 AP）。
- CNM 固件下可 AP + STA 跨信道并发（差旅/中继场景），但仍是 1 个 AP。
- 单频段上的多 SSID（多个 wifi-iface 指向同一 device）也会受 AP 接口上限影响，
  **必须以实机 `iw phy` 输出的 “valid interface combinations” 为准**再决定能否多 SSID。
- 外部经验佐证（x86 + MT7921E/MT7922 可开 AP，2.4/5/6GHz“或”）：见文末 right.com.cn 帖子。

### 5.5 其他坑

1. **ASPM/掉线**：`mt7921e` 有 `disable_aspm` 模块参数（mt76@0936617 `mt7921/pci.c`）；
   实机若出现频繁掉线/扫描异常，可加模块选项 `options mt7921e disable_aspm=1`
   （`/etc/modules.d/`，不在本任务写权限内）或在 GRUB 加 `pcie_aspm=off`
   （`CONFIG_GRUB_BOOTOPTS`，`config/Config-images.in:268-272`）。
   外部讨论见文末 linux-wireless 邮件列表。
2. **名字显示**：MT7922 (`14c3:0616`) 不在 `wifi_devices.json` PCI 名表
   （`wifi-scripts/files-ucode/usr/share/wifi_devices.json:182-194`），
   LuCI/iwinfo 会显示 `Generic MAC80211`（`iwinfo.uc:55-81`）——不影响功能。
3. **BT 是另一套固件**：MT7922 的蓝牙固件在 linux-firmware 的 `mt7922bt-firmware`
   （`package/firmware/linux-firmware/mediatek.mk:63-70`），要蓝牙需另加 `kmod-bluetooth`
   等，与 WiFi AP 无关。
4. **不要**用 `kmod-mt7925e`/`kmod-mt7915e` 顶替：`mt7925e` 是 MT7925/7927 的驱动
   （`package/kernel/mt76/Makefile:367-395`），和 MT7922 无关。
5. **构建位置**：`.build/prep.sh:20-26` 的做法是在 WSL 内重新 `git clone` 到 `/root/immortalwrt`
   再编译；本任务写的 `.build/wifi/*` 在宿主仓库里，**若编译在 WSL 的 clone 内进行，
   需要把 config 片段同样复制过去**（或直接在本仓库根 `.config` 追加）。

---

## 6. 上机验证清单

```sh
# 1) 驱动与固件加载
dmesg | grep -iE 'mt7921|mt7922|firmware'
lsmod | grep -E 'mt7921e|mt76'
#   期望看到 "ASIC revision: 79220010" 之类；失败会打印 firmware 加载错误

# 2) 频段与接口组合（重点看 6GHz 段与 valid interface combinations）
iw phy | sed -n '/Band 4/,/Band 5/p'      # 6GHz 频段是否存在
iw phy | sed -n '/valid interface combinations/,/^[^ ]/p'

# 3) 自动生成无线配置（或直接 LuCI 里保存）
wifi config
uci show wireless | grep -E 'band|country|htmode|radio'

# 4) 6GHz AP 试点
#    - device: band=6g, country=允许 6GHz 的国家码, htmode=HE80/HE160
#    - iface : mode=ap, encryption=sae（或 owe）
wifi reload
ubus call network.wireless status | grep -E 'band|up|pending'
iw reg get

# 5) hostapd 排障
logread -e hostapd
```

---

## 7. 参考来源

### 7.1 本仓库源码（`文件:行号` 已在上文逐条标注）

- `package/kernel/mt76/Makefile`
- `package/kernel/mac80211/Makefile`
- `package/network/services/hostapd/Makefile`、`Config.in`、`files/hostapd-full.config`
- `package/network/config/wifi-scripts/Makefile`、`Config.in`、
  `files/sbin/wifi`、`files/lib/wifi/mac80211.uc`、`files/usr/share/hostap/wifi-detect.uc`、
  `files-ucode/lib/netifd/wireless/mac80211.sh`、`files-ucode/usr/share/ucode/wifi/{iface,hostapd}.uc`、
  `files-ucode/usr/share/ucode/iwinfo.uc`、`files-ucode/usr/share/wifi_devices.json`、
  `files-ucode/usr/share/schema/wireless.wifi-device.json`
- `package/network/utils/{iw,iwinfo}/Makefile`
- `package/firmware/wireless-regdb/Makefile`
- `package/firmware/linux-firmware/mediatek.mk`
- `package/system/rpcd/Makefile`
- `package/kernel/linux/modules/crypto.mk`
- `target/linux/x86/{Makefile,64/target.mk,image/64.mk,image/Makefile,config-6.18}`
- `config/Config-images.in`、`config/Config-kernel.in`
- `include/{target.mk,image.mk,kernel-defaults.mk,version.mk}`
- `scripts/{target-metadata.pl,package-metadata.pl,metadata.pm,gen_image_generic.sh}`
- `package/base-files/image-config.in`
- `.build/parity-src.md`（BleachWrt plus 基线镜像信息）

### 7.2 外部资料（仅作佐证/参考，非本仓库内容）

- mt76 驱动源码（与本仓库 `PKG_SOURCE_VERSION` 完全一致）：
  - `mt792x_core.c`（iface combinations：AP 上限 1、num_different_channels）：
    <https://github.com/openwrt/mt76/blob/0936617dc529ff9da0385221d3fa6de732231177/mt792x_core.c>
  - `mt7921/pci.c`（PCI ID 0x0616/0x7922、`disable_aspm` 模块参数、MT7922 固件声明）：
    <https://github.com/openwrt/mt76/blob/0936617dc529ff9da0385221d3fa6de732231177/mt7921/pci.c>
  - `mt7921/main.c`（6GHz HE caps、6GHz power type、AP start/stop ops）：
    <https://github.com/openwrt/mt76/blob/0936617dc529ff9da0385221d3fa6de732231177/mt7921/main.c>
  - `mt792x.h`（`MT7922_FIRMWARE_WM` / `MT7922_ROM_PATCH`、`MT792x_MAX_INTERFACES`）：
    <https://github.com/openwrt/mt76/blob/0936617dc529ff9da0385221d3fa6de732231177/mt792x.h>
- MT7922 PCI 标识 `14c3:0616`（Ubuntu certified 组件页）：
  <https://ubuntu.com/certified/component/990>
- OpenWrt 24.10.4 x86/64 镜像命名对照（`openwrt-24.10.4-x86-64-generic-squashfs-combined-efi.img.gz`）：
  <https://downloads.openwrt.org/releases/24.10.4/targets/x86/64/>
- OpenWrt 官方镜像的 LuCI 依赖样例（含 `CONFIG_PACKAGE_rpcd-mod-iwinfo=y`、`libiwinfo`）：
  <https://downloads.openwrt.org/releases/24.10.4/targets/x86/64/config.buildinfo>
- MT7922 稳定性/ASPM 讨论（linux-wireless 邮件列表，提到 `mt7921e` 的 `disable_aspm`）：
  <https://lore-kernel.gnuweeb.org/linux-wireless/2f82fb71-9ecd-4370-9468-92bc987f72c9@gmail.com/T/>
- x86 + MT7921E/MT7922 可开 AP、2.4/5/6GHz 可选（恩山论坛帖）：
  <https://www.right.com.cn/forum/archiver/tid-5341741.html>
- OpenWrt 6GHz/country 相关问题（6GHz AP 与监管域）：
  <https://github.com/openwrt/openwrt/issues/18079>

---

## 8. 风险与未验证项

| # | 风险 | 说明 / 建议 |
| :--- | :--- | :--- |
| 1 | **单 AP 接口限制** | 来自上游 mt76 `if_limits`（AP max=1）；三频同时 AP 不可行、多 SSID 可能受限，需实机 `iw phy` 验证。若用户要求三频同时 AP，应改用多张网卡或专用 AP 硬件。 |
| 2 | **6GHz 法规/国家码** | 默认 `country='00'` 下 6GHz 不可用；CN 是否允许 6GHz 需按当地法规与 wireless-regdb 核实（本仓库 regdb 版本 2026.09.03）。 |
| 3 | **LuCI feed 依赖未能在本仓库验证** | 工作区无 feeds；`luci-mod-network` 等需要 feeds update 后才能确认。建议镜像里同时保留 `rpcd-mod-iwinfo`。 |
| 4 | **wpad 唯一性** | `wpad-*`/`hostapd-*` 互斥；若 feeds 里其它插件又拉别的变体，构建会冲突。 |
| 5 | **构建路径** | WSL 内 `prep.sh` 是重新 clone 编译；`.build/wifi/config-wifi.conf` 需复制到实际编译树再拼接。 |
| 6 | **镜像体积** | `ROOTFS_PARTSIZE=2048` 会让 `.img` 变 2 GiB+（gzip 后主要是真实内容）；若目标盘小需下调。 |
| 7 | **名字显示** | `wifi_devices.json` 缺 14c3:0616 → 显示 Generic MAC80211（cosmetic）。 |
