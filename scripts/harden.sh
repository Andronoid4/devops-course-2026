#!/usr/bin/env bash
set -euo pipefail
cp -n /etc/ssh/sshd_config /etc/ssh/sshd_config.backup || true
cat >/etc/ssh/sshd_config.d/00-devops-hardening.conf <<'CONF'
Port 2222
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
AllowUsers devops
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
CONF
sshd -t
ufw default deny incoming
ufw default allow outgoing
ufw limit 2222/tcp comment 'SSH rate-limited'
ufw allow 80/tcp comment HTTP
ufw allow 443/tcp comment HTTPS
ufw logging medium
ufw --force enable
systemctl disable --now ssh.socket
rm -f /etc/systemd/system/ssh.service.requires/ssh.socket
systemctl mask ssh.socket
systemctl daemon-reload
systemctl enable ssh.service
systemctl restart ssh.service
sshd -T | grep -E '^(port|permitrootlogin|passwordauthentication|maxauthtries|allowusers)'
