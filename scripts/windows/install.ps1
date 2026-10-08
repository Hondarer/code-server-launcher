# code-server の Windows standalone 版をユーザー領域へ導入し、待受設定を作成する。
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

# packages\ にアーカイブがあればそれを照合して使用し、ネットワークには接続しない。
# なければキャッシュ フォルダーへ取得する。
$packaged = Join-Path $config.PackagesDir $config.AssetName
if (Test-Path -LiteralPath $packaged -PathType Leaf) {
    if (-not (Test-LauncherFileHash -Path $packaged -Sha256 $config.Sha256)) {
        throw "packages\ のアーカイブの SHA-256 が一致しません: $packaged"
    }
    Write-Output "packages\ の照合済みアーカイブを使用します (オフライン導入): $packaged"
    $archive = $packaged
}
else {
    $archive = Join-Path $config.CacheDir $config.AssetName
    if (Test-LauncherFileHash -Path $archive -Sha256 $config.Sha256) {
        Write-Output "検証済みのアーカイブを使用します: $archive"
    }
    else {
        Write-Output "code-server $($config.Version) をダウンロードします。"
        Save-LauncherVerifiedFile -Url $config.AssetUrl -Destination $archive -Sha256 $config.Sha256
    }
}

$nodeReady = Test-CodeServerInstalled -Config $config
if (-not $nodeReady) {
    $running = @(Get-LauncherCodeServerProcessIds -Config $config)
    if ($running.Count -gt 0) {
        throw "code-server が動作中です。再インストールする前に scripts\windows\stop.ps1 を実行してください。"
    }
    $temp = Join-Path ([System.IO.Path]::GetTempPath()) ("code-server-launcher-" + [guid]::NewGuid().ToString("n"))
    New-Item -ItemType Directory -Force -Path $temp | Out-Null
    try {
        # PATH 上の Git for Windows などに含まれる GNU tar は C:\ を含むパスを扱えないため、OS 標準の tar.exe を使用する。
        $tar = Join-Path $env:SystemRoot "System32\tar.exe"
        & $tar -xzf $archive -C $temp
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
    Write-Output "ログイン パスワード: $created"
}
else {
    Write-Output "既存の設定を使用します: $($config.ConfigFile)"
    Write-Output "待受アドレスを $($config.BindAddr) に更新しました。"
}

Write-Output "導入が完了しました。"
Write-Output "起動: $(Join-Path $PSScriptRoot 'start.ps1')"
& $config.NodeExe $config.AppDir --config $config.ConfigFile --version
if ($LASTEXITCODE -ne 0) {
    throw "code-server --version に失敗しました。"
}
