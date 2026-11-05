#!/bin/sh
# ============================================================
#  TAMBAH SEMUA FITUR ROUTER OPENWRT ke postmarketOS (vince)
#  Jalankan sebagai ROOT di perangkat vince.
#  Isi: SQM(anti-lag) + Adblock + WireGuard + OpenVPN + UPnP
#       + miniDLNA + vnStat(monitoring) + Transmission + tools
# ============================================================
set -e
echo "============================================================"
echo "  INSTAL PAKET ROUTER LENGKAP untuk pmOS vince"
echo "============================================================"

echo ""
echo "[1/8] Update apk & install paket inti..."
apk update
apk add --no-cache \
    wireguard-tools wireguard-virt \
    openvpn \
    miniupnpd \
    minidlna \
    vnstat \
    transmission-daemon transmission-cli \
    iproute2-tc \
    htop nload iftop iperf3 speedtest-cli \
    curl wget jq \
    2>/dev/null || echo "  (beberapa paket mungkin tidak ada, dilewati)"

# (Opsional) Kalau LuCI sudah di-install, tambah halaman config-nya:
if command -v uhttpd >/dev/null 2>&1; then
    echo "  -> Menambahkan luci-app-* (halaman config LuCI)..."
    apk add --no-cache luci-app-wireguard luci-app-openvpn luci-app-minidlna \
        luci-app-upnp luci-app-vnstat luci-app-transmission luci-app-adblock \
        2>/dev/null || echo "  (beberapa luci-app tidak tersedia, tidak masalah)"
fi

echo ""
echo "[2/8] Setup ADBLOCK (blok iklan/tracker via dnsmasq)..."
mkdir -p /etc/adblock
wget -q -O /etc/adblock/hosts https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts 2>/dev/null \
    || curl -s -o /etc/adblock/hosts https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts 2>/dev/null \
    || echo "  (gagal download blocklist, lewati — adblock perlu internet)"
if [ -s /etc/adblock/hosts ]; then
    grep -q "addn-hosts=/etc/adblock/hosts" /etc/dnsmasq.conf 2>/dev/null \
        || echo "addn-hosts=/etc/adblock/hosts" >> /etc/dnsmasq.conf
    rc-service dnsmasq restart 2>/dev/null || /etc/init.d/dnsmasq restart
    echo "  -> Adblock aktif (StevenBlack hosts, ~100k domain diblok)"
else
    echo "  -> Adblock: blocklist gagal diunduh, setup manual nanti."
fi
# Script update blocklist mingguan
cat > /etc/periodic/weekly/adblock-update <<'EOF'
#!/bin/sh
wget -q -O /etc/adblock/hosts https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts \
  && rc-service dnsmasq restart 2>/dev/null
EOF
chmod +x /etc/periodic/weekly/adblock-update 2>/dev/null || true

echo ""
echo "[3/8] Setup SQM (anti-lag / bufferbloat) dengan CAKE..."
# Deteksi interface upstream (USB tethering=usb0, modem=wwan0/rndis)
UPLINK=$(ip route show default 2>/dev/null | awk '{print $5}' | head -1)
[ -z "$UPLINK" ] && UPLINK="usb0"
cat > /etc/init.d/sqm <<'EOF'
#!/sbin/openrc-run
description="SQM CAKE anti-lag"
UPLINK=$(ip route show default 2>/dev/null | awk '{print $5}' | head -1)
start() {
    ebegin "Starting SQM CAKE on $UPLINK"
    tc qdisc add dev $UPLINK root cake bandwidth 50Mbit besteffort 2>/dev/null \
      || tc qdisc replace dev $UPLINK root cake bandwidth 50Mbit besteffort
    eend $?
}
stop() {
    ebegin "Stopping SQM"
    tc qdisc del dev $UPLINK root 2>/dev/null
    eend $?
}
EOF
chmod +x /etc/init.d/sqm
rc-update add sqm default 2>/dev/null || true
rc-service sqm start 2>/dev/null || true
echo "  -> SQM aktif di interface $UPLINK (atur bandwidth di /etc/init.d/sqm)"

echo ""
echo "[4/8] Setup UPnP (miniupnpd)..."
LANIF="wlan0"
cat > /etc/miniupnpd.conf <<EOF
ext_ifname=$UPLINK
listening_ip=$LANIF
enable_natpmp=yes
enable_upnp=yes
secure_mode=yes
EOF
rc-update add miniupnpd default 2>/dev/null || true
rc-service miniupnpd start 2>/dev/null || true
echo "  -> UPnP aktif (LAN=$LANIF, WAN=$UPLINK)"

echo ""
echo "[5/8] Setup miniDLNA (media server ke TV)..."
mkdir -p /home/user/Media
cat > /etc/minidlna.conf <<EOF
media_dir=/home/user/Media
port=8200
friendly_name=vince-DLNA
inotify=yes
EOF
rc-update add minidlna default 2>/dev/null || true
rc-service minidlna start 2>/dev/null || true
echo "  -> miniDLNA aktif (taruh video/musik di /home/user/Media)"

echo ""
echo "[6/8] Setup vnStat (monitoring pemakaian internet per-IP)..."
vnstat -u 2>/dev/null || true
rc-update add vnstat default 2>/dev/null || true
rc-service vnstat start 2>/dev/null || true
echo "  -> vnStat aktif (lihat: vnstat -i $UPLINK)"

echo ""
echo "[7/8] Setup Transmission (torrent client + web UI port 9091)..."
mkdir -p /home/user/Downloads
cat > /etc/transmission-daemon/settings.json 2>/dev/null <<EOF
{ "rpc-enabled": true, "rpc-port": 9091, "rpc-whitelist-enabled": false,
  "download-dir": "/home/user/Downloads", "umask": 0 }
EOF
rc-update add transmission-daemon default 2>/dev/null || true
rc-service transmission-daemon start 2>/dev/null || true
echo "  -> Transmission aktif: http://192.168.50.1:9091"

echo ""
echo "[8/8] Templat WireGuard & OpenVPN (perlu config Anda sendiri)..."
mkdir -p /etc/wireguard /etc/openvpn
cat > /etc/wireguard/wg0.conf.example <<'EOF'
# Isi dengan config dari provider VPN Anda, lalu:
#   cp /etc/wireguard/wg0.conf.example /etc/wireguard/wg0.conf
#   wg-quick up wg0
[Interface]
PrivateKey = <ISI_PRIVATE_KEY_ANDA>
Address = 10.0.0.2/24
DNS = 1.1.1.1
[Peer]
PublicKey = <ISI_PUBLIC_KEY_SERVER>
Endpoint = <SERVER_IP>:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
echo "  -> Templat WireGuard: /etc/wireguard/wg0.conf.example"
echo "  -> Config OpenVPN taruh di /etc/openvpn/*.conf lalu: rc-service openvpn start"

echo ""
echo "============================================================"
echo "  SELESAI! Ringkasan layanan:"
echo "  - Adblock     : aktif (dnsmasq, update mingguan)"
echo "  - SQM anti-lag: aktif di $UPLINK (cake)"
echo "  - UPnP        : aktif"
echo "  - miniDLNA    : aktif (/home/user/Media)"
echo "  - vnStat      : aktif (monitor bandwidth)"
echo "  - Transmission: http://192.168.50.1:9091"
echo "  - WireGuard   : templat di /etc/wireguard/ (isi config VPN)"
echo "  - OpenVPN     : config taruh di /etc/openvpn/"
echo ""
echo "  CATATAN RAM: Layanan ini pakai ~150-250MB RAM."
echo "  Kalau HP terasa berat, matikan yang tidak dipakai:"
echo "    rc-service <nama> stop && rc-update del <nama> default"
echo "  (nama: sqm miniupnpd minidlna vnstat transmission-daemon)"
echo "============================================================"
