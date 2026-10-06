#!/bin/bash

# ログインパスワードを生成し直す。
# シェル起動中ならそのプロセスを止める。ユーザーサービスなら再起動して反映する。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

require_cmd python3
password="$(reset_password_in_config)"

if user_service_active; then
  systemctl --user restart "${CODE_SERVER_UNIT_NAME}"
  echo "ユーザーサービスを再起動し、新しいパスワードを反映しました。"
elif code_server_running; then
  stop_running_code_server
  echo "起動中のプロセスを停止しました。新しいパスワードは、次の start.sh から反映されます。"
  echo "起動: ${SCRIPT_DIR}/start.sh"
fi

echo "新しいログインパスワード: ${password}"
echo "設定: ${CODE_SERVER_CONFIG_FILE}"
