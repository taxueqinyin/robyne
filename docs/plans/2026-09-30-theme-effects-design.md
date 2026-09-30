# 皮肤系统材质层设计（Materials）

> 状态：实施中（2026-09-30）
> 目标：把「效果」从散落在代码里的硬编码提升为皮肤的一等公民，
> 在不放弃「皮肤是纯数据、应用保证不白屏」的前提下，把表现力上限拉到 Flutter 能给的极限。

---

## 1. 问题

当前 `tokens` 体系能表达颜色、圆角、间距、字体、图标、布局、几何，
但**材质效果没有落脚点**：

- `ThemeGradient` 只支持线性渐变，方向写死在渲染代码里；
- 旗舰皮肤 `xuan/theme.json` 里写的 `gradient: { "stops": [...] }`
  解析器根本不认识，实际渲染为「无渐变」——声明被静默吞掉；
- 磨砂的 `effects.blur` 只在沉浸式播放页生效，`glassOpacity` 全项目无人消费；
- 没有混色（BlendMode）、没有光晕（BoxShadow）、没有多光源氛围、没有遮罩层的概念。

结论：**皮肤再怎么写，也只能换色换形，突破不了"平面色块"**。

## 2. 设计原则

1. **效果是数据，不是代码。** 所有效果在 `theme.json` 中声明，皮肤仍是纯数据。
2. **一个词汇表，多个表面。** 新模块 `ThemeMaterial` 描述"一个表面怎么被画出来"，
   七个真实表面复用同一词汇，而不是每个表面长出一套字段。
3. **缺省即上代行为。** 所有新字段缺省时与旧版渲染完全一致（无模糊、无混色、无阴影）。
4. **越界收敛，不报错。** 非法值收敛到边界或忽略，永不白屏。
5. **深度模块。** 解析（manifest）、建模（domain）、解析成 Flutter 值（infrastructure）、
   渲染（presentation）四层各司其职；调用方只认识 `MaterialSurface` 一个接口。

## 3. 模型

### 3.1 `ThemeGradient`（升级）

```jsonc
"gradient": {
  "kind": "linear | radial | sweep",
  "stops": [ { "color": "#FF6B3D", "offset": 0 }, "#63D8C3" ],
  "begin": "topLeft", "end": "bottomRight",      // linear（-1..1 归一化）
  "center": [0.5, 0.3], "radius": 0.8,            // radial（radius 为短边比例）
  "startAngle": 0, "endAngle": 360,               // sweep（角度制）
  "tile": "clamp | repeat | mirror | decal"
}
```

向后兼容：字符串、`["#a", "#b"]`、`[{color, offset}]` 三种旧写法原样可用。

### 3.2 `ThemeMaterial`（新）

```jsonc
"materials": {
  "navBar": {
    "color": "#121417CC",          // 填充色
    "gradient": { },               // 填充渐变（叠加在 color 上）
    "opacity": 0.92,               // 整个填充层的透明度
    "blur": 24,                    // 背景模糊（磨砂）
    "saturation": 1.2,             // 背景增饱和（玻璃）
    "brightness": 1.0,             // 背景明度
    "contrast": 1.0,               // 背景对比度
    "grayscale": 0.0,              // 背景去色
    "blend": "normal",             // 填充层与背景的混色模式
    "overlay": {                   // 第二层混色覆盖
      "gradient": { "kind": "radial" },
      "blend": "softLight",
      "opacity": 0.5
    },
    "border": { "color": "#1CFFFFFF", "width": 1 },
    "radius": null,                // null → 跟随 tokens.radius
    "shadows": [                   // 光晕 / 投影
      { "color": "#66FF6B3D", "blur": 32, "spread": 2, "dy": 6 }
    ],
    "shimmer": {                   // 流光（可选，默认关闭）
      "color": "#33FFFFFF", "width": 0.35, "angle": -20,
      "periodMs": 2400, "blend": "plus", "opacity": 0.5
    }
  }
}
```

七个已接线表面：`navBar` / `topBar` / `playerBar` / `queue` / `card` / `content` / `hero`。
未接线的字段一律不写进模型（不做死 token）。

### 3.3 背景层（升级 `tokens.background`）

```jsonc
"background": {
  "image": "assets/bg.webp", "fillMode": "cover",
  "blur": 32, "saturation": 1.4, "brightness": 0.9,
  "contrast": 1.1, "grayscale": 0, "scale": 1.05,
  "overlay": "#000000", "overlayOpacity": 0.3,
  "overlayGradient": { }, "overlayBlend": "softLight",
  "layers": [                       // 任意多层混色
    { "gradient": { "kind": "radial" }, "blend": "screen", "opacity": 0.6 }
  ]
}
```

### 3.4 氛围层（升级 `components.ambient`）

```jsonc
"ambient": {
  "enabled": true, "strength": 0.28, "heightFraction": 0.32, "blur": 48,
  "driftSeconds": 0,                // >0 时光源缓慢漂移（默认静止）
  "lights": [                       // 多光源晕染；为空则沿用单条光带旧行为
    { "color": null, "anchor": "topLeft", "radius": 0.9,
      "strength": 0.35, "blur": 60, "blend": "screen" }
  ]
}
```

## 4. 渲染

新增 `MaterialSurface`（`presentation/theme_material.dart`）：

```
BoxShadow 光晕（外层）
└─ ClipRRect
   └─ BackdropFilter(blur + 颜色矩阵)
      └─ CustomPaint（填充层 → 覆盖层，各自带 BlendMode）
         └─ child
```

混色通过 `Paint.blendMode` 在同一个绘制层内完成（与 Flutter 的 ShaderMask 同机制），
不做 `saveLayer`，避免每个表面一张离屏缓冲。

## 5. 错误处理与护栏

- 一切数值 clamp（blur ≤ 64、saturation ≤ 3、opacity ≤ 1、阴影 ≤ 8 条、光源 ≤ 6 个）。
- 未知枚举名回退缺省值；未知键忽略。
- 空材质（什么都没声明）不生效，旧皮肤零成本。
- 动画（shimmer / drift）默认关闭，只有皮肤显式声明才创建 ticker。

## 6. 测试

- 解析：三种渐变写法、材质字段、越界收敛、未知键忽略；
- 补丁：`materials.*` 标量旋钮；
- 渲染：模糊产生 `BackdropFilter`、渐变类型正确、混色/阴影/流光可被断言；
- 氛围：多光源渲染、drift 动画只在使用时创建；
- 回归：旗舰皮肤声明的渐变必须真正解析（此前被静默吞掉）。
