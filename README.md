# code-server-launcher

[code-server](https://github.com/coder/code-server) を、Linux (WSL を含む) と Windows のユーザー領域へ導入し、ポート 8000 で動作させるためのスクリプト集です。導入するバージョンは `version.env` で固定し、配布アーカイブの SHA-256 を照合してから展開します。Coder の公式プロジェクトではありません。導入作業およびコマンドによる起動・停止に管理者権限は不要です。Linux でユーザー サービスとして常駐させる場合のみ、linger の有効化に管理者権限が必要となる場合があります (「[応用: systemd ユーザー サービス](#応用-systemd-ユーザー-サービス-linux--wsl)」を参照)。

| 項目 | 値 |
|---|---|
| code-server | 4.140.0 (Code 1.140.0) |
| 待受 | `0.0.0.0:8000` |
| 認証 | パスワード (`auth: password`) |
| TLS | 無効 (`cert: false`) |
| 対象 | Linux x86_64、Windows amd64 |
| 動作確認環境 | WSL2 上の Oracle Linux 8、Windows 11 Pro for Workstations (PowerShell 5.1) |

起動の基本操作は、シェルで `start` スクリプトを実行する方法です。code-server はその端末のフォアグラウンドで動作し、Ctrl+C で終了します。Linux では、ログアウト後も稼働させ続けるための systemd ユーザー サービスを応用手順として用意しています。

## 構成

```text
code-server-launcher/
+-- version.env                  # バージョン、待受の既定値、配布アーカイブの SHA-256
+-- config/
|   \-- config.yaml.example      # 設定ファイルのひな型 (起動には使用しない)
\-- scripts/
    +-- lib/
    |   \-- common.sh            # Linux スクリプトの共通処理
    +-- linux/
    |   +-- install.sh           # 導入と設定ファイルの作成
    |   +-- start.sh             # フォアグラウンドで起動
    |   +-- stop.sh              # 別の端末から停止
    |   +-- status.sh            # 状態の表示
    |   +-- reset-password.sh    # パスワードの再生成
    |   +-- uninstall.sh         # 削除
    |   \-- user-service.sh      # 応用: systemd ユーザー サービス
    \-- windows/
        +-- common.ps1           # Windows スクリプトの共通処理
        +-- install.ps1
        +-- start.ps1
        +-- stop.ps1
        +-- status.ps1
        +-- reset-password.ps1
        \-- uninstall.ps1
```

ポート 8000 は、Linux 側と Windows 側のどちらか一方で利用します。

## 前提条件

Linux / WSL:

- x86_64 (`install.sh` が `uname -m` で確認)
- `curl`、`tar`、`sha256sum`、`python3`、`openssl`、`ss`
- ユーザー サービスを使用する場合のみ、systemd のユーザー セッション (`systemctl --user`) と、linger を有効化するための `loginctl`

Windows:

- amd64 (`install.ps1` と `start.ps1` が確認)
- Windows PowerShell 5.1
- `curl.exe` と `tar.exe` (Windows 10 以降に標準搭載)
- スクリプトは UTF-8 (BOM 付き)、改行コードは CRLF で保存されていること

code-server の公式ドキュメントでは Windows を配布対象として案内していませんが、公式リリースには `windows-amd64` の配布物が含まれています。Windows 版のスクリプトではその配布物を使用します。

## 利用手順

Linux / WSL:

```bash
./scripts/linux/install.sh
./scripts/linux/start.sh
```

Windows (リポジトリ ルートをカレント ディレクトリとした PowerShell):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\install.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\start.ps1
```

`install` スクリプトは初回実行時に限り、ログイン パスワードを自動生成して表示します。ブラウザーで `http://localhost:8000/` を開き、表示されたパスワードでログインします。

## スクリプト一覧

### Linux / WSL

| スクリプト | 動作 |
|---|---|
| `install.sh` | 配布アーカイブを `~/.cache/code-server-launcher/` へ取得し、SHA-256 を照合して `~/.local/lib/code-server-<バージョン>` へ展開する。照合済みのアーカイブが存在すれば再取得しない。`~/.local/bin/code-server` にシンボリック リンクを作成し、設定ファイルを生成する。code-server 自体は起動しない |
| `start.sh [--restart]` | 実行シェル プロセスを code-server に置き換え、フォアグラウンドで動作させる。ログはその端末に出力される |
| `stop.sh` | 起動中の code-server に SIGTERM を送信し、5 秒以内に終了しなければ SIGKILL で強制終了する |
| `status.sh` | バージョン、待受アドレス、ワークスペース、導入先、設定、プロセス、ユーザー サービス、ポート、HTTP 応答を表示する。パスワードは表示しない。待受が存在しなければ終了コード 1 |
| `reset-password.sh` | ログイン パスワードを再生成して表示する |
| `uninstall.sh [--purge]` | 本体を削除する。`--purge` 指定時は設定とデータも削除する |
| `user-service.sh <操作>` | 応用操作。systemd ユーザー サービスの登録、起動、停止、状態表示、削除 |

### Windows

| スクリプト | 動作 |
|---|---|
| `install.ps1` | 配布アーカイブを `%LOCALAPPDATA%\code-server-launcher\cache\` へ取得し、SHA-256 を照合して `%LOCALAPPDATA%\code-server-launcher\code-server-<バージョン>` へ展開する。設定ファイルを生成する。code-server 自体は起動しない |
| `start.ps1 [-Restart]` | 実行ウィンドウのフォアグラウンドで、同梱の `node.exe` を通じて code-server を動作させる。ログはそのウィンドウに出力される |
| `stop.ps1` | 起動中の code-server プロセス ツリーを `taskkill /T /F` で強制終了する |
| `status.ps1` | `status.sh` と同様の項目 (ユーザー サービスを除く) に加え、ポートで待ち受けているプロセスの PID と、それが本ツールの管理対象かを表示する。待受が存在しなければ終了コード 1 |
| `reset-password.ps1` | ログイン パスワードを再生成して表示する |
| `uninstall.ps1 [-Purge]` | 本体を削除する。`-Purge` 指定時は設定とデータも削除する |

Windows 向けには常駐機能 (Windows サービスやログオン タスク) を提供していません。

## 起動と停止

`start` スクリプトは、起動処理の前に次の項目を確認します。

1. code-server が導入済みであること、およびワークスペースのフォルダーが存在すること
2. (Linux) ユーザー サービスが動作していないこと。動作している場合はシェルでの起動を行わず、接続先を表示して終了する (終了コード 0、`--restart` 指定時は 1)。登録済みで停止中の場合は、`user-service.sh start` または `disable` の実行を案内して終了コード 1 で終了する
3. 設定ファイルが存在すること。存在しない場合はパスワード付きで新規作成し、そのパスワードを表示する。存在する場合は `bind-addr` を今回の待受アドレスに合わせて更新する
4. 本ツールの code-server がすでに起動していないこと。起動している場合は接続先を表示して終了する。`--restart` または `-Restart` 指定時は、既存プロセスを停止してから再起動する
5. 待受ポートを他のプロセスが使用していないこと

起動時には環境変数 `VSCODE_IPC_HOOK_CLI` と `ELECTRON_RUN_AS_NODE` を削除します。VS Code 内蔵端末では、これらの環境変数が残っていると code-server が待受を開始せず、親の VS Code 側へ処理を戻して終了してしまうためです。

code-server には次の引数を渡して実行します。

```text
--config <設定ファイル>
--bind-addr <待受ホスト>:<ポート>
--auth password
--ignore-last-opened
--user-data-dir <ユーザーデータ>
--extensions-dir <拡張機能>
<ワークスペース>
```

停止操作は、起動した端末で Ctrl+C を入力するのが基本です。code-server が終了処理を実行したうえで安全に停止します。端末ウィンドウを閉じた場合も終了します。別の端末から停止させる場合は `stop` スクリプトを使用します。

- Linux の `stop.sh` は SIGTERM を送信し、5 秒経過してもプロセスが残存していれば SIGKILL で強制終了します。ユーザー サービスが稼働中の場合は停止せず、`user-service.sh stop` の実行を案内して終了コード 1 で終了します。
- Windows の `stop.ps1` はプロセス ツリーを強制終了します。Windows では外部プロセスへ安全な終了シグナルを送信する標準的な手段が制限されているためです。`start.ps1 -Restart`、`reset-password.ps1`、`uninstall.ps1` においても、起動中プロセスはこの方式で停止します。

`stop` スクリプトが停止対象とするのは、本ツールの設定ファイルを `--config` 引数に指定しているプロセスのみです。同一マシン上で動作している他の code-server プロセスには影響を与えません。

## 設定値と環境変数

設定の既定値は `version.env` に定義されており、Linux と Windows の両スクリプトから参照されます。

| キー | 既定値 | 用途 |
|---|---|---|
| `CODE_SERVER_VERSION` | `4.140.0` | 導入するバージョン |
| `CODE_SERVER_PORT` | `8000` | 待受ポート |
| `CODE_SERVER_BIND_HOST` | `0.0.0.0` | 待受アドレス |
| `CODE_SERVER_LINUX_AMD64_SHA256` | (ハッシュ値) | Linux 版アーカイブの SHA-256 |
| `CODE_SERVER_WINDOWS_AMD64_SHA256` | (ハッシュ値) | Windows 版アーカイブの SHA-256 |

次の環境変数が設定されている場合は、`version.env` の定義よりも優先されます。

| 環境変数 | 用途 |
|---|---|
| `CODE_SERVER_PORT` | 待受ポート |
| `CODE_SERVER_BIND_HOST` | 待受アドレス |
| `CODE_SERVER_WORKSPACE` | 起動時に開くフォルダー (既定値はこのリポジトリ) |

`start` スクリプトは、設定ファイル内の `bind-addr` を起動時の待受アドレスへ更新します。

```bash
CODE_SERVER_BIND_HOST=127.0.0.1 ./scripts/linux/start.sh --restart
```

```powershell
$env:CODE_SERVER_BIND_HOST = "127.0.0.1"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\start.ps1 -Restart
```

待受ホストに `127.0.0.1` を指定すると、接続はその OS のループバック アドレスに限定されます。

### ワークスペース

起動時に開くワークスペース フォルダーの既定値は、本リポジトリのルート ディレクトリです。`install` スクリプトにフォルダーを指定するオプションはありません。変更する場合は、起動前に環境変数 `CODE_SERVER_WORKSPACE` を指定します。

```bash
CODE_SERVER_WORKSPACE="$HOME/work/my-project" ./scripts/linux/start.sh --restart
```

```powershell
$env:CODE_SERVER_WORKSPACE = "D:\work\my-project"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\start.ps1 -Restart
# リポジトリを開く既定値に戻す場合
Remove-Item Env:CODE_SERVER_WORKSPACE
```

起動引数に `--ignore-last-opened` を付与しているため、前回開いたフォルダーよりも今回の起動時の指定が優先されます。ただし、ブラウザーのアクセス URL に `?folder=...` や `?workspace=...` などのクエリ パラメーターが含まれている場合は URL 側の指定が優先されます。その場合は `http://localhost:8000/` へ再度アクセスしてください。

## パスワード

設定ファイル (`config.yaml`) は次の内容で自動生成されます。パスワードは 48 桁の 16 進文字列です。

```yaml
bind-addr: 0.0.0.0:8000
auth: password
password: <生成したパスワード>
cert: false
disable-telemetry: true
disable-update-check: true
```

ファイルのアクセス権限は、Linux ではファイルに `600` (ディレクトリは `700`) を設定し、Windows ではアクセス権の継承を無効化して現在の実行ユーザーのみに制限します。パスワードは次のコマンドで確認できます。

```bash
grep '^password:' ~/.config/code-server-launcher/config.yaml
```

```powershell
Select-String -Path "$env:USERPROFILE\.config\code-server-launcher\config.yaml" -Pattern '^password:'
```

`reset-password` スクリプトは、新しいパスワードを生成して表示します。前述の 6 つのキーを再設定し、`hashed-password` キーが存在する場合は削除します。その他の設定行はそのまま維持します。

- code-server がシェル上で起動中の場合は、該当プロセスを停止します。続いて `start` スクリプトを実行すると、新しいパスワードが適用されます。
- (Linux) ユーザー サービスが稼働中の場合は、サービスを自動で再起動して新しいパスワードを反映します。

`status` スクリプトは、パスワードが `password` キーと `hashed-password` キーのどちらで保存されているかの種別のみを表示します。

## 永続化データ

### 配置先

Linux / WSL:

| 用途 | パス | `uninstall.sh` | `--purge` |
|---|---|---|---|
| 本体 | `~/.local/lib/code-server-4.140.0/` | 削除 | 削除 |
| コマンド | `~/.local/bin/code-server` (本体へのシンボリック リンク) | 削除 | 削除 |
| 設定 | `~/.config/code-server-launcher/config.yaml` | 保持 | 削除 |
| ユーザー データ | `~/.local/share/code-server-launcher/user-data/` | 保持 | 削除 |
| 拡張機能 | `~/.local/share/code-server-launcher/extensions/` | 保持 | 削除 |
| 配布アーカイブ | `~/.cache/code-server-launcher/` | 保持 | 削除 |
| code-server 本体のログ | `~/.local/share/code-server/` 配下の `coder-logs/` および `heartbeat` | 保持 | この 2 つのみ削除 |

`$XDG_DATA_HOME` を設定している場合、code-server 本体のログは `$XDG_DATA_HOME/code-server/` 配下に配置されます。

Windows:

| 用途 | パス | `uninstall.ps1` | `-Purge` |
|---|---|---|---|
| 本体 | `%LOCALAPPDATA%\code-server-launcher\code-server-4.140.0\` | 削除 | 削除 |
| 設定 | `%USERPROFILE%\.config\code-server-launcher\config.yaml` | 保持 | 削除 |
| ユーザー データ | `%LOCALAPPDATA%\code-server-launcher\user-data\` | 保持 | 削除 |
| 拡張機能 | `%LOCALAPPDATA%\code-server-launcher\extensions\` | 保持 | 削除 |
| 配布アーカイブ | `%LOCALAPPDATA%\code-server-launcher\cache\` | 保持 | 削除 |
| code-server 本体のログ | `%LOCALAPPDATA%\code-server\Data\` 配下の `coder-logs\` および `heartbeat` | 保持 | この 2 つのみ削除 |

フォルダー名を `code-server` ではなく `code-server-launcher` としているのは、code-server 既定の配置先と分離するためです。Linux における `~/.config/code-server/config.yaml` や `~/.local/share/code-server/` は、`--config` を指定せずに起動された通常の code-server が使用します。同一マシン上の VS Code や、既定の配置先を使用する他の code-server とは、設定や拡張機能を共有しません。

### ディレクトリ構成

| パス | 内容 |
|---|---|
| `extensions/` | インストールした拡張機能の本体、および一覧管理用の `extensions.json` |
| `user-data/User/settings.json` | ユーザー設定 |
| `user-data/User/keybindings.json`、`snippets/` | キー バインドおよびスニペット (作成時に生成) |
| `user-data/User/globalStorage/` | 拡張機能が保持する永続データ |
| `user-data/User/workspaceStorage/` | ワークスペースごとの個別状態 |
| `user-data/User/History/` | エディターのローカル編集履歴 |
| `user-data/Machine/` | 当該マシン固有の設定 |
| `user-data/logs/` | 起動ごとの実行ログ (起動日時名のフォルダーが追加される) |
| `user-data/CachedProfilesData/` など | キャッシュ データ (削除しても必要に応じて再生成される) |

ワークスペース固有の `.vscode/settings.json` は、ワークスペースのフォルダー側に保存されます。

code-server は `--user-data-dir` の指定に関わらず、既定の配置場所 (表内の「code-server 本体のログ」) に `coder-logs` (標準出力・標準エラー出力のログ) と `heartbeat` (最終アクセス日時ファイル) を出力します。この領域は他の code-server と共有される可能性があるため、`--purge` および `-Purge` ではこの 2 つのみを削除し、フォルダー自体は空になった場合に限り削除します。

### 代表的な管理操作

`user-data/` や `extensions/` を削除またはバックアップする前に、必ず code-server を停止してください。

| 操作目的 | 手順 |
|---|---|
| 設定と拡張機能のバックアップ | `user-data/User/` と `extensions/` をコピーする。拡張機能にはネイティブ バイナリが含まれる場合があるため、同一 OS 間でのみ移行する |
| 設定の初期化 | `user-data/` を削除する (拡張機能は保持される) |
| すべての拡張機能の削除 | `extensions/` を削除する |
| ログの整理 | `user-data/logs/` 配下の古いフォルダー、および code-server 本体の `coder-logs/` を削除する |

拡張機能はブラウザー画面上の拡張機能ビューからインストールします。コマンド ラインからインストールする場合は、`--config`、`--user-data-dir`、`--extensions-dir` を必ず指定してください。指定を省略すると既定の `~/.local/share/code-server/extensions` に配置され、本ツールの code-server からは認識されません。また `--config` を省略した場合は、既定の `~/.config/code-server/config.yaml` も自動生成されます。

```bash
~/.local/bin/code-server \
  --config ~/.config/code-server-launcher/config.yaml \
  --user-data-dir ~/.local/share/code-server-launcher/user-data \
  --extensions-dir ~/.local/share/code-server-launcher/extensions \
  --install-extension <拡張機能 ID>
```

一覧の確認には `--list-extensions`、削除には `--uninstall-extension <ID>` を使用します。インストールした拡張機能は、ブラウザー画面を再読み込みすると利用可能になります。

## 接続方法

### Linux / WSL

WSL 内部からは `http://127.0.0.1:8000/` で接続します。WSL2 の localhost 転送が有効であれば、Windows 側のブラウザーから `http://localhost:8000/` でアクセス可能です。Windows 側の `%USERPROFILE%\.wslconfig` の `[wsl2]` セクションで `localhostForwarding=false` に設定している場合は、WSL の IP アドレス (`hostname -I`) を確認し、`http://<WSL の IP>:8000/` へアクセスします。

別の PC から WSL 上の code-server へアクセスするには、WSL のネットワークを mirrored モードに設定するか、Windows 側で WSL の IP アドレスへポート転送を設定します。なお、WSL の IP アドレスは再起動によって変動する場合があります。

```powershell
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=8000 connectaddress=<WSL の IP> connectport=8000
New-NetFirewallRule -DisplayName "code-server-launcher 8000" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow
```

ポート転送設定を解除する場合は、次のコマンドを実行します。

```powershell
netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=8000
```

### Windows

同一 Windows 上のブラウザーからは `http://localhost:8000/` で接続します。既定の待受アドレスは `0.0.0.0:8000` であるため、LAN 上の他のマシンからも `http://<Windows の IP アドレス>:8000/` で接続可能です。

外部からの受信接続を許可するには、管理者権限で起動した PowerShell でポート 8000 のファイアウォール規則を追加します。ポート番号に対して指定する規則であるため、バージョン アップに伴い `node.exe` の実行パスが変更された場合でもそのまま有効に機能します。

```powershell
New-NetFirewallRule -DisplayName "code-server-launcher 8000" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow
```

初回の起動時に、Windows Defender ファイアウォールが `node.exe` の通信許可を求めるダイアログを表示することがあります。この場合は「許可」を選択してください。「キャンセル」を選択すると、該当する `node.exe` の通信を遮断するブロック規則が自動作成されます。ブロック規則は許可規則よりも優先されるため、前述のポート規則を追加していても接続できなくなります。誤ってブロックした場合は、管理者権限の PowerShell から該当のブロック規則を削除してください。

```powershell
Get-NetFirewallApplicationFilter -Program "$env:LOCALAPPDATA\code-server-launcher\code-server-4.140.0\lib\node.exe" |
  Get-NetFirewallRule | Where-Object Action -eq Block | Remove-NetFirewallRule
```

`status.ps1` は、ポートで待ち受けているプロセスを次のいずれかの区分で表示します。起動元プロセスのみが先に終了し、code-server の本体プロセスが残存した場合は、出力に表示される `taskkill` コマンドでプロセスを停止してください。

| 表示内容 | 意味 |
|---|---|
| このツールの code-server | `start.ps1` から正常に起動されたプロセス |
| このツールの node.exe。起動元のプロセスは終了済み | 本ツールの `node.exe` だが、起動元のシェル プロセスが残存していない状態 |
| 別のプロセス | 本ツール以外のプロセスがポートを使用している状態 |

インストール先のパスが長くなる環境では、Windows の長いパスのサポート (LongPathsEnabled) を有効化したうえで `install.ps1` を再実行してください。

## セキュリティに関する注意

code-server は端末のシェル実行権限を含む開発環境です。本ツールはパスワード認証を使用し、TLS 通信は行いません。待受ホストが `0.0.0.0` の状態では、ネットワーク的に接続可能な第三者からパスワード試行を受けるリスクがあります。このポートをインターネットへ直接開放することは避け、利用範囲は手元のマシンおよび信頼できる LAN 内に限定してください。インターネット経由でアクセスさせる場合は、TLS を終端するリバース プロキシの背後に配置してください。

## バージョンの更新手順

1. [code-server の Releases](https://github.com/coder/code-server/releases) から、対象バージョンの Linux amd64 および Windows amd64 の `.tar.gz` 配布物を確認する。
2. SHA-256 ハッシュ値を算出し、`version.env` のバージョン番号およびハッシュ値を更新する。
3. `uninstall` スクリプトを実行後、`install` および `start` を実行する。`--purge` または `-Purge` を指定しない限り、設定ファイル、ユーザー データ、拡張機能は保持される。
4. Windows 環境でも利用する場合は、ログイン、フォルダーを開く操作、内蔵端末、拡張機能のインストールなどの基本動作を確認する。Windows 版は上流の CI で自動テストが実施されていないため、バージョンごとに実機で動作確認を行う。

## 応用: Windows で待受を localhost に限定する

同一 Windows 上のブラウザーからのみ利用する場合は、待受アドレスをループバック アドレスに限定できます。ユーザー環境変数 `CODE_SERVER_BIND_HOST` を設定すると、以降の `start.ps1` 実行時にその設定が適用されます。環境変数の設定後に新しく開いた PowerShell から、`-Restart` を付与して再起動してください。

```powershell
[Environment]::SetEnvironmentVariable("CODE_SERVER_BIND_HOST", "127.0.0.1", "User")
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\start.ps1 -Restart
```

この設定により他のマシンからの接続は拒否されるようになり、ファイアウォールの受信許可規則も不要となります。以前に追加したポート規則は、管理者権限の PowerShell から削除できます (ただし WSL へのポート転送に同一規則を流用している場合は維持してください)。

```powershell
Remove-NetFirewallRule -DisplayName "code-server-launcher 8000"
```

既定の `0.0.0.0` に戻す場合は、環境変数を削除したうえで新しい PowerShell ウィンドウから `-Restart` を付けて起動します。

```powershell
[Environment]::SetEnvironmentVariable("CODE_SERVER_BIND_HOST", $null, "User")
```

## 応用: systemd ユーザー サービス (Linux / WSL)

ログイン セッション終了後も code-server を常駐稼働させる場合は、systemd のユーザー サービス機能を利用します。WSL 環境では `/etc/wsl.conf` に次の設定が存在し、systemd が有効化されている必要があります。

```ini
[boot]
systemd=true
```

```bash
./scripts/linux/user-service.sh enable
./scripts/linux/user-service.sh status
./scripts/linux/user-service.sh stop
./scripts/linux/user-service.sh start
./scripts/linux/user-service.sh disable
```

| 操作 | 内容 |
|---|---|
| `enable` | `~/.config/systemd/user/code-server-launcher.service` を生成し、サービスを有効化して起動する。登録済みの場合は停止後にユニット ファイルを再生成して再起動する。linger も有効化する |
| `start` | 登録済みのサービスを起動する。すでに起動中の場合は接続先を表示する |
| `stop` | サービスを停止する。自動起動の設定は維持される |
| `status` | `systemctl --user status` の出力、linger の状態、ポート待受状態を表示する。待受が存在しなければ終了コード 1 |
| `disable` | サービスを停止し、ユニット ファイルを削除する。linger 設定は維持する |

シェルによるフォアグラウンド起動とユーザー サービスは同時に使用できません。

- `enable` は、シェルから起動中の code-server が存在する場合は停止させてからサービスへ移行します。ポートを別のプロセスが使用している場合は処理を中断します。
- ユーザー サービスが登録されている間、`start.sh` は起動を行わずに案内メッセージを出力して終了します。シェル起動に戻す場合は、事前に `disable` を実行してください。
- ユーザー サービスが稼働している間、`stop.sh` からサービスを停止することはできません。サービスの停止には `user-service.sh stop` を使用します。
- `reset-password.sh` は、サービスが稼働中の場合は自動で再起動を行い、新しいパスワードを反映します。
- `uninstall.sh` は、本体ファイルの削除前に自動で `user-service.sh disable` を実行します。

`enable` は、パスワードを標準出力には出力しません。設定ファイルの内容から確認してください。待受アドレスを変更する場合は、環境変数を指定して `enable` を再実行します。ユニット ファイルの `ExecStart` 定義が更新され、サービスは新しい待受アドレスで再起動します。

```bash
CODE_SERVER_BIND_HOST=127.0.0.1 ./scripts/linux/user-service.sh enable
```

ユニット定義は `Type=simple` で構成され、ワークスペースを作業ディレクトリに設定します。起動時には `VSCODE_IPC_HOOK_CLI` と `ELECTRON_RUN_AS_NODE` を環境変数から除外し、プロセスが異常終了した場合は 3 秒後に自動再起動します (`Restart=on-failure`)。実行ログは systemd-journald に出力されます。

```bash
journalctl --user -u code-server-launcher.service -f
```

### linger の設定

linger は、ユーザー サービスとして常駐運用する場合にのみ必要な設定です。`start.sh` および `stop.sh` を使用した通常のフォアグラウンド起動・停止では使用しません。シェルから起動した code-server は、端末セッションの終了とともに停止するためです。

systemd のユーザー サービスは、既定では該当ユーザーのログイン セッションが継続している間のみ動作します。linger を有効化すると、ユーザーがログアウトした後や、システム起動後に一度も対話ログインしていない状態でも、ユーザー サービスがバックグラウンドで起動・継続します。

`enable` コマンドは、次の順序で linger の有効化を試みます。

1. `loginctl enable-linger "$USER"` を実行する。自身のユーザーに対する設定は、多くの環境において一般ユーザー権限のまま成功する
2. 失敗した場合は、`sudo -n` (対話パスワード入力を求めない sudo) で同一コマンドを実行する
3. いずれも失敗した場合は、サービス自体の登録と起動はそのまま完了させ、linger が無効である旨と手動有効化コマンドを表示する

3 の場合、サービスはユーザーのログアウトに伴って停止します。常駐を維持する必要がある場合は、管理者権限のある端末から次のコマンドを実行してください。

```bash
sudo loginctl enable-linger "$USER"
```

`disable` コマンドはサービスの登録を解除しますが、linger 設定は無効化しません。linger はユーザー アカウント単位の設定であり、他のユーザー サービスでも利用されている可能性があるためです。不要な場合は手動で次のコマンドを実行して無効化してください。

```bash
loginctl disable-linger "$USER"
```

## ライセンス

本リポジトリのコードは MIT License のもとで公開されています。code-server 本体のライセンスについては、導入された配布物に含まれる `LICENSE` ファイルを参照してください。
