# code-server の本体を削除する。
# 設定とユーザー データは保持する。これらも削除する場合は -Purge を指定する。

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
    # 既定のデータ配置先は他の code-server と共有するため、本ツールが出力したもののみを削除する。
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
    Write-Output "本体、設定、ユーザー データ、拡張機能、ダウンロード キャッシュ、code-server のログを削除しました。"
}
else {
    Write-Output "本体を削除しました。設定とユーザー データは保持しています。"
    Write-Output "完全に削除する場合: $(Join-Path $PSScriptRoot 'uninstall.ps1') -Purge"
}
