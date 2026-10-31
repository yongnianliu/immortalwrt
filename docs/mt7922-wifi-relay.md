# MT7922 单卡「AP + 连别人家 Wi-Fi（中继）」为什么会卡 & 怎么修

> 症状对照：**无线 → 无线概况**里给 `radio0` 加了「客户端（Client / STA）」去连家里的
> `Xiaomi_LYN_5G`，之后出现 ①「已连接站点」永远空、② LuCI 管理网页卡到几乎打不开、
> ③ 客户端状态显示「无线未关联」。
>
> 这不是固件编坏了，是 **MT7922 只有一套射频**这个硬约束 + 你的配置把 AP 钉死在了 ch48。

---

## 0. 三句话结论

1. MT7922（mt7921e 驱动）**同一时刻只能待在一个信道上**。AP 和 STA 想同时工作，就必须
   **同频段、同信道、（同或更窄）带宽**；跨信道并发被驱动直接禁掉了。
2. 你把 `radio0` 钉在 **5GHz / ch48 / 80MHz**，而家里的 `Xiaomi_LYN_5G` 只要不在 ch48
   （或者带宽不同），STA 就**永远关联不上**（截图正是「无线未关联」）。后果是 wpa_supplicant
   不停扫描重试，射频一直被「借去」扫描 → AP 的 beacon 发不出去 → **客户端掉线、站点列表空、
   LuCI 无线页面卡住**。
3. 想要稳：**有线做 WAN、MT7922 只做 AP**。非要无线中继，就把 radio 的信道/带宽改成和上游
   **一模一样**，并把本机 LAN 网段改掉（避免与家里路由器撞网段）。

---

## 1. 证据：驱动里写死的「单信道」限制

本固件用的 mt76 是 `package/kernel/mt76` 的 **2026-10-28（`0936617d`）** 版本，
`mt792x_core.c`（mt7921e / mt7922 共用）里有两套接口组合表：

| 表 | 内容 | 含义 |
| --- | --- | --- |
| `if_comb`（固件无 CNM 能力时） | `{STATION}≤4`、`{AP}≤1`，`max_interfaces=4`，**`num_different_channels=1`** | 全局只能 1 个信道 |
| `if_comb_chanctx_scc`（CNM 固件，同信道） | `{STATION,P2P-client}≤2`、`{AP}≤1`、`{P2P-device}≤1`，**`num_different_channels=1`** | 带 AP 的组合只允许 1 个信道 |
| `if_comb_chanctx_mcc`（CNM 固件，跨信道） | `{STATION,P2P-client}≤2`、**`{P2P-GO}≤1`**、`{P2P-device}≤1`，`num_different_channels=2` | 允许 2 个信道，但**里面没有 AP**（只有 P2P-GO） |

关键点：**所有包含 AP 的组合都是 `num_different_channels = 1`**。也就是说
「AP 开在 5G ch48，同时 STA 连 2.4G 或另一个 5G 信道」在驱动层就被判定为非法组合，
`mac80211` 会拒绝给这个 vif 分配信道（`-EBUSY`），hostapd/wpa_supplicant 日志里能看到
信道相关的失败。

这不是 OpenWrt 的限制，是 MediaTek 2025-06 主动加进上游的补丁，理由写得很直白：

> "Due to the lack of NoA (Notice of Absence) mechanism in SoftAP mode, it is
> inappropriate to allow concurrent SoftAP and STA to operate on the different channels."
> — Leon Yen / Ming Yen Hsieh, MediaTek,
> [[PATCH] wifi: mt76: Limit the concurrent STA and SoftAP to operate on the same channel](https://lore.kernel.org/all/20250619112005.2071110-1-mingyen.hsieh@mediatek.com/)
> （v2：[限同一信道](https://lore.kernel.org/linux-wireless/20250625073720.1385210-1-mingyen.hsieh@mediatek.com/T/#u)）

翻译成人话：**软 AP 没法告诉它自己的客户端「我要离开这个信道一会」（NoA）**。
所以一旦射频跑去服务 STA 另一个信道上的业务，AP 就只有「漏发 beacon / 丢帧」这一种结果 ——
这正是你看到的现象。

> ⚠️ 顺带纠正本文档旧版本里的一句错误建议：「2.4G 做 AP + 5G 做 STA 中继」在 MT7922 上
> **做不到**（那是两个信道）。已经改掉。

---

## 2. 为什么「已连接站点」会空、网页会卡

- **「已连接站点」表只显示连到你 ImmortalWrt 自己 AP 的设备**。STA 连到小米路由器，
  不会出现在这张表里（它属于「上游客户端」，只在 状态→概览/无线 的接口状态里能看到）。
  所以空表可能只是「没有设备连你的 AP」。
- 但只要你把 STA 接口**启用**且它连不上（或连不稳），`wpa_supplicant` 会不停扫描重试。
  单射频上每次扫描都要**离开 AP 当前信道**去扫其他信道，这期间 AP 的 beacon 和客户端的数据
  都被延迟/丢弃 → 手机/电脑掉线重连、`iw station dump` 拿不到数据 → LuCI 的无线页
  （它要靠 ubus 查站点列表）就卡在那儿。**「卡」和「站点表空」是同一个原因的两个表现。**
- 另一个独立嫌疑：**网段冲突**。如果家里小米路由器的 LAN 也是 `192.168.1.0/24`，
  而本机 lan 是 `192.168.1.1`，STA 一连上就会拿到 `192.168.1.x` 的地址 →
  同网段两台 192.168.1.1 → ARP 混乱 → **不管有线无线都卡**。这条必须单独排掉。

---

## 3. 先做 3 个 1 分钟检查（LuCI 里就能做完）

1. **看上游真实信道**：网络 → 无线 → 点 `radio0` 那一行的「**扫描**」，
   在列表里找 `Xiaomi_LYN_5G`，记下它的 **信道** 和带宽（20/40/80/160MHz）。
   再对比你 `radio0` 现在钉的 `48`。**只要不一样，中继就不可能成功。**
2. **看是不是撞网段**：登录小米路由器管理页，看它的 LAN/网关地址。
   如果是 `192.168.1.1`（和本机一样）→ 先把本机改成 `192.168.8.1`（见 4.2）。
3. **看 AP 的加密**：截图里是 `WPA3 OWE`，意思是「**开放网络**（无密码，只做机会加密）」，
   谁都能连。改成 `WPA2-PSK`（或 `WPA2/WPA3 混合`）并设密码。

---

## 4. 方案

### 4.1 方案 A（强烈推荐）：有线做 WAN，MT7922 只做 AP

x86 主机最稳、也是唯一能跑满速的用法：网口 WAN 接光猫/主路由，MT7922 只负责放 Wi-Fi。

```sh
# 只做 5G AP，非 DFS 信道，HE80，WPA2
uci set wireless.radio0.disabled='0'
uci set wireless.radio0.band='5g'
uci set wireless.radio0.channel='149'      # 36/40/44/48 或 149/153/157/161，别用 52-64/100-140(DFS)
uci set wireless.radio0.htmode='HE80'      # 想要 160MHz 写 HE160（部分地区/信道不支持）
uci set wireless.radio0.country='CN'       # 中国允许 36-64、149-165
uci set wireless.radio0.txpower='20'

# 节名先用 `uci show wireless` 确认（一般是 default_radio0）
uci set wireless.default_radio0.ssid='ImmortalWrt-5G'
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.key='换成你的密码'
uci commit wireless
wifi reload
```

注意：
- **单卡同一时刻只能一个频段做 AP**。想要 2.4G 也覆盖，只能把 radio 切到 2.4G（或加网卡/加 AP）。
- 2.4G 做 AP 时同理：`band=2g`、`channel=6`、`htmode=HE40`。

### 4.2 方案 B：真要用这块卡做无线中继（AP + STA 同信道）

前提：**AP 的信道/带宽必须和上游完全一致**，而且本机 LAN 不能和家里撞网段。

```sh
# 0) 先停掉无线，避免边改边打架
wifi down

# 1) 改 LAN 网段（假设家里是 192.168.1.x；示例改成 192.168.8.1）
uci set network.lan.ipaddr='192.168.8.1'
uci commit network
/etc/init.d/network restart
#   ⚠️ 之后要用 http://192.168.8.1 访问 LuCI（旧地址会失效）

# 2) 把 radio 的信道/带宽改成「上游一模一样」（例：上游是 5G ch44 / 80MHz）
uci set wireless.radio0.disabled='0'
uci set wireless.radio0.band='5g'
uci set wireless.radio0.channel='44'        # ← 必须是扫描看到的那个信道，不能写 auto 硬猜
uci set wireless.radio0.htmode='HE80'       # ← 带宽要和上游一致或更窄
uci set wireless.radio0.country='CN'        # 与上游国家码一致，避免 149+ 之类被判非法

# 3) 客户端（STA）接口：网络挂 wwan，别挂 lan（挂 lan 会把两个二层网桥在一起）
uci set wireless.sta.ssid='Xiaomi_LYN_5G'
uci set wireless.sta.mode='sta'
uci set wireless.sta.network='wwan'
uci set wireless.sta.key='家里WiFi的密码'
uci set wireless.sta.encryption='psk2'      # 与上游一致（sae/psk2/sae-mixed 要对）

# 4) AP 侧：和 STA 同信道（同一个 radio，自动就是同信道），加密别用 OWE
uci set wireless.default_radio0.ssid='ImmortalWrt'
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.key='换成你的密码'

uci commit wireless
wifi reload
```

中继模式还要确认：`wwan` 在 **wan 防火墙区**里（网络 → 防火墙 → 区域，把 `wwan` 拖进 `wan` 区域、
开 masq），否则下游设备上不了网。

**中继模式下别指望满速**：单射频同一信道里 AP 和 STA 抢同一份空口时间，实测一般只剩
上游速率的 40–60%，延迟还会翻倍。这是硬件决定的，不是配置问题。

### 4.3 方案 C：加一张网卡（唯一能「中继 + 满速 + 不卡」的办法）

- 再插一张 USB 无线网卡（如 MT7921AU / RTL8812AU，需 `kmod-rtw88`/`kmod-88XXau`）或另一张 PCIe 卡；
- 一张做 STA（连家里），一张做 AP（放 Wi-Fi），两张卡各自独立信道，互不干扰；
- 本固件已带 `usb3` 与大部分无线框架（`mac80211`/`cfg80211`），加驱动包重编即可。

---

## 5. 排错命令（SSH 里逐条跑，2 分钟定位）

```sh
# ① 射频/接口现状：有没有 sta0，AP 在哪个信道
iw dev
iw dev wlan0 link                 # AP 接口（名字可能是 wlan0/phy0-ap0）
iw dev phy0-sta0 link             # STA 接口：Not connected 就是没连上
iwinfo                            # 各接口的信道/发射功率/关联状态

# ② 驱动到底允许什么组合（把这段完整发我，能一锤定音）
iw phy0 info | sed -n '/valid interface combinations/,/^[[:space:]]*$/p'
iw reg get

# ③ 失败原因：hostapd / wpa_supplicant / 内核
logread | grep -iE 'hostapd|wpa_supplicant|wlan|sta' | tail -40
dmesg | grep -iE 'mt7921|mt7922|firmware|timeout|EBUSY' | tail -30

# ④ 是不是撞网段 / 路由打架
ip -4 addr; ip route; ip neigh | head -20
cat /etc/config/network | sed -n '1,60p'
uci show wireless
```

判读表：

| 现象 | 结论 | 处理 |
| --- | --- | --- |
| `iw dev phy0-sta0 link` → `Not connected` | STA 压根没连上 | 信道/带宽/国家码和上游对齐（4.2 第 2 步） |
| `valid interface combinations` 里 `#channels <= 1` 且带 `#{ AP }` | 跨信道 AP+STA 不可能 | 只能同信道，或换方案 A/C |
| `logread` 里 `Cannot start ... channel` / `-EBUSY` / `CSA` 反复 | 信道冲突，射频被拖走 | 同上 |
| `dmesg` 里 `mt7921e ... timeout` / `fw` 报错 / 大量 `tx failed` | 驱动/固件在 AP+STA 并发下不稳 | GRUB 加 `pcie_aspm=off`；仍不行就放弃单卡中继 |
| `ip -4 addr` 里 `br-lan` 是 192.168.1.1，`wwan` 也拿到 192.168.1.x | **撞网段** ← 网页卡的常见真凶 | 改 lan 网段（4.2 第 1 步） |

### 用网线做一次对照实验（很重要）

把电脑用**网线**接到这台 x86 主机，再访问 LuCI：

- 网线也不卡 → 跟无线无关，查网段冲突 / CPU 占用（`top`）/ `dmesg`；
- 网线很顺、只有 Wi-Fi 卡 → 就是单射频并发/扫描干扰，按方案 A/B/C 处理。

---

## 6. 一句话记住

**MT7922 是一块「单信道」的卡：要么当 AP，要么当 STA 中继，要么两者同信道一起凑合用。
想让「家里的 Wi-Fi 稳定又全速」，就用网线做上行，把这块卡留给 AP。**

---

## 7. 参考

- MediaTek 上游补丁（restrict concurrent STA/SoftAP to the same channel）：
  <https://lore.kernel.org/all/20250619112005.2071110-1-mingyen.hsieh@mediatek.com/>
- mt76 驱动源码（与本固件 `0936617d` 一致）：`mt792x_core.c` 的 `if_comb` / `if_comb_chanctx_*`
  <https://github.com/openwrt/mt76/blob/0936617dc529ff9da0385221d3fa6de732231177/mt792x_core.c>
- 本仓库内的实证笔记：[`mt7922-notes.md`](mt7922-notes.md)（驱动/固件/wpad/6GHz 的源码级核实）
- 完整使用说明：[`x86_64-mt7922-plus.md`](x86_64-mt7922-plus.md)
