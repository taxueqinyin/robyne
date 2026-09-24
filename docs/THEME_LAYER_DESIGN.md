# Robyne 可定制 UI 层设计方案（Theme Layer RFC）

> 状态：设计草案 · 目标：多端（Windows / Android / 后续 macOS）· 替代 MusicFree 皮肤方案

---

## 1. 结论先行

**不要把 UI 抽成"一个层"，要抽成两个正交的层：**

| 层 | 名称 | 职责 | 谁写 |
|---|---|---|---|
| L1 | **Token 层（皮肤）** | 颜色、圆角、间距、字体、阴影、模糊、背景图 —— 纯"调色" | 皮肤作者，JSON 声明 |
| L2 | **Layout 层（骨架）** | 区域如何排布、组件如何组合 —— 纯"结构" | 皮肤作者（可选），默认骨架由官方提供 |

**关键判断：L1 和 L2 必须是两个独立可变的东西。**
MusicFree 的失败点就在这 —— 它只有一个 CSS 层，`.l-sidebar` 这种选择器把"结构"焊死成了桌面端形状，所以它永远上不了手机。我们把两者拆开，就天然解决了多端。

**默认 UI 不是特例，它是"内置皮肤包"。** 它和第三方皮肤走完全相同的加载路径、相同的模型、相同的渲染管线。这是给皮肤作者打样的唯一正确做法 —— 如果默认 UI 走后门，第三方皮肤永远会遇到"官方能跑、我不能跑"的墙。

---

## 2. 为什么不兼容 MusicFree（技术论证）

不是不想，是不可靠。MusicFree 皮肤 = `index.css` 手写 CSS：

```css
:root { --color-bg-base: rgb(242,240,213); }
.l-sidebar { backdrop-filter: blur(var(--blur-sm)); }
```

1. **Flutter 没有 CSS 引擎。** 引入 `csslib` 解析后，还得自己实现级联、选择器匹配、盒模型 —— 等于在 Flutter 上重写一个浏览器渲染子集。
2. **选择器与 DOM 强绑定。** `.l-sidebar` 依赖 MusicFree 自己的 class 命名，我们的 widget 树根本没有这些 class，翻译不可判定。
3. **它实际只覆盖 `:root` 变量。** 我抽样了该仓库 60 个主题，**全部**只设 `:root` token + 一句 `backdrop-filter`。真正有信息量的只有那 35 个变量和一个 `--bg-image`。

**所以：我们复刻它的"信息量"，不复刻它的"语法"。** 把 35 个语义 token 变成一等公民的 JSON 字段，表达能力还更高（它没有间距、没有字体、没有圆角）。

如果之后仍想接它，写一个 `mftheme → JSON` 的一次性导入器即可（约 200 行：正则抽 `:root` 变量 → 映射到我们的 token 名）。**导入器是桥，不是地基。**

---

## 3. Token 设计（L1）

采用**三层 token 体系**，这是业界（Material 3 / Tailwind / Figma Variables）的最优实践：

```
Primitive（原始值）  →  Semantic（语义）  →  Component（组件）
#F2B749                 color.brand            playerBar.background
rgba(0,0,0,.06)         color.surface          sidebar.itemSelected
```

- **皮肤作者只允许碰 Semantic 层。** 这是保证"任何皮肤都不会把 UI 弄坏"的核心约束。
- Primitive 由 Semantic 推导，Component 由 Semantic 推导，都不暴露给作者。
- 好处：官方新增一个组件，只要它用 Semantic token，**所有已有皮肤自动适配**，作者零工作量。

### 3.1 语义 Token 清单（v1，约 40 个）

参考 MusicFree 的覆盖面 + M3 的完备性，裁剪成 Flutter 真正需要的：

```jsonc
{
  "color": {
    "background":      { "base", "elevated", "sunken", "overlay" },
    "surface":         { "base", "hover", "active", "selected" },
    "brand":           { "base", "hover", "muted", "onBrand" },
    "text":            { "primary", "secondary", "muted", "disabled", "onBrand" },
    "border":          { "subtle", "default", "strong", "focus" },
    "status":          { "danger", "warning", "success" }
  },
  "radius":  { "sm", "md", "lg", "full" },
  "spacing": { "xs", "sm", "md", "lg", "xl" },
  "typography": { "family", "scale", "weightBody", "weightTitle" },
  "elevation": { "sm", "md", "lg" },
  "effects":  { "blur": 0, "glassOpacity": 1 },
  "background": { "image", "fillMode", "overlay", "overlayOpacity" }
}
```

### 3.2 皮肤清单文件 `theme.json`

```jsonc
{
  "schemaVersion": 1,
  "id": "official.dark",
  "name": "Robyne 暗色",
  "author": { "name": "Robyne", "url": "https://..." },
  "version": "1.0.0",
  "description": "默认暗色皮肤",
  "preview": "preview.webp",
  "tags": ["dark", "minimalist"],
  "mode": "dark",
  "tokens": { },
  "layout": { },
  "assets": { "background": "bg.webp", "font": "Inter.ttf" }
}
```

**为什么用 JSON 而不是 CSS：**
1. Flutter 原生可解析，无需 CSS 引擎，零歧义。
2. 可以被 GUI 编辑器直接读写（面向非程序员作者）。
3. 可以做严格的 JSON Schema 校验 + 类型安全映射。
4. 未来要导回 CSS 给 MusicFree 用，也就是一次 Map → 字符串的序列化。

---

## 4. Layout 设计（L2）—— 真正的"更自由"

这是超越 MusicFree 的地方。**核心手法：命名区域（Named Regions）+ 声明式覆盖 + 默认兜底。**

### 4.1 先定义区域契约

```dart
enum ThemeRegion {
  sidebar,
  topBar,
  content,
  playerBar,
  nowPlaying,
  miniPlayer,
}
```

每个区域官方提供一个**默认实现**。皮肤可以选择性覆盖。

### 4.2 三种自由度（按作者能力分级）

**Level 0 — 只要调色（占 90% 作者）**
只写 `tokens`，不写 `layout`。官方骨架 + 你的配色。**手机桌面都对。**

**Level 1 — 调整参数（不改结构）**

```jsonc
"layout": {
  "sidebar": { "position": "left", "width": 240, "collapsible": true, "labelMode": "all" },
  "playerBar": { "position": "bottom", "height": 72, "showLyrics": true }
}
```

**Level 2 — 重排区域（改结构，不写代码）**

```jsonc
"layout": {
  "desktop": { "slots": ["sidebar", "topBar", "content", "playerBar"] },
  "mobile":  { "slots": ["topBar", "content", "miniPlayer"] },
  "content": { "listStyle": "card" }
}
```

**Level 3 — 自定义视图（进阶，用现有 QuickJS 运行时）**
复用你已经写好的 QuickJS 插件运行时，让皮肤提供一个返回 widget 描述的 JS 函数。但这是 L2 之后的独立阶段，且安全成本高。

> **建议：v1 只做 Level 0 + Level 1。** Level 2 的"重排"在移动端约束下容易做出丑东西，先把 L1 打磨到位，让生态长起来，再根据真实需求决定是否放开 L2。Level 3 短期不做。

### 4.3 多端的关键：布局按形态分叉

**Token 全局共享，Layout 按 formFactor 分叉。** 这是整个方案解决多端的支点：

```jsonc
"layout": {
  "desktop": { },
  "mobile":  { }
}
```

官方提供 `layout.desktop` 和 `layout.mobile` 两套默认值。皮肤只覆盖想改的那个形态，另一个自动继承默认。

运行时由 `MediaQuery` 尺寸断点决定用哪套：
- < 600dp → mobile
- 600 ~ 1024 → tablet（可复用 desktop 或 mobile）
- > 1024dp → desktop

---

## 5. 运行时架构

```
+---------------------------------------------+
|  Feature Pages（业务 UI，不感知皮肤）          |
|  search / library / player / settings ...    |
|  只用 ThemeTokens.of(context)，绝不写死值      |
+----------------+----------------------------+
                 | 读 token / 请求 region
+----------------v----------------------------+
|         ThemeRuntime（新增 core 层）          |
|  +--------------+  +---------------------+  |
|  | TokenResolver|  |  RegionRegistry     |  |
|  | 皮肤JSON→Tokens| |  区域→默认Widget   |  |
|  +--------------+  +---------------------+  |
|  +--------------+  +---------------------+  |
|  | ThemeLoader  |  |  FormFactorResolver |  |
|  | 目录/zip/内置 |  |  desktop/mobile     |  |
|  +--------------+  +---------------------+  |
+---------------------------------------------+
```

**分层落位（契合你现有 core/features/shared 结构）：**

```
lib/
  core/theme/                        <- 新增
    domain/
      theme_package.dart             # 皮肤包模型
      theme_tokens.dart              # Token 模型（不可变 + copyWith）
      theme_layout.dart              # Layout 模型
      theme_manifest.dart            # theme.json 解析
      theme_repository.dart          # 抽象接口
    infrastructure/
      builtin_theme_loader.dart      # 内置皮肤（assets/themes/）
      file_theme_repository.dart     # 用户皮肤目录
      theme_manifest_parser.dart     # JSON -> 模型（含校验）
      token_resolver.dart            # Token -> Flutter ThemeData
      mftheme_importer.dart          # 可选：MusicFree 兼容导入
    application/
      theme_controller.dart          # Riverpod 控制器
      theme_providers.dart
  app/
    theme_scope.dart                 # InheritedWidget 提供 tokens
    shell/                           # 从 router.dart 抽出的骨架
      desktop_shell.dart
      mobile_shell.dart
      region_registry.dart
  assets/themes/
    official-light/theme.json
    official-dark/theme.json
```

**与现有代码的衔接点：**
- `lib/app/app.dart` 现在是唯一写死颜色的地方（2 处 `Color(0x...)`）-> 改为从 `themeController` 读。
- `lib/app/router.dart` 的 `RobyneShell` 现在把 `NavigationRail` 和 `PlayerBar` 硬编码在 build 里 -> 拆成 `DesktopShell` / `MobileShell`，由 `RegionRegistry` 按 formFactor 选择。
- `UserSettings` 增加 `activeThemeId` 字段，走现有 `settings_repository` 持久化。

---

## 6. 皮肤包格式与分发

**包格式：`.rtheme`（其实就是 zip，与 MusicFree 的 `.mftheme` 同构）**

```
mydark.rtheme
├── theme.json          # 必须
├── preview.webp        # 预览图（<=500KB）
├── assets/             # 背景图、字体
│   └── bg.webp
└── LICENSE
```

**分发的三个阶段：**
1. **v1：本地导入。** 从文件选择器选 `.rtheme` 或文件夹 -> 解压到 `appSupport/themes/<id>/`。复用你已有的 `file_picker` 和 `local_file_store`。
2. **v2：主题市场。** 托管一个 `index.json` 清单（id / version / downloadUrl / hash / tags / preview），App 内浏览下载。结构可直接照搬 MusicFree 的 `publish.json` 设计 —— 那部分它做得不错。
3. **v3：在线更新。** 清单带 `hash` 做差分，更新只下变化。

**安全：** 皮肤是**纯数据**（JSON + 图片 + 字体），没有可执行代码，天然安全。这是相比"皮肤能跑 JS"方案的最大优势 —— **不要轻易放弃它**。若未来开 Level 3，必须走 QuickJS 沙箱。

---

## 7. 默认 UI 即内置皮肤

**三个内置皮肤，全部用同一个 JSON 格式：**

| id | 说明 |
|---|---|
| `official.light` | 亮色，M3 风格 |
| `official.dark` | 暗色 |
| `official.dynamic` | 从封面提取主色（Material You 思路） |

它们**放在 `assets/themes/`，随 App 打包，走和用户皮肤完全相同的加载器**。区别仅仅是 `ThemeLoader` 多一个"内置源"。

**为什么必须这样：**
- 官方皮肤即是**最好的文档** —— 作者照着抄就能写。
- 天然形成**回归测试** —— 官方皮肤挂了，CI 立刻发现。
- 骨架演进时，官方皮肤是**第一批被验证的消费者**，不会有"内部 API"和"公开 API"割裂。
- 回答"给皮肤作者打样"的诉求：**打样不是写篇文档，而是让官方 UI 本身成为一份可运行、可复制的样例。**

---

## 8. 实施路线（建议分 4 个 PR）

**PR1 — Token 地基（不动布局，风险最低）**
- 新增 `core/theme/domain` 模型 + `theme_manifest_parser`
- `official-light` / `official-dark` 两个内置皮肤
- `TokenResolver` -> `ThemeData`
- `app.dart` 接上；`UserSettings` 加 `activeThemeId`
- **验收：切换内置皮肤，全 App 配色随之变化，无写死颜色残留**

**PR2 — 皮肤管理 UI + 本地导入**
- 设置页新增"皮肤"分区：列表、预览、切换、删除
- `.rtheme` / 文件夹导入（复用 `file_picker`）
- **验收：导入一个第三方皮肤并切换成功**

**PR3 — Layout 层（Level 1）**
- `RobyneShell` 拆 `DesktopShell` / `MobileShell`
- `RegionRegistry` + `layout` 参数覆盖
- **验收：同一皮肤在 Windows 和 Android 各自正确渲染；改 `sidebar.width` 生效**

**PR4 — 打样与生态**
- 补齐官方皮肤到 3~5 个（含一个"炫技"的，展示背景图 + 模糊 + 玻璃拟态）
- 写 `THEME_AUTHORING.md` + JSON Schema
- 可选：`mftheme` 导入器

---

## 9. 与诉求逐条对齐

| 诉求 | 方案回应 |
|---|---|
| 用户自行设计 UI | L1 调色（人人可做）+ L2 布局参数（进阶）；JSON 可被 GUI 编辑器读写 |
| 漂亮的默认 UI | 官方皮肤用同一格式，且是社区样板 |
| 默认 UI 也用这套 | 强制：内置皮肤 = 普通皮肤，零特权 |
| 多端运行 | Token 全局共享 + Layout 按 formFactor 分叉 |
| 抽成一个层便于接入 | 抽成 **两个正交层**（Token / Layout），接入点只有 `ThemeScope` |
| 兼容 MusicFree | 不做地基，保留 `mftheme` 导入器作为桥（可选） |
| 比它更自由 | 补上它没有的：间距/圆角/字体 token、布局参数、多端分叉、GUI 可编辑 |

---

## 10. 需要拍板的三件事

1. **L2 深度**：v1 只做 Level 0+1（推荐），还是直接上 Level 2 区域重排？
2. **皮肤格式**：JSON（推荐，可 GUI 编辑）还是沿用 CSS/Dart 代码？
3. **GUI 编辑器**：本期是否要做一个可视化调色器（token 可视化编辑 + 实时预览）？这是"用户自行设计"体验的分水岭，但工作量约等于 PR1+PR2。

---

## 附：为什么不用 Flutter 原生 ThemeExtension 就够了

有人会问：Flutter 不是有 `ThemeData` 和 `ThemeExtension` 吗？

- `ThemeData` 是给**应用开发者**在编译期配的，字段是 M3 强语义的，无法承载"作者任意命名 + 覆盖 + 多端分叉"。
- `ThemeExtension` 适合传自定义 token，但**不解决加载、校验、持久化、区域骨架**。

**正确姿势：皮肤 JSON -> `TokenResolver` -> 生成 `ThemeData`（含自研 `ThemeExtension`）。**
`ThemeData` 负责喂给 Flutter 内置组件（按钮、输入框），自研 extension 负责喂给你的业务组件。两者都由同一份 Token 派生，**单一数据源**。
