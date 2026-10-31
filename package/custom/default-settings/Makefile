# SPDX-License-Identifier: GPL-2.0-only
include $(TOPDIR)/rules.mk

PKG_NAME:=default-settings
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_LICENSE:=GPL-2.0-only

include $(INCLUDE_DIR)/package.mk

define Package/default-settings
  SECTION:=base
  CATEGORY:=Base system
  TITLE:=BleachWrt-like default settings (timezone/hostname/theme/root password)
  PKGARCH:=all
  DEPENDS:=+luci-base
endef

define Package/default-settings/description
  First-boot defaults aligned with BleachWrt: Asia/Shanghai timezone, hostname,
  Chinese UI language, root password, and LuCI theme.
endef

define Package/default-settings/conffiles
endef

define Build/Compile
endef

define Package/default-settings/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/99-default-settings $(1)/etc/uci-defaults/
endef

$(eval $(call BuildPackage,default-settings))
