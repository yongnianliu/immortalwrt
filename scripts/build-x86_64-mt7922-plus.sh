#!/usr/bin/env bash
# ============================================================================
# 在 Linux / WSL2 里编译 ImmortalWrt x86/64（MT7922 / BleachWrt-plus 风格）固件
#
# 用法（必须在 Linux 文件系统里，不要在 /mnt/c 或 /mnt/d 上编译）：
#   git clone https://github.com/yongnianliu/immortalwrt.git
#   cd immortalwrt
#   ./scripts/build-x86_64-mt7922-plus.sh
#
# 首次编译前需要安装依赖（Ubuntu 22.04 / Debian 12 为例）：
#   sudo apt-get update && sudo apt-get install -y \
#     build-essential clang flex bison g++ gawk gcc-multilib g++-multilib gettext git \
#     libncurses5-dev libncursesw5-dev libssl-dev python3-dev python3-setuptools \
#     python3-pip python3-distutils rsync swig unzip zlib1g-dev file wget subversion \
#     libelf-dev bc ccache libblkid-dev libfdt-dev device-tree-compiler mtools \
#     dosfstools xorriso cpio zstd liblzma-dev libbz2-dev libgmp-dev libmpc-dev \
#     texinfo help2man patch pkg-config autoconf automake libtool-bin liblz4-dev \
#     libzstd-dev libncurses-dev time
#
# 说明：
#  * 不要先跑 `make download`：这个配置下它会串行下载全部包的源码（含未选中的），耗时极长；
#    直接 make 即可，源码会在编译时按需并行下载。
#  * 以 root 编译（如 Docker/WSL root）时脚本会自动设 FORCE_UNSAFE_CONFIGURE=1。
#  * WSL 下必须清掉 Windows PATH（含 "Program Files" 空格），否则 Go 包会报 shell 语法错误。
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIG_FILE="configs/x86_64-mt7922-plus.config"
FEEDS_EXT="configs/feeds.plus-ext.conf"
PKGS_EXT="configs/packages.plus-ext.txt"
JOBS="${JOBS:-$(nproc)}"

export FORCE_UNSAFE_CONFIGURE=1
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

echo "=== [1/5] update official feeds ==="
./scripts/feeds update -a
./scripts/feeds install -a

echo "=== [2/5] add plus-ext third-party feeds + install whitelist ==="
if ! grep -q 'openwrt-passwall2' feeds.conf.default; then
	cat "$FEEDS_EXT" >> feeds.conf.default
fi
./scripts/feeds update -a
# 注意：只安装白名单里的包。不要 install -a —— kenzok8/small 里有大量与官方重名的包。
if [ -f "$PKGS_EXT" ]; then
	# shellcheck disable=SC2046
	./scripts/feeds install $(tr '\n' ' ' < "$PKGS_EXT")
fi

echo "=== [3/5] apply CN network feed patch ==="
./scripts/apply-cn-feed-patches.sh

echo "=== [4/5] apply config + build (jobs=$JOBS) ==="
cp "$CONFIG_FILE" .config
make defconfig
make -j"$JOBS"

echo "=== [5/5] artifacts ==="
ls -lh bin/targets/x86/64/ | grep -E 'img\.gz|manifest'
echo
echo "烧写用 *squashfs-combined-efi.img.gz（UEFI）；老主板用 *squashfs-combined.img.gz（BIOS）。"
echo "默认地址 http://192.168.1.1 ，root 密码 password（首次登录请修改）。"
