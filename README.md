<div align="center">
  <img src="https://github.com/elliana-wt/MenuCal/blob/main/icon.png?raw=true" width="120">
  <h1><center>MenuCal</center></h1>
</div>


MenuCal 是一个使用 Codex 开发的、轻量的 macOS 菜单栏时钟。

## 功能

- 可以使用 DateFormatter 模板自定义菜单栏时间，例如 `HH:mm:ss` 或 `M月d日 E HH:mm`，还可以添加你的自定义符号；
- 支持调节菜单栏时钟字号、上下位置与左右间距微调；
- 适配了最新的 Liquid Glass 设计语言，并自动适配浅色与深色模式；
- 菜单栏日历弹窗支持多种自定义调节；
- 可以快速浏览 Apple 日历中的事件，点击可调起日历查看；
- 纯菜单栏运行，不显示 Dock 图标。

## 安装

当前 Release 使用 ad-hoc 本地签名，尚未使用 Developer ID 公证。macOS 因此会把它标记为来自未识别开发者，因此第一次打开时需要右键「打开」。

1. 从 [Releases](https://github.com/elliana-wt/MenuCal/releases) 下载安装包。
2. 解压并将 MenuCal.app 移到「应用程序」文件夹。
3. 首次启动时，右键点击 MenuCal，选择「打开」，再确认打开。

MenuCal 为 Apple Silicon 构建，不支持 Intel Mac，最低支持 macOS 14 Sonoma。

## 需要的权限

- 日历：只读取并展示所选日期的事件，不会新增或修改日程。
- 自动化：仅在点击某个日程时控制系统「日历」，用于定位该事件。
- 登录项：只有开启「登录时启动」后才会申请。

如果曾拒绝权限，可前往「系统设置 > 隐私与安全性 > 日历/自动化」重新开启。

## 许可证

[MIT](LICENSE)
