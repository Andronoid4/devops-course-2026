#!/usr/bin/env bash
set -uo pipefail
PASS=0; FAIL=0
check() {
 local desc="$1" expected="$2" actual="$3"
 if [[ "$actual" == "$expected" ]]; then echo "[OK] $desc"; ((PASS+=1));
 else echo "[FAIL] $desc (ожидалось $expected; получено $actual)"; ((FAIL+=1)); fi
}
result() { "$@" >/dev/null 2>&1 && echo yes || echo no; }
echo '[1] Служба SSH'
CFG=$(sudo sshd -T)
check 'Root запрещён' no "$(awk '/^permitrootlogin/{print $2}' <<<"$CFG")"
check 'Пароли отключены' no "$(awk '/^passwordauthentication/{print $2}' <<<"$CFG")"
check 'Порт нестандартный' yes "$(awk '/^port/{if($2!=22) print "yes"; else print "no"}' <<<"$CFG")"
check MaxAuthTries 3 "$(awk '/^maxauthtries/{print $2}' <<<"$CFG")"
echo '[2] UFW'
check 'UFW активен' active "$(sudo ufw status | awk '/^Status:/{print $2}')"
check 'Входящие запрещены' yes "$(result bash -c 'sudo ufw status verbose | grep -q "Default: deny (incoming)"')"
echo '[3] Учётные записи'
awk -F: '$3>=1000 && $3<65534 {print $1,$3}' /etc/passwd
if [[ ${AUDIT_LEVEL:-7} -ge 6 ]]; then
 echo '[4] Веб-сервер'
 check nginx active "$(systemctl is-active nginx)"
 check 'nginx -t' yes "$(result sudo nginx -t)"
 check 'Сертификат действует более 30 дней' yes "$(result openssl x509 -checkend "${CERT_CHECK_SECONDS:-2592000}" -noout -in /etc/ssl/certs/devops.crt)"
 check 'Нет общедоступной записи' '' "$(find /var/www/devops-site -perm -o+w -print)"
 check 'Права закрытого ключа' 600 "$(sudo stat -c %a /etc/ssl/private/devops.key)"
fi
if [[ ${AUDIT_LEVEL:-7} -ge 7 ]]; then
 echo '[5] Контейнеризация'
 check Docker active "$(systemctl is-active docker)"
 DB=$(docker compose --project-directory "$HOME/app" ps -q db)
 check 'PostgreSQL healthy' healthy "$(docker inspect -f '{{.State.Health.Status}}' "$DB" 2>/dev/null)"
 check '5000/5432 только loopback' '' "$(ss -H -tln | awk '$4 ~ /:(5000|5432)$/ && $4 !~ /^127\.0\.0\.1:/ {print $4}')"
 check '.env приложения' 600 "$(stat -c %a "$HOME/app/.env")"
fi
if [[ ${AUDIT_LEVEL:-7} -ge 8 ]]; then
 echo '[6] Контрольная работа 2'
 RD=$(docker compose --project-directory "$HOME/kr2" ps -q redis)
 check 'Redis healthy' healthy "$(docker inspect -f '{{.State.Health.Status}}' "$RD" 2>/dev/null)"
 check '8001 только loopback' '127.0.0.1:8001' "$(docker compose --project-directory "$HOME/kr2" port app 8001)"
 check '.env KR2' 600 "$(stat -c %a "$HOME/kr2/.env")"
 check 'Сертификат KR2' yes "$(result openssl x509 -checkend 2592000 -noout -in /etc/ssl/certs/kr2.crt)"
 check 'KR2 активирован' yes "$(result test -L /etc/nginx/sites-enabled/kr2)"
fi
echo "Пройдено: $PASS; не пройдено: $FAIL"
[[ $FAIL -eq 0 ]]
