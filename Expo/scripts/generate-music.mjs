import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const sampleRate = 22050;
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const output = resolve(root, 'assets/audio');
mkdirSync(output, { recursive: true });

const frequency = midi => 440 * 2 ** ((midi - 69) / 12);
const sine = (hz, time, phase = 0) => Math.sin(Math.PI * 2 * hz * time + phase);
const triangle = (hz, time) => 2 * Math.asin(sine(hz, time)) / Math.PI;
const smooth = phase => Math.sin(Math.PI * Math.min(1, Math.max(0, phase))) ** 1.3;
const pluck = phase => Math.exp(-5.2 * phase) * Math.min(1, phase * 32);
const hashNoise = frame => {
  let value = (Math.imul(frame + 0x6d2b79f5, 1664525) + 1013904223) >>> 0;
  value ^= value >>> 15;
  return value / 4294967296 * 2 - 1;
};

function writeStereoWave(name, seconds, synth) {
  const frames = Math.floor(sampleRate * seconds);
  const dataSize = frames * 4;
  const wave = Buffer.alloc(44 + dataSize);
  wave.write('RIFF', 0); wave.writeUInt32LE(36 + dataSize, 4); wave.write('WAVEfmt ', 8);
  wave.writeUInt32LE(16, 16); wave.writeUInt16LE(1, 20); wave.writeUInt16LE(2, 22);
  wave.writeUInt32LE(sampleRate, 24); wave.writeUInt32LE(sampleRate * 4, 28);
  wave.writeUInt16LE(4, 32); wave.writeUInt16LE(16, 34); wave.write('data', 36); wave.writeUInt32LE(dataSize, 40);
  for (let frame = 0; frame < frames; frame++) {
    const time = frame / sampleRate;
    const edge = Math.min(1, time * 18, (seconds - time) * 18);
    const [left, right] = synth(time, frame);
    wave.writeInt16LE(Math.round(Math.max(-1, Math.min(1, left * edge)) * 32767), 44 + frame * 4);
    wave.writeInt16LE(Math.round(Math.max(-1, Math.min(1, right * edge)) * 32767), 46 + frame * 4);
  }
  writeFileSync(resolve(output, name), wave);
}

function writeMonoWave(name, seconds, synth) {
  const frames = Math.floor(sampleRate * seconds);
  const dataSize = frames * 2;
  const wave = Buffer.alloc(44 + dataSize);
  wave.write('RIFF', 0); wave.writeUInt32LE(36 + dataSize, 4); wave.write('WAVEfmt ', 8);
  wave.writeUInt32LE(16, 16); wave.writeUInt16LE(1, 20); wave.writeUInt16LE(1, 22);
  wave.writeUInt32LE(sampleRate, 24); wave.writeUInt32LE(sampleRate * 2, 28);
  wave.writeUInt16LE(2, 32); wave.writeUInt16LE(16, 34); wave.write('data', 36); wave.writeUInt32LE(dataSize, 40);
  for (let frame = 0; frame < frames; frame++) {
    const time = frame / sampleRate;
    const edge = Math.min(1, time * 10, (seconds - time) * 10);
    const sample = Math.tanh(synth(time, frame) * 1.08) * edge;
    wave.writeInt16LE(Math.round(Math.max(-1, Math.min(1, sample)) * 32767), 44 + frame * 2);
  }
  writeFileSync(resolve(output, name), wave);
}

// 32-second combat suite: four eight-second movements share a motif but change
// harmony, register, percussion density, and countermelody before looping.
const battleLead = [
  62, 65, 69, 67, 65, 62, 57, 60, 62, 67, 70, 69, 65, 64, 60, 57,
  62, 65, 69, 74, 72, 69, 67, 65, 64, 67, 72, 70, 69, 65, 62, 60,
  57, 60, 65, 64, 62, 57, 55, 57, 60, 64, 67, 69, 67, 64, 60, 57,
  62, 69, 67, 74, 72, 70, 69, 65, 67, 72, 70, 67, 65, 64, 62, 57,
];
const battleRoots = [38, 34, 41, 36, 38, 43, 34, 36];
writeStereoWave('ember-battle-v2.wav', 32, (time, frame) => {
  const eighth = 0.5;
  const step = Math.floor(time / eighth) % battleLead.length;
  const phase = (time % eighth) / eighth;
  const beatPhase = (time % 1) / 1;
  const quarterPhase = (time % 0.25) / 0.25;
  const section = Math.floor(time / 8);
  const rootMidi = battleRoots[Math.floor(time / 4) % battleRoots.length];
  const leadHz = frequency(battleLead[step] + (section === 3 && step % 4 === 0 ? 12 : 0));
  const rootHz = frequency(rootMidi);
  const fifthHz = frequency(rootMidi + 7);
  const leadEnvelope = pluck(phase);
  const lead = leadEnvelope * (0.14 * triangle(leadHz, time) + 0.055 * sine(leadHz * 2.002, time));
  const counterMidi = battleLead[(step + 11) % battleLead.length] - 12;
  const counter = section >= 1 && step % 2 === 1 ? pluck(phase) * 0.065 * sine(frequency(counterMidi), time) : 0;
  const bass = 0.105 * triangle(step % 4 < 3 ? rootHz : fifthHz, time) * (0.55 + 0.45 * Math.exp(-4 * beatPhase));
  const pad = 0.032 * sine(rootHz, time) + 0.026 * sine(fifthHz, time, 0.4) + 0.018 * sine(frequency(rootMidi + (section % 2 ? 10 : 3)), time, 0.8);
  const kick = 0.18 * Math.exp(-17 * beatPhase) * sine(70 - 35 * beatPhase, time);
  const secondKick = section >= 2 ? 0.1 * Math.exp(-20 * ((time + 0.5) % 1)) * sine(62, time) : 0;
  const shakerGate = section === 0 ? (step % 2) : 1;
  const shaker = shakerGate * hashNoise(frame) * 0.026 * Math.exp(-22 * quarterPhase);
  const accent = step % 8 === 6 ? hashNoise(frame + 91) * 0.045 * Math.exp(-12 * phase) : 0;
  const pan = 0.14 * Math.sin(time * Math.PI / 4);
  const center = bass + pad + kick + secondKick;
  return [center + lead * (1 - pan) + counter * (1 + pan) + shaker + accent, center + lead * (1 + pan) + counter * (1 - pan) + shaker - accent * 0.4];
});

// 28-second journey theme: a slower call-and-response melody with breathing
// spaces, changing chords, bell overtones, low flute, and a soft stereo breeze.
const journeyMelody = [62, 65, 69, 72, 69, 65, 64, -1, 67, 71, 74, 71, 67, 64, 62, -1, 65, 69, 76, 74, 72, 69, 67, -1, 62, 67, 71, 69];
const journeyRoots = [50, 48, 45, 53, 50, 55, 48];
writeStereoWave('spirit-path-v2.wav', 28, (time, frame) => {
  const stepLength = 1;
  const step = Math.floor(time / stepLength) % journeyMelody.length;
  const phase = time % stepLength;
  const rootMidi = journeyRoots[Math.floor(time / 4) % journeyRoots.length];
  const note = journeyMelody[step];
  const bell = note < 0 ? 0 : pluck(phase) * (0.12 * sine(frequency(note), time) + 0.048 * sine(frequency(note) * 2.01, time) + 0.02 * sine(frequency(note) * 3.98, time));
  const answerNote = journeyMelody[(step + 7) % journeyMelody.length];
  const answerPhase = (time + 0.5) % 1;
  const flute = answerNote < 0 || phase < 0.48 ? 0 : smooth(answerPhase) * 0.045 * sine(frequency(answerNote - 12), time, 0.3);
  const root = frequency(rootMidi);
  const mist = 0.05 * sine(root, time) + 0.035 * sine(frequency(rootMidi + 7), time, 0.4) + 0.025 * sine(frequency(rootMidi + 12), time, 0.9);
  const breeze = hashNoise(frame) * 0.007 * (0.45 + 0.55 * sine(0.08, time) ** 2);
  const pan = 0.22 * Math.sin(time * Math.PI / 7);
  return [mist + bell * (1 - pan) + flute * (1 + pan) + breeze, mist + bell * (1 + pan) + flute * (1 - pan) - breeze];
});

// 48-second original symphonic map theme. Four connected movements grow from
// low strings into horns, choir, timpani, and a broad final statement. Mono PCM
// keeps the Expo Go asset near 2 MB while preserving a long, non-repetitive loop.
const symphonyRoots = [38, 34, 41, 36, 38, 43, 34, 36, 38, 46, 41, 45];
const heroicTheme = [62, 65, 69, 67, 65, 69, 74, 72, 69, 67, 65, 62, 57, 60, 65, 69, 67, 65, 64, 60, 62, 69, 67, 74];
writeMonoWave('spirit-symphony-mobile.wav', 48, (time, frame) => {
  const bar = Math.floor(time / 4); const barPhase = (time % 4) / 4; const section = Math.floor(time / 12);
  const rootMidi = symphonyRoots[bar % symphonyRoots.length]; const root = frequency(rootMidi);
  const swell = 0.28 + 0.72 * smooth(barPhase); const vibrato = 1 + 0.0025 * sine(5.1, time);
  const strings = swell * (0.075 * triangle(root * vibrato, time) + 0.052 * sine(frequency(rootMidi + 7) * vibrato, time, 0.3) + 0.042 * sine(frequency(rootMidi + (bar % 3 === 1 ? 10 : 3)) * vibrato, time, 0.8));
  const ostStep = Math.floor(time / 0.5); const ostPhase = (time % 0.5) / 0.5;
  const ostNotes = [0, 7, 12, 7, 3, 7, 12, 7]; const ostinato = (section >= 1 ? 0.052 : 0.025) * pluck(ostPhase) * triangle(frequency(rootMidi + ostNotes[ostStep % 8]), time);
  const themeStep = Math.floor(time) % heroicTheme.length; const themePhase = time % 1; const themeMidi = heroicTheme[themeStep] + (section === 3 ? 12 : 0);
  const hornGate = section === 0 ? (bar >= 2 ? 0.45 : 0) : section === 1 ? 0.72 : 1;
  const hornEnvelope = Math.min(1, themePhase * 8) * Math.min(1, (1 - themePhase) * 5);
  const horns = hornGate * hornEnvelope * (0.09 * sine(frequency(themeMidi), time) + 0.035 * triangle(frequency(themeMidi) / 2, time));
  const choir = section >= 2 ? (0.032 + section * 0.008) * (sine(frequency(rootMidi + 12), time, 0.4) + 0.7 * sine(frequency(rootMidi + 19), time, 1.1)) : 0;
  const beatPhase = time % 1; const timpani = (section >= 1 || barPhase < 0.08) ? 0.13 * Math.exp(-11 * beatPhase) * sine(63 - 18 * beatPhase, time) : 0;
  const halfBeat = (time + 0.5) % 1; const march = section >= 2 ? hashNoise(frame + 223) * 0.018 * Math.exp(-18 * halfBeat) : 0;
  const cymbalPhase = time % 12; const cymbal = (section > 0 && cymbalPhase < 1.4) ? hashNoise(frame) * 0.035 * Math.exp(-2.6 * cymbalPhase) : 0;
  const finale = section === 3 ? 0.035 * sine(frequency(rootMidi + 24), time, 0.7) * (0.55 + 0.45 * sine(0.25, time)) : 0;
  return strings + ostinato + horns + choir + timpani + march + cymbal + finale;
});

console.log(`Generated longer, multi-section original music including the mobile symphonic theme in ${output}`);
