# Robyne 旗舰 UI 视觉稿

可交互预览：

```text
docs/design/mockups/index.html
```

直接用浏览器打开后可滚动查看四块画板。地址末尾带 `#only=<id>` 时只显示指定画板（`body.solo` 会去掉画板外边距，适合单板截图）：

| 画板 | id |
|---|---|
| 桌面 · 发现 | `desktop-discover` |
| 桌面 · 内容库 | `desktop-library` |
| 手机 · 竖屏 | `mobile-portrait` |
| 手机 · 横屏 | `mobile-landscape` |

桌面端截图建议 1360×900，手机竖屏 480×900，手机横屏 880×460。总览图按四块画板顺序渲染，建议 1400×3400。

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
| `overview.png` | 四块画板总览 |
| `desktop-discover.png` | 桌面发现页 |
| `desktop-library.png` | 桌面内容库 |
| `mobile-portrait.png` | 手机竖屏 |
| `mobile-landscape.png` | 手机横屏 |

注意：桌面发现页当前展示「播放列表」面板停靠在内容区右侧，与播放条右区入口同侧；内容库画板展示播放页覆盖整个应用窗口的沉浸态。

设计规格见 `docs/design/UI_DESIGN_SPEC.md`。
