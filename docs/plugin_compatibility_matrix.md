# Plugin Compatibility Matrix

Last updated: 2026-05-27

This matrix tracks local plugin fixtures against the current QuickJS
runtime. Static scanning treats plugin scripts as untrusted input. The runtime
does not expose filesystem, process, or shell APIs; plugin network access goes
through the Dart HTTP bridge.

Fixtures are labelled by their file hash rather than by the service they talk
to: this repository ships no plugin scripts, and naming the third-party
services a fixture happens to reach is not information this document needs to
carry.

## Runtime Support

| Capability | Status | Notes |
|---|---|---|
| CommonJS `module.exports` / `exports` | Supported | The loader also unwraps `exports.default` / `module.exports.default` when `platform` is on the default export. |
| `axios(config)`, `axios.get`, `axios.post` | Supported | Requests are proxied through `PluginHttpClient` with timeout and retry budget. |
| `crypto-js`, `dayjs`, `cheerio`, `he` | Supported | Provided by bundled `assets/js/musicfree_vendor.js`. |
| `env.getUserVariables` | Supported | Returns values configured on the plugin page and injected when loading the plugin. |
| `setTimeout` / `clearTimeout` | Supported | Implemented by Robyne runtime bridge so timers are cancelled before QuickJS dispose. |
| `fetch`, `XMLHttpRequest`, `WebSocket` | Not supported | No fixture currently requires these for the MVP path. |
| Filesystem / process / shell | Not exposed | `fs`, `child_process`, and `process` are not available in the runtime. |

## Fixture Matrix

| Fixture | Static dependencies | Static risk flags | Metadata load | Search/play status | Notes |
|---|---|---|---|---|---|
| `fixture-01` | axios, cheerio, crypto-js, dayjs, he | default export wrapper | Passed | Search and media source passed in spike | Primary MVP acceptance fixture. Latest controlled spike returned 19 music items and a media URL. |
| `fixture-02` | axios, crypto-js, dayjs | default export wrapper | Passed | Search and media source passed in spike | Primary MVP acceptance fixture. Real playback may still depend on third-party availability. |
| `fixture-03` | axios, he | obfuscated | Passed | Search and media source passed in spike | `jsjiami.com.v7` obfuscation detected. Static scan did not find filesystem/process/eval patterns. Latest controlled spike returned 30 music items and a non-empty media URL. |
| `fixture-04` | axios, cheerio | default export wrapper | Passed | Music search returned null | Lyric-only fixture; it declares only lyric search, so `search(..., "music")` returns null. |
| `fixture-05` | axios, he | setTimeout, top-level demo calls, default export wrapper | Passed | Search passed, media returned empty URL | Uses timers; covered by runtime timer bridge. Latest controlled spike returned music items, but `getMediaSource` produced an empty `url`. The fixture also runs demo search/media/lyric calls at top level, causing extra console output and one lyric null-data rejection. |
| `fixture-06` | axios, cheerio | default export wrapper | Passed | Music search returned null | Lyric-only fixture; it declares only lyric search, so `search(..., "music")` returns null. |
| `fixture-07` | axios, cheerio, crypto-js | default export wrapper | Passed | Music search returned null | Declares music in metadata, but the latest controlled spike returned no items; classify as plugin business/implementation behavior until a supported query/type path is identified. |
| `fixture-08` | axios | default export wrapper | Passed | Search failed | Latest controlled spike failed with the connection closed before headers; classified as third-party service/network failure, not a runtime missing capability. |
| `fixture-09` | axios, cheerio | default export wrapper | Passed | Search returned no items | Latest controlled spike completed a music search but returned an empty item list; classified as plugin/third-party data behavior. |
| `fixture-10` | axios | default export wrapper | Passed | Search returned no items | Latest controlled spike completed search adaptation but returned an empty item list; classified as plugin/third-party data behavior. |

## Verification Commands

```powershell
$env:PATH=(Join-Path $PWD 'build\windows\x64\runner\Debug') + ';' + $env:PATH
$env:RUN_PLUGIN_SPIKE='true'
$env:LIBQUICKJSC_TEST_PATH=(Join-Path $PWD 'build\windows\x64\runner\Debug\quickjs_c_bridge_plugin.dll')
flutter test test\plugin_runtime_spike_test.dart --plain-name "loads metadata for every plugin fixture without invoking network methods"
flutter test test\plugin_runtime_spike_test.dart --plain-name "reports search and media compatibility for music plugin fixtures"
```

Current result: all 10 fixture plugins loaded metadata successfully. The full
spike also verified the two primary MVP plugins still complete music search and
media-source extraction. The compatibility report additionally verified the
obfuscated `fixture-03` can complete search and media-source extraction.

## Next Compatibility Work

- Investigate whether `fixture-07`, `fixture-09`, and `fixture-10` require a
  different query, user variable, or plugin-specific request shape before they
  can return music items.
- Keep failures classified as runtime missing capability, third-party service/network failure, or plugin business failure.
- Do not expand runtime permissions for filesystem, process, shell, local network, or arbitrary browser APIs without an explicit security review.
