"""Synthesizes Duel sound samples in three styles (casino, cartoon, musical)."""
import os, subprocess, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out1')
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(SR * d)) / SR


def mix(length, *parts):
    """parts: (start_seconds, signal)."""
    out = np.zeros(int(SR * length))
    for start, sig in parts:
        i = int(SR * start)
        n = min(len(sig), len(out) - i)
        if n > 0:
            out[i:i + n] += sig[:n]
    return out


def biquad_bp(x, f, q):
    w = 2 * np.pi * f / SR
    a = np.sin(w) / (2 * q)
    b0, b1, b2 = a, 0, -a
    a0, a1, a2 = 1 + a, -2 * np.cos(w), 1 - a
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        y[i] = o
    return y


def lowpass(x, f):
    a = np.exp(-2 * np.pi * f / SR)
    y = np.zeros_like(x)
    p = 0.0
    for i, v in enumerate(x):
        p = (1 - a) * v + a * p
        y[i] = p
    return y


# --- Casino pieces -----------------------------------------------------------

def clack(bright=1.0, dur=0.07):
    """A clay chip hitting a chip: a click and two ceramic resonances."""
    n = rng.normal(size=int(SR * dur)) * np.exp(-t(dur) * 90)
    body = biquad_bp(n, 2600 * bright * rng.uniform(0.92, 1.08), 9) * 1.6
    ring = biquad_bp(n, 5200 * bright * rng.uniform(0.92, 1.08), 14) * 0.9
    click = np.zeros_like(n); click[:30] = rng.normal(size=30) * 0.6
    return (body + ring + click) * 0.9


def coin(f=None):
    f = f or rng.uniform(3800, 6200)
    x = t(0.35)
    s = sum(a * np.sin(2 * np.pi * f * r * x) for r, a in [(1, 1), (1.47, 0.6), (2.09, 0.35), (2.56, 0.25)])
    return s * np.exp(-x * 14) * 0.18


def swoosh(dur, f0, f1, amp=0.5):
    n = rng.normal(size=int(SR * dur))
    out = np.zeros_like(n)
    seg = 512
    for i in range(0, len(n), seg):
        k = i / len(n)
        f = f0 + (f1 - f0) * k
        out[i:i + seg] = biquad_bp(n[i:i + seg], f, 1.2)
    env = np.sin(np.pi * np.linspace(0, 1, len(n))) ** 1.5
    return out * env * amp


def thud(f=70, dur=0.35, amp=0.8):
    x = t(dur)
    fr = f * (1 + 1.5 * np.exp(-x * 30))
    ph = 2 * np.pi * np.cumsum(fr) / SR
    return np.sin(ph) * np.exp(-x * 9) * amp


def stack(n, span, bright=1.0, start=0.0):
    times = np.sort(rng.uniform(0, span, n))
    return [(start + tt, clack(bright) * rng.uniform(0.5, 1)) for tt in times]


casino = {
    'win_small': lambda: mix(0.6, *stack(4, 0.25)),
    'win_medium': lambda: mix(1.0, *stack(9, 0.45), (0.45, coin(5200)), (0.55, coin(6100))),
    'win_big': lambda: mix(2.2, *stack(10, 0.5), *[(0.3 + tt, coin()) for tt in np.sort(rng.uniform(0, 1.3, 32))]),
    'lose_small': lambda: mix(0.6, (0, lowpass(swoosh(0.4, 2400, 800, 0.6), 3000))),
    'lose_medium': lambda: mix(0.9, (0, swoosh(0.55, 3000, 700, 0.7)), *[(0.4 + tt, lowpass(clack(0.8), 2500)) for tt in (0, 0.07, 0.15)]),
    'lose_big': lambda: mix(1.4, (0, swoosh(0.8, 3200, 500, 0.8)), (0.55, thud(60)), *[(0.6 + tt, lowpass(clack(0.7), 2000)) for tt in (0, 0.06, 0.13, 0.22)]),
    'your_turn': lambda: mix(0.4, (0, clack(1.1)), (0.14, clack(1.1))),
    'tension': lambda: mix(1.6, *[(0.0 + 1.3 * (1 - (1 - k / 28) ** 1.6), clack(0.9) * (0.4 + 0.6 * k / 28)) for k in range(28)], (0, thud(48, 1.6, 0.25))),
    'clash': lambda: mix(1.0, (0, thud(80, 0.5, 0.9)), *stack(14, 0.55, 0.95)),
    'chips': lambda: mix(0.4, *stack(3, 0.12)),
    'pot': lambda: mix(1.0, (0, swoosh(0.4, 900, 2600, 0.4)), *stack(12, 0.5, start=0.25)),
}


# --- Cartoon pieces ------------------------------------------------------------

def note(f, dur, kind='pluck', amp=0.4):
    x = t(dur)
    if kind == 'pluck':
        s = np.sign(np.sin(2 * np.pi * f * x)) * 0.35 + np.sin(2 * np.pi * f * x) * 0.65
        env = np.exp(-x * 7) * np.minimum(1, x * 300)
    elif kind == 'saw':
        vib = 1 + 0.012 * np.sin(2 * np.pi * 5.5 * x)
        ph = np.cumsum(f * vib) / SR
        s = 2 * (ph % 1) - 1
        s = lowpass(s, 1800)
        env = np.minimum(1, x * 30) * np.minimum(1, (dur - x) * 8)
    else:
        s = np.sin(2 * np.pi * f * x)
        env = np.exp(-x * 5)
    return s * env * amp


def slide(f0, f1, dur, amp=0.35):
    x = t(dur)
    fr = f0 * (f1 / f0) ** (x / dur)
    fr = fr * (1 + 0.02 * np.sin(2 * np.pi * 7 * x))
    s = np.sin(2 * np.pi * np.cumsum(fr) / SR)
    return s * np.minimum(1, x * 40) * np.minimum(1, (dur - x) * 20) * amp


def boing(f=220, dur=0.5):
    x = t(dur)
    fr = f * (1 + 0.6 * np.exp(-x * 12) * np.cos(2 * np.pi * 14 * x))
    return np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-x * 5) * 0.45


def snare_roll(dur):
    n = rng.normal(size=int(SR * dur))
    x = t(dur)
    hits = 0.5 + 0.5 * np.sin(2 * np.pi * (14 + 10 * x / dur) * x)
    return biquad_bp(n, 2200, 0.8) * hits * (0.2 + 0.6 * x / dur) * 0.5


C5, D5, E5, F5, G5, A5, B5, C6, E6, G6 = 523.3, 587.3, 659.3, 698.5, 784, 880, 987.8, 1046.5, 1318.5, 1568
cartoon = {
    'win_small': lambda: mix(0.6, (0, note(C5, 0.2)), (0.09, note(E5, 0.2)), (0.18, note(G5, 0.35))),
    'win_medium': lambda: mix(1.1, (0, note(C5, 0.2)), (0.09, note(E5, 0.2)), (0.18, note(G5, 0.2)),
                              (0.32, note(C6, 0.6, amp=0.3)), (0.32, note(E5, 0.6, amp=0.2)), (0.32, note(G5, 0.6, amp=0.2))),
    'win_big': lambda: mix(2.0, (0, slide(300, 1200, 0.35)), *[(0.38 + i * 0.08, note(f, 0.25)) for i, f in enumerate([C5, E5, G5, C6, E6])],
                           *[(0.85 + i * 0.07, note(f, 0.9, amp=0.22)) for i, f in enumerate([C6, E6, G6])]),
    'lose_small': lambda: mix(0.7, (0, note(E5, 0.25)), (0.18, note(C5, 0.4))),
    'lose_medium': lambda: mix(0.9, (0, slide(900, 220, 0.75))),
    'lose_big': lambda: mix(2.4, (0, note(392, 0.42, 'saw', 0.35)), (0.45, note(370, 0.42, 'saw', 0.35)),
                            (0.9, note(349, 0.42, 'saw', 0.35)), (1.35, note(330, 1.0, 'saw', 0.35))),
    'your_turn': lambda: mix(0.6, (0, boing(330, 0.5))),
    'tension': lambda: mix(1.6, (0, snare_roll(1.5))),
    'clash': lambda: mix(0.8, (0, thud(160, 0.5, 0.8)), (0, lowpass(rng.normal(size=4000) * np.exp(-t(4000 / SR) * 60), 3000) * 0.6)),
    'chips': lambda: mix(0.45, *[(i * 0.07, note(f, 0.12, 'sine', 0.35)) for i, f in enumerate([E6, G6, E6])]),
    'pot': lambda: mix(1.0, *[(i * 0.045, note(400 * 1.12 ** i, 0.12, 'pluck', 0.3)) for i in range(14)]),
}


# --- Soft & musical ------------------------------------------------------------

def marimba(f, dur=0.8, amp=0.45):
    x = t(dur)
    s = np.sin(2 * np.pi * f * x) * np.exp(-x * 6) + 0.35 * np.sin(2 * np.pi * f * 3.93 * x) * np.exp(-x * 25) \
        + 0.15 * np.sin(2 * np.pi * f * 9.2 * x) * np.exp(-x * 60)
    return s * np.minimum(1, x * 600) * amp


def bell(f, dur=1.8, amp=0.3):
    x = t(dur)
    parts = [(1, 1, 2.2), (2.0, 0.55, 3), (2.76, 0.4, 4), (5.4, 0.25, 7), (8.9, 0.12, 10)]
    s = sum(a * np.sin(2 * np.pi * f * r * x) * np.exp(-x * d) for r, a, d in parts)
    return s * np.minimum(1, x * 800) * amp


def woodblock(f=1100):
    x = t(0.12)
    return (np.sin(2 * np.pi * f * x) + 0.4 * np.sin(2 * np.pi * f * 2.3 * x)) * np.exp(-x * 45) * 0.4


A4, C5m, Eb5, G4, F4, D4 = 440, 523.3, 622.3, 392, 349.2, 293.7
musical = {
    'win_small': lambda: mix(1.0, (0, marimba(G5)), (0.1, marimba(C6))),
    'win_medium': lambda: mix(1.4, *[(i * 0.09, marimba(f)) for i, f in enumerate([C5, E5, G5, C6])]),
    'win_big': lambda: mix(2.8, *[(i * 0.08, marimba(f, amp=0.35)) for i, f in enumerate([C5, E5, G5, C6, E6, G6])],
                           (0.55, bell(C6)), (0.65, bell(E6, amp=0.2)), (0.75, bell(G6, amp=0.18))),
    'lose_small': lambda: mix(1.0, (0, marimba(E5, amp=0.35)), (0.14, marimba(C5, amp=0.35))),
    'lose_medium': lambda: mix(1.3, (0, marimba(G5, amp=0.35)), (0.16, marimba(Eb5, amp=0.35)), (0.32, marimba(C5, amp=0.35))),
    'lose_big': lambda: mix(2.6, (0, bell(G4, 2.4, 0.25)), (0.35, bell(Eb5 / 2, 2.2, 0.22)), (0.7, bell(C5 / 2, 2.0, 0.3))),
    'your_turn': lambda: mix(1.4, (0, bell(E6, 1.2, 0.22)), (0.12, bell(C6 * 1.0, 1.2, 0.18))),
    'tension': lambda: mix(1.6, *[(i * 0.05, marimba(G4 * (1 + 0.0 * i), 0.3, 0.12 + 0.2 * i / 30)) for i in range(30)]),
    'clash': lambda: mix(1.0, (0, marimba(D4, 0.9, 0.5)), (0, marimba(D4 * 1.06, 0.9, 0.4)), (0, woodblock(700))),
    'chips': lambda: mix(0.4, (0, woodblock(1300)), (0.08, woodblock(1500))),
    'pot': lambda: mix(1.2, *[(i * 0.04, marimba(f, 0.5, 0.25)) for i, f in enumerate([C5, D5, E5, G5, A5, C6, D5 * 2, E6])]),
}


def save(name, sig):
    sig = sig / max(1e-6, np.abs(sig).max()) * 0.85
    pcm = (sig * 32767).astype(np.int16)
    wav = os.path.join(OUT, name + '.wav')
    with wave.open(wav, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-codec:a', 'libmp3lame', '-b:a', '96k', wav[:-4] + '.mp3'], check=True)
    os.remove(wav)


os.makedirs(OUT, exist_ok=True)
for style, sounds in [('casino', casino), ('cartoon', cartoon), ('musical', musical)]:
    for name, make in sounds.items():
        save(f'{style}_{name}', make())
print(len(os.listdir(OUT)), 'files')
