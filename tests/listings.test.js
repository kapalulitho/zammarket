import test from 'node:test';
import assert from 'node:assert/strict';
import { listingPhotos, listingInput, validatePhoto } from '../src/lib/listings.js';

const valid = {title:' Phone ',price:'2500',category:'Phones',location:' Lusaka ',description:' Working phone '};
test('photo display supports legacy and array fields without duplicates', () => {
  assert.deepEqual(listingPhotos({image_urls:['https://example.invalid/a.jpg','javascript:alert(1)'],image_url:'https://example.invalid/a.jpg'}),['https://example.invalid/a.jpg']);
  assert.deepEqual(listingPhotos({image_url:'https://example.invalid/old.jpg'}),['https://example.invalid/old.jpg']);
});
test('posting input trims fields and keeps custom categories', () => {
  const value=listingInput({...valid,category:'Others',customCategory:' Books '});
  assert.equal(value.title,'Phone'); assert.equal(value.category,'Books');
  assert.equal(value.price,2500); assert.equal(value.available_from,null);
});
test('rejects invalid prices, whitespace-only fields, and impossible dates', () => {
  for (const price of ['',' ','Infinity','-1','invalid']) assert.throws(() => listingInput({...valid,price}));
  assert.throws(() => listingInput({...valid,title:'  '}));
  assert.throws(() => listingInput({...valid,availability:'date',available_from:'2026-02-30'}));
  assert.equal(listingInput({...valid,availability:'date',available_from:'2028-02-29'}).available_from,'2028-02-29');
});
test('accepts matching JPEG PNG WebP signatures', async () => {
  const values = [
    ['image/jpeg',[255,216,255,224],'jpg'],
    ['image/png',[137,80,78,71,13,10,26,10],'png'],
    ['image/webp',[82,73,70,70,0,0,0,0,87,69,66,80],'webp'],
  ];
  for (const [type,bytes,extension] of values) {
    assert.equal(await validatePhoto(new Blob([new Uint8Array(bytes)],{type})),extension);
  }
});
test('rejects disguised files, empty files, unsupported types, oversized photos', async () => {
  await assert.rejects(validatePhoto(new Blob(['not an image'],{type:'image/jpeg'})));
  await assert.rejects(validatePhoto(new Blob([],{type:'image/png'})));
  await assert.rejects(validatePhoto(new Blob(['<svg/>'],{type:'image/svg+xml'})));
  await assert.rejects(validatePhoto(new Blob([new Uint8Array(5*1024*1024+1)],{type:'image/jpeg'})));
});
