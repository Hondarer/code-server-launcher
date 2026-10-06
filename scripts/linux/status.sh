#!/bin/bash

# code-server の導入状態、待受、HTTP 応答を表示する。
# パスワード自体は表示しない。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

echo "version.env: code-server ${CODE_SERVER_VERSION}"
echo "待受: ${CODE_SERVER_BIND_ADDR}"
echo "ワークスペース: ${CODE_SERVER_WORKSPACE}"

if code_server_installed; then
  echo "導入先: ${CODE_SERVER_INSTALL_DIR}"
  echo "バージョン: $("${CODE_SERVER_BIN}" --config "${CODE_SERVER_CONFIG_FILE}" --version)"
else
  echo "導入先: 未導入"
fi

if [[ -f "${CODE_SERVER_CONFIG_FILE}" ]]; then
  echo "設定: ${CODE_SERVER_CONFIG_FILE}"
  if grep -q '^password:' "${CODE_SERVER_CONFIG_FILE}"; then
    echo "パスワード: 設定ファイルの password キー"
  elif grep -q '^hashed-password:' "${CODE_SERVER_CONFIG_FILE}"; then
    echo "パスワード: hashed-password として保存されています。再設定は scripts/linux/reset-password.sh"
  else
    echo "パスワード: 設定ファイルに password がありません。"
  fi
else
  echo "設定: 未作成"
fi

mapfile -t running_pids < <(code_server_pids)
if [[ ${#running_pids[@]} -gt 0 ]]; then
  echo "プロセス: running (pid ${running_pids[*]})"
else
  echo "プロセス: stopped"
fi

if systemd_user_available; then
  if user_service_exists; then
    echo "ユーザーサービス: $(systemctl --user is-active "${CODE_SERVER_UNIT_NAME}") ($(systemctl --user is-enabled "${CODE_SERVER_UNIT_NAME}" 2>/dev/null || echo unknown))"
  else
    echo "ユーザーサービス: 未登録"
  fi
fi

if port_is_listening; then
  echo "ポート ${CODE_SERVER_PORT}: listening"
  ss -ltn "sport = :${CODE_SERVER_PORT}" || true
else
  echo "ポート ${CODE_SERVER_PORT}: closed"
fi

code="$(http_status)"
echo "HTTP http://127.0.0.1:${CODE_SERVER_PORT}/ : ${code}"

if port_is_listening; then
  exit 0
fi
exit 1
