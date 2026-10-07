# ログイン パスワードを再生成する。
# 起動中のプロセスは停止する。新しいパスワードは、次回 start.ps1 から起動した際に反映される。

[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

$config = Get-LauncherConfig
$running = @(Get-LauncherCodeServerProcessIds -Config $config)
$password = Update-LauncherCodeServerConfig -Config $config -Mode Reset
if ($running.Count -gt 0) {
    & (Join-Path $PSScriptRoot "stop.ps1")
    Write-Output "起動中のプロセスを停止しました。新しいパスワードは、次回の start.ps1 実行時から反映されます。"
}

Write-Output "新しいログイン パスワード: $password"
Write-Output "設定: $($config.ConfigFile)"
Write-Output "起動: $(Join-Path $PSScriptRoot 'start.ps1')"
