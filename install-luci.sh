#!/bin/sh
# ============================================================
#  Install LuCI (OpenWrt web UI) + paket router di postmarketOS (vince)
#  Jalankan sebagai ROOT di perangkat vince (via SSH/serial).
#  Akses setelahnya: http://<IP-vince>:8080/cgi-bin/luci
# ============================================================
set -e

echo "[1/6] Update repository apk..."
apk update

echo ""
echo "[2/6] Install LuCI + uhttpd + rpcd + uci..."
apk add --no-cache luci luci-ssl uhttpd rpcd uci

echo ""
echo "[3/6] Set password root (untuk login LuCI)..."
echo "    (masukkan password baru, lalu konfirmasi)"
passwd root || true

echo ""
echo "[4/6] Konfigurasi uhttpd di PORT 8080 (hindari bentrok dgn vince-webui di port 80)..."
mkdir -p /etc/config /www
cat > /etc/config/uhttpd <<'EOF'
config uhttpd main
    list listen_http 0.0.0.0:8080
    list listen_https 0.0.0.0:8443
    option home /www
    option rfc1918_filter 0
    option cert /etc/uhttpd.crt
    option key /etc/uhttpd.key
    option cgi_prefix /cgi-bin
    option script_timeout 60
    option network_timeout 30
    option ubus_prefix /ubus
EOF
# Generate self-signed cert untuk HTTPS (opsional)
uhttpd -x /etc/uhttpd.crt -k /etc/uhttpd.key -s CN=vince 2>/dev/null || echo "    (HTTPS cert dilewati — HTTP port 8080 tetap jalan)"

echo ""
echo "[5/6] Aktifkan & jalankan layanan..."
rc-update add rpcd default 2>/dev/null || true
rc-update add uhttpd default 2>/dev/null || true
( rc-service rpcd start 2>/dev/null || /etc/init.d/rpcd start ) || true
( rc-service uhttpd start 2>/dev/null || /etc/init.d/uhttpd start ) || true

echo ""
echo "[6/6] (Opsional) Paket router tambahan..."
apk add --no-cache adblock wireguard-tools openvpn miniupnpd htop nload 2>/dev/null \
    || echo "    (beberapa paket tidak tersedia, dilewati — tidak masalah)"

echo ""
echo "============================================================"
echo "  SELESAI!"
echo "  Akses LuCI   : http://192.168.50.1:8080/cgi-bin/luci"
echo "  Login        : root + password yang baru Anda set"
echo "  vince-webui  : http://192.168.50.1 (port 80, tetap jalan)"
echo ""
echo "  CATATAN:"
echo "  - Halaman Network/Firewall di LuCI mengandalkan config UCI"
echo "    OpenWrt; di pmOS (NetworkManager + vince-ap) halaman itu"
echo "    mungkin tidak mengontrol setup yang sudah ada."
echo "  - Kontrol utama (hotspot, SIM, audio, USB) tetap lewat"
echo "    vince-webui di port 80. LuCI = dashboard + paket tambahan."
echo "  - Untuk berhenti: rc-service uhttpd stop"
echo "============================================================"
