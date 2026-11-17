#!/usr/bin/env python3
# Mision Perseo v41 - efectos de sonido de los eventos, sintetizados por codigo (solo biblioteca estandar).
#   python3 tools/gen_sfx_events.py [carpeta]   (por defecto audio/)
# Genera (mono, 22 050 Hz, 16 bits): impact.wav (impacto del meteoro), wind.wav (viento de la tormenta, en bucle),
# cough.wav (tos), sparks.wav (chispas), whoosh.wav (meteoro cayendo), engine.wav (motor de la nave de rescate).
# Todo es original (ruido filtrado y osciladores); sin muestras de terceros.

import math
import os
import random
import struct
import sys
import wave

SR = 22050
OUT = sys.argv[1] if len(sys.argv) > 1 else "audio"


def save(name, data, vol=0.85):
    peak = max(1e-6, max(abs(x) for x in data))
    k = vol / peak
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x * k)) * 32767)) for x in data))
    print("WAV:", path, "%.2f s" % (len(data) / SR))


def noise(n, seed):
    r = random.Random(seed)
    return [r.uniform(-1.0, 1.0) for _ in range(n)]


def lowpass(x, cut):
    a = 1.0 - math.exp(-2.0 * math.pi * cut / SR)
    y, s = [], 0.0
    for v in x:
        s += a * (v - s)
        y.append(s)
    return y


def highpass(x, cut):
    lp = lowpass(x, cut)
    return [a - b for a, b in zip(x, lp)]


def env(n, attack, decay_pow=1.0):
    out = []
    na = max(1, int(attack * SR))
    for i in range(n):
        if i < na:
            out.append(i / na)
        else:
            u = (i - na) / max(1, n - na)
            out.append((1.0 - u) ** decay_pow)
    return out


def impact():
    n = int(1.6 * SR)
    thump = [math.sin(2 * math.pi * (55 - 25 * i / n) * i / SR) for i in range(n)]
    crack = highpass(noise(n, 1), 800)
    rumble = lowpass(noise(n, 2), 180)
    e1 = env(n, 0.004, 3.0)
    e2 = env(n, 0.002, 8.0)
    e3 = env(n, 0.02, 1.5)
    return [0.9 * thump[i] * e1[i] + 0.6 * crack[i] * e2[i] + 1.4 * rumble[i] * e3[i] for i in range(n)]


def wind():
    n = int(4.0 * SR)
    base = lowpass(noise(n, 3), 500)
    hiss = highpass(lowpass(noise(n, 4), 3000), 900)
    out = []
    for i in range(n):
        u = i / n
        gust = 0.6 + 0.4 * math.sin(2 * math.pi * 2 * u) * math.sin(2 * math.pi * 3 * u + 1.0)
        out.append(gust * (1.6 * base[i] + 0.35 * hiss[i]))
    # bucle sin corte: cruza el final con el principio
    m = int(0.4 * SR)
    for i in range(m):
        k = i / m
        out[i] = out[i] * k + out[n - m + i] * (1.0 - k)
    return out[: n - m]


def cough():
    n = int(0.9 * SR)
    out = [0.0] * n
    for start, ln, amp in ((0.0, 0.22, 1.0), (0.32, 0.18, 0.75)):
        s, L = int(start * SR), int(ln * SR)
        burst = highpass(lowpass(noise(L, 5 + int(start * 10)), 1800), 250)
        e = env(L, 0.01, 2.0)
        for i in range(L):
            tone = math.sin(2 * math.pi * (180 - 60 * i / L) * i / SR) * 0.25
            out[s + i] += amp * (burst[i] + tone) * e[i]
    return out


def sparks():
    n = int(0.7 * SR)
    r = random.Random(6)
    out = [0.0] * n
    for _ in range(40):
        p = r.randint(0, n - 400)
        a = r.uniform(0.3, 1.0)
        for i in range(r.randint(60, 300)):
            out[p + i] += a * r.uniform(-1, 1) * math.exp(-i / 60.0)
    return highpass(out, 1500)


def whoosh():
    n = int(1.8 * SR)
    x = noise(n, 7)
    out, s = [], 0.0
    for i in range(n):
        u = i / n
        cut = 300 + 3500 * u * u
        a = 1.0 - math.exp(-2.0 * math.pi * cut / SR)
        s += a * (x[i] - s)
        out.append(s * (u ** 1.5))
    return out


def engine():
    n = int(3.0 * SR)
    rum = lowpass(noise(n, 8), 220)
    roar = lowpass(highpass(noise(n, 9), 150), 1400)
    e = [min(1.0, i / (0.4 * SR)) * min(1.0, (n - i) / (0.6 * SR)) for i in range(n)]
    return [(1.5 * rum[i] + 0.5 * roar[i]) * e[i] for i in range(n)]


def main():
    os.makedirs(OUT, exist_ok=True)
    save("impact.wav", impact(), 0.95)
    save("wind.wav", wind(), 0.7)
    save("cough.wav", cough(), 0.6)
    save("sparks.wav", sparks(), 0.5)
    save("whoosh.wav", whoosh(), 0.75)
    save("engine.wav", engine(), 0.8)


main()
