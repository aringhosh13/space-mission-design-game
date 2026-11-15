"""Original Blue Horizon synthesis; stdlib only, deterministic PCM, no external recordings."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / 'audio'
OUT.mkdir(exist_ok=True)
TAU = math.tau

def save(name, seconds, sample, stereo=False):
    payload = bytearray()
    peak = 0.0
    for i in range(round(seconds * RATE)):
        values = sample(i / RATE)
        if not stereo: values = (values,)
        for value in values:
            peak = max(peak, abs(value))
            payload.extend(struct.pack('<h', round(max(-0.95, min(0.95, value)) * 32767)))
    with wave.open(str(OUT / (name + '.wav')), 'wb') as out:
        out.setnchannels(2 if stereo else 1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(payload)
    assert peak < 0.95, (name, peak)
    print(name, 'peak', round(peak, 3), flush=True)

def note(midi): return 440 * 2 ** ((midi - 69) / 12)

def music(t):
    # 48-second original ambient cycle, Em9 / Cmaj7 / G6 / Dsus2. No borrowed melody.
    chords = [(40, 52, 55, 59, 66), (36, 52, 55, 59, 64), (43, 50, 55, 59, 64), (38, 50, 57, 62, 64)]
    left = right = 0.0
    for block, chord in enumerate(chords):
        phase = (t - block * 12) % 48
        if phase >= 16: continue
        env = min(1, phase / 4) * min(1, (16 - phase) / 4)
        for j, pitch in enumerate(chord):
            frequency = note(pitch)
            tone = (math.sin(TAU * frequency * phase) + 0.18 * math.sin(TAU * frequency * 2 * phase)) * env * 0.047
            pan = j / 4
            left += tone * (0.85 - pan * 0.45)
            right += tone * (0.4 + pan * 0.45)
    # Sparse bell motif, with its own tail, fades across the exact loop boundary.
    for beat, pitch in [(2, 76), (8, 71), (17, 79), (23, 76), (29, 74), (35, 71), (41, 69), (46, 74)]:
        age = (t - beat) % 48
        if age < 8:
            env = min(1, age / 0.04) * math.exp(-age * 0.85)
            tone = math.sin(TAU * note(pitch) * age) * env * 0.032
            left += tone * 0.75
            right += tone * 0.55
    # Zero-crossfade avoids the seam even where tails overlap the cycle.
    seam = min(1, t / 0.08, (48 - t) / 0.08)
    return left * seam, right * seam

save('horizon', 48, music, True)
for name, tones, duration in [
    ('confirm', [523.25, 659.25, 783.99], 0.55),
    ('checkpoint', [329.63, 493.88, 659.25, 783.99], 1.2),
    ('warning', [220, 196], 0.45), ('click', [640], 0.11),
    ('scan', [440, 554.37, 659.25], 0.65),
]:
    def cue(t, frequencies=tones, span=duration):
        segment = span / len(frequencies)
        index = min(len(frequencies) - 1, int(t / segment))
        age = t - index * segment
        env = min(1, age / 0.008) * math.exp(-age * 13) * min(1, (span - t) / 0.02)
        return math.sin(TAU * frequencies[index] * t) * env * 0.25
    save(name, duration, cue)

rng = random.Random(713)
noise = [rng.uniform(-1, 1) for _ in range(RATE * 4)]
smooth = 0.0
wind = []
for value in noise:
    smooth += (value - smooth) * 0.035
    wind.append(smooth)
save('mars_wind', 4, lambda t: wind[min(len(wind)-1, int(t * RATE))] * 0.7 * math.sin(math.pi * t / 4) ** 2)
save('rover', 2, lambda t: (math.sin(TAU * 55 * t) + 0.25 * math.sin(TAU * 110 * t)) * 0.075 * (0.85 + 0.15 * math.sin(TAU * 4 * t)))
save('engine', 2, lambda t: (math.sin(TAU * 42 * t) + 0.3 * math.sin(TAU * 84 * t) + 0.12 * math.sin(TAU * 168 * t)) * 0.1)
save('drill', 2, lambda t: (math.sin(TAU * 145 * t) + 0.25 * math.sin(TAU * 290 * t)) * 0.075 * (0.75 + 0.25 * math.sin(TAU * 18 * t)))
save('scanner', 2, lambda t: math.sin(TAU * 330 * t + 4 * math.sin(TAU * 0.5 * t)) * 0.05 * math.sin(math.pi * t / 2) ** 2)
save('impact', 0.3, lambda t: math.sin(TAU * (90 * t - 70 * t * t)) * 0.3 * math.exp(-t * 22) * min(1, t / 0.004))
