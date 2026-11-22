"""Gentler Duel sound samples: five soft styles. Short, rounded attacks,
nothing harsh or buzzy, quieter peaks."""
import os, subprocess, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out2')
rng = np.random.default_rng(11)


def t(d):
    return np.arange(int(SR * d)) / SR


def mix(length, *parts):
    out = np.zeros(int(SR * length))
    for start, sig in parts:
        i = int(SR * start)
        n = min(len(sig), len(out) - i)
        if n > 0:
            out[i:i + n] += sig[:n]
    return out


def lowpass(x, f):
    a = np.exp(-2 * np.pi * f / SR)
    y = np.zeros_like(x)
    p = 0.0
    for i, v in enumerate(x):
        p = (1 - a) * v + a * p
        y[i] = p
    return y


def soft_env(x, attack=0.006, decay=6.0):
    return np.minimum(1, x / attack) * np.exp(-x * decay)


# Notes (C major / pentatonic)
N = {'G4': 392.0, 'A4': 440.0, 'C5': 523.3, 'D5': 587.3, 'E5': 659.3, 'G5': 784.0, 'A5': 880.0,
     'C6': 1046.5, 'D6': 1174.7, 'E6': 1318.5, 'G6': 1568.0, 'Eb5': 622.3, 'F4': 349.2, 'D4': 293.7, 'C4': 261.6,
     'A3': 220.0, 'E4': 329.6, 'Bb4': 466.2}


# --- Instruments -------------------------------------------------------------------

def chime(f, dur=1.4, amp=0.3):
    """Soft glass chime: pure partials, slow-ish attack, long gentle decay."""
    x = t(dur)
    s = np.sin(2 * np.pi * f * x) + 0.25 * np.sin(2 * np.pi * f * 2.0 * x) * np.exp(-x * 3) \
        + 0.12 * np.sin(2 * np.pi * f * 3.01 * x) * np.exp(-x * 6)
    return s * soft_env(x, 0.008, 2.6) * amp


def kalimba(f, dur=0.9, amp=0.35):
    x = t(dur)
    s = np.sin(2 * np.pi * f * x) + 0.3 * np.sin(2 * np.pi * f * 5.4 * x) * np.exp(-x * 40) \
        + 0.15 * np.sin(2 * np.pi * f * 2.0 * x) * np.exp(-x * 8)
    return s * soft_env(x, 0.003, 4.5) * amp


def keys(f, dur=1.0, amp=0.32):
    """Warm electric piano: sine + soft bell overtone, gentle tremolo, low-passed."""
    x = t(dur)
    trem = 1 + 0.08 * np.sin(2 * np.pi * 5 * x)
    s = (np.sin(2 * np.pi * f * x) + 0.4 * np.sin(2 * np.pi * f * 2 * x) * np.exp(-x * 4)
         + 0.1 * np.sin(2 * np.pi * f * 7 * x) * np.exp(-x * 20)) * trem
    return lowpass(s * soft_env(x, 0.005, 3.2), 3500) * amp


def tap(f=420, dur=0.12, amp=0.4):
    """A muted wooden tap on felt."""
    x = t(dur)
    s = np.sin(2 * np.pi * f * x) + 0.3 * np.sin(2 * np.pi * f * 1.9 * x)
    n = rng.normal(size=len(x)) * np.exp(-x * 120) * 0.25
    return lowpass((s * np.exp(-x * 38) + n), 2200) * amp


def chip_soft(amp=0.35):
    """A clay chip set down gently: a soft, rounded click."""
    x = t(0.06)
    n = rng.normal(size=len(x)) * np.exp(-x * 140)
    body = np.sin(2 * np.pi * rng.uniform(1700, 2100) * x) * np.exp(-x * 90)
    return lowpass(n * 0.4 + body * 0.8, 4500) * amp


def pop(f=600, dur=0.14, amp=0.35):
    """A soft bubble pop: a sine gliding down quickly."""
    x = t(dur)
    fr = f * (1 + 0.8 * np.exp(-x * 60))
    s = np.sin(2 * np.pi * np.cumsum(fr) / SR)
    return s * soft_env(x, 0.002, 28) * amp


def hum(f, dur, amp=0.12):
    x = t(dur)
    return np.sin(2 * np.pi * f * x) * np.minimum(1, x / 0.3) * np.minimum(1, (dur - x) / 0.3) * amp


def heartbeat(dur=1.5, amp=0.5):
    """Two soft low thumps, twice: suspense without a sting."""
    out = []
    for k, start in enumerate([0.0, 0.18, 0.75, 0.93]):
        x = t(0.25)
        fr = 55 * (1 + 0.6 * np.exp(-x * 30))
        s = np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-x * 14) * (amp if k % 2 == 0 else amp * 0.7)
        out.append((start, s))
    return mix(dur, *out)


def softthud(amp=0.5):
    x = t(0.4)
    fr = 90 * (1 + 0.7 * np.exp(-x * 25))
    return lowpass(np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-x * 10), 900) * amp


def arp(inst, notes, gap, length, **kw):
    return mix(length, *[(i * gap, inst(N[n], **kw)) for i, n in enumerate(notes)])


# --- Styles ------------------------------------------------------------------------------

styles = {
    'chimes': {
        'win_small': lambda: arp(chime, ['E6', 'G6'], 0.09, 1.4),
        'win_medium': lambda: arp(chime, ['C6', 'E6', 'G6'], 0.09, 1.6),
        'win_big': lambda: arp(chime, ['C6', 'D6', 'E6', 'G6', 'C6'], 0.08, 2.0, amp=0.26) + mix(2.0, (0.45, chime(N['G6'] * 2, 1.4, 0.12))),
        'lose_small': lambda: arp(chime, ['E5'], 0.1, 1.2, amp=0.22),
        'lose_medium': lambda: arp(chime, ['G5', 'E5'], 0.16, 1.4, amp=0.22),
        'lose_big': lambda: arp(chime, ['G5', 'E5', 'C5'], 0.2, 1.8, amp=0.22),
        'your_turn': lambda: arp(chime, ['G5', 'C6'], 0.12, 1.3, amp=0.24),
        'tension': lambda: mix(1.6, (0, hum(N['G4'] / 2, 1.5, 0.1)), *[(i * 0.3, chime(N['G5'], 0.5, 0.06 + 0.03 * i)) for i in range(5)]),
        'clash': lambda: mix(1.0, (0, softthud(0.4)), (0.02, chime(N['C5'], 0.8, 0.15))),
        'chips': lambda: mix(0.4, (0, chip_soft()), (0.07, chip_soft(0.28))),
        'pot': lambda: mix(1.0, *[(i * 0.05, chip_soft(0.3)) for i in range(6)], (0.32, chime(N['E6'], 0.9, 0.14))),
    },
    'kalimba': {
        'win_small': lambda: arp(kalimba, ['C5', 'E5'], 0.1, 1.0),
        'win_medium': lambda: arp(kalimba, ['C5', 'E5', 'G5', 'C6'], 0.09, 1.2),
        'win_big': lambda: arp(kalimba, ['C5', 'D5', 'E5', 'G5', 'A5', 'C6', 'E6'], 0.075, 1.6),
        'lose_small': lambda: arp(kalimba, ['E5', 'D5'], 0.13, 1.0, amp=0.28),
        'lose_medium': lambda: arp(kalimba, ['G5', 'E5', 'D5'], 0.14, 1.2, amp=0.28),
        'lose_big': lambda: arp(kalimba, ['A5', 'G5', 'E5', 'C5'], 0.17, 1.6, amp=0.28),
        'your_turn': lambda: arp(kalimba, ['G5'], 0.1, 0.9, amp=0.33),
        'tension': lambda: mix(1.6, *[(i * 0.12, kalimba(N['D5'] if i % 2 else N['C5'], 0.4, 0.06 + 0.014 * i)) for i in range(12)]),
        'clash': lambda: mix(1.0, (0, softthud(0.4)), (0, kalimba(N['C4'], 0.8, 0.3))),
        'chips': lambda: mix(0.4, (0, tap(700, amp=0.3)), (0.07, tap(760, amp=0.25))),
        'pot': lambda: arp(kalimba, ['G4', 'C5', 'E5', 'G5'], 0.05, 1.0, amp=0.25),
    },
    'keys': {
        'win_small': lambda: arp(keys, ['E5', 'G5'], 0.11, 1.1),
        'win_medium': lambda: arp(keys, ['C5', 'E5', 'G5'], 0.11, 1.3) + mix(1.3, (0.33, keys(N['C6'], 1.0, 0.18))),
        'win_big': lambda: mix(2.0, (0, keys(N['C5'], 1.6, 0.2)), (0, keys(N['E5'], 1.6, 0.18)), (0, keys(N['G5'], 1.6, 0.18)),
                               *[(0.3 + i * 0.1, keys(N[n], 1.0, 0.18)) for i, n in enumerate(['C6', 'D6', 'E6', 'G6'])]),
        'lose_small': lambda: arp(keys, ['D5', 'C5'], 0.16, 1.1, amp=0.24),
        'lose_medium': lambda: arp(keys, ['E5', 'D5', 'A4'], 0.17, 1.3, amp=0.24),
        'lose_big': lambda: mix(2.0, (0, keys(N['A4'], 1.8, 0.2)), (0, keys(N['C5'], 1.8, 0.16)), (0, keys(N['E5'], 1.8, 0.14)),
                                (0.45, keys(N['G4'], 1.4, 0.18)), (0.45, keys(N['Bb4'], 1.4, 0.14))),
        'your_turn': lambda: arp(keys, ['C6'], 0.1, 1.0, amp=0.26),
        'tension': lambda: mix(1.6, (0, keys(N['A3'], 1.6, 0.16)), (0, keys(N['E4'], 1.6, 0.12))),
        'clash': lambda: mix(1.0, (0, softthud(0.45)), (0, keys(N['D4'], 0.8, 0.22)), (0, keys(N['F4'] * 1.0, 0.8, 0.15))),
        'chips': lambda: mix(0.4, (0, chip_soft()), (0.08, chip_soft(0.3)), (0.13, chip_soft(0.24))),
        'pot': lambda: mix(1.0, *[(i * 0.045, chip_soft(0.28)) for i in range(7)], (0.3, keys(N['G5'], 0.7, 0.15))),
    },
    'felt': {
        'win_small': lambda: mix(0.6, (0, tap(520)), (0.09, tap(660))),
        'win_medium': lambda: mix(0.8, (0, tap(520)), (0.08, tap(620)), (0.16, tap(780)), *[(0.28 + i * 0.05, chip_soft(0.3)) for i in range(4)]),
        'win_big': lambda: mix(1.4, *[(i * 0.07, tap(f)) for i, f in enumerate([520, 620, 700, 780, 1040])], *[(0.4 + i * 0.045, chip_soft(0.28)) for i in range(10)]),
        'lose_small': lambda: mix(0.5, (0, tap(380, amp=0.3))),
        'lose_medium': lambda: mix(0.6, (0, tap(440, amp=0.3)), (0.12, tap(340, amp=0.3))),
        'lose_big': lambda: mix(0.9, (0, tap(440, amp=0.3)), (0.14, tap(370, amp=0.3)), (0.28, tap(300, amp=0.3)), (0.3, softthud(0.25))),
        'your_turn': lambda: mix(0.5, (0, tap(700, amp=0.35)), (0.13, tap(700, amp=0.3))),
        'tension': lambda: heartbeat(1.5, 0.45),
        'clash': lambda: mix(0.6, (0, softthud(0.5)), (0, tap(260, amp=0.3))),
        'chips': lambda: mix(0.4, (0, chip_soft()), (0.07, chip_soft(0.3))),
        'pot': lambda: mix(0.9, *[(i * 0.05 + rng.uniform(0, 0.02), chip_soft(0.3)) for i in range(9)]),
    },
    'bubbles': {
        'win_small': lambda: mix(0.5, (0, pop(600)), (0.08, pop(800))),
        'win_medium': lambda: mix(0.7, *[(i * 0.08, pop(f)) for i, f in enumerate([600, 750, 900, 1200])]),
        'win_big': lambda: mix(1.4, *[(i * 0.065, pop(f)) for i, f in enumerate([600, 700, 800, 900, 1000, 1200, 1400])], (0.5, chime(N['C6'], 0.9, 0.12))),
        'lose_small': lambda: mix(0.5, (0, pop(500, amp=0.28)), (0.12, pop(380, amp=0.28))),
        'lose_medium': lambda: mix(0.7, *[(i * 0.13, pop(f, amp=0.28)) for i, f in enumerate([520, 420, 330])]),
        'lose_big': lambda: mix(1.0, *[(i * 0.15, pop(f, 0.2, 0.28)) for i, f in enumerate([520, 440, 360, 280])]),
        'your_turn': lambda: mix(0.4, (0, pop(900, amp=0.32))),
        'tension': lambda: mix(1.6, *[(i * 0.11, pop(300 + i * 25, amp=0.08 + 0.015 * i)) for i in range(14)]),
        'clash': lambda: mix(0.6, (0, softthud(0.45)), (0.02, pop(250, 0.2, 0.3))),
        'chips': lambda: mix(0.4, (0, pop(1100, amp=0.25)), (0.06, pop(1250, amp=0.22))),
        'pot': lambda: mix(0.9, *[(i * 0.045, pop(700 + 60 * i, amp=0.2)) for i in range(10)]),
    },
}


def save(name, sig):
    # Quieter than before: a gentle peak.
    sig = sig / max(1e-6, np.abs(sig).max()) * 0.6
    fade = min(len(sig), int(SR * 0.04))
    sig[-fade:] *= np.linspace(1, 0, fade)
    pcm = (sig * 32767).astype(np.int16)
    wav = os.path.join(OUT, name + '.wav')
    with wave.open(wav, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-codec:a', 'libmp3lame', '-b:a', '96k', wav[:-4] + '.mp3'], check=True)
    os.remove(wav)


os.makedirs(OUT, exist_ok=True)
for style, sounds in styles.items():
    for name, make in sounds.items():
        save(f'{style}_{name}', make())
print(len(os.listdir(OUT)), 'files')
