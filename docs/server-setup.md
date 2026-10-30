# Конфигурация виртуальной машины devops-vm

Владелец: Алипян Андраник Айказович, ЭФБО-18-24. Контрольная работа: вариант 1.

## 1. Параметры машины
Ubuntu Server 24.04 LTS ARM64, Multipass, 2 CPU, 2 ГиБ RAM, диск 25 ГиБ.

## 2. Сетевые интерфейсы
Multipass на macOS использует собственную NAT-сеть с прямым доступом хоста к IP гостя.
Фактический IP после запуска сохраняется в evidence/ip.txt. Два адаптера VirtualBox не создаются.

## 3. Управляющий доступ
Прямое подключение к IP гостя, порт 2222, пользователь devops. Проброс портов не требуется.
Файл ssh_config формируется координатором. Пример: ssh -F ./ssh_config devops.
Ключ хоста сверяется через Multipass, затем сохраняется в evidence/known_hosts.
Пользовательский закрытый ключ ~/.ssh/devops_vm не копируется в проект и на сервер.

## 4. Учётные записи
Пользователь devops включён в sudo и docker. Ключевая аутентификация, ~/.ssh 700, authorized_keys 600.
Для автоматического выполнения учебных проверок используется NOPASSWD в /etc/sudoers.d/devops;
синтаксис предварительно проверяется visudo. Это отклонение от интерактивного sudo в методичке.
Группа docker эквивалентна административным правам.

## 5. Служба SSH
/etc/ssh/sshd_config.d/00-devops-hardening.conf: Port 2222, PermitRootLogin no,
PasswordAuthentication no, KbdInteractiveAuthentication no, PubkeyAuthentication yes,
PermitEmptyPasswords no, MaxAuthTries 3, LoginGraceTime 30, AllowUsers devops,
X11Forwarding no, ClientAliveInterval 300, ClientAliveCountMax 2.
Ранний префикс 00 обеспечивает приоритет перед cloud-init. ssh.socket отключается,
ssh.service включается. До перезапуска выполняется sshd -t; результат проверяется sshd -T и ss.
После смены SSH-порта Multipass не может использовать свой внутренний SSH на 22.
Управление выполняется через ssh devops. Для автоматического запуска используется явный unit
/etc/systemd/system/ssh.service (scripts/ssh-persistent.sh). Файл шаблона hosts cloud-init
исправлен, чтобы hostname -f сохранялся после перезапуска.

## 6. Межсетевой экран
default deny incoming, allow outgoing; LIMIT 2222/tcp, ALLOW 80/tcp и 443/tcp; logging medium.
Порты приложения 5000 и 8001 публикуются Docker только на 127.0.0.1; порты БД не публикуются.

## 7. Снимки состояния
Координатор создаёт снимки при остановленной VM: s01-clean-install, s02-keys-configured,
s03-ssh-persistent, s04-nginx-https, s05-docker-compose, s06-before-kr2, s07-kr2.
Созданные снимки нужно проверять командой multipass info devops-vm --snapshots.

## 8. Веб-сервер
/etc/nginx/sites-available/devops-site, ссылка в sites-enabled; root /var/www/devops-site.
Владелец каталога devops, каталоги 755, файлы 644. HTTPS: devops.local, SAN DNS:devops.local.
Ключ /etc/ssl/private/devops.key, root:root, 600; сертификат /etc/ssl/certs/devops.crt.
HTTP перенаправляется кодом 301. Журналы /var/log/nginx/devops-site.access.log и .error.log.
Сертификат копируется на хост и передаётся curl через --cacert; -k не используется для подтверждения.

## 9. Контейнеризация
Docker Engine и Compose Plugin устанавливаются из официального apt-репозитория Docker.
Проект ~/app, .env только на сервере, 600. PostgreSQL 16-alpine, том db_data,
сеть backend, готовность pg_isready. Приложение devops-app:1.0 работает от app,
Gunicorn в exec-форме. Nginx /app/ → http://127.0.0.1:5000/ с удалением префикса.

## 10. Контрольная работа
Исходный шаблон https://gitverse.ru/dgimatdinov/kr2-template, коммит 3ee6c4b.
Проект ~/kr2, Redis 7-alpine с AOF, том redis_data, аутентификация и healthcheck.
Секрет генерируется openssl rand только на сервере. api.devops.local → 127.0.0.1:8001.
Отдельные /etc/nginx/sites-available/kr2, /etc/ssl/certs/kr2.crt и /etc/ssl/private/kr2.key.
Сценарий scripts/audit.sh поддерживает AUDIT_LEVEL=5, 6, 7, 8.

## Восстановление
После восстановления исходного снимка перенести harden.sh и выполнить через multipass exec с sudo.
Затем выполнить nginx-setup.sh, install-docker.sh, доставить site/, app/ и kr2/,
сгенерировать новые .env, запустить docker compose up -d --build --wait,
выполнить kr2-nginx.sh и аудит. Сертификаты после пересоздания нужно заново скопировать на хост.
