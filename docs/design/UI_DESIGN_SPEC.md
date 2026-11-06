# Robyne 旗舰 UI 视觉设计稿

> 状态：**已定稿 · 已由《玄》皮肤与旗舰 UI 实现**（阶段 2 完成）
> 本文仍是视觉判定的权威：实现与本文冲突时，以本文为准并改代码。
> 关联：`docs/THEME_ROADMAP.md`（OPEN-1 / D2 / D4 / D6 / D7）、`docs/ADR-001-responsive-window-size-class.md`

---

## 1. 设计立场

这份设计稿借鉴 QQ 音乐的**信息层级**（侧栏 → 顶栏 → 内容 → 播放条），但视觉语言完全独立：

- 色彩：近黑底 + 珊瑚橙品牌色 + 薄荷绿辅助，不使用 QQ 音乐的绿色与蓝紫渐变
- 圆角：小件 6px / 卡片 8px / 大面板 16px，大封面和播放页可到 20px
- 字体：保持平台默认字体，不做品牌字体绑定
- 图标：不照抄第三方图标，用 Material Icons 通用形态描述
- 交互：列表行 hover 展示操作；快捷功能优先一级可达，低频项收进更多菜单
- 氛围：内容区跟随当前/邻接封面生成柔光渐变，播放页进一步用模糊封面做沉浸层

### 1.1 不照抄的判断

参考图里值得保留的结构判断：**左侧导航占主轴比例而非固定像素**、**内容区承担信息密度**、**播放条常驻**。

不保留的判断：

- 推荐位不是常驻区域，它只是 `content.style` 的 `banner` 变体
- 歌单详情页的横向滚动推荐位不是独立区域，它只是 `banner` 的实例
- 播放页全屏展开后覆盖整个应用窗口；不在沉浸态里复制第二套控制区，退出入口与窗口控制保持一级可达

---

## 2. 区域集合（回答 OPEN-1）

### 2.1 桌面（expanded width）

```jsonc
{
  "desktop": [
    { "region": "topBar",    "slot": "top",    "size": 0.06 },
    { "region": "navBar",    "slot": "left",   "size": 0.14 },
    { "region": "content",   "slot": "center" },
    { "region": "playerBar", "slot": "bottom", "size": 0.09 },
    { "region": "queue",     "slot": "right",  "size": 0.24, "overlay": false }
  ]
}
```

`queue` 开合由播放条队列按钮或快捷键控制。窗口空间不足时 `queue` 收为 overlay。

队列必须与播放条右区的「播放列表」入口同侧：默认停靠在内容区右侧。触发点、光标运动方向和展开位置在同一侧，符合就近操作原则；皮肤或布局把导航移到右侧时，播放条与队列整体镜像。

### 2.2 移动端（compact / medium width）

```jsonc
{
  "mobile": [
    { "region": "content",   "slot": "center" },
    { "region": "playerBar", "slot": "bottom", "size": 0.09 },
    { "region": "navBar",    "slot": "bottom", "size": 0.09 }
  ]
}
```

`topBar` 在移动端完全不出现。搜索入口收进内容区顶部：首页头部一条（`mobile-portrait.png` 的 `.msearch`），**搜索结果页正文再一条**。后者不是重复——手机没有 `topBar`，全局搜索框在屏幕上根本不存在，结果页若不自带输入框，用户想换关键词就只能退回首页头部；桌面端不渲染这一条，因为 `topBar` 已经提供了唯一输入框（`ShellChrome.topBarVisible` 是这里的判据）。

### 2.3 桌面 compact-height 退化

窗口高度 compact 时，按顺序：

1. `queue` 收为右侧 overlay
2. `topBar` 压到 0.04
3. `playerBar` 降为 mini bar
4. `navBar` 收成图标条（labelMode=none）

### 2.3.1 侧栏的“死区”必须塌成胶囊

比例换 dp 是应用的事（D7），不是皮肤的。侧栏有一条皮肤比例恰好落不进去的带：

| 解析出的侧栏宽 | 该画什么 | 该占多少 |
|---|---|---|
| ≥ 168dp | 图标 + 标签 | 皮肤声明的比例 |
| < 168dp | 只画图标 | **72dp 胶囊，不是比例值** |

落在中间带的宽度是纯浪费：旗舰皮肤 0.18 的比例在 760dp 窗口上算出 137dp，比它实际画的 22dp 图标宽了 65dp，那 65dp 只是居中图标两侧的空白。所以解析侧栏时若宽度低于标签阈值，就同时设 `navIconOnly = true` 并把该侧压到 72dp——把省下的宽度还给 `content`。

只压 nav 所在的一侧。另一侧可能是停靠的 queue，它的 240dp 是队列自己的内容，不该被侧栏的胶囊规则挤掉。

### 2.4 区域集合就是这 5 个

| 区域 | 桌面 | 移动端 |
|---|---|---|
| `topBar` | top，搜索 + 窗口控制 | 不出现 |
| `navBar` | left，可被皮肤挪到 right | bottom tab |
| `content` | center，必有 | center，必有 |
| `playerBar` | bottom | bottom |
| `queue` | right，与入口同侧；可与 content 并列 | 收进 content |

推荐位 / 排行榜 / 歌单宫格都是 `content.style` 的实例。歌词是 NowPlayingPage 的内部布局，不是独立区域。

### 2.5 `content.style` 枚举

| 枚举值 | 用途 |
|---|---|
| `list` | 歌单详情、队列、本地库 |
| `grid` | 发现页歌单宫格 |
| `banner` | 推荐横幅、歌单详情顶部横幅 |
| `card` | 歌单封面卡片流 |
| `compact` | 横屏手机列表行高压缩 |

---

## 3. 视觉系统

### 3.1 颜色 token

深色皮肤基准：

| Token | 值 | 用途 |
|---|---|---|
| `color.background.base` | `#0E0F12` | 全局底色 |
| `color.background.elevated` | `#15171B` | 面板、侧栏、顶栏 |
| `color.background.sunken` | `#0A0B0D` | 内容区最深底层 |
| `color.surface.base` | `#1A1D21` | 卡片 |
| `color.surface.hover` | `#22262B` | 卡片悬浮 |
| `color.surface.selected` | `#2E211D` | 列表选中 |
| `color.brand.base` | `#FF6B4A` | 主操作、播放按钮 |
| `color.brand.hover` | `#FF8570` | 悬浮 |
| `color.brand.muted` | `#33FF6B4A` | 品牌弱化 |
| `color.onBrand` | `#141517` | 品牌色上的文字 |
| `color.accent.base` | `#5AD0BE` | 薄荷绿，用于无损/高音质与二级强调 |
| `color.accent.muted` | `#245A50` | 薄荷绿弱化 |
| `color.text.primary` | `#F2F3F5` | 主文本 |
| `color.text.secondary` | `#A9AEB6` | 次文本 |
| `color.text.muted` | `#6E737B` | 弱文本 |
| `color.border.subtle` | `#14FFFFFF` | 分隔线 |
| `status.success` | `#5AD0BE` | 成功态 |

亮色皮肤基准：

| Token | 值 |
|---|---|
| `color.background.base` | `#F4F3F1` |
| `color.background.elevated` | `#FFFFFF` |
| `color.background.sunken` | `#E9E8E4` |
| `color.surface.base` | `#FFFFFF` |
| `color.brand.base` | `#E85A3B` |
| `color.accent.base` | `#3C9B8B` |
| `color.text.primary` | `#1B1D20` |
| `status.success` | `#3C9B8B` |

### 3.2 尺寸与间距

| 项 | 桌面 | 移动 |
|---|---|---|
| 内容区左右 padding | 32 | 16 |
| 列表行高 | 56 | 64 |
| 卡片最小宽 | 180 | 140 |
| 卡片间距 | 16 | 12 |
| 播放条高度（比例） | 0.09 | 0.09 |
| 侧栏比例 | 0.14 | 不适用 |

### 3.3 字体

| 层级 | 字号 | 字重 |
|---|---|---|
| 页面标题 | 24 | 600 |
| 区块标题 | 18 | 600 |
| 列表主文本 | 15 | 400 |
| 列表次文本 | 13 | 400 |
| 标签 / 徽标 | 11 | 500 |

### 3.4 氛围系统

Robyne 的标志性识别不是固定色块，而是「封面驱动氛围」：

1. 页面内容顶部从当前区块主封面取主色，生成 20%-35% 透明度的柔光渐变
2. 柔光只叠加在 `content` 的前 25%-35% 高度，向下衰减为 `background.base`
3. 文本仍按原 token 渲染；氛围层不参与可读性判断
4. 播放页使用全屏模糊封面 + 颜色遮罩，亮度压到 `0.18-0.28`
5. 皮肤可以关闭氛围层，关闭后 content 直接使用 `background.base`

实现时氛围层只是普通 Layer/Container，不侵入文字组件。

### 3.5 快捷操作分级

| 层级 | 位置 | 项 |
|---|---|---|
| 一级 | 播放条 / 行内 / 卡片 hover | 我喜欢、播放/暂停、队列 |
| 二级 | 播放条右区 | 播放模式、无损/高音质、桌面歌词、播放列表、音量 |
| 三级 | 更多菜单 | 查看专辑、查看歌手、加入歌单、下载、分享、显示歌词 |

移动端 `playerBar` 保留：我喜欢、更多菜单、播放/暂停、播放列表。音质切换与桌面歌词收进更多菜单。

---

## 4. 关键页面

### 4.1 桌面 · 内容库

结构从左到右：

1. `navBar`：搜索、发现、内容库、播放页、下载、插件、设置
2. `topBar`：全局搜索框、窗口控制
3. `content`：标题 + 工具行 + 列表
4. `playerBar`：封面 / 标题 / 播放控制 / 进度 / 队列入口

列表行设计：

| 列 | 内容 |
|---|---|
| 1 | 封面，40x40，radius 6 |
| 2 | 标题 + 艺术家 |
| 3 | 标签（可选） |
| 4 | 专辑 |
| 5 | 时长 |

悬浮态：行背景 `surface.hover`，标题右侧出现播放 / 加入队列两个图标按钮。

### 4.2 桌面 · 发现

发现页是**一级页面**：排行榜与热门歌单同时在场，不再藏进二级的「插件榜单」
浏览器，也没有「每日电台」区块。

`content` 从上到下：

1. 页头：标题「发现」+ 副标题「排行榜与热门歌单」+ 刷新
2. `sources`：插件来源描边 pill 行，横向滚动；形态与搜索结果页的来源条一致
3. 双栏（可用宽度 ≥ 620dp 且高度不是 compact）：
   - 左栏「排行榜」：分组标题 + `grid`，3-5 列自适应
   - 右栏「热门歌单」：标签 pill 行 + `grid`/`card`，3-6 列自适应，滚动到底加载下一页

可用宽度不足（窄桌面、手机）时，两栏改为同一滚动列内的上下两段，顺序不变。
点击任一榜单或歌单，整页切到曲目详情；返回按钮回到这两段。

### 4.2.1 桌面 · 发现（窄窗口与手机）

- 竖屏：页头占一行标题 + 副标题，来源条在其下；两段上下堆叠，来源条横向滚动
- 横屏（compact height）：页头压成单行——标题、来源条、刷新同一行；两段继续堆叠
- 详情页在所有形态下都是整页，不再保留二栏 master/detail；页头是封面 + 标题 + 刷新，**没有自己的返回键**——退出走顶栏前进/后退、系统返回，或再点一次「发现」（任何一种都会回到排行榜 + 热门歌单）

### 4.3 桌面 · 播放页

点击播放条歌曲头像后，播放页覆盖整个应用窗口，包括 `topBar`、`navBar`、`content` 与全局 `playerBar`。沉浸态不保留双套控制区：

1. 背景：模糊封面 + 颜色遮罩，做全屏沉浸
2. 左侧：封面 + 唱片旋转隐喻 + 品牌色进度
3. 右侧：歌词，当前行品牌色，非当前行 `text.secondary`
4. 左上角折叠按钮：退出播放页并恢复上一个 `content` 页面
5. 右上角保留窗口控制；不出现第二套播放按钮

全屏播放页是沉浸态，退出后回到上一个 `content` 页面，不产生路由栈污染。

### 4.4 移动端 · 竖屏

`navBar` 在底部，`content` 在上方，`playerBar` 贴在 navBar 上方。

列表行高加大到 64，触控目标不小于 44。

### 4.5 移动端 · 横屏

高度 compact 时：

- `navBar` 收成 48 高图标条
- `playerBar` 收成 mini bar
- `content` 列表行高压到 48
- 推荐页 banner 横向滚动，不压缩为两列

---

## 5. 皮肤压力测试点

### 5.1 播放条快捷操作

桌面 `playerBar` 从左到右为：

1. 封面 + 标题/艺术家
2. 我喜欢（liked = 品牌色填充，默认 = 线性图标）
3. 更多菜单
4. 播放模式 badge（单曲 / 随机 / 顺序）
5. 上一首 / 播放 / 下一首
6. 进度区
7. 音质切换 chip：`无损` 用 `accent.base`，`标准` 用 surface
8. 桌面歌词 toggle
9. 播放列表
10. 音量

约束：

- 图标按钮 42px；音质 chip 高 28
- 窗口宽 < 960 时隐藏桌面歌词与音量，音质 chip 保留
- 窗口宽 < 720 时只保留我喜欢、更多菜单、播放控制、音质 chip、播放列表
- 我喜欢采用乐观 UI：点击后立刻变品牌填充，失败回滚
- 播放列表按钮带 1-999 的 count badge，超过显示 `999+`

手机 `playerBar` 为：封面 / 标题 / 我喜欢 / 更多 / 播放 / 播放列表。

### 5.2 全局压力项

这份 UI 必须能被皮肤系统覆盖而不破坏可用性：

1. `navBar` 从 left 挪到 right，所有页面仍可用
2. `navBar` 比例调到 0.05 时收成图标条
3. `playerBar` 比例调到 0.14 时进度条不换行
4. `queue` 比例调到 0.40 时 content 仍有可读宽度
5. `content.style` 从 list 切到 grid 时，本地库与发现页都能正确重排
6. 品牌色换成深蓝、亮黄、暗红时，`onBrand` 对比度仍可读
7. 背景图 + blur 20 时，列表行文字仍满足可读性
8. 横屏手机下任何皮肤组合都不能溢出

---

## 6. 实施映射

### 6.1 皮肤系统落点

| 设计元素 | 皮肤系统落点 |
|---|---|
| 桌面骨架 | `layout.desktop.arrangement` |
| 移动骨架 | `layout.mobile.arrangement` |
| 侧栏宽度 | `navBar` 主轴比例，非像素 |
| 列表风格 | `content.style` |
| 导航渐变 | `components.navBar.gradient` |
| 导航选中态 | `components.navBar.selectedItem` / `selectedIndicator` |
| 播放条背景 | `components.playerBar.gradient` |
| 播放条进度 | `components.playerBar.progressTrack` / `progressActive` |
| 列表选中 | `components.list.itemSelected` |
| 列表悬浮 | `components.list.itemHover` |
| 歌词当前行 | `components.lyric.activeLine` |
| 歌词非当前行 | `components.lyric.inactiveLine` |
| 卡片表面 | `components.card.surface` / `hover` / `selected` |
| 动效节奏 | `components.motion.shortDurationMs` / `mediumDurationMs` / `curve` |

### 6.2 播放条操作落点

快捷操作属于应用层能力，不能由皮肤决定“有没有”。皮肤只决定它长什么样：

| 操作 | 应用层落点 | 皮肤只可覆盖 |
|---|---|---|
| 我喜欢 | `PlayerBarActions.like` | 图标颜色、选中填充色 |
| 更多菜单 | `PlayerBarActions.more` | 图标颜色、菜单表面 |
| 播放模式 | `PlayerBarActions.playMode` | badge 颜色 |
| 音质切换 | `PlayerBarActions.quality` | chip 背景与文字色 |
| 桌面歌词 | `PlayerBarActions.desktopLyric` | toggle 开启色 |
| 播放列表 | `PlayerBarActions.queue` | count badge 颜色 |
| 音量 | `PlayerBarActions.volume` | 轨道与填充色 |

这些入口的可见性只由窗口尺寸和设置决定，不由皮肤切换改变；否则用户换肤后会丢失功能。

### 6.3 约束

- 氛围层是可选装饰，关闭后布局不位移
- 快捷操作图标使用主题前景色，选中态允许使用品牌色或 `accent`
- 换肤动画只作用于颜色与动效，不改变区域尺寸
- 所有操作必须有 tooltip 与无障碍 label

视觉稿文件：

`docs/design/mockups/index.html` —— **由应用生成，不是画出来的**。每个画板的底图是应用自己渲染的 PNG，区域标注是 `RobyneShellPlan.resolve()` 算出的真实 dp，颜色变量直接读 `assets/themes/xuan/theme.json`。

重新生成：

```bash
ROBYNE_BOARDS=1 flutter test test/design_boards_test.dart --tags boards --update-goldens
python tool/generate_design_html.py
```

画板清单见 `docs/design/mockups/README.md`，生成物在 `test/goldens/boards/`（PNG + 同名的 `.plan.json`）。

> 2026-10-14：此前的手绘 HTML/PNG 与实现漂移严重（品牌色 `#FF6B4A` vs 实际 `#FF6B3D`、侧栏 profile 块已移除、Now Playing 已反相为浅色），已整批替换为生成物。旧 PNG 已删除。
