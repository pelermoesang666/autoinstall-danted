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
echo "peler:Musangking123" | chpasswd

systemctl restart danted
systemctl enable danted

apt install -y build-essential gcc make git

rm -rf /tmp/3proxy
cd /tmp
git clone https://github.com/3proxy/3proxy.git
cd 3proxy

make -f Makefile.Linux

sed -i -E '/^[[:space:]]*bin\/\$\(PREFIX\)(ftppr|imapp|pop3p|smtpp)[[:space:]]*\\[[:space:]]*$/d' Makefile.Linux

make -f Makefile.Linux install

mkdir -p /etc/3proxy
: > /etc/3proxy/3proxy.cfg
cat > /etc/3proxy/3proxy.cfg <<EOF
daemon
pidfile /var/run/3proxy.pid
nserver 8.8.8.8
nserver 1.1.1.1
nscache 65536
log /var/log/3proxy.log D
logformat "- +_L%t.%. %N.%p %E %U %C:%c %R:%r %O %I %h %T"
timeouts 1 5 30 60 180 1800 15 60
users peler:CL:Musangking123
auth strong
allow peler
proxy -p8443 -a
EOF

mkdir -p /etc/systemd/system/3proxy.service.d
cat > /etc/systemd/system/3proxy.service.d/override.conf <<EOF
[Service]
User=root
Group=root
Type=forking
PIDFile=/var/run/3proxy.pid
EOF

systemctl daemon-reload
systemctl enable 3proxy
systemctl restart 3proxy

sleep 2
ss -tlnp | grep -E '443|8443'
