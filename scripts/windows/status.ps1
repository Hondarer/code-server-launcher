# code-server の導入状態、待受、HTTP 応答を表示する。
# パスワード自体は表示しない。待受が無い場合は終了コード 1。

[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

$config = Get-StudyConfig
Write-Output "version.env: code-server $($config.Version)"
Write-Output "待受: $($config.BindAddr)"
Write-Output "ワークスペース: $($config.Workspace)"

if (Test-CodeServerInstalled -Config $config) {
    Write-Output "導入先: $($config.InstallDir)"
    & $config.NodeExe $config.AppDir --config $config.ConfigFile --version
}
else {
    Write-Output "導入先: 未導入"
}

if (Test-Path -LiteralPath $config.ConfigFile) {
    Write-Output "設定: $($config.ConfigFile)"
    $hasPassword = Select-String -LiteralPath $config.ConfigFile -Pattern "^password:" -Quiet
    $hasHash = Select-String -LiteralPath $config.ConfigFile -Pattern "^hashed-password:" -Quiet
    if ($hasPassword) {
        Write-Output "パスワード: 設定ファイルの password キー"
    }
    elseif ($hasHash) {
        Write-Output "パスワード: hashed-password として保存されています。再設定は scripts\windows\reset-password.ps1"
    }
    else {
        Write-Output "パスワード: 設定ファイルに password がありません。"
    }
}
else {
    Write-Output "設定: 未作成"
}

$running = @(Get-StudyCodeServerProcessIds -Config $config)
if ($running.Count -gt 0) {
    Write-Output ("プロセス: running (pid " + ($running -join ", ") + ")")
}
else {
    Write-Output "プロセス: stopped"
}

$owners = @(Get-StudyPortOwnerIds -Port $config.Port)
$listening = $owners.Count -gt 0
if ($listening) {
    Write-Output "ポート $($config.Port): listening"
    foreach ($ownerId in $owners) {
        $info = Get-CimInstance Win32_Process -Filter "ProcessId = $ownerId" -ErrorAction SilentlyContinue
        $name = "unknown"
        $label = "別のプロセス"
        if ($null -ne $info) {
            $name = $info.Name
            if ($running -contains $ownerId -or $running -contains [int]$info.ParentProcessId) {
                $label = "このサンプルの code-server"
            }
            elseif ([string]$info.ExecutablePath -eq $config.NodeExe) {
                $label = "このサンプルの node.exe。起動元のプロセスは終了済み。止めるには taskkill /PID $ownerId /T /F"
            }
        }
        Write-Output "  pid $ownerId ($name): $label"
    }
}
else {
    Write-Output "ポート $($config.Port): closed"
}

$http = Get-StudyHttpStatus -Port $config.Port
Write-Output "HTTP http://127.0.0.1:$($config.Port)/ : $http"

if (-not $listening) {
    exit 1
}
