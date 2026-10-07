# study-code-server

[code-server](https://github.com/coder/code-server) を、Linux (WSL を含む) と Windows のユーザー領域へ導入し、ポート 8000 で動かすためのスクリプト集です。導入する版は `version.env` で固定し、配布アーカイブの SHA-256 を照合してから展開します。導入と、コマンドによる起動・停止に管理者権限は要りません。Linux でユーザーサービスにする場合だけ、linger の有効化に権限が要ることがあります (「応用: systemd ユーザーサービス」を参照)。

| 項目 | 値 |
|---|---|
| code-server | 4.140.0 (Code 1.140.0) |
| 待受 | `0.0.0.0:8000` |
| 認証 | パスワード (`auth: password`) |
| TLS | 使わない (`cert: false`) |
| 対象 | Linux x86_64、Windows amd64 |
| 動作確認環境 | WSL2 上の Oracle Linux 8、Windows 11 Pro for Workstations (PowerShell 5.1) |

起動の基本は、シェルで `start` スクリプトを実行する方法です。code-server はその端末のフォアグラウンドで動き、Ctrl+C で終わります。Linux では、ログアウト後も動かし続けるための systemd ユーザーサービスを応用として用意しています。

## 構成

```text
study-code-server/
├── version.env                  # 版、待受の既定値、配布アーカイブの SHA-256
├── config/config.yaml.example   # 設定ファイルのひな型 (起動には使わない)
└── scripts/
    ├── lib/common.sh            # Linux スクリプトの共通処理
    ├── linux/
    │   ├── install.sh           # 導入と設定ファイルの作成
    │   ├── start.sh             # フォアグラウンドで起動
    │   ├── stop.sh              # 別の端末から停止
    │   ├── status.sh            # 状態の表示
    │   ├── reset-password.sh    # パスワードの再生成
    │   ├── uninstall.sh         # 削除
    │   └── user-service.sh      # 応用: systemd ユーザーサービス
    └── windows/
        ├── common.ps1           # Windows スクリプトの共通処理
        ├── install.ps1
        ├── start.ps1
        ├── stop.ps1
        ├── status.ps1
        ├── reset-password.ps1
        └── uninstall.ps1
```

ポート 8000 は、Linux 側と Windows 側のどちらか一方で使います。

## 前提

Linux / WSL:

- x86_64 (`install.sh` が `uname -m` で確かめる)
- `curl`、`tar`、`sha256sum`、`python3`、`openssl`、`ss`
- ユーザーサービスを使う場合だけ、systemd のユーザーセッション (`systemctl --user`) と、linger を有効にするための `loginctl`

Windows:

- amd64 (`install.ps1` と `start.ps1` が確かめる)
- Windows PowerShell 5.1
- `curl.exe` と `tar.exe` (Windows 10 以降の標準添付)
- スクリプトは UTF-8 (BOM 付き)、改行は CRLF で保存してある

code-server の公式ドキュメントは Windows を配布対象として案内していませんが、リリースには `windows-amd64` の配布物が含まれています。Windows 版のスクリプトはそれを使います。

## はじめかた

Linux / WSL:

```bash
./scripts/linux/install.sh
./scripts/linux/start.sh
```

Windows (このリポジトリをカレントにした PowerShell):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\install.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\start.ps1
```

`install` は初回だけ、ログインパスワードを生成して表示します。ブラウザで `http://localhost:8000/` を開き、そのパスワードでログインします。

## スクリプト

### Linux / WSL

| スクリプト | 動作 |
|---|---|
| `install.sh` | 配布アーカイブを `~/.cache/study-code-server/` へ取得し、SHA-256 を照合して `~/.local/lib/code-server-<版>` へ展開する。照合済みのアーカイブがあれば再取得しない。`~/.local/bin/code-server` にリンクを張り、設定ファイルを用意する。code-server は起動しない |
| `start.sh [--restart]` | このシェルを code-server に置き換えて、フォアグラウンドで動かす。ログはその端末に出る |
| `stop.sh` | 起動中の code-server に TERM を送り、5 秒で終わらなければ KILL する |
| `status.sh` | 版、待受、ワークスペース、導入先、設定、プロセス、ユーザーサービス、ポート、HTTP 応答を表示する。パスワードは表示しない。待受が無ければ終了コード 1 |
| `reset-password.sh` | パスワードを生成し直して表示する |
| `uninstall.sh [--purge]` | 本体を削除する。`--purge` で設定とデータも削除する |
| `user-service.sh <操作>` | 応用。systemd ユーザーサービスの登録、起動、停止、状態表示、削除 |

### Windows

| スクリプト | 動作 |
|---|---|
| `install.ps1` | 配布アーカイブを `%LOCALAPPDATA%\study-code-server\cache\` へ取得し、SHA-256 を照合して `%LOCALAPPDATA%\study-code-server\code-server-<版>` へ展開する。設定ファイルを用意する。code-server は起動しない |
| `start.ps1 [-Restart]` | このウィンドウのフォアグラウンドで、同梱の `node.exe` から code-server を動かす。ログはそのウィンドウに出る |
| `stop.ps1` | 起動中の code-server のプロセスツリーを `taskkill /T /F` で強制終了する |
| `status.ps1` | `status.sh` と同じ項目 (ユーザーサービスを除く) に加え、ポートで待ち受けているプロセスの PID と、それがこのサンプルのものかを表示する。待受が無ければ終了コード 1 |
| `reset-password.ps1` | パスワードを生成し直して表示する |
| `uninstall.ps1 [-Purge]` | 本体を削除する。`-Purge` で設定とデータも削除する |

Windows には常駐の仕組み (サービス、ログオンタスク) はありません。以前の手順で登録したログオンタスク `study-code-server` が残っていれば、`uninstall.ps1` が削除します。

## 起動と停止

`start` は、起動の前に次を確かめます。

1. code-server が導入済みであること、ワークスペースのフォルダがあること
2. (Linux) ユーザーサービスが動いていないこと。動いていれば、このシェルでは起動せず接続先を表示して終わる (終了コード 0、`--restart` 付きなら 1)。登録済みで停止中なら、`user-service.sh start` か `disable` を案内して終了コード 1 で終わる
3. 設定ファイルがあること。無ければパスワード付きで作り、そのパスワードを表示する。あれば `bind-addr` を今回の待受に合わせる
4. このサンプルの code-server がすでに動いていないこと。動いていれば接続先を表示して終わる。`--restart` / `-Restart` 付きなら、止めてから起動し直す
5. ポートを別のプロセスが使っていないこと

起動時には `VSCODE_IPC_HOOK_CLI` と `ELECTRON_RUN_AS_NODE` を外します。VS Code の端末では、これらがあると code-server が待受を始めずに VS Code 側へ処理を返して終わるためです。

code-server には次の引数を渡します。

```text
--config <設定ファイル>
--bind-addr <待受ホスト>:<ポート>
--auth password
--ignore-last-opened
--user-data-dir <ユーザーデータ>
--extensions-dir <拡張機能>
<ワークスペース>
```

停止は、起動した端末で Ctrl+C を押すのが基本です。code-server は終了処理をしてから止まります。端末を閉じた場合も終わります。別の端末から止める場合は `stop` を使います。

- Linux の `stop.sh` は TERM を送り、5 秒たっても残っていれば KILL します。ユーザーサービスが動いているあいだは止めず、`user-service.sh stop` を案内して終了コード 1 で終わります。
- Windows の `stop.ps1` は強制終了です。Windows には外のプロセスへ穏やかな終了を送る手段が乏しいためです。`start.ps1 -Restart`、`reset-password.ps1`、`uninstall.ps1` も、起動中ならこの方法で止めます。

`stop` が止めるのは、このサンプルの設定ファイルを `--config` で指定しているプロセスだけです。同じマシンの別の code-server には触れません。

## 設定値と環境変数

`version.env` に既定値があり、Linux と Windows のスクリプトの両方が読みます。

| キー | 既定値 | 用途 |
|---|---|---|
| `CODE_SERVER_VERSION` | `4.140.0` | 導入する版 |
| `CODE_SERVER_PORT` | `8000` | 待受ポート |
| `CODE_SERVER_BIND_HOST` | `0.0.0.0` | 待受アドレス |
| `CODE_SERVER_LINUX_AMD64_SHA256` | (ハッシュ) | Linux 版アーカイブの SHA-256 |
| `CODE_SERVER_WINDOWS_AMD64_SHA256` | (ハッシュ) | Windows 版アーカイブの SHA-256 |

次の環境変数があれば、`version.env` より優先します。

| 環境変数 | 用途 |
|---|---|
| `CODE_SERVER_PORT` | 待受ポート |
| `CODE_SERVER_BIND_HOST` | 待受アドレス |
| `CODE_SERVER_WORKSPACE` | 起動時に開くフォルダ。既定はこのリポジトリ |

`start` は設定ファイルの `bind-addr` を、そのときの待受へ書き換えます。

```bash
CODE_SERVER_BIND_HOST=127.0.0.1 ./scripts/linux/start.sh --restart
```

```powershell
$env:CODE_SERVER_BIND_HOST = "127.0.0.1"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\start.ps1 -Restart
```

`127.0.0.1` にすると、待受はその OS のループバックに限られます。

### ワークスペース

ワークスペース (起動時に開くフォルダ) の既定はこのリポジトリです。`install` にフォルダを指定するオプションはありません。変える場合は、起動の前に `CODE_SERVER_WORKSPACE` を指定します。

```bash
CODE_SERVER_WORKSPACE="$HOME/work/my-project" ./scripts/linux/start.sh --restart
```

```powershell
$env:CODE_SERVER_WORKSPACE = "D:\work\my-project"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\start.ps1 -Restart
# リポジトリを開く既定値に戻す
Remove-Item Env:CODE_SERVER_WORKSPACE
```

`--ignore-last-opened` を付けているので、前回開いたフォルダより、起動時の指定が優先されます。ただし、ブラウザの URL に `?folder=...` や `?workspace=...` が付いている場合は、URL の指定が優先されます。その場合は `http://localhost:8000/` を開き直します。

## パスワード

設定ファイル (`config.yaml`) は次の内容で作られます。パスワードは 48 桁の 16 進数です。

```yaml
bind-addr: 0.0.0.0:8000
auth: password
password: <生成したパスワード>
cert: false
disable-telemetry: true
disable-update-check: true
```

ファイルの権限は、Linux では `600` (ディレクトリは `700`)、Windows では継承を切って現在のユーザーだけに絞ります。パスワードは次で確かめます。

```bash
grep '^password:' ~/.config/study-code-server/config.yaml
```

```powershell
Select-String -Path "$env:USERPROFILE\.config\study-code-server\config.yaml" -Pattern '^password:'
```

`reset-password` は、新しいパスワードを生成して表示します。上の 6 つのキーを書き直し、`hashed-password` があれば取り除きます。ほかの行はそのまま残します。

- code-server がシェルで起動中なら、そのプロセスを止めます。続けて `start` を実行すると、新しいパスワードが使われます。
- (Linux) ユーザーサービスが動いていれば、サービスを再起動して反映します。

`status` は、パスワードが `password` キーと `hashed-password` キーのどちらで保存されているかだけを表示します。

## 永続化データ

### 配置先

Linux / WSL:

| 用途 | パス | `uninstall.sh` | `--purge` |
|---|---|---|---|
| 本体 | `~/.local/lib/code-server-4.140.0/` | 削除 | 削除 |
| コマンド | `~/.local/bin/code-server` (本体へのリンク) | 削除 | 削除 |
| 設定 | `~/.config/study-code-server/config.yaml` | 残す | 削除 |
| ユーザーデータ | `~/.local/share/study-code-server/user-data/` | 残す | 削除 |
| 拡張機能 | `~/.local/share/study-code-server/extensions/` | 残す | 削除 |
| 配布アーカイブ | `~/.cache/study-code-server/` | 残す | 削除 |
| code-server 自身のログ | `~/.local/share/code-server/` の `coder-logs/` と `heartbeat` | 残す | この 2 つだけ削除 |
| 以前の版の作業領域 | `~/.local/state/study-code-server/` | 残す | 削除 |

`$XDG_DATA_HOME` を設定している場合、code-server 自身のログは `$XDG_DATA_HOME/code-server/` にあります。

Windows:

| 用途 | パス | `uninstall.ps1` | `-Purge` |
|---|---|---|---|
| 本体 | `%LOCALAPPDATA%\study-code-server\code-server-4.140.0\` | 削除 | 削除 |
| 設定 | `%USERPROFILE%\.config\study-code-server\config.yaml` | 残す | 削除 |
| ユーザーデータ | `%LOCALAPPDATA%\study-code-server\user-data\` | 残す | 削除 |
| 拡張機能 | `%LOCALAPPDATA%\study-code-server\extensions\` | 残す | 削除 |
| 配布アーカイブ | `%LOCALAPPDATA%\study-code-server\cache\` | 残す | 削除 |
| code-server 自身のログ | `%LOCALAPPDATA%\code-server\Data\` の `coder-logs\` と `heartbeat` | 残す | この 2 つだけ削除 |
| 以前の版の作業領域 | `%LOCALAPPDATA%\study-code-server\state\` | 残す | 削除 |

フォルダ名を `code-server` ではなく `study-code-server` にしているのは、code-server の既定の置き場所と分けるためです。Linux の `~/.config/code-server/config.yaml` と `~/.local/share/code-server/` は、`--config` を付けずに起動した code-server が読み書きします。同じマシンの VS Code や、既定の場所を使う別の code-server とは、設定も拡張機能も共有しません。

### 中身

| パス | 中身 |
|---|---|
| `extensions/` | インストールした拡張機能の本体と、その一覧の `extensions.json` |
| `user-data/User/settings.json` | ユーザー設定 |
| `user-data/User/keybindings.json`、`snippets/` | キーバインドとスニペット。作ったときにできる |
| `user-data/User/globalStorage/` | 拡張機能が保存するデータ |
| `user-data/User/workspaceStorage/` | ワークスペースごとの状態 |
| `user-data/User/History/` | エディターのローカル履歴 |
| `user-data/Machine/` | このマシンだけに効く設定 |
| `user-data/logs/` | 起動ごとのログ。起動日時の名前のフォルダが増えていく |
| `user-data/CachedProfilesData/` など | キャッシュ。消しても作り直される |

ワークスペースの `.vscode/settings.json` は、ワークスペースのフォルダ側に保存されます。

code-server は `--user-data-dir` の指定と関係なく、既定の置き場所 (表の「code-server 自身のログ」) に `coder-logs` (標準出力と標準エラーの写し) と `heartbeat` (最終アクセスの印) を書きます。ここはほかの code-server と共有することがあるため、`--purge` / `-Purge` はこの 2 つだけを消し、フォルダは空になった場合だけ消します。

### よくある操作

`user-data/` や `extensions/` を消したりコピーしたりする前に、code-server を止めます。

| したいこと | 方法 |
|---|---|
| 設定と拡張機能をバックアップする | `user-data/User/` と `extensions/` をコピーする。拡張機能はネイティブ部品を含むことがあるので、同じ OS の間で持ち運ぶ |
| 設定を初期状態に戻す | `user-data/` を消す。拡張機能は残る |
| 拡張機能をすべて外す | `extensions/` を消す |
| ログを片付ける | `user-data/logs/` の古いフォルダと、code-server 自身の `coder-logs/` を消す |

拡張機能は画面の拡張機能ビューから入れます。コマンドラインから入れる場合は、`--config`、`--user-data-dir`、`--extensions-dir` を付けます。付けないと、既定の `~/.local/share/code-server/extensions` に入ってしまい、このサンプルの code-server からは見えません。`--config` を省くと、既定の `~/.config/code-server/config.yaml` も作られます。

```bash
~/.local/bin/code-server \
  --config ~/.config/study-code-server/config.yaml \
  --user-data-dir ~/.local/share/study-code-server/user-data \
  --extensions-dir ~/.local/share/study-code-server/extensions \
  --install-extension <拡張機能 ID>
```

`--list-extensions` で一覧、`--uninstall-extension <ID>` で削除です。入れた拡張機能は、開いている画面を再読み込みすると使えます。

## 接続

### Linux / WSL

WSL の中からは `http://127.0.0.1:8000/` です。WSL2 の localhost 転送が有効なら、Windows のブラウザから `http://localhost:8000/` で開けます。Windows 側の `%USERPROFILE%\.wslconfig` の `[wsl2]` で `localhostForwarding=false` にしている場合は、WSL の IP アドレス (`hostname -I`) を使って `http://<WSL の IP>:8000/` を開きます。

別の PC から WSL 上の code-server へ届けるには、WSL のネットワークを mirrored モードにするか、Windows 側で WSL の IP へポートを転送します。WSL の IP は再起動で変わることがあります。

```powershell
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=8000 connectaddress=<WSL の IP> connectport=8000
New-NetFirewallRule -DisplayName "study-code-server 8000" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow
```

転送を外す場合は `netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=8000` です。

### Windows

同じ Windows のブラウザからは `http://localhost:8000/` です。既定の待受は `0.0.0.0:8000` なので、LAN 上の他のマシンからも `http://<Windows の IP アドレス>:8000/` で接続できます。

受信を通すには、管理者として開いた PowerShell でポート 8000 の規則を追加します。ポートで指定する規則なので、版を上げて `node.exe` のパスが変わってもそのまま効きます。

```powershell
New-NetFirewallRule -DisplayName "study-code-server 8000" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow
```

初回の起動で、Windows Defender ファイアウォールが `node.exe` の通信を許可するか尋ねることがあります。ここは「許可」を選びます。「キャンセル」を選ぶと、その `node.exe` の受信を止めるブロック規則が作られます。ブロック規則は許可規則より優先されるため、上のポート規則があっても接続できなくなります。その場合は、同じユーザーで管理者として開いた PowerShell からブロック規則を消します。

```powershell
Get-NetFirewallApplicationFilter -Program "$env:LOCALAPPDATA\study-code-server\code-server-4.140.0\lib\node.exe" |
  Get-NetFirewallRule | Where-Object Action -eq Block | Remove-NetFirewallRule
```

`status.ps1` は、ポートで待ち受けているプロセスを次のどれかとして表示します。起動元のプロセスだけが先に終わって code-server の本体が残った場合は、表示された `taskkill` のコマンドで止めます。

| 表示 | 意味 |
|---|---|
| このサンプルの code-server | `start.ps1` で起動したもの |
| このサンプルの node.exe。起動元のプロセスは終了済み | このサンプルの `node.exe` だが、起動元が残っていない |
| 別のプロセス | このサンプル以外のプロセスがポートを使っている |

展開先のパスが長くなる環境では、Windows の長いパスのサポートを有効にしてから `install.ps1` を再実行します。

## セキュリティ

code-server はターミナルを含む開発環境です。このサンプルはパスワード認証を使い、TLS は使いません。待受が `0.0.0.0` のあいだは、届くネットワークからパスワードを試せます。インターネットへこのポートを転送せず、利用範囲は手元のマシンと信頼できる LAN に留めます。外へ出す場合は、TLS を終端するリバースプロキシの背後に置きます。

## 版を上げる

1. [code-server の Releases](https://github.com/coder/code-server/releases) から、Linux amd64 と Windows amd64 の `.tar.gz` を選ぶ。
2. SHA-256 を計算し、`version.env` の版とハッシュを書き換える。
3. `uninstall` のあと `install` と `start` を実行する。`--purge` / `-Purge` を付けない限り、設定、ユーザーデータ、拡張機能は残る。
4. Windows でも使う場合は、ログイン、フォルダを開く、ターミナル、拡張機能の導入を一通り試す。Windows 版は上流の CI で自動テストされていないため、版ごとに手元で確かめておく。

## 応用: Windows で待受を localhost に限定する

同じ Windows のブラウザからだけ使う場合は、待受をループバックに限定できます。ユーザー環境変数 `CODE_SERVER_BIND_HOST` を設定すると、以後の `start.ps1` はそれを使います。設定後に開いた PowerShell で、`-Restart` を付けて起動し直します。

```powershell
[Environment]::SetEnvironmentVariable("CODE_SERVER_BIND_HOST", "127.0.0.1", "User")
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\start.ps1 -Restart
```

他のマシンからは接続できなくなり、ファイアウォールの許可も要りません。ポート規則を追加していた場合は、管理者の PowerShell で外せます。ただし、WSL へのポート転送に同じ規則を使っている場合は残します。

```powershell
Remove-NetFirewallRule -DisplayName "study-code-server 8000"
```

既定の `0.0.0.0` へ戻す場合は、環境変数を消してから、新しい PowerShell で `-Restart` を付けて起動します。

```powershell
[Environment]::SetEnvironmentVariable("CODE_SERVER_BIND_HOST", $null, "User")
```

## 応用: systemd ユーザーサービス (Linux / WSL)

ログアウトしても待受を残す場合は、systemd のユーザーサービスを使います。WSL では `/etc/wsl.conf` に次があり、systemd が動いている必要があります。

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
| `enable` | `~/.config/systemd/user/study-code-server.service` を書き、有効化して起動する。登録済みなら、止めてからユニットを書き直して起動し直す。linger も有効にする |
| `start` | 登録済みのサービスを起動する。すでに動いていれば接続先を表示する |
| `stop` | サービスを停止する。自動起動の設定は残る |
| `status` | `systemctl --user status`、linger、ポートを表示する。待受が無ければ終了コード 1 |
| `disable` | サービスを停止し、ユニットを削除する。linger は残す |

シェル起動とユーザーサービスは同時に使いません。

- `enable` は、シェルで起動している code-server があれば止めてからサービスへ切り替えます。ポートを別のプロセスが使っていれば失敗します。
- サービスが登録されているあいだ、`start.sh` は起動せずに案内を出して終わります。シェル起動へ戻す場合は、先に `disable` を実行します。
- サービスが動いているあいだ、`stop.sh` はサービスを止めません。停止は `user-service.sh stop` です。
- `reset-password.sh` は、サービスが動いていれば再起動して新しいパスワードを反映します。
- `uninstall.sh` は、本体を消す前に `user-service.sh disable` を呼びます。

`enable` は、パスワードを標準出力へは出しません。設定ファイルで確かめます。待受アドレスを変える場合は、環境変数を付けて `enable` を再実行します。ユニットの `ExecStart` がそのときの待受で書き換わり、サービスは新しい待受で起動し直します。

```bash
CODE_SERVER_BIND_HOST=127.0.0.1 ./scripts/linux/user-service.sh enable
```

ユニットは `Type=simple` で、ワークスペースを作業ディレクトリにします。`VSCODE_IPC_HOOK_CLI` と `ELECTRON_RUN_AS_NODE` を外して起動し、異常終了したときは 3 秒後に再起動します (`Restart=on-failure`)。ログは journal に出ます。

```bash
journalctl --user -u study-code-server.service -f
```

### linger

linger は、ユーザーサービスにする場合にだけ必要な設定です。`start.sh` と `stop.sh` による起動・停止では使いません。シェル起動の code-server は、その端末とともに終わるためです。

ユーザーサービスは、既定ではそのユーザーのログインセッションが続くあいだだけ動きます。linger を有効にすると、ログアウトしても、また OS の起動後にログインしなくても、ユーザーサービスが動きます。

`enable` は、linger を次の順に有効にしようとします。

1. `loginctl enable-linger "$USER"` を実行する。自分のユーザーに対しては、多くの環境で一般ユーザーのまま通る
2. 通らなければ、`sudo -n` (パスワードを尋ねない sudo) で同じコマンドを実行する
3. どちらも通らなければ、サービスはそのまま登録して起動し、linger が無効であることと、手で有効にするコマンドを表示する

3 の場合、サービスはログアウトすると止まります。必要なら、権限のある端末で次を実行します。

```bash
sudo loginctl enable-linger "$USER"
```

`disable` はサービスを外しますが、linger は消しません。linger はユーザー単位の設定で、ほかのユーザーサービスも使っていることがあるためです。不要なら次を実行します。

```bash
loginctl disable-linger "$USER"
```

## ライセンス

このリポジトリは MIT License です。code-server 本体のライセンスは、導入した配布物に含まれる `LICENSE` に従います。
