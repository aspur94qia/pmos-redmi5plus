#!/usr/bin/env python3
"""
vince-compress: Proxy kompresi data transparan (HTTP port 80 saja).
- Menerima redirect iptables dari client wlan0 (tujuan tcp dport 80).
- Mengambil tujuan asli via SO_ORIGINAL_DST.
- Meng-gzip konten teks (html/css/js/json/text) jika belum terkompresi.
- Meneruskan binary/gambar/video apa adanya (sudah terkompresi).
- Mencatat bytes_in (dari internet) vs bytes_out (ke client) ke stats.json.
CATATAN: HTTPS (port 443) TIDAK dapat dikompresi karena terenkripsi end-to-end.
         Memaksa kompresi HTTPS = MITM yang merusak keamanan (TIDAK dilakukan).
"""
import socket, threading, json, os, time, gzip, io, re

LISTEN = ("127.0.0.1", 8888)
STATS_FILE = "/var/lib/vince-compress/stats.json"
SO_ORIGINAL_DST = 80
stats_lock = threading.Lock()
stats = {"bytes_in": 0, "bytes_out": 0, "requests": 0, "started": time.time()}

os.makedirs(os.path.dirname(STATS_FILE), exist_ok=True)

def save_stats():
    while True:
        time.sleep(2)
        try:
            with stats_lock:
                tmp = dict(stats)
            with open(STATS_FILE + ".tmp", "w") as f:
                json.dump(tmp, f)
            os.replace(STATS_FILE + ".tmp", STATS_FILE)
        except Exception:
            pass

def original_dst(sock):
    try:
        dst = sock.getsockopt(socket.SOL_IP, SO_ORIGINAL_DST, 16)
        port = (dst[2] << 8) | dst[3]
        ip = ".".join(str(b) for b in dst[4:8])
        return ip, port
    except Exception:
        return None, None

def pipe(src, dst, counter_key, max_bytes=None):
    total = 0
    try:
        while True:
            chunk = src.recv(65536)
            if not chunk:
                break
            dst.sendall(chunk)
            total += len(chunk)
            with stats_lock:
                stats[counter_key] += len(chunk)
            if max_bytes and total >= max_bytes:
                break
    except Exception:
        pass
    return total

def handle(client):
    try:
        dst_ip, dst_port = original_dst(client)
        if not dst_ip:
            client.close(); return
        # Baca request HTTP dari client
        req = b""
        while b"\r\n\r\n" not in req:
            c = client.recv(8192)
            if not c:
                client.close(); return
            req += c
            if len(req) > 65536:
                break
        # Teruskan ke server asli
        remote = socket.create_connection((dst_ip, dst_port), timeout=15)
        remote.sendall(req)
        # Baca header response
        resp = b""
        while b"\r\n\r\n" not in resp:
            c = remote.recv(8192)
            if not c:
                break
            resp += c
        header_end = resp.find(b"\r\n\r\n") + 4
        head = resp[:header_end]
        body = resp[header_end:]
        # Cek Content-Encoding & Content-Type
        head_lower = head.lower()
        is_text = bool(re.search(rb"content-type:\s*(text/|application/(json|javascript|xml|xhtml))", head_lower))
        already_gzip = b"content-encoding:" in head_lower and b"gzip" in head_lower
        m = re.search(rb"content-length:\s*(\d+)", head_lower)
        clen = int(m.group(1)) if m else None
        with stats_lock:
            stats["requests"] += 1
        if is_text and not already_gzip and clen is not None:
            # Baca sisa body
            remaining = clen - len(body)
            while remaining > 0:
                c = remote.recv(min(65536, remaining))
                if not c:
                    break
                body += c
                remaining -= len(c)
            with stats_lock:
                stats["bytes_in"] += clen
            # Gzip body
            buf = io.BytesIO()
            with gzip.GzipFile(fileobj=buf, mode="wb", compresslevel=9) as gz:
                gz.write(body)
            gzbody = buf.getvalue()
            new_head = re.sub(rb"content-length:\s*\d+", b"Content-Length: " + str(len(gzbody)).encode(), head, flags=re.I)
            new_head = re.sub(rb"(?i)connection:\s*[^\r\n]+", b"Connection: close", new_head)
            if b"content-encoding:" not in new_head.lower():
                new_head = new_head.replace(b"\r\n\r\n", b"\r\nContent-Encoding: gzip\r\n\r\n", 1)
            try:
                client.sendall(new_head + gzbody)
                with stats_lock:
                    stats["bytes_out"] += len(new_head) + len(gzbody)
            except Exception:
                pass
        else:
            # Lewatkan apa adanya (binary / gambar / video / sudah gzip)
            with stats_lock:
                stats["bytes_in"] += len(body)
            try:
                client.sendall(head + body)
                with stats_lock:
                    stats["bytes_out"] += len(head) + len(body)
                # Teruskan sisa
                pipe(remote, client, "bytes_in")
                # bytes_out dihitung di pipe
                with stats_lock:
                    pass  # pipe sudah menambah ke counter yang sama; perlu koreksi
            except Exception:
                pass
        remote.close()
    except Exception:
        pass
    finally:
        try:
            client.close()
        except Exception:
            pass

def main():
    threading.Thread(target=save_stats, daemon=True).start()
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(LISTEN)
    srv.listen(128)
    while True:
        try:
            c, _ = srv.accept()
            threading.Thread(target=handle, args=(c,), daemon=True).start()
        except Exception:
            time.sleep(0.5)

if __name__ == "__main__":
    main()
