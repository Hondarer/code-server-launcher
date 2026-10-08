# code-server-launcher の Windows スクリプト共通処理。
# 各スクリプトからドットソースで読み込む。直接の実行は想定しない。

Set-StrictMode -Version 2.0

function Get-LauncherConfig {
    # ProviderPath は UNC パス (\\wsl.localhost\... など) でもプロバイダー名を含まないため、外部コマンドへそのまま渡せる。
    $repoRoot = [System.IO.Path]::GetFullPath((Resolve-Path (Join-Path $PSScriptRoot "..\..")).ProviderPath)
    $versionFile = Join-Path $repoRoot "version.env"
    if (-not (Test-Path -LiteralPath $versionFile)) {
        throw "version.env が見つかりません: $versionFile"
    }

    $values = @{}
    foreach ($raw in Get-Content -LiteralPath $versionFile -Encoding UTF8) {
        $line = $raw.Trim()
        if ($line.Length -eq 0 -or $line.StartsWith("#")) {
            continue
        }
        $idx = $line.IndexOf("=")
        if ($idx -lt 1) {
            continue
        }
        $values[$line.Substring(0, $idx)] = $line.Substring($idx + 1)
    }

    foreach ($name in @(
            "CODE_SERVER_VERSION",
            "CODE_SERVER_PORT",
            "CODE_SERVER_BIND_HOST",
            "CODE_SERVER_WINDOWS_AMD64_SHA256"
        )) {
        if (-not $values.Contains($name) -or [string]::IsNullOrWhiteSpace($values[$name])) {
            throw "version.env に $name が定義されていません。"
        }
    }

    if ($env:CODE_SERVER_PORT) {
        $values["CODE_SERVER_PORT"] = $env:CODE_SERVER_PORT
    }
    if ($env:CODE_SERVER_BIND_HOST) {
        $values["CODE_SERVER_BIND_HOST"] = $env:CODE_SERVER_BIND_HOST
    }

    $workspace = $repoRoot
    if ($env:CODE_SERVER_WORKSPACE) {
        $workspace = $env:CODE_SERVER_WORKSPACE
    }

    $linuxSha256 = ""
    if ($values.Contains("CODE_SERVER_LINUX_AMD64_SHA256")) {
        $linuxSha256 = $values["CODE_SERVER_LINUX_AMD64_SHA256"].ToLowerInvariant()
    }

    $version = $values["CODE_SERVER_VERSION"]
    $port = $values["CODE_SERVER_PORT"]
    $bindHost = $values["CODE_SERVER_BIND_HOST"]
    $base = Join-Path $env:LOCALAPPDATA "code-server-launcher"
    $installDir = Join-Path $base ("code-server-" + $version)
    $configDir = Join-Path $env:USERPROFILE ".config\code-server-launcher"

    return [pscustomobject]@{
        RepoRoot       = $repoRoot
        Version        = $version
        Port           = [int]$port
        BindHost       = $bindHost
        BindAddr       = "${bindHost}:${port}"
        Workspace      = $workspace
        AssetName      = "code-server-$version-windows-amd64.tar.gz"
        AssetUrl       = "https://github.com/coder/code-server/releases/download/v$version/code-server-$version-windows-amd64.tar.gz"
        Sha256         = $values["CODE_SERVER_WINDOWS_AMD64_SHA256"].ToLowerInvariant()
        LinuxAssetName = "code-server-$version-linux-amd64.tar.gz"
        LinuxAssetUrl  = "https://github.com/coder/code-server/releases/download/v$version/code-server-$version-linux-amd64.tar.gz"
        LinuxSha256    = $linuxSha256
        # 事前に取得した配布アーカイブの置き場所。ここに照合済みのアーカイブがあれば、ネットワークに接続せずに導入する。
        PackagesDir    = Join-Path $repoRoot "packages"
        BaseDir        = $base
        InstallDir     = $installDir
        NodeExe        = Join-Path $installDir "lib\node.exe"
        AppDir         = $installDir
        ConfigDir      = $configDir
        ConfigFile     = Join-Path $configDir "config.yaml"
        UserDataDir    = Join-Path $base "user-data"
        ExtensionsDir  = Join-Path $base "extensions"
        CacheDir       = Join-Path $base "cache"
        # code-server が --user-data-dir の指定と無関係に使用する既定のデータ配置先。coder-logs と heartbeat を出力する。
        SharedDataDir  = Join-Path $env:LOCALAPPDATA "code-server\Data"
    }
}

function Assert-WindowsAmd64 {
    $arch = $env:PROCESSOR_ARCHITECTURE
    if ($env:PROCESSOR_ARCHITEW6432) {
        $arch = $env:PROCESSOR_ARCHITEW6432
    }
    if ($arch -ne "AMD64") {
        throw "本ツールが対応している Windows アーキテクチャーは amd64 です (現在: $arch)。"
    }
}

function Test-LauncherFileHash {
    param(
        [string]$Path,
        [string]$Sha256
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
    return $actual -eq $Sha256
}

# URL からファイルを取得し、SHA-256 を照合してから配置する。照合済みのファイルが既に存在すれば取得しない。
function Save-LauncherVerifiedFile {
    param(
        [string]$Url,
        [string]$Destination,
        [string]$Sha256
    )
    if (Test-LauncherFileHash -Path $Destination -Sha256 $Sha256) {
        Write-Output "照合済みのアーカイブが存在します: $Destination"
        return
    }
    Write-Output "ダウンロードします: $Url"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
    $partial = "$Destination.partial"
    if (Test-Path -LiteralPath $partial) {
        Remove-Item -LiteralPath $partial -Force
    }
    $curl = Join-Path $env:SystemRoot "System32\curl.exe"
    & $curl -fL --retry 3 --retry-delay 2 --connect-timeout 20 -o $partial $Url
    if ($LASTEXITCODE -ne 0) {
        if (Test-Path -LiteralPath $partial) {
            Remove-Item -LiteralPath $partial -Force
        }
        throw "ダウンロードに失敗しました (curl exit $LASTEXITCODE)。"
    }
    if (-not (Test-LauncherFileHash -Path $partial -Sha256 $Sha256)) {
        $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $partial).Hash.ToLowerInvariant()
        Remove-Item -LiteralPath $partial -Force
        throw "SHA-256 が一致しません。期待 $Sha256 / 実際 $actual"
    }
    Move-Item -LiteralPath $partial -Destination $Destination -Force
}

function New-LauncherPassword {
    $bytes = New-Object byte[] 24
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($bytes)
    }
    finally {
        $rng.Dispose()
    }
    $builder = New-Object System.Text.StringBuilder
    foreach ($byte in $bytes) {
        [void]$builder.Append($byte.ToString("x2"))
    }
    return $builder.ToString()
}

function Protect-LauncherConfigFile {
    param([string]$Path)
    $acl = New-Object System.Security.AccessControl.FileSecurity
    $acl.SetAccessRuleProtection($true, $false)
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $identity,
        "FullControl",
        "Allow"
    )
    $acl.AddAccessRule($rule)
    [System.IO.File]::SetAccessControl($Path, $acl)
}

function Write-LauncherTextFile {
    param(
        [string]$Path,
        [string]$Content
    )
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Update-LauncherCodeServerConfig {
    param(
        $Config,
        [ValidateSet("Ensure", "Reset")]
        [string]$Mode
    )

    New-Item -ItemType Directory -Force -Path $Config.ConfigDir | Out-Null
    $exists = Test-Path -LiteralPath $Config.ConfigFile
    $password = $null

    if (-not $exists) {
        $password = New-LauncherPassword
        $content = @(
            "bind-addr: $($Config.BindAddr)"
            "auth: password"
            "password: $password"
            "cert: false"
            "disable-telemetry: true"
            "disable-update-check: true"
        ) -join "`r`n"
        Write-LauncherTextFile -Path $Config.ConfigFile -Content ($content + "`r`n")
        Protect-LauncherConfigFile -Path $Config.ConfigFile
        return $password
    }

    $lines = @(Get-Content -LiteralPath $Config.ConfigFile -Encoding UTF8)
    $out = New-Object System.Collections.Generic.List[string]
    $sawBind = $false

    if ($Mode -eq "Reset") {
        $password = New-LauncherPassword
        $rendered = @{
            "bind-addr"             = "bind-addr: $($Config.BindAddr)"
            "auth"                  = "auth: password"
            "password"              = "password: $password"
            "cert"                  = "cert: false"
            "disable-telemetry"     = "disable-telemetry: true"
            "disable-update-check"  = "disable-update-check: true"
        }
        $seen = @{}
        foreach ($line in $lines) {
            $key = ""
            if ($line -match "^([^:#][^:]*):") {
                $key = $Matches[1].Trim()
            }
            if ($key -eq "hashed-password") {
                continue
            }
            if ($rendered.ContainsKey($key)) {
                $out.Add($rendered[$key])
                $seen[$key] = $true
            }
            else {
                $out.Add($line)
            }
        }
        foreach ($key in @(
                "bind-addr",
                "auth",
                "password",
                "cert",
                "disable-telemetry",
                "disable-update-check"
            )) {
            if (-not $seen.ContainsKey($key)) {
                $out.Add($rendered[$key])
            }
        }
    }
    else {
        foreach ($line in $lines) {
            if ($line -match "^bind-addr:") {
                $out.Add("bind-addr: $($Config.BindAddr)")
                $sawBind = $true
            }
            else {
                $out.Add($line)
            }
        }
        if (-not $sawBind) {
            $out.Insert(0, "bind-addr: $($Config.BindAddr)")
        }
    }

    $text = ($out -join "`r`n") + "`r`n"
    Write-LauncherTextFile -Path $Config.ConfigFile -Content $text
    Protect-LauncherConfigFile -Path $Config.ConfigFile
    return $password
}

function Get-CodeServerArguments {
    param($Config)
    return @(
        $Config.AppDir,
        "--config", $Config.ConfigFile,
        "--bind-addr", $Config.BindAddr,
        "--auth", "password",
        # 前回開いたフォルダーよりも、今回の起動で指定したワークスペースを優先する。
        "--ignore-last-opened",
        "--user-data-dir", $Config.UserDataDir,
        "--extensions-dir", $Config.ExtensionsDir,
        $Config.Workspace
    )
}

function Test-CodeServerInstalled {
    param($Config)
    return (Test-Path -LiteralPath $Config.NodeExe) -and (Test-Path -LiteralPath (Join-Path $Config.AppDir "package.json"))
}

function Get-LauncherCodeServerProcessIds {
    param($Config)
    $marker = [string]$Config.ConfigFile
    $found = @()
    $processes = @(Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" -ErrorAction SilentlyContinue)
    if ($processes.Count -eq 1 -and $null -eq $processes[0]) {
        return @()
    }
    foreach ($process in $processes) {
        if ($null -eq $process) {
            continue
        }
        $command = [string]$process.CommandLine
        if ($command -and $command.Contains($marker)) {
            $found += [int]$process.ProcessId
        }
    }
    return @($found)
}

# ポートで待ち受けているプロセスの PID を取得する。netstat の出力と異なり、OS の表示言語に影響されない。
function Get-LauncherPortOwnerIds {
    param([int]$Port)
    $connections = @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)
    return @($connections | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_.OwningProcess } | Sort-Object -Unique)
}

function Test-LauncherPortListening {
    param([int]$Port)
    return @(Get-LauncherPortOwnerIds -Port $Port).Count -gt 0
}

function Get-LauncherHttpStatus {
    param([int]$Port)
    try {
        $request = [System.Net.HttpWebRequest]::Create("http://127.0.0.1:$Port/")
        $request.Method = "GET"
        $request.AllowAutoRedirect = $false
        $request.Timeout = 3000
        $response = $request.GetResponse()
        try {
            return [int]$response.StatusCode
        }
        finally {
            $response.Close()
        }
    }
    catch [System.Net.WebException] {
        $webResponse = $_.Exception.Response
        if ($webResponse -ne $null) {
            try {
                return [int]$webResponse.StatusCode
            }
            finally {
                $webResponse.Close()
            }
        }
        return 0
    }
    catch {
        return 0
    }
}

# Windows では外部コンソール プロセスへ安全な終了シグナルを送る標準手段が制限されているため、プロセス ツリーを強制終了する。
# 通常の停止操作には、起動したウィンドウでの Ctrl+C を推奨する。
function Stop-LauncherCodeServer {
    param($Config)
    $ids = @(Get-LauncherCodeServerProcessIds -Config $Config)
    if ($ids.Count -eq 0) {
        return $false
    }
    foreach ($processId in $ids) {
        & taskkill.exe /PID $processId /T /F | Out-Null
    }
    Start-Sleep -Seconds 1
    return $true
}

function Write-LauncherEndpoints {
    param($Config)
    Write-Output "接続先: http://127.0.0.1:$($Config.Port)/"
    Write-Output "同一 Windows 上のブラウザーからは http://localhost:$($Config.Port)/ で接続します。"
    Write-Output "設定: $($Config.ConfigFile)"
    Write-Output "ワークスペース: $($Config.Workspace)"
}
