#!/usr/bin/env python3
"""카우보이 파티 효과음 합성 (순수 stdlib — 저작권 0, 재현 가능).

레이어드 합성: 노이즈 버스트 + 저음 스윕 + 하모닉 톤 + 협곡 에코 리버브를
섞어 단일-파형보다 훨씬 풍부하게. 파일명/용도는 고정(코드 재배선 불필요),
사운드 품질만 강화한다. 실행: python3 tool/make_sounds.py
"""
import math
import os
import random
import struct
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')
random.seed(42)  # 재현 가능


def write_wav(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    peak = max(1e-9, max(abs(s) for s in samples))
    norm = 0.9 / peak
    with wave.open(path, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(
            struct.pack('<h', int(max(-1, min(1, s * norm)) * 32767))
            for s in samples))
    print(f'{name}: {len(samples)/SR:.2f}s')


def env(i, n, attack=0.005, decay=4.0):
    t = i / SR
    a = min(1.0, t / attack) if attack > 0 else 1.0
    return a * math.exp(-decay * t)


def noise_burst(dur, decay, lp=0.5):
    n = int(SR * dur)
    out, last = [], 0.0
    for i in range(n):
        v = random.uniform(-1, 1)
        last = last + lp * (v - last)  # 1차 로우패스
        out.append(last * env(i, n, 0.001, decay))
    return out


def sweep(dur, f0, f1, decay=6.0, shape=math.sin):
    n = int(SR * dur)
    out, ph = [], 0.0
    for i in range(n):
        f = f0 + (f1 - f0) * (i / n)
        ph += 2 * math.pi * f / SR
        out.append(shape(ph) * env(i, n, 0.002, decay))
    return out


def tone(dur, freq, decay=5.0, vib=0.0):
    n = int(SR * dur)
    out, ph = [], 0.0
    for i in range(n):
        f = freq * (1 + vib * math.sin(2 * math.pi * 6 * i / SR))
        ph += 2 * math.pi * f / SR
        out.append(math.sin(ph) * env(i, n, 0.003, decay))
    return out


def htone(dur, freq, decay=5.0, vib=0.0, partials=(1.0, 0.45, 0.22, 0.1)):
    """하모닉 톤 — 배음을 쌓아 사인보다 풍부한 벨/브라스 음색."""
    n = int(SR * dur)
    out = []
    phs = [0.0] * len(partials)
    for i in range(n):
        v = vib * math.sin(2 * math.pi * 6 * i / SR)
        s = 0.0
        for k, amp in enumerate(partials):
            f = freq * (k + 1) * (1 + v)
            phs[k] += 2 * math.pi * f / SR
            # 상위 배음은 더 빨리 감쇠 → 자연스러운 음색 변화
            s += amp * math.sin(phs[k]) * math.exp(-decay * 0.25 * k * (i / SR))
        out.append(s * env(i, n, 0.003, decay))
    return out


def sub(dur, freq, decay=10.0):
    """저음 펀치 — 임팩트 바디용 사인 서브."""
    n = int(SR * dur)
    out, ph = [], 0.0
    for i in range(n):
        ph += 2 * math.pi * freq / SR
        out.append(math.sin(ph) * env(i, n, 0.0, decay))
    return out


def saturate(samples, drive=1.6):
    """소프트 클립 — 펀치/따뜻함 추가 (tanh)."""
    return [math.tanh(s * drive) for s in samples]


def reverb(samples, taps=((0.13, 0.5), (0.27, 0.32), (0.41, 0.2)), wet=0.35):
    """협곡 에코 — 멀티탭 딜레이로 트인 공간감. 서부 총성에 핵심."""
    n = len(samples)
    extra = int(SR * max(d for d, _ in taps)) + int(SR * 0.2)
    out = list(samples) + [0.0] * extra
    for delay, gain in taps:
        d = int(SR * delay)
        for i in range(n):
            out[i + d] += samples[i] * gain * wet
    return out


def mix(*layers):
    n = max(len(l) for l in layers)
    return [sum(l[i] if i < len(l) else 0.0 for l in layers) for i in range(n)]


def gap(dur):
    return [0.0] * int(SR * dur)


def seq(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


# 탭/클릭 — 짧은 우드블록 느낌 (크리스피하게 유지)
write_wav('click.wav', mix(
    tone(0.06, 1800, decay=60),
    tone(0.05, 2700, decay=80),
    noise_burst(0.03, 80, lp=0.8),
))

# 결정 확정 — 클릭 두 번 위로 (살짝 밝게)
write_wav('confirm.wav', seq(
    mix(htone(0.07, 900, decay=40), noise_burst(0.02, 90)),
    gap(0.03),
    mix(htone(0.1, 1350, decay=32), noise_burst(0.02, 90)),
))

# 장전 — 금속 클릭 2연 + 스프링
write_wav('reload.wav', seq(
    mix(noise_burst(0.04, 70, lp=0.9), tone(0.04, 2400, decay=80)),
    gap(0.05),
    mix(noise_burst(0.06, 50, lp=0.9), tone(0.06, 1900, decay=60),
        sweep(0.06, 900, 1400, decay=40)),
))

# 빵야 — 노이즈 크랙 + 저음 펀치 + 서브 바디 + 협곡 에코
write_wav('shot.wav', reverb(saturate(mix(
    noise_burst(0.28, 18, lp=0.95),
    sweep(0.22, 220, 45, decay=16),
    sub(0.12, 70, decay=22),
    noise_burst(0.05, 60, lp=0.3),
), drive=1.4), wet=0.3))

# 슈퍼빵야 — 차지 스윕 후 더블 샷 + 큰 에코
write_wav('super.wav', reverb(saturate(seq(
    sweep(0.25, 300, 1400, decay=3),
    mix(noise_burst(0.35, 14, lp=0.95), sweep(0.3, 260, 40, decay=12),
        sub(0.18, 60, decay=14)),
), drive=1.5), taps=((0.17, 0.55), (0.33, 0.36), (0.5, 0.22)), wet=0.4))

# 방어 — 금속 핑 (막아냄) + 살짝 잔향
write_wav('shield.wav', reverb(mix(
    htone(0.25, 1230, decay=14, vib=0.004, partials=(1.0, 0.6, 0.35, 0.2)),
    tone(0.25, 1845, decay=18),
    noise_burst(0.03, 90, lp=0.8),
), taps=((0.09, 0.3), (0.18, 0.18)), wet=0.25))

# 덫 — 철컹 (스냅 + 저음)
write_wav('trap.wav', seq(
    mix(noise_burst(0.05, 60, lp=0.95), tone(0.05, 700, decay=50)),
    mix(noise_burst(0.12, 30, lp=0.9), sweep(0.15, 320, 90, decay=18),
        tone(0.12, 480, decay=25), sub(0.1, 80, decay=20)),
))

# 연막 — 슉 (화이트노이즈 스윕)
write_wav('smoke.wav', mix(
    noise_burst(0.4, 7, lp=0.25),
    noise_burst(0.3, 9, lp=0.12),
    sweep(0.35, 800, 200, decay=8),
))

# 명중/피격 — 둔탁한 임팩트 + 서브 펀치
write_wav('hit.wav', saturate(mix(
    noise_burst(0.15, 30, lp=0.6),
    sweep(0.2, 160, 50, decay=14),
    sub(0.14, 75, decay=18),
), drive=1.3))

# 승리 — 서부풍 3음 팡파레 (브라스 하모닉 + 홀 잔향)
write_wav('win.wav', reverb(seq(
    mix(htone(0.16, 523, decay=8), htone(0.16, 659, decay=8)),
    mix(htone(0.16, 659, decay=8), htone(0.16, 784, decay=8)),
    mix(htone(0.5, 784, decay=4, vib=0.006), htone(0.5, 1047, decay=4),
        htone(0.5, 523, decay=4)),
), taps=((0.14, 0.4), (0.28, 0.25), (0.45, 0.15)), wet=0.3))

# 패배 — 하강 2음 (잔향으로 쓸쓸하게)
write_wav('lose.wav', reverb(seq(
    htone(0.25, 330, decay=7),
    mix(htone(0.55, 247, decay=4.5), sweep(0.4, 250, 180, decay=6)),
), taps=((0.16, 0.35), (0.32, 0.2)), wet=0.3))

# 코인 — 동전 띵 2연 (밝은 벨 하모닉)
write_wav('coin.wav', seq(
    mix(htone(0.08, 1976, decay=30), htone(0.08, 2637, decay=35)),
    gap(0.02),
    mix(htone(0.22, 2349, decay=14), htone(0.22, 3136, decay=18)),
))
