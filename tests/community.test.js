import test from 'node:test';import assert from 'node:assert/strict';
import {moduleInput} from '../src/lib/community.js';
const base={title:'Local workshop',description:'A useful local workshop',location:'Lusaka',status:'published',price:'0',starts_at:'2026-11-01T10:00',ends_at:'2026-11-01T12:00'};
test('module input normalises fields, accepts free events and interprets dates in Zambia time',()=>{const value=moduleInput('event',base);assert.equal(value.starts_at,'2026-11-01T08:00:00.000Z');assert.equal(value.price,0);assert.equal(value.status,'published');});
test('module validation rejects unsafe prices, backwards times and unsupported types',()=>{assert.throws(()=>moduleInput('event',{...base,ends_at:'2026-11-01T09:00'}));assert.throws(()=>moduleInput('job',{...base,price:'-1'}));assert.throws(()=>moduleInput('unknown',base));assert.throws(()=>moduleInput('event',{...base,starts_at:''}));});
