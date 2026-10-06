#!/bin/bash

# シェルから起動した code-server を停止する。
# ユーザーサービスが待受を担当している場合は、そちらを停止しない。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

if user_service_active; then
  echo "ユーザーサービス ${CODE_SERVER_UNIT_NAME} が待受を担当しています。"
  echo "停止は ${SCRIPT_DIR}/user-service.sh stop です。"
  exit 1
fi

stop_running_code_server
