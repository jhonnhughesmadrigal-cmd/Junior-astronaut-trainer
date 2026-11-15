import numpy as np, wave, sys
SR = 16000
LOOP = 32.0
N = int(SR * LOOP)

def hz(n, o):
    base = {"C":0,"D":2,"E":4,"F":5,"G":7,"A":9,"B":11,"Bb":10,"Eb":3,"Ab":8,"F#":6}[n]
    return 440.0 * 2 ** ((12*(o+1)+base - 69)/12.0)

def add(buf, start, seg):
    idx = (start + np.arange(len(seg))) % len(buf)
    np.add.at(buf, idx, seg)

def pad(f, dur):
    t = np.arange(int(dur*SR))/SR
    s = np.sin(2*np.pi*f*t) + 0.5*np.sin(2*np.pi*f*2.003*t) + 0.3*np.sin(2*np.pi*f*0.997*t)
    return s * np.sin(np.pi*t/dur)**2

def pluck(f, dur, decay=1.6, bright=0.35):
    t = np.arange(int(dur*SR))/SR
    s = np.sin(2*np.pi*f*t) + bright*np.sin(2*np.pi*f*2*t) + bright*0.4*np.sin(2*np.pi*f*3*t)
    return s * np.exp(-t*decay) * (1-np.exp(-t*120))

def echo(b, d, fb, taps=5):
    o = b.copy(); k = int(d*SR)
    for i in range(1, taps+1): o += (fb**i)*np.roll(b, k*i)
    return o

def build(chords, melody, beat, pad_gain, mel_gain, mel_decay, drone, bell=None):
    buf = np.zeros(N)
    seg = LOOP/len(chords)
    for i, ch in enumerate(chords):
        st = int((i*seg - 1.5)*SR)
        for n,o in ch:
            add(buf, st, pad(hz(n,o), seg+3.0)*0.18*pad_gain)
    t = np.arange(N)/SR
    buf += (np.sin(2*np.pi*hz(*drone)*t)*0.18)
    pos = 0.0
    for n,o,beats in melody:
        if n is not None:
            add(buf, int(pos*beat*SR), pluck(hz(n,o), 3.5, mel_decay)*mel_gain)
        pos += beats
    assert abs(pos*beat - LOOP) < 1e-6, pos*beat
    return echo(buf, 0.45, 0.42)

def save(name, x):
    x = x/np.max(np.abs(x))*0.8
    with wave.open(name+".wav","wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x*32767).astype('<i2').tobytes())

# VICTORIA / buen final: C - G - Am - F, 64 bpm -> 8 beats por acorde * 4 = 32 beats... beat=1.0 s (32 beats = 32 s)
win_chords = [[("C",3),("G",3),("E",4)], [("G",2),("D",3),("B",3)], [("A",2),("E",3),("C",4)], [("F",2),("C",3),("A",3)]]
win_mel = [("E",5,2),("G",5,2),("C",6,2),("G",5,2),   # 8
           ("D",5,2),("G",5,2),("B",5,2),("G",5,2),   # 16
           ("C",5,2),("E",5,2),("A",5,2),("E",5,2),   # 24
           ("A",5,2),("C",6,2),("F",5,3),(None,0,1)]  # 32
save("music_outro_win", build(win_chords, win_mel, 1.0, 1.0, 0.22, 1.4, ("C",2)))

# DERROTA / final triste: Am - F - C - E, notas lentas y graves
lose_chords = [[("A",2),("E",3),("A",3),("C",4)], [("F",2),("C",3),("F",3),("A",3)], [("C",3),("G",3),("E",4)], [("E",2),("B",2),("E",3),("G",3)]]
lose_mel = [("E",5,3),("C",5,3),("A",4,2),            # 8
            ("C",5,3),("A",4,3),("F",4,2),            # 16
            ("G",4,3),("E",4,3),("C",4,2),            # 24
            ("B",4,3),("G",4,2),(None,0,3)]           # 32
save("music_outro_lose", build(lose_chords, lose_mel, 1.0, 0.9, 0.2, 1.1, ("A",1)))
print("ok")
