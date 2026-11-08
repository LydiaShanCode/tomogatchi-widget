const {test} = require('node:test');
const assert = require('node:assert/strict');
const d = require('../lib/domain');
test('four foods and two roles only',()=>{
 for(const f of ['apple','bread','steak','bokChoy']) assert.equal(d.validFood(f),true);
 for(const f of ['pizza','Apple',null,{},'']) assert.equal(d.validFood(f),false);
 assert.equal(d.validRole('parent'),true); assert.equal(d.validRole('child'),true); assert.equal(d.validRole('admin'),false);
});
test('only child can consume a pending gift',()=>{
 assert.equal(d.consumptionAllowed('child','pending'),true); assert.equal(d.consumptionAllowed('parent','pending'),false); assert.equal(d.consumptionAllowed('child','consumed'),false);
});
test('invalid preferences rejected',()=>{
 assert.equal(d.validatePreferences(d.defaultPreferences),true);
 for(const patch of [{tiredAfterHours:2},{hungryAfterHours:0},{quietStart:24},{schedules:[]},{timeZone:'Nowhere'},{remindersEnabled:'yes'}]) assert.equal(d.validatePreferences({...d.defaultPreferences,...patch}),false);
 const p=structuredClone(d.defaultPreferences);p.schedules[1].id='Breakfast';assert.equal(d.validatePreferences(p),false);
});
test('quiet hours honor time zones and cross midnight',()=>{
 const p=d.defaultPreferences;
 assert.equal(d.isQuiet(p,new Date('2026-11-08T04:00:00Z')),true);assert.equal(d.isQuiet(p,new Date('2026-11-08T18:00:00Z')),false);
 assert.equal(d.isQuiet({...p,quietStart:7,quietEnd:7},new Date()),false);
 assert.equal(d.isQuiet({...p,quietStart:12,quietEnd:15},new Date('2026-11-08T18:00:00Z')),true);
});
test('IDs cannot inject document paths',()=>{assert.equal(d.validID('550e8400-e29b-41d4-a716-446655440000'),true);assert.equal(d.validID('../other/gift'),false);assert.equal(d.validID(''),false);});
