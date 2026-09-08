#!/bin/bash
#
# DIY script for Tenda BE12 Pro ImmortalWrt build
# Usage:
#   ./diy.sh pre   # before feeds update/install
#   ./diy.sh feeds # after feeds update, before feeds install
#   ./diy.sh post  # after feeds install, before build

set -euo pipefail

STAGE="${1:-pre}"

case "$STAGE" in
  pre)
    echo "[diy.sh] Pre-feed stage: adding third-party feeds"
    # OpenClash & iStore 相关的包通过 kenzo/small feeds 提供
    # 在 feeds.conf.default 中已添加
    ;;

  feeds)
    echo "[diy.sh] Feeds stage: feeds already updated"
    ;;

  post)
    echo "[diy.sh] Post-feed stage: merging config"

    # 基底 defconfig
    base="defconfig/low-mem-512m/mt7987-mt7992-be7200.config"
    if [ ! -f "$base" ]; then
      echo "Missing upstream base defconfig: $base" >&2
      exit 1
    fi

    # 合并配置
    sed -e '/routerich_be7200/d' \
        -e '/CONFIG_PACKAGE_luci-app-upnp/d' \
        -e '/CONFIG_PACKAGE_miniupnpd-nftables/d' \
        -e '/CONFIG_PACKAGE_luci-i18n-upnp-zh-cn/d' \
        -e '/CONFIG_PACKAGE_luci-app-eqos-mtk/d' \
        "$base" > .config.base
    cat .config.base config/defconfig-delta > .config
    rm -f .config.base

    # 默认 LAN IP 192.168.1.1 -> 192.168.3.1
    cfg_file="package/base-files/files/bin/config_generate"
    if [ -f "$cfg_file" ]; then
      sed -i 's/192\.168\.1\.1/192.168.3.1/g' "$cfg_file"
    else
      echo "Missing file: $cfg_file" >&2
      exit 1
    fi
    ;;

  *)
    echo "Unknown stage: $STAGE (expected: pre|feeds|post)" >&2
    exit 1
    ;;
esac
