"""Deterministic chiptune SFX + music for Hexvault.

Usage: python tools/audiogen/build.py
Writes assets/audio/sfx/*.wav (22.05 kHz mono 16-bit) and assets/audio/music/*.ogg
(music is rendered to WAV then encoded with ffmpeg/libvorbis if available; otherwise
the WAV is kept and the game falls back to it).
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import wave

import numpy as np

SR = 22050
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "audio")
RNG = np.random.default_rng(1337)


# --- oscillators -----------------------------------------------------------
def t_of(dur: float) -> np.ndarray:
    return np.arange(int(SR * dur)) / SR


def phase(freq) -> np.ndarray:
    """Integrate a (possibly time-varying) frequency array into phase (cycles)."""
    return np.cumsum(np.asarray(freq, dtype=np.float64)) / SR


def square(freq, duty: float = 0.5) -> np.ndarray:
    ph = phase(freq) % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def tri(freq) -> np.ndarray:
    ph = phase(freq) % 1.0
    return 4.0 * np.abs(ph - 0.5) - 1.0


def saw(freq) -> np.ndarray:
    ph = phase(freq) % 1.0
    return 2.0 * ph - 1.0


def noise(n: int, hold: int = 1) -> np.ndarray:
    base = RNG.uniform(-1, 1, n // hold + 1)
    return np.repeat(base, hold)[:n]


def env(n: int, a: float = 0.005, d: float = 0.1, s: float = 0.0, r: float = 0.05, total: float | None = None) -> np.ndarray:
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    sus_n = max(0, n - a_n - d_n - r_n)
    e = np.concatenate([
        np.linspace(0, 1, max(a_n, 1)), np.linspace(1, s, max(d_n, 1)),
        np.full(sus_n, s), np.linspace(s, 0, max(r_n, 1)),
    ])
    if len(e) < n:
        e = np.concatenate([e, np.zeros(n - len(e))])
    return e[:n]


def sweep(f0: float, f1: float, n: int, curve: float = 1.0) -> np.ndarray:
    x = np.linspace(0, 1, n) ** curve
    return f0 * (f1 / f0) ** x


def lowpass(x: np.ndarray, k: float) -> np.ndarray:
    """One-pole lowpass, k in (0,1]: smaller = darker."""
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += k * (v - acc)
        y[i] = acc
    return y


def mix(*parts: np.ndarray) -> np.ndarray:
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def norm(x: np.ndarray, peak: float = 0.8) -> np.ndarray:
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def write_wav(path: str, x: np.ndarray) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data.tobytes())


# --- sound effects -----------------------------------------------------------
def sfx_defs() -> dict[str, np.ndarray]:
    S = {}
    n = int(0.12 * SR)
    S["shoot_pistol"] = norm(square(sweep(900, 220, n, 0.6), 0.25) * env(n, 0.001, 0.1, 0, 0.02) * 0.6
                             + noise(n, 2) * env(n, 0.001, 0.03, 0, 0.01) * 0.4, 0.55)
    n = int(0.28 * SR)
    S["shoot_shotgun"] = norm(lowpass(noise(n, 1), 0.35) * env(n, 0.001, 0.25, 0, 0.03)
                              + square(sweep(180, 60, n), 0.5) * env(n, 0.001, 0.12, 0, 0.02) * 0.5, 0.7)
    n = int(0.08 * SR)
    S["shoot_rifle"] = norm(square(sweep(1200, 400, n), 0.3) * env(n, 0.001, 0.07, 0, 0.01)
                            + noise(n, 3) * env(n, 0.001, 0.02, 0, 0.01) * 0.3, 0.45)
    n = int(0.4 * SR)
    S["shoot_sniper"] = norm(saw(sweep(1600, 90, n, 0.4)) * env(n, 0.001, 0.35, 0, 0.04)
                             + lowpass(noise(n), 0.5) * env(n, 0.001, 0.1, 0, 0.02) * 0.7, 0.75)
    n = int(0.06 * SR)
    S["shoot_needle"] = norm(tri(sweep(2400, 1500, n)) * env(n, 0.001, 0.05, 0, 0.01), 0.35)
    n = int(0.16 * SR)
    S["bow"] = norm(tri(sweep(300, 700, n)) * env(n, 0.002, 0.14, 0, 0.02)
                    + noise(n, 4) * env(n, 0.001, 0.05, 0, 0.01) * 0.25, 0.5)
    n = int(0.14 * SR)
    S["swing"] = norm(lowpass(noise(n, 1), 0.25) * env(n, 0.02, 0.1, 0, 0.02), 0.55)
    n = int(0.22 * SR)
    S["magic"] = norm((tri(sweep(500, 1300, n)) + 0.5 * square(sweep(750, 1950, n), 0.5)) * env(n, 0.005, 0.2, 0, 0.02), 0.45)
    n = int(0.35 * SR)
    S["rocket"] = norm(lowpass(noise(n), 0.2) * env(n, 0.01, 0.3, 0.2, 0.05)
                       + square(sweep(120, 260, n), 0.5) * env(n, 0.005, 0.2, 0, 0.05) * 0.4, 0.6)
    n = int(0.7 * SR)
    S["explosion"] = norm(lowpass(noise(n, 2), 0.18) * env(n, 0.001, 0.6, 0, 0.1)
                          + square(sweep(90, 30, n), 0.5) * env(n, 0.001, 0.3, 0, 0.05) * 0.6, 0.85)
    n = int(0.07 * SR)
    S["laser"] = norm(square(np.full(n, 1400.0) + 200 * np.sin(np.arange(n) / SR * 2 * np.pi * 60), 0.5)
                      * env(n, 0.001, 0.06, 0, 0.01), 0.3)
    n = int(0.2 * SR)
    S["zap"] = norm(square(1800 + 900 * noise(n, 40), 0.5) * env(n, 0.001, 0.18, 0, 0.02), 0.4)
    n = int(0.07 * SR)
    S["hit"] = norm(square(sweep(500, 120, n), 0.5) * env(n, 0.001, 0.06, 0, 0.01)
                    + noise(n, 2) * env(n, 0.001, 0.03, 0, 0.01) * 0.5, 0.5)
    n = int(0.12 * SR)
    S["crit"] = norm(square(sweep(1400, 300, n), 0.25) * env(n, 0.001, 0.1, 0, 0.01)
                     + tri(np.full(n, 2093.0)) * env(n, 0.001, 0.08, 0, 0.01) * 0.6, 0.55)
    n = int(0.3 * SR)
    S["enemy_die"] = norm(square(sweep(600, 70, n, 0.7), 0.5) * env(n, 0.001, 0.28, 0, 0.02)
                          + lowpass(noise(n, 3), 0.4) * env(n, 0.001, 0.15, 0, 0.02) * 0.6, 0.6)
    n = int(0.3 * SR)
    S["player_hurt"] = norm(square(sweep(400, 90, n), 0.5) * env(n, 0.001, 0.26, 0, 0.03)
                            + noise(n, 6) * env(n, 0.001, 0.12, 0, 0.02) * 0.6, 0.75)
    n = int(1.2 * SR)
    S["player_die"] = norm(square(sweep(440, 40, n, 0.6), 0.5) * env(n, 0.001, 1.1, 0, 0.1)
                           + tri(sweep(220, 30, n)) * env(n, 0.001, 1.1, 0, 0.1) * 0.6, 0.75)
    n = int(0.12 * SR)
    coin_f = np.concatenate([np.full(n // 3, 1318.0), np.full(n - n // 3, 1760.0)])
    S["coin"] = norm(square(coin_f, 0.5) * env(n, 0.001, 0.11, 0, 0.01), 0.35)
    n = int(0.25 * SR)
    S["shard"] = norm((tri(sweep(880, 1760, n)) + 0.5 * tri(sweep(1320, 2640, n))) * env(n, 0.001, 0.22, 0, 0.02), 0.45)
    n = int(0.4 * SR)
    arp = np.concatenate([np.full(n // 4, f) for f in (523.0, 659.0, 784.0, 1046.0)])
    S["heal"] = norm(tri(arp) * env(len(arp), 0.005, 0.35, 0.2, 0.05), 0.5)
    n = int(0.5 * SR)
    arp = np.concatenate([np.full(n // 5, f) for f in (392.0, 523.0, 659.0, 784.0, 1046.0)])
    S["chest"] = norm(square(arp, 0.25) * env(len(arp), 0.002, 0.45, 0.3, 0.05), 0.45)
    n = int(0.35 * SR)
    S["door_lock"] = norm(square(sweep(220, 110, n), 0.5) * env(n, 0.001, 0.3, 0.2, 0.05)
                          + square(sweep(225, 112, n), 0.5) * env(n, 0.001, 0.3, 0.2, 0.05), 0.5)
    n = int(0.45 * SR)
    arp = np.concatenate([np.full(n // 3, f) for f in (330.0, 440.0, 660.0)])
    S["door_open"] = norm(tri(arp) * env(len(arp), 0.002, 0.4, 0.3, 0.05), 0.5)
    n = int(0.15 * SR)
    S["dash"] = norm(lowpass(noise(n, 1), 0.5) * env(n, 0.005, 0.13, 0, 0.01)
                     + tri(sweep(300, 900, n)) * env(n, 0.001, 0.1, 0, 0.01) * 0.3, 0.45)
    n = int(0.5 * SR)
    S["skill"] = norm((square(sweep(200, 800, n), 0.5) + tri(sweep(400, 1600, n))) * env(n, 0.01, 0.45, 0, 0.05), 0.55)
    n = int(0.04 * SR)
    S["ui_click"] = norm(square(np.full(n, 1046.0), 0.5) * env(n, 0.001, 0.035, 0, 0.005), 0.3)
    n = int(0.03 * SR)
    S["ui_move"] = norm(square(np.full(n, 784.0), 0.25) * env(n, 0.001, 0.025, 0, 0.005), 0.2)
    n = int(0.12 * SR)
    S["ui_deny"] = norm(square(np.full(n, 140.0), 0.5) * env(n, 0.001, 0.1, 0, 0.01), 0.4)
    n = int(1.4 * SR)
    S["boss_roar"] = norm(lowpass(saw(sweep(70, 45, n)) + 0.6 * noise(n, 8), 0.3) * env(n, 0.05, 1.2, 0.3, 0.2), 0.85)
    n = int(1.0 * SR)
    S["boss_phase"] = norm((square(sweep(100, 800, n, 2.0), 0.5) + lowpass(noise(n, 2), 0.3)) * env(n, 0.01, 0.9, 0, 0.1), 0.75)
    n = int(0.25 * SR)
    S["telegraph"] = norm(square(np.full(n, 880.0), 0.5) * (np.sin(np.arange(n) / SR * 2 * np.pi * 24) > 0)
                          * env(n, 0.001, 0.24, 0.5, 0.01), 0.35)
    n = int(0.35 * SR)
    S["reload"] = norm(mix(square(np.full(int(0.05 * SR), 600.0), 0.5) * env(int(0.05 * SR), 0.001, 0.04, 0, 0.005),
                           np.concatenate([np.zeros(int(0.22 * SR)),
                                           square(np.full(int(0.06 * SR), 900.0), 0.5) * env(int(0.06 * SR), 0.001, 0.05, 0, 0.005)])), 0.35)
    n = int(0.05 * SR)
    S["empty"] = norm(square(np.full(n, 200.0), 0.5) * env(n, 0.001, 0.04, 0, 0.005), 0.25)
    n = int(0.6 * SR)
    arp = np.concatenate([np.full(n // 6, f) for f in (523.0, 659.0, 784.0, 659.0, 784.0, 1046.0)])
    S["boon"] = norm(tri(arp) * env(len(arp), 0.002, 0.55, 0.3, 0.05) + 0.4 * square(arp * 2, 0.125) * env(len(arp), 0.002, 0.3, 0, 0.05), 0.5)
    n = int(1.0 * SR)
    S["portal"] = norm((tri(sweep(200, 1200, n, 1.5)) + 0.5 * tri(sweep(300, 1800, n, 1.5))) * env(n, 0.05, 0.9, 0, 0.05), 0.5)
    n = int(0.4 * SR)
    S["spawn"] = norm(tri(sweep(1200, 300, n)) * env(n, 0.01, 0.38, 0, 0.02) * (0.6 + 0.4 * square(np.full(n, 30.0))), 0.35)
    n = int(0.25 * SR)
    S["crate_break"] = norm(lowpass(noise(n, 4), 0.4) * env(n, 0.001, 0.22, 0, 0.02), 0.55)
    n = int(0.9 * SR)
    arp = np.concatenate([np.full(n // 6, f) for f in (392.0, 523.0, 659.0, 784.0, 1046.0, 1318.0)])
    S["victory"] = norm(square(arp, 0.25) * env(len(arp), 0.002, 0.8, 0.4, 0.1) + 0.5 * tri(arp / 2), 0.55)
    n = int(0.3 * SR)
    S["buy"] = norm(square(np.concatenate([np.full(n // 2, 988.0), np.full(n - n // 2, 1318.0)]), 0.5)
                    * env(n, 0.001, 0.28, 0.2, 0.02), 0.4)
    return S


# --- music ---------------------------------------------------------------------
NOTE = {n: i for i, n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def hz(name: str) -> float:
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTE[pitch] + 12 * (octave + 1) - 69) / 12)


def render_track(bpm: float, chords: list[list[str]], bass_oct: int, lead_scale: list[str], seed: int,
                 bars_per_chord: int = 1, lead_density: float = 0.6, drums: str = "four",
                 lead_wave: str = "square", repeats: int = 2) -> np.ndarray:
    rng = np.random.default_rng(seed)
    step = 60.0 / bpm / 4  # 16th note
    steps_per_bar = 16
    total_steps = len(chords) * bars_per_chord * steps_per_bar
    n_total = int(total_steps * step * SR)
    out = np.zeros(n_total + SR)
    sn = int(step * SR)

    def place(sig: np.ndarray, at_step: int, gain: float) -> None:
        i = int(at_step * step * SR)
        out[i:i + len(sig)] += sig[: len(out) - i] * gain

    # precompose a lead motif per chord, repeated (gives a hummable phrase)
    motif_cache: dict[int, list] = {}
    for ci, chord in enumerate(chords):
        root = chord[0]
        for b in range(bars_per_chord):
            bar0 = (ci * bars_per_chord + b) * steps_per_bar
            # bass: root on 1 and 3, fifth pickups
            for s in range(0, 16, 2):
                note = root if s % 8 == 0 else (chord[1] if s % 8 == 4 else root)
                f = hz(note[:-1] + str(bass_oct))
                sig = tri(np.full(sn * 2, f)) * env(sn * 2, 0.002, step * 1.6, 0.3, 0.02)
                place(sig, bar0 + s, 0.42)
            # arpeggio pad (quiet pulse)
            for s in range(16):
                note = chord[s % len(chord)]
                sig = square(np.full(sn, hz(note)), 0.125) * env(sn, 0.001, step * 0.8, 0, 0.005)
                place(sig, bar0 + s, 0.07)
            # lead
            key = ci % 4
            if key not in motif_cache:
                mot = []
                s = 0
                while s < 16:
                    length = int(rng.choice([2, 2, 4, 1, 3]))
                    if rng.random() < lead_density:
                        mot.append((s, length, int(rng.integers(0, len(lead_scale)))))
                    s += length
                motif_cache[key] = mot
            for (s, length, idx) in motif_cache[key]:
                f = hz(lead_scale[idx])
                ln = sn * length
                vib = f * (1 + 0.006 * np.sin(np.arange(ln) / SR * 2 * np.pi * 6))
                wavef = square(vib, 0.25) if lead_wave == "square" else tri(vib)
                sig = wavef * env(ln, 0.004, step * length * 0.7, 0.4, 0.03)
                place(sig, bar0 + s, 0.16 if lead_wave == "square" else 0.24)
            # drums
            for s in range(16):
                kick = (drums == "four" and s % 4 == 0) or (drums == "half" and s in (0, 10)) or (drums == "drive" and s in (0, 3, 8, 11))
                snare = s in (4, 12)
                hat = s % 2 == 0
                if kick:
                    kn = int(0.12 * SR)
                    place(np.sin(2 * np.pi * phase(sweep(140, 45, kn))) * env(kn, 0.001, 0.11, 0, 0.01), bar0 + s, 0.55)
                if snare and drums != "none":
                    nn = int(0.1 * SR)
                    place(lowpass(noise(nn, 1), 0.6) * env(nn, 0.001, 0.09, 0, 0.01), bar0 + s, 0.22)
                if hat and drums != "none":
                    hn = int(0.03 * SR)
                    place(noise(hn, 1) * env(hn, 0.001, 0.025, 0, 0.004), bar0 + s, 0.06)
    loop = out[:n_total]
    # crossfade the tail spill into the head so the loop is seamless
    tail = out[n_total:n_total + int(0.2 * SR)]
    loop[: len(tail)] += tail
    full = np.tile(loop, repeats)
    return norm(full, 0.7)


def music_defs() -> dict[str, np.ndarray]:
    return {
        "hub": render_track(92, [["A3", "C4", "E4"], ["F3", "A3", "C4"], ["C3", "E3", "G3"], ["G3", "B3", "D4"]],
                            2, ["A4", "C5", "D5", "E5", "G5", "A5"], 11, 2, 0.45, "half", "tri", 1),
        "dungeon": render_track(128, [["D3", "F3", "A3"], ["A#2", "D3", "F3"], ["C3", "E3", "G3"], ["A2", "C#3", "E3"]],
                                2, ["D5", "E5", "F5", "A5", "C6", "D6"], 23, 2, 0.6, "four", "square", 1),
        "boss": render_track(150, [["E3", "G3", "B3"], ["C3", "E3", "G3"], ["D3", "F#3", "A3"], ["B2", "D#3", "F#3"]],
                             2, ["E5", "F#5", "G5", "B5", "D6", "E6"], 37, 2, 0.75, "drive", "square", 1),
    }


def main() -> None:
    meta = {"sfx": {}, "music": {}}
    for name, x in sfx_defs().items():
        p = os.path.join(OUT, "sfx", name + ".wav")
        write_wav(p, x)
        meta["sfx"][name] = "res://assets/audio/sfx/%s.wav" % name
    ffmpeg = shutil.which("ffmpeg")
    for name, x in music_defs().items():
        wav = os.path.join(OUT, "music", name + ".wav")
        write_wav(wav, x)
        if ffmpeg:
            ogg = os.path.join(OUT, "music", name + ".ogg")
            r = subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4",
                                "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact", ogg])
            if r.returncode == 0:
                os.remove(wav)
                meta["music"][name] = "res://assets/audio/music/%s.ogg" % name
                continue
        meta["music"][name] = "res://assets/audio/music/%s.wav" % name
    with open(os.path.join(OUT, "audio_manifest.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(meta, f, indent=1, sort_keys=True)
        f.write("\n")
    print("sfx=%d music=%d" % (len(meta["sfx"]), len(meta["music"])))


if __name__ == "__main__":
    main()
