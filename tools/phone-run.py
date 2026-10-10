#!/usr/bin/env python3
"""Run a shell command on the phone's Halium initrd telnet (192.168.2.15:23) and print its output."""
import socket, sys, time
cmd, wait = sys.argv[1], float(sys.argv[2]) if len(sys.argv) > 2 else 3
s = socket.create_connection(("192.168.2.15", 23), timeout=5)
def strip_iac(b):
    out, i = bytearray(), 0
    while i < len(b):
        if b[i] == 255 and i + 1 < len(b):
            if b[i+1] in (251, 252, 253, 254) and i + 2 < len(b):   # WILL/WONT/DO/DONT opt -> refuse
                s.sendall(bytes([255, 254 if b[i+1] in (251, 252) else 252, b[i+2]])); i += 3; continue
            i += 2; continue
        out.append(b[i]); i += 1
    return bytes(out)
time.sleep(0.8); s.settimeout(0.5)
try: s.recv(65536)
except socket.timeout: pass
s.sendall(f"stty -echo 2>/dev/null; echo __BEGIN__; {cmd}; echo __END__\n".encode())
buf, t0 = b"", time.time()
s.settimeout(1)
while time.time() - t0 < wait + 60:
    try:
        d = s.recv(65536)
        if not d: break
        buf += strip_iac(d)
        if b"\n__END__" in buf: break
    except socket.timeout:
        if time.time() - t0 > wait and b"__BEGIN__" in buf and b"__END__" in buf: break
txt = buf.decode(errors="replace").replace("\r", "")
if "\n__BEGIN__" in txt: txt = txt.split("\n__BEGIN__", 1)[1]
elif "__BEGIN__\n" in txt: txt = txt.split("__BEGIN__\n", 1)[1]
print(txt.split("__END__")[0].strip("\n"))
s.close()
