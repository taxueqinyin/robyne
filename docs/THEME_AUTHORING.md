# Robyne 皮肤制作指南

> 本文档描述当前实现。布局已按 [`THEME_ROADMAP.md`](./THEME_ROADMAP.md)
> 的 D6/D7 落地：**区域身份跨形态稳定，槽位按形态受限，尺寸一律主轴比例**。
> 旧版 `sidebar.width` / `playerBarHeight` / `playerBarPosition` / `mobile.navigation`
> 等像素字段**已移除**（它们被 arrangement 取代，且没有任何界面读它们）。写了会被忽略，
> 不会报错——这是本文件一贯的容错契约。

> 本指南面向皮肤作者。**官方 UI 本身就是一份皮肤**，照着 assets/themes/ 里的内置皮肤抄即可。

---

## 1. 皮肤是什么

一个皮肤包就是一个目录（或打包成 .rtheme 的 zip），里面必须有一个 theme.json：

    mytheme/
    |-- theme.json          # 必须
    |-- preview.webp        # 预览图（也可直接用颜色值，见下文）
    `-- assets/
        |-- bg.webp         # 可选：背景图
        `-- MyFont.ttf      # 可选：随包字体

**皮肤是纯数据，没有任何可执行代码。** 这是有意为之——你不需要担心一个皮肤会损害用户设备，我们也不需要扫描它。

---

## 2. 最小可用皮肤

只需要两个字段：

```json
{
  "id": "mytheme",
  "name": "我的第一个皮肤"
}
```

缺的字段全部自动使用内置默认值。所以你**永远不会因为少写一个字段而得到报错或白屏**。

---

## 3. 完整字段说明

```jsonc
{
  "schemaVersion": 1,
  "id": "mytheme",
  "name": "主题名称",
  "author": "作者",
  "authorUrl": "https://...",
  "version": "1.0.0",
  "description": "一句话描述",
  "preview": "preview.webp",
  "tags": ["dark", "minimalist"],
  "mode": "dark",
  "tokens": { },
  "settings": [ ],
  "strings": {
    "nav.discover": "发现",
    "nav.library": "内容库",
    "search.hint": "搜索歌曲、歌手、专辑",
    "queue.title": "当前播放"
  },
  "assets": {
    "background": "assets/bg.webp",   // 全局背景图
    "font": "assets/MyFont.ttf",      // 随包字体
    "logo": "assets/logo.png",        // 侧栏品牌标识
    "avatar": "assets/avatar.png",    // 用户资料头像
    "hero": "assets/hero.webp"        // 首页英雄横幅图
  }
}
```

所有资源位都是可选的：缺失时按设计稿的渐变/图标回退，不会留白或报错。
每个文件仍受 500KB 单资源预算约束。

### mode 的含义

决定系统状态栏图标颜色等平台元素的明暗倾向。用户可以在「设置 - 外观」里强制覆盖为亮/暗。

优先级：**用户显式选择 > 皮肤的 mode > 系统设置**。

---

## 4. Token 体系（核心）

### 4.1 三层 Token

    Primitive（原始值）  ->  Semantic（语义）  ->  Component（组件）
    #F2B749                 color.brand            playerBar.background

**你只能写 Semantic 层。** 这是保护性的：因为你在描述"品牌色是什么"，而不是"第 3 个按钮的背景是什么"。当我们新增组件时，**你的皮肤会自动适配，零工作量**。

### 4.2 支持的 Token

#### color

```jsonc
"color": {
  "background": { "base": "", "elevated": "", "sunken": "", "overlay": "" },
  "surface":    { "base": "", "hover": "", "active": "", "selected": "" },
  "brand":      { "base": "", "hover": "", "muted": "", "onBrand": "" },
  "text":       { "primary": "", "secondary": "", "muted": "", "disabled": "" },
  "border":     { "subtle": "", "default": "", "strong": "", "focus": "" },
  "status":     { "danger": "", "warning": "", "success": "" }
}
```

#### radius / spacing

```jsonc
"radius":  { "sm": 6, "md": 10, "lg": 16, "full": 999 },
"spacing": { "xs": 4, "sm": 8, "md": 12, "lg": 16, "xl": 24 }
```

#### typography / elevation / effects

```jsonc
"typography": { "family": "Inter", "scale": 1.0, "bodyWeight": 400, "titleWeight": 600 },
"elevation":  { "sm": 1, "md": 3, "lg": 6 },
"effects":    { "blur": 0, "glassOpacity": 1 }
```

- scale 是全局字号倍率，取值会被限制在 **0.75 ~ 1.5**
- blur 是背景模糊半径，取值会被限制在 **0 ~ 40**；设为 0 即关闭毛玻璃

#### background

```jsonc
"background": {
  "image": "assets/bg.webp",
  "fillMode": "cover",
  "overlay": "#000000",
  "overlayOpacity": 0.3
}
```

fillMode 可选：cover | contain | stretch | tile

#### components —— 让皮肤有辨识度（v1 新增）

语义 token 只描述"角色"（品牌色、正文色），但播放器真正有辨识度的是**具体表面**：
导航栏渐变、歌词高亮行、卡片悬浮态。这些在语义层没有落脚点，所以单列一组。

```jsonc
"components": {
  "navBar": {
    "background": "#1A1C20",        // 留空则用语义背景色
    "gradient": ["#FF5B5B", "#8A2BE2"],   // 渐变；也可只写一个颜色
    "selectedItem": "#6EA8FE",
    "selectedIndicator": "#26EA8FE"
  },
  "playerBar": {
    "background": "#1A1C20",
    "gradient": "#1A1C20",
    "progressTrack": "#33FFFFFF",
    "progressActive": "#6EA8FE"
  },
  "lyric": {
    "activeLine": "#6EA8FE",
    "inactiveLine": "#7A8089",
    "activeBackground": "#1F6EA8FE"   // 全透明即关闭高亮
  },
  "card":  { "surface": "#1C1F24", "hover": "#0AFFFFFF", "selected": "#2B4A7A" },
  "list":  { "itemSelected": "#2B4A7A", "itemHover": "#0AFFFFFF" },
  "motion": {
    "shortDurationMs": 150,
    "mediumDurationMs": 300,
    "curve": "standard"          // standard | decelerate | accelerate | linear
  },
  "ambient": {
    "enabled": true,               // 封面驱动的顶部柔光，见下
    "strength": 0.28,              // 峰值不透明度 0~0.6
    "heightFraction": 0.32,        // 向下衰减到内容区高度的百分之多少
    "blur": 48,                    // 柔化程度；0 即硬渐变
    "color": null                  // 指定固定颜色；不写则跟随当前封面
  },
  "content": {
    "gutter": 28,                  // 桌面左右留白
    "gutterCompact": 16,           // 手机左右留白
    "rowHeight": 56,               // 列表行高
    "rowHeightCompact": 48,        // 横屏手机行高
    "cardMinWidth": 180,           // 宫格卡片最小宽
    "cardMinWidthCompact": 140,
    "cardGap": 16,
    "cardGapCompact": 12,
    "sectionGap": 24,              // 内容区块之间的间距
    "navIconSize": 22,             // 侧栏图标
    "logoSize": 26,                // 侧栏品牌标识
    "avatarSize": 38               // 头像
  }
}
```

**gradient 两种写法都行：**

```jsonc
"gradient": "#FF5B5B"                                  // 单色
"gradient": [                                          // 多色标
  { "color": "#FF5B5B", "offset": 0 },
  { "color": "#8A2BE2", "offset": 1 }
]
```

- 最多 8 个色标，超出部分忽略；`offset` 会被收敛到 0~1 并自动排序
- 写错的色标会被跳过；一个都不剩就退化为"无渐变"，不会报错

> **只写你想改的字段。** 没写的自动用官方默认值，所以写了 `lyric.activeLine` 不会影响 `inactiveLine`。

#### typography —— 不只是整体缩放

`scale` 是一把粗尺子：一个系数乘到所有字号上。它做不到「标题大、标签紧」这种**字体性格**，
所以另有五个按角色命名的字号，对应设计稿 §3.3 的五行：

| 字段 | 角色 | 设计稿默认 |
|---|---|---|
| `pageTitleSize` | 页面标题 | 24 |
| `sectionTitleSize` | 区块标题 | 18 |
| `listPrimarySize` | 列表主文本 | 15 |
| `listSecondarySize` | 列表次文本 | 13 |
| `labelSize` / `labelWeight` | 标签 / 徽标 | 11 / 500 |

```jsonc
"typography": {
  "family": "Source Han Sans",
  "scale": 1,              // 用户可调的全局系数，与角色字号相乘
  "titleWeight": 600,
  "pageTitleSize": 30,     // 只改这一个角色
  "labelSize": 10
}
```

未声明的角色用设计稿默认值，所以只写一个不会把其他四个压成 0。
字号被收敛到 `8`–`96`：太小读不了，太大撑爆任何面板。

**`scale` 与角色字号是相乘关系**，不是二选一：角色字号是皮肤的表达，`scale` 仍是留给
用户的整体大小调节。

#### content —— 内容区的几何（`components.content`）

设计稿 §3.2 / §4.5 把留白、行高、卡片宽与间距写成了具体数字，但此前它们是散落在
各页面里的字面量：皮肤能改一行的颜色，却**挪不动它一个像素**。这就是「想把行距收紧
一点」必须改代码的原因。

| 字段 | 桌面 | 移动 |
|---|---|---|
| `gutter` / `gutterCompact` | 内容区左右留白 | 28 / 16 |
| `rowHeight` / `rowHeightCompact` | 列表行高 | 56 / 48 |
| `cardMinWidth` / `cardMinWidthCompact` | 卡片最小宽 | 180 / 140 |
| `cardGap` / `cardGapCompact` | 卡片间距 | 16 / 12 |
| `sectionGap` | 区块间距 | 24 |
| `navIconSize` / `logoSize` / `avatarSize` | 侧栏图标 / 品牌标识 / 头像 | 22 / 26 / 38 |

行内的封面尺寸**跟随行高**（行高的 70%，收敛在 24–56 之间），所以调 `rowHeight`
会带动整套行内比例，而不是只把行拉长、封面留在原地。

**为什么这些用像素而 `layout` 用比例？** 留白与行高是可用性问题，有正确答案：
32dp 的行在任何窗口都是 32dp，不该随窗口缩放。`layout` 的比例是给**区域**用的，
它要随窗口伸缩。两者服务不同的目的，所以量纲也不同。

**约束：** 行高收敛到 32–160（8dp 点不到、400dp 一屏一行）；留白 0–96；
卡片 80–480；间距 0–64。一个皮肤写错数字不会让内容变得不可用。

#### ambient —— 封面驱动的氛围（设计稿 §3.4「标志性识别」）

内容区顶部从**当前播放封面的主色**取色，生成一层向下衰减的柔光。这是设计稿里
Robyne 的signature：换一首歌，整页的色温跟着换。关掉它就退回平色面板。

| 字段 | 含义 |
|---|---|
| `enabled` | 总开关，默认 `false`（老皮肤渲染树与开销完全不变） |
| `strength` | 峰值不透明度，按设计稿建议 `0.20`~`0.35`；解析时上限收到 `0.6` |
| `heightFraction` | 柔光覆盖内容区顶部多少比例；设计稿建议 `0.25`~`0.35` |
| `blur` | 柔化程度；`0` 是硬边渐变，`48` 是柔光 |
| `color` | 固定颜色。不写就跟随封面取色——那是设计稿的本意；写死则是「无论放什么都用品牌光晕」的退路 |

**约束：**

- 氛围层是**纯装饰**：不参与布局、不改文字颜色、不参与可读性判断（§3.4 第 3 条）。
  因此把 `strength` 拉满也不会让某一页变得读不了
- `strength` 为 `0` 或 `enabled` 为 `false` 时**完全不渲染**，不付出任何开销
- 封面取色失败（图挂了、格式不认识）时退回品牌色，而不是让页面失去氛围或抛错
- 封面主色由把封面解码到 16px 求平均得到，结果按 URL 缓存——不是精确调色板，
  但柔光被模糊到这个程度后只有色相还留着

#### materials —— 材质（磨砂 / 渐变 / 混色 / 光晕 / 流光）

`components` 回答「这个表面是什么颜色」，`materials` 回答「这个表面**怎么被画出来**」。
两者分开是为了让皮肤可以一次只给一个表面升级质感，而不必动整份配色。

七个已接线表面：`navBar` / `topBar` / `playerBar` / `queue` / `card` / `content` / `hero`。

```jsonc
"materials": {
  "playerBar": {
    "color": "#E60D0E10",              // 填充色（可半透明）
    "gradient": { "kind": "linear" },  // 填充渐变，见下
    "opacity": 0.92,                   // 整个填充层的透明度
    "blur": 20,                        // 背景模糊 —— 磨砂玻璃
    "saturation": 1.1,                 // 背景增饱和（玻璃的通透感）
    "brightness": 1.0,                 // 背景明度
    "contrast": 1.0,                   // 背景对比度
    "grayscale": 0.0,                  // 背景去色
    "blend": "normal",                 // 填充层与背景的混色模式
    "overlay": {                       // 第二层，画在内容之上
      "gradient": { "kind": "radial", "center": [0.8, 0.2] },
      "blend": "screen",
      "opacity": 0.6
    },
    "border": { "color": "#1AFFFFFF", "width": 1 },
    "radius": 14,                      // 不写则跟随 tokens.radius
    "shadows": [                       // 光晕 / 投影，最多 8 条
      { "color": "#33FF6B3D", "blur": 46, "spread": 1 }
    ],
    "shimmer": {                       // 流光扫过，不写则完全没有开销
      "color": "#4DFFFFFF", "width": 0.18, "angle": -22,
      "periodMs": 5200, "blend": "plus", "opacity": 0.4
    }
  }
}
```

**渐变升级为三种形态**（旧写法原样可用）：

```jsonc
// 1. 旧写法：等分色标
"gradient": ["#FF0000", "#0000FF"]

// 2. 旧写法：任意色标
"gradient": { "stops": [ { "color": "#FF0000", "offset": 0 } ] }

// 3. 完整写法：形态 + 方向 + 铺贴
"gradient": {
  "kind": "linear",                  // linear | radial | sweep
  "begin": "topLeft", "end": "bottomRight",   // linear，-1..1 或 "top-right"
  "center": [0.8, 0.2], "radius": 1.2,        // radial，radius 是短边比例
  "startAngle": 0, "endAngle": 360,           // sweep，角度制
  "tile": "clamp",                   // clamp | repeat | mirror | decal
  "stops": [ { "color": "#FF6B3D", "offset": 0 } ]
}
```

**混色模式**（`blend` / `overlay.blend` / 背景层的 `blend`）可选：
`normal` / `multiply` / `screen` / `overlay` / `darken` / `lighten` /
`colorDodge` / `colorBurn` / `hardLight` / `softLight` / `difference` /
`exclusion` / `hue` / `saturation` / `color` / `luminosity` / `plus` / `modulate`。

**约束：** blur ≤ 200、saturation/brightness/contrast ≤ 4、grayscale ≤ 1、
阴影最多 8 条、流光周期 200ms–20s。越界收敛不报错，未知值忽略。

> **流光与漂移默认关闭。** 只有显式写了 `shimmer`（或下面氛围的 `driftSeconds`）
> 才会创建动画。系统开启「减弱动态效果」时，装饰动画自动停用，材质照常绘制。

#### background 的调色与多层混色

全屏背景图可以像任何材质一样被调色、混色，这是「照片当壁纸」能用的前提：

```jsonc
"background": {
  "image": "assets/bg.webp", "fillMode": "cover",
  "blur": 32, "saturation": 1.4, "brightness": 0.9,
  "contrast": 1.1, "grayscale": 0, "scale": 1.05,
  "overlay": "#000000", "overlayOpacity": 0.3,
  "overlayGradient": { "kind": "radial" }, "overlayBlend": "softLight",
  "layers": [                        // 任意多层混色，最多 8 层
    { "gradient": { "kind": "radial" }, "blend": "screen", "opacity": 0.6 }
  ]
}
```

#### ambient 的多光源与漂移

单条光带升级为任意多个柔光源。`lights` 为空时沿用旧行为：

```jsonc
"ambient": {
  "enabled": true, "strength": 0.3, "heightFraction": 0.42, "blur": 64,
  "driftSeconds": 24,                // >0 时光源缓慢漂移；0 = 完全静止
  "lights": [                        // 最多 6 个
    { "color": null, "anchor": "topLeft", "radius": 1.1,
      "strength": 0.3, "blur": 80, "blend": "screen" },
    { "anchor": [0.2, 0.6], "radius": 0.9, "strength": 0.22 }
  ]
}
```

`color` 省略（或 `null`）时跟随当前封面主色，这是设计稿的本意；写死颜色则是
「无论放什么都用品牌光晕」的退路。

> **`effects.blur` / `effects.glassOpacity` 仍然有效**，它们是材质出现之前的写法：
> 只写这两个字段的旧皮肤会得到外壳磨砂。材质字段优先，两者不会互相覆盖。

### 4.3 颜色怎么写

支持三种格式：

| 格式 | 示例 | 说明 |
|---|---|---|
| 6 位 hex | `#FF0000` | 最常用 |
| 3 位简写 | `#F00` | 等价于 #FFFF0000 |
| 8 位带 alpha | `#80FF0000` | 前两位是透明度 |

> **建议写 8 位**：很多 MusicFree 主题用 rgba(255,255,255,0.1) 做半透明表面，换成 8 位 hex 就是 #1AFFFFFF。


---

### 4.4 界面文字（`strings`）

**壳层（导航栏、顶栏、队列面板）上的文字由皮肤声明**，不在 App 里写死。
这样一份中文设计稿不必再显示英文导航。

```jsonc
"strings": {
  "nav.discover": "发现",
  "nav.library": "内容库",
  "nav.settings": "设置",
  "search.hint": "搜索歌曲、歌手、专辑",
  "queue.title": "当前播放",
  "queue.count": "{count} 首"
}
```

**只写你想改的那几条**，没写的自动用中性默认值（`nav.library` 默认 `Library`）。
未知键会被忽略，所以为更新版本 App 写的皮肤在旧版本上仍能正常加载。

可覆盖的槽位是**封闭集合**——皮肤能改 App 已经渲染的文字，不能新增界面。
当前的槽位：

| 前缀 | 内容 |
|---|---|
| `nav.*` | 侧栏主导航（`nav.search` / `nav.discover` / `nav.library` / `nav.nowPlaying` / `nav.playlists` / `nav.downloads` / `nav.plugins` / `nav.settings`） |
| `nav.section.playlists` / `nav.playlists.empty` | 侧栏分组标题与空态（默认 `My playlists` / `No playlists yet`） |
| `tab.*` | 手机底部 tab（`tab.discover` / `tab.library` / `tab.search` / `tab.mine`） |
| `rail.brand` / `rail.profile.name` / `rail.profile.subtitle` | 品牌名与资料卡 |
| `search.hint` / `search.action` / `search.stop` | 顶栏搜索 |
| `queue.*` | 队列面板标题、分页、空态、清空与开合提示 |
| `library.title` | 内容库页标题 |
| `library.subtitle` / `library.importFiles` / `library.importFolder` / `library.empty` | 内容库页的副标题、导入按钮与空态 |
| `player.back` / `player.nothingPlaying` / `nowPlaying.close` | 播放条返回提示与空态 |
| `quality.*` | 音质 chip 的两个分类（`无损` / `标准`）与提示 |
| `discover.more` / `discover.back` | 发现页的插件浏览器入口 |
| `appearance.mode.*` | 外观面板的明暗选择 |

### 导航入口（`navigation`）

皮肤已经决定导航长什么样，所以它可以决定三件事：

- 哪些入口**值得出现**——典型的原因和《玄》一样：侧栏已经列出 `playlists`，正下方又有
  同一目的地的歌单分组，两个入口指向同一个页面，看起来像两套导航
- 入口的**排列顺序**——侧栏的先后本身就是界面构成的一部分：围绕「听」设计的皮肤会把
  `discover` 放前面，围绕本地收藏设计的会把 `library` 放前面
- 放不下的入口**去哪里**——手机底部 tab 栏只放得下四五个，而 App 的目的地比这多

```jsonc
"navigation": {
  "desktop": ["playlists"],      // 桌面端隐藏的入口
  "mobile": [],                  // 手机端隐藏的入口
  "desktopOrder": ["library"],   // 桌面端：这些入口排在最前
  "mobileOrder": [],             // 手机端：这些入口排在最前
  "desktopOverflow": "none",     // 桌面端溢出去向
  "mobileOverflow": "moreTab"    // 手机端溢出去向
}
```

`desktop` / `mobile` 是**扁平数组**（不是 `hidden` 子对象），两者独立，
与 `layout.home` 的分叉规则一致；只写其中一个不影响另一个。

#### 入口排序（`desktopOrder` / `mobileOrder`）

排序是**前缀**，不是完整排列：皮肤只写它关心的那几个，没提到的入口保持内置相对顺序，
排在写出来的那些后面。

```jsonc
"desktopOrder": ["library", "discover"]
// 内置顺序是 search, discover, library, ...
// 实际渲染：library, discover, search, ...
```

这样设计有两个理由：皮肤只需表达它真正想改的那一件事（「把发现放前面」），不必把整份
它基本认同的列表重述一遍；而且 App 日后新增目的地时，老皮肤不会因为写死了完整排列而
把新入口弄丢。

未知名字和重复项被忽略（重复时以第一次出现为准）。**隐藏优先于排序**：`applyOrder`
只作用于已经过滤掉隐藏项的选择集，所以不能靠排序把一个自己已经隐藏的入口「排回来」，
也不能把某个界面本来不提供的入口排进去。

#### 溢出槽位（`desktopOverflow` / `mobileOverflow`）

| 值 | 行为 |
|---|---|
| `none` | 没有溢出容器，只显示放得下的入口 |
| `moreTab` | 主导航末尾出现一个「更多」入口，点开是底部抽屉，列出其余入口 |
| `homeHeader` | 溢出的入口挂在首页头部、搜索框旁边 |

默认值刻意不对称：桌面是 `none`（侧栏本来就放得下全部），手机是 `moreTab` 而不是
`none`。手机不可能一次显示全部目的地，默认 `none` 恰恰是「导入插件在手机上找不到入口」
的成因。皮肤如果**刻意**要做极简界面，可以显式写 `none`。

**约束（有意收紧，不是漏掉）：**

- 只能隐藏**导航入口**，不能隐藏区域。`content`、`playerBar` 永远渲染，否则 App 不可用
- `settings` 永远无法隐藏——那是回到外观面板的唯一入口，不能让皮肤把用户困在外面
- 被隐藏的入口仍然可达：它重复的那个入口、快捷键、以及队列页等次级路径都还在
- 未知名字被忽略

`quickActions` / `categoryChips` 等首页区块里的**作者自定义文案**（如「每日电台」）不在其内：
那些是内容位，不是壳层。

> 注意：这是**皮肤能力，不是多语言系统**。没有复数、没有日期/数字格式化，功能页面的文案也不在其中。
> `queue.count` 只支持一个 `{count}` 占位符；语言有复数变化时，请写成不依赖单复数的说法
> （例如省略量词），而不是期待 App 去推断。

### 界面图标（`icons`）

图标是最后一块皮肤碰不到的界面元素：侧栏某一行、播放条某个按钮，原本都是 App 里的
`Icons.*` 字面量，皮肤只能改它的颜色，改不了它的形状。这把皮肤的差异上限压在了
「同一套 Material 字形配不同颜色」——换色不换形。

```jsonc
"icons": {
  // 简写：一个码点，用字体自带的图标集（这里是 Material）
  "discover": "0xE037",

  // 完整写法：换成皮肤自带的图标字体里的字形
  "play":    { "glyph": "0xE800", "size": 26, "color": "#FF6B3D" },
  "like":    { "image": "icons/heart.png", "size": 22 },
  "volume":  { "codePoint": "0xE050", "fontFamily": "SegoeIcons" }
}
```

三种声明方式，精细度递增：

| 字段 | 含义 |
|---|---|
| `codePoint` | 某个字体里的码点；`fontFamily` 省略时用平台图标字体 |
| `glyph` | 皮肤自带图标字体（`assets.icons.font`）里的码点 |
| `image` | 皮肤自带的位图，用于字体表达不了的图形 |

码点接受 `57431`、`"0xE037"`、`"E037"` 三种写法——图标字体的 cheat sheet 发布的通常是
十六进制，强制十进制只会逼每位作者自己做一次转换。

**自带图标字体：**

```jsonc
"assets": {
  "icons": { "font": "icons/set.ttf", "fontFamily": "MySet" }
}
```

族名会被自动加命名空间（`robyne_<来源>_<皮肤id>_icons_MySet`）。即使你把这套字集命名为
`MaterialIcons`，它也**不会**真的变成 `MaterialIcons` 并顶替 App 自己的字形：
两个皮肤不能撞族名，皮肤也不能劫持已有族名。

当前槽位（封闭集合）：`search` / `discover` / `library` / `nowPlaying` / `playlists` /
`downloads` / `plugins` / `settings` / `more` / `back` / `like` /
`play` / `pause` / `skipNext` / `skipPrevious` / `queue` / `volume` / `lyric`。

**选中态与普通态：** 侧栏、tab、爱心这类控件靠「描边 ↔ 填充」的切换表达「你在这里」。
只声明一个字形会把这种区分压平，所以三种画法都有对应的 `active` 版本：

```jsonc
"icons": {
  "discover": { "glyph": "0xE001", "activeGlyph": "0xE002", "activeColor": "#FF6B3D" },
  "like":     { "codePoint": "0xE87E", "activeCodePoint": "0xE87D" }
}
```

不写 `active*` 时，选中态复用普通态——对于没有填充变体的图标字体，这正是想要的默认。
只写了 `active*` 而不写普通态也能用：普通态会复用你声明的那个，而不是退回 Material，
因为作者显然是想让这个槽位用自己的图形。

**约束：**

- 声明无效（码点不是数字、图缺失或超限、字体加载失败）时**回退到 App 的字形**。
  图标不是装饰：播放键必须一直找得到，皮肤不允许靠写坏一个图标来删掉一个控件
- `size` / `color` 是可选的单项覆盖；不写就用那一处界面本来决定的值，这样声明的图标
  不会撑破它并不了解的紧凑行
- 未知槽位被忽略

**实现约束（给改这段代码的人）：** 皮肤码点只能在运行时拿到，所以**不能用**
`IconData(codePoint, fontFamily: ...)` 去画它。release 构建会跑一个图标树摇
（icon tree-shaker），它扫描编译产物里的所有 `IconData`；任何一个「非常量」实例都会让
构建直接失败：
`Avoid non-constant invocations of IconData or try to build again with --no-tree-shake-icons.`
`ThemeIconView` 因此用 `RichText` + `TextStyle` 直接画出码点——这正是 `Icon` 内部的做法，
像素一致，但不存在运行期构造的 `IconData`。

`test/theme_tree_shake_guard_test.dart` 守着这条线：它会扫描 `lib/` 下所有
`IconData(...)`，要求每一处都在 `const` 上下文里。如果你非要恢复 `Icon` 的画法，
就得同时用 `--no-tree-shake-icons` 放行（代价是 Material 字体从 11KB 涨回 1.6MB），
或者把这条守卫一并证明为过时。

## 4.5 布局（layout）—— 多端的关键

**Token 全局共享，Layout 按形态分叉。** 皮肤不写像素，只写「哪个区域放在哪个槽位、占主轴多少比例」。

### 区域与槽位

区域身份是固定的 5 个，不能新增：

| 区域 | 含义 | 桌面合法槽位 | 手机合法槽位 |
|---|---|---|---|
| `topBar` | 全局搜索 / 窗口控制 | `top` | `top` |
| `navBar` | 主导航 | `left` / `right` / `bottom` | `bottom` / `top` |
| `content` | 页面内容，**每个形态必须存在** | `center` | `center` |
| `playerBar` | 播放条 | `bottom` / `top` | `bottom` / `top` |
| `queue` | 播放队列 | `left` / `right` / `bottom` | `bottom` / `top` |

`size` 是主轴比例（`0.05`–`0.40`），不是像素；`content` 不写 `size`，它永远占剩余空间。

### 官方默认

```jsonc
"layout": {
  "desktop": {
    "arrangement": [
      { "region": "topBar",    "slot": "top",    "size": 0.06 },
      { "region": "navBar",    "slot": "left",   "size": 0.14 },
      { "region": "content",   "slot": "center" },
      { "region": "queue",     "slot": "right",  "size": 0.24 },
      { "region": "playerBar", "slot": "bottom", "size": 0.09 }
    ]
  },
  "mobile": {
    "arrangement": [
      { "region": "content",   "slot": "center" },
      { "region": "playerBar", "slot": "bottom", "size": 0.09 },
      { "region": "navBar",    "slot": "bottom", "size": 0.09 }
    ]
  },
  "content": { "listStyle": "grid" }   // list | banner | card | grid | compact
}
```

`listStyle` 是**全局默认**；设计稿 §2.5 的表格是**按页面**给的（本地库用 `list`、
发现页用 `grid`、推荐横幅用 `banner`），所以还可以逐个目的地覆盖：

```jsonc
"content": {
  "listStyle": "list",          // 没写 styles 的页面用这个
  "styles": {
    "library": "list",          // 本地库
    "discover": "grid",         // 发现页歌单宫格
    "playlists": "card",        // 歌单详情
    "downloads": "list",
    "queue": "list",
    "search": "list"
  }
}
```

可用目的地是**封闭集合**：`library` / `discover` / `playlists` / `downloads` /
`queue` / `search`。未知目的地与未知值都被忽略（不会因为写错一个值就悄悄退化成
`list` 覆盖掉原本的安排）。

**只写你想改的形态。** 另一个形态自动继承官方默认：

```jsonc
"layout": {
  "mobile": {
    "arrangement": [
      { "region": "content", "slot": "center" },
      { "region": "navBar",  "slot": "bottom", "size": 0.12 },
      { "region": "playerBar", "slot": "bottom", "size": 0.09 }
    ]
  }
}
```

#### `content.listStyle` 的五个值分别是什么

| 值 | 效果 |
|---|---|
| `list` | 常规行列表（封面 + 标题 + 时长），默认值 |
| `grid` | 自适应宫格，封面卡片密排 |
| `card` | 封面卡片流（与 `grid` 同族，卡片感更重） |
| `banner` | **横向封面流**：一行可横向滑动的推荐横幅，带标题与歌手 |
| `compact` | 横屏手机用的压缩行，行高与分隔线一起收紧 |

五个值都有真实分支，写哪个就渲染哪个——不存在「声明了但静默回退」的值。

### 首页区块（`layout.home`）

首页不是写死的页面，而是一串**区块**。皮肤声明区块和顺序，应用负责给每个区块填数据；
数据源没准备好时区块显示设计稿的占位形态，不会塌成空白。

| 区块 | 内容 |
|---|---|
| `quickActions` | 手机端的四宫格快捷入口（每日电台 / 排行榜 / 分类歌单 / 我喜欢） |
| `hero` | 渐变英雄横幅 + 主行动按钮 |
| `recommendations` | 横向滚动的推荐卡片流 |
| `recent` | 最近入库的本地曲目 |
| `favorites` | 红心歌曲列表（手机设计稿的主列表） |
| `queue` | 当前队列的精简列表 |

`home` 和 `layout.<形态>.arrangement` 一样可以**只写你想改的形态**：

```jsonc
"home": {
  "blocks": ["quickActions", "hero", "recommendations", "recent"],  // 两形态共用
  "desktop": { "blocks": ["hero", "recommendations", "recent"] },
  "mobile":  { "blocks": ["quickActions", "hero", "favorites"] }
}
```

只写 `blocks` 就两形态共用；只写 `mobile` 时桌面自动用 `blocks`（再退回官方默认）。
未知区块名被忽略，空列表不生效。

### 容错与自动降级

布局的容错是**应用责任**，不是作者责任：

- 未知区域 / 非法槽位：只有该条被丢弃，其余照常，缺失区域继承官方值
- 缺少 `content`：整个形态回退官方 baseline，绝不白屏
- 比例超界：收敛到 `0.05`–`0.40`；非数字回退官方值
- 空间不足：按 `queue → topBar → playerBar 压缩 → navBar 图标化` 降级，`content` 永不牺牲
- 桌面专用布局被手机加载：手机的 `mobile` 仍使用自己的 arrangement，不会硬塞侧栏

### 保存即生效（热重载）

**客户端不提供调色、圆角或布局编辑器。** 皮肤就是 `theme.json`，你在编辑器里改完保存，App 会自动重载。

监听范围：用户皮肤目录 `<themes>/<skin-id>/` 下的所有文件（`theme.json` 与随包资源），
去抖 250ms 后重新解析当前皮肤。

- 一次保存触发的多步写入（写临时文件 → 改名 → 截断）只会重载一次
- 以 `.` 开头的临时文件与 `~` 结尾的备份文件被忽略
- 解析失败时保留上一份可用皮肤，不会白屏；改回正确内容后下一次保存即恢复

> 运行时改动的是**用户皮肤**（`%APPDATA%\robyne\themes\...`）。
> 内置的 `assets/themes/xuan/` 打包进 App，运行时无法热更新；开发内置皮肤请把它复制到用户目录再改。

---

## 5. 声明可调参数（settings）

`settings` 仍然被解析，但**旗舰版客户端不再渲染这些控件**：皮肤的可调项由作者直接写进
`tokens`。保留该段是为了未来可能出现的独立编辑器或编辑模式。

```jsonc
"settings": [
  {
    "key": "brandColor",
    "type": "color",
    "label": "强调色",
    "default": "#F2B749",
    "target": "color.brand.base"
  },
  {
    "key": "cornerRadius",
    "type": "range",
    "label": "圆角",
    "min": 0,
    "max": 28,
    "default": 10,
    "target": "radius.md"
  },
  {
    "key": "listStyle",
    "type": "select",
    "label": "列表样式",
    "options": ["list", "card", "grid"],
    "default": "card"
  }
]
```

type 支持：range、color、toggle、text、select

target 支持 `components.*`，例如把歌词高亮色也做成旋钮：

```jsonc
{ "key": "lyricHighlight", "type": "color", "label": "歌词高亮",
  "default": "#6EA8FE", "target": "components.lyric.activeLine" }
```

> 注意：**gradient 不能作为旋钮目标。** 滑块和取色器产不出结构化值，
> 允许旋钮写渐变等于让皮肤绕过校验塞入任意数据。渐变只能在 `tokens` 里静态声明。

---

## 6. 容错：你的皮肤永远不会害白屏

我们对皮肤做了严格防御：

| 情况 | 行为 |
|---|---|
| theme.json 解析失败 | 回退到**上一个成功加载的皮肤**，并在设置页提示 |
| 缺少某个 token | 用内置默认值补齐 |
| token 值非法（如 "radius": "abc"） | 忽略该值，用默认值 |
| 值超出范围（如 "blur": 999） | **自动收敛到边界**（999 变成 40），不报错 |
| 背景图缺失 | 忽略背景图，其余照常 |
| 出现未知字段 | 忽略，仅 debug 日志 |
| 单个皮肤目录损坏 | 不影响其他皮肤的显示 |

**注意「回退到上一个皮肤」这条**：这是特意的。假设用户装了你的皮肤但文件坏了，我们希望他回到上次那个能用的皮肤，而不是突然被扔回默认蓝——那样会很突兀。

---

## 7. 分发

### 本地安装（当前）

把皮肤目录放进用户目录的 themes/ 下即可，App 启动时自动发现。

Windows：`%APPDATA%\robyne\themes\<your-theme-id>\`

### 资源限制

沿用业界合理约束：

- 单张图片不超过 500KB
- 单个视频不超过 5MB
- 整包不超过 10MB

建议用 **WebP** 格式，比同等画质 PNG/JPG 小很多。

---

## 8. 从 MusicFree 皮肤迁移

我们不强兼容 index.css，但迁移很简单，因为**两边的信息量是一样的**——都是一组语义色。

对照表：

| MusicFree CSS 变量 | Robyne token |
|---|---|
| --color-bg-base | tokens.color.background.base |
| --color-bg-surface | tokens.color.surface.base |
| --color-fill-brand | tokens.color.brand.base |
| --color-text-primary | tokens.color.text.primary |
| --color-border-default | tokens.color.border.default |
| --bg-image | tokens.background.image |
| backdrop-filter: blur() | tokens.effects.blur |

把 rgb(r,g,b) 转成 hex 即可。

**而且你会得到 MusicFree 没有的东西**：间距、圆角、字体、用户可调旋钮、多端布局。

---

## 9. 清单

发布前检查：

- id 唯一（建议 作者.主题名）
- name / author / version / description 已填
- preview 要么是包内路径，要么是 #RRGGBB
- 在浅色和深色下都看过效果
- 图片已压缩，整包不超过 10MB
- 如果用了 settings，每个都有合理的 default
