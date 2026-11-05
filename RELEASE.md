# Rilis pmOS Vince (Redmi 5 Plus / Note 5)

Build otomatis dari source. File di dalam rilis ini: **`boot.img`** + **`rootfs.img`** (plus file teks petunjuk partisi).

## Kredensial default (semua: `vince123`)

- WiFi Hotspot: SSID **`pmOS-Vince`** / sandi **`vince123`**
- Web UI: `http://192.168.50.1` — user `admin` atau `user` / `vince123`
- Web Terminal: `http://192.168.50.1:7681` — `user` / `vince123`
- AriaNg: `http://192.168.50.1:6801` — RPC secret `vince123`
- SSH via USB: `ssh user@172.16.42.1` — **tanpa password** (recovery)

## Flash cepat (4 langkah)

1. Bootloader **harus unlocked** (Mi Unlock Tool). Masuk fastboot (Volume Bawah + Power).
2. `fastboot flash boot boot.img`
3. `fastboot flash userdata rootfs.img` (jika error, coba `system` — lihat file teks di dalam zip)
4. `fastboot reboot` → tunggu 1–2 menit → sambung WiFi `pmOS-Vince` → buka `http://192.168.50.1`

Tutorial lengkap, cara ganti sandi, set APN/Repeater, dan troubleshooting ada di **README** repo ini.
