# Robyne 最小化音乐播放器规划文档

## 1. 项目定位

Robyne 是一个基于 Flutter 的多端本地音乐播放器。项目优先支持 Windows 和 Android，后续再扩展 macOS。项目早期目标不是复刻完整音乐产品，而是先验证并稳定实现一个核心能力：兼容 MusicFree 风格的 JavaScript 音源插件，让用户可以导入、自写、调试音源脚本，并通过这些脚本完成搜索与播放。

平台优先级必须保持清晰：

1. Windows：第一开发与调试平台，优先用于验证 Flutter 工程、QuickJS 插件运行时、media_kit 播放链路和两个真实测试插件。
2. Android：第一移动端目标，阶段 0 就要验证 debug 构建、NDK/CMake、明文 HTTP 网络配置和 media_kit 原生依赖。
3. macOS：后续扩展目标，架构上必须避免写死 Windows 或 Android 细节，但不在 MVP 阶段优先投入适配。

项目应坚持两个原则：

1. MVP 功能尽量小，优先跑通插件搜索、获取播放地址、播放三条主链路。
2. 架构边界要清晰，播放器、插件运行时、业务用例、UI、存储要解耦，方便后续扩展歌词、歌单、收藏、下载、缓存、桌面端优化、移动端适配等能力。

## 2. 技术可行性结论

整体可行，但核心难点不在 Flutter UI，而在 JavaScript 插件运行时兼容、安全隔离、网络请求适配、跨端差异处理和 MusicFree 插件协议的持续兼容。

### 2.1 可行点

- Flutter 适合做多端 UI 和本地应用，MVP 优先覆盖 Windows 和 Android，后续扩展 macOS。
- 音频播放正式选型为 media_kit。它底层基于 mpv，适合 Windows、Android、macOS 多端播放，并且更适合处理带 headers、User-Agent、Referer 的在线音频流。
- MusicFree 插件本质是 JavaScript 对象导出一组约定方法，例如 platform、search、getMediaSource、getLyric、getAlbumInfo、getMusicSheetInfo 等，可以通过嵌入 JS 引擎或平台侧运行时调用。
- MVP 阶段只要求兼容搜索和播放，不需要一次性实现 MusicFree 全量协议。
- 插件机制天然适合做成独立模块，后续可以单独扩展兼容层而不影响 UI 和播放器核心。

### 2.2 主要风险

| 风险 | 说明 | MVP 应对策略 |
|---|---|---|
| JS 运行时选择 | Flutter/Dart 直接执行 CommonJS 风格插件并不天然支持 require、module.exports、fetch、axios、crypto-js 等能力 | 第一阶段定义 Plugin Runtime 抽象，优先验证 QuickJS + 受控 CommonJS 兼容层；插件能力通过桥接 API 渐进补齐 |
| 插件兼容范围 | MusicFree 社区插件可能使用不同依赖和非标准写法 | MVP 只声明兼容核心接口和两个测试插件所需 API，不承诺 100% 兼容所有插件 |
| 安全问题 | 用户脚本可能访问网络、构造恶意请求、死循环、消耗资源 | 插件运行放入受控沙箱；限制文件系统访问；设置调用超时；插件权限显式化 |
| 跨端差异 | Windows、Android、macOS 的 C/C++ 编译、网络策略、沙盒权限和后台播放能力不同 | MVP 优先 Windows 调试，再验证 Android；插件层接口不绑定平台实现；macOS 后续单独做权限检查 |
| 音频链接可播放性 | 插件返回的播放地址可能需要 headers、userAgent、referer、cookie，也可能返回 http 明文链接 | MediaSource 模型必须包含 url、headers、quality、expires 等扩展字段；播放器使用 media_kit；Android 开启必要明文网络配置 |
| 原生依赖编译 | QuickJS 和 media_kit 都涉及原生组件，不同平台需要 C/C++、CMake、NDK 或系统权限配置 | 阶段 0 明确检查 Windows Visual Studio C++、Android NDK/CMake、macOS sandbox 权限 |
| 法律与版权 | 插件可能接入第三方音乐平台资源 | 应用本身不内置音源，仅提供插件机制和本地播放能力；插件由用户自行管理 |

## 3. MVP 范围

### 3.1 MVP 必须实现

1. Flutter 应用基础壳
   - 首页
   - 搜索页
   - 搜索结果列表
   - 简易播放栏
   - 插件管理入口

2. 插件管理
   - 从本地文件导入 JavaScript 插件
   - 从网络 URL 下载并导入 JavaScript 插件
   - 展示已安装插件列表
   - 启用或禁用插件
   - 删除插件
   - 查看插件基本信息：platform、version、author、description

3. MusicFree 兼容层最小接口
   - 加载插件脚本
   - 读取 module.exports 或 exports 导出的插件定义
   - 调用 search(query, page, type)
   - 调用 getMediaSource(musicItem, quality)
   - 将插件返回数据转换为应用内部统一模型

4. 搜索与播放
   - 输入关键词
   - 对所有已启用插件并发搜索
   - 以插件标签/TAB 切换展示各插件的 music 类型搜索结果
   - 点击歌曲后调用 getMediaSource
   - 使用返回的 url 和 headers 播放
   - 新播放请求必须使旧播放请求失效；旧请求即使晚返回也不能顶掉当前播放

5. 本地持久化
   - 保存插件文件或插件引用路径
   - 保存插件启用状态
   - 保存基础应用配置

### 3.2 MVP 暂不实现

- 账号系统
- 云同步
- 精致 UI
- 歌词滚动
- 歌单订阅
- 下载缓存
- 播放历史
- 收藏夹
- 插件市场
- 插件自动更新
- Web 端完整支持
- 后台播放深度适配
- 复杂音质选择 UI

这些能力不进入第一阶段，避免 MVP 膨胀。

## 4. 推荐技术栈

### 4.1 客户端框架

- Flutter：跨端 UI 与应用主体。
- Dart：业务逻辑、状态管理、数据模型、插件调用编排。

### 4.2 状态管理

MVP 明确选择 Riverpod，不使用旧的 provider 包。这里的 Provider 指 Riverpod 体系里的 provider 概念，例如 Provider、StateNotifierProvider、AsyncNotifierProvider 等，不是 `provider` 这个独立状态管理库。

选择 Riverpod 的原因：

- 适合中小型项目渐进扩展。
- Riverpod 的 provider 粒度清晰，便于将插件列表、搜索状态、播放状态拆开。
- 对 AI 编程友好，代码模板稳定。
- 不强依赖 BuildContext，业务状态更容易测试，也更适合放在 application 层。

### 4.3 音频播放

正式选型为 media_kit，不优先使用 just_audio。播放器层仍然必须封装成 AudioPlayerService，不允许 UI 直接依赖 media_kit。这样后续如果某个平台兼容性不佳，可以替换或扩展底层实现。

本项目的主力平台是 Windows 和 Android，因此播放器选型要优先服务在线音源插件场景，而不是只服务本地 mp3 播放。just_audio 不作为主路线：Windows 端依赖系统 Media Foundation，面对需要自定义 headers、User-Agent、Referer、Cookie 的在线音频流时容易出现 403、无法解码或行为不一致；Android 端虽然依赖 ExoPlayer 可用性较好，但多端一致性仍不如 media_kit。Robyne 的播放链路应直接围绕 media_kit 设计。

选择 media_kit 的原因：

- 底层基于 mpv，Windows、Android、macOS 多端播放行为更一致。
- 更适合处理在线音频流的 headers、User-Agent、Referer 等请求头透传。
- 对 FLAC、Hi-Res、DASH 音频流、非标准音频流等格式兼容性通常更强。
- 与本项目的 MusicFree 插件播放场景更匹配，插件返回的 MediaSource 经常不只是一个简单 mp3 URL。

注意事项：

- MediaSource 必须保留 headers 字段，并在 AudioPlayerService 中完整透传给 media_kit。
- Android 需要允许必要的 HTTP 明文请求，否则部分 http 音源链接会失败。
- media_kit 涉及原生依赖，阶段 0 必须验证 Windows 和 Android 的构建环境。
- Windows 优先验证带 headers 的在线流播放，不要只用本地文件或普通 mp3 URL 作为验收依据。
- Android 优先验证 http 与 https 两类链接，避免出现 Windows 可播、Android 因系统安全策略失败的问题。

### 4.4 本地存储

MVP 推荐分层使用：

- shared_preferences：保存简单设置，例如主题、默认插件、插件启用状态。
- 本地文件目录：保存用户导入的插件脚本。
- 后续可引入 SQLite/Drift/Isar：保存播放历史、收藏、歌单、缓存索引等结构化数据。

### 4.5 JavaScript 插件运行时

这是项目最关键的技术选型，必须通过独立 Spike 验证。

当前决策：MVP 第一主平台选择 Windows，Android 作为第一移动端同步验证目标，优先保证 Windows 上的开发、调试和插件验证体验，同时不能引入阻碍 Android 后续运行的运行时方案。正式运行时主路线选择 QuickJS + 受控 CommonJS 兼容层，不再优先使用 WebView。

推荐运行时路线：

```text
Flutter App
  -> PluginRuntime 抽象
  -> QuickJsPluginRuntime
  -> CommonJS Wrapper + require 白名单 + vendor.js
  -> MusicFree 插件
  -> Dart HTTP Bridge / Env Bridge / Logger Bridge
```

选择 QuickJS 主路线的原因：

- 比 WebView 更轻，不受浏览器 CORS 限制。
- 比 Node sidecar 更适合长期多端，避免 Android/iOS 集成 Node 的复杂性。
- 默认没有文件系统、系统命令等 Node 能力，安全边界更清晰。
- 可以由 Dart 层统一接管网络请求、代理、Cookie、超时、日志和错误处理。
- 适合逐步实现 MusicFree 插件所需的最小 Node 兼容子集。

MVP 不实现完整 Node.js，只实现这两个测试插件所需的受控能力：

```text
CommonJS: require, module.exports, exports
内置模块白名单: axios, crypto-js, dayjs, cheerio, he
全局对象: env.getUserVariables, console
异步能力: JS Promise <-> Dart Future
网络能力: axios(config), axios.get(url, config), axios.post(url, data, config)
插件接口: platform, version, author, description, supportedSearchType, userVariables, search, getMediaSource
```

axios 不直接使用 JS 网络，而是做成 shim，将请求转发到 Dart HTTP Bridge。Dart 侧可以使用 Dio 或 http 实现真实请求，并统一处理 headers、params、data、timeout、responseType、错误转换和敏感信息脱敏。

vendor.js 用于打包纯 JS 依赖，例如 crypto-js、dayjs、cheerio、he。第一阶段必须验证这些依赖在 QuickJS 中的导出形态能兼容插件里的 require 写法，例如 `require("axios").default`、`require("cheerio").load`、`require("crypto-js").MD5`。

Node.js Plugin Host 保留为辅助调试方案，只用于 Windows 上对照验证插件原始行为，不作为正式多端运行时主线。WebView 不作为优先方案，仅在 QuickJS 方案遇到不可接受阻塞时再重新评估。

QuickJS 相关原生编译要求必须提前处理：

- Windows 开发机必须安装 Visual Studio，而不是只安装 VS Code，并勾选“使用 C++ 的桌面开发”工作负载，确保 Flutter Windows 构建能找到 CMake、MSVC 编译器和 Windows SDK。
- Android 构建环境必须在 Android Studio SDK Manager 中安装 NDK Side by side 和 CMake，确保 QuickJS 这类 C/C++ 原生依赖可以编译为 Android `.so` 动态库。
- 阶段 1 选择 QuickJS Flutter 绑定库时，必须验证 Windows 与 Android 两端的实际构建，不允许只看 pub.dev 声称支持的平台。

第一阶段目标明确为：跑通 `fixture A` 和 `fixture B` 的 music 搜索与播放地址获取。

插件兼容范围：MVP 只兼容 MusicFree 插件协议的简单子集，先支持 search 和 getMediaSource，后续再逐步扩展歌词、歌单、用户变量 UI、插件调试控制台、更多内置依赖和完整兼容矩阵。

## 5. 架构设计

### 5.1 总体分层

建议采用接近 Clean Architecture 的轻量分层，不追求形式复杂，但必须保证依赖方向清晰。

```text
lib/
  app/
    app.dart
    router.dart
    bootstrap.dart
  core/
    errors/
    logging/
    result/
    storage/
    network/
  features/
    plugin/
      domain/
      application/
      infrastructure/
      presentation/
    search/
      domain/
      application/
      presentation/
    player/
      domain/
      application/
      infrastructure/
      presentation/
  shared/
    models/
    widgets/
```

依赖方向：

```text
presentation -> application -> domain
infrastructure -> domain
application 通过抽象接口调用 infrastructure
```

UI 不应该直接调用 JS 引擎，也不应该直接依赖音频播放库。

### 5.2 核心模块

#### 5.2.1 Plugin 模块

职责：

- 管理插件安装、删除、启用、禁用。
- 解析插件元信息。
- 通过 PluginRuntime 调用插件方法。
- 将插件返回值转换为内部标准模型。

关键对象：

```text
PluginManifest
PluginPackage
PluginRuntime
PluginRegistry
PluginRepository
MusicFreeCompatAdapter
```

#### 5.2.2 Search 模块

职责：

- 接收用户搜索请求。
- 对所有已启用插件并发搜索。
- 调用插件 search。
- 管理每个插件独立的加载、失败、结果和当前选中标签状态。

当前 MVP 已从原计划的单插件搜索调整为多插件并发搜索，但不做跨插件结果合并、排序和去重。每个插件结果保留在独立标签页中，便于定位单个插件失败或接口波动。

#### 5.2.3 Player 模块

职责：

- 接收 MusicItem。
- 调用插件 getMediaSource。
- 将 MediaSource 交给音频播放服务。
- 管理播放、暂停、进度、错误状态。
- 保证播放请求具有“最后一次点击优先”语义：用户点击新的播放后，旧的解析和播放请求必须失效，不能在晚返回时覆盖当前播放。

播放器模块只理解内部模型，不理解 MusicFree 原始返回结构。

#### 5.2.4 Storage 模块

职责：

- 管理插件文件保存路径。
- 管理配置读写。
- 后续管理播放历史、收藏、缓存索引。

## 6. 核心数据模型

### 6.1 PluginDefinition

```text
PluginDefinition
- id: String
- platform: String
- version: String?
- author: String?
- description: String?
- sourcePath: String
- enabled: bool
- installedAt: DateTime
- updatedAt: DateTime
```

### 6.2 MusicItem

```text
MusicItem
- id: String
- platform: String
- title: String
- artist: String?
- album: String?
- duration: Duration?
- artworkUrl: String?
- raw: Map<String, dynamic>
```

raw 字段非常重要，用于保存插件原始返回数据。调用 getMediaSource 时，很多插件依赖原始 musicItem 结构，不能只传标准化后的字段。

### 6.3 SearchResult

```text
SearchResult
- items: List<MusicItem>
- page: int
- isEnd: bool
- raw: Map<String, dynamic>?
```

兼容 MusicFree 常见返回：

```text
{
  isEnd: boolean,
  data: [...]
}
```

也要兼容部分插件可能返回：

```text
{
  list: [...],
  total: number,
  page: number
}
```

### 6.4 MediaSource

```text
MediaSource
- url: String
- headers: Map<String, String>
- quality: String?
- mimeType: String?
- expiresAt: DateTime?
- raw: Map<String, dynamic>?
```

headers 必须作为一等字段处理，因为很多音源播放依赖 User-Agent、Referer、Cookie 等请求头。

## 7. MusicFree 插件兼容策略

### 7.1 MVP 兼容接口

MVP 必须优先兼容：

```text
module.exports = {
  platform,
  version,
  author,
  description,
  supportedSearchType,
  async search(query, page, type),
  async getMediaSource(musicItem, quality)
}
```

其中：

- search 的 type 默认传 music。
- page 从 1 开始。
- quality 默认先传 standard 或空值，具体根据测试插件适配。
- getMediaSource 的 musicItem 优先传插件 search 返回的原始 item。

### 7.2 后续兼容接口

后续逐步支持：

```text
getLyric(musicItem)
getAlbumInfo(albumItem)
getArtistWorks(artistItem, page, type)
getMusicSheetInfo(sheetItem, page)
getRecommendSheetTags()
getTopLists()
importMusicSheet(url)
userVariables
```

### 7.3 全局 API 兼容

MusicFree 插件常见依赖可能包括：

- fetch
- axios
- CryptoJS
- cheerio
- dayjs
- URLSearchParams
- Buffer
- env.userVariables

MVP 不应该一次性全部实现，而是采用按需兼容：

1. 先支持 Promise、JSON、基本 JS 运行。
2. 支持 fetch 或提供 request bridge。
3. 支持 headers、query params、GET/POST。
4. 对 axios 做轻量 shim，或者要求插件使用 fetch 子集。
5. 对 CryptoJS 等依赖，优先允许通过内置模块白名单注入。

## 8. 插件安全设计

用户自写脚本是项目能力核心，也是最大风险来源。

MVP 必须至少做到：

- 插件调用设置超时，例如 search 15 秒，getMediaSource 10 秒。
- 插件不能直接访问任意本地文件。
- 插件不能直接执行系统命令。
- 插件网络请求经过受控 bridge，便于后续做日志、限流和权限提示。
- 插件错误必须被捕获并转换成用户可理解的错误，不允许导致应用崩溃。
- 插件原始异常进入调试日志，但不要在 UI 中泄露敏感 headers 或 cookie。

后续可以加入：

- 插件权限声明。
- 插件来源校验。
- 插件网络域名白名单提示。
- 插件调试控制台。

## 9. 错误处理策略

统一定义 AppError：

```text
AppError
- code: String
- message: String
- cause: Object?
- stackTrace: StackTrace?
```

常见错误码：

```text
plugin.load_failed
plugin.invalid_exports
plugin.method_missing
plugin.method_timeout
plugin.runtime_error
search.empty_keyword
search.failed
player.media_source_empty
player.unsupported_source
player.play_failed
storage.read_failed
storage.write_failed
network.request_failed
```

所有模块返回错误时，不直接抛给 UI，而是通过 Result 或状态对象表达。

## 10. 建议开发阶段

### 阶段 0：项目初始化（Windows 已完成，Android 构建与启动已验证）

目标：建立 Flutter 工程、基本工程规范和 Windows/Android 优先的原生构建环境。阶段 0 不追求完整业务功能，但必须尽早暴露原生编译、播放器初始化和 Android 网络策略问题。

任务：

- 创建 Flutter 项目。
- 配置 lint。
- 确定状态管理方案为 Riverpod。
- 确定音频播放方案为 media_kit，并建立 AudioPlayerService 抽象。
- 建立基础目录结构。
- 添加空页面和路由。
- Windows 环境确认已安装 Visual Studio，并包含“使用 C++ 的桌面开发”工作负载。
- Windows 环境确认 CMake、MSVC 编译器、Windows SDK 能被 Flutter Windows 构建链正确发现。
- Android 环境确认已安装 Android SDK、NDK Side by side 和 CMake。
- AndroidManifest.xml 的 application 标签加入必要的明文网络配置：`android:usesCleartextTraffic="true"`。
- Android 网络验证必须覆盖 `http://` 音频链接，因为部分音源插件解析出的播放地址不是 `https://`。
- macOS 后续适配时预留 App Sandbox 网络权限检查项，尤其是 Outgoing Connections (Client)。

验收标准与当前状态：

- Windows 应用能启动：已通过 `flutter build windows --debug`。
- Android debug 构建能启动到空页面：已通过 `flutter build apk --debug`、`flutter install --debug -d 9b234798` 和 `adb shell am start -n com.robyne.robyne/.MainActivity` 验证。
- lint 和 test 命令可运行：已通过 `flutter analyze` 和 `flutter test`。
- 目录结构符合规划：已完成。
- media_kit 播放服务能完成初始化并进入真实播放链路：Windows 已验证，Android 待验证。
- Windows 端已确认 Flutter 能正常调用原生构建链，不出现缺少 Visual Studio、CMake、MSVC 或 Windows SDK 的错误：已完成。
- Android 端已确认 NDK Side by side 和 CMake 可用，不出现原生依赖无法编译为 `.so` 的错误：已通过 debug APK 构建验证。
- AndroidManifest.xml 已包含 `android:usesCleartextTraffic="true"`，并确认应用具备访问 http 音源链接的基础条件：配置已复核，真机 HTTP 播放待验证。
- 当前 Android 注意项：本机直连 `https://storage.googleapis.com/` 存在 TLS 握手失败，构建时需要设置 `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`；详见 `docs/android_validation.md`。

### 阶段 1：QuickJS 插件运行时 Spike（Windows 已完成）

目标：在 Windows 上优先跑通 `fixture A` 和 `fixture B` 的 music 搜索与播放地址获取，验证 QuickJS + 受控 CommonJS 兼容层路线可行。

任务：

- 调研并选择 Flutter 可用的 QuickJS 绑定库，重点验证 Windows 支持、异步 bridge、异常捕获和资源释放能力。
- 实现 PluginRuntime 抽象。
- 实现 QuickJsPluginRuntime 原型。
- 实现 CommonJS wrapper，支持 require、module.exports、exports。
- 实现 require 白名单，首批支持 axios、crypto-js、dayjs、cheerio、he。
- 打包 vendor.js，验证 crypto-js、dayjs、cheerio、he 在 QuickJS 中的导出形态。
- 实现 axios shim，将 axios(config)、axios.get、axios.post 转发到 Dart HTTP Bridge。
- 实现 env.getUserVariables bridge，先允许返回空配置，后续接插件用户变量 UI。
- 加载 `fixture A`，读取 platform、supportedSearchType、userVariables。
- 加载 `fixture B`，读取 platform、supportedSearchType。
- 调用两个插件的 search(query, 1, "music")。
- 使用搜索结果 raw item 调用 getMediaSource(musicItem, "standard")。
- 将插件返回的 url、headers、quality 转换为内部 MediaSource。
- 为插件加载、搜索、获取播放地址增加超时和结构化错误。

验收标准与当前状态：

- Dart 可以通过 QuickJS 加载两个测试插件：已完成。
- 可以读取两个插件的 platform、version、supportedSearchType：已完成。
- fixture A 插件可以执行 `search("周杰伦", 1, "music")` 并返回可解析列表：已完成。
- fixture B 插件可以执行 `search("周杰伦", 1, "music")` 并返回可解析列表：已完成。
- 两个插件的搜索结果都保留 raw 数据：已完成。
- 可以对至少一条 fixture A 搜索结果调用 getMediaSource 并得到 MediaSource 或明确的业务失败结果：已完成。
- 可以对至少一条 fixture B 搜索结果调用 getMediaSource 并得到包含 url 和 headers 的 MediaSource：已完成。
- axios shim 支持 config、get、post 三种调用形态：已完成。
- crypto-js 的 MD5、AES、HmacSHA256 能被插件正常调用：已完成。
- cheerio 的 load 能被 fixture B 插件正常调用：已完成。
- dayjs.unix(...).format(...) 能被插件正常调用：已完成。
- he.decode 能被 fixture B 插件正常调用：已完成。
- 插件运行异常、网络异常、超时都能被捕获并转换为 AppError：已实现基础能力，并补充了 QuickJS Promise/HTTP bridge 超时和释放竞态保护。
- 插件不能访问文件系统和系统命令：当前 QuickJS 运行时未暴露文件系统和系统命令能力，仍需在阶段 5 兼容矩阵中记录安全边界。

### 阶段 2：插件管理 MVP（已完成基础版本）

目标：用户可以导入和启用插件。

任务：

- 插件文件导入。
- 插件 URL 下载导入。
- 插件元信息解析。
- 插件列表页。
- 启用、禁用、删除。
- 插件状态持久化。

验收标准与当前状态：

- 重启应用后插件列表仍存在：已通过本地文件保存和 SharedPreferences 持久化实现。
- 禁用插件不会参与搜索：已实现。
- 插件加载失败有错误提示：已有基础错误提示。
- 插件 URL 导入：已实现基础版本，仅允许 `http://` 和 `https://`，下载后先做 QuickJS 元信息验证，验证成功才写入本地插件目录。
- 插件元信息展示：已展示 platform、version、author、supportedSearchTypes；description 仍未做完整 UI。
- 插件用户变量配置：已实现基础版本，支持声明了 `userVariables` 的插件在插件页配置文本/开关值，并在搜索和播放时注入 `env.getUserVariables()`。

### 阶段 3：搜索 MVP（已调整为多插件并发搜索）

目标：用户可以通过插件搜索歌曲。

任务：

- 搜索输入框。
- 对所有已启用插件并发调用 search。
- 用插件标签/TAB 展示各插件搜索状态和结果数量。
- 点击标签切换歌曲列表。
- 支持下一页或简单分页。

验收标准与当前状态：

- 两个测试插件搜索可用：已通过 spike 测试。
- 空结果、失败、加载中状态正确显示：已实现基础状态；插件级错误会显示在对应标签和面板中。
- 搜索结果保留 raw 数据：已完成。
- 下一页或分页：已实现当前选中插件的自动加载下一页；列表接近底部时触发，成功后追加结果，失败时保留已有结果并在底部显示错误。

### 阶段 4：播放 MVP（Windows 已完成基础版本）

目标：用户可以点击搜索结果播放。

任务：

- 封装 AudioPlayerService。
- 调用 getMediaSource。
- 支持 url + headers 播放。
- 实现播放、暂停、停止。
- 展示当前歌曲和基础进度。

验收标准与当前状态：

- 测试插件返回的音频地址可播放：Windows 已跑通，真实可播性仍受第三方接口和网络状态影响。
- 播放失败不会崩溃：已实现错误状态返回。
- 切歌时旧播放状态正确释放：已实现“最后一次点击优先”，旧解析请求晚返回也不能顶掉当前播放；底层 media_kit Player 会在新 play/stop 时替换以隔离旧 open 的副作用。

### 阶段 5：插件兼容矩阵与扩展验证（已开始）

目标：在两个验收插件跑通后，沉淀 QuickJS 兼容层能力清单，并为后续接入更多 MusicFree 插件建立可重复的验证流程。

任务：

- 整理 `fixture A` 和 `fixture B` 已使用到的 CommonJS、axios、vendor、env、headers、MediaSource 能力。
- 形成插件 API 兼容矩阵，标记已支持、部分支持、未支持：已创建 `docs/plugin_compatibility_matrix.md`，覆盖当前 `test_files` 中 10 个插件的静态依赖、风险标记和元信息加载状态。
- 选择新的 1 到 2 个社区插件作为扩展验证样本。
- 按需补齐必要 shim，但不得破坏已有两个验收插件：已补 `exports.default` 导出解包和受控 `setTimeout` / `clearTimeout`。
- 记录不兼容点、第三方接口业务失败、运行时缺失能力三类问题。

验收标准：

- 两个验收插件仍能完成 music 搜索和播放地址获取：保持为 spike 验证项。
- 至少新增一个真实插件能完成搜索，能否播放按插件实际接口和第三方服务情况记录：已验证一个混淆过的 fixture能完成 music 搜索和播放地址获取。
- 每个失败插件都能给出明确失败分类：矩阵已记录第三方服务/网络失败、插件业务空数据、插件顶层副作用、歌词类非 music 插件等分类。
- 形成兼容矩阵，为后续扩展开发提供依据：已完成初版。

建议产出：

- `docs/plugin_compatibility_matrix.md`：记录插件、平台、搜索、播放、用到的 API、失败类型和备注。
- `docs/android_validation.md`：记录 Android 工具链、构建、真机运行、HTTP 播放、HTTPS 播放、headers 播放验证结果。

### 阶段 6：本地音乐与播放体验增强（下一阶段，按 TDD 开发）

目标：在插件播放闭环稳定后，补齐一个普通音乐播放器应具备的基础体验：本地音乐导入与播放、可拖拽进度条、音量控制、在线歌曲缓存、播放列表、播放模式和播放历史。

开发方式必须采用 TDD：

1. 每个子功能先写失败测试。
2. 确认测试因功能缺失而失败。
3. 编写最小实现让测试通过。
4. 每轮至少运行对应测试文件。
5. 阶段完成后运行 `flutter analyze`、`flutter test`、`flutter build windows --debug`。

已确认产品决策：

- 本地音乐导入后引用原文件，不复制到应用目录；如果原文件被移动或删除，播放时返回 `local.file_missing`。
- 导入文件夹时递归扫描子文件夹。
- 本地音乐第一版只用文件名展示标题，不读取音频 metadata，不解析封面、歌手和专辑标签。
- 支持的本地音频扩展名第一版为 `mp3`、`flac`、`wav`、`m4a`、`aac`、`ogg`、`opus`、`wma`。
- 在线音乐点击播放后采用边播边缓存：首次播放尽快开始，同时后台下载整首音频。
- 缓存只针对插件解析出的远程音频，本地音乐不复制、不缓存。
- 缓存默认上限为 1GB，超过后按最久未用清理。
- 播放列表不是历史记录，而是当前可播放队列。
- 播放列表按来源和 ID 去重：插件歌曲使用 `plugin:<platform>:<musicId>`，本地歌曲使用 `local:<normalizedPath>`。
- 播放 A、B、A 后，播放列表仍显示 A、B，只是当前播放指针切回 A。
- 支持删除播放列表中的某一首，支持清空播放列表；删除当前项或清空列表时停止播放。
- 播放模式包括顺序播放、随机播放、全部循环、单曲循环。
- 播放历史按真实播放顺序追加；ABABAB 循环应记录为 ABABAB；单曲循环的自动重复不重复追加历史。
- 播放历史第一版最多保留 1000 条，超过后删除最旧记录。
- 第二阶段以 Windows 验收为主，Android 保持可构建可运行；Android 本地文件夹长期权限问题后续单独验证。

任务：

- 新增统一播放项模型 `PlaybackItem`，同时表示插件歌曲和本地歌曲。
- 新增本地音乐库导入能力，支持单首/多首文件和文件夹递归导入。
- 扩展 `AudioPlayerService`，增加 `seek(Duration)`、`setVolume(double)`，并在 `PlayerSnapshot` 中暴露 volume 和 completed。
- 重构 `PlayerController`，增加统一播放入口、播放列表、播放模式、播放历史和旧请求失效保护。
- 新增在线音频缓存服务，缓存命中时优先播放本地缓存文件，未命中时边播边后台下载。
- 新增 Library 页面，用于本地音乐导入、展示和播放。
- 新增 Queue 页面，用于查看播放列表、切换播放模式、删除队列项、清空队列、查看播放历史。
- 扩展底部播放栏，加入进度条、音量条、上一首、下一首和播放模式入口。

验收标准：

- 可以导入本地单首或多首音乐文件。
- 可以导入一个文件夹，并递归导入支持格式的音乐文件。
- 不支持格式会被忽略，重复路径不会重复导入。
- 点击本地音乐可直接播放，文件丢失时给出明确错误。
- 插件搜索结果和本地音乐都可以进入同一播放列表。
- 播放栏进度条可以拖拽并调用底层 seek。
- 音量条可以控制 media_kit 音量，并在 UI 中反映当前音量。
- 在线音乐首次播放时开始后台缓存，后续再次播放优先使用缓存文件。
- 缓存超过 1GB 后按 LRU 清理。
- 播放列表支持 A/B/A 去重语义、删除单项、清空列表。
- 四种播放模式行为明确且可测试。
- 播放历史最多保留 1000 条，记录顺序符合真实播放顺序。
- 原有插件导入、搜索、分页、播放请求失效保护测试保持通过。

## 11. AI 编程工作方式建议

为了让后续 AI 开发稳定推进，每次只给 AI 一个明确小任务，并要求它完成后运行检查。

推荐提示词结构：

```text
请基于 PROJECT_PLAN.md 的阶段 X，实现 Y。
要求：
1. 先阅读相关目录和现有代码，不要破坏架构边界。
2. 只实现本任务范围，不要扩展额外功能。
3. 不要在代码里添加无关注释。
4. 完成后运行项目已有的 lint/typecheck/test 命令。
5. 如果发现规划文档与代码冲突，先说明冲突，不要擅自大改。
```

推荐开发顺序：

1. 初始化 Flutter 工程。
2. 建立目录结构和基础页面。
3. 定义 domain 模型。
4. 定义 PluginRuntime 抽象。
5. 做 QuickJS Runtime Spike，优先跑通两个测试插件。
6. 做插件管理。
7. 做搜索。
8. 做播放。
9. 建立插件兼容矩阵并扩展更多插件。

## 12. 关键架构决策记录

### ADR-001：应用本体不内置音源

决定：Robyne 本体只提供播放器、插件运行、插件管理和本地数据能力，不内置任何第三方音乐平台音源。

原因：

- 降低版权和维护风险。
- 保持项目定位清晰。
- 鼓励用户自定义插件。

代价：

- 初始可用性依赖插件。
- 需要做好插件导入和错误提示。

### ADR-002：插件层使用兼容适配器隔离 MusicFree 协议

决定：应用内部不直接使用 MusicFree 返回结构，而是通过 MusicFreeCompatAdapter 转换为内部模型。

原因：

- MusicFree 协议未来可能变化。
- 内部播放器不应绑定外部插件协议。
- 后续可以兼容其他插件协议。

代价：

- 初期需要多写一层转换代码。

### ADR-003：播放器服务必须封装 media_kit

决定：播放器正式选型为 media_kit。UI 和业务用例不直接依赖 media_kit，而是依赖 AudioPlayerService 抽象；just_audio 不作为 MVP 主播放器路线。

原因：

- media_kit 底层基于 mpv，Windows、Android、macOS 多端行为更一致。
- Robyne 的核心场景是播放插件解析出来的在线音频流，这些流经常依赖 headers、User-Agent、Referer、Cookie 或非标准格式。
- Windows 上 just_audio 依赖系统 Media Foundation，面对带自定义请求头的在线流风险较高。
- media_kit 对 FLAC、Hi-Res、DASH 音频流 和非标准音频流的兼容性更适合本项目。
- 通过 AudioPlayerService 封装后，仍然可以隔离平台差异并方便测试。

代价：

- 需要处理 media_kit 的原生依赖和平台初始化细节。
- 需要设计一套内部播放状态模型。
- 阶段 0 必须验证 Windows 和 Android 的原生构建环境。

### ADR-004：MVP 搜索模式调整为多插件并发、按插件标签展示

决定：第一版不做跨插件合并、排序和去重，但会对所有已启用插件并发搜索，并按插件标签/TAB 展示结果。用户可以在标签之间切换查看单个插件的结果。

原因：

- 保留多音源搜索的实用性，同时避免跨插件合并、排序、去重、错误合并的复杂度。
- 优先验证插件兼容和播放链路。

代价：

- 结果不会自动去重，用户需要在插件标签之间切换。
- 插件并发运行会增加网络请求数量，后续可能需要限制并发或提供插件级搜索开关。

### ADR-005：正式插件运行时采用 QuickJS + 受控 CommonJS 兼容层

决定：MVP 正式运行时主路线采用 QuickJS，不优先使用 WebView，不把 Node.js sidecar 作为正式多端运行时。QuickJS 内部通过 CommonJS wrapper、require 白名单、vendor.js 和 Dart HTTP Bridge 来兼容 MusicFree 插件的最小必要能力。

原因：

- 当前测试插件使用 CommonJS、axios、crypto-js、dayjs、cheerio、he 等能力，单纯 WebView 并不能天然兼容。
- WebView 容易遇到 CORS、隐藏 WebView 管理、跨端行为不一致等问题。
- Node.js sidecar 在 Windows 上调试方便，但移动端集成和发布复杂，不适合作为长期多端主线。
- QuickJS 更轻量，跨端一致性更好，安全边界更可控。
- 网络请求交给 Dart HTTP Bridge，可以统一处理 headers、Cookie、代理、超时、日志和错误转换。

代价：

- 需要自行实现 CommonJS 兼容层和 axios shim。
- 需要维护 vendor.js 打包流程。
- 需要验证 Dart Future 与 JS Promise 的桥接稳定性。
- 对复杂 MusicFree 插件的兼容需要逐步扩展，不能一次性承诺全兼容。

### ADR-006：第一阶段以两个真实测试插件作为验收目标

决定：第一阶段不再只验证 demo 插件，而是以 `fixture A` 和 `fixture B` 作为主要验收插件，目标是跑通 music 搜索和播放地址获取。

原因：

- 两个插件能代表 MusicFree 常见插件形态：CommonJS、第三方依赖、异步网络请求、加密、HTML 解析、用户变量、headers 播放。
- 用真实插件验收可以尽早暴露运行时兼容问题。
- 目标足够具体，便于 AI 编程逐步实现和验证。

代价：

- 第一阶段运行时工作量增加。
- 真实接口可能受网络、平台风控、Cookie、音源有效性影响，验收时要区分运行时错误和第三方服务业务失败。

### ADR-007：平台策略为 Windows 和 Android 优先，macOS 后续扩展

决定：MVP 阶段以 Windows 和 Android 为一等目标平台。Windows 作为第一开发与调试平台，Android 作为第一移动端目标；macOS 保持架构兼容，但不作为 MVP 的主要交付平台。

原因：

- Windows 适合快速验证 Flutter 桌面端、QuickJS 插件运行时、media_kit 播放和真实插件调试。
- Android 是主要移动端使用场景，必须尽早验证 NDK/CMake、明文 HTTP、播放器原生依赖和网络权限。
- macOS 与当前技术栈兼容性较好，但会额外涉及 App Sandbox 和签名权限，适合在核心链路稳定后再处理。

代价：

- 阶段 0 需要同时关注 Windows 和 Android 两套原生构建环境。
- macOS 的权限、沙盒和分发问题会延后处理，但架构设计不能写死平台。
- 后续新增平台能力时，需要为不同平台维护清晰的构建与权限检查清单。

### ADR-008：第二阶段采用统一播放项、播放队列和本地引用策略

决定：第二阶段将插件歌曲和本地歌曲统一抽象为 PlaybackItem，由播放器应用层管理播放列表、历史、播放模式和缓存。本地音乐导入后引用原文件，不复制到应用目录；在线插件歌曲采用 1GB LRU 缓存。

原因：

- 插件搜索结果、本地音乐、播放列表和历史需要一套统一身份模型，否则 A/B/A 去重、历史记录和播放模式会分散到多个模块。
- 本地引用原文件更节省空间，适合早期版本快速验证本地播放体验。
- 在线音乐缓存应服务于插件音源，避免重复解析和重复下载；本地音乐已经在磁盘上，不需要复制成缓存。
- 1GB LRU 缓存能控制手机和桌面端的存储占用，同时保留常听歌曲的命中率。

代价：

- 本地原文件移动或删除后会导致播放失败，需要清晰错误提示。
- Android 文件夹导入和长期读取权限可能需要后续专项适配。
- 播放器应用层会承担更多状态编排，需要用单元测试覆盖播放列表、历史和模式切换。

## 13. 第一批验收用测试插件

第一阶段以两个真实插件作为主要验收目标：

```text
fixture A
fixture B
```

必须优先跑通：

- 读取插件元信息。
- 调用 music 搜索。
- 将搜索结果转换为内部 MusicItem，并保留 raw。
- 使用 raw musicItem 调用 getMediaSource。
- 将返回结果转换为内部 MediaSource。

同时保留一个完全本地可控的 demo 插件，用于排查基础运行时问题。当真实插件失败时，先用 demo 插件判断是 QuickJS 基础运行时问题，还是第三方接口、网络、风控、依赖兼容问题。

```javascript
module.exports = {
  platform: 'demo',
  version: '0.1.0',
  author: 'Robyne',
  description: 'Demo plugin for MVP validation',
  supportedSearchType: ['music'],
  async search(query, page, type) {
    return {
      isEnd: true,
      data: [
        {
          id: 'demo-1',
          title: `${query} Demo Song`,
          artist: 'Demo Artist',
          album: 'Demo Album',
          duration: 180,
          artwork: ''
        }
      ]
    };
  },
  async getMediaSource(musicItem, quality) {
    return {
      url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      headers: {}
    };
  }
};
```

这个插件用于验证架构链路，不代表正式音源能力。

## 14. 当前最重要的下一步

当前 Windows 侧核心闭环已经成立：插件导入、多插件搜索、播放地址解析和 media_kit 播放均已跑通。下一步进入阶段 6，并按 TDD 顺序执行：

1. 先为本地音乐导入、播放器 seek/volume/completed、缓存、播放列表、播放模式、播放历史和基础 UI 写失败测试。
2. 再实现 domain/application 层，优先保证播放项模型、本地库、队列、历史和缓存逻辑可测试。
3. 然后扩展 media_kit 播放器服务能力并接入统一播放入口。
4. 最后补 Library、Queue 和播放栏 UI。
5. 阶段完成后运行 `flutter analyze`、`flutter test`、`flutter build windows --debug`。
