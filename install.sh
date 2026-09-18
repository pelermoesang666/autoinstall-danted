#!/bin/bash

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Jalankan sebagai root: sudo bash install.sh"
    exit 1
fi

DEFAULT_IP=$(curl -s4 ifconfig.me || hostname -I | awk '{print $1}')

read -rp "Masukkan IP eksternal VPS [$DEFAULT_IP]: " EXTERNAL_IP < /dev/tty
EXTERNAL_IP=${EXTERNAL_IP:-$DEFAULT_IP}

if [ -z "$EXTERNAL_IP" ]; then
    echo "IP tidak boleh kosong"
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt update && apt upgrade -y

apt install -y ufw
ufw allow 443

apt install dante-server -y

if [ -f /etc/danted.conf ]; then
    mv /etc/danted.conf /etc/danted.conf.bak
fi

cat > /etc/danted.conf <<EOF
logoutput: syslog
user.privileged: root
user.unprivileged: nobody
internal: 0.0.0.0 port = 443
external: $EXTERNAL_IP
socksmethod: username
clientmethod: none
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error
}
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error
}
EOF

if ! id peler &>/dev/null; then
    useradd -r -s /bin/false peler
fi
echo "peler:peler123" | chpasswd

systemctl restart danted
systemctl enable danted

echo ""
echo "=========================================="
echo "SOCKS5 Proxy siap"
echo "IP      : $EXTERNAL_IP"
echo "Port    : 443"
echo "User    : peler"
echo "Password: peler123"
echo "=========================================="
