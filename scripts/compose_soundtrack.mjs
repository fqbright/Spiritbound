#!/usr/bin/env node
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SAMPLE_RATE = 44100;
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const godotAudioDir = resolve(root, 'Godot/assets/audio');
const expoAudioDir = resolve(root, 'Expo/assets/audio');
mkdirSync(godotAudioDir, { recursive: true });
mkdirSync(expoAudioDir, { recursive: true });

// Musical frequencies (MIDI -> Hz)
function m2f(midi) {
  return 440.0 * Math.pow(2.0, (midi - 69.0) / 12.0);
}

// Pseudo-random noise with seed
class PRNG {
  constructor(seed = 123456789) {
    this.s = seed;
  }
  next() {
    this.s = (Math.imul(this.s, 1664525) + 1013904223) | 0;
    return ((this.s >>> 0) / 4294967296) * 2.0 - 1.0;
  }
}

// Simple Schroeder / Freeverb-inspired Stereo Reverb
class StereoReverb {
  constructor(sampleRate) {
    const combDelays = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617];
    this.combL = combDelays.map(d => new Float32Array(Math.floor(d * sampleRate / 44100)));
    this.combR = combDelays.map(d => new Float32Array(Math.floor((d + 23) * sampleRate / 44100)));
    this.combIndexL = new Uint32Array(combDelays.length);
    this.combIndexR = new Uint32Array(combDelays.length);
    this.feedback = 0.82;

    const allpassDelays = [225, 341, 441, 556];
    this.apL = allpassDelays.map(d => new Float32Array(Math.floor(d * sampleRate / 44100)));
    this.apR = allpassDelays.map(d => new Float32Array(Math.floor((d + 17) * sampleRate / 44100)));
    this.apIndexL = new Uint32Array(allpassDelays.length);
    this.apIndexR = new Uint32Array(allpassDelays.length);
  }

  process(inL, inR, dry = 0.75, wet = 0.35) {
    let outL = 0;
    let outR = 0;

    for (let i = 0; i < this.combL.length; i++) {
      const bufL = this.combL[i];
      const idxL = this.combIndexL[i];
      const readL = bufL[idxL];
      bufL[idxL] = inL + readL * this.feedback;
      this.combIndexL[i] = (idxL + 1) % bufL.length;
      outL += readL;

      const bufR = this.combR[i];
      const idxR = this.combIndexR[i];
      const readR = bufR[idxR];
      bufR[idxR] = inR + readR * this.feedback;
      this.combIndexR[i] = (idxR + 1) % bufR.length;
      outR += readR;
    }
    outL *= 0.125;
    outR *= 0.125;

    for (let i = 0; i < this.apL.length; i++) {
      const bufL = this.apL[i];
      const idxL = this.apIndexL[i];
      const readL = bufL[idxL];
      const vL = outL - readL * 0.5;
      bufL[idxL] = vL;
      this.apIndexL[i] = (idxL + 1) % bufL.length;
      outL = readL + vL * 0.5;

      const bufR = this.apR[i];
      const idxR = this.apIndexR[i];
      const readR = bufR[idxR];
      const vR = outR - readR * 0.5;
      bufR[idxR] = vR;
      this.apIndexR[i] = (idxR + 1) % bufR.length;
      outR = readR + vR * 0.5;
    }

    return [
      inL * dry + outL * wet,
      inR * dry + outR * wet
    ];
  }
}

// Physical modeling & DSP Instruments
class InstrumentEngine {
  constructor(sampleRate) {
    this.sampleRate = sampleRate;
    this.prng = new PRNG(42);
  }

  // Guzheng / Guqin: Plucked string with Karplus-Strong & wooden body resonance
  pluckGuzheng(freq, duration, brightness = 0.85, vibrato = 0) {
    const len = Math.floor(duration * this.sampleRate);
    const buffer = new Float32Array(len);
    const delayLen = Math.max(2, Math.floor(this.sampleRate / freq));
    const delayLine = new Float32Array(delayLen);

    // Initial noise burst / pluck excitation
    for (let i = 0; i < delayLen; i++) {
      delayLine[i] = this.prng.next() * brightness;
    }

    let ptr = 0;
    let prev = 0;
    for (let i = 0; i < len; i++) {
      const vib = vibrato > 0 && i > this.sampleRate * 0.25 
        ? Math.sin(i / this.sampleRate * Math.PI * 2 * 5.2) * vibrato 
        : 0;
      const cur = delayLine[ptr];
      // One-pole lowpass filter in feedback loop (acoustic string dissipation)
      const filtered = (cur + prev) * 0.496;
      prev = filtered;
      delayLine[ptr] = filtered;
      ptr = (ptr + 1) % delayLen;

      // Wooden body formants (resonances around 320Hz and 780Hz)
      const t = i / this.sampleRate;
      const decay = Math.exp(-t * (freq > 400 ? 3.5 : 2.0));
      buffer[i] = (cur * 0.8 + Math.sin(t * Math.PI * 2 * 320) * 0.1 * decay) * (1.0 + vib * 0.2) * decay;
    }
    return buffer;
  }

  // Dizi / Xiao: Bamboo flute with breath chiff and harmonic overtones
  bambooFlute(freq, duration, vibratoAmount = 0.008) {
    const len = Math.floor(duration * this.sampleRate);
    const buffer = new Float32Array(len);
    let phase = 0;

    for (let i = 0; i < len; i++) {
      const t = i / this.sampleRate;
      // Envelope: soft breath attack, sustained, smooth release
      const attack = Math.min(1.0, t * 14.0);
      const release = Math.min(1.0, (duration - t) * 12.0);
      const env = attack * release;

      const vib = t > 0.15 ? Math.sin(t * Math.PI * 2 * 5.5) * vibratoAmount : 0;
      const instantFreq = freq * (1.0 + vib);
      phase += instantFreq / this.sampleRate;

      // Odd harmonics characteristic of stopped/open bamboo pipe + warm even harmonics
      const s1 = Math.sin(phase * Math.PI * 2);
      const s2 = Math.sin(phase * Math.PI * 4) * 0.35;
      const s3 = Math.sin(phase * Math.PI * 6) * 0.22;
      const s4 = Math.sin(phase * Math.PI * 8) * 0.08;

      // Air breath turbulence noise
      const breath = this.prng.next() * 0.04 * (attack > 0.8 ? 0.3 : 1.0);

      buffer[i] = (s1 + s2 + s3 + s4 + breath) * env * 0.45;
    }
    return buffer;
  }

  // Taiko War Drum: Pitch drop + resonant body + membrane slap
  taikoDrum(strength = 1.0, startPitch = 125, endPitch = 48) {
    const duration = 1.2;
    const len = Math.floor(duration * this.sampleRate);
    const buffer = new Float32Array(len);
    let phase = 0;

    for (let i = 0; i < len; i++) {
      const t = i / this.sampleRate;
      const env = Math.exp(-t * 5.5) * strength;
      const pitchEnv = Math.exp(-t * 22.0);
      const curFreq = endPitch + (startPitch - endPitch) * pitchEnv;
      phase += curFreq / this.sampleRate;

      const body = Math.sin(phase * Math.PI * 2) * 0.7 + Math.sin(phase * Math.PI * 4) * 0.25;
      const slap = this.prng.next() * Math.exp(-t * 45.0) * 0.5;
      buffer[i] = (body + slap) * env;
    }
    return buffer;
  }

  // Temple Chime / Bianzhong: Inharmonic metallic bells
  templeChime(pitchMidi = 74, duration = 3.5) {
    const len = Math.floor(duration * this.sampleRate);
    const buffer = new Float32Array(len);
    const f = m2f(pitchMidi);
    // Inharmonic modal ratios typical of bronze bells
    const modes = [1.0, 1.414, 1.732, 2.31, 3.01];
    const weights = [0.55, 0.28, 0.18, 0.12, 0.06];

    for (let i = 0; i < len; i++) {
      const t = i / this.sampleRate;
      let val = 0;
      for (let m = 0; m < modes.length; m++) {
        const modeFreq = f * modes[m];
        const decay = Math.exp(-t * (1.2 + m * 0.9));
        val += Math.sin(t * Math.PI * 2 * modeFreq) * weights[m] * decay;
      }
      // Initial hammer strike click
      const strike = this.prng.next() * Math.exp(-t * 70.0) * 0.12;
      buffer[i] = (val + strike) * 0.6;
    }
    return buffer;
  }

  // Cinematic Silk String Pad
  silkPad(freq, duration) {
    const len = Math.floor(duration * this.sampleRate);
    const buffer = new Float32Array(len);
    for (let i = 0; i < len; i++) {
      const t = i / this.sampleRate;
      const attack = Math.min(1.0, t * 1.5);
      const release = Math.min(1.0, (duration - t) * 1.8);
      const env = attack * release;

      // Warm ensemble chorus with 3 detuned oscillators
      const o1 = Math.sin(t * Math.PI * 2 * freq);
      const o2 = Math.sin(t * Math.PI * 2 * freq * 1.003 + 0.3);
      const o3 = Math.sin(t * Math.PI * 2 * freq * 0.997 + 0.6);
      const o4 = Math.sin(t * Math.PI * 2 * freq * 2.0) * 0.2;

      buffer[i] = (o1 + o2 + o3 + o4) * env * 0.18;
    }
    return buffer;
  }
}

// Track Mixer with Stereo Positioning
class AudioTrackMixer {
  constructor(durationSec, sampleRate = SAMPLE_RATE) {
    this.totalSamples = Math.floor(durationSec * sampleRate);
    this.sampleRate = sampleRate;
    this.left = new Float32Array(this.totalSamples);
    this.right = new Float32Array(this.totalSamples);
  }

  add(sampleBuffer, startSec, gain = 1.0, pan = 0.0) {
    const startSample = Math.floor(startSec * this.sampleRate);
    // Pan: -1 (full left) to +1 (full right)
    const panAngle = (pan + 1.0) * 0.25 * Math.PI;
    const gainL = Math.cos(panAngle) * gain;
    const gainR = Math.sin(panAngle) * gain;

    for (let i = 0; i < sampleBuffer.length; i++) {
      const targetIdx = (startSample + i) % this.totalSamples;
      this.left[targetIdx] += sampleBuffer[i] * gainL;
      this.right[targetIdx] += sampleBuffer[i] * gainR;
    }
  }

  renderWav() {
    const reverb = new StereoReverb(this.sampleRate);
    const outL = new Float32Array(this.totalSamples);
    const outR = new Float32Array(this.totalSamples);

    for (let i = 0; i < this.totalSamples; i++) {
      const [rL, rR] = reverb.process(this.left[i], this.right[i], 0.72, 0.38);
      // Soft saturation limiter to prevent digital clipping
      outL[i] = Math.tanh(rL * 1.15);
      outR[i] = Math.tanh(rR * 1.15);
    }

    const dataSize = this.totalSamples * 4;
    const buffer = Buffer.alloc(44 + dataSize);
    buffer.write('RIFF', 0);
    buffer.writeUInt32LE(36 + dataSize, 4);
    buffer.write('WAVEfmt ', 8);
    buffer.writeUInt32LE(16, 16);
    buffer.writeUInt16LE(1, 20); // PCM
    buffer.writeUInt16LE(2, 22); // Stereo
    buffer.writeUInt32LE(this.sampleRate, 24);
    buffer.writeUInt32LE(this.sampleRate * 4, 28);
    buffer.writeUInt16LE(4, 32); // Block align
    buffer.writeUInt16LE(16, 34); // 16-bit
    buffer.write('data', 36);
    buffer.writeUInt32LE(dataSize, 40);

    for (let i = 0; i < this.totalSamples; i++) {
      const sL = Math.max(-1.0, Math.min(1.0, outL[i]));
      const sR = Math.max(-1.0, Math.min(1.0, outR[i]));
      buffer.writeInt16LE(Math.round(sL * 32767), 44 + i * 4);
      buffer.writeInt16LE(Math.round(sR * 32767), 46 + i * 4);
    }
    return buffer;
  }
}

// ==========================================
// 1. Map Symphony: Ethereal Eastern Journey
// ==========================================
function composeMapSymphony() {
  const duration = 48.0; // 48-second seamless loopable suite
  const mixer = new AudioTrackMixer(duration);
  const eng = new InstrumentEngine(SAMPLE_RATE);

  // Pentatonic Roots in D (Yu/Gong mode: D, F, G, A, C)
  // Section A (0-12s): Mist & Temple Dawn
  // Section B (12-24s): Bamboo Flute Journey
  // Section C (24-36s): Grand Strings & Silk Swell
  // Section D (36-48s): Gentle Guzheng Cadence resolving back to A

  // 1. Chimes & Temple Gongs
  const chimeTimes = [0.0, 12.0, 24.0, 36.0];
  const chimePitches = [74, 69, 74, 69]; // D5, A4, D5, A4
  chimeTimes.forEach((t, i) => {
    mixer.add(eng.templeChime(chimePitches[i], 5.0), t, 0.45, (i % 2 === 0 ? -0.4 : 0.4));
  });

  // 2. Silk String Pads (Chords: Dm -> Bb -> F -> C)
  const padProgression = [
    { start: 0.0, dur: 12.0, notes: [50, 57, 65] },  // D, A, F
    { start: 12.0, dur: 12.0, notes: [46, 53, 62] }, // Bb, F, D
    { start: 24.0, dur: 12.0, notes: [41, 48, 57] }, // F, C, A
    { start: 36.0, dur: 12.0, notes: [48, 55, 60] }, // C, G, C
  ];
  padProgression.forEach(chord => {
    chord.notes.forEach((midi, idx) => {
      mixer.add(eng.silkPad(m2f(midi), chord.dur), chord.start, 0.32, (idx - 1) * 0.45);
    });
  });

  // 3. Guzheng Flowing Arpeggios (Pentatonic cascading notes)
  const guzhengPattern = [
    // Sec A
    { t: 1.0, m: 62 }, { t: 2.5, m: 65 }, { t: 3.5, m: 69 }, { t: 5.0, m: 72 }, { t: 6.5, m: 69 }, { t: 8.0, m: 65 }, { t: 9.5, m: 62 }, { t: 11.0, m: 57 },
    // Sec B
    { t: 13.0, m: 58 }, { t: 14.5, m: 62 }, { t: 16.0, m: 65 }, { t: 17.5, m: 69 }, { t: 19.0, m: 70 }, { t: 20.5, m: 65 }, { t: 22.0, m: 62 },
    // Sec C
    { t: 25.0, m: 65 }, { t: 26.5, m: 69 }, { t: 28.0, m: 72 }, { t: 29.5, m: 77 }, { t: 31.0, m: 74 }, { t: 32.5, m: 72 }, { t: 34.0, m: 69 },
    // Sec D
    { t: 37.0, m: 60 }, { t: 38.5, m: 64 }, { t: 40.0, m: 67 }, { t: 41.5, m: 72 }, { t: 43.0, m: 69 }, { t: 44.5, m: 65 }, { t: 46.0, m: 62 },
  ];
  guzhengPattern.forEach((note, i) => {
    const pan = Math.sin(note.t * 0.8) * 0.55;
    mixer.add(eng.pluckGuzheng(m2f(note.m), 2.8, 0.88, 0.005), note.t, 0.42, pan);
  });

  // 4. Bamboo Flute Expressive Melody (Section B & C)
  const fluteNotes = [
    // Lead melody entering in Section B
    { t: 13.0, m: 69, dur: 2.2 }, // A4
    { t: 15.5, m: 72, dur: 1.8 }, // C5
    { t: 17.5, m: 74, dur: 3.2 }, // D5
    { t: 21.0, m: 72, dur: 1.4 },
    { t: 22.5, m: 69, dur: 2.0 },
    // Peak melody in Section C
    { t: 25.0, m: 74, dur: 2.4 }, // D5
    { t: 27.5, m: 77, dur: 2.2 }, // F5
    { t: 30.0, m: 76, dur: 1.5 }, // E5
    { t: 31.5, m: 74, dur: 2.0 }, // D5
    { t: 33.5, m: 69, dur: 3.5 }, // A4 resolve
    // Gentle echo in Section D
    { t: 38.0, m: 72, dur: 2.5 },
    { t: 41.0, m: 65, dur: 2.2 },
    { t: 43.5, m: 62, dur: 4.0 }, // D4 resolve
  ];
  fluteNotes.forEach(fn => {
    mixer.add(eng.bambooFlute(m2f(fn.m), fn.dur), fn.t, 0.52, -0.15);
  });

  // 5. Gentle Earth Drum pulses in background (sparse, breathing)
  const drumBeats = [6.0, 12.0, 18.0, 24.0, 27.0, 30.0, 33.0, 36.0, 42.0];
  drumBeats.forEach(t => {
    mixer.add(eng.taikoDrum(0.45, 95, 42), t, 0.35, 0.0);
  });

  return mixer.renderWav();
}

// ==========================================
// 2. Battle Stages 0 to 4: Dynamic War Orchestras
// ==========================================
function composeBattleStage(stageIndex) {
  // Stage 0: Mistwood - Rhythmic, stealthy, brisk
  // Stage 1: Ashlands - Fiery, fast percussion, urgent
  // Stage 2: Glacial Peaks - Grand, echoing, majestic
  // Stage 3: Starfall - Ethereal celestial bells & soaring countermelodies
  // Stage 4: Abyssal Rift - Thunderous Taiko, epic choir & maximum intensity
  const duration = stageIndex === 4 ? 36.0 : 32.0;
  const mixer = new AudioTrackMixer(duration);
  const eng = new InstrumentEngine(SAMPLE_RATE);

  const tempoBpm = 110 + stageIndex * 7; // 110 up to 138 BPM
  const beatSec = 60.0 / tempoBpm;
  const totalBeats = Math.floor(duration / beatSec);

  // 1. Taiko War Drums & Martial Percussion
  for (let b = 0; b < totalBeats; b++) {
    const t = b * beatSec;
    // Primary kick on beat 1 & 3, additional rolls on higher stages
    if (b % 4 === 0) {
      mixer.add(eng.taikoDrum(0.85 + stageIndex * 0.05, 130 + stageIndex * 10, 44), t, 0.65, -0.1);
    } else if (b % 4 === 2) {
      mixer.add(eng.taikoDrum(0.70, 115, 48), t, 0.52, 0.1);
    } else if (stageIndex >= 1 && b % 2 === 1) {
      // Syncopated percussion
      mixer.add(eng.taikoDrum(0.48, 140, 58), t, 0.38, (b % 4 === 1 ? -0.3 : 0.3));
    }
    // High stage rapid drum rolls
    if (stageIndex >= 3 && b % 8 === 7) {
      mixer.add(eng.taikoDrum(0.55, 160, 65), t + beatSec * 0.5, 0.42, 0.2);
    }
  }

  // 2. Driving Guzheng Martial Riffs (Plucked ostinato)
  // Pentatonic scales: Stage 0-2 (D Yu: D, F, G, A, C), Stage 3-4 (E Phrygian/Gong: E, G, A, B, D)
  const rootMidi = stageIndex >= 3 ? 40 : 38; // E or D
  const scaleOffsets = [0, 3, 5, 7, 10, 12, 15, 17, 19, 22];

  for (let b = 0; b < totalBeats * 2; b++) {
    const t = b * (beatSec / 2.0);
    const step = b % 16;
    // Driving syncopated pattern
    if ([0, 2, 3, 6, 8, 10, 11, 14].includes(step)) {
      const noteIdx = (step + Math.floor(b / 16) * 2) % scaleOffsets.length;
      const midi = rootMidi + 12 + scaleOffsets[noteIdx];
      const pan = ((step % 4) - 1.5) * 0.4;
      mixer.add(eng.pluckGuzheng(m2f(midi), 1.2, 0.92, 0.003), t, 0.38 + stageIndex * 0.04, pan);
    }
  }

  // 3. Bamboo Flute Heroic Battle Theme (Phased in 2 movements)
  const leadPhrases = [
    // Phrase 1 (First half)
    { beat: 4, m: rootMidi + 24, dur: beatSec * 3 },
    { beat: 8, m: rootMidi + 27, dur: beatSec * 2.5 },
    { beat: 12, m: rootMidi + 29, dur: beatSec * 3.5 },
    { beat: 16, m: rootMidi + 27, dur: beatSec * 2 },
    { beat: 20, m: rootMidi + 24, dur: beatSec * 3 },
    // Phrase 2 (Second half - climactic flourish)
    { beat: 28, m: rootMidi + 29, dur: beatSec * 2.5 },
    { beat: 32, m: rootMidi + 31, dur: beatSec * 3 },
    { beat: 36, m: rootMidi + 34, dur: beatSec * 4 },
    { beat: 42, m: rootMidi + 31, dur: beatSec * 2 },
    { beat: 46, m: rootMidi + 29, dur: beatSec * 3 },
  ];
  leadPhrases.forEach(p => {
    if (p.beat * beatSec < duration - 2.0) {
      mixer.add(eng.bambooFlute(m2f(p.m), p.dur, 0.012), p.beat * beatSec, 0.55, -0.2);
    }
  });

  // 4. Harmonic Silk Strings Support (Dark power chords)
  const barSec = beatSec * 4;
  const numBars = Math.floor(duration / barSec);
  for (let bar = 0; bar < numBars; bar++) {
    const t = bar * barSec;
    const chordRoot = rootMidi + (bar % 4 === 1 ? 3 : (bar % 4 === 2 ? 7 : (bar % 4 === 3 ? 5 : 0)));
    mixer.add(eng.silkPad(m2f(chordRoot), barSec * 1.05), t, 0.28, -0.3);
    mixer.add(eng.silkPad(m2f(chordRoot + 7), barSec * 1.05), t, 0.24, 0.3);
    if (stageIndex >= 2) {
      mixer.add(eng.silkPad(m2f(chordRoot + 12), barSec * 1.05), t, 0.20, 0.0);
    }
  }

  // 5. Climax Accents (Gongs & Bianzhong chimes on section markers)
  for (let s = 0; s < duration; s += 8.0) {
    mixer.add(eng.templeChime(rootMidi + 24, 4.0), s, 0.50 + stageIndex * 0.08, 0.35);
  }

  return mixer.renderWav();
}

console.log('🎵 Starting Spiritbound Eastern Orchestral Composition Engine...');

// Generate Map Symphony
console.log('🎼 Composing Map Symphony: Ethereal Eastern Journey (48s Suite)...');
const mapWav = composeMapSymphony();
writeFileSync(resolve(godotAudioDir, 'map_symphony.wav'), mapWav);
writeFileSync(resolve(godotAudioDir, 'spirit-path-v2.wav'), mapWav);
writeFileSync(resolve(expoAudioDir, 'spirit-path-v2.wav'), mapWav);
console.log('   ✓ map_symphony.wav rendered successfully.');

// Generate 5 Battle Stages
for (let stage = 0; stage < 5; stage++) {
  console.log(`⚔️ Composing Battle Stage ${stage} Orchestral Suite...`);
  const battleWav = composeBattleStage(stage);
  const stageName = `battle_stage_${stage}.wav`;
  writeFileSync(resolve(godotAudioDir, stageName), battleWav);
  if (stage === 0) {
    writeFileSync(resolve(godotAudioDir, 'ember-battle-v2.wav'), battleWav);
    writeFileSync(resolve(expoAudioDir, 'ember-battle-v2.wav'), battleWav);
  }
  console.log(`   ✓ ${stageName} rendered successfully.`);
}

console.log('✨ All Eastern orchestral master tracks generated successfully in Godot and Expo assets!');
