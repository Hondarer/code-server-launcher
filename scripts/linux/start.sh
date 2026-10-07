#!/bin/bash

# code-server をこのシェルのフォアグラウンドで起動する。
# 終了は Ctrl+C、または別のシェルからの stop.sh で行う。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

restart=0
if [[ "${1:-}" == "--restart" ]]; then
  restart=1
elif [[ $# -gt 0 ]]; then
  die "使い方: $0 [--restart]"
fi

require_cmd python3 ss
require_installed
require_workspace

# シェル起動とユーザー サービスは同時には使用しない。サービスの操作は user-service.sh で行う。
if user_service_active; then
  echo "ユーザー サービス ${CODE_SERVER_UNIT_NAME} が稼働しています。このシェルでは起動しません。"
  echo "停止する場合は ${SCRIPT_DIR}/user-service.sh stop、シェル起動に戻す場合は ${SCRIPT_DIR}/user-service.sh disable を実行してください。"
  print_endpoints
  # --restart はサービスを再起動しないため、その場合は失敗として終了する。
  exit "${restart}"
fi
if user_service_enabled; then
  echo "ユーザー サービス ${CODE_SERVER_UNIT_NAME} が登録されています (停止中)。"
  echo "サービスとして起動する場合は ${SCRIPT_DIR}/user-service.sh start を実行してください。"
  echo "このシェルで起動する場合は、事前に ${SCRIPT_DIR}/user-service.sh disable を実行してください。"
  exit 1
fi

created_password="$(ensure_config)"
if [[ -n "${created_password}" ]]; then
  echo "設定ファイルを作成しました: ${CODE_SERVER_CONFIG_FILE}"
  echo "ログイン パスワード: ${created_password}"
fi

if code_server_running; then
  if [[ "${restart}" -eq 0 ]]; then
    echo "すでに起動しています。終了する場合はこのシェルで Ctrl+C を押すか、別のシェルから stop.sh を実行してください。"
    print_endpoints
    exit 0
  fi
  stop_running_code_server
fi
if port_is_listening; then
  die "ポート ${CODE_SERVER_PORT} は別のプロセスが使用しています。"
fi

mapfile -t server_args < <(code_server_args)

echo "このシェルで code-server を起動します。終了は Ctrl+C です。"
print_endpoints
echo "パスワードの確認: grep '^password:' '${CODE_SERVER_CONFIG_FILE}'"
# VS Code の端末環境では VSCODE_IPC_HOOK_CLI が存在すると、code-server が
# 待受を開始せずに VS Code へ処理を戻して終了する。
unset VSCODE_IPC_HOOK_CLI ELECTRON_RUN_AS_NODE
cd "${CODE_SERVER_WORKSPACE}"
exec "${CODE_SERVER_BIN}" "${server_args[@]}"
