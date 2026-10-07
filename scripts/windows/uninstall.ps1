# code-server の本体を削除する。
# 設定とユーザーデータは残す。それらも消す場合は -Purge を付ける。

[CmdletBinding()]
param(
    [switch]$Purge
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

$config = Get-LauncherConfig
& (Join-Path $PSScriptRoot "stop.ps1")

if (Test-Path -LiteralPath $config.InstallDir) {
    Remove-Item -LiteralPath $config.InstallDir -Recurse -Force
}

if ($Purge) {
    foreach ($dir in @($config.ConfigDir, $config.UserDataDir, $config.ExtensionsDir, $config.CacheDir)) {
        if (Test-Path -LiteralPath $dir) {
            Remove-Item -LiteralPath $dir -Recurse -Force
        }
    }
    # 既定のデータ置き場はほかの code-server と共有するので、このツールが書くものだけを消す。
    foreach ($name in @("coder-logs", "heartbeat")) {
        $target = Join-Path $config.SharedDataDir $name
        if (Test-Path -LiteralPath $target) {
            Remove-Item -LiteralPath $target -Recurse -Force
        }
    }
    foreach ($dir in @($config.SharedDataDir, (Split-Path -Parent $config.SharedDataDir))) {
        if ((Test-Path -LiteralPath $dir) -and -not (Get-ChildItem -LiteralPath $dir -Force)) {
            Remove-Item -LiteralPath $dir -Force
        }
    }
    Write-Output "本体、設定、ユーザーデータ、拡張機能、ダウンロードキャッシュ、code-server のログを削除しました。"
}
else {
    Write-Output "本体を削除しました。設定とユーザーデータは残しています。"
    Write-Output "完全に消す場合: $(Join-Path $PSScriptRoot 'uninstall.ps1') -Purge"
}
