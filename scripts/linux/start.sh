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

# シェル起動とユーザーサービスは同時に使わない。サービスの操作は user-service.sh に任せる。
if user_service_active; then
  echo "ユーザーサービス ${CODE_SERVER_UNIT_NAME} が待受を担当しています。このシェルでは起動しません。"
  echo "停止は ${SCRIPT_DIR}/user-service.sh stop、シェル起動へ戻す場合は ${SCRIPT_DIR}/user-service.sh disable です。"
  print_endpoints
  # --restart はサービスを再起動しないので、その場合は失敗として返す。
  exit "${restart}"
fi
if user_service_enabled; then
  echo "ユーザーサービス ${CODE_SERVER_UNIT_NAME} が登録されています (停止中)。"
  echo "サービスとして起動する場合は ${SCRIPT_DIR}/user-service.sh start です。"
  echo "このシェルで起動する場合は、先に ${SCRIPT_DIR}/user-service.sh disable を実行します。"
  exit 1
fi

created_password="$(ensure_config)"
if [[ -n "${created_password}" ]]; then
  echo "設定ファイルを作成しました: ${CODE_SERVER_CONFIG_FILE}"
  echo "ログインパスワード: ${created_password}"
fi

if code_server_running; then
  if [[ "${restart}" -eq 0 ]]; then
    echo "既に起動しています。終了はそのシェルで Ctrl+C か、別のシェルから stop.sh です。"
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
# VS Code の端末では VSCODE_IPC_HOOK_CLI があると、code-server は
# 待受を始めずに VS Code へ処理を返して終了する。
unset VSCODE_IPC_HOOK_CLI ELECTRON_RUN_AS_NODE
cd "${CODE_SERVER_WORKSPACE}"
exec "${CODE_SERVER_BIN}" "${server_args[@]}"
