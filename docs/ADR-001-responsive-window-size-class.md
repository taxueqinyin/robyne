# ADR-001：以 Window Size Class 为唯一自适应依据

> 状态：已接受 · 日期：2026-03-05 · 影响：全 App 布局层
> 相关：`docs/THEME_LAYER_DESIGN.md`、`docs/THEME_AUTHORING.md`

---

## 背景

Robyne 的皮肤系统把 UI 拆成两个正交层：Token 层（调色）与 Layout 层（骨架）。
设计文档正确地判断出"Layout 必须按 form factor 分叉"是多端的关键（`THEME_LAYER_DESIGN.md:154`）。

但实际运行中发现：**PC 上正常的布局，在手机上信息显示不全。** 且换任何皮肤都一样。

排查后的结论：**这不是皮肤系统的问题，是官方骨架在窄屏下的实现不完整。** 具体病症：

| # | 症状 | 根因 | 位置 |
|---|---|---|---|
| 1 | 安卓横屏界面错乱 | 断点只看宽度。横屏手机 800×360 被判定为 desktop，走 `NavigationRail` 分支，内容区只剩 ~248dp 高 | `router.dart:62,174` |
| 2 | 竖屏歌词整栏消失 | `Row` 硬编码：`SizedBox(width:340)` + `VerticalDivider(48)` + 歌词 = 388dp > 可用 336dp | `now_playing_page.dart:45` |
| 3 | 布局字段是死字段 | `mobile.playerBarHeight` / `navigation` / `listStyle` / `density` 除了在设置页当文本显示，无任何 widget 读取 | `theme_layout.dart:71` |
| 4 | 对话框溢出 | 固定宽高 720/520/460/420/360/320，部分还带 `height: 520` | `now_playing_page.dart:506` 等 8 处 |
| 5 | 断点互相打架 | 外壳用 700，Discover 用 960，且 compact 分支是上下堆叠（每个面板 ~80dp） | `discover_page.dart:86,118` |
| 6 | 播放条标题截断 | compact 分支去掉音量条后仍有 5 个 IconButton（≥240dp） | `player_bar.dart:97` |

一个附加事实：**症状 3 意味着 `THEME_AUTHORING.md:168` 承诺的 `"layout": { "mobile": { "playerBarHeight": 56 } }` 实际不生效。** 文档对皮肤作者做出了当前实现无法兑现的承诺。

## 决策

### D1. 引入 Window Size Class 作为唯一自适应依据

新建 `lib/core/layout/window_size_class.dart`，采用 Material 3 canonical breakpoints，且**宽高双维**：

| Width class | 范围 | Height class | 范围 |
|---|---|---|---|
| compact | < 600 | compact | < 480 |
| medium | 600–839 | medium | 480–899 |
| expanded | ≥ 840 | expanded | ≥ 900 |

删除全项目中散落的自造断点常量（`_compactWidthBreakpoint` 三份、`960` 一份），统一由 `WindowSizeClass.of(context)` 提供。

### D2. 用 size class 判断布局，不用 platform 判断布局

`isDesktopPlatform`（`router.dart:47`）保留，但职责收窄为**仅判断平台能力**（桌面歌词窗口依赖 `desktop_multi_window`，Android 无实现）。它不再参与任何布局决策。

理由：platform 与可用空间没有因果。平板、折叠屏、分屏、自由缩放的桌面窗口都会打破"Windows ⇒ 宽屏"的假设。横屏手机 = medium width + compact height，正是当前 bug 的精确描述。

### D3. 一套组件 + 多套 shell 布局，不做两套 UI

不重复的维度：
- **组件库**：单一实现，每个组件自己响应约束
- **shell 骨架**：`_buildExpandedBody` / `_buildCompactBody` 两个 builder 的方向保留并强化
- **平台差异**：仅局部替换（Android 返回手势 / 桌面快捷键）

判定 pairs 的对错标准不是"是不是手机"，而是"能不能放下"。

### D4. 皮肤给意图，不给像素；尺寸值一律相对于视口

这是 Level 1 布局层的修正方向（本期先在应用层落地围栏，皮肤侧的语义枚举化属于 P1）：

- 引入惯用 helper：`RobyneDialogWidth.of()`、`viewportClamped()`
- 任何固定尺寸在使用点做 `min(value, viewport * ratio)` 收敛
- 未来布局 token 改为语义枚举（`density` / `scale`），废弃绝对像素（宽度/高度）

**自适应是应用的责任，不是皮肤作者的责任。** 把移动端适配推给作者，等于 90% 的皮肤永远残缺。

### D5. compact height 时 Playbar 降级为 mini bar

M3 对 compact-height 的处理是压缩 chrome 而非堆叠内容。PlayerBar 在 `height == compact` 时进入单层 mini bar。

### D6. list-detail 页面在 compact 下用单 pane + 导航切换

Discover 的 browse/detail 与 Queue 的 queue/history 都是 M3 的 list-detail canonical layout。compact width 下的正确行为是**全屏 pane 切换**，而非上下堆叠（堆叠后每 pane ~80dp，等于不可读）。

---

## 备选方案与取舍

### A. 做两套 UI（桌面一套、移动端一套）
**否决。** 功能漂移成本不可承受：新增一个功能要改两处，两套 UI 的状态随之发散，且 bug 加倍。没有主流应用这么做。

### B. 用 `double` 缩放比例（按屏宽等比缩放）
**否决。** 文本不可读、触控目标小于 44dp、且依然存在极端比例错乱。Responsive ≠ Uniform scaling。

### C. 让皮肤作者填两套绝对像素（现状）
**否决。** 见 D4。而且 paser 目前只做绝对范围 clamp（`_ranged(width, 56, 400)`，`theme_manifest_parser.dart:134`），`width:240` 在 360dp 屏上合法但致命。

### D. Window Size Class（选用）
- 优点：M3 / Apple Size Classes / Web 生态的事实标准；开发者熟悉；只需处理 3×3 而非连续空间；高度维度天然解决横屏痛点
- 代价：需重写 shell 与页面分支；短期内多为 🔧 plumbing

---

## 后果

### 正面
- 横屏 / 竖屏 / 折叠屏 / 分屏 / 缩放窗口全部有定义行为
- Regressions 可被 widget test 锁定（用 `tester.view.physicalSize` 注入三个代表性尺寸）
- 为 P1 让 `layout.mobile.*` 真正生效铺路；届时 `THEME_AUTHORING.md` 的承诺得以兑现

### 负面 / 需管理
- 页面增加分支复杂度 → 由 `WindowSizeClass` 集中收口，避免在页面里重复写 `MediaQuery.sizeOf(context).width < X`
- 皮肤作者已写的绝对像素 token 在新语义下语义漂移 → P1 处理，P0 保持 parser 现状，降级为"值会在运行时被视口收敛"
- Discover 单 pane 切换改变了既有交互 → 用 widget test 覆盖两个方向的跳转

### 验证方式
新增 `test/responsive_layout_test.dart`，注入三组尺寸断言零 overflow：
- `400×800`（竖屏手机）
- `800×360`（横屏手机）
- `1280×900`（桌面）

`expect(tester.takeException(), isNull)` + Flutter ErrorWidget 捕获，即可在 CI 锁死"信息显示不全"这一整类回归。

---

## 状态与后续

- **P0（本期）**：真凶修复，与皮肤系统无关。D1 / D2 / D5 / D6 + 对话框约束
- **P1**：让 `layout.mobile.*` 生效；布局 token 语义枚举化；skin 尺寸值视口相对 clamp
- **P2**：皮肤编辑器三形态实时预览；市场 `index.json` 携带 `formFactors` 兼容性声明
