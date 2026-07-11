// 총성 후보 3종 생성 — 시청 보드용. 사용: node gen_gunshots.js <출력폴더>
const fs = require('fs');
const path = require('path');
const { sfxr, Params } = require('jsfxr');

const outDir = process.argv[2] || '.';
fs.mkdirSync(outDir, { recursive: true });

function make(name, tune) {
  const p = new Params();
  Object.assign(p, { sample_rate: 44100, sample_size: 16, sound_vol: 0.32 }, tune);
  const b64 = sfxr.toWave(p).dataURI.split(',')[1];
  fs.writeFileSync(path.join(outDir, name), Buffer.from(b64, 'base64'));
  console.log('ok', name);
}

// A. 리볼버 — 중간 톤, 강한 펀치, 표준 웨스턴 "탕"
make('gun_revolver.wav', {
  wave_type: 3,
  p_env_attack: 0, p_env_sustain: 0.08, p_env_punch: 0.7, p_env_decay: 0.34,
  p_base_freq: 0.15, p_freq_ramp: -0.34,
  p_lpf_freq: 0.5, p_lpf_ramp: -0.22, p_lpf_resonance: 0.45,
});

// B. 샤프 크랙 — 높고 날카로운 "탕!" (빠른 감쇠, 경쾌)
make('gun_crack.wav', {
  wave_type: 3,
  p_env_attack: 0, p_env_sustain: 0.05, p_env_punch: 0.8, p_env_decay: 0.2,
  p_base_freq: 0.24, p_freq_ramp: -0.42,
  p_lpf_freq: 0.75, p_lpf_ramp: -0.3, p_hpf_freq: 0.08,
});

// C. 묵직한 붐 — 낮고 무거운 "쿵" (긴 잔향, 대구경 느낌)
make('gun_boom.wav', {
  wave_type: 3,
  p_env_attack: 0, p_env_sustain: 0.1, p_env_punch: 0.55, p_env_decay: 0.5,
  p_base_freq: 0.09, p_freq_ramp: -0.22,
  p_lpf_freq: 0.34, p_lpf_ramp: -0.14, p_lpf_resonance: 0.55,
});
