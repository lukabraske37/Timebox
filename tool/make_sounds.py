"""Builds the alarm sounds in assets/sounds from nothing but arithmetic.

Every sound is synthesised here, so there is no recording to license and
nothing to download. Run it with numpy and ffmpeg installed:

    python tool/make_sounds.py

Each sound ends in a short silence, because Android plays an alarm's sound in
a loop until it is answered and the loop needs somewhere to breathe.
"""

import os
import subprocess
import tempfile
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')


def silence(seconds):
    return np.zeros(int(RATE * seconds))


def times(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def fade(x, attack=0.004, release=0.01):
    """Ramp the ends so a tone starts and stops without a click."""
    x = x.copy()
    a, r = int(RATE * attack), int(RATE * release)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if r:
        x[-r:] *= np.linspace(1, 0, r)
    return x


def mix(length, parts):
    """Lay (start seconds, samples) pairs over a silent bed."""
    bed = np.zeros(int(RATE * length))
    for start, x in parts:
        i = int(RATE * start)
        x = x[: max(0, len(bed) - i)]
        bed[i : i + len(x)] += x
    return bed


def note(name):
    """Frequency of a note written like 'A4' or 'C#5'."""
    steps = {'C': -9, 'D': -7, 'E': -5, 'F': -4, 'G': -2, 'A': 0, 'B': 2}
    semitone = steps[name[0]] + (1 if '#' in name else 0) + 12 * (int(name[-1]) - 4)
    return 440.0 * 2 ** (semitone / 12)


def beep(freq, seconds, harmonics=(1.0, 0.35, 0.12)):
    t = times(seconds)
    x = sum(a * np.sin(2 * np.pi * freq * (n + 1) * t) for n, a in enumerate(harmonics))
    return fade(x)


def struck(freq, seconds, partials, decay):
    """A struck bar or bell: fixed partials, each dying away at its own pace."""
    t = times(seconds)
    x = np.zeros_like(t)
    for ratio, amp, rate in partials:
        x += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t * decay * rate)
    return fade(x, attack=0.002, release=0.03)


def pluck(freq, seconds, damping=0.996, seed=1):
    """Karplus-Strong: a burst of noise going round a delay line."""
    rng = np.random.default_rng(seed)
    period = int(RATE / freq)
    line = rng.uniform(-1, 1, period)
    # The loop passes anything that does not change, so a burst that does not
    # average to zero leaves a silent offset that eats the headroom.
    line -= line.mean()
    out = np.empty(int(RATE * seconds))
    for i in range(len(out)):
        out[i] = line[i % period]
        line[i % period] = damping * 0.5 * (line[i % period] + line[(i + 1) % period])
    return fade(out, attack=0.001, release=0.05)


GLOCK = [(1, 1.0, 1.0), (2.76, 0.45, 1.8), (5.4, 0.22, 3.0), (8.93, 0.08, 4.5)]
MARIMBA = [(1, 1.0, 1.0), (4.0, 0.30, 3.5), (10.0, 0.08, 8.0)]
BELL = [(0.5, 0.55, 0.6), (1, 1.0, 1.0), (1.2, 0.55, 1.4), (1.5, 0.35, 1.8),
        (2, 0.5, 2.2), (2.5, 0.22, 3.0), (3, 0.18, 3.8), (4.2, 0.08, 5.0)]


def classic():
    """Four beeps and a pause: the bedside alarm clock."""
    one = np.concatenate([beep(880, 0.085), silence(0.07)])
    burst = np.concatenate([one] * 4 + [silence(0.45)])
    return np.concatenate([burst] * 3)


def digital():
    """The two-beep trill of a wristwatch."""
    one = np.concatenate([beep(1976, 0.055, (1.0, 0.2)), silence(0.055)])
    pair = np.concatenate([one, one, silence(0.16)])
    return np.concatenate([pair] * 4 + [silence(0.55)] + [pair] * 4 + [silence(0.7)])


def chime():
    """A rising run on a glockenspiel."""
    run = ['C5', 'E5', 'G5', 'C6', 'G5', 'E5', 'G5', 'C6']
    return mix(4.4, [(i * 0.42, struck(note(n), 1.9, GLOCK, 3.2)) for i, n in enumerate(run)]) * 0.9


def marimba():
    """A warm mallet tune, two bars long."""
    tune = ['G4', 'B4', 'D5', 'G5', 'D5', 'B4', 'G4', 'B4', 'A4', 'C5', 'E5', 'A5', 'E5', 'C5', 'D5', 'G5']
    parts = [(i * 0.2, struck(note(n), 0.9, MARIMBA, 5.5)) for i, n in enumerate(tune)]
    return mix(4.2, parts)


def sunrise():
    """A chord that swells in under a few bell notes: the gentle one."""
    length = 6.5
    t = times(length)
    pad = np.zeros_like(t)
    for n in ['C4', 'G4', 'E5', 'B5']:
        f = note(n)
        pad += np.sin(2 * np.pi * f * t) + 0.6 * np.sin(2 * np.pi * f * 1.004 * t)
    swell = np.clip(t / 2.2, 0, 1) ** 1.5 * np.clip((length - 0.5 - t) / 1.5, 0, 1)
    pad *= swell * (0.85 + 0.15 * np.sin(2 * np.pi * 0.7 * t)) * 0.16
    bells = mix(length, [(s, struck(note(n), 2.2, GLOCK, 2.4) * 0.55)
                         for s, n in [(1.6, 'E6'), (2.5, 'G6'), (3.4, 'B6'), (4.3, 'G6')]])
    return pad + bells


def bell():
    """Two strokes of a large bell."""
    one = struck(note('A4'), 2.9, BELL, 1.5)
    return mix(6.2, [(0.0, one), (3.0, one)])


def pulse():
    """Three rising sweeps, close together. Hard to sleep through."""
    t = times(0.2)
    sweep = fade(np.sin(2 * np.pi * (650 * t + (1350 - 650) / 0.4 * t * t)) +
                 0.3 * np.sin(2 * np.pi * (1300 * t + (2700 - 1300) / 0.4 * t * t)))
    burst = np.concatenate([sweep, silence(0.05)] * 3 + [silence(0.4)])
    return np.concatenate([burst] * 3)


def birds():
    """Birdsong at a window: short chirps that sweep up and fall back."""
    rng = np.random.default_rng(7)
    parts = []
    at = 0.2
    while at < 5.4:
        base = rng.uniform(2600, 3800)
        for k in range(int(rng.integers(2, 5))):
            d = rng.uniform(0.07, 0.13)
            t = times(d)
            sweep = base + 900 * np.sin(np.pi * t / d) + 250 * np.sin(2 * np.pi * 38 * t)
            chirp = np.sin(2 * np.pi * np.cumsum(sweep) / RATE) * np.sin(np.pi * t / d) ** 2
            parts.append((at + k * (d + 0.045), chirp * rng.uniform(0.5, 1.0)))
        at += rng.uniform(0.6, 1.1)
    return mix(6.0, parts)


def harp():
    """A plucked run up a pentatonic scale and one chord at the top."""
    run = ['C4', 'D4', 'E4', 'G4', 'A4', 'C5', 'D5', 'E5', 'G5', 'A5', 'C6']
    parts = [(i * 0.13, pluck(note(n), 2.2, seed=i + 1)) for i, n in enumerate(run)]
    parts += [(1.75, pluck(note(n), 2.4, seed=20 + i) * 0.8) for i, n in enumerate(['C5', 'E5', 'G5', 'C6'])]
    return mix(4.6, parts)


SOUNDS = {
    'alarm_classic': classic,
    'alarm_digital': digital,
    'alarm_chime': chime,
    'alarm_marimba': marimba,
    'alarm_harp': harp,
    'alarm_sunrise': sunrise,
    'alarm_birds': birds,
    'alarm_bell': bell,
    'alarm_pulse': pulse,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, make in SOUNDS.items():
        x = make()
        x = x - x.mean()
        x = x / np.max(np.abs(x))
        # A phone speaker is small. The quiet, decaying sounds are pressed
        # gently against the ceiling so they carry as far as the beeps do.
        if np.sqrt(np.mean(x ** 2)) < 0.16:
            x = np.tanh(2.2 * x) / np.tanh(2.2)
        x = x * 0.89
        pcm = (x * 32767).astype('<i2')
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
            path = tmp.name
        with wave.open(path, 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm.tobytes())
        target = os.path.join(OUT, name + '.ogg')
        subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', path, '-c:a', 'libvorbis',
                        '-q:a', '4', '-ac', '1', target], check=True)
        os.unlink(path)
        print(f'{name}: {len(x) / RATE:.1f}s, {os.path.getsize(target) // 1024} KB')


if __name__ == '__main__':
    main()
