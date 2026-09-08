# 腾达 BE12 PRO ImmortalWrt 自编译固件

基于 `chasey-dev/immortalwrt-mt798x-rebase` (25.12-dev-wifi7 分支) 构建，适配 Tenda BE12 Pro (MT7987A + MT7992 Wi-Fi 7)。

## 包含组件

| 组件 | 说明 |
|------|------|
| OpenClash | Clash 图形客户端，支持 SS/SSR/Vmess/Trojan 等 |
| iStore | 软件中心，方便后续安装其他插件 |
| LuCI | 中文 Web 管理界面 + argon 主题 |
| 中文语言包 | 完整中文支持 |

## 硬件信息

- SoC: MediaTek MT7987A (Filogic)
- Wi-Fi 7: MT7992 (联发科闭源驱动)
- 2.5G PHY: Airoha EN8811H
- RAM: 512MB
- 默认管理地址: 192.168.3.1

## 编译方式

### 方式一：GitHub Actions（推荐，无需本地环境）

1. Fork 本仓库到你的 GitHub 账号
2. 进入 Actions 页面，找到 `Build ImmortalWrt for Tenda BE12 Pro`
3. 点击 `Run workflow`，等待编译完成（约 2-3 小时）
4. 在 Artifacts 中下载固件包

### 方式二：本地编译

系统要求：Ubuntu 22.04/24.04，至少 6 核 CPU、16GB 内存、50GB 可用磁盘。

一键编译：
```bash
chmod +x build-local.sh
./build-local.sh
```

```bash
# 安装依赖
sudo apt update
sudo apt install -y build-essential clang flex bison g++ gawk \
  gcc-multilib g++-multilib gettext git libelf-dev libncurses-dev \
  libssl-dev python3-distutils rsync unzip zlib1g-dev file wget

# 克隆源码
git clone -b 25.12-dev-wifi7 --single-branch --depth=1 \
  https://github.com/chasey-dev/immortalwrt-mt798x-rebase.git immortalwrt
cd immortalwrt

# 添加第三方 feeds（OpenClash + iStore）
cat >> feeds.conf.default << 'EOF'
src-git kenzo https://github.com/kenzok8/openwrt-packages
src-git small https://github.com/kenzok8/small
EOF

# 更新并安装 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 克隆 OpenClash 到 package 目录
git clone --depth=1 https://github.com/vernesong/OpenClash.git /tmp/openclash
cp -r /tmp/openclash/luci-app-openclash package/

# 克隆 iStore
git clone --depth=1 https://github.com/linkease/istore.git /tmp/istore
cp -r /tmp/istore/luci-app-store package/

# 使用增量配置（覆盖基底 defconfig）
cp ../config/defconfig-delta .config.delta

# 合并基底 defconfig 和增量配置
base="defconfig/low-mem-512m/mt7987-mt7992-be7200.config"
sed -e '/routerich_be7200/d' \
    -e '/CONFIG_PACKAGE_luci-app-upnp/d' \
    -e '/CONFIG_PACKAGE_miniupnpd-nftables/d' \
    -e '/CONFIG_PACKAGE_luci-i18n-upnp-zh-cn/d' \
    -e '/CONFIG_PACKAGE_luci-app-eqos-mtk/d' \
    "$base" > .config.base
cat .config.base .config.delta > .config
rm -f .config.base

# 修改默认 LAN IP 为 192.168.3.1
sed -i 's/192\.168\.1\.1/192.168.3.1/g' package/base-files/files/bin/config_generate

# 下载所有依赖
make defconfig
make download -j$(nproc)

# 开始编译
make -j$(nproc) || make -j1 V=s
```

编译产物位于 `bin/targets/mediatek/filogic/` 目录。

## 源码仓库说明

本项目基于以下上游仓库构建：

| 仓库 | 分支 | 说明 |
|------|------|------|
| chasey-dev/immortalwrt-mt798x-rebase | 25.12-dev-wifi7 | 主线 Wi-Fi 7 支持（MT7992） |
| kalicyh/ImmortalWrt-tenda_be12-pro | tenda-be12-pro | BE12 Pro 专用补丁（备用） |

恩山论坛也有社区编译版：<https://www.right.com.cn/forum/thread-8477866-1-1.html>

## 刷机说明

1. 进入路由器后台（原厂固件或已刷 ImmortalWrt）
2. 选择「系统 → 备份/升级」
3. 上传 `immortalwrt-mediatek-filogic-tenda_be12-pro-squashfs-sysupgrade.bin` 刷入
4. 等待重启完成

> ⚠️ 首次从原厂固件刷入需要使用 TFTP 或编程器方式，请参考恩山论坛相关教程。

### 刷机后验证

```bash
# SSH 登录后执行
ubus call system board      # 确认 board_name: tenda,be12-pro
ip link                      # 确认 eth0/eth1/eth2/ra0/rai0 存在
logread | grep -iE 'mt7992|hnat'  # 确认 WiFi 7 和 HNAT 正常
```

## 配置说明

`config/defconfig-delta` 是增量配置文件，只包含额外添加的包。基底配置来自上游 `defconfig/low-mem-512m/mt7987-mt7992-be7200.config`。

### 自定义添加包

如需添加更多包，在 `config/defconfig-delta` 中追加 `CONFIG_PACKAGE_xxx=y`，或在编译前执行 `make menuconfig` 交互式选择。
