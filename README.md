# MenuCal

MenuCal 是一个轻量的 macOS 菜单栏时钟。你可以自定义菜单栏中的日期时间格式和字号，点击时钟即可查看月历与系统日程。

> MenuCal 仅支持 Apple Silicon（arm64），最低系统版本为 macOS 14 Sonoma，不支持 Intel Mac。

## 功能

- 使用 `DateFormatter` 模板自定义菜单栏时间，例如 `HH:mm:ss` 或 `M月d日 E HH:mm`
- 12–24 px 菜单栏字号、上下位置与左右间距微调
- macOS 26 Liquid Glass 日历外观，并自动适配浅色与深色模式
- 本月 6×7 日历、前后翻月、返回今天和日期选择，支持日期字号、行列间距与高亮色调节
- 弹窗宽度随日历左右间距自动收放，最宽保持 360 pt
- 日期下方显示中国法定节假日和调休，使用 Apple 的中国大陆节假日订阅，优先标注“休／班”
- 在 MenuCal 内添加、开关、刷新和删除自己的 ICS / webcal 日历订阅；支持离线缓存
- 读取并展示系统日历中的全天与定时事件
- 点击事件后在系统“日历”中定位
- 在设置中检查 GitHub Releases 更新，校验 SHA-256、应用标识、签名结构与 arm64 架构后自动安装并重启
- 浅色/深色模式和登录时启动
- 纯菜单栏运行，不显示 Dock 图标

## 安装

1. 从 [Releases](https://github.com/elliana-wt/MenuCal/releases) 下载 `MenuCal-arm64.zip`。
2. 解压并将 `MenuCal.app` 移到“应用程序”文件夹。
3. 首次启动时右键点击 MenuCal，选择“打开”，再确认打开。

当前 Release 使用 ad-hoc 本地签名，尚未使用 Developer ID 公证。macOS 因此会把它标记为来自未识别开发者；右键“打开”只需在首次启动时操作。

## 设置

设置窗口由 `NSWindowController` 管理，使用 AppKit 的 `NSSplitViewController` 与独立 `NSToolbar`，macOS 26 及以上采用系统 Liquid Glass 侧栏、工具栏和安全区域布局；设置项使用原生 SwiftUI 分组表单。侧栏分为「外观设置」「日历订阅」「通用」。外观页包含菜单栏时钟与弹窗日历，通用页提供登录启动与软件更新。可从日历弹窗底部或 `⌘,` 打开；关闭后保留所选页面，并记住窗口大小与位置。

## 日历订阅

在“设置 → 日历订阅”中粘贴日历服务提供的 `https://` 或 `webcal://` 订阅链接。名称可留空，自动读取日历名称。MenuCal 直接管理这些只读订阅，不需要系统日历权限；账号登录或 CalDAV 账户连接不在此次支持范围内。

中国节假日默认从 [Apple 中国大陆节假日日历](https://calendars.icloud.com/holidays/cn_zh.ics) 同步，显示法定节日及休假、补班安排。日期下方显示简称，悬停或点击日程可查看完整名称。未来年份只显示源中已经发布的安排，不推算调休。关闭“显示日程”后，日期下方的节假日仍可独立显示。

打开日历或设置时，距离上次成功更新超过 6 小时的已启用订阅会自动刷新，也可以手动刷新。下载或解析失败会在设置中显示原因并保留旧缓存。订阅链接及缓存仅保存在当前 Mac 的 `~/Library/Application Support/MenuCal/CalendarSubscriptions.json`，删除订阅会同时清除对应缓存。

支持全天、跨天、UTC / IANA 时区事件，以及按日、周、月、年重复的常见规则（含间隔、截止日、次数、指定星期、月日、位置筛选和例外日期、单次改期／取消）。遇到暂不支持的规则（如按小时重复、`RANGE=THISANDFUTURE` 或自定义时区）会明确报错，不会静默省略日程。

## 权限

- 日历：只读取并展示所选日期的事件，不会新增或修改日程。
- 自动化：仅在点击某个日程时控制系统“日历”，用于定位该事件。
- 登录项：只有开启“登录时启动”后才会注册。

如果曾拒绝权限，可前往“系统设置 → 隐私与安全性 → 日历/自动化”重新开启。

## 从源码构建

需要 Apple Silicon Mac、macOS 14 或更高版本，以及带 macOS 26 或更新 SDK 的 Swift 6 工具链。macOS 27 默认外观在 macOS 27 上运行时生效。

```bash
git clone https://github.com/elliana-wt/MenuCal.git
cd MenuCal
swift test --arch arm64
./script/build_and_run.sh
```

构建脚本使用当前工具链的 macOS SDK，生成 `dist/MenuCal.app`、执行 ad-hoc 签名并启动应用。有完整 Xcode 时使用 Xcode 工程；只有 Command Line Tools 时使用 SwiftPM 原生构建后端，后者不编译 Icon Composer 图标。脚本会核验 Mach-O 的 SDK 标记，防止 SDK 被错误写成最低部署版本而触发旧版 AppKit 外观。若文件提供程序给应用包持续附加 Finder 元数据，脚本会自动在本地临时目录完成签名并启动，日志会显示实际路径。

SDK 27 的 Command Line Tools 缺少 SwiftUI State 宏插件时，`ViewState` 类型别名显式引用系统 State 属性包装器；不引入自定义状态或 UI 实现。其他可用模式：

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
./script/build_and_run.sh --debug
```

## 发布

推送形如 `v1.0.0` 的 Git 标签会触发 GitHub Actions，运行测试、生成 arm64 应用包，并发布 ZIP 与 SHA-256 校验文件。

## 许可证

[MIT](LICENSE)
