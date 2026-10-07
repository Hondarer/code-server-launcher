# study-code-server

Linux (WSL) と Windows で [code-server](https://github.com/coder/code-server) をポート 8000 でホストするための手順とスクリプトです。導入する版は `version.env` で固定し、配布アーカイブの SHA-256 を検証してからユーザー領域へ展開します。

待受は `0.0.0.0:8000`、認証はパスワード、通信は HTTP です。手元のブラウザと、信頼できるネットワークからの利用を想定しています。

## 構成

```
study-code-server/
├── version.env                     # 版、ポート、SHA-256
├── config/config.yaml.example      # 設定のひな型
└── scripts/
    ├── lib/common.sh
    ├── linux/                      # Linux と WSL。user-service.sh は応用
    └── windows/                    # Windows amd64
```

ポート 8000 は、Linux 側か Windows 側のどちらか一方で使います。

| 項目 | 値 |
|---|---|
| code-server | 4.140.0（Code 1.140.0） |
| 待受 | `0.0.0.0:8000` |
| 認証 | `password` |
| TLS | 無効 (`cert: false`) |
| 対象 | Linux x86_64、Windows amd64 |

ワークスペース（起動時に開くフォルダ）の初期値はこのリポジトリです。`install.ps1` / `install.sh` にフォルダ指定オプションはありません。変更する場合は、`install` 時ではなく起動前に `CODE_SERVER_WORKSPACE` を指定します。OS のホームディレクトリや本体の配置先は変更しません。

```powershell
$env:CODE_SERVER_WORKSPACE = "D:\work\my-project"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\start.ps1 -Restart
# リポジトリを開く既定値に戻す
Remove-Item Env:CODE_SERVER_WORKSPACE
```

```bash
CODE_SERVER_WORKSPACE="$HOME/work/my-project" ./scripts/linux/start.sh --restart
```

両OSとも `--ignore-last-opened` を付け、前回開いたフォルダより起動時の指定を優先します。既存のブラウザURLに `?folder=...` / `?workspace=...` が付いている場合は、そのURLの指定が優先されるため、`http://localhost:8000/` を開き直してください。Linux / WSL では `http://127.0.0.1:8000/` を開き直してください。

## 前提

Linux / WSL:

- x86_64
- `curl`、`tar`、`sha256sum`、`python3`、`openssl`、`ss`

Windows:

- amd64
- Windows PowerShell 5.1
- `curl.exe` と `tar.exe`（Windows 10 以降の標準添付）
- スクリプト内の日本語は UTF-8 BOM で保存してある

起動は、ユーザーがシェルで `start` スクリプトを実行する方法です。code-server はその端末のフォアグラウンドで動き、Ctrl+C か別の端末からの `stop` で終わります。このリポジトリの動作確認環境は WSL2 上の Oracle Linux 8 と Windows 11 Pro for Workstations（PowerShell 5.1）です。

## Linux / WSL

```bash
./scripts/linux/install.sh
./scripts/linux/start.sh
./scripts/linux/status.sh
```

`install.sh` は初回だけ、ログインパスワードを標準出力と設定ファイルへ書きます。`start.sh` はこのシェルを code-server に置き換えます。ログはその端末に出ます。すでに同じ設定で起動している場合は、何もせず接続先を表示して戻ります。起動し直す場合は `./scripts/linux/start.sh --restart` です。VS Code の端末から実行しても code-server 自身が待受を始めるよう、起動時に `VSCODE_IPC_HOOK_CLI` を外します。

`start.sh` はシェル起動だけを行います。ユーザーサービス `study-code-server.service` が有効なあいだは、二重起動を避けて終了します。登録と解除は「応用: systemd ユーザーサービス」です。`uninstall.sh` は、登録済みのユーザーサービスがあれば `user-service.sh disable` で無効化してユニットを削除します。

```bash
./scripts/linux/stop.sh
./scripts/linux/reset-password.sh
./scripts/linux/uninstall.sh           # 本体を削除し、設定は残す
./scripts/linux/uninstall.sh --purge   # 設定、ユーザーデータ、拡張機能、キャッシュも削除
```

`stop.sh` は、このサンプルの設定ファイルで動いているプロセスを止めます。端末を閉じた場合も、そのシェルで動いていた code-server は終了します。

配置先:

| 用途 | パス | `uninstall.sh` | `--purge` |
|---|---|---|---|
| 本体 | `~/.local/lib/code-server-4.140.0` | 削除 | 削除 |
| コマンド | `~/.local/bin/code-server` | 削除 | 削除 |
| 設定 | `~/.config/study-code-server/config.yaml` | 残す | 削除 |
| ユーザーデータ | `~/.local/share/study-code-server/user-data/` | 残す | 削除 |
| 拡張機能 | `~/.local/share/study-code-server/extensions/` | 残す | 削除 |
| 配布アーカイブ | `~/.cache/study-code-server/` | 残す | 削除 |
| code-server 自身のログ | `~/.local/share/code-server/` の `coder-logs/` と `heartbeat` | 残す | この 2 つだけ削除 |

`$XDG_DATA_HOME` を設定している場合、最後の行は `$XDG_DATA_HOME/code-server/` です。各ディレクトリの中身は「[永続化データ](#永続化データ)」にまとめています。

ログは `start.sh` を実行した端末に出ます。同じ内容はファイルにも残ります。

### Windows のブラウザから WSL へ接続する

WSL2 の localhost 転送が有効なら、Windows のブラウザで次を開きます。

```text
http://localhost:8000/
```

WSL の中からは `http://127.0.0.1:8000/` です。`/etc/wsl.conf` で `localhostForwarding=false` になっている場合は、WSL の IP アドレス（`hostname -I`）に対して `http://<WSL の IP>:8000/` を開きます。

別の PC から WSL 上の code-server へ届けるには、WSL のネットワークが mirrored モードであるか、Windows 側で WSL の IP へポート転送します。WSL の IP は再起動で変わることがあります。

```powershell
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=8000 connectaddress=<WSL の IP> connectport=8000
New-NetFirewallRule -DisplayName "study-code-server 8000" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow
```

転送を外す場合は `netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=8000` です。

## Windows

code-server の公式ドキュメントは Windows を配布対象として案内していませんが、リリースには `windows-amd64` の配布物が含まれています。このサンプルはそれを使います。

PowerShell で、このリポジトリをカレントにして実行します。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\install.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\start.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\status.ps1
```

`start.ps1` はこのウィンドウのフォアグラウンドで code-server を動かします。終了は Ctrl+C です。code-server は終了処理をしてから止まります。起動し直す場合は `-Restart` を付けます。VS Code の端末から実行しても code-server 自身が待受を始めるよう、起動時に `VSCODE_IPC_HOOK_CLI` を外します。

`stop.ps1` は、別のウィンドウから止めるためのものです。Windows には外のプロセスへ穏やかな終了を送る手段が乏しいため、プロセスツリーを強制終了します。`-Restart`、`reset-password.ps1`、`uninstall.ps1` も、起動中ならこの方法で止めます。ふだんは Ctrl+C で止めます。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\start.ps1 -Restart
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\stop.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\reset-password.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\uninstall.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\uninstall.ps1 -Purge
```

接続先は `http://127.0.0.1:8000/` です。同じ Windows 上のブラウザからは `http://localhost:8000/` でも開けます。配布物に同梱された `node.exe` を使うため、別途 Node.js は使いません。以前の手順でログオンタスク `study-code-server` を登録している場合、`uninstall.ps1` がそれを削除します。

`status.ps1` は、ポートで待ち受けているプロセスの PID も表示します。このサンプル以外のプロセスがポートを使っている場合や、起動元のプロセスだけが先に終わって code-server の本体が残った場合に、どれを止めればよいか分かります。

配置先:

| 用途 | パス | `uninstall.ps1` | `-Purge` |
|---|---|---|---|
| 本体 | `%LOCALAPPDATA%\study-code-server\code-server-4.140.0` | 削除 | 削除 |
| 設定 | `%USERPROFILE%\.config\study-code-server\config.yaml` | 残す | 削除 |
| ユーザーデータ | `%LOCALAPPDATA%\study-code-server\user-data\` | 残す | 削除 |
| 拡張機能 | `%LOCALAPPDATA%\study-code-server\extensions\` | 残す | 削除 |
| 配布アーカイブ | `%LOCALAPPDATA%\study-code-server\cache\` | 残す | 削除 |
| code-server 自身のログ | `%LOCALAPPDATA%\code-server\Data\` の `coder-logs\` と `heartbeat` | 残す | この 2 つだけ削除 |

ログは `start.ps1` を実行したウィンドウに出ます。同じ内容はファイルにも残ります。

展開先のパスが長くなる環境では、Windows の長いパスのサポートを有効にしてから `install.ps1` を再実行します。

### 他のマシンから接続する

既定の待受は `0.0.0.0:8000` で、LAN 上の他のマシンから接続できます。他のマシンのブラウザでは `http://<Windows の IP アドレス>:8000/` を開きます。

受信を通すには、管理者として開いた PowerShell でポート 8000 の規則を追加します。ポートで指定する規則なので、版を上げて `node.exe` のパスが変わってもそのまま効きます。

```powershell
New-NetFirewallRule -DisplayName "study-code-server 8000" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow
```

初回の起動で、Windows Defender ファイアウォールが `node.exe` の通信を許可するか尋ねることがあります。ここは「許可」を選びます。「キャンセル」を選ぶと、その `node.exe` の受信を止めるブロック規則が作られます。ブロック規則は許可規則より優先されるため、上のポート規則があっても接続できなくなります。その場合は、同じユーザーで管理者として開いた PowerShell からブロック規則を消します。

```powershell
Get-NetFirewallApplicationFilter -Program "$env:LOCALAPPDATA\study-code-server\code-server-4.140.0\lib\node.exe" |
  Get-NetFirewallRule | Where-Object Action -eq Block | Remove-NetFirewallRule
```

同じ Windows のブラウザからだけ使う場合は、「応用: Windows で待受を localhost に限定する」の設定にします。

## 永続化データ

code-server が使い続けるデータは、OS ごとに次の場所にあります。以下の説明では、この基点からの相対パスで書きます。

| 基点 | Linux / WSL | Windows |
|---|---|---|
| データ | `~/.local/share/study-code-server/` | `%LOCALAPPDATA%\study-code-server\` |
| 設定 | `~/.config/study-code-server/` | `%USERPROFILE%\.config\study-code-server\` |

起動時に `--user-data-dir` と `--extensions-dir` を指定しています。そのため、同じマシンの VS Code や、既定の場所を使う別の code-server とは、設定も拡張機能も共有しません。フォルダ名を `code-server` ではなく `study-code-server` にしているのも同じ理由です。Linux の `~/.config/code-server/config.yaml` と `~/.local/share/code-server/` は code-server の既定の置き場所で、`--config` を付けずに起動した code-server が読み書きします。

| パス | 中身 |
|---|---|
| `extensions/` | インストールした拡張機能の本体と、その一覧の `extensions.json` |
| `user-data/User/settings.json` | ユーザー設定。画面の「設定」で変えた内容 |
| `user-data/User/keybindings.json`、`snippets/` | キーバインドとスニペット。作ったときにできる |
| `user-data/User/globalStorage/` | 拡張機能が保存するデータ |
| `user-data/User/workspaceStorage/` | ワークスペースごとの状態。開いていたタブなど |
| `user-data/User/History/` | エディターのローカル履歴 |
| `user-data/Machine/` | このマシンだけに効く設定 |
| `user-data/logs/` | 起動ごとのログ。起動日時の名前のフォルダが増えていく |
| `user-data/CachedProfilesData/` など | キャッシュ。消しても作り直される |
| `config.yaml`(設定側) | 待受、認証方式、パスワード |

ワークスペースの `.vscode/settings.json` は、ワークスペースのフォルダ側に保存されます。

code-server は、上の指定とは関係なく、次の場所にも書きます。

| 場所 | 中身 |
|---|---|
| Linux: `~/.local/share/code-server/`<br>Windows: `%LOCALAPPDATA%\code-server\Data\` | `coder-logs/` に code-server 本体の標準出力と標準エラーの写し、`heartbeat` に最終アクセスの印 |

この場所は code-server の既定の置き場所で、ほかの code-server と共有することがあります。そのため `--purge` / `-Purge` は、`coder-logs` と `heartbeat` だけを消します。フォルダは空になった場合だけ消します。

### よくある操作

`user-data/` や `extensions/` を消したりコピーしたりする前に、`stop` で code-server を止めます。

| したいこと | 方法 |
|---|---|
| 設定と拡張機能をバックアップする | `user-data/User/` と `extensions/` をコピーする。拡張機能はネイティブ部品を含むことがあるので、同じ OS の間で持ち運ぶ |
| 設定を初期状態に戻す | `user-data/` を消す。拡張機能は残る |
| 拡張機能をすべて外す | `extensions/` を消す |
| ログを片付ける | `user-data/logs/` の古いフォルダと、code-server 自身の `coder-logs/` を消す |

拡張機能は画面の拡張機能ビューから入れます。コマンドラインで入れる場合は、`--extensions-dir` と `--config` を必ず付けます。付けないと、拡張機能は既定の `~/.local/share/code-server/extensions` に入ってしまい、このサンプルの code-server からは見えません。`--config` を省くと、既定の `~/.config/code-server/config.yaml` も作られます。

```bash
~/.local/bin/code-server \
  --config ~/.config/study-code-server/config.yaml \
  --user-data-dir ~/.local/share/study-code-server/user-data \
  --extensions-dir ~/.local/share/study-code-server/extensions \
  --install-extension <拡張機能 ID>
```

`--list-extensions` で一覧、`--uninstall-extension <ID>` で削除です。入れた拡張機能は、起動中の画面を再読み込みすると使えます。

## パスワード

初回の `install` が表示したパスワードは、設定ファイルの `password` にあります。

```bash
grep '^password:' ~/.config/study-code-server/config.yaml
```

```powershell
Select-String -Path "$env:USERPROFILE\.config\study-code-server\config.yaml" -Pattern '^password:'
```

設定ファイルの権限は、Linux では `600`、Windows では現在のユーザーだけに絞ります。作り直す場合は `reset-password` を実行します。シェルで起動している場合、そのプロセスはそこで停止するので、続けて `start` を実行すると新しいパスワードが使われます。ユーザーサービスで起動している場合は、そのサービスを再起動して反映します。

## 待受の変更

`version.env` の `CODE_SERVER_PORT` と `CODE_SERVER_BIND_HOST` が初期値です。起動時に同名の環境変数があれば、そちらを使います。`start` は設定ファイルの `bind-addr` をその値へ更新します。

```bash
CODE_SERVER_BIND_HOST=127.0.0.1 ./scripts/linux/start.sh --restart
```

```powershell
$env:CODE_SERVER_BIND_HOST = "127.0.0.1"
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\start.ps1 -Restart
```

`127.0.0.1` にすると、待受は各 OS のループバックに限られます。WSL で Windows 側の localhost 転送を使う場合も、多くの環境では `127.0.0.1` のままで届きます。LAN や WSL の仮想 NIC からも届ける場合は `0.0.0.0` のままにします。ユーザーサービスを使っている場合は、同じ環境変数を付けて `user-service.sh enable` を再実行します。Windows で毎回 `127.0.0.1` にする方法は「応用: Windows で待受を localhost に限定する」です。

## セキュリティ

code-server はターミナルを含む開発環境です。このサンプルはパスワード認証をコマンドラインから指定し、TLS は使いません。待受が `0.0.0.0` の間は、到達できるネットワークからパスワードを試せます。インターネットへこのポートを転送せず、利用範囲は手元のマシンと信頼できる LAN に留めます。外向きに出す場合は、TLS を終端するリバースプロキシの背後に置きます。

## 版を上げる

1. [code-server の Releases](https://github.com/coder/code-server/releases) から Linux amd64 と Windows amd64 の `.tar.gz` を選ぶ。
2. SHA-256 を計算し、`version.env` の版とハッシュを更新する。
3. `uninstall` のあと `install` と `start` を実行する。`--purge` / `-Purge` を付けない限り、設定、ユーザーデータ、拡張機能は残る。拡張機能は新しい版でも、そのまま読み込まれる。
4. Windows でも使う場合は、ログイン、フォルダを開く、ターミナル、拡張機能の導入を一通り試す。Windows 版は上流の CI で自動テストされていないため、版ごとに手元で確かめておく。

## 応用: Windows で待受を localhost に限定する

同じ Windows のブラウザからだけ使う場合は、待受をループバックに限定できます。ユーザー環境変数 `CODE_SERVER_BIND_HOST` を設定すると、以後の `start.ps1` はそれを使います。設定後に開いた PowerShell で `-Restart` を付けて起動し直します。

```powershell
[Environment]::SetEnvironmentVariable("CODE_SERVER_BIND_HOST", "127.0.0.1", "User")
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\start.ps1 -Restart
```

ループバックだけで待ち受けるので、他のマシンからは接続できません。ファイアウォールの許可も要りません。ポート規則を追加していた場合は、管理者の PowerShell で外せます。ただし、WSL へのポート転送に同じ規則を使っている場合は残します。

```powershell
Remove-NetFirewallRule -DisplayName "study-code-server 8000"
```

既定の `0.0.0.0` へ戻す場合は、環境変数を消してから、新しい PowerShell で `-Restart` を付けて起動します。

```powershell
[Environment]::SetEnvironmentVariable("CODE_SERVER_BIND_HOST", $null, "User")
```

## 応用: systemd ユーザーサービス

既定の起動は `./scripts/linux/start.sh` です。ログアウトしても待受を残す場合に、Linux と WSL では systemd のユーザーサービスを使います。Windows の手順にはこの常駐方法はありません。

WSL では `/etc/wsl.conf` に次があり、systemd が動いている必要があります。

```ini
[boot]
systemd=true
```

シェル起動とユーザーサービスは同時に使いません。サービスが有効なあいだ、`start.sh` は二重起動を避けて終了します。シェル起動へ戻す場合は、先に `disable` を実行します。

```bash
./scripts/linux/user-service.sh enable
./scripts/linux/user-service.sh status
./scripts/linux/user-service.sh stop
./scripts/linux/user-service.sh start
./scripts/linux/user-service.sh disable
```

| 操作 | 内容 |
|---|---|
| `enable` | `~/.config/systemd/user/study-code-server.service` を書き、有効化して起動する。登録済みならユニットを書き直して再起動する。linger も有効にする |
| `start` | 登録済みのサービスを起動する |
| `stop` | サービスを停止する。自動起動の設定は残る |
| `status` | `systemctl --user status`、linger、ポートを表示する |
| `disable` | サービスを停止し、ユニットを削除する。linger は残す |

`enable` は、このサンプルの設定でフォアグラウンド起動しているプロセスがあれば止めてからサービスを始めます。ポートを別のプロセスが使っている場合は失敗します。初回のパスワードは標準出力へは出さず、設定ファイルにあります。

linger を有効にすると、ログアウト後もユーザーサービスが残ります。`disable` は linger を消しません。不要なら次を実行します。

```bash
loginctl disable-linger "$USER"
```

ログは次で追います。

```bash
journalctl --user -u study-code-server.service -f
```

ユニットは `Type=simple` です。起動時に `VSCODE_IPC_HOOK_CLI` と `ELECTRON_RUN_AS_NODE` を外します。異常終了時は `Restart=on-failure` で再起動します。サービスが動いているあいだ、`stop.sh` はそのプロセスを止めません。停止は `user-service.sh stop` です。

待受アドレスを変える場合は、環境変数を付けて `enable` を再実行します。ユニットの `ExecStart` がそのときの待受で書き換わり、サービスは新しい待受で起動し直します。

```bash
CODE_SERVER_BIND_HOST=127.0.0.1 ./scripts/linux/user-service.sh enable
```

パスワードを作り直す場合も `./scripts/linux/reset-password.sh` です。サービスが動いていれば、その場で再起動して新しいパスワードを反映します。

`uninstall.sh` は本体を消す前に `user-service.sh disable` を呼び、登録済みのユーザーサービスを無効化してユニットを削除します。linger は残します。

## ライセンス

このリポジトリは MIT License です。code-server 本体のライセンスは、導入した配布物に含まれる `LICENSE` に従います。
