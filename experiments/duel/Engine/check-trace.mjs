// Re-run the combat engine from the recorded brain outputs. No model data is
// required: this checks that the video trace follows the shipped game rules.
import fs from 'node:fs';
import readline from 'node:readline';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const path=process.argv[2];
if(!path) throw new Error('Usage: node Engine/check-trace.mjs path/to/trace.ndjson');
const context=vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('../Sources/DuelCore/Resources/engine.js',import.meta.url),'utf8'),context);
const engine=context.DuelEngine;
engine.reset(42);
function compare(expected,actual,label) {
  if(typeof expected==='number') {
    assert.ok(Number.isFinite(actual)&&Math.abs(expected-actual)<1e-7,`${label}: ${expected} != ${actual}`);
  } else if(expected && typeof expected==='object') {
    if(Array.isArray(expected)) assert.equal(actual.length,expected.length,label);
    for(const [key,value] of Object.entries(expected)) compare(value,actual[key],label+'.'+key);
  } else assert.equal(actual,expected,label);
}
let samples=0,events=0,last;
for await(const line of readline.createInterface({input:fs.createReadStream(path),crlfDelay:Infinity})) {
  const sample=JSON.parse(line);
  samples++;
  for(const a of sample.activity) {
    assert.ok(Math.abs(a.time-samples/10)<1e-7,'brain advances in 100 ms samples');
    assert.ok(a.activeCells>0 && a.activeCells<=166700);
    assert.ok(a.points.every(p=>p.index>=0&&p.index<166700&&p.rate>=0&&Number.isFinite(p.rate)));
  }
  const actual=JSON.parse(engine.advance(sample.activity.map(a=>a.reading)));
  compare(sample.frames,actual,`sample ${samples}`);
  events+=sample.frames.flatMap(f=>f.events).filter(e=>e.type==='hit').length;
  last=sample.frames.at(-1);
}
assert.equal(last.phase,'finished');
assert.ok(events>0);
console.log(`${samples} recorded brain samples reproduce every combat frame, including ${events} hits. Winner: ${last.winner===0?'Pip':'Zip'}.`);
