#!/bin/bash

# study-code-server の Linux / WSL スクリプト共通処理。
# 各スクリプトから source する。直接は実行しない。

if [[ -z "${STUDY_CODE_SERVER_ROOT:-}" ]]; then
  _lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  STUDY_CODE_SERVER_ROOT="$(cd "${_lib_dir}/../.." && pwd)"
fi

_saved_port="${CODE_SERVER_PORT:-}"
_saved_host="${CODE_SERVER_BIND_HOST:-}"
_saved_workspace="${CODE_SERVER_WORKSPACE:-}"

# shellcheck disable=SC1091
source "${STUDY_CODE_SERVER_ROOT}/version.env"

if [[ -n "${_saved_port}" ]]; then
  CODE_SERVER_PORT="${_saved_port}"
fi
if [[ -n "${_saved_host}" ]]; then
  CODE_SERVER_BIND_HOST="${_saved_host}"
fi
if [[ -n "${_saved_workspace}" ]]; then
  CODE_SERVER_WORKSPACE="${_saved_workspace}"
else
  CODE_SERVER_WORKSPACE="${STUDY_CODE_SERVER_ROOT}"
fi
unset _saved_port _saved_host _saved_workspace

CODE_SERVER_BIND_ADDR="${CODE_SERVER_BIND_HOST}:${CODE_SERVER_PORT}"
CODE_SERVER_INSTALL_DIR="${HOME}/.local/lib/code-server-${CODE_SERVER_VERSION}"
CODE_SERVER_BIN_DIR="${CODE_SERVER_INSTALL_DIR}/bin"
CODE_SERVER_BIN="${CODE_SERVER_BIN_DIR}/code-server"
CODE_SERVER_BIN_LINK="${HOME}/.local/bin/code-server"
CODE_SERVER_CONFIG_DIR="${HOME}/.config/study-code-server"
CODE_SERVER_CONFIG_FILE="${CODE_SERVER_CONFIG_DIR}/config.yaml"
CODE_SERVER_DATA_DIR="${HOME}/.local/share/study-code-server"
CODE_SERVER_USER_DATA_DIR="${CODE_SERVER_DATA_DIR}/user-data"
CODE_SERVER_EXTENSIONS_DIR="${CODE_SERVER_DATA_DIR}/extensions"
# 以前の版がバックグラウンド起動の PID とログを置いていた場所。現在は uninstall.sh --purge が消すだけ。
CODE_SERVER_STATE_DIR="${HOME}/.local/state/study-code-server"
CODE_SERVER_CACHE_DIR="${HOME}/.cache/study-code-server"
# code-server が --user-data-dir と無関係に使う既定のデータ置き場。coder-logs と heartbeat を書く。
# ほかの code-server と共有するので、このサンプルは自分が書くものだけを消す。
CODE_SERVER_SHARED_DATA_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/code-server"
CODE_SERVER_UNIT_NAME="study-code-server.service"
CODE_SERVER_ASSET="code-server-${CODE_SERVER_VERSION}-linux-amd64.tar.gz"
CODE_SERVER_ASSET_URL="https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/${CODE_SERVER_ASSET}"

die() {
  echo "Error: $*" >&2
  exit 1
}

require_cmd() {
  local cmd
  for cmd in "$@"; do
    command -v "${cmd}" >/dev/null 2>&1 || die "コマンドが見つかりません: ${cmd}"
  done
}

ensure_dirs() {
  mkdir -p \
    "${HOME}/.local/bin" \
    "${CODE_SERVER_CONFIG_DIR}" \
    "${CODE_SERVER_USER_DATA_DIR}" \
    "${CODE_SERVER_EXTENSIONS_DIR}" \
    "${CODE_SERVER_CACHE_DIR}"
  chmod 700 "${CODE_SERVER_CONFIG_DIR}"
}

code_server_installed() {
  [[ -x "${CODE_SERVER_BIN}" && -x "${CODE_SERVER_INSTALL_DIR}/lib/node" ]]
}

require_installed() {
  if ! code_server_installed; then
    die "code-server が未導入です。先に scripts/linux/install.sh を実行してください。"
  fi
}

require_workspace() {
  [[ -d "${CODE_SERVER_WORKSPACE}" ]] || die "ワークスペースがありません: ${CODE_SERVER_WORKSPACE}"
}

# 設定ファイルが無ければパスワード付きで作成し、そのパスワードを標準出力へ出す。
# 既存ファイルでは bind-addr だけを現在の待受アドレスへ合わせ、パスワードは維持する。
ensure_config() {
  ensure_dirs
  python3 - "${CODE_SERVER_CONFIG_FILE}" "${CODE_SERVER_BIND_ADDR}" <<'PY'
import pathlib
import secrets
import sys

path, bind = sys.argv[1], sys.argv[2]
file = pathlib.Path(path)
if not file.exists():
    password = secrets.token_hex(24)
    file.write_text(
        "\n".join(
            [
                f"bind-addr: {bind}",
                "auth: password",
                f"password: {password}",
                "cert: false",
                "disable-telemetry: true",
                "disable-update-check: true",
                "",
            ]
        )
    )
    file.chmod(0o600)
    print(password)
    raise SystemExit(0)

lines = file.read_text().splitlines()
found = False
out = []
for line in lines:
    if line.startswith("bind-addr:"):
        out.append(f"bind-addr: {bind}")
        found = True
    else:
        out.append(line)
if not found:
    out.insert(0, f"bind-addr: {bind}")
file.write_text("\n".join(out).rstrip() + "\n")
file.chmod(0o600)
PY
}

# 新しい平文パスワードを設定し、hashed-password があれば取り除く。
# 新しいパスワードだけを標準出力へ出す。
reset_password_in_config() {
  ensure_dirs
  python3 - "${CODE_SERVER_CONFIG_FILE}" "${CODE_SERVER_BIND_ADDR}" <<'PY'
import pathlib
import secrets
import sys

path, bind = sys.argv[1], sys.argv[2]
file = pathlib.Path(path)
password = secrets.token_hex(24)
lines = file.read_text().splitlines() if file.exists() else []
rendered = {
    "bind-addr": f"bind-addr: {bind}",
    "auth": "auth: password",
    "password": f"password: {password}",
    "cert": "cert: false",
    "disable-telemetry": "disable-telemetry: true",
    "disable-update-check": "disable-update-check: true",
}
seen = set()
out = []
for line in lines:
    key = line.split(":", 1)[0] if ":" in line else ""
    if key == "hashed-password":
        continue
    if key in rendered:
        out.append(rendered[key])
        seen.add(key)
    else:
        out.append(line)
for key, value in rendered.items():
    if key not in seen:
        out.append(value)
file.write_text("\n".join(out).rstrip() + "\n")
file.chmod(0o600)
print(password)
PY
}

code_server_args() {
  printf '%s\n' \
    "--config" "${CODE_SERVER_CONFIG_FILE}" \
    "--bind-addr" "${CODE_SERVER_BIND_ADDR}" \
    "--auth" "password" \
    "--user-data-dir" "${CODE_SERVER_USER_DATA_DIR}" \
    "--extensions-dir" "${CODE_SERVER_EXTENSIONS_DIR}" \
    "${CODE_SERVER_WORKSPACE}"
}

prepare_user_bus() {
  if [[ -z "${XDG_RUNTIME_DIR:-}" && -d "/run/user/$(id -u)" ]]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
  fi
}

systemd_user_available() {
  prepare_user_bus
  command -v systemctl >/dev/null 2>&1 || return 1
  [[ -S "${XDG_RUNTIME_DIR:-}/bus" ]] || return 1
  systemctl --user show-environment >/dev/null 2>&1
}

# 以下はユーザーサービスの状態を調べるだけの関数。登録と削除は user-service.sh が行う。
user_service_exists() {
  systemd_user_available && systemctl --user cat "${CODE_SERVER_UNIT_NAME}" >/dev/null 2>&1
}

user_service_enabled() {
  systemd_user_available && systemctl --user is-enabled --quiet "${CODE_SERVER_UNIT_NAME}" >/dev/null 2>&1
}

user_service_active() {
  systemd_user_available && systemctl --user is-active --quiet "${CODE_SERVER_UNIT_NAME}" >/dev/null 2>&1
}

# このサンプルの設定ファイルを指定して動いている code-server の PID を出す。
code_server_pids() {
  local pid_path pid cmdline
  for pid_path in /proc/[0-9]*; do
    [[ -d "${pid_path}" ]] || continue
    pid="${pid_path#/proc/}"
    if [[ "${pid}" -eq "$$" || "${pid}" -eq "${PPID:-0}" ]]; then
      continue
    fi
    cmdline="$(tr '\0' ' ' < "${pid_path}/cmdline" 2>/dev/null || true)"
    if [[ "${cmdline}" == *"--config ${CODE_SERVER_CONFIG_FILE}"* || "${cmdline}" == *"--config=${CODE_SERVER_CONFIG_FILE}"* ]]; then
      printf '%s\n' "${pid}"
    fi
  done
}

code_server_running() {
  local pid
  pid="$(code_server_pids | head -n 1 || true)"
  [[ -n "${pid}" ]]
}

stop_running_code_server() {
  local pids=() pid i
  mapfile -t pids < <(code_server_pids)
  if [[ ${#pids[@]} -eq 0 ]]; then
    echo "起動中の code-server はありません。"
    return 0
  fi
  for pid in "${pids[@]}"; do
    kill -TERM "${pid}" 2>/dev/null || true
  done
  for i in $(seq 1 20); do
    mapfile -t pids < <(code_server_pids)
    [[ ${#pids[@]} -eq 0 ]] && break
    sleep 0.25
  done
  if [[ ${#pids[@]} -gt 0 ]]; then
    for pid in "${pids[@]}"; do
      kill -KILL "${pid}" 2>/dev/null || true
    done
  fi
  echo "code-server を停止しました。"
}

port_is_listening() {
  ss -ltn "sport = :${CODE_SERVER_PORT}" | grep -Eq "[.:]${CODE_SERVER_PORT}([^0-9]|$)"
}

http_status() {
  local code
  # 接続できない場合も curl は -w の 000 を出して非 0 で終わる。
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 3 \
    "http://127.0.0.1:${CODE_SERVER_PORT}/" 2>/dev/null)" || true
  printf '%s' "${code:-000}"
}

print_endpoints() {
  echo "接続先: http://127.0.0.1:${CODE_SERVER_PORT}/"
  echo "WSL の場合、Windows のブラウザからは http://localhost:${CODE_SERVER_PORT}/ で接続します。"
  echo "設定: ${CODE_SERVER_CONFIG_FILE}"
  echo "ワークスペース: ${CODE_SERVER_WORKSPACE}"
}

download_release() {
  local dest partial sha
  require_cmd curl sha256sum tar
  dest="${CODE_SERVER_CACHE_DIR}/${CODE_SERVER_ASSET}"
  partial="${dest}.partial"
  sha="${CODE_SERVER_LINUX_AMD64_SHA256}"
  [[ -n "${sha}" ]] || die "CODE_SERVER_LINUX_AMD64_SHA256 が version.env にありません。"
  mkdir -p "${CODE_SERVER_CACHE_DIR}"
  if [[ -f "${dest}" ]] && echo "${sha}  ${dest}" | sha256sum -c --status; then
    echo "検証済みのアーカイブを使います: ${dest}"
    return 0
  fi
  echo "code-server ${CODE_SERVER_VERSION} をダウンロードします。"
  rm -f "${partial}"
  curl -fL --retry 3 --retry-delay 2 --connect-timeout 20 -o "${partial}" "${CODE_SERVER_ASSET_URL}"
  mv "${partial}" "${dest}"
  echo "${sha}  ${dest}" | sha256sum -c - || die "SHA-256 が一致しません: ${dest}"
}

extract_release() {
  local tmp extracted
  tmp="$(mktemp -d)"
  if ! tar -C "${tmp}" -xzf "${CODE_SERVER_CACHE_DIR}/${CODE_SERVER_ASSET}"; then
    rm -rf "${tmp}"
    die "アーカイブの展開に失敗しました。"
  fi
  extracted="${tmp}/code-server-${CODE_SERVER_VERSION}-linux-amd64"
  if [[ ! -d "${extracted}" ]]; then
    rm -rf "${tmp}"
    die "アーカイブの展開結果が見つかりません。"
  fi
  mkdir -p "${HOME}/.local/lib"
  rm -rf "${CODE_SERVER_INSTALL_DIR}"
  mv "${extracted}" "${CODE_SERVER_INSTALL_DIR}"
  rm -rf "${tmp}"
}
