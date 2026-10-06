# code-server の本体を削除する。
# 設定とユーザーデータは残す。それらも消す場合は -Purge を付ける。
# 以前登録したログオンタスクが残っていれば削除する。

[CmdletBinding()]
param(
    [switch]$Purge
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

$config = Get-StudyConfig
& (Join-Path $PSScriptRoot "stop.ps1")

Unregister-ScheduledTask -TaskName $config.TaskName -Confirm:$false -ErrorAction SilentlyContinue

if (Test-Path -LiteralPath $config.InstallDir) {
    Remove-Item -LiteralPath $config.InstallDir -Recurse -Force
}

if ($Purge) {
    foreach ($dir in @($config.ConfigDir, $config.UserDataDir, $config.ExtensionsDir, $config.StateDir, $config.CacheDir)) {
        if (Test-Path -LiteralPath $dir) {
            Remove-Item -LiteralPath $dir -Recurse -Force
        }
    }
    Write-Output "本体、設定、ユーザーデータ、ダウンロードキャッシュを削除しました。"
}
else {
    Write-Output "本体を削除しました。設定とユーザーデータは残しています。"
    Write-Output "完全に消す場合: $(Join-Path $PSScriptRoot 'uninstall.ps1') -Purge"
}
