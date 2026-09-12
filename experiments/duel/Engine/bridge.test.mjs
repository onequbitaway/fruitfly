import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import crypto from 'node:crypto';
const context = vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('../Sources/DuelCore/Resources/engine.js', import.meta.url),'utf8'), context);
const engine = context.DuelEngine;
const reading = [{drive:.8,turn:.1},{drive:.75,turn:-.1}];
test('vendored engine files match the pinned MIT source', () => {
  const meta=JSON.parse(fs.readFileSync(new URL('vendor/UPSTREAM.json',import.meta.url)));
  for(const [file, hash] of Object.entries(meta.files)) assert.equal(crypto.createHash('sha256').update(fs.readFileSync(new URL('vendor/'+file,import.meta.url))).digest('hex'),hash);
});
test('twenty stock matches finish, preserve finite state, and generate hits and KOs',()=>{
  for(let seed=1;seed<=20;seed++) {
    engine.reset(seed); let s, hits=0, kos=0;
    for(let i=0;i<2400;i++) {
      const frames=JSON.parse(engine.advance(reading));
      for(s of frames) {
        hits+=s.events.filter(e=>e.type==='hit').length; kos+=s.events.filter(e=>e.type==='ko').length;
        for(const f of s.fighters) {
          assert.ok(Number.isFinite(f.position.x+f.position.y+f.percent)); assert.ok(f.stocks>=0&&f.stocks<=3);
        }
      }
      if(s.phase==='finished')break;
    }
    assert.equal(s.phase,'finished',`seed ${seed}`); assert.ok(hits>0&&kos>=3);
    assert.ok([0,1].includes(s.winner)); // A time limit can decide a winner with both stocks left.
    assert.ok(s.fighters[s.winner].stocks > 0);
    const frozen=engine.snapshot(); engine.advance(reading); assert.equal(engine.snapshot(),frozen);
  }
});
test('same seed and readings reproduce the match; changed rates change play',()=>{
  function run(r) {engine.reset(42);for(let i=0;i<120;i++)engine.advance(r);return engine.snapshot();}
  assert.equal(run(reading),run(reading));
  assert.notEqual(run(reading),run([{drive:.15,turn:-1},{drive:1,turn:1}]));
});
test('a silent brain supplies no move or attack input',()=>{
  const input={held:new Set(['attack','right','jump']),pressed:new Set(['attack']),released:new Set(),direction:{x:1,y:1}};
  const coupled=engine.couple(input,{drive:0,turn:1},17,0);
  assert.equal(coupled.held.size,0); assert.equal(coupled.direction.x,0); assert.equal(coupled.direction.y,0);
});

test('explicit repeated jumps and smash direction presses survive coupling',()=>{
  const input={held:new Set(['jump','right','attack']),pressed:new Set(['jump','right','attack']),released:new Set(),direction:{x:1,y:0}};
  const result=engine.couple(input,{drive:1,turn:0},17,0);
  for(const key of input.pressed) assert.ok(result.pressed.has(key));
  const gated=engine.couple(input,{drive:.1,turn:0},8,0);
  assert.ok(!gated.pressed.has('attack'));
  assert.ok(gated.pressed.has('jump'));
});
