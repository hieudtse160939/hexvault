#!/usr/bin/env python3
"""Minimal `apksigner` replacement: APK Signature Scheme v2 (RSA, SHA-256).

Used when the Android SDK build-tools cannot be downloaded (blocked network).
Implements the parts of the apksigner CLI that Godot's exporter calls:
  apksigner sign --ks <keystore.p12/jks> --ks-pass pass:<pw> [--ks-key-alias A] [--verbose] <apk>
  apksigner verify [--verbose] <apk>
The keystore must be PKCS12 (keytool's default format). v2 is accepted by
Android 7.0+ (API 24+), which is also Godot 4's minimum.
Spec: https://source.android.com/docs/security/features/apksigning/v2
"""
from __future__ import annotations

import hashlib
import struct
import sys

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives.serialization import pkcs12

MAGIC = b"APK Sig Block 42"
V2_ID = 0x7109871A
RSA_SHA256 = 0x0103
CHUNK = 1 << 20


def lp(b: bytes) -> bytes:
    return struct.pack("<I", len(b)) + b


def find_eocd(data: bytes) -> int:
    for i in range(len(data) - 22, max(-1, len(data) - 22 - 65536), -1):
        if data[i:i + 4] == b"PK\x05\x06":
            return i
    raise SystemExit("not a zip: no end of central directory")


def sections(data: bytes) -> tuple[bytes, bytes, bytes, int]:
    eocd = find_eocd(data)
    cd_off = struct.unpack("<I", data[eocd + 16:eocd + 20])[0]
    start = cd_off
    # an existing signing block sits right before the central directory: drop it
    if data[cd_off - 16:cd_off] == MAGIC:
        size = struct.unpack("<Q", data[cd_off - 24:cd_off - 16])[0]
        start = cd_off - size - 8
    return data[:start], data[cd_off:eocd], data[eocd:], start


def digest(entries: bytes, cd: bytes, eocd: bytes) -> bytes:
    chunks = []
    for sec in (entries, cd, eocd):
        for i in range(0, len(sec), CHUNK):
            c = sec[i:i + CHUNK]
            chunks.append(hashlib.sha256(b"\xa5" + struct.pack("<I", len(c)) + c).digest())
    return hashlib.sha256(b"\x5a" + struct.pack("<I", len(chunks)) + b"".join(chunks)).digest()


def eocd_with_cd_offset(eocd: bytes, off: int) -> bytes:
    return eocd[:16] + struct.pack("<I", off) + eocd[20:]


def sign(apk: str, ks: str, password: str) -> None:
    with open(ks, "rb") as f:
        key, cert, _ = pkcs12.load_key_and_certificates(f.read(), password.encode())
    data = open(apk, "rb").read()
    entries, cd, eocd, start = sections(data)
    eocd0 = eocd_with_cd_offset(eocd, start)          # digest uses the CD offset = signing block start
    dg = digest(entries, cd, eocd0)
    cert_der = cert.public_bytes(serialization.Encoding.DER)
    signed_data = lp(lp(struct.pack("<I", RSA_SHA256) + lp(dg))) + lp(lp(cert_der)) + lp(b"")
    sig = key.sign(signed_data, padding.PKCS1v15(), hashes.SHA256())
    pub = key.public_key().public_bytes(serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)
    signer = lp(signed_data) + lp(lp(struct.pack("<I", RSA_SHA256) + lp(sig))) + lp(pub)
    value = lp(lp(signer))
    pair = struct.pack("<Q", len(value) + 4) + struct.pack("<I", V2_ID) + value
    size = len(pair) + 8 + 16
    block = struct.pack("<Q", size) + pair + struct.pack("<Q", size) + MAGIC
    out = entries + block + cd + eocd_with_cd_offset(eocd, len(entries) + len(block))
    with open(apk, "wb") as f:
        f.write(out)


def verify(apk: str) -> bool:
    data = open(apk, "rb").read()
    eocd_pos = find_eocd(data)
    cd_off = struct.unpack("<I", data[eocd_pos + 16:eocd_pos + 20])[0]
    if data[cd_off - 16:cd_off] != MAGIC:
        print("no APK signing block")
        return False
    size = struct.unpack("<Q", data[cd_off - 24:cd_off - 16])[0]
    start = cd_off - size - 8
    pairs = data[start + 8:cd_off - 24]
    i = 0
    while i < len(pairs):
        ln = struct.unpack("<Q", pairs[i:i + 8])[0]
        pid = struct.unpack("<I", pairs[i + 8:i + 12])[0]
        val = pairs[i + 12:i + 8 + ln]
        i += 8 + ln
        if pid != V2_ID:
            continue
        signer = val[8:]                                   # signers seq -> first signer
        sd_len = struct.unpack("<I", signer[:4])[0]
        signed_data = signer[4:4 + sd_len]
        rest = signer[4 + sd_len:]
        sigs_len = struct.unpack("<I", rest[:4])[0]
        sig = rest[4:4 + sigs_len][4 + 4 + 4:]
        pub_der = rest[4 + sigs_len + 4:]
        dg_len = struct.unpack("<I", signed_data[8 + 4:8 + 8])[0]
        dg = signed_data[8 + 8:8 + 8 + dg_len]
        certs = signed_data[4 + struct.unpack("<I", signed_data[:4])[0]:]
        cert_der = certs[8:8 + struct.unpack("<I", certs[4:8])[0]]
        pub = serialization.load_der_public_key(pub_der)
        pub.verify(sig, signed_data, padding.PKCS1v15(), hashes.SHA256())
        x509.load_der_x509_certificate(cert_der)
        ok = digest(data[:start], data[cd_off:eocd_pos], eocd_with_cd_offset(data[eocd_pos:], start)) == dg
        print("Verifies" if ok else "DOES NOT VERIFY: digest mismatch")
        print("Verified using v2 scheme (APK Signature Scheme v2): %s" % ("true" if ok else "false"))
        return ok
    print("no v2 signature")
    return False


def main(argv: list[str]) -> int:
    if not argv:
        print("usage: apksigner sign|verify ...")
        return 1
    cmd, args = argv[0], argv[1:]
    opts: dict[str, str] = {}
    pos: list[str] = []
    i = 0
    while i < len(args):
        a = args[i]
        if a in ("--ks", "--ks-pass", "--ks-key-alias", "--key-pass", "--min-sdk-version", "--out"):
            opts[a] = args[i + 1]
            i += 2
        elif a.startswith("--"):
            i += 1
        else:
            pos.append(a)
            i += 1
    if cmd == "--version" or cmd == "version":
        print("0.9-v2only")
        return 0
    if cmd == "sign":
        pw = opts.get("--ks-pass", "pass:android")
        pw = pw[5:] if pw.startswith("pass:") else pw
        apk = pos[-1]
        if "--out" in opts:
            import shutil
            shutil.copyfile(apk, opts["--out"])
            apk = opts["--out"]
        sign(apk, opts["--ks"], pw)
        print("Signed")
        return 0
    if cmd == "verify":
        return 0 if verify(pos[-1]) else 1
    print("unsupported command " + cmd)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
