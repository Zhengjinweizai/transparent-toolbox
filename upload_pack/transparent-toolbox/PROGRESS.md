# Transparent Toolbox 开发进度

开始时间戳：1793033361（2026-10-27）
收工时间戳：1793044161（满 3 小时停止开发）

## 技术方案
- 原生 Swift/AppKit（环境无 Node，Electron 不可用）
- 零第三方依赖，swiftc 直接编译，单二进制

## v2.5 Bento 栅格改版
- 布局从单列长条改为 450px 双列 Bento 瀑布流（FlippedView 手工布局引擎 layoutBento）
- 15 部件声明 span（5 个通栏 + 10 个半卡），半卡紧凑化宽度
- 卡片折叠/展开/内容变化实时重排

## v2 迭代（2026-10-28 凌晨，第二轮 3 小时冲刺）

### 设计
- 调研 iStat Menus 7 / Stats / One Switch / Maccy / Paste / Raycast / Dropover + Apple HIG（见 DESIGN.md）
- UI 设计系统 v2：语义色板、度量系统（卡距10/内边距12-14/圆角14）、图标底衬、卡片 hover 高亮、空状态组件
- 新组件：Sparkline 历史曲线、RingProgress 环形进度、MiniBar 自动配色（绿→橙→红）

### 功能
- 系统信息 v2：CPU/内存/网速三条 Sparkline、磁盘用量条、开机时长
- 剪贴板 v2：搜索、置顶、相对时间戳、上限 50（clips2 数据模型，v1 自动迁移）
- 番茄钟 v2：环形进度、今日轮数统计（跨天清零）、阶段自动切换
- 新部件 快捷开关：深浅色切换、屏保、桌面图标显隐、清废纸篓
- 时钟 v2：世界时钟行（纽约/伦敦/东京）
- 计算器：物理键盘输入（焦点在文本框时自动让路）
- 每卡片独立折叠（chevron + 双击标题），状态持久化 collapsedCards

### 验证
- MathParser 14 用例 + 数据层 5 用例（v1 迁移/Sparkline 缓冲/相对时间）全过
- verify.sh 全过；系统窗口查询 = 1；真实稳态内存 36MB（峰值 93MB 启动期）

## 已完成（全部验证通过）
- [x] 骨架：入口 / 透明毛玻璃悬浮面板 / 状态栏菜单 / 边缘吸附 / 拖动 / 置顶开关 / 折叠小圆钮 / 双击卡片标题折叠
- [x] 部件×14：时钟、系统信息（CPU/内存/网速）、番茄钟、倒计时（重置记忆所选时长）、秒表（计次）、待办（完成沉底）、便签（多页：新建/删除/翻页，旧单便签自动迁移实测通过）、剪贴板历史、计算器、二维码（CoreImage）、密码生成（SecRandom）、取色器（ScreenCaptureKit）、启动器（含算式即算，MathParser 递归下降求值器 14 用例单测全过）、截图贴图（screencapture 框选 → 置顶贴图窗）
- [x] 设置窗：透明度 30–100%（拖动防抖保存）、材质三选、番茄钟时长（即时生效）、部件显隐 + ↑↓ 排序、开机自启（SMAppService）
- [x] 全局快捷键 ⌥Space 显示/隐藏；菜单栏「关闭所有贴图」；待办/启动器内容变化自动重算面板高度
- [x] 持久化 state.json（旧版向后兼容，缺字段自动补默认值；实测旧 JSON 读入 + 退出写回全字段）
- [x] .app 打包（图标脚本生成 + Info.plist + ad-hoc 签名）、DMG 打包、verify.sh 一键自检
- [x] 修复：剪贴板/启动器条目按钮 intrinsic 宽度为 0 不可点 → 改原生 NSButton 标题/图标；折叠循环重复宽度约束；取色器 Esc 取消 + 监听器泄漏；剪贴板清空后列表不刷新；部件重建时 NotificationCenter 观察者泄漏；透明度拖动保存防抖；便签 TextView minSize/maxSize；计算器显示宽度对齐按钮网格与 % 运算优先级

## 运行验证记录
- 编译零错误零警告；两轮 10 分钟长跑均通过（0% CPU、~38MB RSS 稳定）
- state.json 读写实测通过（旧版兼容 + 单便签迁移多便签实测）
- MathParser 单元测试 14/14 通过（tests/run_tests.sh）
- verify.sh 一键自检通过；最终 .app / DMG 已产出并再次验证

## 待办 / 未来方向
- 截图贴图、剪贴板图片类型、全局热键自定义、公证（Notarization）
