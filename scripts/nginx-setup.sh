#!/usr/bin/env bash
set -euo pipefail
install -d -m 755 -o devops -g devops /var/www/devops-site
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt -subj '/CN=devops.local' -addext 'subjectAltName=DNS:devops.local'
chmod 600 /etc/ssl/private/devops.key
cat >/etc/nginx/sites-available/devops-site <<'CONF'
server {
    listen 80;
    server_name devops.local;
    return 301 https://$host$request_uri;
}
server {
    listen 443 ssl;
    server_name devops.local;
    ssl_certificate /etc/ssl/certs/devops.crt;
    ssl_certificate_key /etc/ssl/private/devops.key;
    root /var/www/devops-site;
    index index.html;
    access_log /var/log/nginx/devops-site.access.log;
    error_log /var/log/nginx/devops-site.error.log;
    error_page 404 /404.html;
    location / { try_files $uri $uri/ =404; }
    location /app/ {
        proxy_pass http://127.0.0.1:5000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
CONF
ln -sfn /etc/nginx/sites-available/devops-site /etc/nginx/sites-enabled/devops-site
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable nginx
systemctl reload nginx
