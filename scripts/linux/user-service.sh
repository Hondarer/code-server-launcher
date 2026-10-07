#!/bin/bash

# 応用: code-server を systemd のユーザー サービスとして常駐させる。
# 既定の起動方法は start.sh。ログアウト後も待受を維持する場合に本スクリプトを使用する。
# シェル起動とユーザー サービスは同時には使用しない。
# ユニットの登録 (enable) と削除 (disable) は本スクリプトのみが行う。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

CODE_SERVER_UNIT_DIR="${HOME}/.config/systemd/user"
CODE_SERVER_UNIT_FILE="${CODE_SERVER_UNIT_DIR}/${CODE_SERVER_UNIT_NAME}"

usage() {
  cat <<EOF
使い方: $0 enable|start|stop|status|disable

  enable   ユニットを登録して起動する。登録済みの場合は再生成して再起動する。linger も有効化する
  start    登録済みのユーザー サービスを起動する
  stop     ユーザー サービスを停止する。自動起動の設定は維持される
  status   ユーザー サービスの状態を表示する
  disable  ユーザー サービスを停止し、ユニットを削除する
EOF
}

require_systemd_user() {
  if ! systemd_user_available; then
    die "systemd のユーザー セッションが利用できません。WSL では /etc/wsl.conf に [boot] systemd=true の設定が必要です。"
  fi
}

# ExecStart= の引数を systemd の書式に従ってエスケープする。% は指定子、$ は環境変数展開として解釈されるためエスケープする。
quote_systemd_arg() {
  python3 - "$1" <<'PY'
import sys

arg = sys.argv[1].replace("%", "%%").replace("$", "$$")
if arg and all(c.isalnum() or c in "/._-+:=,@" for c in arg):
    print(arg)
else:
    print('"' + arg.replace("\\", "\\\\").replace('"', '\\"') + '"')
PY
}

write_user_unit() {
  local args_quoted="" arg
  mkdir -p "${CODE_SERVER_UNIT_DIR}"
  args_quoted="$(quote_systemd_arg "${CODE_SERVER_BIN}")"
  while IFS= read -r arg; do
    args_quoted+=" $(quote_systemd_arg "${arg}")"
  done < <(code_server_args)
  # WorkingDirectory= は引用符を解釈しないため、パスをそのまま記述する。
  cat > "${CODE_SERVER_UNIT_FILE}" <<EOF
[Unit]
Description=code-server-launcher (code-server ${CODE_SERVER_BIND_ADDR})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${CODE_SERVER_WORKSPACE//%/%%}
ExecStart=${args_quoted}
UnsetEnvironment=VSCODE_IPC_HOOK_CLI ELECTRON_RUN_AS_NODE
Restart=on-failure
RestartSec=3
KillMode=control-group

[Install]
WantedBy=default.target
EOF
}

enable_linger() {
  if loginctl enable-linger "${USER}" >/dev/null 2>&1 \
    || sudo -n loginctl enable-linger "${USER}" >/dev/null 2>&1; then
    echo "linger を有効化しました。ログアウト後もユーザー サービスは継続して稼働します。"
    return 0
  fi
  echo "linger は有効化されていません。ログアウトするとユーザー サービスは停止します。"
  echo "有効化コマンド: loginctl enable-linger ${USER}"
}

wait_until_listening() {
  local i
  for i in $(seq 1 40); do
    if port_is_listening; then
      return 0
    fi
    sleep 0.5
  done
  return 1
}

cmd_enable() {
  require_cmd python3 systemctl ss
  require_systemd_user
  require_installed
  require_workspace
  ensure_config >/dev/null
  if code_server_running && ! user_service_active; then
    echo "シェルから起動中の code-server を停止し、ユーザー サービスへ切り替えます。"
    stop_running_code_server
  fi
  if user_service_active; then
    # 待受アドレスが変更された場合に備え、既存プロセスを停止してからポート状態を確認する。
    systemctl --user stop "${CODE_SERVER_UNIT_NAME}"
  fi
  if port_is_listening; then
    die "ポート ${CODE_SERVER_PORT} は別のプロセスが使用しています。"
  fi
  write_user_unit
  systemctl --user daemon-reload
  systemctl --user enable "${CODE_SERVER_UNIT_NAME}"
  systemctl --user start "${CODE_SERVER_UNIT_NAME}"
  enable_linger
  if ! wait_until_listening; then
    echo "code-server が待受を開始しませんでした。" >&2
    systemctl --user status "${CODE_SERVER_UNIT_NAME}" --no-pager >&2 || true
    journalctl --user -u "${CODE_SERVER_UNIT_NAME}" -n 40 --no-pager >&2 || true
    exit 1
  fi
  echo "ユーザー サービス ${CODE_SERVER_UNIT_NAME} を起動しました。"
  print_endpoints
  echo "ログ: journalctl --user -u ${CODE_SERVER_UNIT_NAME} -f"
  echo "パスワードの確認: grep '^password:' '${CODE_SERVER_CONFIG_FILE}'"
}

cmd_start() {
  require_cmd ss
  require_systemd_user
  if ! user_service_exists; then
    die "ユーザー サービスは未登録です。先に $0 enable を実行してください。"
  fi
  if user_service_active; then
    echo "ユーザー サービスは起動しています。"
    print_endpoints
    return 0
  fi
  if port_is_listening; then
    die "ポート ${CODE_SERVER_PORT} は別のプロセスが使用しています。"
  fi
  systemctl --user start "${CODE_SERVER_UNIT_NAME}"
  if ! wait_until_listening; then
    echo "code-server が待受を開始しませんでした。" >&2
    journalctl --user -u "${CODE_SERVER_UNIT_NAME}" -n 40 --no-pager >&2 || true
    exit 1
  fi
  echo "ユーザー サービスを起動しました。"
  print_endpoints
}

cmd_stop() {
  require_systemd_user
  if ! user_service_exists; then
    echo "ユーザー サービスは未登録です。"
    return 0
  fi
  systemctl --user stop "${CODE_SERVER_UNIT_NAME}"
  echo "ユーザー サービスを停止しました。自動起動の設定は保持されています。"
}

cmd_status() {
  if ! systemd_user_available; then
    echo "systemd のユーザー セッションが利用できません。"
    exit 1
  fi
  if ! user_service_exists; then
    echo "ユーザー サービス: 未登録"
    exit 1
  fi
  systemctl --user status "${CODE_SERVER_UNIT_NAME}" --no-pager || true
  echo "linger: $(loginctl show-user "${USER}" -p Linger --value 2>/dev/null || echo unknown)"
  if port_is_listening; then
    echo "ポート ${CODE_SERVER_PORT}: listening"
    exit 0
  fi
  echo "ポート ${CODE_SERVER_PORT}: closed"
  exit 1
}

# ユーザー サービスを停止してユニット ファイルを削除する。未登録の場合は何もしない。
# systemd が利用できない状態でも、ユニット ファイルが存在する場合は削除する。
cmd_disable() {
  local wants="${CODE_SERVER_UNIT_DIR}/default.target.wants/${CODE_SERVER_UNIT_NAME}"
  local removed=0 linger
  if [[ -f "${CODE_SERVER_UNIT_FILE}" || -L "${wants}" ]]; then
    removed=1
  fi
  if user_service_exists; then
    systemctl --user disable --now "${CODE_SERVER_UNIT_NAME}" >/dev/null 2>&1 || true
    systemctl --user reset-failed "${CODE_SERVER_UNIT_NAME}" >/dev/null 2>&1 || true
    removed=1
  fi
  rm -f "${CODE_SERVER_UNIT_FILE}" "${wants}"
  if [[ "${removed}" -eq 0 ]]; then
    echo "ユーザー サービスは未登録です。"
    return 0
  fi
  if systemd_user_available; then
    systemctl --user daemon-reload >/dev/null 2>&1 || true
  fi
  echo "ユーザー サービス ${CODE_SERVER_UNIT_NAME} を無効化し、ユニット ファイルを削除しました。"
  linger="$(loginctl show-user "${USER}" -p Linger --value 2>/dev/null || true)"
  if [[ "${linger}" == "yes" ]]; then
    echo "linger は有効のまま保持されています。無効化する場合は次のコマンドを実行してください: loginctl disable-linger ${USER}"
  fi
}

action="${1:-}"
case "${action}" in
  enable) cmd_enable ;;
  start) cmd_start ;;
  stop) cmd_stop ;;
  status) cmd_status ;;
  disable) cmd_disable ;;
  -h|--help|help|"") usage ;;
  *)
    usage >&2
    die "不明な操作です: ${action}"
    ;;
esac
