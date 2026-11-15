import test from 'node:test';
import assert from 'node:assert/strict';
import {filterProducts,rememberViewed,compareSelection} from '../src/lib/discovery.js';
import {resolveTheme} from '../src/lib/theme.js';
import {desktopNavigation,moreNavigation,zambiaProvinces} from '../src/config/platform.js';
import {formatZambiaLocation} from '../src/lib/locations.js';
const rows=[{id:1,title:'Blue phone',category:'Phones',description:'Box included',price:100,location:'Lusaka',condition:'Used'},{id:2,title:'New phone',price:200,category:'Phones',location:'Ndola',condition:'New'},{id:3,title:'Free case',price:0,location:'Lusaka'},{id:4,title:'Unpriced',price:null}];
test('discovery combines search terms across fields with location, condition and inclusive price filters',()=>{
 assert.deepEqual(filterProducts(rows,{search:'PHONE box LUSAKA',minPrice:'100',maxPrice:'100',condition:'Used'}).map(item=>item.id),[1]);
 assert.deepEqual(filterProducts(rows,{location:'lusaka',maxPrice:'0'}).map(item=>item.id),[3]);
 assert.deepEqual(filterProducts(rows,{category:'Phones',condition:'New'}).map(item=>item.id),[2]);
 assert.deepEqual(filterProducts(rows,{minPrice:'200',maxPrice:'100'}),[]);
 assert.deepEqual(filterProducts(rows,{minPrice:'invalid'}),[]);
 assert.deepEqual(filterProducts(rows,{minPrice:'-1'}),[]);
});
test('recent views deduplicate and cap history while comparisons enforce a three-product limit',()=>{
 assert.deepEqual(rememberViewed(['2','1','3'],1,3),['1','2','3']);
 assert.deepEqual(rememberViewed(Array.from({length:15},(_,i)=>String(i)),99).length,12);
 assert.deepEqual(compareSelection(['1','2','3'],'4'),['1','2','3']);
 assert.deepEqual(compareSelection(['1','2','3'],'2'),['1','3']);
 assert.deepEqual(compareSelection(['1'],2),['1','2']);
});
test('theme preference respects explicit choices and system appearance',()=>{
 assert.equal(resolveTheme('dark',false),'dark');assert.equal(resolveTheme('light',true),'light');
 assert.equal(resolveTheme('system',true),'dark');assert.equal(resolveTheme('system',false),'light');
});
test('platform navigation is unique and Zambia has all ten province choices',()=>{
 assert.equal(new Set(desktopNavigation.map(([page])=>page)).size,desktopNavigation.length);
 assert.equal(desktopNavigation.length,5);assert.deepEqual(desktopNavigation.map(([page])=>page),['Home','Explore','Messages','My Activity','Account']);
 assert.ok(moreNavigation.some(([page])=>page==='Cart'));assert.equal(new Set([...desktopNavigation,...moreNavigation].map(([page])=>page)).size,desktopNavigation.length+moreNavigation.length);
 assert.equal(zambiaProvinces.length,10);assert.equal(new Set(zambiaProvinces).size,10);
 assert.ok(zambiaProvinces.includes('Muchinga'));assert.ok(zambiaProvinces.includes('North-Western'));
});
test('posting formats a trimmed town and valid province without inventing region mappings',()=>{
 assert.equal(formatZambiaLocation(' Chongwe ','Lusaka'),'Chongwe, Lusaka');
 assert.equal(formatZambiaLocation('   ','Lusaka'),'');
 assert.equal(formatZambiaLocation('Chongwe','Unknown'),'');
 assert.equal(formatZambiaLocation('x'.repeat(121),'Lusaka'),'');
});
