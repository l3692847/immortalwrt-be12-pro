#!/bin/bash
#
# 本地编译脚本 - Tenda BE12 Pro ImmortalWrt
# 要求: Ubuntu 22.04+, 6核+, 16GB RAM+, 50GB+ 磁盘

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "============================================"
echo "  Tenda BE12 Pro ImmortalWrt 编译脚本"
echo "============================================"

# 检查磁盘空间
avail_gb=$(df -BG "$SCRIPT_DIR" | awk 'NR==2 {print $4}' | tr -d 'G')
if [ "$avail_gb" -lt 40 ]; then
  echo "❌ 磁盘空间不足: ${avail_gb}GB 可用，建议至少 40GB"
  exit 1
fi

# 安装依赖
echo "📦 安装编译依赖..."
sudo apt-get update
sudo apt-get install -y build-essential clang flex bison g++ gawk \
  gcc-multilib g++-multilib gettext git libelf-dev libncurses-dev \
  libssl-dev python3-distutils rsync unzip zlib1g-dev file wget ccache

# 克隆源码
if [ ! -d "$SCRIPT_DIR/openwrt" ]; then
  echo "📥 克隆 ImmortalWrt 源码 (25.12-dev-wifi7)..."
  git clone -b 25.12-dev-wifi7 --single-branch --depth=1 \
    https://github.com/chasey-dev/immortalwrt-mt798x-rebase.git "$SCRIPT_DIR/openwrt"
fi

cd "$SCRIPT_DIR/openwrt"

# 添加第三方 feeds
echo "📋 添加第三方软件源..."
if ! grep -q 'kenzo' feeds.conf.default; then
  cat >> feeds.conf.default << 'EOF'
src-git kenzo https://github.com/kenzok8/openwrt-packages
src-git small https://github.com/kenzok8/small
EOF
fi

# 更新 feeds
echo "🔄 更新软件源..."
./scripts/feeds update -a
./scripts/feeds install -a

# 克隆 OpenClash
if [ ! -d "$SCRIPT_DIR/openwrt/package/luci-app-openclash" ]; then
  echo "📥 克隆 OpenClash..."
  git clone --depth=1 https://github.com/vernesong/OpenClash.git /tmp/openclash
  cp -r /tmp/openclash/luci-app-openclash package/
fi

# 克隆 iStore
if [ ! -d "$SCRIPT_DIR/openwrt/package/luci-app-store" ]; then
  echo "📥 克隆 iStore..."
  git clone --depth=1 https://github.com/linkease/istore.git /tmp/istore
  cp -r /tmp/istore/luci-app-store package/
fi

# 合并配置
echo "⚙️  合并配置文件..."
bash "$SCRIPT_DIR/diy.sh" post

# 生成最终配置
make defconfig

# 显示关键配置
echo ""
echo "=== 关键配置确认 ==="
grep -E '(openclash|istore|store|TARGET_DEVICE|luci=)' .config | grep '=y' || true
echo ""

# 下载
echo "📥 下载源码包..."
make download -j$(nproc)

# 编译
echo "🔨 开始编译 (这可能需要 1-3 小时)..."
echo "   编译日志: $SCRIPT_DIR/build.log"
make -j$(nproc) 2>&1 | tee "$SCRIPT_DIR/build.log" || {
  echo "⚠️  并行编译失败，尝试单线程重试..."
  make -j1 V=s 2>&1 | tee "$SCRIPT_DIR/build.log"
}

echo ""
echo "✅ 编译完成！"
echo "📁 固件位置: bin/targets/mediatek/filogic/"
ls -la bin/targets/mediatek/filogic/*.bin 2>/dev/null || echo "未找到固件文件"
