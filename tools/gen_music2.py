import numpy as np, wave
SR = 16000
LOOP = 32.0
N = int(SR * LOOP)
rng = np.random.default_rng(11)

def hz(n, o):
    base = {"C":0,"C#":1,"D":2,"Eb":3,"E":4,"F":5,"F#":6,"G":7,"Ab":8,"A":9,"Bb":10,"B":11}[n]
    return 440.0 * 2 ** ((12*(o+1)+base - 69)/12.0)

def add(buf, start, seg):
    idx = (start + np.arange(len(seg))) % len(buf)
    np.add.at(buf, idx, seg)

def pad(f, dur):
    t = np.arange(int(dur*SR))/SR
    s = np.sin(2*np.pi*f*t) + 0.5*np.sin(2*np.pi*f*2.003*t) + 0.3*np.sin(2*np.pi*f*0.997*t)
    return s * np.sin(np.pi*t/dur)**2

def pluck(f, dur, decay, bright=0.35):
    t = np.arange(int(dur*SR))/SR
    s = np.sin(2*np.pi*f*t) + bright*np.sin(2*np.pi*f*2*t) + bright*0.4*np.sin(2*np.pi*f*3*t)
    return s * np.exp(-t*decay) * (1-np.exp(-t*150))

def bass(f, dur):
    t = np.arange(int(dur*SR))/SR
    s = np.sin(2*np.pi*f*t) + 0.35*np.sin(2*np.pi*f*2*t) + 0.15*np.sign(np.sin(2*np.pi*f*t))
    return s * np.exp(-t*5.0) * (1-np.exp(-t*200))

def kick():
    t = np.arange(int(0.2*SR))/SR
    f = 42 + 90*np.exp(-t*28)
    ph = 2*np.pi*np.cumsum(f)/SR
    return np.sin(ph)*np.exp(-t*16)

def hat():
    t = np.arange(int(0.06*SR))/SR
    n = rng.normal(0,1,len(t)); n = np.diff(n, prepend=0)
    return n*np.exp(-t*70)

def echo(b, d, fb, taps=4):
    o = b.copy(); k = int(d*SR)
    for i in range(1, taps+1): o += (fb**i)*np.roll(b, k*i)
    return o

def save(name, x):
    x = x/np.max(np.abs(x))*0.8
    with wave.open(name+".wav","wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x*32767).astype('<i2').tobytes())

def calm(chords, beat, drone, arp_gain, pad_gain=1.0, arp_pat=(0,1,2,1,3,2,1,2)):
    """Suave: pads + arpegio de corcheas con eco."""
    buf = np.zeros(N)
    nb = int(round(LOOP/beat)); per = nb/len(chords)
    seg = per*beat
    t = np.arange(N)/SR
    for i, ch in enumerate(chords):
        st = int((i*seg - 1.2)*SR)
        for n,o in ch:
            add(buf, st, pad(hz(n,o), seg+2.4)*0.16*pad_gain)
        steps = int(per*2)
        for k in range(steps):
            n,o = ch[arp_pat[k % len(arp_pat)] % len(ch)]
            add(buf, int((i*seg + k*beat/2)*SR), pluck(hz(n,o+1), 2.5, 2.2)*arp_gain)
    buf += np.sin(2*np.pi*hz(*drone)*t)*0.12
    return echo(buf, beat*0.75, 0.4)

def drive(chords, beat, bass_oct, arp_pat, arp_gain, pad_gain=0.7):
    """Movida: bombo en cada pulso, hi-hat a contratiempo, bajo y arpegio en semicorcheas."""
    buf = np.zeros(N)
    nb = int(round(LOOP/beat)); per = nb/len(chords)
    seg = per*beat
    for i, ch in enumerate(chords):
        st = int((i*seg - 0.5)*SR)
        for n,o in ch:
            add(buf, st, pad(hz(n,o), seg+1.0)*0.12*pad_gain)
        root = ch[0]
        for k in range(int(per*2)):
            tpos = i*seg + k*beat/2
            f = hz(root[0], bass_oct + (1 if k % 4 == 3 else 0))
            add(buf, int(tpos*SR), bass(f, beat*0.5)*0.34)
        for k in range(int(per*4)):
            tpos = i*seg + k*beat/4
            n,o = ch[arp_pat[k % len(arp_pat)] % len(ch)]
            add(buf, int(tpos*SR), pluck(hz(n,o+1), 0.35, 9.0)*arp_gain)
    for b in range(nb):
        add(buf, int(b*beat*SR), kick()*0.55)
        add(buf, int((b*beat + beat/2)*SR), hat()*0.16)
    return echo(buf, beat*0.75, 0.25, 3)

# ---- DIA (calmado, distinto al interior): beat 0.8 s -> 40 pulsos (4 acordes de 10) ----
moon_day = [[("F",3),("A",3),("C",4),("E",4)], [("G",3),("B",3),("D",4),("F#",4)], [("E",3),("G",3),("B",3),("D",4)], [("A",2),("E",3),("A",3),("C",4)]]
save("music_day_moon", calm(moon_day, 0.8, ("F",2), 0.2))
mars_day = [[("D",3),("A",3),("C",4),("F#",4)], [("C",3),("G",3),("Bb",3),("E",4)], [("G",2),("D",3),("G",3),("B",3)], [("A",2),("E",3),("A",3),("C",4)]]
save("music_day_mars", calm(mars_day, 0.8, ("D",2), 0.2, arp_pat=(0,2,1,3,2,1,3,2)))

# ---- NOCHE (movida, 120 bpm): beat 0.5 s -> 64 pulsos (4 acordes de 16) ----
moon_night = [[("A",3),("C",4),("E",4)], [("F",3),("A",3),("C",4)], [("D",3),("F",3),("A",3)], [("E",3),("Ab",3),("B",3)]]
save("music_night_moon", drive(moon_night, 0.5, 2, (0,1,2,1,2,1,0,2), 0.2))
mars_night = [[("D",3),("F",3),("A",3)], [("Bb",2),("D",3),("F",3)], [("G",2),("Bb",2),("D",3)], [("A",2),("C",3),("E",3)]]
save("music_night_mars", drive(mars_night, 0.5, 2, (0,2,1,2,0,2,1,2), 0.2))
print("ok")
