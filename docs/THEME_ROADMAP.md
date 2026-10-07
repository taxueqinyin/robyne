# Robyne 皮肤系统 · 正式规划

> 状态：**阶段 1–3 已完成，阶段 4 已决定不做** · 当前工作是收尾与持续调优
> 替代 `THEME_DECISIONS.md`（那份的 Q1「本期只做 L0+L1」建议已被推翻）
> 面向：**后续可能由其他 AI / 其他会话接手**，故每一项都写明依据、文件位置和验收标准
> 前置文档：`ADR-001-responsive-window-size-class.md`、`THEME_LAYER_DESIGN.md`、`THEME_AUTHORING.md`
>
> **多端（桌面 / 移动端）如何处理**：浓缩在 **D4 / D6 / D7** 三条决策，汇总说明见 **§5**。

---

## 0. 项目定位（决定一切取舍的前提）

**Robyne 是开源玩票项目，不是商业软件。** 这直接推导出两条与商业软件相反的原则：

1. **自由优先于护栏。** 极客用户要能改布局、改界面、换图、换色。宁可让用户做出难看的东西，也不要因为「怕难看」而锁死能力。
2. **官方 UI 就是旗舰皮肤。** 它的存在目的不是「给用户一个默认」，而是**证明这套系统的自由度和上限**。

由此确定的总目标：

> **一个完备的皮肤系统（可调布局 / 界面 / 图片 / 颜色）+ 一个旗舰音乐量级的官方默认皮肤，
> 后者作为系统能力的展示示范。**

---

## 1. 已确定的决策

### D1 · 三层自由，对应用户分层 【已定】

用户的直觉本身就是最好的架构分层，直接照它设计：

| 层 | 面向 | 能力 | 当前状态 |
|---|---|---|---|
| **L0 调色** | 所有人 | 颜色 / 圆角 / 间距 / 字体 / 背景图 / 模糊 | ✅ 已可用 |
| **L1 旋钮** | 普通用户 | 皮肤声明 `settings`，用户在设置页拖滑块改，**不改 JSON** | ✅ 已可用 |
| **L2 布局** | 极客 | 命名区域重排 + 尺寸比例 + 区域风格 | ✅ 已可用（改 JSON + 热重载） |
| ~~L3 脚本~~ | — | `theme.js` 输出 JSON | ❌ **明确不做** |

**L3 放弃的理由**（尽管项目已有 QuickJS 运行时 `lib/features/plugin/infrastructure/quickjs_plugin_runtime.dart`）：
`THEME_DECISIONS.md:14` 的原则是对的——**让 JS 产出 JSON，不让 JS 取代 JSON**。JSON 覆盖 95% 需求；脚本层带来皮肤崩溃、性能问题、安全审计负担，在开源项目里是无底洞。

### D2 · L2 的能力边界 【已定 · 用户已确认】

**允许**：重排已有区域、调区域尺寸（主轴比例）、换区域风格（枚举）。
**不允许**：

- 隐藏或新增区域（`content` 永远存在，否则 App 无法使用）
- 塞入自定义 widget / 任意 widget 树（即不做完整 SDUI）
- 指定绝对像素尺寸（一律主轴比例，见 D4）

这样既能玩出花，又保证**没有皮肤能把 App 做成打不开**。

### D3 · 实施顺序：系统与旗舰皮肤锁步推进，不是先后 【已定】

`THEME_LAYER_DESIGN.md:19` 已立原则：**默认 UI 不是特例，它就是内置皮肤包**。既然如此，「完备的皮肤系统」和「旗舰级官方皮肤」就是同一件事的两面，不是一个先一个后。

**理由**：token 清单与区域契约只有在被一个真实、复杂、有审美要求的 UI 撑过一遍之后，才知道定得对不对。若先抽象设计系统再写 UI，写到一半必然发现「导航栏渐变没地方表达」「歌词高亮没地方放」，然后回头改 token —— 返工。

**所以**：旗舰级 UI 不是系统的「应用」，它是系统的**规格来源和唯一压力测试**。

### D4 · 尺寸一律主轴比例，不用绝对像素 【已定】

延续 `ADR-001` 决策 D4。皮肤的布局尺寸声明为**主轴比例**（`0.18` = 18%），运行时按视口换算并 clamp。

护栏：
- 比例 clamp 到 `0.05 – 0.40`
- 未知 slot / 未知区域名 → 回退 baseline，不报错
- `content` 区域不可被压缩到 0

这条同时解决了「桌面调的宽度在手机上吃掉整个屏幕」的问题。

### D5 · 官方皮肤必须能被一键复制成第三方皮肤 【已定】

验收标准：`assets/themes/` 下任一内置皮肤，可以直接拷到用户目录 `themes/<id>/` 下变成用户皮肤，且行为完全一致。这是「零特权」原则的可执行检验。

**已核实的两个阻碍**（阶段 1 需修）：

**阻碍 1 · 内置皮肤优先，同名用户皮肤被遮蔽** 🔴

`theme_controller.dart:174` 的 `_CompositeThemeRepository.loadTheme`：

```dart
final builtIn = await _builtIn.loadTheme(id);
if (builtIn != null) {
  return builtIn;          // ← 同名用户皮肤永远拿不到
}
```

→ 用户把 `official.dark` 复制成自己的皮肤并保持同 id，会被内置版本静默遮蔽（`listThemes` 里两条都在，但切换时永远加载内置的）。修法：用户皮肤优先，或导入时强制改 id。

**阻碍 2 · 内置 / 用户两套 asset 路径规则不一致** 🟡

- 内置：`theme_asset_resolver.dart:86` → `assets/themes/${id.replaceAll('.', '-')}` → 目录 `official-dark`（**横线**）
- 用户：`theme_repository.dart:107` → `_sanitizeId(theme.id)` 保留 `.` → 目录 `official.dark`（**点号**）

当前靠 `theme.source` 分流所以不暴露，但两条规则并存是隐患：一旦 `source` 与实际加载路径不一致（例如内置皮肤被复制到用户目录），asset 就会解析失败。建议统一为一套 id→目录 的映射函数。

### D6 · 区域集合按形态分别定义，而非一套通用集合 【已定 · 修正 D3 的内部矛盾】

**这是多端问题的核心决策，也是最容易被做错的一处。**

`ADR-001` 已确立：布局由 **Window Size Class（宽 × 高双维）** 决定，不由 platform 决定。
由此直接推出：**区域集合必须按形态分别定义**。试图设计一套「桌面手机通用」的区域集合，是上面 OPEN-1 初版假设的错误所在。

**修正后的模型**：

```
RobyneRegion（区域身份，跨形态稳定）
  ├─ topBar      ─ 仅桌面有意义的顶部栏（搜索 / 窗口控制）
  ├─ navBar      ─ 主导航（桌面侧栏 / 手机底部 tab）
  ├─ content     ─ 内容区（**每个形态都必须存在**）
  ├─ playerBar   ─ 播放条
  └─ queue       ─ 队列面板（桌面可与 content 并列，手机上进 content）

RobyneSlot（槽位，按形态选择）
  desktop:  top / left / center / right / bottom
  mobile:   top / bottom / center          ← 手机没有左右槽位
```

**为什么分成「区域」+「槽位」两层**：

- 区域是**身份**（我是导航栏），跨形态稳定 —— 这样「把 navBar 挪到右边」在两种形态上都是同一个语义操作
- 槽位是**摆法**（我放在哪），按形态受限 —— 手机上不存在 `left` 槽位，因为 400dp 宽放不下侧栏

**皮肤只声明槽位与比例，不发明区域**：

```jsonc
"layout": {
  "desktop": {
    "arrangement": [
      { "region": "topBar",    "slot": "top",    "size": 0.08 },
      { "region": "navBar",    "slot": "left",   "size": 0.18 },
      { "region": "content",   "slot": "center" },
      { "region": "playerBar", "slot": "bottom", "size": 0.10 }
    ]
  },
  "mobile": {
    "arrangement": [
      { "region": "content",   "slot": "center" },
      { "region": "navBar",    "slot": "bottom", "size": 0.09 },
      { "region": "playerBar", "slot": "bottom", "size": 0.09 }
    ]
  }
}
```

**关键约束（护栏）**：

1. `content` 在每个形态的 arrangement 里都必须存在，否则回退 baseline
2. 槽位必须是该形态允许的取值；不合法 → 该条目回退 baseline，不报错
3. 同一槽位内多个区域按数组顺序排列（如 mobile 的 `bottom` 里有 navBar 和 playerBar）
4. 皮肤**不能新增区域**（D2），只能重排已有区域
5. 尺寸是主轴比例（D4），不是像素

**继承规则**（降低作者负担）：皮肤只写想改的形态，另一个形态继承官方默认 arrangement。这与 `THEME_AUTHORING.md:165` 承诺的「只写你想改的那个形态」保持一致——而那个承诺目前因为 layout 是死字段尚未兑现（缺陷 D），本决策是让它真正兑现的方式。

### D7 · 多端自适应是应用的责任，皮肤只给意图 【已定】

自适应**不推给皮肤作者**。作者写的是「导航栏放左边占 18%」，应用负责决定「当前是哪种形态、这个比例换算成多少 dp、放不下时怎么退化」。

具体分工：

| 问题 | 谁负责 | 机制 |
|---|---|---|
| 当前是桌面还是手机形态 | 应用 | `WindowSizeClass.of(context)`（ADR-001） |
| 该形态用哪套 arrangement | 应用 | 读 `layout.<formFactor>.arrangement` |
| 比例换算成实际 dp | 应用 | `size × 视口主轴长度`，再 clamp |
| 换算后仍放不下 | 应用 | 按优先级丢弃（见下） |
| 区域内部怎么排（如 list vs grid） | 皮肤 | `content.style` 枚举 |

**退化优先级**（空间不足时）：`queue` → `topBar` → `playerBar` 压缩 → `navBar` 收成图标条 → `content` 永不牺牲。

这保证：**任何皮肤在任何形态下都不会做出打不开 App 的布局。**

---

## 2. 决议事项（已关闭）

### ✅ OPEN-1 · 区域集合与形态映射 【已由视觉设计文档关闭】

> **已修订**：初版假设了一套「桌面手机通用」的扁平区域集合，该假设**已作废**——
> 它既与 D3 的 `layout.desktop.regions` / `layout.mobile.regions` 双套写法自相矛盾，
> 也把 `nowPlaying` 错误地列为了常驻区域（实际它是全屏页，生活在 `content` 内部）。
> 现按 **D6** 的「区域 + 槽位」两层模型重新表述。

**当前候选区域**（`RobyneRegion`，需视觉设计文档确认/调整）：

| 区域 | 桌面 | 手机 | 说明 |
|---|---|---|---|
| `topBar` | 常见（top） | 通常不出现 | 搜索 / 窗口控制 |
| `navBar` | 侧栏（left/right） | 底部 tab（bottom） | 主导航 |
| `content` | 必有（center） | 必有（center） | 内容区 |
| `playerBar` | bottom | bottom | 播放条 |
| `queue` | 可与 content 并列（right） | 进 content | 队列面板 |

**视觉设计文档给出的答案**（`UI_DESIGN_SPEC.md`）：
1. 区域集合**就是这 5 个**。没有独立的「推荐 banner 区」——banner 是 `content.style`
   的一个取值（§2.5）；歌词是全屏播放页内部的事，不是常驻区域
2. `topBar` 在移动端**完全不出现**，搜索入口收进内容区顶部（§2.2）
3. 默认比例见 §2.1 / §2.2 的 arrangement，与本文 §4 官方默认一致

**接手者注意**：OPEN-1 已关闭，阶段 2 / 3 均已完成。当前剩余的只有 §6 工作清单里
列明的收尾项，以及阶段 4 中保留的那一项低优先级 lint。

### ✅ RESOLVED-2 · L2 边界 — 用户已接受 D2 所述边界。

---

## 3. 现状盘点（已核实，供接手者直接采信）

### 3.1 已经做对的部分（不要动）

| 能力 | 位置 | 说明 |
|---|---|---|
| 语义 token 体系 | `core/theme/domain/theme_tokens.dart` | ~40 个 token，7 组（color / radius / spacing / typography / elevation / effects / background） |
| Token → ThemeData | `core/theme/infrastructure/token_resolver.dart:124` | 单一来源，覆盖 14 类组件主题 + `RobyneTheme` extension |
| 明暗自适应 | `token_resolver.dart:37` `adaptToBrightness` | 不匹配皮肤原生亮度时只换中性色，保留品牌色 |
| 容错解析 | `theme_manifest_parser.dart` | 非法值收敛、缺失取 baseline、非有限数拒绝 |
| 路径加固 | `theme_path_guard.dart` | Zip Slip / 目录穿越 / UNC / 绝对路径 全防 |
| 体积预算 | `theme_asset_resolver.dart:23` `theme_importer.dart:146` | 单资源 500KB、整包 10MB、归档条目 1000 |
| 用户旋钮 | `theme_package.dart:136` `token_patcher.dart` | 5 种类型，按 `target` 点号路径写回 token |
| `.rtheme` 导入 | `theme_importer.dart` | 目录 / zip / 多皮肤目录 三种形态 |
| 响应式地基 | `core/layout/window_size_class.dart` | ADR-001 已落地，见 §5 |
| 图标可重绘 | `theme_icons.dart` + `presentation/theme_icon.dart` | 封闭 18 槽位；`codePoint` / 自带图标字体 `glyph` / 位图 `image` 三种画法，含 `active*` 选中态变体；无效声明一律回退内置字形 |
| 氛围层 | `components.ambient` + `presentation/theme_ambient.dart` | 封面取主色（16px 解码均值，按 URL 缓存）→ content 顶部柔光；默认关闭，纯装饰不参与布局与可读性 |
| 字体角色 | `theme_tokens.dart` `ThemeTypography` | 除 `scale` 外五个按角色命名的字号（页面标题 / 区块标题 / 列表主 / 列表次 / 标签）+ 标签字重，与设计稿 §3.3 一一对应 |
| 导航入口排序 | `theme_navigation.dart` `applyOrder` | `desktopOrder` / `mobileOrder`，**前缀**语义；隐藏优先于排序 |
| 皮肤导航溢出 | `theme_navigation.dart` `ThemeOverflowSlot` | `none` / `moreTab` / `homeHeader`；手机默认 `moreTab`，保证目的地不会因为装不下而消失 |

### 3.2 已确认的缺陷（阶段 1 要修）

**缺陷 A · 皮肤自带字体实际不生效** 🔴 真 bug

`theme.json` 的 `assets.font` 被解析（parser:302）、被路径加固、被计入体积预算（`theme_importer.dart:214`），但**全项目没有任何 `FontLoader` 调用**（已 grep 确认）。
`typography.family`（parser:248）只接受系统已安装字体名（`RegExp(r'^[A-Za-z0-9 _-]+$')`），也会走 `ThemeData.fontFamily`（resolver:136）。
→ **结论：皮肤只能指定系统字体，不能自带字体文件。**

修法：在皮肤加载后对 `assets.font` 调 `FontLoader.loadFromBytes`（需 `rootBundle` 读内置 / `File` 读用户皮肤），并把 family 名注入 `ThemeData.fontFamily`。注意字体加载是异步的，需要 `ThemeController` 持有加载结果。

**缺陷 B · 组件不消费 Robyne 语义 token** 🔴 架构缺口

`RobyneTheme` 全项目只在 2 处被读取：
- `theme_settings_tab.dart:155`
- `theme_setting_control.dart:32`

**所有 feature 页面都写 `Theme.of(context).colorScheme.xxx`。** 目前能工作，是因为 token 会流进 colorScheme；但 colorScheme 的语义角色是 Material 固定的那十几个，旗舰级 UI 真正有辨识度的东西**没有落脚点**：

- 导航栏渐变
- 歌词当前行 / 非当前行
- 卡片悬浮态
- 列表选中态
- 播放条背景

这些东西不给组件级 token，写 UI 时就只能硬写，皮肤承诺随即断裂。

**缺陷 C · 硬编码漏网** 🟡 已定位

`Colors.*`（feature 层，不含歌词窗口）：
- `discover_page.dart:653` — `Colors.white`
- `discover_page.dart:775` — `Colors.white`

裸 `BorderRadius.circular(数字)`：
- `discover_page.dart:476, 654, 656, 663, 776`
- `settings_page.dart:609, 669, 715, 721, 849`
- `theme_settings_tab.dart:161, 323`
- `artwork_view.dart:169`
- `desktop_lyric_window.dart:643`

**缺陷 D · layout 字段是死字段** ✅ **已修复（并已删除字段）**

原状：`theme_layout.dart` 声明的字段中只有 `desktop.sidebar.{width,labelMode,position}`
被真实读取；`desktop.playerBarHeight` / `desktop.playerBarPosition` /
`mobile.navigation` / `mobile.playerBarHeight` / `mobile.playerBarCompact` /
`content.listStyle` / `content.density` 全部无人读取，
`THEME_AUTHORING.md` 承诺的 `"mobile": { "playerBarHeight": 56 }` 根本不生效。

**修复方式**：按本文一贯决定（「不要把旧字段接活」），arrangement 落地后这些字段被
**删除**而非接活：

- 删字段：`ThemeDesktopLayout` 只留 `arrangement`；`ThemeMobileLayout` 只留 `arrangement`
- 删类型：`ThemeSidebarLayout` / `ThemeSidebarPosition` / `ThemeRailLabelMode` /
  `ThemePlayerBarPosition` / `ThemeMobileNavigation`
- 删声明：三个内置皮肤 `theme.json` 里的 `sidebar` / `playerBarHeight` /
  `playerBarPosition` / `navigation` / `playerBarCompact` 段
- `content.listStyle` / `content.density` 是**新模型**的一部分，已生效（见 §4 阶段 3），
  不属于被删的旧字段

保留这些字段的真实代价：皮肤可以同时声明「72dp 播放条」和「0.09 的 arrangement 比例」，
其中一个会被静默忽略——两个真源比一个死字段更糟。

**缺陷 E · `schemaVersion` 被声明但未使用** 🟡

三个内置 `theme.json` 都写了 `"schemaVersion": 1`，但 parser 从不读它（grep 确认 `lib/core/theme` 下无引用）。将来 token 演进时需要它做迁移判断，建议阶段 1 顺手读取并存到 `ThemePackage`。

**缺陷 F · 桌面歌词窗口自成一套颜色** 🟡

`desktop_lyric_window.dart` 大量 `Colors.white.withAlpha(...)`（642/644/671/696），完全绕开 token 系统。
`THEME_DECISIONS.md:49` 的建议（Q2 选 A：v1 只让 `fromAccent` 取皮肤的 `color.brand.base`）仍然有效，成本一行。

### 3.3 现有内置皮肤

`assets/themes/`：`official-light`、`official-dark`、`official-midnight`。
三者都带 `layout` 段（含死字段），都带 `settings` 旋钮（brandColor / cornerRadius）。

---

## 4. 路线图

### 阶段 1 — 地基 ✅ **已完成**（2026-03-05）

> 全部为新增 + 机械改动，**不动任何业务 UI 的行为**。

| # | 内容 | 状态 |
|---|---|---|
| 1 | 组件级 token：`core/theme/domain/theme_components.dart` | ✅ |
| 2 | 修缺陷 A（皮肤自带字体） | ✅ |
| 3 | 立铁律并**用测试卡住**（见下） | ✅ |
| 4 | 清缺陷 C 的硬编码 | ✅ |
| 5 | 补 `schemaVersion` 读取（缺陷 E） | ✅ |
| 6 | 歌词窗口 accent（缺陷 F） | ✅ **原本就已满足** |
| 7 | 修 D5 两个阻碍 | ✅ 追加 |

**完成时的实际落地**：

1. **组件 token** 新建 `lib/core/theme/domain/theme_components.dart`，
   6 组共 18 个字段：`navBar`(4) / `playerBar`(4) / `lyric`(3) / `card`(3) / `list`(2) / `motion`(3)，
   外加 `ThemeGradient`（多色标渐变，支持单色与数组两种写法）。
   同步改了 4 处：`theme_tokens.dart`、`theme_manifest_parser.dart`、`token_patcher.dart`、`token_resolver.dart`。

2. **字体**（缺陷 A）新建 `lib/core/theme/infrastructure/theme_font_loader.dart`，
   经 `FontLoader` 注册皮肤自带字体；新增
   `activeSkinFontFamilyProvider` / `resolvedThemeTypographyProvider` 接入管线。
   单字体上限 2MB，加载失败静默退回平台字体。

3. **铁律** 用 `test/theme_hardcode_guard_test.dart` 扫描 `lib/features/`
   禁止 `Colors.*` 与裸 `BorderRadius.circular(数字)`。
   **未引入 `custom_lint` 依赖**（当前 pubspec 不含它）；改用测试卡，零新依赖、CI 可执行。
   若日后接手者想换成 analyzer lint，`custom_lint` 是正路，但需加依赖。

4. **硬编码** 清理了 discover / artwork_view / settings_page / theme_settings_tab
   共 9 处。圆形/胶囊形（色板圆点、pill）改用 `radius.full` 而非字面量 18/16——
   它们在语义上就是"全圆角"，不该写死数字。

5. **`schemaVersion`** 已读入 `ThemePackage`，未知/缺失按 1 处理，更大的值向下收敛。

6. **歌词窗口 accent**：核实后发现 `DesktopLyricTheme.fromTokens` 早已读取
   `color.brand.base`，且 `lyrics_providers.dart:99` 已接线 —— **无需改动**。
   歌词窗口自身的大量 `Colors.white.withAlpha(...)` 仍在，但按
   `THEME_DECISIONS.md` Q2 的选择（v1 不动歌词窗口）保留。

7. **D5 两个阻碍**已修：`loadTheme` 改为用户皮肤优先；
   统一 id→目录 映射到 `ThemePathGuard.directoryName()`。

**验收结果**：`flutter analyze` 零 issue；**201 个测试全绿**（基线 178，新增 23）；
三个内置皮肤未声明组件 token，故视觉效果不变（回归通过）。

**已知遗留**（不影响阶段 2）：
- 内置皮肤尚未使用任何组件 token —— 它们将在阶段 2 随旗舰 UI 一起用上
- `test/theme_hardcode_guard_test.dart` 目前把 `desktop_lyric_window.dart`
  列入 allowlist（依据 `THEME_DECISIONS.md` Q2 的"v1 不动歌词窗口"）。
  若日后把歌词窗口纳入皮肤系统，记得把它移出 allowlist。

### 阶段 2 — 旗舰 UI（与阶段 1 交叉进行）✅ **已完成**

**原阻塞已解除**：视觉设计文档 `docs/design/UI_DESIGN_SPEC.md` 已产出，OPEN-1 的
三个问题（区域集合是否就是这 5 个、`topBar` 在手机上如何处理、各形态默认比例）
在 §2.4 / §3.2 中已有答案，区域集合据此定稿。

- 按视觉设计文档实现 旗舰级 UI
- **每一行都走 `RobyneTheme.of(context)`**，不得出现 `colorScheme` 直取或硬编码
- UI 从第一天就对着 `RegionRegistry` 写（哪怕此时皮肤还不能覆盖它）
- 响应式遵循 ADR-001（Window Size Class），并落地 D6 的两层模型：
  - 定义 `RobyneRegion` / `RobyneSlot`
  - 为每个形态建立官方默认 `arrangement`
  - **每个形态的 arrangement 都必须包含 `content`**
- 区域内部风格（`content.style`: list / grid / card）此时就接入

**验收（多端）**：
- 三种 size class（400×800 / 800×360 / 1280×900）下均无溢出，沿用
  `test/responsive_layout_test.dart` 的注入方式并扩充到新 UI
- **横屏手机（800×360）必须有可用布局** —— 这是 ADR-001 记录过的主要病症
- 这套 UI 本身是 `assets/themes/` 下的一个内置皮肤，且能通过 D5（一键复制成第三方皮肤）

### 阶段 3 — L2 开放 ✅ **已完成**

**原阻塞已解除**：区域集合已随阶段 2 定稿。

- 区域契约从内部 registry 变成皮肤可覆盖
- `theme.json` 支持 `layout.desktop.arrangement` / `layout.mobile.arrangement`（D6 格式）
- 实现 D7 的分工：应用负责形态判定 / 比例换算 / 空间不足时的退化优先级
- **保存即生效**：监听用户皮肤目录，`theme.json` 或资源改动后去抖热重载（`theme_hot_reload.dart`）
  - 客户端**不做**调色/圆角/布局编辑器；创作者直接用编辑器改 JSON
  - 失败保留上一份可用皮肤，不白屏
- `layout.home.blocks`：旗舰首页区块顺序由皮肤声明（hero / recommendations / recent / queue）
  - **已扩展为按形态分叉**：`layout.home.desktop` / `layout.home.mobile` 各写一份区块序列，
    只写一个形态时另一个继承 `blocks`。旗舰《玄》据此把手机首页做成
    `quickActions → hero → favorites`，桌面做成 `hero → recommendations → recent`
  - 区块集合：`quickActions` / `hero` / `recommendations` / `recent` / `favorites` / `queue`
- 皮肤资源位：`assets.logo` / `assets.avatar` / `assets.hero`，与背景图、字体同一条解析与导出链路
- **界面图标可重绘**：图标是最后一块皮肤碰不到的壳层——侧栏某一行、播放条某个按钮原本
  都是 `Icons.*` 字面量，皮肤只能改颜色改不了形状，差异上限被压在「换色不换形」。
  `icons` 段（`theme_icons.dart` + `presentation/theme_icon.dart`）给出封闭的 18 个槽位，
  三种声明方式：`codePoint`（某字体里的码点）、`glyph`（皮肤自带图标字体
  `assets.icons.font`）、`image`（位图）。护栏：声明无效一律回退内置字形——图标不是装饰，
  播放键必须一直找得到；图标字体族名自动加命名空间，皮肤不能劫持 `MaterialIcons` 之类的
  已有族名，两个皮肤也不会撞族名
  - **《玄》刻意不写 `icons` 段。** 设计稿用的字形与 Material 现有字形是同一个形状
    （发现=指南针、内容库=音符、设置=齿轮），把 `codePoint` 写成同样的值是一份没有效果的
    声明，只会让后来者以为「旗舰在用自定义图标」。能力已经就位：真正的图标字体皮肤
    照 `THEME_AUTHORING.md`「界面图标（`icons`）」的示例写即可，`theme_icons_test.dart` /
    `theme_icon_render_test.dart` 已覆盖「换字形」「选中态变体」「坏声明回退」三条路径
- **氛围层真的存在了**：设计稿 §3.4 把「封面驱动氛围」称为 Robyne 的标志性识别，
  但在此之前整份设计里没有对应 token，也就从没实现过。新增 `components.ambient`
  （开关 / 强度 / 覆盖高度 / 柔化 / 固定色）与 `presentation/theme_ambient.dart`：
  从当前封面取主色（解码到 16px 求平均，按 URL 缓存），在 content 顶部画一层向下衰减的
  柔光。护栏：默认关闭所以老皮肤渲染树不变；纯装饰不参与布局与文字颜色，强度再高也不会
  影响可读性；显式 `color` 优先于封面取色
- **动作节奏不再是死 token**：`components.motion` 此前被解析、导出、往返测试覆盖，
  却没有任何 widget 读它——皮肤声明了节奏而屏幕上什么都不会变。现在它驱动换肤时的
  过渡（`MaterialApp.themeAnimationDuration` / `themeAnimationCurve`），并通过
  `activeThemeMotionProvider` 对其它动画开放
- **`content.style` 不再有死枚举**：`banner` 在枚举里、在 `UI_DESIGN_SPEC.md` §2.5
  里（「推荐横幅」）、在解析器里都存在，但没有任何 widget 分支处理它——皮肤要求横幅却
  静默拿到行列表。现在本地库有真实的横向封面流分支。回归测试按滚动轴断言每种 style
  渲染出**不同的**布局，而不是只断言「不抛异常」——后者对「静默落回行列表」同样会通过
- **`content.style` 按目的地生效**：设计稿 §2.5 的表格是**按页面**给的（本地库
  `list`、发现页 `grid`、推荐横幅 `banner`），而模型只有一个全局值。后果是《玄》为了
  拿到推荐横幅而声明了 `banner`，于是**本地库也变成一屏四个巨型封面**——一个全局值
  无法表达表格里本来就分行的意图。新增 `layout.content.styles.<目的地>`
  （`ThemeContentSurface` 封闭集合）逐页覆盖，全局 `listStyle` 退为默认值。
  护栏：未知目的地与未知值都被忽略，而不是经 `fromName` 的 `list` 兜底变成真实覆盖
- **字体有了角色，不只是整体缩放**：`typography` 此前只有 `scale` 一个粗系数，
  做不到「标题大、标签紧」这种字体性格。新增五个按角色命名的字号
  （`pageTitleSize` / `sectionTitleSize` / `listPrimarySize` / `listSecondarySize` /
  `labelSize` + `labelWeight`），对应 `UI_DESIGN_SPEC.md` §3.3 的五行为。
  未声明的角色用设计稿默认值；字号收敛到 8–96。`scale` 与角色字号**相乘**而非互斥，
  角色是皮肤的表达，`scale` 仍是用户的整体大小调节
- **内容区几何可声明**：设计稿 §3.2 / §4.5 的留白、行高、卡片宽与间距此前是散落在
  各页面里的字面量，皮肤能改一行颜色却挪不动它一个像素——这让「把行距收紧一点」这类
  微调必须改代码。新增 `components.content`（`ThemeContentMetrics`）暴露 gutter /
  rowHeight / cardMinWidth / cardGap / sectionGap，各自带 compact 变体。行内封面尺寸
  跟随行高（70%，收敛 24–56），所以调整行高会带动整套行内比例。量纲上刻意用像素而非
  比例：留白与行高是可用性问题，有正确答案；比例是给**区域**随窗口伸缩用的
- **壳层比例也可声明**：侧栏图标、品牌标识、头像三个尺寸此前是 `router.dart` 里的
  字面量——皮肤能改它们的颜色却改不了大小。现在同样挂在 `components.content` 下
  （`navIconSize` / `logoSize` / `avatarSize`）。`ThemeDensity` 也从「解析了没人读」
  变成真实生效：它是 `rowHeight` 上的一**个系数**（compact 0.85 / regular 1 /
  comfortable 1.2），而不是与 `rowHeight` 竞争的第二套行高
- `content.style` 的 `grid` / `card` / `compact` 都有真实分支：`compact` 用于横屏手机的
  压缩行（封面 32dp、行高 48dp），与设计稿 §4.5 一致
- **首帧不再闪白**：`_placeholder` 改用 `ThemeTokens.darkBaseline()`。此前它用的是
  `baseline()`（浅色）却声明 `mode: dark`，两者矛盾，导致每次冷启动都闪一下已下线的浅色外观
- **壳层文案**：`strings` 段让皮肤声明导航栏 / 顶栏 / 队列面板的文字（`theme_strings.dart`）。
  槽位是封闭集合（`ThemeStringKey`），未知键被忽略、缺失键回退中性默认值。
  这是为了让《玄》能显示中文导航，而不是要把 App 变成多语言系统：没有复数与时区格式化，
  功能页面文案仍归应用所有
- **导航入口**：`navigation.<形态>`（扁平数组）+ `navigation.<形态>Overflow` 让皮肤
   （`theme_navigation.dart`）决定「哪些入口值得出现」「按什么顺序排列」与
   「放不下的入口去哪里」。
   《玄》借此隐藏了侧栏的 `playlists` 行——它正下方的歌单分组是同一目的地，两个入口
   指向同一页面只会显得像两套导航。排序（`navigation.<形态>Order`）是**前缀**而非完整
   排列：皮肤只写它关心的几个，其余保持内置顺序跟在后面，这样老皮肤不会因为写死列表而
   丢掉日后新增的目的地。护栏：只能隐藏入口不能隐藏区域，`settings` 永不可隐藏，
   隐藏优先于排序
- **手机端的溢出入口**：`mobileOverflow: moreTab` 在手机底部 tab 栏末尾加一个「更多」，
   点开是抽屉，列出插件 / 设置 / 下载 / 正在播放等放不下的入口。此前这些目的地只渲染在
   桌面侧栏里，手机上**没有任何入口**（「导入插件根本找不到」就是这个成因）。
   默认值刻意不对称：桌面 `none`（侧栏放得下全部）、手机 `moreTab`，这样手机默认不会
   因为皮肤少声明一个字段就丢目的地；皮肤要极简界面时须显式写 `none`
- **顶栏收敛到设计稿**：搜索框宽度从 620dp 收到 430dp（设计稿的 `.searchbox` 是
  `max-width:430px` 的胶囊），并删除顶栏的队列按钮——播放条已有该入口，两个控件
  意味着两个状态真源
- **下线皮肤的 id 不再被复活**：`BuiltInThemeRepository.loadTheme` 对未注册的 id 返回
  `null` 而不是合成皮肤。此前持久化设置里残留的 `official.light` 会让合成皮肤赢得
  回退，App 一直显示旧的亮色皮肤、《玄》的 tokens 和 strings 全部失效——这是
  「文案还是英文」「当前皮肤叫亮色」两个症状的共同根因
- 旧 `theme_layout.dart` 字段迁移或废弃，同步更新 `THEME_AUTHORING.md`
- **旧 layout 字段已删除**（缺陷 D 收尾）：见 §3.2 缺陷 D。`sidebar.*` /
  `playerBarHeight` / `playerBarPosition` / `mobile.navigation` / `playerBarCompact`
  连同相关枚举全部移除；三个内置皮肤的声明同步清理。理由不是「它们没用」而是
  **它们与 arrangement 构成两个真源**——皮肤可以同时声明 72dp 播放条与 0.09 比例，
  其中一个必然被静默忽略，这比一个死字段更难诊断。
  原测试改写为覆盖 arrangement（继承、非法槽位修复、缺 `content` 回退）
- **阶段 4 已决定不做**：皮肤编辑器取消。编辑由文件热重载承担，分享靠截图。详见 §4

**已隐藏（代码保留）**：客户端内的 L1 旋钮控件与 L2 布局编辑器已从设置页移除。
`ThemeSettingControl`、`ThemeLayoutOverride` 与 `settings_repository` 的
`theme.layout_overrides` 持久化仍然存在且被测试覆盖，只是不再有任何入口渲染它们。
保留的理由是：如果日后 JSON 编辑在某些场景下不够方便，可以据此重新做一个独立的
编辑模式，而不必从零开始；在此之前，皮肤创作者直接改 `theme.json`，客户端热重载。
旗舰《玄》的 `settings` 为空数组，所以即使将来某个入口重新渲染旋钮，它也不会变回
「用户可调」的样子。

**验收（多端）**：
- 把官方皮肤的 `navBar` 从 left 挪到 right、`content` 改成 grid，App 仍完整可用且无溢出
- **只写 `mobile` 的 arrangement 时，桌面保持官方默认**（继承规则生效）
- **写一个「桌面专用」的极端 arrangement，在手机上仍不崩溃**（护栏生效）
- 把 `content` 从 arrangement 里删掉 → 应回退 baseline 且不白屏

### 阶段 4 — 生态 ❌ **已决定不做**

**决定：不做皮肤编辑器。** 原计划的「三种 size class 同时预览」编辑器取消。

理由：

- **编辑工作已经由文件热重载承担**（阶段 3 已落地：`theme_hot_reload.dart` 监听
  `theme.json` 与同级资源，去抖后重载，失败保留上一份可用皮肤）。创作者用自己顺手的
  编辑器改 JSON，保存即生效——这是 §0「自由优先于护栏」最直接的兑现：不强加一个
  我们自己的编辑体验
- **分享靠截图，不靠市场。** 用户想分享皮肤，在社交平台发截图即可。这也意味着
  原计划的「一键分享可信度」问题不存在了：没有市场，就不需要为市场的可信度做预览

因此以下原定项**一并取消**：

- ~~编辑器：三种 size class 同时预览~~
- ~~市场 `index.json` 带 `formFactors` 声明~~
- ~~皮肤卡片显示形态兼容性评级~~

**保留的一项**（它不依赖编辑器，且属于导入安全而非生态）：

- 导入时 lint：arrangement 合法性检查（含每个形态是否含 `content`）。
  这一项其实**已经在解析期做了**（`theme_regions.dart` 的 repair / fallback），
  缺的只是把它从「静默修复」升级为「导入时显式提示」。低优先级，有需要再做

**明确不做**：`mftheme` → JSON 导入器。它是给 MusicFree 生态做桥，不是本项目的地基；
且导入器会引入一整套外部格式的兼容负担，与「JSON 是唯一真源」相冲

---

## 5. 桌面 / 移动端：多端问题在这个路线图里怎么解决

> 本节汇总多端相关决策，避免接手者从各章节里拼凑。

### 5.1 已解决的部分（ADR-001，P0 已落地）

ADR-001「以 Window Size Class 为唯一自适应依据」已落地，P0 六项全部完成：

| 项 | 内容 | 状态 |
|---|---|---|
| P0-1 | `core/layout/window_size_class.dart`，宽高双维 M3 断点 | ✅ |
| P0-2 | NowPlayingPage 紧凑宽度改 Tab，封面/对话框视口收敛 | ✅ |
| P0-3 | 8 处对话框固定宽高改视口收敛 | ✅ |
| P0-4 | PlayerBar 紧凑高度降为 mini bar | ✅ |
| P0-5 | DiscoverPage 单 pane 导航（list-detail） | ✅ |
| P0-6 | QueuePage 紧凑宽度改 Tab | ✅ |

回归测试：`test/responsive_layout_test.dart`，注入 400×800 / 800×360 / 1280×900 三组尺寸断言零溢出。

**这部分解决的是「应用自身的自适应」**：即无论皮肤怎么写，App 骨架在任意视口下都不丢内容。
它已经解决了横屏手机错乱、竖屏歌词消失、对话框溢出等实际病症。

**原定的 P1（让 `layout.mobile.*` 生效）已作废**，理由见缺陷 D —— 那些字段属于 MVP UI 的区域模型，会被新的区域契约取代。

### 5.2 尚未解决的部分（皮肤如何跨形态声明布局）

P0 只解决了「App 自己怎么自适应」，**没有**解决「皮肤作者怎么声明一个跨形态的布局」。
这是阶段 2 / 3 的事，由三条规定：

| 规定 | 内容 |
|---|---|
| **D6** | 区域集合按形态分别定义。`RobyneRegion`（身份，跨形态稳定）+ `RobyneSlot`（摆法，按形态受限）。皮肤写 `layout.desktop.arrangement` / `layout.mobile.arrangement`，只写想改的那个形态，另一个继承官方默认 |
| **D4** | 尺寸是主轴比例不是像素，运行时换算 + clamp（0.05–0.40）。这从根上消除「桌面调的 240dp 侧栏在 360dp 屏幕上吃掉一切」 |
| **D7** | 自适应是应用的责任。应用负责形态判定 / 比例换算 / 空间不足时的退化优先级（`queue` → `topBar` → `playerBar` → `navBar`，`content` 永不牺牲） |

### 5.3 为什么这个组合是对的

把三件事串起来看：

1. **ADR-001** 让 App 骨架自己不出错（已完成）
2. **D6** 让皮肤作者能表达「桌面和手机不一样」（阶段 3）
3. **D7 + D4** 保证作者表达错了也不会毁掉 App（护栏）

**核心判断：多端适配的责任在应用，不在皮肤。** 皮肤只能给「意图」（导航栏放左边占 18%），
不能给「像素」（左边 240dp）。这条是 ADR-001 决策 D4 在皮肤维度的延伸，两者是同一条原则。

### 5.4 一个明确的反面参照

MusicFree 的失败点（`THEME_LAYER_DESIGN.md:17` 已记录）正是：`.l-sidebar` 这种选择器把结构焊死成桌面形状，所以它永远上不了手机。
**不要重蹈覆辙**：任何让皮肤声明具体像素、具体 widget、或一套不分形态的绝对区域摆法的做法，都会把 Robyne 锁死在某个形态上。

---

## 6. 给接手者的工作清单

**当前状态**：**阶段 1 / 2 / 3 均已完成**；阶段 4 已决定不做（详见 §4 阶段 4）。
剩余的只有下面几项收尾工作，以及《玄》与皮肤系统的持续调优。

**剩余收尾项**（均已核实，不是推测）：
1. ~~**缺陷 D 收尾**~~ ✅ **已完成**：`theme_layout.dart` 的旧字段
   （`playerBarHeight` / `playerBarPosition` / `sidebar.*` / `mobile.navigation` /
   `playerBarCompact`）连同 `ThemeSidebarLayout` / `ThemePlayerBarPosition` /
   `ThemeMobileNavigation` / `ThemeSidebarPosition` / `ThemeRailLabelMode` 一并删除；
   三个内置皮肤 `theme.json` 里的对应声明也清掉了。原测试
   （`theme_pr3_test.dart`、`theme_security_test.dart`）改写为覆盖 arrangement
2. 复核 `theme_hardcode_guard_test.dart` 的 allowlist
   （`desktop_lyric_window.dart`）——若歌词窗口要纳入皮肤系统，需移出。
   当前**有意保留**（依据 `THEME_DECISIONS.md` Q2 的「v1 不动歌词窗口」）
3. 内置皮肤补组件 token：三个内置皮肤已带 `components` 段，但旗舰是《玄》。
   是否进一步对齐，取决于内置皮肤是否还要继续维护
4. 导入时 lint 显式化（阶段 4 保留项，低优先级）：arrangement 合法性检查目前在
   解析期静默修复，尚未在导入时提示

**已完成的原「必须等待」项**：视觉设计文档已产出、OPEN-1 区域集合已定稿，
阶段 2 / 3 不再阻塞。

**开工前先读**（避免踩已填过的坑）：
- `lib/core/theme/domain/theme_components.dart` —— 组件 token 已就绪，
  旗舰 UI 应直接使用，不要再往 `colorScheme` 上硬写
- `test/theme_hardcode_guard_test.dart` —— 写完 UI 会立刻告诉你哪里漏了 token
- `lib/core/layout/window_size_class.dart` —— 响应式地基，D6 的两层模型要接着它写

**不要做**：
- 不要把 `theme_layout.dart` 的旧字段接活（缺陷 D）
- 不要引入 `theme.js` / 脚本层（D1）
- 不要在 L2 里开放「新增区域」或「自定义 widget」（D2）
- **不要让皮肤声明绝对像素尺寸**（D4）—— 一律主轴比例
- **不要设计一套「桌面手机通用」的区域集合**（D6）—— 必须按形态分别定义；这是本项目的前车之鉴（§5.4）
- **不要做皮肤编辑器**（§4 阶段 4）：编辑由文件热重载承担，分享靠截图。
  再引入一个编辑器是与「JSON 是唯一真源」相冲的第二套编辑体验

**测试基线**：`flutter test` → **363 passed, 8 skipped**（2026-09-26 复核；阶段 1 完成时是
201 passed / 8 skipped）
本轮新增：`theme_icons_test.dart`（20）、`theme_icon_render_test.dart`（4）、
`theme_ambient_test.dart`（23，含按滚动轴断言每种 `content.style` 渲染出**不同**布局）、
`theme_navigation_test.dart`（17）、`shell_mobile_reachability_test.dart`（4）

### 2026-09-26 收尾

- 《玄》导航选中态拆成两个 token：`selectedIndicator` 是实色右缘，
  `selectedIndicatorFill` 是品牌洗染背景；旧透明色不再被硬当实色渲染。
- `ambient.blur` 不再是死 token：氛围色带现在真正应用模糊，柔光读作光而不是色块。
- 发现页一级入口从裸图标改为设计稿的「插件榜单」文本 pill，文案进入皮肤字符串
  (`discover.rankingEntry`)。
- 插件榜单二级页（发现 → 插件榜单）整套 chrome 交给皮肤：标题、来源、排行榜 /
  热门歌单切换、空状态、重试、播放 / 下载 tooltip、`{count} tracks` 都在
  `theme.json` 的 `strings` 里声明（`discover.*`），不再有英文硬编码。
  来源与标签用设计稿的描边 pill（`_SourceChip`）而不是 `ChoiceChip`，切换用
  两段 pill（`_SurfaceSwitch`）而不是 `SegmentedButton`，歌曲行是设计稿的行结构
  而不是 `ListTile`。
- 二栏拆分按**可用宽度**（560dp）判定，而不是 shell 的 expanded 断点：1280 窗口
  减去侧栏与队列后仍有约 800dp，之前会因为 < 840 而塌成单栏。
- `ChipThemeData` 补进 `TokenResolver`：此前没有声明，`ChoiceChip` 落到 Material
  默认色，搜索页 / 正在播放页的 chip 是雾蓝而不是皮肤色。
- 热门歌单网格换回设计稿的封面卡片（`_CollectionCard`，封面在上、标题在下，
  `mainAxisExtent` 固定 caption 高度），之前 `_CollectionTile` 的 190dp 行卡
  压出两行标题叠在封面上。
- 插件榜单数据加 1 小时 TTL 缓存（`discoverCacheTtl`），切换插件 / tab 命中
  缓存不重新请求；「刷新」按钮仍然 `force: true` 直打插件。缓存按
  `插件 + surface + 标签` 分键，每个插件独立过期。
- 搜索页（`desktop-search` 画板）重写为《玄》风格：标题 / 副标题 / 空态 /
  插件计数 pill / 播放 / 下载 tooltip 都走 `search.*` 皮肤字符串，来源用
  `_SourcePill`，结果行带序号、封面、平台 chip、行内动作，不再是
  `ListTile` + 英文硬编码。
- 队列页 / 下载管理 / 我的音乐 / 插件页四张页面从 Material 默认样式迁移到
  token + 皮肤字符串；`Mode` / `Clear` / `Retry` / 状态文案 / 弹窗按钮 /
  导入摘要 / 进度条颜色全部可被 `theme.json` 覆盖。播放模式选择改成
  描边 pill + 下拉（`_ModePill`），队列行 / 历史行 / 下载行 / 歌单行不再是
  `ListTile`。
- 移动端护栏：新增 `page_phone_overflow_test.dart`，把队列 / 下载 / 搜索 /
  插件四页在 400×800（竖屏）与 800×360（横屏）用极长标题 + 极长平台名压一遍，
  页面必须不溢出；手机头部 / 底部 tab / 底部播放条沿用皮肤 arrangement，
  二级页面自身的 gutter 也来自 `components.content`。
- **涉及布局时**：补 `test/responsive_layout_test.dart` 的尺寸用例
  （必须覆盖 400×800 / 800×360 / 1280×900，横屏手机 800×360 是历史上出错最多的形态）

### 2026-09-28 收尾

- 修复播放条在 800×360 横屏下溢出 2px 的根因：外壳的 `_playerBarMin`
  72dp 小于播放条自身内容（42dp 按钮行 + 20dp 进度行 = 62dp，加上 12dp
  底部 margin 需要 74dp）。下限现在由内容推导（74dp），不再用魔法数猜。
  皮肤请求更小的播放条仍然会被钳到这个最小值，而不是拿到一个自我溢出的条。
- 发现页来源 pill 行从「水平滚动里的 `Wrap`」改为 `Row`：`Wrap` 在滚动轴
  上拿到的是无界宽度，所有 chip 排在一行然后溢出面板。补了
  `discover browser fits 400×800 / 800×360` 两条溢出护栏。
- 《玄》首页不再等用户自己点进「插件榜单」才拉插件数据：首页挂载时
  `seedHomeShelf` 同步启用的插件后，按顺序试到第一个能返回热门歌单的
  插件为止（某个插件只有排行榜、没有 `getRecommendSheetTags`，是现成的
  反例）。选中的插件留在成功那个上，浏览器打开时看到的是同一份货架而不是
  一个错误页。为此新增 `discover_cache_test.dart` 两条用例。
- **测试基线**：`flutter test` → **380 passed, 8 skipped**（2026-09-28 复核；
  本轮新增 4 条，`page_phone_overflow_test.dart` +2、
  `discover_cache_test.dart` +2）

### 2026-09-28 补充

- 侧栏身份块（头像 / 昵称 / 本地曲库计数）改由皮肤声明：新增
  `navBar.showProfile` 组件 flag，默认 `true`；《玄》设 `false`，因为没有账号
  功能，这块就是死控件。UI 的「1」不是 app 渲染的徽标，是设计稿画的等级角标，
  皮肤关掉整块即可。
- 「插件榜单」入口从裸 `IconButton` 换成设计稿的描边 pill
  （`InkWell` + 可见边框 + padding 命中区）。原先的 IconButton 只有内部
  稀疏的命中矩形，pill 视觉边界比命中区大，点上去容易落空，读起来就像
  「点了没反应」。现在整个 pill 都是点击区，并有 tooltip 保留可发现性。
- 修正 `shell_responsive_test.dart` 的 harness：它此前用裸 `MaterialApp`
  渲染 `RobyneShell`，而 shell 是从 Material theme extension 读 token 的，
  裸 MaterialApp 没有 extension 会静默退回 `ThemeTokens.baseline()`，导致
  任何皮肤组件 flag 都读成默认值。harness 现在装 `darkThemeDataProvider`，
  与生产一致；新增「皮肤隐藏身份块」用例。
- **测试基线**：`flutter test` → **381 passed, 8 skipped**（2026-09-28 复核）

### 2026-09-28 二次补充

- 首页 hero 的「立即播放 / 收藏」与推荐卡（卡身、右下播放圆钮）此前只调
  `openCollection` 加载详情，却从不拉起浏览器视图——详情在不可见的浏览器里
  装好了，首页一动不动，所有按钮读起来都是「点了没反应」。`_openDiscover`
  现在先 `discoverBrowserProvider.open()` 再 `openCollection(item)`，
  首页跳到插件榜单并直接定位到那张歌单的曲目列表。
- 推荐卡右下角的播放圆钮从纯装饰 `Icon` 改成自带 `onTap` + tooltip 的
  `InkWell`：此前它完全依赖外层卡片 InkWell 的命中测试，任何 Stack 命中
  行为的调整都会让这个可见按钮静默失效。
- 「收藏」在插件协议没有歌单收藏方法之前仍与「立即播放」一样打开歌单详情；
  真正的整单收藏需要插件协议补齐，不在皮肤层伪造。
- **测试基线**：`flutter test` → **381 passed, 8 skipped**（2026-09-28 复核）

---

### 2026-09-30 材质层落地（磨砂 / 混色 / 渐变三形态 / 光晕 / 流光）

**动机**：皮肤此前能换色换形，但换不了"质感"。`ThemeGradient` 只有线性且方向写死在
渲染代码里；效果 token 只有两个全局标量，`effects.glassOpacity` 全项目无人消费；
没有任何 `BlendMode`。结果是所有皮肤都停在"平面色块"。

**做法**：把"效果"升格为一等公民，新增 `tokens.materials` 模块与
`MaterialSurface` 渲染件，七个真实表面接入：`navBar` / `topBar` / `playerBar` /
`queue` / `card` / `content` / `hero`。

落地内容：

1. **渐变三形态**：`linear` / `radial` / `sweep`，带方向、径向中心与半径、
   扫掠角度、shader 铺贴（clamp / repeat / mirror / decal）。旧写法
   （字符串、色标数组、`{stops: [...]}`）全部继续可用。
   **顺带修掉一个静默缺陷**：`{ "stops": [...] }` 这种写法此前解析器不认，
   《玄》里写的导航渐变被吞掉、实际渲染为无渐变。现在它是正式语法。
2. **材质字段**：`color` / `gradient` / `opacity` / `blur` / `saturation` /
   `brightness` / `contrast` / `grayscale` / `blend` / `overlay`（第二层混色）/
   `border` / `radius` / `shadows`（光晕与投影）/ `shimmer`（流光）。
3. **18 种混色模式**（`multiply` / `screen` / `softLight` / `color` / `plus` …）。
4. **背景层升级**：全屏背景图可模糊、调色、缩放，支持渐变遮罩与最多 8 层任意
   混色叠加——这是"照片当壁纸"能用的前提。
5. **氛围层升级**：单条光带升级为最多 6 个柔光源，带可选漂移动画；`lights` 为空时
   完全沿用旧行为。
6. **旧 token 接活**：`effects.blur` / `effects.glassOpacity` 现在是材质的兼容
   回退路径（只在壳层生效，避免卡片网格静默获得几十个 backdrop filter）。
7. **旋钮扩展**：`materials.<surface>.<scalar>` 可作为用户旋钮目标。

**护栏沿用既有原则**：一切数值 clamp、未知值忽略、声明为空时不改变渲染树与开销、
流光与漂移默认关闭。装饰动画受 `MediaQuery.disableAnimations` 门控（减弱动态效果
时停用，材质照常绘制）。

**《玄》默认关闭氛围层**：`components.ambient.enabled` 改回 `false`，首页普通视图
的 content 平面直接落到 `background.base`（`#0B0C0E`），不再有封面取色铺出的
模糊光晕。`lights` 的声明保留，所以想开氛围的皮肤把 `enabled` 翻回 `true` 即可
拿到原来的多光源效果；`enabled: false` 时 `ThemeAmbient` 直接返回 child，渲染树
和开销与没有该 token 时完全一致（这是 §3.4「皮肤可以关闭氛围层」的既有约定）。

**测试基线**：`flutter test` → **459 passed, 9 skipped**（2026-09-30 复核）。
本轮新增 `theme_material_test.dart`（24 条：三形态渐变、材质字段、越界收敛、
背景调色、多光源、旋钮、渲染断言、旗舰皮肤防回归）与
`theme_motion_gate_test.dart`（2 条：减弱动态效果、静止仍绘制）。
`theme_material_preview_test.dart` 是可选预览（`ROBYNE_PREVIEW=1` 时导出
`build/shots/materials-preview.png`），默认跳过。

---

### 2026-09-28 六项功能落地

- **收藏歌单**：新增 `FavoriteCollections` 表（schema v2，带 `onUpgrade`）与
  `FavoriteCollectionRepository`。存的是一条**指向插件条目的指针 + 展示快照**
  （标题 / 封面 / raw payload），不是把曲目复制进本地歌单：在线歌单的曲目归插件
  所有且会变，复制会冻结一份会过期的数据并放大存储。详情页头部新增
  「播放整个歌单 / 收藏歌单」两个按钮。
- **播放歌单的入队策略**：`CollectionPlayController` 负责「先问一次、之后复用」。
  首次播放弹 `collection_play_dialog`，二选一（添加到播放列表 / 替换播放列表），
  带「以后都按这个来」勾选；勾选后写入设置，之后不再打断。设置页「通用」新增
  「播放歌单的方式」可随时改回「每次询问」或改选另一种。
- **队列操作**：`PlayerController.enqueueItems` / `replaceQueueWithItems`。
  两个方法都 `await future` 再写入——`build()` 是异步恢复持久化队列的，早于它
  落地的写入会被随后的恢复覆盖（这是实测抓到的真实竞态，不只是测试问题）。
- **队列面板记忆**：`queuePanelVisibleProvider` 从设置读取上次的开关状态，
  切换时写回。此前桌面端每次都按「设计稿停靠」默认打开，用户的关闭决定过不了
  重启。
- **封面**：发现页推荐卡与 hero 之前画的是渐变色块，完全没用 `item.artworkUrl`；
  实测插件 payload 的封面字段是 `coverImg`（歌单）/ `artwork`（榜单），适配器本来
  就解析了，缺的是 UI。现在统一走 `ArtworkView`，共用既有的
  `robyne_artwork_cache` 磁盘缓存（按 URL 哈希），不另存一份；`ArtworkView`
  新增 `expand` / `fit` 以支持横版封面，缓存路径不变。渐变色降级为加载中与
  无封面时的兜底。
- **沉浸式播放页入口**：`_NowPlayingActions`（收藏 + 更多菜单：歌词搜索 /
  本地歌词 / 歌词偏移 / 加入歌单 / 清除关联）此前只在非沉浸式渲染，
  点击播放栏封面展开的全屏播放页没有任何入口。现在两种形态都渲染，
  沉浸式居中、分栏形态左对齐。
- **自绘窗口按钮**：`bootstrap` 设 `TitleBarStyle.hidden` 隐藏原生标题栏，
  顶栏右端新增最小化 / 最大化 / 关闭三个按钮（走 `window_manager`，保留
  Snap、任务栏预览、Alt+F4）。测试环境通过 `showWindowControls: false`
  不触碰窗口插件。
- **测试基线**：`flutter test` → **386 passed, 8 skipped**（2026-09-28 复核；
  本轮新增 `collection_queue_test.dart` 3 条、`favorite_collection_test.dart`
  2 条）

### 2026-09-28 播放条单行弹性重构与顶栏拖动

三项实测缺陷，都来自「皮肤重写后还没在新布局上复验」：

- **窗口不能拖动**：`TitleBarStyle.hidden` 之后顶栏没有接住拖动，窗口一次都
  挪不动。`_TopBar` 现在把 `DragToMoveArea` 铺在最底层（`Stack` 的第一个
  child），搜索框、箭头、窗口按钮都在它上面，命中测试仍归控件；实测窗口从
  `(0,0)` 拖到 `(-105,56)`。
- **最大化后播放条错位**：旧布局是「两个定宽半边 + 一个 470dp 封顶的中间
  列」。窗口一旦超过这个 cap，多出来的像素全被左侧信息块吃掉，进度条卡在
  470dp，传输区落在视觉中心左边。改成设计稿本身画的**单行弹性布局**：信息块
  是 `(宽度 * 0.18).clamp(120, 260)` 的定宽列，进度条是行内唯一的 `Expanded`。
  这样窗口越宽、进度条越长，没有第二个断崖。
- **队列面板没有封面**：停靠面板的 `_QueueRow` 无条件画 `_queueAccent` 渐变，
  从没读过 `item.artworkUrl`，而中间详情列表早就走了 `ArtworkView`——同一首歌
  两个地方表现不一致。现在渐变只做底，真封面走 `ArtworkView(expand: true)`，
  共用同一个 `robyne_artwork_cache`，不新增缓存。
- **回归测试**：`test/responsive_layout_test.dart` 新增 7 个宽度点
  （600 / 660 / 720 / 840 / 960 / 1000 / 1180），每个都断言零溢出。旧布局在
  1000dp 溢出 70dp、600dp 溢出 68dp，这些宽度此前没有任何测试覆盖。
  修 720dp 那 3.6dp 溢出时把时间标签从 40dp 收到 36dp，而不是挪动规格里的
  720 断点。
- **测试基线**：`flutter test` → **393 passed, 8 skipped**（2026-09-28 复核）

## 7. 文档索引

| 文档 | 状态 | 说明 |
|---|---|---|
| `THEME_ROADMAP.md`（本文） | **权威** | 当前执行规划与现状盘点。多端问题见 §5 |
| `ADR-001-responsive-window-size-class.md` | **有效** | 响应式决策（应用侧自适应）。P0 已落地；皮肤侧布局见本文 D4 / D6 / D7 |

> ⚠️ **编号消歧**：本文的 D1–D7 是**皮肤系统**的决策编号；
> `ADR-001` 的 D1–D6 是**响应式**的决策编号。两者独立，不要混用。
> 引用时请写明出处，如「本文 D6」或「ADR-001 的 D6」。
| `THEME_LAYER_DESIGN.md` | 部分有效 | 架构原则仍成立；§4.2 的 Level 分级已被 D1 取代；§8 的 PR 划分已被本文 §4 取代 |
| `THEME_AUTHORING.md` | **有效（已同步）** | layout 已按 arrangement 重写（缺陷 D 修复），并新增 icons / ambient / 字体角色 / content 几何等章节 |
| `THEME_DECISIONS.md` | **已废弃** | Q1「只做 L0+L1」已被 D1 推翻；其余 Q2–Q10 建议已并入本文 |
