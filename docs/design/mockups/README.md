# Robyne 设计板（生成物）

`index.html` 不是画出来的。它由脚本从应用自己的输出合成：

| 层 | 来源 | 为什么可信 |
|---|---|---|
| 底图 | `test/goldens/boards/*.png` | `flutter test` 用应用本身渲染，像素即真相 |
| 区域标注 | `test/goldens/boards/*.plan.json` | `RobyneShellPlan.resolve()` 算出的 dp，与像素同源 |
| 颜色变量 | `assets/themes/xuan/theme.json` | 皮肤 token，页面只引用不复制 |

## 重新生成

```bash
# 1. 画板（PNG + plan.json）
ROBYNE_BOARDS=1 flutter test test/design_boards_test.dart --tags boards --update-goldens

# 2. 合成 HTML
python tool/generate_design_html.py
```

改了 UI 就重跑一遍——重新生成即同步，没有手维护的第三份实现。

## 画板清单（44 块）

**桌面 1360×900（13）**：发现 / 内容库 / 搜索 / 我喜欢 / 下载 / 插件 / 设置×4 tab / 队列停靠 / 队列浮层 / 沉浸播放页

**手机（6）**：竖屏 发现/内容库/搜索/我的、队列抽屉、横屏 800×360

**响应式 5 断点 × 5 页面（25）**：
1360×900（expanded/expanded，侧栏 245dp 带标签）、960×700（expanded/medium，侧栏 173dp 带标签）、760×760（medium/expanded，侧栏塌成 72dp 胶囊）、400×800（手机竖屏）、800×360（compact 高度，D7 丢顶栏）

每块画板下方有可展开的 `RobyneShellPlan` JSON：`topBarVisible`、`navSlot`、`queueOverlay`、各区域 dp 值。页首「开/关区域标注」按钮在底图上叠加区域框。

## fixture 数据

假数据在 `test/support/fixture_data.dart`（林俊杰曲库、两个搜索插件、六种下载状态），封面是运行时生成的渐变 PNG（`test/support/fixture_artwork.dart`，落在系统临时目录，不进仓库）。

## 注意

- 裸 `flutter test` 会跳过画板（`skip` 门 + `boards` tag 双保险）；必须显式 `--tags boards` 加 `ROBYNE_BOARDS=1`
- 画板对字体敏感：字体在测试里手动 `FontLoader` 注册。曾因 `ThemeManifestParser` 清空默认字体族导致整套画板 CJK 全变方块——已修（`copyWith(fontFamily: family ?? baseline.fontFamily)`）
- 历史：2026-10-14 之前这里是手绘 HTML + 18 张静态 PNG，与实现漂移严重后整批废弃
