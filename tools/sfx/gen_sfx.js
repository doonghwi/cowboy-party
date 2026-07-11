// jsfxr 파라미터 → WAV 생성기. 사용: node gen_sfx.js <출력폴더>
// 프리셋을 기반으로 서부극 톤에 맞게 수동 튜닝한 파라미터.
const fs = require('fs');
const path = require('path');
const { sfxr, Params } = require('jsfxr');

const outDir = process.argv[2] || '.';
fs.mkdirSync(outDir, { recursive: true });

function make(name, tune) {
  const p = new Params();
  // 기본값 위에 튜닝값을 덮어쓴다
  Object.assign(p, { sample_rate: 44100, sample_size: 16, sound_vol: 0.25 }, tune);
  const wave = sfxr.toWave(p);
  const uri = wave.dataURI; // data:audio/wav;base64,...
  const b64 = uri.split(',')[1];
  const file = path.join(outDir, name);
  fs.writeFileSync(file, Buffer.from(b64, 'base64'));
  console.log(name, fs.statSync(file).size, 'bytes');
}

// 1) 총성 — 노이즈 파형, 강한 펀치, 빠른 감쇠, 저역 필터로 "탕" 느낌
make('jsfxr_gunshot.wav', {
  wave_type: 3, // noise
  p_env_attack: 0,
  p_env_sustain: 0.07,
  p_env_punch: 0.65,
  p_env_decay: 0.32,
  p_base_freq: 0.16,
  p_freq_ramp: -0.32,
  p_lpf_freq: 0.55,
  p_lpf_ramp: -0.25,
  p_lpf_resonance: 0.4,
  p_hpf_freq: 0.02,
  sound_vol: 0.3,
});

// 2) 코인 — 사각파 + 상승 아르페지오, 짧고 명랑한 "칭"
make('jsfxr_coin.wav', {
  wave_type: 0, // square
  p_env_attack: 0,
  p_env_sustain: 0.05,
  p_env_punch: 0.45,
  p_env_decay: 0.35,
  p_base_freq: 0.62,
  p_arp_mod: 0.45,
  p_arp_speed: 0.6,
  p_duty: 0.3,
  sound_vol: 0.22,
});

// 3) UI 클릭 — 아주 짧은 블립, 높은 톤, 즉시 감쇠
make('jsfxr_ui_click.wav', {
  wave_type: 1, // sawtooth
  p_env_attack: 0,
  p_env_sustain: 0.012,
  p_env_punch: 0.2,
  p_env_decay: 0.09,
  p_base_freq: 0.72,
  p_freq_ramp: -0.1,
  p_lpf_freq: 0.9,
  sound_vol: 0.2,
});
