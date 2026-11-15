// Generates the ZamNexus signature sound: a short, warm kalimba-style sting.
// Pure Node — no dependencies. Output: public/sounds/zamnexus-sting.wav
// Re-run with: node scripts/make-brand-sting.mjs

import {writeFile, mkdir} from 'node:fs/promises';
import {dirname} from 'node:path';
import {fileURLToPath} from 'node:url';

const SAMPLE_RATE = 44100;

// A rising A-major motif that resolves on a soft high A — friendly and short.
// [frequency Hz, start seconds, gain, decay seconds]
const notes = [
  [220.00, 0.00, 0.30, 0.55],  // A3 — warm low anchor
  [440.00, 0.10, 0.62, 0.60],  // A4
  [554.37, 0.30, 0.58, 0.60],  // C#5
  [659.25, 0.50, 0.58, 0.62],  // E5
  [880.00, 0.74, 0.44, 0.85],  // A5 — resolve, longest ring
];

const END = 1.9; // seconds — leaves the last note room to ring out
const total = Math.ceil(END * SAMPLE_RATE);
const buffer = new Float64Array(total);

for (const [frequency, start, gain, decay] of notes) {
  const begin = Math.floor(start * SAMPLE_RATE);
  // Kalimba tine: soft second/third partials give the wooden, plucked warmth.
  const partials = [[1, 1], [2, 0.32], [3, 0.12]];
  for (let i = begin; i < total; i++) {
    const t = (i - begin) / SAMPLE_RATE;
    const attack = Math.min(1, t / 0.006);           // fast 6 ms attack
    const envelope = attack * Math.exp(-t / decay);
    let sample = 0;
    for (const [multiple, level] of partials) {
      sample += level * Math.sin(2 * Math.PI * frequency * multiple * t);
    }
    buffer[i] += gain * envelope * sample;
  }
}

// Normalise to a comfortable level (leaves headroom, never clips).
const peak = Math.max(...buffer.map(Math.abs)) || 1;
const scale = 0.72 / peak;

const pcm = Buffer.alloc(total * 2);
for (let i = 0; i < total; i++) {
  pcm.writeInt16LE(Math.round(Math.max(-1, Math.min(1, buffer[i] * scale)) * 32767), i * 2);
}

// Standard 44-byte WAV header, mono 16-bit.
const header = Buffer.alloc(44);
header.write('RIFF', 0);
header.writeUInt32LE(36 + pcm.length, 4);
header.write('WAVE', 8);
header.write('fmt ', 12);
header.writeUInt32LE(16, 16);        // PCM chunk size
header.writeUInt16LE(1, 20);         // PCM format
header.writeUInt16LE(1, 22);         // mono
header.writeUInt32LE(SAMPLE_RATE, 24);
header.writeUInt32LE(SAMPLE_RATE * 2, 28); // byte rate
header.writeUInt16LE(2, 32);         // block align
header.writeUInt16LE(16, 34);        // bits per sample
header.write('data', 36);
header.writeUInt32LE(pcm.length, 40);

const out = fileURLToPath(new URL('../public/sounds/zamnexus-sting.wav', import.meta.url));
await mkdir(dirname(out), {recursive: true});
await writeFile(out, Buffer.concat([header, pcm]));
console.log(`Wrote ${out} (${(44 + pcm.length) / 1024} KB, ${END}s)`);
