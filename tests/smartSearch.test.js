import test from 'node:test';
import assert from 'node:assert/strict';
import {parseSmartSearch,smartMatches} from '../src/lib/smartSearch.js';
import {campusOf} from '../src/lib/campuses.js';
test('a plain word is left to normal search',()=>{assert.equal(parseSmartSearch('phone'),null);assert.equal(parseSmartSearch(''),null);});
test('understands a budget and a product',()=>{
  const parsed=parseSmartSearch('I need a good phone under K5,000');
  assert.equal(parsed.maxPrice,5000);assert.deepEqual(parsed.keywords,['phone']);
  assert.ok(smartMatches({title:'Samsung Galaxy',price:'4500'},parsed));
  assert.equal(smartMatches({title:'Samsung Galaxy',price:'6500'},parsed),false);
});
test('understands thousands and campuses',()=>{
  const parsed=parseSmartSearch('laptop below 3k near UNZA');
  assert.equal(parsed.maxPrice,3000);assert.equal(parsed.campus,'unza');
  assert.ok(smartMatches({title:'Dell laptop',price:2500,description:'Campus: UNZA'},parsed));
  assert.equal(smartMatches({title:'Dell laptop',price:2500,description:'Campus: CBU'},parsed),false);
});
test('routes a section word with a campus to that section',()=>{assert.equal(parseSmartSearch('accommodation near UNZA').section,'Stays');});
test('finds the campus of a listing',()=>{assert.equal(campusOf({location:'Kitwe',description:'Campus: CBU'}),'cbu');assert.equal(campusOf({title:'Shoes'}),null);});
