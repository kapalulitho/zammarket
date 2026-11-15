import test from 'node:test';
import assert from 'node:assert/strict';
import {ownedCatalogue,safetyDraft} from '../src/lib/operations.js';
test('operations catalogue excludes another owner and deleted records and respects Lusaka date',()=>{
 const rows=[{id:1,user_id:'a',title:'Solar kit',location:'Lusaka',available_from:'2026-10-31'},{id:2,user_id:'b',title:'Solar kit'},{id:3,user_id:'a',deleted_at:'date'},{id:4,user_id:'a',title:'Solar kit',status:'sold'}];
 assert.deepEqual(ownedCatalogue(rows,'a','solar lusaka','Coming Soon',new Date('2026-10-30T21:00:00Z')).map(x=>x.id),[1]);
 assert.deepEqual(ownedCatalogue(rows,'a','','Available',new Date('2026-10-30T22:00:00Z')).map(x=>x.id),[1]);assert.equal(ownedCatalogue(rows,null).length,0);
});
test('safety preparation remains unsent and rejects invalid targets and obvious credentials',()=>{
 const value={kind:'listing',target:'listing-reference',reason:'Suspected scam',details:'The description contains conflicting information.'};
 assert.equal(safetyDraft(value).state,'unsent');assert.throws(()=>safetyDraft({...value,kind:'moderator'}));assert.throws(()=>safetyDraft({...value,target:''}));assert.throws(()=>safetyDraft({...value,reason:'anything'}));assert.throws(()=>safetyDraft({...value,details:'password=please-do-not-store-this'}));
});
