#!/bin/bash

# code-server の standalone 版をユーザー領域へ導入し、待受設定を作る。
# プロセスは起動しない。起動は start.sh が行う。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

require_cmd curl tar sha256sum python3 openssl
[[ "$(uname -m)" == "x86_64" ]] || die "このツールが検証している Linux アーキテクチャは x86_64 です (現在: $(uname -m))。"

ensure_dirs

if code_server_installed; then
  echo "導入済みです: ${CODE_SERVER_INSTALL_DIR}"
else
  if code_server_running; then
    die "code-server が動作中です。入れ直す前に scripts/linux/stop.sh を実行してください。"
  fi
  download_release
  extract_release
  echo "展開しました: ${CODE_SERVER_INSTALL_DIR}"
fi

ln -sfn "${CODE_SERVER_BIN}" "${CODE_SERVER_BIN_LINK}"

created_password="$(ensure_config)"
if [[ -n "${created_password}" ]]; then
  echo "設定ファイルを作成しました: ${CODE_SERVER_CONFIG_FILE}"
  echo "ログインパスワード: ${created_password}"
else
  echo "既存の設定を使います: ${CODE_SERVER_CONFIG_FILE}"
  echo "待受アドレスを ${CODE_SERVER_BIND_ADDR} に合わせました。"
fi

echo "導入が完了しました。"
echo "起動: ${SCRIPT_DIR}/start.sh"
echo "バージョン: $("${CODE_SERVER_BIN}" --config "${CODE_SERVER_CONFIG_FILE}" --version)"
