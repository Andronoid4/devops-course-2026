#!/usr/bin/env bash
set -euo pipefail
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server ufw nginx rsync dnsutils curl openssl ca-certificates
id devops >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo devops
install -d -m 700 -o devops -g devops /home/devops/.ssh
install -m 600 -o devops -g devops /tmp/devops_vm.pub /home/devops/.ssh/authorized_keys
# Dedicated VM administrator; unattended checks use a validated sudoers fragment.
printf 'devops ALL=(ALL:ALL) NOPASSWD: ALL\n' >/tmp/devops-sudo
visudo -cf /tmp/devops-sudo
install -m 440 /tmp/devops-sudo /etc/sudoers.d/devops
hostnamectl set-hostname devops-vm
sed -i '/^127.0.1.1/d' /etc/hosts
echo '127.0.1.1 devops-vm.devops.local devops-vm' >>/etc/hosts
