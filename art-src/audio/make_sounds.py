"""Every sound in Off the Books, synthesized (no samples, no third-party audio): footsteps, tools, the noise
ring, the drag scrape, the phone, the accident's impact and heartbeat, the stingers, room tone, the yard,
and two quiet music beds. Mono 16-bit WAV (the long *_loop beds as Ogg Vorbis, needs ffmpeg), written to
godot-house/assets/audio/.

    python3 art-src/audio/make_sounds.py            (numpy only; runs on the laptop in a few seconds)

Loops (names ending in _loop) are built to repeat without a click: their ends cross-fade into their starts.
"""
import os
import subprocess
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "godot-house", "assets", "audio")
rng = np.random.default_rng(7)


def t(seconds):
    return np.arange(int(seconds * SR)) / SR


def noise(seconds):
    return rng.standard_normal(int(seconds * SR))


def lp(x, cutoff):
    """Fast low-pass by FFT (brick wall with a soft shoulder)."""
    f = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    f *= 1 / (1 + (freqs / cutoff) ** 4)
    return np.fft.irfft(f, len(x))


def hp(x, cutoff):
    f = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / SR)
    f *= 1 / (1 + (cutoff / np.maximum(freqs, 1)) ** 4)
    return np.fft.irfft(f, len(x))


def env(n, attack, decay, sustain_level=0.0):
    """Attack (s) then an exponential decay (s time constant) towards sustain_level."""
    x = np.arange(n) / SR
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    d = sustain_level + (1 - sustain_level) * np.exp(-np.maximum(x - attack, 0) / decay)
    return a * d


def norm(x, peak=0.9):
    m = np.max(np.abs(x))
    return x / m * peak if m > 0 else x


def fade(x, inn=0.005, out=0.02):
    n_in, n_out = int(inn * SR), int(out * SR)
    x = x.copy()
    if n_in:
        x[:n_in] *= np.linspace(0, 1, n_in)
    if n_out:
        x[-n_out:] *= np.linspace(1, 0, n_out)
    return x


def loopable(x, overlap=0.5):
    """Cross-fade the tail into the head so the sound repeats seamlessly."""
    n = int(overlap * SR)
    head, tail = x[:n], x[-n:]
    w = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = head * w + tail * (1 - w)
    return x


def write(name, x, peak=0.9):
    os.makedirs(OUT, exist_ok=True)
    x = norm(np.asarray(x, dtype=np.float64), peak)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    if name.endswith("_loop"):            # long beds: Ogg Vorbis (a tenth of the size); Godot loops it
        path = os.path.join(OUT, name)
        subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-i", path + ".wav", "-c:a", "libvorbis",
                        "-q:a", "4", path + ".ogg"], check=True)
        os.remove(path + ".wav")
    print(f"{name}  {len(x) / SR:.2f} s")


# ---------------------------------------------------------------- footsteps and the house

def step(surface, i):
    n = int(0.16 * SR)
    knock = noise(0.16)
    if surface == "wood":
        body = lp(knock, 900 + 150 * i) * env(n, 0.002, 0.035)
        thump = np.sin(2 * np.pi * (95 + 12 * i) * t(0.16)) * env(n, 0.002, 0.04)
        return fade(body + 0.8 * thump)
    grit = hp(knock, 2500) * env(n, 0.001, 0.02) * 0.6
    tap = lp(knock, 1800) * env(n, 0.001, 0.03)
    return fade(grit + tap)


for s in ("wood", "stone"):
    for i in range(3):
        write(f"step_{s}_{i}", step(s, i), 0.5)

# the noise ring: a soft two-note chime that says "they heard that"
x = t(1.1)
ring = sum(np.sin(2 * np.pi * f * x) * a for f, a in ((880, 1.0), (1320, 0.5), (1760, 0.2)))
ring = ring * env(len(x), 0.004, 0.25)
ring2 = np.sin(2 * np.pi * 660 * x) * env(len(x), 0.004, 0.3)
ring = ring + np.concatenate([np.zeros(int(0.12 * SR)), ring2[:-int(0.12 * SR)]]) * 0.7
write("ring", fade(ring), 0.35)

# ---------------------------------------------------------------- tools

x = t(0.9)
drill = sum(np.sin(2 * np.pi * f * x * (1 + 0.01 * np.sin(2 * np.pi * 7 * x))) / k for k, f in enumerate((310, 620, 930, 1240), 1))
drill = (drill + 0.25 * hp(noise(0.9), 3000)) * env(len(x), 0.05, 5.0)
write("drill", fade(drill, 0.04, 0.1), 0.45)

n = int(0.35 * SR)
hit = lp(noise(0.35), 3000) * env(n, 0.0005, 0.02) + np.sin(2 * np.pi * 180 * t(0.35)) * env(n, 0.0005, 0.06)
ringing = np.sin(2 * np.pi * 2300 * t(0.35)) * env(n, 0.0005, 0.08) * 0.3
write("hammer", fade(hit + ringing), 0.7)

n = int(0.5 * SR)
pop = noise(0.5) * env(n, 0.0002, 0.012)
air = hp(noise(0.5), 1500) * env(n, 0.002, 0.07) * 0.4
thud = np.sin(2 * np.pi * 120 * t(0.5)) * env(n, 0.001, 0.05)
write("nailgun", fade(pop + air + thud), 0.9)

x = t(0.6)
screw = (np.sin(2 * np.pi * 70 * x) > 0).astype(float) * 0.3 + lp(noise(0.6), 2500) * 0.2
write("screwdriver", fade(screw * env(len(x), 0.02, 1.0), 0.02, 0.1), 0.25)

# dragging something heavy across boards: a rough, low scrape that loops
x = t(4.5)
scrape = lp(noise(4.5), 500) * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 0.9 * x)))
scrape += hp(lp(noise(4.5), 2500), 600) * 0.25 * (0.5 + 0.5 * np.sin(2 * np.pi * 1.7 * x) ** 2)
write("drag_loop", loopable(scrape), 0.5)

# his phone, buzzing on the floor
x = t(1.6)
buzz = np.sign(np.sin(2 * np.pi * 150 * x)) * 0.5 + np.sin(2 * np.pi * 300 * x) * 0.3
gate = ((x % 0.8) < 0.45).astype(float)
gate = lp(gate, 60)
write("phone", fade(lp(buzz, 1800) * gate, 0.01, 0.05), 0.4)

# ---------------------------------------------------------------- the accident

n = int(1.8 * SR)
x = t(1.8)
impact = lp(noise(1.8), 400) * env(n, 0.001, 0.12)
impact += np.sin(2 * np.pi * 55 * x) * env(n, 0.001, 0.25) * 1.2
impact += hp(noise(1.8), 1200) * env(n, 0.0005, 0.03) * 0.5
write("impact", fade(impact), 0.95)

x = t(3.2)
beat = np.zeros_like(x)
for k, at in enumerate((0.0, 0.32, 1.1, 1.42, 2.2, 2.52)):
    i = int(at * SR)
    m = len(x) - i
    b = np.sin(2 * np.pi * (48 if k % 2 == 0 else 42) * x[:m]) * env(m, 0.01, 0.07)
    beat[i:] += b * (1.0 if k % 2 == 0 else 0.7)
write("heartbeat", fade(lp(beat, 200), 0.005, 0.3), 0.9)

# stinger: a low cluster that swells and hangs (the discovery, the verdict)
x = t(4.5)
stinger = sum(np.sin(2 * np.pi * f * x + p) for f, p in ((55, 0), (82.4, 1), (87.3, 2), (130.8, 0.5), (138.6, 1.5)))
stinger += 0.3 * lp(noise(4.5), 300)
stinger *= env(len(x), 0.15, 1.6)
write("stinger", fade(stinger, 0.01, 0.6), 0.8)

# ---------------------------------------------------------------- beds

x = t(12.0)
tone = lp(noise(12.0), 180) * 0.5 + np.sin(2 * np.pi * 50 * x) * 0.03 + lp(noise(12.0), 1200) * 0.04
write("room_loop", loopable(tone, 1.0), 0.15)

yard = lp(noise(12.0), 900) * 0.25
for k in range(9):                        # a few birds: short chirps rising and falling
    at = rng.uniform(0.3, 10.5)
    i = int(at * SR)
    m = int(0.18 * SR)
    xx = np.arange(m) / SR
    f0 = rng.uniform(2600, 4200)
    chirp = np.sin(2 * np.pi * (f0 + 1800 * np.sin(np.pi * xx / 0.18)) * xx) * env(m, 0.01, 0.05)
    yard[i:i + m] += chirp * 0.35
write("yard_loop", loopable(yard, 1.0), 0.2)


def pad(chords, seconds_each, brightness, name, peak):
    """A slow, quiet chord bed: detuned sines with a gentle swell on each chord."""
    out = []
    for ch in chords:
        x = t(seconds_each)
        s = np.zeros_like(x)
        for f in ch:
            for det in (-0.6, 0.0, 0.7):
                s += np.sin(2 * np.pi * (f + det) * x) / len(ch)
                s += brightness * np.sin(2 * np.pi * 2 * (f + det) * x) / len(ch)
        s *= 0.55 + 0.45 * np.sin(np.pi * x / seconds_each) ** 2
        out.append(s)
    music = np.concatenate(out)
    write(name, loopable(lp(music, 1600), 1.5), peak)


# morning: warm, plain (C major, A minor, F, G); after the accident: low, unresolved
pad([(130.8, 164.8, 196.0), (110.0, 130.8, 164.8), (87.3, 110.0, 130.8), (98.0, 123.5, 146.8)], 6.0, 0.25, "music_day_loop", 0.25)
pad([(73.4, 87.3, 110.0), (69.3, 87.3, 103.8), (65.4, 77.8, 98.0), (69.3, 82.4, 103.8)], 7.0, 0.1, "music_tense_loop", 0.3)

# interface: a soft click
n = int(0.06 * SR)
write("click", fade(lp(noise(0.06), 3000) * env(n, 0.0005, 0.006)), 0.3)
