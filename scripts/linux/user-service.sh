#!/bin/bash

# 応用: code-server を systemd のユーザーサービスとして常駐させる。
# 既定の起動方法は start.sh。ログアウト後も待受を残す場合にこちらを使う。
# シェル起動とユーザーサービスを同時には使わない。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  cat <<EOF
使い方: $0 enable|start|stop|status|disable

  enable   ユニットを登録し、今すぐ起動する。linger も有効にする
  start    登録済みのユーザーサービスを起動する
  stop     ユーザーサービスを停止する。自動起動の設定は残る
  status   ユーザーサービスの状態を表示する
  disable  ユーザーサービスを停止し、ユニットを削除する
EOF
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
  require_cmd python3 systemctl
  require_systemd_user
  require_installed
  require_workspace
  ensure_dirs
  ensure_config >/dev/null
  if code_server_running && ! user_service_active; then
    stop_running_code_server
  fi
  if port_is_listening && ! user_service_active; then
    die "ポート ${CODE_SERVER_PORT} は別のプロセスが使用しています。"
  fi
  write_user_unit
  systemctl --user daemon-reload
  systemctl --user enable --now "${CODE_SERVER_UNIT_NAME}"
  enable_linger
  if ! wait_until_listening; then
    echo "code-server が待受を始めませんでした。" >&2
    systemctl --user status "${CODE_SERVER_UNIT_NAME}" --no-pager >&2 || true
    journalctl --user -u "${CODE_SERVER_UNIT_NAME}" -n 40 --no-pager >&2 || true
    exit 1
  fi
  echo "ユーザーサービス ${CODE_SERVER_UNIT_NAME} を起動しました。"
  print_endpoints
  echo "ログ: journalctl --user -u ${CODE_SERVER_UNIT_NAME} -f"
  echo "パスワードの確認: grep '^password:' '${CODE_SERVER_CONFIG_FILE}'"
}

cmd_start() {
  require_systemd_user
  if ! user_service_exists; then
    die "ユーザーサービスは未登録です。先に $0 enable を実行してください。"
  fi
  systemctl --user start "${CODE_SERVER_UNIT_NAME}"
  if ! wait_until_listening; then
    echo "code-server が待受を始めませんでした。" >&2
    journalctl --user -u "${CODE_SERVER_UNIT_NAME}" -n 40 --no-pager >&2 || true
    exit 1
  fi
  echo "ユーザーサービスを起動しました。"
  print_endpoints
}

cmd_stop() {
  require_systemd_user
  if ! user_service_exists; then
    echo "ユーザーサービスは未登録です。"
    return 0
  fi
  systemctl --user stop "${CODE_SERVER_UNIT_NAME}"
  echo "ユーザーサービスを停止しました。自動起動の設定は残っています。"
}

cmd_status() {
  if ! systemd_user_available; then
    echo "systemd のユーザーセッションが使えません。"
    exit 1
  fi
  if ! user_service_exists; then
    echo "ユーザーサービス: 未登録"
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

cmd_disable() {
  disable_user_service
  linger="$(loginctl show-user "${USER}" -p Linger --value 2>/dev/null || true)"
  if [[ "${linger}" == "yes" ]]; then
    echo "linger は有効なままです。不要なら次で無効にします: loginctl disable-linger ${USER}"
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
