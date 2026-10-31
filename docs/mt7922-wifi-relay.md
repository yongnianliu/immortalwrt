# MT7922 单卡做「AP + 连别人家 Wi-Fi（中继）」：实测结论与崩溃恢复

> 本文基于 **x86 / R86S（MT7922, `14c3:0616`）+ 本仓库固件（内核 6.18.55，mt76 2026.10.28）**
> 的实机实测，不是推测。
>
> **一句话结论：这块卡在本驱动/固件版本下不能做 AP+STA 中继。**
> 一旦把第二个（STA）接口拉起来，MT7922 的 MCU 立刻挂死，只能**物理断电**才救得回来。
> 想「盒子发 Wi-Fi」，请走有线 WAN；想「盒子自己上网」，请只用 STA 模式；两个都要，加第二张网卡。

---

## 1. 实测记录（可复现）

### 1.1 中继配置本身是"合规"的

| 项 | 值 |
| --- | --- |
| 上游 `Xiaomi_LYN_5G` | **ch40（5200 MHz）/ 80 MHz / WPA2-PSK(AES)**，信号 -60 dBm |
| 本机 AP | ch40 / HE80 / center 42（与上游同信道同带宽） |
| 本机 STA | `psk2` + 正确密码（同信道 SCC 组合） |

按驱动上报的 `valid interface combinations`，这已经是唯一合法的 AP+STA 组合
（`#{ managed,P2P-client }<=2, #{ AP }<=1, #channels<=1`），**配置没有任何问题**。

### 1.2 结果：拉起 STA 接口 → MCU 挂死

```
netifd: wifi-scripts: Preparing interface: phy0-sta0
wpa_supplicant: Failed to bring up device phy0-sta0: RTNETLINK answers: Operation timed out
dmesg: mt7921e 0000:04:00.0: Message 00020000x (seq N) timeout
dmesg: mt7921e 0000:04:00.0: Failed to get patch semaphore
dmesg: mt7921e 0000:04:00.0: MCU is not ready for firmware download
dmesg: mt7921e 0000:04:00.0: chip reset failed     （之后每 ~5s 循环一次，永不恢复）
```

现象组合（用户视角）：

1. **LuCI 管理页面变得极慢**——无线相关页面要读 `iwinfo`/`station dump`，每条都要等 MCU 超时；
2. **「已连接站点」永远空**——AP 接口即使存在也没有真正在信道上（`iwinfo` 显示
   `Channel: 0 (unknown)`），自然没有站点；
3. 内核日志被 `Loading firmware patch ... Failed to get patch semaphore ... chip reset failed`
   每 5 秒刷屏，`load average` 常驻 1.5~4；
4. 反复 `wifi reload` 也没用，驱动自己救不回来。

> 另一条更早的线索：`if_connecting` 失败前会出现 `Message 00020003 (seq 3) timeout`，
> 也就是 MediaTek 上游补丁所说的「SoftAP 没有 NoA 机制、不允许跨信道」的那种崩法，
> 但在本卡上**同信道也一样崩**，说明是这版固件对 AP+STA 并发本身支持不完整。

---

## 2. 崩溃后怎么救（重要，别瞎重启）

| 手段 | 结果 |
| --- | --- |
| `wifi reload` / `wifi down`+`up` | ❌ 继续刷超时 |
| `rmmod mt7921e` | ❌ **卡死在模块卸载**，接着整机重启也会卡在同一处 |
| `reboot`（热重启） | ❌ 起来后变成 `mt7921e: driver own failed` + `probe failed with error -5`，**驱动连初始化都过不去** |
| PCI `remove` + `rescan` 重新枚举 | ❌ 设备能重新枚举、BAR 重新分配，但仍是 `driver own failed` |
| **物理断电（拔电源 / 按住电源键 10s 再上电）** | ✅ **唯一有效**。冷启动后 `ASIC revision: 79220010`、固件正常加载、AP 正常上信道 |

结论：**MT7921/MT7922 的固件崩溃是"粘住"的，只有给芯片断电才能复位**；
`reboot`、`sysrq b/o`（在驱动卡死时也会被 shutdown hook 挡住）都不行。

如果需要远程让机器进入"可断电"状态，注意 `poweroff` 也可能被卡死的驱动钩子挡住，
此时只能人工按电源键。

---

## 3. 顺手要做的硬化：关掉 PCIe ASPM

MT7921/MT7922 在 **ASPM L0s/L1 开启**时非常容易出现
`Failed to get patch semaphore` / `MCU is not ready` / `chip reset failed` 这类固件加载失败。
本机 BIOS 默认把这条链路设成 `ASPM L0s L1 Enabled`。

三种做法（推荐第 1 种，本仓库镜像已默认）：

1. **内核启动参数 `pcie_aspm.policy=performance`**（= 关闭 ASPM）
   本仓库 `configs/x86_64-mt7922-plus.config` 已设
   `CONFIG_GRUB_BOOTOPTS="pcie_aspm.policy=performance"`。已装机的可手改：
   ```sh
   sed -i 's|rootwait|rootwait pcie_aspm.policy=performance|' /boot/grub/grub.cfg
   ```
   注意：**`pcie_aspm=off` 不等于关闭 ASPM**——它只是让内核"不去改" BIOS 已经开启的 ASPM，
   `lspci -vv` 里仍然是 `ASPM L0s L1 Enabled`，需要在驱动 probe 前就生效才行。
   （而且 `pcie_aspm=off` 时向 `/sys/module/pcie_aspm/parameters/policy` 写入会返回 `EPERM`。）
2. **运行时清掉链路 ASPM 位**（立即生效，适合已开机的机器）：
   ```sh
   D=0000:04:00.0            # 用 lspci -nn | grep 14c3 确认
   cur=$(setpci -s $D CAP_EXP+10.w)
   setpci -s $D CAP_EXP+10.w=$(printf '%04x' $((0x$cur & 0xfffc)))
   lspci -vv -s $D | grep LnkCtl:   # 应显示 ASPM Disabled
   ```
   放到 `/etc/rc.local` 里可以每次开机执行。
3. `mt7921e` 的模块参数 `disable_aspm=1`：**实测在 OpenWrt 的 kmodloader 下写
   `/etc/modules.d/` 不生效**（参数仍是 `N`），别在这上面浪费时间。

---

## 4. 那到底怎么配才对

### 4.1 方案 A（推荐）：有线 WAN + MT7922 纯 AP

```sh
# 只做 5G AP（单卡同一时刻只能一个频段、一个 AP）
uci set wireless.radio0.disabled='0'
uci set wireless.radio0.band='5g'
uci set wireless.radio0.channel='149'      # 36/40/44/48 或 149/153/157/161；别用 52-64/100-140(DFS)
uci set wireless.radio0.htmode='HE80'
uci set wireless.radio0.country='CN'

# 节名用 `uci show wireless` 确认（一般是 default_radio0）
uci set wireless.default_radio0.ssid='ImmortalWrt'
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.key='换成你的密码'
uci commit wireless && wifi reload
```

`iwinfo` 里应看到 `Channel: 149 (5.745 GHz)`（不是 `Channel: 0`），
`iw dev` 里应看到 `channel 149 (5745 MHz), width: 80 MHz`。
选信道时和邻居错开：先 `iw dev phy0-ap0 scan` 看看别人用哪个，别和家里主路由同信道。

### 4.2 方案 B：只用 STA 模式（盒子自己上网，不做 AP）

```sh
uci set wireless.default_radio0.disabled='1'     # 关掉 AP
uci set wireless.radio0.channel='40'             # 上游信道（扫描确认）
uci set wireless.radio0.htmode='HE80'
uci set wireless.wifinet1.mode='sta'
uci set wireless.wifinet1.network='wwan'
uci set wireless.wifinet1.ssid='Xiaomi_LYN_5G'
uci set wireless.wifinet1.encryption='psk2'      # 上游是 WPA2-PSK(AES) 就写 psk2
uci set wireless.wifinet1.key='上游WiFi密码'
uci set wireless.wifinet1.disabled='0'
uci commit wireless && wifi reload
```

单 vif 的 STA 是能稳定工作的；盒子通过 `wwan`（DHCP）拿到地址后，
LAN 口接的设备就能上网（`wwan` 已在 `wan` 防火墙区、开了 masq）。
但**盒子自己就不发 Wi-Fi 了**，无线覆盖靠家里主路由。

### 4.3 方案 C：加第二张网卡

- USB 无线网卡（`kmod-rtw88` / `kmod-88XXau` / `kmod-mt7921u` 等）或第二张 PCIe 卡；
- 一张 STA 连家里、一张 AP 发 Wi-Fi，两条独立射频、独立信道，互不干扰；
- 这是唯一能「无线中继 + 双频 + 满速」的硬件级解法。

---

## 5. 相关参数速查

| 项 | 值 |
| --- | --- |
| 用户态看到的接口 | `phy0-ap0`（AP）、`phy0-sta0`（STA） |
| `iw dev phy0-ap0 info` | 正常应显示 `channel 149 (5745 MHz), width: 80 MHz` |
| 驱动 `valid interface combinations` | `#{ managed,P2P-client }<=2, #{ AP }<=1, #{ P2P-device }<=1, total<=3, #channels<=1` |
| 健康标志 | `ASIC revision: 79220010` + `WM Firmware Version` + 无 `chip reset failed` |
| 挂死标志 | `Failed to get patch semaphore` / `MCU is not ready for firmware download` / `chip reset failed` / `iwinfo` 显示 `Channel: 0` |
| 恢复 | **物理断电 20 秒再上电** |

---

## 6. 参考

- MediaTek 上游补丁（限制 SoftAP+STA 同信道）：
  <https://lore.kernel.org/all/20250619112005.2071110-1-mingyen.hsieh@mediatek.com/>
- mt76 源码（与本固件 `0936617d` 一致）：
  <https://github.com/openwrt/mt76/blob/0936617dc529ff9da0385221d3fa6de732231177/mt792x_core.c>
- 本仓库实证笔记：[`mt7922-notes.md`](mt7922-notes.md) ·
  完整使用说明：[`x86_64-mt7922-plus.md`](x86_64-mt7922-plus.md)
