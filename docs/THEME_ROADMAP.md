# Robyne 皮肤系统 · 正式规划

> 状态：**执行中** · 替代 `THEME_DECISIONS.md`（那份的 Q1「本期只做 L0+L1」建议已被推翻）
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

> **一个完备的皮肤系统（可调布局 / 界面 / 图片 / 颜色）+ 一个 QQ音乐量级的官方默认皮肤，
> 后者作为系统能力的展示示范。**

---

## 1. 已确定的决策

### D1 · 三层自由，对应用户分层 【已定】

用户的直觉本身就是最好的架构分层，直接照它设计：

| 层 | 面向 | 能力 | 当前状态 |
|---|---|---|---|
| **L0 调色** | 所有人 | 颜色 / 圆角 / 间距 / 字体 / 背景图 / 模糊 | ✅ 已可用 |
| **L1 旋钮** | 普通用户 | 皮肤声明 `settings`，用户在设置页拖滑块改，**不改 JSON** | ✅ 已可用 |
| **L2 布局** | 极客 | 命名区域重排 + 尺寸比例 + 区域风格 | ❌ 待建 |
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

`THEME_LAYER_DESIGN.md:19` 已立原则：**默认 UI 不是特例，它就是内置皮肤包**。既然如此，「完备的皮肤系统」和「QQ音乐式官方皮肤」就是同一件事的两面，不是一个先一个后。

**理由**：token 清单与区域契约只有在被一个真实、复杂、有审美要求的 UI 撑过一遍之后，才知道定得对不对。若先抽象设计系统再写 UI，写到一半必然发现「导航栏渐变没地方表达」「歌词高亮没地方放」，然后回头改 token —— 返工。

**所以**：QQ音乐式 UI 不是系统的「应用」，它是系统的**规格来源和唯一压力测试**。

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

## 2. 待定事项（阻塞中）

### ⏸ OPEN-1 · 区域集合与形态映射 【待视觉设计文档确定】

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

**需要视觉设计文档回答的问题**：
1. 区域集合是否就是这 5 个？有没有独立的「推荐 banner 区」或「歌词区」？
2. `topBar` 在手机上是否完全不出现，还是变形为别的？
3. 各形态下区域的默认比例各是多少？

**接手者注意**：视觉设计文档产出前，**不要**开始阶段 3（L2 开放）。**可以**开始阶段 1（与区域无关）。

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

**所有 feature 页面都写 `Theme.of(context).colorScheme.xxx`。** 目前能工作，是因为 token 会流进 colorScheme；但 colorScheme 的语义角色是 Material 固定的那十几个，QQ音乐式 UI 真正有辨识度的东西**没有落脚点**：

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

**缺陷 D · layout 字段是死字段** 🟡

`theme_layout.dart` 声明的字段中，**只有 3 个被真实读取**（`router.dart`）：
- `desktop.sidebar.width` ✅
- `desktop.sidebar.labelMode` ✅
- `desktop.sidebar.position` ✅

**未被读取**：`desktop.playerBarHeight`、`desktop.playerBarPosition`、`mobile.navigation`、`mobile.playerBarHeight`、`mobile.playerBarCompact`、`content.listStyle`、`content.density`。
→ `THEME_AUTHORING.md:168` 承诺的 `"layout": { "mobile": { "playerBarHeight": 56 } }` **不生效**。文档兑现能力存在缺口。

**重要**：这些字段是**为 MVP UI 设计的**。新 UI 有顶栏 / 侧边导航 / 宫格 / 全屏播放页，区域集合完全变了。**不要把旧字段接活**——那是在即将拆掉的地基上装修。旧字段应随 L2 一起被新的区域契约取代。

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

### 阶段 2 — 旗舰 UI（与阶段 1 交叉进行）

**阻塞**：需先有视觉设计文档（OPEN-1）。

- 按视觉设计文档实现 QQ音乐式 UI
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

### 阶段 3 — L2 开放

**阻塞**：依赖阶段 2 定稿的区域集合。

- 区域契约从内部 registry 变成皮肤可覆盖
- `theme.json` 支持 `layout.desktop.arrangement` / `layout.mobile.arrangement`（D6 格式）
- 实现 D7 的分工：应用负责形态判定 / 比例换算 / 空间不足时的退化优先级
- 设置页加布局编辑入口（拖拽 / 下拉选 slot，实时预览 + 一键还原）
- 旧 `theme_layout.dart` 字段迁移或废弃，同步更新 `THEME_AUTHORING.md`

**验收（多端）**：
- 把官方皮肤的 `navBar` 从 left 挪到 right、`content` 改成 grid，App 仍完整可用且无溢出
- **只写 `mobile` 的 arrangement 时，桌面保持官方默认**（继承规则生效）
- **写一个「桌面专用」的极端 arrangement，在手机上仍不崩溃**（护栏生效）
- 把 `content` 从 arrangement 里删掉 → 应回退 baseline 且不白屏

### 阶段 4 — 生态

- 编辑器：**三种 size class 同时预览**（这是让「一键分享」可信的关键——作者能在发布前看到自己皮肤在手机横竖屏上的样子）
- 导入时 lint：WCAG 对比度检查、arrangement 合法性检查（含每个形态是否含 `content`），皮肤卡片显示形态兼容性评级
- 市场 `index.json` 带 `formFactors` 声明（作者测过哪些形态）
- 可选：`mftheme` → JSON 导入器（桥，非地基）

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

**当前状态**：**阶段 1 已完成**（2026-03-05）。详见 §4 阶段 1 的落地记录。

**可以立刻做的剩余项**：
1. 复核 `theme_hardcode_guard_test.dart` 的 allowlist
   （`desktop_lyric_window.dart`）——若歌词窗口要纳入皮肤系统，需移出
2. 给内置皮肤补上组件 token（会随阶段 2 的旗舰 UI 一起做，不必单独做）

**必须等待**：
- 阶段 2、3 → 等视觉设计文档与 OPEN-1 区域集合定稿

**阶段 2 开工时先读**（避免踩已填过的坑）：
- `lib/core/theme/domain/theme_components.dart` —— 组件 token 已就绪，
  旗舰 UI 应直接使用，不要再往 `colorScheme` 上硬写
- `test/theme_hardcode_guard_test.dart` —— 写完 UI 会立刻告诉你哪里漏了 token
- `lib/core/layout/window_size_class.dart` —— 响应式地基，D6 的两层模型要接着它写

**必须等待**：
- 阶段 2、3 → 等视觉设计文档与 OPEN-1 区域集合定稿

**不要做**：
- 不要把 `theme_layout.dart` 的旧字段接活（缺陷 D）
- 不要引入 `theme.js` / 脚本层（D1）
- 不要在 L2 里开放「新增区域」或「自定义 widget」（D2）
- **不要让皮肤声明绝对像素尺寸**（D4）—— 一律主轴比例
- **不要设计一套「桌面手机通用」的区域集合**（D6）—— 必须按形态分别定义；这是本项目的前车之鉴（§5.4）

**测试基线（阶段 1 完成后）**：`flutter test` → **201 passed, 8 skipped**
新增：`test/theme_stage1_test.dart`（20）、`test/theme_hardcode_guard_test.dart`（3）
- **涉及布局时**：补 `test/responsive_layout_test.dart` 的尺寸用例
  （必须覆盖 400×800 / 800×360 / 1280×900，横屏手机 800×360 是历史上出错最多的形态）

---

## 7. 文档索引

| 文档 | 状态 | 说明 |
|---|---|---|
| `THEME_ROADMAP.md`（本文） | **权威** | 当前执行规划与现状盘点。多端问题见 §5 |
| `ADR-001-responsive-window-size-class.md` | **有效** | 响应式决策（应用侧自适应）。P0 已落地；皮肤侧布局见本文 D4 / D6 / D7 |

> ⚠️ **编号消歧**：本文的 D1–D7 是**皮肤系统**的决策编号；
> `ADR-001` 的 D1–D6 是**响应式**的决策编号。两者独立，不要混用。
> 引用时请写明出处，如「本文 D6」或「ADR-001 的 D6」。
| `THEME_LAYER_DESIGN.md` | 部分有效 | 架构原则仍成立；§4.2 的 Level 分级已被 D1 取代；§8 的 PR 划分已被本文 §4 取代 |
| `THEME_AUTHORING.md` | **需更新** | §4.5 描述的 layout 字段与实现不符（缺陷 D），阶段 3 需同步修订 |
| `THEME_DECISIONS.md` | **已废弃** | Q1「只做 L0+L1」已被 D1 推翻；其余 Q2–Q10 建议已并入本文 |
