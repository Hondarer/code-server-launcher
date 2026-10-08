#!/bin/bash

# code-server の配布アーカイブを packages/ へ事前に取得する。
# 取得したアーカイブがあれば、install.sh はネットワークに接続せずに導入する。
# --all を指定すると、Windows 版のアーカイブも取得する。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  echo "使い方: $0 [--all]"
  echo "  --all  Linux 版に加えて Windows 版のアーカイブも取得する"
}

include_windows=0
for arg in "$@"; do
  case "${arg}" in
    --all) include_windows=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

require_cmd curl sha256sum
[[ -n "${CODE_SERVER_LINUX_AMD64_SHA256:-}" ]] || die "CODE_SERVER_LINUX_AMD64_SHA256 が version.env に定義されていません。"

mkdir -p "${CODE_SERVER_PACKAGES_DIR}"
fetch_verified "${CODE_SERVER_ASSET_URL}" "${CODE_SERVER_PACKAGES_DIR}/${CODE_SERVER_ASSET}" "${CODE_SERVER_LINUX_AMD64_SHA256}"

if [[ "${include_windows}" -eq 1 ]]; then
  [[ -n "${CODE_SERVER_WINDOWS_AMD64_SHA256:-}" ]] || die "CODE_SERVER_WINDOWS_AMD64_SHA256 が version.env に定義されていません。"
  fetch_verified "${CODE_SERVER_WINDOWS_ASSET_URL}" "${CODE_SERVER_PACKAGES_DIR}/${CODE_SERVER_WINDOWS_ASSET}" "${CODE_SERVER_WINDOWS_AMD64_SHA256}"
fi

echo "取得が完了しました: ${CODE_SERVER_PACKAGES_DIR}"
echo "packages/ を含むリポジトリ一式をオフライン環境へ持ち込み、install スクリプトを実行してください。"
