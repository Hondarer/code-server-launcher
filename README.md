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

ワークスペースの初期値はこのリポジトリです。変更する場合は起動前に `CODE_SERVER_WORKSPACE` を指定します。

## 前提

Linux / WSL:

- x86_64
- `curl`、`tar`、`sha256sum`、`python3`、`openssl`、`ss`

Windows:

- amd64
- Windows PowerShell 5.1
- `curl.exe` と `tar.exe`（Windows 10 以降の標準添付）
- スクリプト内の日本語は UTF-8 BOM で保存してある

起動は、ユーザーがシェルで `start` スクリプトを実行する方法です。code-server はその端末のフォアグラウンドで動き、Ctrl+C か別の端末からの `stop` で終わります。このリポジトリの動作確認環境は WSL2 上の Oracle Linux 8 です。

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
./scripts/linux/uninstall.sh --purge   # 設定、ユーザーデータ、キャッシュも削除
```

`stop.sh` は、このサンプルの設定ファイルで動いているプロセスを止めます。端末を閉じた場合も、そのシェルで動いていた code-server は終了します。

配置先:

| 用途 | パス |
|---|---|
| 本体 | `~/.local/lib/code-server-4.140.0` |
| コマンド | `~/.local/bin/code-server` |
| 設定 | `~/.config/study-code-server/config.yaml` |
| ユーザーデータ | `~/.local/share/study-code-server/user-data` |
| 拡張機能 | `~/.local/share/study-code-server/extensions` |
| 配布アーカイブ | `~/.cache/study-code-server/` |

ログは `start.sh` を実行した端末に出ます。

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

PowerShell で、このリポジトリをカレントにして実行します。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\install.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\start.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\status.ps1
```

`start.ps1` はこのウィンドウのフォアグラウンドで code-server を動かします。終了は Ctrl+C です。起動し直す場合は `-Restart` を付けます。VS Code の端末から実行しても code-server 自身が待受を始めるよう、起動時に `VSCODE_IPC_HOOK_CLI` を外します。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\start.ps1 -Restart
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\stop.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\reset-password.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\uninstall.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\uninstall.ps1 -Purge
```

接続先は `http://127.0.0.1:8000/` です。同じ Windows 上のブラウザからは `http://localhost:8000/` でも開けます。配布物に同梱された `node.exe` を使うため、別途 Node.js は使いません。以前の手順でログオンタスク `study-code-server` を登録している場合、`uninstall.ps1` がそれを削除します。

配置先:

| 用途 | パス |
|---|---|
| 本体 | `%LOCALAPPDATA%\study-code-server\code-server-4.140.0` |
| 設定 | `%USERPROFILE%\.config\study-code-server\config.yaml` |
| ユーザーデータ | `%LOCALAPPDATA%\study-code-server\user-data` |
| 拡張機能 | `%LOCALAPPDATA%\study-code-server\extensions` |
| 配布アーカイブ | `%LOCALAPPDATA%\study-code-server\cache\` |

ログは `start.ps1` を実行したウィンドウに出ます。LAN 上の他のマシンからも Windows 版へ接続する場合は、TCP 8000 の受信を許可するファイアウォール規則を追加します。

展開先のパスが長くなる環境では、Windows の長いパスのサポートを有効にしてから `install.ps1` を再実行します。

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

`127.0.0.1` にすると、待受は各 OS のループバックに限られます。WSL で Windows 側の localhost 転送を使う場合も、多くの環境では `127.0.0.1` のままで届きます。LAN や WSL の仮想 NIC からも届ける場合は `0.0.0.0` のままにします。ユーザーサービスを使っている場合は、同じ環境変数を付けて `user-service.sh enable` を再実行します。

## セキュリティ

code-server はターミナルを含む開発環境です。このサンプルはパスワード認証をコマンドラインから指定し、TLS は使いません。待受が `0.0.0.0` の間は、到達できるネットワークからパスワードを試せます。インターネットへこのポートを転送せず、利用範囲は手元のマシンと信頼できる LAN に留めます。外向きに出す場合は、TLS を終端するリバースプロキシの背後に置きます。

## 版を上げる

1. [code-server の Releases](https://github.com/coder/code-server/releases) から Linux amd64 と Windows amd64 の `.tar.gz` を選ぶ。
2. SHA-256 を計算し、`version.env` の版とハッシュを更新する。
3. `uninstall` のあと `install` と `start` を実行する。`--purge` / `-Purge` を付けない限り、設定とユーザーデータは残る。

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
