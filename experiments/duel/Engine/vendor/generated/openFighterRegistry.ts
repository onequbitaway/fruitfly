// Original Fruitfly roster. These are not the upstream generated characters.
export const OPEN_2D_FIGHTER_IDS = ['pip', 'zip'] as const;
export const OPEN_3D_FIGHTER_IDS = [] as const;
export const OPEN_FIGHTER_PACKS = OPEN_2D_FIGHTER_IDS.map((id, i) => ({
  id,
  identity: { displayName: i ? 'Zip' : 'Pip', archetype: 'Fruit fly', playstyle: 'Fast wings, light body' },
  gameplay: {
    colors: { primary: i ? '#6850B9' : '#D74443', secondary: '#164459', accent: '#FFFFFF' },
    size: { width: 50, height: 66 }, spriteReferenceHeight: 78,
    weight: 78, dash: 1.55, dashFrames: 8, run: 1.5, air: 1.25,
    gravity: .13, fall: 2.15, fastFall: 2.8, jump: 3.0, doubleJump: 3.0,
    jumpSquat: 3, shortHop: .6, power: 1.12, speed: 1.08, reach: 1.1,
    specials: {
      'neutral-special': { label: 'Wing burst', damage: 12, radius: 75, offset: {x: 10, y: 5}, active: 8 },
      'side-special': { label: 'Dive', damage: 14, movement: {x: 700, y: 100}, airMovement: {x: 700, y: 100}, radius: 53, active: 12 },
      'up-special': { label: 'Wing lift', damage: 9, movement: {x: 180, y: 1300}, airMovement: {x: 180, y: 1300}, radius: 45, active: 16 },
      'down-special': { label: 'Stomp', damage: 15, angle: 270, radius: 56, offset: {x: 0, y: -25}, airMovement: {x: 0, y: -500} }
    }
  }
}));
