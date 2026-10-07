#!/bin/bash

# code-server の本体とシンボリック リンクを削除する。
# ユーザー サービスが登録されている場合は、user-service.sh disable で登録を解除する。
# 設定とユーザー データは保持する。これらも削除する場合は --purge を指定する。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

purge=0
if [[ "${1:-}" == "--purge" ]]; then
  purge=1
elif [[ $# -gt 0 ]]; then
  die "使い方: $0 [--purge]"
fi

"${SCRIPT_DIR}/user-service.sh" disable
"${SCRIPT_DIR}/stop.sh"

if [[ -L "${CODE_SERVER_BIN_LINK}" ]]; then
  rm -f "${CODE_SERVER_BIN_LINK}"
fi
rm -rf "${CODE_SERVER_INSTALL_DIR}"

if [[ "${purge}" -eq 1 ]]; then
  rm -rf "${CODE_SERVER_CONFIG_DIR}" "${CODE_SERVER_DATA_DIR}" "${CODE_SERVER_CACHE_DIR}"
  rm -rf "${CODE_SERVER_SHARED_DATA_DIR}/coder-logs"
  rm -f "${CODE_SERVER_SHARED_DATA_DIR}/heartbeat"
  rmdir "${CODE_SERVER_SHARED_DATA_DIR}" 2>/dev/null || true
  echo "本体、設定、ユーザー データ、拡張機能、ダウンロード キャッシュ、code-server のログを削除しました。"
else
  echo "本体を削除しました。設定とユーザー データは保持しています。"
  echo "完全に削除する場合: ${SCRIPT_DIR}/uninstall.sh --purge"
fi
