#!/usr/bin/env bash
# 国内网络补丁：sing-box 的 naive outbound 依赖 libcronet（Chrome cronet），
# 而 libcronet 需要 gn 工具链（gn.googlesource.com 在墙外无法下载），
# 打开时会导致 libcronet 构建失败、进而整个镜像无法生成。
# 这个补丁把该隐藏选项默认值改成 n，使 feeds 与 configs/ 里的配置一致。
#
# 在 `./scripts/feeds update -a` 之后、`make defconfig` 之前执行。
set -euo pipefail

MK="feeds/packages/net/sing-box/Makefile"
[ -f "$MK" ] || { echo "skip: $MK not found"; exit 0; }

if grep -q -A1 'config SING_BOX_BUILD_NAIVE_OUTBOUND' "$MK" | grep -q 'def_bool y'; then
	sed -i '/config SING_BOX_BUILD_NAIVE_OUTBOUND/,+1 s/def_bool y/def_bool n/' "$MK"
	echo "patched: $MK (sing-box naive outbound -> n)"
else
	echo "already patched or symbol missing: $MK"
fi
