// 최종 발사음 풀 — "샤프 크랙" 계열 3변형 (사용자 승인: 크랙+펀치 레이어드)
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
// 승인된 원본
make('crack_a.wav', {
  wave_type: 3, p_env_attack: 0, p_env_sustain: 0.05, p_env_punch: 0.8, p_env_decay: 0.2,
  p_base_freq: 0.24, p_freq_ramp: -0.42, p_lpf_freq: 0.75, p_lpf_ramp: -0.3, p_hpf_freq: 0.08,
});
// 변형 1: 살짝 낮고 감쇠 김
make('crack_b.wav', {
  wave_type: 3, p_env_attack: 0, p_env_sustain: 0.06, p_env_punch: 0.75, p_env_decay: 0.24,
  p_base_freq: 0.21, p_freq_ramp: -0.38, p_lpf_freq: 0.68, p_lpf_ramp: -0.28, p_hpf_freq: 0.07,
});
// 변형 2: 살짝 높고 더 짧음
make('crack_c.wav', {
  wave_type: 3, p_env_attack: 0, p_env_sustain: 0.045, p_env_punch: 0.85, p_env_decay: 0.17,
  p_base_freq: 0.27, p_freq_ramp: -0.46, p_lpf_freq: 0.8, p_lpf_ramp: -0.32, p_hpf_freq: 0.09,
});
