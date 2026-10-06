#!/bin/bash

# code-server をこのシェルのフォアグラウンドで起動する。
# 終了は Ctrl+C、または別のシェルからの stop.sh。

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
ensure_dirs
if user_service_enabled || user_service_active; then
  echo "ユーザーサービス ${CODE_SERVER_UNIT_NAME} が有効です。"
  echo "待受は ${SCRIPT_DIR}/user-service.sh start で始めます。"
  echo "このシェルで直接起動する場合は、先に ${SCRIPT_DIR}/user-service.sh disable を実行します。"
  if user_service_active; then
    print_endpoints
    exit 0
  fi
  exit 1
fi
created_password="$(ensure_config)"
if [[ -n "${created_password}" ]]; then
  echo "設定ファイルを作成しました: ${CODE_SERVER_CONFIG_FILE}"
  echo "ログインパスワード: ${created_password}"
fi

if [[ "${restart}" -eq 1 ]]; then
  if code_server_running; then
    stop_running_code_server
  fi
elif code_server_running; then
  echo "既に起動しています。終了はそのシェルで Ctrl+C か、別のシェルから stop.sh です。"
  print_endpoints
  exit 0
elif port_is_listening; then
  die "ポート ${CODE_SERVER_PORT} は別のプロセスが使用しています。"
fi

if port_is_listening; then
  die "ポート ${CODE_SERVER_PORT} は別のプロセスが使用しています。"
fi

mapfile -t server_args < <(code_server_args)

echo "このシェルで code-server を起動します。終了は Ctrl+C です。"
print_endpoints
echo "パスワードの確認: grep '^password:' '${CODE_SERVER_CONFIG_FILE}'"
# VS Code の端末では VSCODE_IPC_HOOK_CLI があると、code-server は
# 待受を始めずに VS Code へ処理を返して終了する。
unset VSCODE_IPC_HOOK_CLI ELECTRON_RUN_AS_NODE
cd "${CODE_SERVER_WORKSPACE}"
exec "${CODE_SERVER_BIN}" "${server_args[@]}"
