# pmOS Redmi 5 Plus / Redmi Note 5 (vince) — Headless Router

postmarketOS (Alpine Linux) tanpa layar untuk **Xiaomi Redmi 5 Plus / Redmi Note 5** (codename `vince`, Snapdragon 625/MSM8953). Berfungsi sebagai router WiFi portable, modem 4G, downloader, dan file server — dikendalikan penuh lewat web UI.

---

## Kredensial (semua sandi: `vince123`)

| Layanan | Cara akses | Login |
|---|---|---|
| WiFi Hotspot | SSID `pmOS-Vince` | sandi `vince123` |
| Web UI utama | `http://192.168.50.1` | user `admin` atau `user` + `vince123` |
| Web Terminal (ttyd) | `http://192.168.50.1:7681` | user `user` + `vince123` |
| AriaNg (downloader) | `http://192.168.50.1:6801` | RPC secret `vince123` |
| File Sharing (Samba) | `\\192.168.50.1` | user `user` + `vince123` |
| SSH lewat kabel USB | `ssh user@172.16.42.1` | **tanpa password** (recovery) |
| LuCI (opsional) | `http://192.168.50.1:8080` | root + password yang diset saat instalasi |

---

## Sebelum flash (WAJIB dibaca)

1. **Bootloader vince HARUS unlocked** dulu (pakai **Mi Unlock Tool** resmi dari Xiaomi — proses ini menghapus semua data). Tanpa unlock, fastboot akan menolak flash.
2. PC dengan **fastboot** (Android platform-tools) terinstall.
3. Baterai >50%, backup data penting.
4. ROM ini menghapus sistem Android asli.

---

## Cara flash (langkah demi langkah)

1. Dari halaman **Releases**, download file rilis terbaru, extract → dapat `boot.img` dan `rootfs.img` (plus file teks petunjuk).
2. Matikan HP → masuk mode **fastboot** (tahan **Volume Bawah + Power**) → colok ke PC via USB.
3. Cek koneksi: `fastboot devices` (harus muncul kode perangkat).
4. Flash kernel/boot:
   ```bash
   fastboot flash boot boot.img
   ```
5. Flash sistem (rootfs):
   ```bash
   fastboot flash userdata rootfs.img
   ```
   Jika error "partition not found", ganti `userdata` dengan `system`. (Ikuti file teks di dalam artifact untuk nama partisi yang tepat.)
6. Opsional (disarankan): `fastboot erase cache`
7. `fastboot reboot`
8. Tunggu **1–2 menit** (boot pertama agak lama) → di HP/laptop sambung WiFi **`pmOS-Vince`** (sandi `vince123`) → buka browser **`http://192.168.50.1`** → login `admin` / `vince123`.

---

## Setelah masuk Web UI

- **Tab SIM**: set APN kartu (misal `internet`/`3gprs` sesuai operator) supaya data 4G jalan, atau aktifkan mode jaringan 4G only.
- **Tab Repeater**: sambung ke WiFi rumah sebagai sumber internet (lalu dipancarkan ulang via hotspot).
- **Tab Hotspot**: ganti SSID/sandi hotspot kalau mau.
- **Tab System**: reboot, set LED, volume, Bluetooth, USB mode.
- Untuk install **LuCI** (panel router OpenWrt, opsional): salin `install-luci.sh` dari repo ini ke perangkat, lalu jalankan sebagai root (`sh install-luci.sh`) → akses `:8080`.

---

## Ganti sandi

- **Web UI / ttyd / Samba / Aria2 RPC** (satu sumber): lewat SSH USB atau web terminal:
  ```bash
  echo sandi_baru > /etc/vince/smb-pass
  rc-service vince-webui restart
  rc-service vince-ttyd restart
  ```
- **Hotspot WiFi**: lewat Web UI tab Hotspot (atau edit `/etc/NetworkManager/system-connections/Hotspot.nmconnection`).

---

## Troubleshooting

| Gejala | Solusi |
|---|---|
| Stuck logo / tidak boot | Pastikan bootloader unlocked; ulang flash; cek `fastboot getvar unlocked` harus `yes`. |
| Hotspot `pmOS-Vince` tidak muncul | Tunggu 2 menit. Colok USB → `ssh user@172.16.42.1` → `rc-service vince-ap restart`, cek `cat /var/log/vince-ap.log`. |
| Lupa sandi web UI | SSH via USB (tanpa password) → `echo vince123 > /etc/vince/smb-pass && rc-service vince-webui restart`. |
| Tidak ada internet | Set APN atau Repeater di Web UI; cek `mmcli -L` dan `nmcli con`. |
| Web UI bisa dibuka tapi login gagal (503) | File `/etc/vince/smb-pass` kosong — isi via SSH USB seperti di atas. |

---

## Build ulang sendiri

Fork repo ini → tab **Actions** → enable → workflow jalan otomatis (45–90 menit). Hasil build otomatis dipublikasikan ke halaman **Releases**. Sandi default sudah `vince123`; kalau mau ganti, set repository secret `PMOS_PASSWORD` dan `HOTSPOT_PSK`.

---

*Dipasang dengan risiko sendiri. postmarketOS adalah komunitas, bukan firmware resmi Xiaomi.*
