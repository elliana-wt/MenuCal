# MenuCal

MenuCal 是一个轻量的 macOS 菜单栏时钟。你可以自定义菜单栏中的日期时间格式和字号，点击时钟即可查看月历与系统日程。

> MenuCal 仅支持 Apple Silicon（arm64），最低系统版本为 macOS 14 Sonoma，不支持 Intel Mac。

## 功能

- 使用 `DateFormatter` 模板自定义菜单栏时间，例如 `HH:mm:ss` 或 `M月d日 E HH:mm`
- 12–24 px 菜单栏字号、上下位置与左右间距微调
- macOS 26 Liquid Glass 日历外观，并自动适配浅色与深色模式
- 本月 6×7 日历、前后翻月、返回今天和日期选择，支持日期字号、行列间距与高亮色调节
- 弹窗宽度随日历左右间距自动收放，最宽保持 360 pt
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

## 权限

- 日历：只读取并展示所选日期的事件，不会新增或修改日程。
- 自动化：仅在点击某个日程时控制系统“日历”，用于定位该事件。
- 登录项：只有开启“登录时启动”后才会注册。

如果曾拒绝权限，可前往“系统设置 → 隐私与安全性 → 日历/自动化”重新开启。

## 从源码构建

需要 Apple Silicon Mac、macOS 14 或更高版本，以及 Swift 6 工具链。

```bash
git clone https://github.com/elliana-wt/MenuCal.git
cd MenuCal
swift test --arch arm64
./script/build_and_run.sh
```

构建脚本会生成 `dist/MenuCal.app`、执行 ad-hoc 签名并启动应用。其他可用模式：

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
