# Robyne

一个用 Flutter 写的音乐播放器。Windows 和 Android 都能跑，插件化接音源。

[English](./README.en.md)

## 它能干什么

Robyne 自己不带任何音源。它提供的是一套插件机制：你导入 JS 插件，它负责跑起来、搜索、拿播放地址、放歌。音乐资源来自插件，插件由你自己管。

- 兼容 MusicFree 风格的 JS 音源插件，支持本地文件、文件夹、URL 三种导入方式
- 搜索、播放队列、播放模式、断点续播
- 歌词（支持偏移微调）和多窗口桌面歌词
- 本地音乐库、歌单、在线歌单收藏
- 下载和音频格式转换
- 可导入的皮肤系统，官方 UI 本身就是一份皮肤
- Windows 桌面增强：托盘、全局快捷键、胶囊窗模式

## 跑起来

需要 Flutter 3.41+（SDK `^3.11.1`）。Windows 端还要 Visual Studio 的 C++ 工具链，因为 QuickJS 原生部分要编译。

```bash
flutter pub get
flutter run -d windows    # 或 -d android
```

Windows 正式包：

```bash
flutter build windows
```

Android 如果在国内网络环境下构建卡住，设置 Flutter 镜像再试：

```bash
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

## 加音源

打开「插件」页，选本地文件／文件夹／URL 导入，插件会出现在列表里。导入后到「搜索」页开搜就行。

插件可能要求你填 Cookie、音质之类的用户变量，在插件详情页填。标记为敏感的变量会被 UI 遮蔽。需要注意骗子插件始终是可能的，只装你信得过的。

## 换皮肤

皮肤就是一个带 `theme.json` 的目录，或者打包成 `.rtheme`（本质是个 zip）。最小可用版本只有两个字段：

```json
{
  "id": "mytheme",
  "name": "我的第一个皮肤"
}
```

**皮肤是纯数据，不含可执行代码**，所以一个皮肤没有能力损害你的设备。缺的字段自动回退到内置默认值，你不会因为少写一个字段就白屏。

想正经写皮肤看 [docs/THEME_AUTHORING.md](./docs/THEME_AUTHORING.md)，内置的 [`assets/themes/`](./assets/themes/) 也是很好的参考。

## 项目结构

按 Clean Architecture 分层，每个 feature 一个目录：

```
lib/
  app/          应用外壳、路由、桌面窗口控制
  core/theme/   皮肤引擎（token、材质、导入导出）
  features/     discover library player lyrics playlists
                 plugin search settings downloads tray
native/sqlite3/  Android 用的 SQLite 源码
```

技术栈：Flutter + Riverpod + media_kit（播放）+ drift/SQLite（本地存储）+ QuickJS（插件运行时）。

## 测试

```bash
flutter test
```

约 475 个用例，覆盖 UI、业务需求、皮肤解析和安全边界。

## TODO
- [ ] 头尾跳过一段时间功能
- [ ] 导入其他平台歌单

## 状态

能日常使用，但仍在开发中。有些社区插件因为用了未支持的 API 会跑不起来，详见 [docs/plugin_compatibility_matrix.md](./docs/plugin_compatibility_matrix.md)。

## 许可

见 [LICENSE](./LICENSE)。第三方依赖按各自许可执行，仓库里已 vendored 的部分（SQLite、QuickJS、JS vendor）按其原始许可来。
