# 🧰 Transparent Toolbox · 透明工具箱

[![Swift](https://img.shields.io/badge/Swift-AppKit-orange)](https://swift.org)
[![macOS](https://img.shields.io/badge/platform-macOS%2013%2B-blue)](https://www.apple.com/macos)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Widgets](https://img.shields.io/badge/widgets-15-8A2BE2)](#功能一览)

一款用 **原生 Swift/AppKit** 打造的 macOS 桌面悬浮透明工具箱：毛玻璃半透明 **Bento 卡片栅格**，常驻桌面、可拖动、可缩放、可置顶，内置 15 个实用小部件。**零第三方依赖**，`swiftc` 直接编译，单二进制，稳态内存 ~36MB。

> 灵感来自 iStat Menus / One Switch / Maccy / Raycast，设计遵循 Apple HIG，布局采用 Apple 官网式 Bento Grid。

## ✨ 亮点

- 🪟 **透明毛玻璃 + Bento 双列瀑布流**：大小卡片混排，滚轮浏览，边缘拖拽缩放，位置尺寸全记忆
- 📊 **iStat 式系统监控**：CPU / 内存 / 网速实时 **Sparkline 历史曲线**，磁盘用量（绿→橙→红自动配色），开机时长
- ⏱ **番茄钟 + 倒计时 + 秒表**：环形进度、今日轮数统计（跨天清零）、计次
- 📋 **Maccy 式剪贴板**：50 条历史、搜索过滤、图钉置顶、相对时间戳
- 🚀 **Raycast 式启动器**：搜 App + 算式即算（自写递归下降求值器，14 用例单测）
- 🔀 **One Switch 式快捷开关**：深浅色、屏保、桌面图标显隐、清废纸篓
- ✍️ 多页便签、待办（完成沉底）、计算器（物理键盘）、二维码、密码生成（SecRandom）、取色器、截图贴图
- 🎛 全部部件可显隐 / 排序 / 单卡折叠，透明度与材质可调，⌥Space 全局唤起

## 功能一览

| 部件 | 说明 |
|---|---|
| 🕐 时钟 | 大字时间 + 中文日期 + **世界时钟**（纽约/伦敦/东京），每秒刷新 |
| 💻 系统信息 | CPU/内存/网速 **历史曲线**（Sparkline）、磁盘用量、开机时长 |
| ⏱ 番茄钟 | **环形进度**、专注/休息自动切换、**今日完成轮数统计**、结束提示音，时长可调 |
| ⏳ 倒计时 | 1/3/5/10/25 分钟快捷预设，最后 10 秒变橙提示 |
| ⏲ 秒表 | 0.1 秒精度，计次（保留最近 5 条）、暂停续走、重置 |
| ✅ 待办 | 添加、勾选完成（划线置灰）、删除，持久化 |
| 📝 便签 | 多张便签翻页（新建/删除/左右切换），输入防抖自动保存，旧版单便签自动迁移 |
| 📋 剪贴板 | 最近 50 条文本历史，**搜索过滤**、**置顶**、相对时间戳，点击复制，一键清空 |
| 🎨 取色器 | 屏幕任意位置采样颜色，实时预览色块 + HEX，点击确认、Esc 取消、一键复制 HEX |
| 🔀 快捷开关 | 深浅色切换、启动屏保、显示/隐藏桌面图标、清倒废纸篓 |
| 🚀 启动器 | 搜索 /Applications、系统应用并快速打开，回车启动第一个匹配项；输入算式（如 `12*8`、`(3+5)/2`）即出结果，点击复制 |
| 🧮 计算器 | 四则运算、百分比、正负号；支持**物理键盘输入**（数字/运算符/回车/退格） |
| 🔳 二维码 | 文本/链接生成二维码（CoreImage），点击复制图片 |
| 🔑 密码生成 | 6–48 位可调，可选符号，SecRandom 加密安全随机，一键复制 |
| 📷 截图贴图 | 框选屏幕区域 → 生成置顶可拖动贴图小窗，双击贴图关闭，菜单栏可一键关闭全部 |

## 窗口与控制

- **拖动**：按住面板任意空白处拖动；靠近屏幕边缘自动吸附
- **置顶**：默认悬浮于所有窗口之上；状态栏菜单「窗口置顶」(⌘P) 可切换
- **折叠**：点击面板右上角 ➖ 或**双击任意卡片标题**，折叠成小圆钮；再点展开；状态自动记忆
- **显示/隐藏**：状态栏 (⌨ 菜单栏) 图标控制，快捷键 ⌘T；全局快捷键 **⌥Space** 随时唤起/隐藏
- **透明度**：设置中 30%–100% 无级调节
- **材质**：深色毛玻璃 / 纯深色 / 浅色三种
- **部件显隐与排序**：设置中勾选显隐，↑↓ 调整顺序
- **卡片折叠**：每张卡片右上角 chevron 可独立收起（状态记忆），双击卡片标题同样生效
- **悬停反馈**：卡片 hover 时描边高亮为主题色
- **开机自启**：设置中开关（以 .app 方式运行时生效）

## 构建 & 运行

```bash
# 直接编译运行（裸二进制）
./build.sh
./build/TransparentToolbox

# 打包成正规 .app（含图标，ad-hoc 签名）
./make_app.sh
open build/TransparentToolbox.app

# 打包 DMG
./make_dmg.sh   # 输出 build/TransparentToolbox.dmg

# 一键自检（构建 → 启动 → 稳定性 → 状态文件）
./verify.sh

# 单元测试（MathParser 14 用例）
./tests/run_tests.sh
```

要求：macOS 13+，Xcode Command Line Tools（`xcode-select --install`）。

## 数据与权限

- **状态持久化**：`~/Library/Application Support/TransparentToolbox/state.json`（便签、待办、剪贴板历史、透明度、材质、折叠状态、部件显隐与排序全部自动保存；旧版文件向后兼容）
- **取色器**和**截图贴图**需要**屏幕录制权限**（系统设置 → 隐私与安全性 → 屏幕录制），未授权时会显示提示，不影响其他功能

## 已知限制

- 取色器实时预览使用 ScreenCaptureKit，首次使用会触发系统权限弹窗
- 截图贴图依赖 `screencapture` 命令行交互框选，需要屏幕录制权限
- 剪贴板历史仅记录文本类型（图片/文件暂不支持）
- 裸二进制方式运行时开机自启不可用，请使用 .app 方式
- 未做公证（Notarization），其他电脑首次打开需右键 → 打开

## 项目结构

```
transparent-toolbox/
├── Sources/
│   ├── main.swift            # 入口
│   ├── AppDelegate.swift     # 应用生命周期
│   ├── PanelController.swift # 透明悬浮面板 + 卡片容器 + 吸附/折叠
│   ├── StatusBar.swift       # 菜单栏控制
│   ├── SettingsWindow.swift  # 设置（透明度/材质/时长/显隐/排序/自启）
│   ├── Store.swift           # 状态持久化（JSON）
│   ├── Theme.swift           # 公共 UI 工具
│   └── *Widget.swift         # 14 个小部件
├── tests/run_tests.sh        # 单元测试
├── scripts/make_icon.swift   # 图标生成
├── build.sh                  # 裸编译
├── make_app.sh               # .app 打包
├── make_dmg.sh               # DMG 打包
├── verify.sh                 # 一键自检
└── PROGRESS.md               # 开发日志
```

## 后续可扩展方向

- 截图贴图（需屏幕录制权限 + 区域选择交互）
- 剪贴板支持图片/文件类型
- 系统信息增加磁盘/网络速率
- 快捷键全局唤起（需注册全局热键）
- 多面板/多套配置
