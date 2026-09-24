# Compiles the SQLite amalgamation into jniLibs for all Android ABIs.
# See native/sqlite3/README.md for why this project bundles its own SQLite.
#
# Usage (repo root): pwsh native/sqlite3/build_android.ps1
[CmdletBinding()]
param(
    # Upstream amalgamation; bump the year/version to upgrade SQLite.
    [string]$AmalgamationUrl = 'https://sqlite.org/2025/sqlite-amalgamation-3500200.zip',
    [string]$AndroidHome = $env:ANDROID_HOME
)

$ErrorActionPreference = 'Stop'

if (-not $AndroidHome) {
    $AndroidHome = 'D:\software\AndroidSDK'
}

$repoRoot = Split-Path (Split-Path $PSScriptRoot)
$jniLibs = Join-Path $repoRoot 'android\app\src\main\jniLibs'

# Pick the newest installed NDK.
$ndk = Get-ChildItem (Join-Path $AndroidHome 'ndk') -Directory |
    Sort-Object Name -Descending |
    Select-Object -First 1
if (-not $ndk) {
    throw "No Android NDK found under $AndroidHome\ndk"
}
$clang = Join-Path $ndk.FullName 'toolchains\llvm\prebuilt\windows-x86_64\bin\clang.exe'
$llvmNm = Join-Path $ndk.FullName 'toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-nm.exe'
if (-not (Test-Path $clang)) {
    throw "clang not found at $clang"
}
Write-Host "Using NDK $($ndk.Name)"

# Download and extract the amalgamation.
$tempZip = Join-Path $env:TEMP 'sqlite-amalg.zip'
$tempDir = Join-Path $env:TEMP 'sqlite-amalg'
Write-Host "Downloading $AmalgamationUrl ..."
Invoke-WebRequest -Uri $AmalgamationUrl -OutFile $tempZip -TimeoutSec 120 -UseBasicParsing
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force
$sqliteC = Get-ChildItem $tempDir -Recurse -Filter 'sqlite3.c' | Select-Object -First 1
if (-not $sqliteC) { throw 'sqlite3.c not found in amalgamation archive' }
Write-Host "Using $($sqliteC.FullName)"

# Feature flags: keep in sync with the defaults of package:sqlite3's build
# hook (lib/src/hook/description.dart).
$defines = @(
    '-DSQLITE_ENABLE_FTS5',
    '-DSQLITE_ENABLE_RTREE',
    '-DSQLITE_ENABLE_MATH_FUNCTIONS',
    '-DSQLITE_ENABLE_DBSTAT_VTAB',
    '-DSQLITE_DQS=0',
    '-DSQLITE_DEFAULT_MEMSTATUS=0',
    '-DSQLITE_TEMP_STORE=2',
    '-DSQLITE_MAX_EXPR_DEPTH=0',
    '-DSQLITE_STRICT_SUBTYPE=1',
    '-DSQLITE_OMIT_AUTHORIZATION',
    '-DSQLITE_OMIT_DECLTYPE',
    '-DSQLITE_OMIT_DEPRECATED',
    '-DSQLITE_OMIT_PROGRESS_CALLBACK',
    '-DSQLITE_OMIT_SHARED_CACHE',
    '-DSQLITE_OMIT_TCL_VARIABLE',
    '-DSQLITE_OMIT_TRACE',
    '-DSQLITE_USE_ALLOCA',
    '-DSQLITE_ENABLE_SESSION',
    '-DSQLITE_ENABLE_PREUPDATE_HOOK',
    '-DSQLITE_UNTESTABLE',
    '-DSQLITE_HAVE_ISNAN',
    '-DSQLITE_HAVE_LOCALTIME_R',
    '-DSQLITE_HAVE_LOCALTIME_S',
    '-DSQLITE_HAVE_MALLOC_USABLE_SIZE',
    '-DSQLITE_HAVE_STRCHRNUL',
    '-DSQLITE_THREADSAFE=1'
)

$abis = @(
    @{ abi = 'arm64-v8a';   target = 'aarch64-linux-android24' },
    @{ abi = 'armeabi-v7a'; target = 'armv7a-linux-androideabi23' },
    @{ abi = 'x86_64';      target = 'x86_64-linux-android24' },
    @{ abi = 'riscv64';     target = 'riscv64-linux-android35' }
)

$sysroot = Join-Path $ndk.FullName 'toolchains\llvm\prebuilt\windows-x86_64\sysroot'
foreach ($entry in $abis) {
    $outDir = Join-Path $jniLibs $entry.abi
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $out = Join-Path $outDir 'libsqlite3.so'
    if (Test-Path $out) { Remove-Item $out -Force }

    Write-Host "Building $($entry.abi) ..."
    # NOTE: do not pass -fvisibility=hidden; the FFI layer resolves public
    # sqlite3_* symbols via dlsym, so they must keep default visibility.
    & $clang `
        "--target=$($entry.target)" `
        "--sysroot=$sysroot" `
        @defines `
        '-O2', '-fPIC', '-shared', '-Wl,--export-dynamic' `
        '-o', $out, $sqliteC.FullName, '-lm'
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $out)) {
        throw "Compile failed for $($entry.abi)"
    }

    $symbol = & $llvmNm -D --defined-only $out | Select-String ' T sqlite3_initialize'
    if (-not $symbol) {
        throw "sqlite3_initialize is not exported from $($entry.abi) build"
    }
    $sizeMb = [math]::Round((Get-Item $out).Length / 1MB, 2)
    Write-Host "  OK $($entry.abi): $sizeMb MB, sqlite3_initialize exported"
}

Write-Host 'All ABIs built. Run `flutter build apk` to pick them up.'
