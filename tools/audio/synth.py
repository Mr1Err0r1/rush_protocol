"""Rush Protocol - Platzhalter-Audio (SFX + Musik), komplett synthetisch erzeugt.

Keine fremden Samples. Aufruf:  python tools/audio/synth.py [ziel_ordner]
Benoetigt: numpy, scipy und ffmpeg (libvorbis) im PATH. Standardziel: assets/sounds/
Die Ausgabe ist deterministisch (fester Seed) und kann beliebig neu erzeugt werden.
"""
import pathlib, shutil, subprocess, sys, tempfile
import numpy as np
from scipy import signal
from scipy.io import wavfile
sr = 44100
OUT_DIR = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parents[2] / 'assets' / 'sounds'
WAV_DIR = pathlib.Path(tempfile.mkdtemp(prefix='rush_audio_'))
rng = np.random.default_rng(1234)

def midi(m): return 440.0 * 2 ** ((m - 69) / 12)
def T(d): return np.arange(int(d * sr)) / sr
def env(n, a=0.005, d=0.2):
    t = np.arange(n) / sr
    return np.minimum(1, t / max(a, 1e-4)) * np.exp(-t / d)
def lp(x, fc, o=2):
    b, a = signal.butter(o, min(fc, sr / 2 - 100) / (sr / 2), 'low'); return signal.lfilter(b, a, x)
def hp(x, fc, o=2):
    b, a = signal.butter(o, fc / (sr / 2), 'high'); return signal.lfilter(b, a, x)
def bp(x, lo, hi, o=2):
    b, a = signal.butter(o, [lo / (sr / 2), min(hi, sr / 2 - 100) / (sr / 2)], 'band'); return signal.lfilter(b, a, x)
def noise(d): return rng.standard_normal(int(d * sr))
def glide(f0, f1, d, curve=1.0):
    t = np.linspace(0, 1, int(d * sr)) ** curve
    f = f0 + (f1 - f0) * t
    return np.cumsum(2 * np.pi * f / sr)

# ---------- Instrumente ----------
def ep(f, d, vel=1.0):          # E-Piano (FM)
    t = T(d); idx = 1.4 * vel * np.exp(-t / 0.4) + 0.15
    y = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * t)) * env(len(t), 0.004, 0.9)
    y += 0.12 * np.sin(2 * np.pi * f * 7 * t) * np.exp(-t / 0.04)
    return y * (0.5 + 0.5 * vel)
def bell(f, d, vel=1.0):        # FM-Glocke
    t = T(d); idx = 2.2 * np.exp(-t / 0.25)
    return np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * 3.5 * t)) * env(len(t), 0.002, d / 3.2) * vel
def pluck(f, d, vel=1.0):
    t = T(d); y = np.zeros_like(t)
    for k in range(1, 8): y += np.sin(2 * np.pi * f * k * t) / k * np.exp(-t * (4 + 5 * k) / d)
    return y * vel * 0.6
def bass(f, d, vel=1.0):
    t = T(d); y = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(4 * np.pi * f * t)
    return lp(y, 600) * env(len(t), 0.01, d * 0.5) * vel
def pad(f, d, vel=1.0):
    t = T(d); y = sum(np.sin(2 * np.pi * f * (1 + dt) * t) for dt in (-0.004, 0, 0.004)) / 3
    y += 0.4 * lp(signal.sawtooth(2 * np.pi * f * t), 900) * 0.5
    a = np.minimum(1, t / 0.6) * np.minimum(1, (d - t) / 0.8)
    return y * a * vel
def kick(d=0.35, f0=150, f1=42):
    ph = glide(f0, f1, d, 0.3); return np.sin(ph) * env(int(d * sr), 0.001, 0.12)
def hat(d=0.06, br=0.0):
    return hp(noise(d), 6500) * env(int(d * sr), 0.0008 + br, d / 3)
def brush(d=0.18):
    return bp(noise(d), 2500, 9000) * env(int(d * sr), 0.02, d / 2.5)

# ---------- Mixer ----------
class Track:
    def __init__(self, dur, loop=True, tail=0.0):
        self.loop = loop; self.N = int(dur * sr); self.L = self.N + (0 if loop else int(tail * sr))
        self.b = np.zeros((2, self.L))
    def add(self, x, t0, gain=1.0, pan=0.0):
        i = int(t0 * sr); l = gain * np.cos((pan + 1) * np.pi / 4); r = gain * np.sin((pan + 1) * np.pi / 4)
        n = len(x)
        if self.loop:
            i %= self.N
            for c, g in ((0, l), (1, r)):
                pos = i; done = 0
                while done < n:
                    k = min(n - done, self.N - pos)
                    self.b[c, pos:pos + k] += x[done:done + k] * g
                    done += k; pos = (pos + k) % self.N
        else:
            n = min(n, self.L - i)
            if n > 0:
                self.b[0, i:i + n] += x[:n] * l; self.b[1, i:i + n] += x[:n] * r
    def reverb(self, mix=0.25, decay=1.6):
        m = int(decay * sr); t = np.arange(m) / sr
        ir = np.stack([lp(rng.standard_normal(m), 5000) * np.exp(-t / (decay / 4.5)) for _ in range(2)])
        ir[:, :int(0.012 * sr)] *= 0.2
        ir /= np.sqrt((ir ** 2).sum(axis=1, keepdims=True))
        wet = np.zeros_like(self.b)
        for c in range(2):
            if self.loop:
                x = np.tile(self.b[c], 3); w = signal.fftconvolve(x, ir[c])[:len(x)]; wet[c] = w[self.N:2 * self.N]
            else:
                w = signal.fftconvolve(self.b[c], ir[c]); wet[c] = w[:self.L]
        self.b = self.b * (1 - mix * 0.5) + wet * mix * 3.0
    def out(self, peak=0.6):
        y = self.b.copy(); y = np.tanh(y * 1.1) ; y *= peak / max(np.abs(y).max(), 1e-6); return y

def save(name, y, peak=0.7):
    y = np.atleast_2d(y); y = y * (peak / max(np.abs(y).max(), 1e-6))
    fade = int(0.003 * sr)
    if name in ('music_menu', 'music_match', 'music_tense'):
        pass                                   # nahtlose Loops: keine Fades an den Rändern
    else:
        y[:, :fade] *= np.linspace(0, 1, fade); y[:, -fade:] *= np.linspace(1, 0, fade)
    wavfile.write(str(WAV_DIR / f'{name}.wav'), sr, (y.T * 32767).astype(np.int16))

def mono(fn, *a, **k):
    return fn(*a, **k)

# ---------- SFX ----------
def sfx():
    n = int(0.06 * sr)
    save('ui_click', np.sin(2 * np.pi * 2300 * T(0.06)) * env(n, .0008, .012) * .6 + hp(noise(.06), 3000) * env(n, .0003, .006) * .4, .55)
    save('ui_hover', np.sin(2 * np.pi * 1500 * T(0.05)) * env(int(.05 * sr), .002, .012), .35)
    c = np.zeros(int(.25 * sr))
    for k, f in enumerate((880, 1320)):
        s = np.sin(2 * np.pi * f * T(.1)) * env(int(.1 * sr), .002, .04); i = int(k * .07 * sr); c[i:i + len(s)] += s
    save('ui_confirm', c, .55)
    w = np.zeros(int(1.1 * sr))
    for k, m in enumerate((72, 76, 79, 84)):
        s = bell(midi(m), .7); i = int(k * .075 * sr); w[i:i + len(s)] += s
    w += hp(noise(1.1), 7000) * env(len(w), .01, .25) * 0.08
    save('risk_win', w, .7)
    l = np.zeros(int(1.0 * sr))
    for k, m in enumerate((67, 64, 60)):
        s = lp(signal.square(2 * np.pi * midi(m) * T(.3)), 1400) * env(int(.3 * sr), .005, .16); i = int(k * .17 * sr); l[i:i + len(s)] += s
    s = lp(signal.sawtooth(glide(110, 70, .35)), 500) * env(int(.35 * sr), .01, .2); l[int(.5 * sr):int(.5 * sr) + len(s)] += s
    save('risk_lose', l, .6)
    ph = glide(440, 988, .55, 1.4); h = (np.sin(ph) + .3 * np.sin(2 * ph)) * env(int(.55 * sr), .02, .5)
    h = np.concatenate([h, np.zeros(int(.45 * sr))]); h[int(.4 * sr):int(.4 * sr) + int(.5 * sr)] += bell(midi(88), .5) * .5
    save('item_heal', h, .6)
    sw = bp(noise(.4), 400, 4500) * np.sin(np.linspace(0, np.pi, int(.4 * sr))) ** 2
    sw = np.concatenate([sw, np.zeros(int(.2 * sr))]); sw[int(.3 * sr):int(.3 * sr) + int(.2 * sr)] += np.sin(2 * np.pi * 1800 * T(.2)) * env(int(.2 * sr), .002, .05) * .6
    save('item_peek', sw, .6)
    f = kick(.45, 170, 38) + lp(noise(.45), 1500) * env(int(.45 * sr), .001, .09) * .6
    save('item_force', np.tanh(f * 2.2), .75)
    st = np.zeros(int(.6 * sr))
    for k, m in enumerate((81, 74)):
        s = pluck(midi(m), .3); i = int(k * .09 * sr); st[i:i + len(s)] += s
    st[:int(.3 * sr)] += bp(noise(.3), 3000, 9000) * np.sin(np.linspace(0, np.pi, int(.3 * sr))) * .25
    save('item_steal', st, .6)
    save('item_generic', pluck(midi(81), .3), .55)
    t2 = np.zeros(int(.9 * sr))
    for k, m in enumerate((76, 83)):
        s = bell(midi(m), .6); i = int(k * .13 * sr); t2[i:i + len(s)] += s
    save('turn_start', t2, .55)
    d = lp(signal.sawtooth(glide(320, 55, .9, .6)), 1200) * env(int(.9 * sr), .005, .55) + lp(noise(.9), 900) * env(int(.9 * sr), .001, .15) * .4
    save('player_die', d, .7)
    fan = np.zeros(int(2.2 * sr))
    for k, chord in enumerate(((60, 64, 67), (65, 69, 72), (67, 71, 74), (72, 76, 79, 84))):
        for m in chord:
            f0 = midi(m); s = lp(signal.sawtooth(2 * np.pi * f0 * T(.7)), 2500) * env(int(.7 * sr), .01, .45 if k < 3 else .9); i = int(k * .28 * sr); fan[i:i + len(s)] += s * .3
    save('match_over', fan, .65)
sfx()

# ---------- Musik ----------
def menu():
    bpm = 84; beat = 60 / bpm; tr = Track(8 * 4 * beat)
    chords = [[50, 53, 57, 60, 64], [55, 59, 64, 65], [48, 52, 59, 62], [57, 61, 67, 70]] * 2
    roots = [38, 43, 36, 33] * 2
    mel = [74, 72, 69, 67, 65, 62]
    for b in range(8):
        t0 = b * 4 * beat
        for j, m in enumerate(chords[b]):
            tr.add(ep(midi(m), 2.4, .8), t0 + j * .012, .2, -.35 + .15 * j)
            tr.add(ep(midi(m), 1.0, .55), t0 + (2 + .667) * beat + j * .01, .13, .35 - .15 * j)
        r = roots[b]; nr = roots[(b + 1) % 8]
        for j, m in enumerate((r, r + 7, r + 12, nr + 1)):
            tr.add(bass(midi(m), beat * .95), t0 + j * beat, .5, 0)
        for j in (1, 3):
            tr.add(brush(.2), t0 + j * beat, .12, .2)
            tr.add(brush(.1), t0 + (j + .667) * beat, .05, -.2)
        for off in rng.choice([0, 1.667, 2.667, 3.0], size=2, replace=False):
            tr.add(bell(midi(int(rng.choice(mel))), 1.2, .6), t0 + off * beat, .1, rng.uniform(-.5, .5))
    tr.reverb(.22, 1.8); save('music_menu', tr.out(.6), .6)
def match():
    bpm = 100; beat = 60 / bpm; tr = Track(8 * 4 * beat)
    prog = [(57, 60, 64), (53, 57, 60), (48, 52, 55), (55, 59, 62)] * 2; roots = [33, 29, 36, 31] * 2
    for b in range(8):
        t0 = b * 4 * beat; ch = prog[b]
        for j in range(8):
            tr.add(bass(midi(roots[b] + (12 if j % 4 == 3 else 0)), beat * .5), t0 + j * beat / 2, .45, 0)
            tr.add(hat(.05), t0 + j * beat / 2, .12 if j % 2 else .07, .3)
        for j in range(16):
            m = ch[j % 3] + (12 if (j // 3) % 2 else 0) + 12
            tr.add(pluck(midi(m), .35), t0 + j * beat / 4, .1 if j % 4 else .16, -.5 + (j % 5) * .25)
        for q in (0, 2): tr.add(kick(), t0 + q * beat, .7, 0)
        for q in (1, 3): tr.add(bp(noise(.15), 1500, 6000) * env(int(.15 * sr), .001, .05), t0 + q * beat, .25, 0)
        if b % 2 == 0:
            for m in ch: tr.add(pad(midi(m), 4.8, .5), t0, .1, rng.uniform(-.4, .4))
    tr.reverb(.18, 1.2); save('music_match', tr.out(.6), .6)
def tense():
    dur = 16.0; tr = Track(dur)
    for f, g in ((38, .5), (45, .35), (50, .25)):
        tr.add(pad(midi(f), dur + 1.5, 1.0)[:int(dur * sr)] * (1 + .25 * np.sin(2 * np.pi * .125 * T(dur))[:int(dur * sr)]), 0, g, 0)
    for k in range(16):
        tr.add(kick(.3, 90, 38), k * 1.0, .55, 0); tr.add(kick(.25, 85, 36), k * 1.0 + .22, .35, 0)
    t = T(dur)
    for f, pn in ((midi(74), -.5), (midi(75), .5)):
        s = np.sin(2 * np.pi * f * t) * (.5 + .5 * np.sin(2 * np.pi * 6 * t)) * (.5 + .5 * np.sin(2 * np.pi * .0625 * t + pn)) ** 2
        tr.add(s, 0, .06, pn)
    for k in range(4): tr.add(bp(noise(3), 800, 3000) * np.sin(np.linspace(0, np.pi, int(3 * sr))) ** 2, k * 4.0, .05, rng.uniform(-.7, .7))
    tr.reverb(.25, 2.2); save('music_tense', tr.out(.6), .6)
def gameover():
    tr = Track(9.0, loop=False, tail=3.0)
    for k, ch in enumerate(((62, 65, 69, 72), (58, 62, 65, 69), (55, 58, 62, 65), (57, 61, 64, 67))):
        for j, m in enumerate(ch):
            tr.add(ep(midi(m), 3.2, .7), k * 2.0 + j * .05, .22, -.4 + .27 * j)
        tr.add(bass(midi(ch[0] - 24), 2.0), k * 2.0, .5, 0)
    tr.reverb(.35, 3.0); save('music_gameover', tr.out(.6), .6)
menu(); match(); tense(); gameover()

ffmpeg = shutil.which('ffmpeg')
if ffmpeg is None:
    sys.exit('ffmpeg nicht gefunden - WAV-Dateien liegen in ' + str(WAV_DIR))
OUT_DIR.mkdir(parents=True, exist_ok=True)
for wav in sorted(WAV_DIR.glob('*.wav')):
    subprocess.run([ffmpeg, '-loglevel', 'error', '-y', '-i', str(wav), '-c:a', 'libvorbis', '-q:a', '4', str(OUT_DIR / (wav.stem + '.ogg'))], check=True)
print('fertig:', len(list(WAV_DIR.glob('*.wav'))), 'Dateien ->', OUT_DIR)
