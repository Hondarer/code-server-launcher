# code-server の導入状態、待受状態、HTTP 応答を表示する。
# パスワード自体は表示しない。待受が存在しない場合は終了コード 1。

[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common.ps1")

$config = Get-LauncherConfig
Write-Output "version.env: code-server $($config.Version)"
Write-Output "待受: $($config.BindAddr)"
Write-Output "ワークスペース: $($config.Workspace)"

if (Test-CodeServerInstalled -Config $config) {
    Write-Output "導入先: $($config.InstallDir)"
    # code-server を実行すると、設定ファイルが存在しない場合に既定内容で自動生成してしまうため、package.json から読み取る。
    $package = Get-Content -LiteralPath (Join-Path $config.AppDir "package.json") -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Output "バージョン: $($package.version)"
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
        Write-Output "パスワード: hashed-password として保存されています。再設定コマンド: scripts\windows\reset-password.ps1"
    }
    else {
        Write-Output "パスワード: 設定ファイルに password キーが存在しません。"
    }
}
else {
    Write-Output "設定: 未作成"
}

$running = @(Get-LauncherCodeServerProcessIds -Config $config)
if ($running.Count -gt 0) {
    Write-Output ("プロセス: running (pid " + ($running -join ", ") + ")")
}
else {
    Write-Output "プロセス: stopped"
}

$owners = @(Get-LauncherPortOwnerIds -Port $config.Port)
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
                $label = "このツールの code-server"
            }
            elseif ([string]$info.ExecutablePath -eq $config.NodeExe) {
                $label = "本ツールの node.exe。起動元プロセスは終了済み。停止コマンド: taskkill /PID $ownerId /T /F"
            }
        }
        Write-Output "  pid $ownerId ($name): $label"
    }
}
else {
    Write-Output "ポート $($config.Port): closed"
}

$http = Get-LauncherHttpStatus -Port $config.Port
Write-Output "HTTP http://127.0.0.1:$($config.Port)/ : $http"

if (-not $listening) {
    exit 1
}
