#!/usr/bin/env bash
set -euo pipefail
# Explicit standalone unit for the cloud image: no socket activation dependency.
cat >/etc/systemd/system/ssh.service <<'UNIT'
[Unit]
Description=OpenSSH server for DevOps laboratory
After=network.target
[Service]
Type=simple
ExecStartPre=/usr/bin/mkdir -p /run/sshd
ExecStartPre=/usr/sbin/sshd -t
ExecStart=/usr/sbin/sshd -D -e
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
KillMode=process
[Install]
WantedBy=multi-user.target
UNIT
rm -f /etc/systemd/system/ssh.service.requires/ssh.socket
systemctl mask ssh.socket
systemctl daemon-reload
ln -sfn /etc/systemd/system/ssh.service /etc/systemd/system/multi-user.target.wants/ssh.service
systemctl restart ssh.service
systemctl show ssh.service -p FragmentPath -p Requires -p UnitFileState
