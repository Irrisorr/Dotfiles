#!/usr/bin/env python3
"""Print one localStorage value of Spotify's app page (xpui) from disk.

Usage: spotify_storage.py KEY [LEVELDB_DIR]

Chromium keeps localStorage in a LevelDB; no LevelDB module is installed, so
this reads its files directly: the write-ahead .log and the snappy-compressed
.ldb tables. Every write carries a sequence number, so the record with the
highest one is the current value, whichever files are still live. Reading
works while Spotify runs (Chromium writes changes after a second or so).
"""

import glob
import os
import struct
import sys

ORIGIN = b"_https://xpui.app.spotify.com\x00\x01"
DEFAULT_DIR = os.path.expanduser("~/.cache/spotify/Browser/Local Storage/leveldb")


def varint(buf, i):
    n = shift = 0
    while True:
        b = buf[i]
        i += 1
        n |= (b & 0x7F) << shift
        if b < 0x80:
            return n, i
        shift += 7


def snappy(buf):
    size, i = varint(buf, 0)
    out = bytearray()
    while i < len(buf):
        tag = buf[i]
        i += 1
        kind = tag & 3
        if kind == 0:
            n = tag >> 2
            if n >= 60:
                extra = n - 59
                n = int.from_bytes(buf[i : i + extra], "little")
                i += extra
            n += 1
            out += buf[i : i + n]
            i += n
            continue
        if kind == 1:
            n = ((tag >> 2) & 7) + 4
            off = ((tag >> 5) << 8) | buf[i]
            i += 1
        elif kind == 2:
            n = (tag >> 2) + 1
            off = int.from_bytes(buf[i : i + 2], "little")
            i += 2
        else:
            n = (tag >> 2) + 1
            off = int.from_bytes(buf[i : i + 4], "little")
            i += 4
        for _ in range(n):  # copies may overlap their own output
            out.append(out[-off])
    if len(out) != size:
        raise ValueError("bad snappy block")
    return bytes(out)


def block(data, off, size):
    raw, kind = data[off : off + size], data[off + size]
    return snappy(raw) if kind == 1 else raw


def block_entries(buf):
    restarts = struct.unpack_from("<I", buf, len(buf) - 4)[0]
    end, i, key = len(buf) - 4 - 4 * restarts, 0, b""
    while i < end:
        shared, i = varint(buf, i)
        unshared, i = varint(buf, i)
        vlen, i = varint(buf, i)
        key = key[:shared] + buf[i : i + unshared]
        i += unshared
        yield key, buf[i : i + vlen]
        i += vlen


# Internal keys end in 8 bytes: sequence << 8 | type (1 = value, 0 = deletion).
def table_records(path):
    data = open(path, "rb").read()
    footer = data[-48:]
    _, j = varint(footer, 0)
    _, j = varint(footer, j)
    off, j = varint(footer, j)
    size, _ = varint(footer, j)
    for _, handle in block_entries(block(data, off, size)):
        boff, j = varint(handle, 0)
        bsize, _ = varint(handle, j)
        for ikey, value in block_entries(block(data, boff, bsize)):
            tag = int.from_bytes(ikey[-8:], "little")
            yield ikey[:-8], tag >> 8, tag & 0xFF, value


def log_records(path):
    data, payload, batches = open(path, "rb").read(), b"", []
    i = 0
    while i + 7 <= len(data):
        if 32768 - i % 32768 < 7:
            i += 32768 - i % 32768  # block trailer padding
            continue
        length, kind = struct.unpack_from("<HB", data, i + 4)
        if kind == 0 and length == 0:
            i += 32768 - i % 32768
            continue
        chunk = data[i + 7 : i + 7 + length]
        i += 7 + length
        if kind in (1, 2):  # full / first
            payload = chunk
        else:
            payload += chunk
        if kind in (1, 4):  # full / last
            batches.append(payload)
    for b in batches:
        seq, count = struct.unpack_from("<QI", b, 0)
        j = 12
        for n in range(count):
            kind = b[j]
            j += 1
            klen, j = varint(b, j)
            key = b[j : j + klen]
            j += klen
            value = b""
            if kind == 1:
                vlen, j = varint(b, j)
                value = b[j : j + vlen]
                j += vlen
            yield key, seq + n, kind, value


def decode(value):
    # Chromium's prefix byte: 0 = UTF-16LE, 1 = Latin-1.
    return value[1:].decode("utf-16-le" if value[:1] == b"\x00" else "latin-1")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__.strip().splitlines()[2])
    want = ORIGIN + sys.argv[1].encode("latin-1")
    folder = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_DIR
    best = None
    for path in glob.glob(os.path.join(folder, "*.ldb")) + glob.glob(os.path.join(folder, "*.log")):
        records = table_records(path) if path.endswith(".ldb") else log_records(path)
        try:
            for key, seq, kind, value in records:
                if key == want and (best is None or seq > best[0]):
                    best = (seq, kind, value)
        except (IndexError, ValueError, struct.error):
            continue  # a table being written right now; the others still count
    if not best or best[1] != 1:
        sys.exit(1)
    print(decode(best[2]))


if __name__ == "__main__":
    main()
