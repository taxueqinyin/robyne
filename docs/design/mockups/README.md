# Robyne 旗舰 UI 视觉稿

可交互预览：

```text
docs/design/mockups/index.html
```

直接用浏览器打开后可滚动查看全部画板。地址末尾带 `#only=<id>` 时只显示指定画板（`body.solo` 会去掉画板外边距，适合单板截图）：

桌面端截图建议 1360×900，手机竖屏 480×900，手机横屏 880×460。总览图按画板顺序渲染，建议 1400×3400。

当前 `index.html` 里的全部画板：

| 画板 | id |
|---|---|
| 桌面 · 发现 | `desktop-discover` |
| 桌面 · 发现（带浏览器） | `desktop-discover-browser` |
| 桌面 · 内容库 | `desktop-library` |
| 桌面 · 搜索 | `desktop-search` |
| 桌面 · 播放列表 | `desktop-playlists` |
| 桌面 · 下载 | `desktop-downloads` |
| 桌面 · 插件 | `desktop-plugins` |
| 桌面 · 插件（从 URL 导入） | `desktop-plugin-import-url` |
| 桌面 · 插件（配置用户变量） | `desktop-plugin-variables` |
| 桌面 · 设置 | `desktop-settings` |
| 桌面 · 设置（外观） | `desktop-settings-appearance` |
| 桌面 · 设置（歌词） | `desktop-settings-lyrics` |
| 桌面 · 设置（快捷键） | `desktop-settings-shortcuts` |
| 桌面 · 桌面歌词 | `desktop-lyric` |
| 手机 · 更多（溢出入口） | `mobile-overflow` |
| 手机 · 竖屏 | `mobile-portrait` |
| 手机 · 横屏 | `mobile-landscape` |

使用 Chrome headless 导出示例：

```powershell
# 在仓库根目录执行；用 $PWD 生成 file:// URL，避免把机器相关路径写进文档。
$base = 'file:///' + ((Get-Location).Path -replace '\\','/') + '/docs/design/mockups/index.html'
$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
& $chrome --headless=new --disable-gpu --no-sandbox --hide-scrollbars `
  --window-size=1360,900 `
  --screenshot='docs\design\mockups\desktop-discover.png' "$base#only=desktop-discover"
```

静态导出：

| 文件 | 内容 |
|---|---|
| `overview.png` | 画板总览（2026-09-24 生成，只含前四块；新的 6 块画板尚未收录） |
| `desktop-discover.png` | 桌面发现页 |
| `desktop-discover-browser.png` | 桌面发现页（带浏览器外框） |
| `desktop-library.png` | 桌面内容库 |
| `desktop-search.png` | 桌面搜索页 |
| `desktop-playlists.png` | 桌面播放列表页 |
| `desktop-downloads.png` | 桌面下载页 |
| `desktop-plugins.png` | 桌面插件页 |
| `desktop-plugin-import-url.png` | 桌面插件 · 从 URL 导入弹窗 |
| `desktop-plugin-variables.png` | 桌面插件 · 配置用户变量弹窗 |
| `desktop-settings.png` | 桌面设置页 |
| `desktop-settings-appearance.png` | 桌面设置 · 外观 |
| `desktop-settings-lyrics.png` | 桌面设置 · 歌词 |
| `desktop-settings-shortcuts.png` | 桌面设置 · 快捷键 |
| `desktop-lyric.png` | 桌面歌词窗口 |
| `mobile-overflow.png` | 手机 · 更多溢出面板 |
| `mobile-portrait.png` | 手机竖屏 |
| `mobile-landscape.png` | 手机横屏 |

注意：桌面发现页当前展示「播放列表」面板停靠在内容区右侧，与播放条右区入口同侧；内容库画板展示播放页覆盖整个应用窗口的沉浸态。

注意：`overview.png` 尚未重拍，新的搜索 / 播放列表 / 下载 / 插件 / 设置 / 桌面歌词画板只存在于 `index.html` 与各自的静态导出文件里。

设计规格见 `docs/design/UI_DESIGN_SPEC.md`。
