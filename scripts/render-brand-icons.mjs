// Optional authoring tool. The generated PNGs are committed assets; the app does
// not load this renderer. Install it under .validation to regenerate icons.
import fs from 'node:fs';
import { Resvg } from '../.validation/node_modules/@resvg/resvg-js/index.js';
const mark = fs.readFileSync('public/brand-mark.svg','utf8');
fs.writeFileSync('public/favicon.svg',mark);
const content = mark.replace(/^<svg[^>]*>/,'').replace(/<\/svg>\s*$/,'');
const icon = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96" fill="none"><rect width="96" height="96" fill="#f0f5ff"/><g transform="translate(16 15)">${content}</g></svg>`;
fs.writeFileSync('public/app-icon.svg',icon);
for (const [name,size] of [['icon-192.png',192],['icon-512.png',512],['apple-touch-icon.png',180],['favicon-32.png',32]]) {
  fs.writeFileSync(`public/${name}`,new Resvg(icon,{fitTo:{mode:'width',value:size}}).render().asPng());
}
