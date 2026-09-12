import { CombatGame, createEmptyInput } from './vendor/engine';
import { CpuController } from './vendor/ai';
import type { InputFrame, ActionName } from './vendor/contracts';

export interface Reading { drive: number; turn: number }
let game: CombatGame;
let bots: CpuController[];
let previous: Set<ActionName>[];
const clamp = (x: number, lo: number, hi: number) => Math.max(lo, Math.min(hi, x));
export function reset(seed = 42, stocks = 3, countdownFrames = 180) {
  game = new CombatGame({
    players: [
      { fighter:'pip', skin:'00', name:'Pip', slot:0, cpu:true, cpuLevel:3 },
      { fighter:'zip', skin:'00', name:'Zip', slot:1, cpu:true, cpuLevel:3 }
    ], stocks, timeLimitSeconds:90, items:false, itemFrequency:'low', stage:'pond'
  }, {seed, countdownFrames});
  bots = [new CpuController(0, 3, seed), new CpuController(1, 3, seed + 7919)];
  previous = [new Set(), new Set()];
  return JSON.stringify(game.getSnapshot());
}
// Explicit game policy: the upstream controller chooses moves and recovers to
// the stage. Calculated cell rates set movement strength and action duty cycle.
// A fully silent brain sends no input. This is not a learned fighting skill.
export function couple(input: InputFrame, reading: Reading, frame: number, slot: number): InputFrame {
  const drive = Number.isFinite(reading.drive) ? clamp(reading.drive, 0, 1) : 0;
  const turn = Number.isFinite(reading.turn) ? clamp(reading.turn, -1, 1) : 0;
  if (drive <= 0) return createEmptyInput();
  const held = new Set(input.held);
  const activeTicks = Math.max(1, Math.ceil(drive * 12));
  if ((frame + slot * 5) % 12 >= activeTicks) {
    held.delete('attack'); held.delete('special'); held.delete('grab');
  }
  const x = clamp(input.direction.x * (.55 + drive * .45) + turn * .12, -1, 1);
  held.delete('left'); held.delete('right');
  if (x < -.2) held.add('left');
  if (x > .2) held.add('right');
  return {held, pressed:new Set([...input.pressed].filter(a => held.has(a))),released:new Set(),direction:{x,y:input.direction.y},analog:true};
}
export function advance(readings: [Reading, Reading]) {
  const frames = [];
  for (let tick = 0; tick < 6; tick++) {
    const before = game.getSnapshot();
    if (before.phase === 'finished') break;
    const inputs = bots.map((bot, i) => {
      const result = couple(bot.next(before), readings[i], before.frame, i);
      // Rebuild edges after gating. Otherwise a suppressed press can be lost.
      result.pressed = new Set([...result.pressed, ...[...result.held].filter(a => !previous[i].has(a))]);
      result.released = new Set([...previous[i]].filter(a => !result.held.has(a)));
      previous[i] = new Set(result.held);
      return result;
    }) as [InputFrame, InputFrame];
    frames.push(game.step(inputs));
  }
  return JSON.stringify(frames);
}
export function snapshot() { return JSON.stringify(game.getSnapshot()); }
