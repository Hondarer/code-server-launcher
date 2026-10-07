# code-server の Windows standalone 版をユーザー領域へ導入し、待受設定を作る。
# プロセスは起動しない。起動は start.ps1 が行う。

[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

Assert-WindowsAmd64
$config = Get-LauncherConfig

foreach ($dir in @(
        $config.BaseDir,
        $config.CacheDir,
        $config.UserDataDir,
        $config.ExtensionsDir,
        $config.ConfigDir
    )) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

$archive = Join-Path $config.CacheDir $config.AssetName
$hashOk = $false
if (Test-Path -LiteralPath $archive) {
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash.ToLowerInvariant()
    $hashOk = $actual -eq $config.Sha256
}

if (-not $hashOk) {
    Write-Output "code-server $($config.Version) をダウンロードします。"
    $partial = "$archive.partial"
    if (Test-Path -LiteralPath $partial) {
        Remove-Item -LiteralPath $partial -Force
    }
    $curl = Join-Path $env:SystemRoot "System32\curl.exe"
    & $curl -fL --retry 3 --retry-delay 2 --connect-timeout 20 -o $partial $config.AssetUrl
    if ($LASTEXITCODE -ne 0) {
        throw "ダウンロードに失敗しました (curl exit $LASTEXITCODE)。"
    }
    Move-Item -LiteralPath $partial -Destination $archive -Force
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash.ToLowerInvariant()
    if ($actual -ne $config.Sha256) {
        Remove-Item -LiteralPath $archive -Force
        throw "SHA-256 が一致しません。期待 $($config.Sha256) / 実際 $actual"
    }
}
else {
    Write-Output "検証済みのアーカイブを使います: $archive"
}

$nodeReady = Test-CodeServerInstalled -Config $config
if (-not $nodeReady) {
    $running = @(Get-LauncherCodeServerProcessIds -Config $config)
    if ($running.Count -gt 0) {
        throw "code-server が動作中です。入れ直す前に scripts\windows\stop.ps1 を実行してください。"
    }
    $temp = Join-Path ([System.IO.Path]::GetTempPath()) ("code-server-launcher-" + [guid]::NewGuid().ToString("n"))
    New-Item -ItemType Directory -Force -Path $temp | Out-Null
    try {
        & tar.exe -xzf $archive -C $temp
        if ($LASTEXITCODE -ne 0) {
            throw "アーカイブの展開に失敗しました (tar exit $LASTEXITCODE)。"
        }
        $extracted = Join-Path $temp ("code-server-" + $config.Version + "-windows-amd64")
        if (-not (Test-Path -LiteralPath $extracted)) {
            throw "アーカイブの展開結果が見つかりません: $extracted"
        }
        if (Test-Path -LiteralPath $config.InstallDir) {
            Remove-Item -LiteralPath $config.InstallDir -Recurse -Force
        }
        Move-Item -LiteralPath $extracted -Destination $config.InstallDir
    }
    finally {
        if (Test-Path -LiteralPath $temp) {
            Remove-Item -LiteralPath $temp -Recurse -Force
        }
    }
    Write-Output "展開しました: $($config.InstallDir)"
}
else {
    Write-Output "導入済みです: $($config.InstallDir)"
}

$created = Update-LauncherCodeServerConfig -Config $config -Mode Ensure
if ($created) {
    Write-Output "設定ファイルを作成しました: $($config.ConfigFile)"
    Write-Output "ログインパスワード: $created"
}
else {
    Write-Output "既存の設定を使います: $($config.ConfigFile)"
    Write-Output "待受アドレスを $($config.BindAddr) に合わせました。"
}

Write-Output "導入が完了しました。"
Write-Output "起動: $(Join-Path $PSScriptRoot 'start.ps1')"
& $config.NodeExe $config.AppDir --config $config.ConfigFile --version
if ($LASTEXITCODE -ne 0) {
    throw "code-server --version に失敗しました。"
}
