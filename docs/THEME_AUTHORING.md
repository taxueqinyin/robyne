# Robyne 皮肤制作指南

> ⚠️ **本文档 §4.5「布局（layout）」与当前实现不符。**
> `layout.mobile.*`、`layout.content.*`、`desktop.playerBarHeight`、`desktop.playerBarPosition` 目前**尚未生效**
> （`layout` 段里只有 `desktop.sidebar` 的 `width` / `labelMode` / `position` 三个字段被实际读取）。
> 布局层正在按 [`THEME_ROADMAP.md`](./THEME_ROADMAP.md) 重建，届时本文档会同步修订。
> 其余章节（Token、settings、容错、分发）**仍然准确，可照常使用**。

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
  "assets": {
    "background": "assets/bg.webp",
    "font": "assets/MyFont.ttf"
  }
}
```

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

### 4.3 颜色怎么写

支持三种格式：

| 格式 | 示例 | 说明 |
|---|---|---|
| 6 位 hex | `#FF0000` | 最常用 |
| 3 位简写 | `#F00` | 等价于 #FFFF0000 |
| 8 位带 alpha | `#80FF0000` | 前两位是透明度 |

> **建议写 8 位**：很多 MusicFree 主题用 rgba(255,255,255,0.1) 做半透明表面，换成 8 位 hex 就是 #1AFFFFFF。


---

## 4.5 布局（layout）—— 多端的关键

**Token 全局共享，Layout 按形态分叉。** 这是你的皮肤能同时服务桌面和手机的原因。

```jsonc
"layout": {
  "desktop": {
    "sidebar": {
      "position": "left",       // left | right
      "width": 80,              // 基础宽度（显示标签时会自动加宽）
      "collapsible": false,
      "labelMode": "all"        // all | selected | none
    },
    "playerBarPosition": "bottom",   // bottom | top
    "playerBarHeight": 72
  },
  "mobile": {
    "navigation": "bottomTabs",      // bottomTabs | navigationDrawer
    "playerBarHeight": 64,
    "playerBarCompact": true         // 去掉音量条、收紧边距
  },
  "content": {
    "listStyle": "list",             // list | card | grid | compact
    "density": "regular"             // compact | regular | comfortable
  }
}
```

**只写你想改的那个形态。** 另一个自动继承官方默认：

```jsonc
"layout": { "mobile": { "playerBarHeight": 56 } }   // 桌面保持默认
```

### 宽度说明

`width` 是**基础宽度**。当 `labelMode` 是 `all` 或 `selected` 时会自动加宽以容纳文字：

| labelMode | 实际宽度 |
|---|---|
| none | width |
| selected | width < 100 时 +32 |
| all | width < 120 时 +52 |

> **注意**：`width` 保持官方默认的 `80` 时，侧栏会使用 Flutter 的自适应尺寸（在大屏上表现最好）。只有当你明确想改宽度时才需要设成别的值。

### 布局的容错

布局字段同样强容错：未知的 `position`、非数字的 `width` 都会被忽略并回退到默认值，**不会因为布局写错而崩溃或白屏**。

---

## 5. 让用户能微调你的皮肤（settings）

这部分很划算：你在 JSON 里声明几个参数，用户在设置页拖滑块、选颜色就能改，**不用改 JSON、不用重新打包**。

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