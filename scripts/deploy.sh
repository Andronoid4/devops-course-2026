#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Ошибка доставки" >&2' ERR
ROOT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
cd "$ROOT"
DRY=0
RSYNC_ARGS=(-avz --delete --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r)
if [[ $# -gt 1 ]]; then exit 1; fi
if [[ $# -eq 1 ]]; then [[ $1 == --dry-run ]] || exit 1; DRY=1; RSYNC_ARGS+=(--dry-run); fi
[[ -f site/index.html ]] || { echo 'Нет site/index.html' >&2; exit 1; }
[[ -z $(git status --porcelain) ]] || { echo 'Рабочая копия содержит изменения' >&2; exit 1; }
rsync "${RSYNC_ARGS[@]}" -e 'ssh -o BatchMode=yes -o ConnectTimeout=5' site/ devops:/var/www/devops-site/
[[ $DRY -eq 1 ]] && exit 0
curl --no-ca-native --fail --silent --show-error --max-time 10 --cacert "${HOME}/devops.crt" https://devops.local/ >/dev/null
echo "Доставлен коммит $(git rev-parse --short HEAD)"
