import os
import wave
import struct
import math

os.makedirs('assets/audio', exist_ok=True)

def gen(name, freqs, duration):
    f = wave.open('assets/audio/' + name + '.wav', 'w')
    f.setnchannels(1)
    f.setsampwidth(2)
    f.setframerate(44100)
    data = b''
    for i in range(int(44100 * duration)):
        t = i / 44100.0
        val = int(32767 * 0.5 * sum([math.sin(2 * math.pi * freq * t) for freq in freqs]) / len(freqs))
        data += struct.pack('<h', val)
    f.writeframesraw(data)
    f.close()

gen('success', [523.25, 659.25, 783.99], 0.3)
gen('fail', [150.0], 0.4)
