// デモ実画面のスクショ → LP用webp
// ★UIのスクショは写真より高い品質が要る（文字が潰れると「実物」の説得力が消える）＝quality 84・幅1600
// 実行: node D:/work/lp-sample/optimize-shots.mjs
import sharp from 'file:///D:/work/image-gen/node_modules/sharp/dist/index.mjs';
import fs from 'fs';
import path from 'path';

const SHOTS = 'D:/work/lp-sample/assets/shots';
const ASSETS = 'D:/work/lp-sample/assets';

const jobs = [
  { src: `${SHOTS}/ui-01-sales-dashboard.png`, out: `${SHOTS}/ui-01-sales-dashboard.webp`, w: 1800 },
  { src: `${SHOTS}/ui-02-sales-report.png`,    out: `${SHOTS}/ui-02-sales-report.webp`,    w: 1600 },
  { src: `${SHOTS}/ui-03-process.png`,         out: `${SHOTS}/ui-03-process.webp`,         w: 1600 },
  { src: `${SHOTS}/ui-04-process-b.png`,       out: `${SHOTS}/ui-04-process-b.webp`,       w: 1600 },
  { src: `${ASSETS}/kintone-arari.png`,        out: `${SHOTS}/ui-05-kintone.webp`,         w: 1600 },
];

console.log('name | 元 | 後 | 元KB | 後KB');
for (const j of jobs) {
  if (!fs.existsSync(j.src)) { console.log(`${path.basename(j.src)} | 元ファイル無し`); continue; }
  const before = fs.statSync(j.src).size;
  const m0 = await sharp(j.src).metadata();
  await sharp(j.src).resize({ width: j.w, withoutEnlargement: true }).webp({ quality: 84 }).toFile(j.out);
  const m1 = await sharp(j.out).metadata();
  const after = fs.statSync(j.out).size;
  console.log(`${path.basename(j.out)} | ${m0.width}x${m0.height} | ${m1.width}x${m1.height} | ${(before/1024)|0}KB | ${(after/1024)|0}KB`);
}
const total = fs.readdirSync(SHOTS).filter(f => f.endsWith('.webp'))
  .reduce((s, f) => s + fs.statSync(path.join(SHOTS, f)).size, 0);
console.log(`webp合計: ${(total/1024/1024).toFixed(2)}MB`);
