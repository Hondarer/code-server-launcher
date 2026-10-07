#!/bin/bash

# シェルから起動した code-server を停止する。
# ユーザー サービスが待受を行っている場合は停止しない。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

if user_service_active; then
  echo "ユーザー サービス ${CODE_SERVER_UNIT_NAME} が待受を行っています。"
  echo "停止する場合は ${SCRIPT_DIR}/user-service.sh stop を実行してください。"
  exit 1
fi

stop_running_code_server
