// 2차 후보 — 장전(저음 썸프)·쇼다운 예열(심장박동 두근) 소스 생성
const fs = require('fs');
const path = require('path');
const { sfxr, Params } = require('jsfxr');
const outDir = process.argv[2] || '.';
fs.mkdirSync(outDir, { recursive: true });
function make(name, tune) {
  const p = new Params();
  Object.assign(p, { sample_rate: 44100, sample_size: 16, sound_vol: 0.3 }, tune);
  const b64 = sfxr.toWave(p).dataURI.split(',')[1];
  fs.writeFileSync(path.join(outDir, name), Buffer.from(b64, 'base64'));
  console.log('ok', name);
}
// 낮은 "쿵"(장전의 묵직함 레이어)
make('thump.wav', {
  wave_type: 3, p_env_attack: 0, p_env_sustain: 0.03, p_env_punch: 0.5, p_env_decay: 0.16,
  p_base_freq: 0.07, p_freq_ramp: -0.1, p_lpf_freq: 0.2, p_lpf_resonance: 0.5,
});
// 심장박동 단타 "둑"(저음 사인)
make('heartbeat1.wav', {
  wave_type: 2, p_env_attack: 0.01, p_env_sustain: 0.05, p_env_punch: 0.3, p_env_decay: 0.22,
  p_base_freq: 0.055, p_freq_ramp: -0.06, p_lpf_freq: 0.14,
});
