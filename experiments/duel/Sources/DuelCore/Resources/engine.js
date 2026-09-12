var DuelEngine = (() => {
  var __defProp = Object.defineProperty;
  var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __hasOwnProp = Object.prototype.hasOwnProperty;
  var __defNormalProp = (obj, key, value) => key in obj ? __defProp(obj, key, { enumerable: true, configurable: true, writable: true, value }) : obj[key] = value;
  var __export = (target, all) => {
    for (var name in all)
      __defProp(target, name, { get: all[name], enumerable: true });
  };
  var __copyProps = (to, from, except, desc) => {
    if (from && typeof from === "object" || typeof from === "function") {
      for (let key of __getOwnPropNames(from))
        if (!__hasOwnProp.call(to, key) && key !== except)
          __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
    }
    return to;
  };
  var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);
  var __publicField = (obj, key, value) => __defNormalProp(obj, typeof key !== "symbol" ? key + "" : key, value);

  // Engine/bridge.ts
  var bridge_exports = {};
  __export(bridge_exports, {
    advance: () => advance,
    couple: () => couple,
    reset: () => reset,
    snapshot: () => snapshot
  });

  // Engine/vendor/generated/openFighterRegistry.ts
  var OPEN_2D_FIGHTER_IDS = ["pip", "zip"];
  var OPEN_3D_FIGHTER_IDS = [];
  var OPEN_FIGHTER_PACKS = OPEN_2D_FIGHTER_IDS.map((id, i) => ({
    id,
    identity: { displayName: i ? "Zip" : "Pip", archetype: "Fruit fly", playstyle: "Fast wings, light body" },
    gameplay: {
      colors: { primary: i ? "#6850B9" : "#D74443", secondary: "#164459", accent: "#FFFFFF" },
      size: { width: 50, height: 66 },
      spriteReferenceHeight: 78,
      weight: 78,
      dash: 1.55,
      dashFrames: 8,
      run: 1.5,
      air: 1.25,
      gravity: 0.13,
      fall: 2.15,
      fastFall: 2.8,
      jump: 3,
      doubleJump: 3,
      jumpSquat: 3,
      shortHop: 0.6,
      power: 1.12,
      speed: 1.08,
      reach: 1.1,
      specials: {
        "neutral-special": { label: "Wing burst", damage: 12, radius: 75, offset: { x: 10, y: 5 }, active: 8 },
        "side-special": { label: "Dive", damage: 14, movement: { x: 700, y: 100 }, airMovement: { x: 700, y: 100 }, radius: 53, active: 12 },
        "up-special": { label: "Wing lift", damage: 9, movement: { x: 180, y: 1300 }, airMovement: { x: 180, y: 1300 }, radius: 45, active: 16 },
        "down-special": { label: "Stomp", damage: 15, angle: 270, radius: 56, offset: { x: 0, y: -25 }, airMovement: { x: 0, y: -500 } }
      }
    }
  }));

  // Engine/vendor/generated/openStageRegistry.ts
  var OPEN_STAGE_IDS = ["pond"];
  var DEFAULT_STAGE_ID = "pond";
  var OPEN_STAGE_PACKS = [{
    id: "pond",
    identity: { displayName: "The pond", series: "Fruitfly", description: "Three leaves. Two flies." },
    gameplay: {
      platforms: [
        { id: "main", x: 0, y: -36, width: 1e3, height: 72, kind: "ground" },
        { id: "left", x: -265, y: 165, width: 225, height: 18, kind: "platform" },
        { id: "right", x: 265, y: 165, width: 225, height: 18, kind: "platform" },
        { id: "top", x: 0, y: 330, width: 200, height: 18, kind: "platform" }
      ],
      ledges: [{ platformId: "main", side: "left" }, { platformId: "main", side: "right" }],
      spawns: [{ x: -185, y: 65 }, { x: 185, y: 65 }],
      blastZone: { left: -980, right: 980, top: 900, bottom: -600 }
    },
    render: { kind: "2d", art: { width: 1280, height: 900, originPx: { x: 640, y: 530 }, worldUnitsPerPixel: 1.55 } },
    runtime: { previewUrl: "", thumbnailUrl: "", arenaUrl: "", backdropUrl: "" },
    colors: { edge: "#164459", surface: "#388768", body: "#24624B", shadow: "#164459" },
    license: { id: "MIT", attribution: "Fruitfly contributors" }
  }];

  // Engine/vendor/contracts.ts
  var OPEN_FIGHTER_IDS = [
    ...OPEN_3D_FIGHTER_IDS,
    ...OPEN_2D_FIGHTER_IDS
  ];

  // Engine/vendor/fighterBuilders.ts
  var MELEE_HORIZONTAL_WORLD_SCALE = 7.7991409242;
  var MELEE_VERTICAL_WORLD_SCALE = 6.7860696517;
  var meleeHorizontalSpeed = (unitsPerFrame) => Math.round(unitsPerFrame * MELEE_HORIZONTAL_WORLD_SCALE * 60);
  var meleeHorizontalAcceleration = (unitsPerFrameSquared) => Math.round(unitsPerFrameSquared * MELEE_HORIZONTAL_WORLD_SCALE * 60 * 60);
  var meleeVerticalSpeed = (unitsPerFrame) => Math.round(unitsPerFrame * MELEE_VERTICAL_WORLD_SCALE * 60);
  var meleeGravity = (unitsPerFrameSquared) => Math.round(unitsPerFrameSquared * MELEE_VERTICAL_WORLD_SCALE * 60 * 60);
  var move = (label, damage, angle, baseKnockback, knockbackGrowth, startup, active, recovery, radius, offset, extra = {}) => ({
    label,
    startup,
    active,
    recovery,
    damage,
    angle,
    baseKnockback,
    knockbackGrowth,
    hitstop: Math.max(3, Math.round(damage * 0.45)),
    hitstun: Math.max(7, Math.round(baseKnockback * 0.35)),
    radius,
    offset,
    shieldDamage: damage * 0.75 + 2,
    ...extra
  });
  var standardThrows = (power = 1) => ({
    forward: { damage: 7 * power, angle: 35, baseKnockback: 49, knockbackGrowth: 0.78 },
    back: { damage: 8 * power, angle: 145, baseKnockback: 52, knockbackGrowth: 0.83 },
    up: { damage: 6 * power, angle: 82, baseKnockback: 47, knockbackGrowth: 0.8 },
    down: { damage: 6 * power, angle: 68, baseKnockback: 34, knockbackGrowth: 0.65 }
  });
  var scaledFrames = (frames, speed) => Math.max(1, Math.round(frames / speed));
  var buildStandardAttacks = (profile) => {
    const power = profile.power ?? 1;
    const speed = profile.speed ?? 1;
    const reach = profile.reach ?? 1;
    const name = profile.fighterName;
    const normal = (label, damage, angle, baseKnockback, growth, startup, active, recovery, radius, offset, extra = {}) => move(
      `${name} \u2014 ${label}`,
      Math.max(1, Math.round(damage * power * 10) / 10),
      angle,
      Math.round(baseKnockback * power),
      growth * power,
      scaledFrames(startup, speed),
      active,
      scaledFrames(recovery, speed),
      radius * reach,
      { x: offset.x * reach, y: offset.y },
      extra
    );
    const special = (key) => {
      const spec = profile.specials[key];
      return move(
        spec.label,
        spec.damage,
        spec.angle ?? 48,
        Math.round((spec.damage <= 0 ? 34 : 38 + spec.damage * 0.9) * power),
        (0.58 + spec.damage / 65) * power,
        scaledFrames(spec.startup ?? 10, speed),
        spec.active ?? Math.max(1, spec.multiHit ? spec.multiHit * 2 : 4),
        scaledFrames(spec.recovery ?? 22, speed),
        (spec.radius ?? 44) * reach,
        spec.offset ?? { x: 36 * reach, y: 4 },
        {
          projectile: spec.projectile,
          movement: spec.movement,
          airMovement: spec.airMovement,
          specialMovement: spec.specialMovement,
          selfDamage: spec.selfDamage,
          chargeable: spec.chargeable,
          maxChargeFrames: spec.maxChargeFrames,
          storesCharge: spec.storesCharge,
          multiHit: spec.multiHit,
          reflectsProjectiles: spec.reflectsProjectiles,
          absorbsProjectiles: spec.absorbsProjectiles,
          counters: spec.counters,
          commandGrab: spec.commandGrab,
          statusEffect: spec.statusEffect,
          statusFrames: spec.statusFrames,
          requiresFacingTarget: spec.requiresFacingTarget,
          reversesFacing: spec.reversesFacing
        }
      );
    };
    return {
      jab: normal("neutral attack", 3, 40, 25, 0.48, 3, 2, 9, 31, { x: 33, y: 4 }),
      "dash-attack": normal("dash attack", 10, 48, 44, 0.8, 7, 6, 22, 48, { x: 44, y: 1 }, { movement: { x: 270, y: 0 } }),
      "forward-tilt": normal("forward tilt", 9, 38, 40, 0.76, 7, 4, 17, 43, { x: 42, y: 5 }),
      "up-tilt": normal("up tilt", 8, 88, 37, 0.72, 6, 5, 16, 42, { x: 3, y: 50 }),
      "down-tilt": normal("down tilt", 7, 67, 33, 0.64, 6, 4, 14, 40, { x: 39, y: -25 }),
      "forward-smash": normal("forward smash", 17, 40, 61, 1.08, 14, 5, 30, 54, { x: 50, y: 5 }, { chargeable: true, maxChargeFrames: 55 }),
      "up-smash": normal("up smash", 16, 87, 58, 1.04, 11, 6, 28, 51, { x: 3, y: 58 }, { chargeable: true, maxChargeFrames: 55 }),
      "down-smash": normal("down smash", 15, 31, 56, 1, 10, 7, 27, 52, { x: 0, y: -25 }, { chargeable: true, maxChargeFrames: 55 }),
      "neutral-air": normal("neutral aerial", 9, 48, 40, 0.75, 5, 9, 18, 43, { x: 0, y: 3 }),
      "forward-air": normal("forward aerial", 12, 42, 49, 0.9, 9, 6, 23, 48, { x: 43, y: 4 }),
      "back-air": normal("back aerial", 11, 143, 48, 0.88, 7, 5, 20, 45, { x: -41, y: 6 }),
      "up-air": normal("up aerial", 9, 83, 40, 0.78, 6, 6, 17, 43, { x: 2, y: 46 }),
      "down-air": normal("down aerial", 12, 270, 46, 0.86, 10, 7, 23, 46, { x: 0, y: -42 }),
      "neutral-special": special("neutral-special"),
      "side-special": special("side-special"),
      "up-special": special("up-special"),
      "down-special": special("down-special")
    };
  };

  // Engine/vendor/openRoster.ts
  var createOpenFighter = (seed) => ({
    id: seed.id,
    displayName: seed.displayName,
    archetype: seed.archetype,
    playstyle: seed.playstyle,
    colors: seed.colors,
    size: seed.size,
    spriteReferenceHeight: seed.spriteReferenceHeight,
    weight: seed.weight,
    initialDashSpeed: meleeHorizontalSpeed(seed.dash),
    initialDashFrames: seed.dashFrames,
    runSpeed: meleeHorizontalSpeed(seed.run),
    airSpeed: meleeHorizontalSpeed(seed.air),
    groundAcceleration: Math.min(
      3300,
      Math.round(3300 * Math.max(0.82, seed.run / 1.6))
    ),
    airAcceleration: meleeHorizontalAcceleration(Math.max(0.035, seed.air * 0.05)),
    traction: meleeHorizontalAcceleration(seed.weight >= 115 ? 0.075 : 0.065),
    wavedashTraction: meleeHorizontalAcceleration(seed.weight >= 115 ? 0.075 : 0.065),
    gravity: meleeGravity(seed.gravity),
    maxFallSpeed: meleeVerticalSpeed(seed.fall),
    fastFallSpeed: meleeVerticalSpeed(seed.fastFall),
    jumpSpeed: meleeVerticalSpeed(seed.jump),
    doubleJumpSpeed: meleeVerticalSpeed(seed.doubleJump),
    jumpSquatFrames: seed.jumpSquat,
    shortHopSpeedMultiplier: seed.shortHop,
    maxJumps: 2,
    shieldHealth: Math.round(54 + Math.min(20, seed.weight / 7)),
    shieldRegen: Math.max(5.2, 8.2 - seed.weight / 55),
    attacks: buildStandardAttacks({
      fighterName: seed.displayName,
      power: seed.power,
      speed: seed.speed,
      reach: seed.reach,
      specials: seed.specials
    }),
    throws: standardThrows(seed.power ?? 1)
  });
  var seeds = OPEN_FIGHTER_PACKS.map(({ id, identity, gameplay }) => ({
    id,
    ...identity,
    ...gameplay
  }));
  var OPEN_ROSTER = Object.fromEntries(
    seeds.map((seed) => [seed.id, createOpenFighter(seed)])
  );

  // Engine/vendor/roster.ts
  var SPRITE_VISUAL_TO_BODY_HEIGHT_RATIO = 1.17;
  var ROSTER = OPEN_ROSTER;
  function getFighterDefinition(id) {
    return ROSTER[id];
  }

  // Engine/vendor/stages.ts
  var STAGE_IDS = [...OPEN_STAGE_IDS];
  var DEFAULT_STAGE_ID2 = STAGE_IDS[0] ?? DEFAULT_STAGE_ID;
  var generatedStagePacks = OPEN_STAGE_PACKS;
  var openStageDefinitions = generatedStagePacks.map((pack) => ({
    id: pack.id,
    displayName: pack.identity.displayName,
    series: pack.identity.series,
    identity: pack.identity.description,
    previewUrl: pack.runtime.previewUrl,
    thumbnailUrl: pack.runtime.thumbnailUrl,
    renderUrl: pack.runtime.arenaUrl,
    backdropUrl: pack.runtime.backdropUrl,
    ...pack.render.kind === "3d" && pack.render.scene && pack.runtime.sceneUrl ? {
      scene: {
        url: pack.runtime.sceneUrl,
        scale: pack.render.scene.scale,
        offset: pack.render.scene.offset,
        cameraDirection: pack.render.scene.cameraDirection
      }
    } : {},
    art: pack.render.art,
    platforms: pack.gameplay.platforms,
    ledges: pack.gameplay.ledges,
    spawns: pack.gameplay.spawns,
    blastZone: pack.gameplay.blastZone,
    colors: pack.colors,
    license: pack.license
  }));
  var STAGE_DEFINITIONS = Object.fromEntries(
    openStageDefinitions.map((definition) => [definition.id, definition])
  );
  var getStageDefinition = (id) => STAGE_DEFINITIONS[id];
  var stageSurfaceYAt = (platform, worldX) => {
    const fallback = platform.y + platform.height / 2;
    const [leftY, rightY] = platform.surfaceY ?? [fallback, fallback];
    if (platform.width <= 0) return (leftY + rightY) / 2;
    const leftX = platform.x - platform.width / 2;
    const ratio = Math.max(0, Math.min(1, (worldX - leftX) / platform.width));
    return leftY + (rightY - leftY) * ratio;
  };

  // Engine/vendor/items.ts
  var item = (label, category, effect, amount, duration, charges, color, id) => {
    return {
      label,
      category,
      effect,
      amount,
      duration,
      charges,
      color,
      iconUrl: `/assets/open/items/${id}.svg`
    };
  };
  var ITEM_DEFINITIONS = {
    "vitality-fruit": item("Vitality Fruit", "auto", "heal-small", 30, 0, 1, "#ef3a35", "vitality-fruit"),
    "med-kit": item("Med Kit", "auto", "heal-large", 60, 0, 1, "#ff6e8b", "med-kit"),
    "power-orb": item("Power Orb", "auto", "power-up", 1.25, 600, 1, "#e54337", "power-orb"),
    "wind-boots": item("Wind Boots", "auto", "speed-up", 1.38, 600, 1, "#ffe38a", "wind-boots"),
    "iron-ward": item("Iron Ward", "auto", "armor", 0.68, 540, 1, "#aeb7c4", "iron-ward"),
    "nova-star": item("Nova Star", "auto", "invincibility", 1, 360, 1, "#ffe735", "nova-star"),
    "plasma-blade": item("Plasma Blade", "weapon", "sword", 11, 0, 6, "#61d7ff", "plasma-blade"),
    "power-bat": item("Power Bat", "weapon", "bat", 18, 0, 3, "#f4c683", "power-bat"),
    "pulse-blaster": item("Pulse Blaster", "weapon", "ray", 7, 0, 8, "#72f5ff", "pulse-blaster"),
    "flame-sprayer": item("Flame Sprayer", "weapon", "flame", 5, 0, 10, "#ff713e", "flame-sprayer"),
    "blast-core": item("Blast Core", "throwable", "bomb", 20, 90, 1, "#27233c", "blast-core"),
    "ricochet-disc": item("Ricochet Disc", "throwable", "shell", 12, 360, 1, "#4cc64c", "ricochet-disc"),
    "slick-gel": item("Slick Gel", "trap", "slip-trap", 5, 720, 1, "#ffe350", "slick-gel"),
    "proximity-mine": item("Proximity Mine", "trap", "proximity-bomb", 16, 720, 1, "#ed4d4d", "proximity-mine"),
    "rebound-pad": item("Rebound Pad", "trap", "bumper", 9, 720, 1, "#e95b80", "rebound-pad"),
    "snare-trap": item("Snare Trap", "trap", "bury", 7, 720, 1, "#a88a5d", "snare-trap"),
    "shock-seed": item("Shock Seed", "throwable", "stun", 4, 100, 1, "#d5b06f", "shock-seed"),
    "smoke-bomb": item("Smoke Bomb", "throwable", "smoke", 0.72, 240, 1, "#9f91bf", "smoke-bomb"),
    "reflector-charm": item("Reflector Charm", "auto", "projectile-shield", 1, 480, 1, "#f3b44c", "reflector-charm"),
    "time-dilator": item("Time Dilator", "auto", "slow-time", 0.58, 300, 1, "#80b8ff", "time-dilator")
  };
  var ITEM_KINDS = Object.freeze(Object.keys(ITEM_DEFINITIONS));
  var isAutomaticItem = (kind) => ITEM_DEFINITIONS[kind].category === "auto";

  // Engine/vendor/engine.ts
  var itemProjectileAttack = (label, damage, kind, speed, radius) => ({
    label,
    startup: 1,
    active: 1,
    recovery: 4,
    damage,
    angle: 35,
    baseKnockback: 34,
    knockbackGrowth: 0.72,
    hitstop: 3,
    hitstun: 7,
    radius,
    offset: { x: 34, y: 4 },
    shieldDamage: damage * 0.75 + 2,
    projectile: {
      kind,
      speed,
      gravity: kind === "fireball" ? 80 : 0,
      lifetimeFrames: kind === "fireball" ? 100 : 70,
      radius,
      absorbable: true
    }
  });
  var ITEM_RAY_ATTACK = itemProjectileAttack("Pulse Shot", 7, "blaster", 720, 14);
  var ITEM_FLAME_ATTACK = itemProjectileAttack("Flame Burst", 5, "fireball", 480, 18);
  var FIXED_DT = 1 / 60;
  var FIXED_DT_MS = 1e3 / 60;
  var COUNTDOWN_FRAMES = 240;
  var INPUT_BUFFER_FRAMES = 2;
  var JUMP_INPUT_BUFFER_FRAMES = 6;
  var SHIELD_INPUT_BUFFER_FRAMES = 5;
  var SMASH_CHORD_GRACE_FRAMES = 4;
  var MAX_RESPONSIVE_JUMP_SQUAT_FRAMES = 4;
  var SHORT_HOP_RELEASE_GRACE_FRAMES = 4;
  var GROUND_RUN_SPEED_MULTIPLIER = 0.92;
  var AIR_DODGE_VELOCITY_RETENTION = 0.86;
  var AIR_DODGE_SPEED_MULTIPLIER = 1.9;
  var L_CANCEL_WINDOW_FRAMES = 7;
  var FAST_FALL_BUFFER_FRAMES = 3;
  var WAVEDASH_LANDING_LAG_FRAMES = 10;
  var GROUND_TO_AIR_MOMENTUM = 0.8;
  var DIGITAL_DASH_IMPULSE_MULTIPLIER = 0.42;
  var GROUND_RELEASE_BRAKE_MULTIPLIER = 4;
  var GROUND_REVERSAL_ACCELERATION_MULTIPLIER = 2.25;
  var GROUND_ATTACK_BRAKE_MULTIPLIER = 3;
  var GROUND_HITSTUN_BRAKE_MULTIPLIER = 3.2;
  var GROUND_HITSTUN_LANDING_VELOCITY_RETENTION = 0.7;
  var GROUND_HITSTUN_EDGE_VELOCITY_RETENTION = 0.42;
  var ATTACK_MOBILITY_RECOVERY_FRAMES = 3;
  var MIN_FULL_HOP_RISE = 185;
  var MIN_DOUBLE_JUMP_RISE = 165;
  var DIRECTIONAL_LAUNCH_SUSTAIN_FRAMES = 14;
  var DIRECTIONAL_LAUNCH_EXIT_VELOCITY_RETENTION = 0.35;
  var SDI_DISTANCE = 6;
  var ASDI_DISTANCE = 3;
  var TECH_INPUT_WINDOW_FRAMES = 20;
  var TECH_INPUT_LOCKOUT_FRAMES = 40;
  var TECH_NEUTRAL_FRAMES = 26;
  var TECH_INVULNERABLE_FRAMES = 20;
  var MELEE_TUMBLE_KNOCKBACK_THRESHOLD = 80;
  var SHIELD_DROP_THRESHOLD = -0.55;
  var SAME_MOVE_LOCK_BREAK_HIT = 2;
  var DEFENSIVE_MOVE_STARTUP_GRACE_FRAMES = 4;
  var DEFENSIVE_MOVE_END_GRACE_FRAMES = 5;
  var LEDGE_MAX_HANG_FRAMES = 600;
  var LEDGE_HORIZONTAL_CATCH_BONUS = 64;
  var LEDGE_VERTICAL_CATCH_BONUS = 72;
  var PROJECTILE_RETURN_TURN_RATE = 42;
  var STANDARD_PROJECTILE_LIFETIME_MULTIPLIER = 1.25;
  var BUFFERABLE_ACTIONS = ["jump", "attack", "special", "grab", "shield"];
  var AERIAL_NORMALS = /* @__PURE__ */ new Set([
    "neutral-air",
    "forward-air",
    "back-air",
    "up-air",
    "down-air"
  ]);
  var COMBO_STARTER_NORMALS = /* @__PURE__ */ new Set(["jab", "up-tilt", "down-tilt"]);
  var SAME_MOVE_LOCK_BREAK_LAUNCH_MULTIPLIER = 1.45;
  var MELEE_CLANK_DAMAGE_WINDOW = 9;
  var defensiveMoveActiveAtFrame = (frame, move2) => {
    if (!move2.counters && !move2.absorbsProjectiles && !move2.reflectsProjectiles) return false;
    const firstFrame = Math.max(0, move2.startup - DEFENSIVE_MOVE_STARTUP_GRACE_FRAMES);
    const lastFrameExclusive = move2.startup + move2.active + DEFENSIVE_MOVE_END_GRACE_FRAMES;
    return frame >= firstFrame && frame < lastFrameExclusive;
  };
  var effectiveProjectileLifetime = (definition) => {
    const mechanicallyTimed = Boolean(
      definition.returns || definition.controlledByOwner || definition.ownerDischargeRadius || definition.manualDetonation || definition.restsOnGround || definition.kind === "ground-wave"
    );
    return mechanicallyTimed ? definition.lifetimeFrames : Math.round(definition.lifetimeFrames * STANDARD_PROJECTILE_LIFETIME_MULTIPLIER);
  };
  var comboStarterBaseKnockbackScale = (move2, percent) => COMBO_STARTER_NORMALS.has(move2) ? 0.76 + Math.min(1, Math.max(0, percent) / 80) * 0.24 : 1;
  var activeAuthoredHitboxes = (hitboxes, activeFrame) => hitboxes.flatMap((hitbox) => {
    const start = Math.max(0, hitbox.activeStart ?? 0);
    const end = Math.max(start, hitbox.activeEnd ?? Number.POSITIVE_INFINITY);
    if (activeFrame < start || activeFrame > end) return [];
    const duration = Number.isFinite(end) ? Math.max(1, end - start) : 1;
    const progress = clamp((activeFrame - start) / duration, 0, 1);
    const endOffset = hitbox.endOffset ?? hitbox.offset;
    return [{
      offset: {
        x: hitbox.offset.x + (endOffset.x - hitbox.offset.x) * progress,
        y: hitbox.offset.y + (endOffset.y - hitbox.offset.y) * progress
      },
      radius: Math.max(4, hitbox.radius),
      damageMultiplier: hitbox.damageMultiplier ?? 1,
      knockbackMultiplier: hitbox.knockbackMultiplier ?? 1,
      priority: hitbox.priority ?? 1,
      kind: hitbox.kind ?? "normal"
    }];
  });
  var competitiveHitboxesForMove = (moveName, move2, activeFrame) => {
    if (move2.hitboxes?.length) return activeAuthoredHitboxes(move2.hitboxes, activeFrame);
    const progress = move2.active <= 1 ? 1 : clamp(activeFrame / Math.max(1, move2.active - 1), 0, 1);
    const extension = 0.84 + Math.sin(progress * Math.PI) * 0.16;
    const x = move2.offset.x;
    const y = move2.offset.y;
    const radius = (scale) => Math.max(7, move2.radius * scale);
    const zone = (offsetX, offsetY, radiusScale, damageMultiplier = 1, knockbackMultiplier = 1, priority = 1, kind = "normal") => ({
      offset: { x: offsetX, y: offsetY },
      radius: radius(radiusScale),
      damageMultiplier,
      knockbackMultiplier,
      priority,
      kind
    });
    const line = (reachX, reachY, innerScale, outerScale, tipDamage = 1.03, tipKnockback = 1.04) => [
      zone(reachX * 0.42, reachY * 0.42, innerScale, 0.94, 0.94, 3, "sour"),
      zone(reachX * 0.72, reachY * 0.72, (innerScale + outerScale) / 2, 1, 1, 2),
      zone(reachX, reachY, outerScale, tipDamage, tipKnockback, 1, "sweet")
    ];
    switch (moveName) {
      case "jab":
        return line(x * 1.12, y, 0.4, 0.55, 1, 1);
      case "dash-attack":
        return [
          zone(x * 0.35, y, 0.46, 0.9, 0.9, 3, "sour"),
          zone(x * 0.75 * extension, y, 0.48, 1, 1, 2),
          zone(x * extension, y, 0.4, 1.04, 1.04, 1, "sweet")
        ];
      case "forward-tilt":
        return line(x * extension, y, 0.4, 0.38);
      case "down-tilt":
        return line(x * extension, y, 0.38, 0.34, 1.02, 1.02);
      case "forward-smash":
        return line(x * extension * 1.08, y, 0.5, 0.47, 1.08, 1.1);
      case "up-tilt":
      case "up-smash": {
        const sweepX = x + (progress - 0.5) * Math.abs(y) * 0.72;
        const reachY = y * extension;
        const smash = moveName === "up-smash";
        return line(
          sweepX,
          reachY,
          smash ? 0.5 : 0.4,
          smash ? 0.47 : 0.38,
          smash ? 1.08 : 1.03,
          smash ? 1.1 : 1.04
        );
      }
      case "down-smash": {
        const reach = Math.max(Math.abs(x), move2.radius * 1.02) * extension;
        const front = progress <= 0.68 ? line(reach, y, 0.48, 0.44, 1.06, 1.08) : [];
        const back = progress >= 0.32 ? line(-reach, y, 0.46, 0.42, 1.03, 1.05) : [];
        return [...front, ...back];
      }
      case "neutral-air": {
        const early = progress <= 0.34;
        const damage = early ? 1.04 : 0.82;
        const knockback = early ? 1.04 : 0.84;
        const kind = early ? "sweet" : "sour";
        return [
          zone(0, y * 0.35, 0.5, damage, knockback, 3, kind),
          zone(move2.radius * 0.48, y, 0.38, damage, knockback, 2, kind),
          zone(-move2.radius * 0.48, y, 0.38, damage, knockback, 2, kind)
        ];
      }
      case "forward-air":
      case "back-air": {
        const early = progress <= 0.45;
        return line(
          x * extension,
          y,
          0.44,
          0.4,
          early ? 1.06 : 0.9,
          early ? 1.08 : 0.9
        );
      }
      case "up-air": {
        const sweepX = x + (progress - 0.5) * Math.abs(y) * 0.62;
        return line(sweepX, y * extension, 0.42, 0.38, 1.04, 1.05);
      }
      case "down-air": {
        const early = progress <= 0.42;
        return line(
          x,
          y * extension,
          0.43,
          0.39,
          early ? 1.06 : 0.88,
          early ? 1.1 : 0.86
        );
      }
      default:
        return [zone(x, y, 0.86)];
    }
  };
  var meleeClankOutcome = (firstDamage, secondDamage) => {
    const difference = firstDamage - secondDamage;
    if (Math.abs(difference) <= MELEE_CLANK_DAMAGE_WINDOW) return "both";
    return difference < 0 ? "first" : "second";
  };
  var meleeClankReboundFrames = (strongerDamage) => Math.ceil(0.559 * (Math.max(0, strongerDamage) + 10));
  var effectiveJumpSquatFrames = (authoredFrames) => Math.min(MAX_RESPONSIVE_JUMP_SQUAT_FRAMES, Math.max(1, authoredFrames));
  var jumpSpeedForMinimumRise = (authoredSpeed, gravity, minimumRise) => Math.max(
    authoredSpeed,
    Math.sqrt(2 * gravity * minimumRise) + gravity * FIXED_DT * 0.5
  );
  var MELEE_LAUNCH_SPEED_MULTIPLIER = 0.03;
  var MELEE_LAUNCH_SPEED_DECAY_PER_FRAME = 0.051;
  var MELEE_HITSTUN_PER_KNOCKBACK = 0.4;
  var calculateMeleeKnockback = ({
    postHitPercent,
    damage,
    weight,
    baseKnockback,
    knockbackGrowth,
    ratio = 1
  }) => {
    const percent = Math.max(0, postHitPercent);
    const hitDamage = Math.max(0, damage);
    const targetWeight = Math.max(1, weight);
    return Math.max(
      0,
      (((percent / 10 + percent * hitDamage / 20) * 200 / (targetWeight + 100) * 1.4 + 18) * Math.max(0, knockbackGrowth) + Math.max(0, baseKnockback)) * Math.max(0, ratio)
    );
  };
  var meleeHitstunFrames = (knockback) => Math.floor(Math.max(0, knockback) * MELEE_HITSTUN_PER_KNOCKBACK);
  var meleeLaunchVelocity = (knockback, angleDegrees) => {
    const speed = Math.max(0, knockback) * MELEE_LAUNCH_SPEED_MULTIPLIER;
    const radians = angleDegrees * Math.PI / 180;
    return {
      x: Math.cos(radians) * speed,
      y: Math.sin(radians) * speed
    };
  };
  var meleeLaunchVelocityToWorld = (velocity) => ({
    x: velocity.x * MELEE_HORIZONTAL_WORLD_SCALE * 60,
    y: velocity.y * MELEE_VERTICAL_WORLD_SCALE * 60
  });
  var decayMeleeLaunchVelocity = (velocity) => {
    const speed = Math.hypot(velocity.x, velocity.y);
    if (speed <= MELEE_LAUNCH_SPEED_DECAY_PER_FRAME) return { x: 0, y: 0 };
    const retained = (speed - MELEE_LAUNCH_SPEED_DECAY_PER_FRAME) / speed;
    return { x: velocity.x * retained, y: velocity.y * retained };
  };
  function createEmptyInput() {
    return {
      held: /* @__PURE__ */ new Set(),
      pressed: /* @__PURE__ */ new Set(),
      released: /* @__PURE__ */ new Set(),
      direction: { x: 0, y: 0 }
    };
  }
  var EMPTY_INPUT = Object.freeze(createEmptyInput());
  var clamp = (value, min, max) => Math.max(min, Math.min(max, value));
  var sampleRootMotion = (samples, progress) => {
    if (samples.length === 0) return { x: 0, y: 0 };
    const cursor = clamp(progress, 0, 1) * (samples.length - 1);
    const lower = Math.floor(cursor);
    const upper = Math.min(samples.length - 1, lower + 1);
    const blend = cursor - lower;
    const lowerSample = samples[lower] ?? samples[0];
    const upperSample = samples[upper] ?? lowerSample;
    return {
      x: lowerSample[0] + (upperSample[0] - lowerSample[0]) * blend,
      y: lowerSample[1] + (upperSample[1] - lowerSample[1]) * blend
    };
  };
  var specialVisualRotation = (fighter) => {
    const action = fighter.action;
    if (!action) return 0;
    const behavior = fighter.definition.attacks[action.name].specialMovement;
    if (!behavior || behavior.kind !== "directional-launch" && behavior.kind !== "directional-bursts" || !behavior.rotateWithDirection) return 0;
    const direction = action.lastSpecialDirection;
    if (!direction) return 0;
    const magnitude = Math.hypot(direction.x, direction.y);
    if (magnitude <= 0.01) return 0;
    return Math.atan2(
      -direction.y / magnitude,
      direction.x / magnitude * fighter.facing
    );
  };
  var approach = (value, target, amount) => {
    if (value < target) return Math.min(value + amount, target);
    if (value > target) return Math.max(value - amount, target);
    return value;
  };
  var distanceSquared = (a, b) => {
    const dx = a.x - b.x;
    const dy = a.y - b.y;
    return dx * dx + dy * dy;
  };
  var fighterHurtboxProfile = (size, state) => {
    const standingHalfHeight = size.height * 0.48;
    const halfHeight = state === "crouch" ? standingHalfHeight * 0.68 : standingHalfHeight;
    return {
      radius: Math.min(Math.max(size.width, size.height) * 0.34, halfHeight),
      halfHeight,
      centerOffsetY: -standingHalfHeight + halfHeight
    };
  };
  var circleIntersectsFighter = (fighter, circle, circleRadius) => {
    const { radius, halfHeight, centerOffsetY } = fighterHurtboxProfile(
      fighter.definition.size,
      fighter.statusEffect === "bury" ? "crouch" : fighter.state
    );
    const centerY = fighter.position.y + centerOffsetY;
    const segmentHalfHeight = Math.max(0, halfHeight - radius);
    const dx = circle.x - fighter.position.x;
    const dy = Math.max(0, Math.abs(circle.y - centerY) - segmentHalfHeight);
    return dx * dx + dy * dy <= (circleRadius + radius) ** 2;
  };
  var cloneVec = (value) => ({ x: value.x, y: value.y });
  var slotOther = (slot) => slot === 0 ? 1 : 0;
  var platformTop = (platform, worldX = platform.position.x) => stageSurfaceYAt(platform, worldX);
  var platformBottom = (platform, worldX = platform.position.x) => platformTop(platform, worldX) - platform.height;
  var platformLeft = (platform) => platform.position.x - platform.width / 2;
  var platformRight = (platform) => platform.position.x + platform.width / 2;
  var platformContainsX = (platform, worldX) => worldX >= platformLeft(platform) && worldX <= platformRight(platform);
  var crossingTime = (before, after) => {
    const span = before - after;
    if (Math.abs(span) < 1e-6) return null;
    const time = before / span;
    return time >= 0 && time <= 1 ? time : null;
  };
  var findGroundVolumeCollision = (platforms, previous2, current, halfWidth, halfHeight, ignoredPlatformIds = /* @__PURE__ */ new Set()) => {
    const deltaX = current.x - previous2.x;
    const candidates = [];
    for (const platform of platforms) {
      if (platform.kind !== "ground" || ignoredPlatformIds.has(platform.id)) continue;
      const previousUnder = platformBottom(platform, previous2.x) - (previous2.y + halfHeight);
      const currentUnder = platformBottom(platform, current.x) - (current.y + halfHeight);
      if (previousUnder >= -3 && currentUnder <= 0) {
        const time = crossingTime(previousUnder, currentUnder);
        if (time !== null) {
          const xAtImpact = previous2.x + deltaX * time;
          if (xAtImpact + halfWidth >= platformLeft(platform) && xAtImpact - halfWidth <= platformRight(platform)) {
            candidates.push({ platform, face: "bottom", time });
          }
        }
      }
      const checkSide = (face) => {
        const edgeX = face === "left" ? platformLeft(platform) : platformRight(platform);
        const previousEdge = face === "left" ? edgeX - (previous2.x + halfWidth) : previous2.x - halfWidth - edgeX;
        const currentEdge = face === "left" ? edgeX - (current.x + halfWidth) : current.x - halfWidth - edgeX;
        if (previousEdge < -3 || currentEdge > 0) return;
        const time = crossingTime(previousEdge, currentEdge);
        if (time === null) return;
        const yAtImpact = previous2.y + (current.y - previous2.y) * time;
        const edgeTop = platformTop(platform, edgeX);
        const edgeBottom = platformBottom(platform, edgeX);
        if (yAtImpact + halfHeight <= edgeBottom || yAtImpact - halfHeight >= edgeTop) return;
        candidates.push({ platform, face, time });
      };
      if (deltaX > 0) checkSide("left");
      if (deltaX < 0) checkSide("right");
    }
    return candidates.sort((a, b) => a.time - b.time)[0] ?? null;
  };
  var normalizedDirection = (input) => {
    const x = clamp(Number.isFinite(input.direction.x) ? input.direction.x : 0, -1, 1);
    const y = clamp(Number.isFinite(input.direction.y) ? input.direction.y : 0, -1, 1);
    const length = Math.hypot(x, y);
    if (length <= 1 || length === 0) return { x, y };
    return { x: x / length, y: y / length };
  };
  var sdiRegionForDirection = (direction) => {
    if (Math.hypot(direction.x, direction.y) < 0.5) return null;
    const octant = Math.round(Math.atan2(direction.y, direction.x) / (Math.PI / 4));
    return (octant + 8) % 8;
  };
  var landingLagFramesForAttack = (attack) => clamp(Math.round(attack.recovery * 0.42), 6, 16);
  var withoutEdges = (input) => ({
    held: input.held,
    pressed: /* @__PURE__ */ new Set(),
    released: /* @__PURE__ */ new Set(),
    direction: input.direction,
    analog: input.analog
  });
  var SeededRandom = class {
    constructor(seed) {
      __publicField(this, "state");
      this.state = seed >>> 0 || 2654435769;
    }
    next() {
      let value = this.state;
      value ^= value << 13;
      value ^= value >>> 17;
      value ^= value << 5;
      this.state = value >>> 0;
      return this.state / 4294967296;
    }
  };
  var CombatGame = class {
    constructor(config, options = {}) {
      __publicField(this, "config");
      __publicField(this, "options");
      __publicField(this, "random");
      __publicField(this, "stage");
      __publicField(this, "fighters");
      __publicField(this, "projectiles", []);
      __publicField(this, "items", []);
      __publicField(this, "events", []);
      __publicField(this, "frame", 0);
      __publicField(this, "countdownFrames", 0);
      __publicField(this, "phase", "countdown");
      __publicField(this, "winner", null);
      __publicField(this, "result", null);
      __publicField(this, "suddenDeath", false);
      __publicField(this, "timeLimitFrames");
      __publicField(this, "kos", [0, 0]);
      __publicField(this, "nextEntityId", 1);
      __publicField(this, "nextItemFrame", Number.POSITIVE_INFINITY);
      __publicField(this, "accumulator", 0);
      this.config = config;
      const normalizedOptions = typeof options === "number" ? { seed: options } : options;
      this.options = {
        seed: normalizedOptions.seed ?? 12648430,
        countdownFrames: Math.max(0, Math.round(normalizedOptions.countdownFrames ?? COUNTDOWN_FRAMES)),
        spawnPositions: normalizedOptions.spawnPositions
      };
      const timeLimitSeconds = config.timeLimitSeconds;
      this.timeLimitFrames = typeof timeLimitSeconds === "number" && Number.isFinite(timeLimitSeconds) && timeLimitSeconds > 0 ? Math.max(1, Math.round(timeLimitSeconds * 60)) : null;
      this.random = new SeededRandom(this.options.seed);
      this.stage = this.createStage();
      this.initializeMatch();
    }
    step(inputs) {
      this.events = [];
      if (this.phase === "finished") return this.getSnapshot();
      this.frame += 1;
      if (this.phase === "countdown") {
        if (this.countdownFrames <= 180 && this.countdownFrames % 60 === 0) {
          this.emit({
            type: "countdown",
            value: Math.ceil(this.countdownFrames / 60),
            sound: "countdown"
          });
        }
        this.countdownFrames = Math.max(0, this.countdownFrames - 1);
        if (this.countdownFrames === 0) {
          this.phase = "playing";
          for (const fighter of this.fighters) {
            if (fighter.state === "entrance") fighter.state = "idle";
          }
          this.emit({ type: "match-start", sound: "announcer-go" });
        }
        return this.getSnapshot();
      }
      this.updateFighter(this.fighters[0], inputs[0], inputs);
      this.updateFighter(this.fighters[1], inputs[1], inputs);
      this.resolveFighterOverlap();
      this.resolveMeleeHits(inputs);
      this.updateProjectiles(inputs);
      this.updateItems(inputs);
      this.maybeSpawnItem();
      this.resolveKnockouts();
      if (this.phase === "playing") this.resolveTimeLimit();
      return this.getSnapshot();
    }
    /**
     * Convenience adapter for render loops. Simulation always advances in fixed
     * 1/60 s ticks; edge-triggered inputs are consumed only by the first tick.
     */
    advance(elapsedSeconds, inputs) {
      this.accumulator = Math.min(this.accumulator + Math.max(0, elapsedSeconds), FIXED_DT * 8);
      let firstTick = true;
      let snapshot2 = this.getSnapshot();
      const accumulatedEvents = [];
      while (this.accumulator >= FIXED_DT && this.phase !== "finished") {
        snapshot2 = this.step(
          firstTick ? inputs : [withoutEdges(inputs[0]), withoutEdges(inputs[1])]
        );
        accumulatedEvents.push(...snapshot2.events);
        firstTick = false;
        this.accumulator -= FIXED_DT;
      }
      if (!firstTick) {
        this.events = accumulatedEvents;
        snapshot2 = this.getSnapshot();
      }
      return snapshot2;
    }
    getSnapshot() {
      const playingFrames = this.playingFrames();
      return {
        frame: this.frame,
        elapsedMs: this.frame * FIXED_DT_MS,
        remainingTimeMs: this.timeLimitFrames === null || this.suddenDeath ? null : Math.max(0, this.timeLimitFrames - playingFrames) * FIXED_DT_MS,
        suddenDeath: this.suddenDeath,
        phase: this.phase,
        countdownFrames: this.countdownFrames,
        fighters: [this.snapshotFighter(this.fighters[0]), this.snapshotFighter(this.fighters[1])],
        projectiles: this.projectiles.map((projectile) => ({
          id: projectile.id,
          owner: projectile.owner,
          kind: projectile.kind,
          position: cloneVec(projectile.position),
          velocity: cloneVec(projectile.velocity),
          radius: projectile.radius,
          remainingFrames: projectile.remainingFrames,
          rotation: projectile.rotation
        })),
        items: this.items.map((item2) => ({
          id: item2.id,
          kind: item2.kind,
          position: cloneVec(item2.position),
          velocity: cloneVec(item2.velocity),
          radius: item2.radius,
          mode: item2.mode,
          owner: item2.owner
        })),
        stage: {
          ...this.stage,
          platforms: this.stage.platforms.map((platform) => ({
            ...platform,
            position: cloneVec(platform.position)
          })),
          ledges: this.stage.ledges.map((ledge) => ({
            ...ledge,
            position: cloneVec(ledge.position)
          })),
          blastZone: { ...this.stage.blastZone }
        },
        winner: this.winner,
        result: this.result ? {
          winner: this.result.winner,
          durationMs: this.result.durationMs,
          kos: [...this.result.kos]
        } : null,
        events: this.events.map((event) => ({
          ...event,
          position: event.position ? cloneVec(event.position) : void 0
        }))
      };
    }
    fighterLaunchWorldVelocity(fighter) {
      return meleeLaunchVelocityToWorld(fighter.launchVelocity);
    }
    fighterWorldVelocity(fighter) {
      const launch = this.fighterLaunchWorldVelocity(fighter);
      return {
        x: fighter.velocity.x + launch.x,
        y: fighter.velocity.y + launch.y
      };
    }
    clearLaunchVelocity(fighter) {
      fighter.launchVelocity = { x: 0, y: 0 };
    }
    reset() {
      this.initializeMatch();
      return this.getSnapshot();
    }
    spawnItem(kind, position, velocity = { x: 0, y: 0 }) {
      const item2 = {
        id: this.nextEntityId,
        kind,
        position: cloneVec(position),
        velocity: cloneVec(velocity),
        radius: 24,
        mode: "world",
        owner: null,
        age: 0,
        grounded: false,
        supportPlatform: null
      };
      this.nextEntityId += 1;
      this.items.push(item2);
      this.emit({ type: "item-spawn", item: kind, position: cloneVec(position), sound: "item-spawn" });
      return item2.id;
    }
    initializeMatch() {
      this.frame = 0;
      this.countdownFrames = this.options.countdownFrames;
      this.phase = this.countdownFrames > 0 ? "countdown" : "playing";
      this.winner = null;
      this.result = null;
      this.suddenDeath = false;
      this.kos = [0, 0];
      this.nextEntityId = 1;
      this.projectiles = [];
      this.items = [];
      this.events = [];
      this.accumulator = 0;
      this.stage = this.createStage();
      const stageDefinition = getStageDefinition(this.config.stage);
      const usesAuthoredStageSpawns = this.options.spawnPositions === void 0;
      const spawns = this.options.spawnPositions ?? stageDefinition.spawns;
      this.fighters = [
        this.createFighter(0, spawns[0], usesAuthoredStageSpawns),
        this.createFighter(1, spawns[1], usesAuthoredStageSpawns)
      ];
      this.nextItemFrame = this.config.items ? this.itemIntervalFrames() : Number.POSITIVE_INFINITY;
    }
    createStage() {
      const definition = getStageDefinition(this.config.stage);
      const platforms = definition.platforms.map((platform) => ({
        ...platform,
        position: { x: platform.x, y: platform.y }
      }));
      const main = platforms.find((platform) => platform.id === "main");
      if (!main) throw new Error(`Stage ${definition.id} has no main platform.`);
      const ledges = definition.ledges.map((ledge) => {
        const platform = platforms.find(({ id }) => id === ledge.platformId);
        if (!platform || platform.kind !== "ground") {
          throw new Error(
            `The ${ledge.side} ledge of ${definition.id} must reference a valid ground volume.`
          );
        }
        const x = ledge.side === "left" ? platformLeft(platform) : platformRight(platform);
        return {
          ...ledge,
          position: { x, y: platformTop(platform, x) }
        };
      });
      return {
        id: definition.id,
        platforms,
        ledges,
        blastZone: { ...definition.blastZone }
      };
    }
    mainPlatform() {
      const main = this.stage.platforms.find((platform) => platform.id === "main");
      if (!main) throw new Error(`Stage ${this.stage.id} has no main platform.`);
      return main;
    }
    createFighter(slot, spawn, placeOnAuthoredSurface = false) {
      const setup = this.config.players[slot];
      const definition = getFighterDefinition(setup.fighter);
      const spawnSupport = placeOnAuthoredSurface ? this.stage.platforms.filter(
        (platform) => platformContainsX(platform, spawn.x) && platformTop(platform, spawn.x) <= spawn.y + 4
      ).sort(
        (left, right) => platformTop(right, spawn.x) - platformTop(left, spawn.x)
      )[0] : void 0;
      const position = spawnSupport ? {
        x: spawn.x,
        y: platformTop(spawnSupport, spawn.x) + definition.size.height / 2
      } : cloneVec(spawn);
      return {
        slot,
        fighter: setup.fighter,
        skin: setup.skin,
        name: setup.name,
        cpu: setup.cpu,
        definition,
        position,
        previousPosition: cloneVec(position),
        velocity: { x: 0, y: 0 },
        launchVelocity: { x: 0, y: 0 },
        facing: slot === 0 ? 1 : -1,
        percent: 0,
        stocks: Math.max(1, Math.round(this.config.stocks)),
        state: this.phase === "countdown" ? "entrance" : spawnSupport ? "idle" : "fall",
        grounded: Boolean(spawnSupport),
        supportPlatform: spawnSupport?.id ?? null,
        jumpsRemaining: definition.maxJumps,
        fastFalling: false,
        fastFallInputFrames: 0,
        floatFramesRemaining: definition.floatDurationFrames ?? 0,
        floating: false,
        airUpSpecialUsed: false,
        airDodgeUsed: false,
        airDodgeHelpless: false,
        analogRunning: false,
        coyoteFrames: 0,
        bufferedAction: null,
        bufferedDirection: { x: 0, y: 0 },
        bufferedDirectionAction: null,
        bufferedActionFrames: 0,
        smashDirection: { x: 0, y: 0 },
        smashDirectionAction: null,
        smashDirectionFrames: 0,
        dropThroughFrames: 0,
        shield: definition.shieldHealth,
        shieldLockFrames: 0,
        shieldStunFrames: 0,
        invulnerableFrames: 0,
        hitstopFrames: 0,
        hitstopElapsedFrames: 0,
        hitstunFrames: 0,
        launchBaseAngle: null,
        pendingHitstopDi: null,
        sdiRegion: null,
        asdiDirection: null,
        techWindowFrames: 0,
        techLockoutFrames: 0,
        techable: false,
        statusEffect: null,
        statusResistanceFrames: 0,
        lastHitMove: null,
        consecutiveHitMoveCount: 0,
        dodgeFrames: 0,
        dodgeKind: null,
        jumpSquatFrames: 0,
        fullHopRequested: true,
        shortHopReleaseFrames: 0,
        landingLagFrames: 0,
        wavedashFrames: 0,
        lCancelFrames: 0,
        dashFrames: 0,
        turnFrames: 0,
        tauntFrames: 0,
        attackLockFrames: 0,
        action: null,
        grabTarget: null,
        grabbedBy: null,
        grabFrames: 0,
        throwAnimation: null,
        respawnFrames: 0,
        ledge: null,
        ledgeCooldownFrames: 0,
        ledgeHangFrames: 0,
        ledgeDirectionReleased: false,
        lastHitBy: null,
        lastHitFrames: 0,
        damageMultiplier: 1,
        damageBuffFrames: 0,
        speedMultiplier: 1,
        speedBuffFrames: 0,
        jumpMultiplier: 1,
        jumpBuffFrames: 0,
        defenseMultiplier: 1,
        defenseBuffFrames: 0,
        projectileShieldFrames: 0,
        heldItem: null,
        itemUseFrames: 0,
        itemAction: null,
        storedCharges: {}
      };
    }
    fighterCannotStartAction(fighter) {
      return fighter.state === "ko" || fighter.state === "respawn" || fighter.state === "grabbed" || fighter.state === "ledge" || fighter.hitstopFrames > 0 || fighter.hitstunFrames > 0 || fighter.shieldStunFrames > 0 || fighter.jumpSquatFrames > 0 || fighter.landingLagFrames > 0 || fighter.tauntFrames > 0 || fighter.dodgeFrames > 0 || fighter.airDodgeHelpless || fighter.itemUseFrames > 0 || fighter.grabTarget !== null || fighter.grabFrames > 0 || fighter.action !== null;
    }
    captureBufferedAction(fighter, input) {
      const action = BUFFERABLE_ACTIONS.find((candidate) => input.pressed.has(candidate));
      if (!action) return false;
      fighter.bufferedAction = action;
      fighter.bufferedDirection = normalizedDirection(input);
      fighter.bufferedDirectionAction = ["left", "right", "up", "down"].find((candidate) => input.pressed.has(candidate)) ?? null;
      fighter.bufferedActionFrames = action === "jump" ? JUMP_INPUT_BUFFER_FRAMES : action === "shield" ? SHIELD_INPUT_BUFFER_FRAMES : INPUT_BUFFER_FRAMES;
      return true;
    }
    captureSmashDirection(fighter, input) {
      const action = ["left", "right", "up", "down"].find(
        (candidate) => input.pressed.has(candidate)
      );
      if (!action) return;
      const direction = normalizedDirection(input);
      fighter.smashDirectionAction = action;
      fighter.smashDirection = Math.hypot(direction.x, direction.y) > 0.25 ? direction : action === "left" ? { x: -1, y: 0 } : action === "right" ? { x: 1, y: 0 } : action === "up" ? { x: 0, y: 1 } : { x: 0, y: -1 };
      fighter.smashDirectionFrames = SMASH_CHORD_GRACE_FRAMES + 1;
    }
    clearSmashDirection(fighter) {
      fighter.smashDirection = { x: 0, y: 0 };
      fighter.smashDirectionAction = null;
      fighter.smashDirectionFrames = 0;
    }
    withBufferedAction(fighter, input) {
      const hasFreshAction = BUFFERABLE_ACTIONS.some((candidate) => input.pressed.has(candidate));
      if (hasFreshAction) {
        this.clearBufferedAction(fighter);
        return input;
      }
      if (!fighter.bufferedAction || fighter.bufferedActionFrames <= 0) return input;
      const pressed = new Set(input.pressed);
      const held = new Set(input.held);
      pressed.add(fighter.bufferedAction);
      held.add(fighter.bufferedAction);
      if (fighter.bufferedDirectionAction) {
        pressed.add(fighter.bufferedDirectionAction);
        held.add(fighter.bufferedDirectionAction);
      }
      return {
        ...input,
        pressed,
        held,
        direction: { ...fighter.bufferedDirection }
      };
    }
    ageBufferedAction(fighter) {
      if (fighter.bufferedActionFrames <= 0) return;
      fighter.bufferedActionFrames -= 1;
      if (fighter.bufferedActionFrames === 0) this.clearBufferedAction(fighter);
    }
    consumeBufferedAction(fighter, action) {
      if (fighter.bufferedAction === action) this.clearBufferedAction(fighter);
    }
    clearBufferedAction(fighter) {
      fighter.bufferedAction = null;
      fighter.bufferedDirection = { x: 0, y: 0 };
      fighter.bufferedDirectionAction = null;
      fighter.bufferedActionFrames = 0;
    }
    captureMeleeTechniqueInputs(fighter, input) {
      if (input.pressed.has("shield") && fighter.techable && (fighter.hitstopFrames > 0 || fighter.hitstunFrames > 0) && fighter.techLockoutFrames === 0) {
        fighter.techWindowFrames = TECH_INPUT_WINDOW_FRAMES;
        fighter.techLockoutFrames = TECH_INPUT_LOCKOUT_FRAMES;
      }
      if (fighter.hitstopFrames > 0 || fighter.hitstunFrames > 0) return;
      if (fighter.grounded) return;
      if (input.pressed.has("down")) {
        fighter.fastFallInputFrames = FAST_FALL_BUFFER_FRAMES;
      }
      if (input.pressed.has("shield") && fighter.action && AERIAL_NORMALS.has(fighter.action.name)) {
        fighter.lCancelFrames = L_CANCEL_WINDOW_FRAMES;
      }
      if (!fighter.fastFalling && fighter.fastFallInputFrames > 0 && fighter.velocity.y <= 0) {
        fighter.fastFalling = true;
        fighter.fastFallInputFrames = 0;
        fighter.velocity.y = -fighter.definition.fastFallSpeed;
      }
    }
    updateFighter(fighter, input, inputs) {
      const controlsLocked = this.fighterCannotStartAction(fighter);
      const captured = controlsLocked && this.captureBufferedAction(fighter, input);
      if (!controlsLocked) input = this.withBufferedAction(fighter, input);
      if (!captured) this.ageBufferedAction(fighter);
      this.tickFighterTimers(fighter);
      this.captureSmashDirection(fighter, input);
      this.captureMeleeTechniqueInputs(fighter, input);
      if (fighter.state === "ko") {
        fighter.respawnFrames = Math.max(0, fighter.respawnFrames - 1);
        if (fighter.respawnFrames === 0 && fighter.stocks > 0) this.respawnFighter(fighter);
        return;
      }
      if (fighter.state === "respawn" && fighter.respawnFrames > 0) {
        fighter.respawnFrames -= 1;
        fighter.velocity = { x: 0, y: 0 };
        this.clearLaunchVelocity(fighter);
        if (fighter.respawnFrames === 0) fighter.state = "fall";
        return;
      }
      if (fighter.hitstopFrames > 0) {
        const hitstopDirection = normalizedDirection(input);
        if (fighter.launchBaseAngle !== null && Math.hypot(hitstopDirection.x, hitstopDirection.y) > 0.25) {
          fighter.pendingHitstopDi = hitstopDirection;
        }
        if (fighter.launchBaseAngle !== null) {
          const region = sdiRegionForDirection(hitstopDirection);
          fighter.asdiDirection = region === null ? null : cloneVec(hitstopDirection);
          if (region === null) {
            fighter.sdiRegion = null;
          } else if (region !== fighter.sdiRegion) {
            if (fighter.hitstopElapsedFrames >= 1) {
              this.applyHitstopDisplacement(fighter, hitstopDirection, SDI_DISTANCE);
            }
            fighter.sdiRegion = region;
          }
          fighter.hitstopElapsedFrames += 1;
        }
        fighter.hitstopFrames -= 1;
        if (fighter.hitstopFrames === 0) this.finishHitstopDi(fighter);
        return;
      }
      if (fighter.state === "grabbed") {
        this.followGrabber(fighter);
        return;
      }
      if (fighter.state === "ledge") {
        this.updateLedge(fighter, input);
        return;
      }
      if (fighter.hitstunFrames > 0) {
        fighter.launchBaseAngle = null;
        fighter.pendingHitstopDi = null;
        const mashEscape = fighter.statusEffect ? Math.min(
          9,
          ["jump", "attack", "special", "grab", "shield"].filter((action) => input.pressed.has(action)).length * 3 + ["left", "right", "up", "down"].filter((action) => input.pressed.has(action)).length * 2
        ) : 0;
        fighter.hitstunFrames = Math.max(0, fighter.hitstunFrames - 1 - mashEscape);
        fighter.state = "hitstun";
        const direction2 = normalizedDirection(input);
        if (fighter.statusEffect === "bury") {
          fighter.velocity.x = 0;
        } else if (fighter.grounded) {
          fighter.velocity.x = approach(
            fighter.velocity.x,
            0,
            fighter.definition.traction * GROUND_HITSTUN_BRAKE_MULTIPLIER * FIXED_DT
          );
        } else {
          fighter.velocity.x += direction2.x * fighter.definition.airAcceleration * FIXED_DT * 0.32;
        }
        this.integrateFighter(fighter, input);
        if (fighter.hitstunFrames === 0) {
          if (fighter.statusEffect) {
            fighter.statusResistanceFrames = Math.max(
              fighter.statusResistanceFrames,
              fighter.statusEffect === "bury" ? 90 : 45
            );
            fighter.statusEffect = null;
          }
          fighter.techable = false;
          if (fighter.dodgeFrames === 0) fighter.state = fighter.grounded ? "idle" : "fall";
        }
        return;
      }
      if (fighter.shieldStunFrames > 0) {
        fighter.shieldStunFrames -= 1;
        this.integrateFighter(fighter, input);
        return;
      }
      if (fighter.jumpSquatFrames > 0) {
        fighter.jumpSquatFrames -= 1;
        fighter.state = "jump-squat";
        if (!input.held.has("jump")) fighter.fullHopRequested = false;
        const jumpDirection = normalizedDirection(input);
        const preservingMomentum = Math.abs(jumpDirection.x) > 0.08 && Math.sign(jumpDirection.x) === Math.sign(fighter.velocity.x);
        if (!preservingMomentum) {
          fighter.velocity.x = approach(
            fighter.velocity.x,
            0,
            fighter.definition.traction * 0.25 * FIXED_DT
          );
        }
        if (fighter.jumpSquatFrames === 0) {
          fighter.grounded = false;
          fighter.supportPlatform = null;
          fighter.coyoteFrames = 0;
          fighter.jumpsRemaining = Math.max(0, fighter.definition.maxJumps - 1);
          fighter.velocity.x *= GROUND_TO_AIR_MOMENTUM;
          fighter.velocity.y = (fighter.fullHopRequested ? jumpSpeedForMinimumRise(
            fighter.definition.jumpSpeed,
            fighter.definition.gravity,
            MIN_FULL_HOP_RISE
          ) : fighter.definition.jumpSpeed * fighter.definition.shortHopSpeedMultiplier) * fighter.jumpMultiplier;
          fighter.shortHopReleaseFrames = fighter.fullHopRequested ? SHORT_HOP_RELEASE_GRACE_FRAMES : 0;
          fighter.fastFalling = false;
          fighter.fastFallInputFrames = 0;
          fighter.state = "jump";
          this.emit({ type: "jump", slot: fighter.slot, position: cloneVec(fighter.position), sound: "jump" });
        }
        return;
      }
      if (fighter.shortHopReleaseFrames > 0) {
        if (!fighter.grounded && fighter.velocity.y > 0 && !input.held.has("jump")) {
          const shortHopSpeed = fighter.definition.jumpSpeed * fighter.jumpMultiplier * fighter.definition.shortHopSpeedMultiplier;
          fighter.velocity.y = Math.min(fighter.velocity.y, shortHopSpeed);
          fighter.fullHopRequested = false;
          fighter.shortHopReleaseFrames = 0;
        } else {
          fighter.shortHopReleaseFrames -= 1;
        }
      }
      if (fighter.landingLagFrames > 0) {
        fighter.landingLagFrames -= 1;
        if (fighter.wavedashFrames > 0) fighter.wavedashFrames -= 1;
        fighter.state = "crouch";
        fighter.velocity.x = approach(
          fighter.velocity.x,
          0,
          (fighter.wavedashFrames > 0 ? fighter.definition.wavedashTraction : fighter.definition.traction * 0.72) * FIXED_DT
        );
        this.integrateFighter(fighter, input);
        if (fighter.landingLagFrames === 0) {
          fighter.state = fighter.grounded ? "idle" : "fall";
        }
        return;
      }
      if (fighter.tauntFrames > 0) {
        fighter.tauntFrames -= 1;
        fighter.state = "taunt";
        fighter.velocity.x = approach(fighter.velocity.x, 0, fighter.definition.traction * FIXED_DT);
        if (fighter.tauntFrames === 0) fighter.state = fighter.grounded ? "idle" : "fall";
        return;
      }
      if (fighter.dodgeFrames > 0) {
        fighter.dodgeFrames -= 1;
        fighter.state = "dodge";
        if (fighter.grounded) {
          fighter.velocity.x = approach(fighter.velocity.x, 0, 1250 * FIXED_DT);
        } else if (fighter.dodgeKind === "air") {
          fighter.velocity.x *= AIR_DODGE_VELOCITY_RETENTION;
          fighter.velocity.y *= AIR_DODGE_VELOCITY_RETENTION;
        }
        this.integrateFighter(fighter, input);
        if (fighter.dodgeFrames === 0) {
          fighter.dodgeKind = null;
          if (fighter.landingLagFrames === 0) fighter.state = fighter.grounded ? "idle" : "fall";
        }
        return;
      }
      if (fighter.airDodgeHelpless && !fighter.grounded) {
        fighter.state = "fall";
        this.integrateFighter(fighter, input);
        return;
      }
      if (fighter.itemUseFrames > 0) {
        fighter.itemUseFrames -= 1;
        fighter.state = "attack";
        fighter.velocity.x = approach(fighter.velocity.x, 0, fighter.definition.traction * FIXED_DT);
        this.integrateFighter(fighter, input);
        if (fighter.itemUseFrames === 0) {
          fighter.itemAction = null;
          fighter.state = fighter.grounded ? "idle" : "fall";
        }
        return;
      }
      if (fighter.grabTarget !== null) {
        this.updateHeldGrab(fighter, input, inputs[fighter.grabTarget]);
        return;
      }
      if (fighter.grabFrames > 0) {
        fighter.grabFrames -= 1;
        fighter.state = "grab";
        fighter.velocity.x = approach(fighter.velocity.x, 0, fighter.definition.traction * FIXED_DT);
        this.integrateFighter(fighter, input);
        if (fighter.grabFrames === 0) {
          fighter.throwAnimation = null;
          fighter.state = fighter.grounded ? "idle" : "fall";
        }
        return;
      }
      if (fighter.action) {
        const activeAction = fighter.action;
        const move2 = fighter.definition.attacks[fighter.action.name];
        this.updateActiveMove(fighter, input);
        const recoveryInput = !input.pressed.has("jump") && fighter.bufferedAction === "jump" && fighter.bufferedActionFrames > 0 ? {
          ...input,
          held: /* @__PURE__ */ new Set([...input.held, "jump"]),
          pressed: /* @__PURE__ */ new Set([...input.pressed, "jump"]),
          direction: { ...fighter.bufferedDirection }
        } : input;
        const recoveryDirection = normalizedDirection(recoveryInput);
        const mobilityUnlockFrame = move2.startup + move2.active + Math.min(move2.recovery, ATTACK_MOBILITY_RECOVERY_FRAMES);
        const mobilityRequested = recoveryInput.pressed.has("jump") || Math.abs(recoveryDirection.x) > 0.08;
        if (fighter.action === activeAction && !activeAction.charging && !move2.specialMovement && !move2.projectile?.ownerLaunchOnContact && activeAction.frame >= mobilityUnlockFrame && mobilityRequested) {
          const totalFrames = move2.startup + move2.active + move2.recovery;
          fighter.attackLockFrames = Math.max(
            fighter.attackLockFrames,
            totalFrames - activeAction.frame
          );
          fighter.action = null;
          fighter.state = fighter.grounded ? "idle" : "fall";
          this.updateMovement(fighter, recoveryInput, recoveryDirection);
          this.integrateFighter(fighter, recoveryInput);
          return;
        }
        const inRecovery = activeAction.frame >= move2.startup + move2.active;
        if (fighter.grounded && !move2.specialMovement && (!move2.movement || inRecovery)) {
          fighter.velocity.x = approach(
            fighter.velocity.x,
            0,
            fighter.definition.traction * GROUND_ATTACK_BRAKE_MULTIPLIER * FIXED_DT
          );
        }
        this.applyAirDrift(fighter, input, 0.68);
        this.integrateFighter(fighter, input);
        return;
      }
      if (fighter.airUpSpecialUsed && !fighter.grounded) {
        fighter.state = "fall";
        this.applyAirDrift(fighter, input, 1);
        this.integrateFighter(fighter, input);
        return;
      }
      const direction = normalizedDirection(input);
      const directionPressed = input.pressed.has("left") || input.pressed.has("right") || input.pressed.has("up") || input.pressed.has("down");
      const shieldSupport = fighter.supportPlatform ? this.stage.platforms.find((platform) => platform.id === fighter.supportPlatform) : void 0;
      if (fighter.state === "shield" && fighter.grounded && shieldSupport?.kind === "platform" && input.pressed.has("down") && direction.y <= SHIELD_DROP_THRESHOLD) {
        fighter.grounded = false;
        fighter.supportPlatform = null;
        fighter.dropThroughFrames = 12;
        fighter.position.y -= 5;
        fighter.velocity.y = Math.min(fighter.velocity.y, -70);
        fighter.state = "fall";
        this.integrateFighter(fighter, input);
        return;
      }
      const canDodge = fighter.grounded || !fighter.airDodgeUsed;
      if (canDodge && (input.pressed.has("shield") && (!fighter.grounded || Math.hypot(direction.x, direction.y) > 0.25) || fighter.state === "shield" && directionPressed)) {
        this.consumeBufferedAction(fighter, "shield");
        this.startDodge(fighter, direction);
        this.integrateFighter(fighter, input);
        return;
      }
      if (input.pressed.has("grab") && input.held.has("shield") && fighter.grounded) {
        this.consumeBufferedAction(fighter, "grab");
        fighter.tauntFrames = 60;
        fighter.state = "taunt";
        fighter.velocity.x = 0;
        this.emit({ type: "taunt", slot: fighter.slot, position: cloneVec(fighter.position), sound: "taunt" });
        return;
      }
      if (input.pressed.has("grab")) {
        this.consumeBufferedAction(fighter, "grab");
        if (this.tryPickupItem(fighter)) {
          this.integrateFighter(fighter, input);
          return;
        }
        this.startGrab(fighter);
        this.integrateFighter(fighter, input);
        return;
      }
      if ((input.held.has("shield") || input.pressed.has("shield")) && fighter.grounded && fighter.shieldLockFrames === 0) {
        fighter.state = "shield";
        fighter.velocity.x = approach(fighter.velocity.x, 0, fighter.definition.traction * 1.4 * FIXED_DT);
        fighter.shield = Math.max(0, fighter.shield - 0.16);
        if (fighter.shield <= 0) this.breakShield(fighter);
        this.integrateFighter(fighter, input);
        return;
      }
      if (fighter.state === "shield") fighter.state = "idle";
      if (fighter.attackLockFrames === 0 && input.pressed.has("attack") && fighter.heldItem) {
        this.useHeldItem(fighter, input, inputs[slotOther(fighter.slot)]);
        this.integrateFighter(fighter, input);
        return;
      }
      if (fighter.attackLockFrames === 0 && (input.pressed.has("attack") || input.pressed.has("special"))) {
        const requestedAction = input.pressed.has("special") ? "special" : "attack";
        this.consumeBufferedAction(fighter, requestedAction);
        const attackDirection = !input.pressed.has("special") && Math.hypot(direction.x, direction.y) <= 0.25 && fighter.smashDirectionFrames > 0 ? fighter.smashDirection : direction;
        const moveName = input.pressed.has("special") ? this.chooseSpecial(direction) : this.chooseNormal(fighter, attackDirection);
        if (moveName.includes("smash")) this.clearSmashDirection(fighter);
        const selectedMove = fighter.definition.attacks[moveName];
        if (moveName === "up-special" && (selectedMove.movement || selectedMove.specialMovement || selectedMove.projectile?.ownerLaunchOnContact)) {
          if (fighter.airUpSpecialUsed) {
            this.integrateFighter(fighter, input);
            return;
          }
          fighter.airUpSpecialUsed = true;
        }
        this.startMove(fighter, moveName, input);
        this.integrateFighter(fighter, input);
        return;
      }
      this.updateMovement(fighter, input, direction);
      this.integrateFighter(fighter, input);
    }
    tickFighterTimers(fighter) {
      fighter.invulnerableFrames = Math.max(0, fighter.invulnerableFrames - 1);
      fighter.dropThroughFrames = Math.max(0, fighter.dropThroughFrames - 1);
      fighter.ledgeCooldownFrames = Math.max(0, fighter.ledgeCooldownFrames - 1);
      fighter.shieldLockFrames = Math.max(0, fighter.shieldLockFrames - 1);
      fighter.coyoteFrames = Math.max(0, fighter.coyoteFrames - 1);
      fighter.lCancelFrames = Math.max(0, fighter.lCancelFrames - 1);
      fighter.fastFallInputFrames = Math.max(0, fighter.fastFallInputFrames - 1);
      fighter.smashDirectionFrames = Math.max(0, fighter.smashDirectionFrames - 1);
      if (fighter.smashDirectionFrames === 0) this.clearSmashDirection(fighter);
      fighter.statusResistanceFrames = Math.max(0, fighter.statusResistanceFrames - 1);
      fighter.techWindowFrames = Math.max(0, fighter.techWindowFrames - 1);
      fighter.techLockoutFrames = Math.max(0, fighter.techLockoutFrames - 1);
      fighter.attackLockFrames = Math.max(0, fighter.attackLockFrames - 1);
      if (fighter.lastHitFrames > 0) fighter.lastHitFrames -= 1;
      else fighter.lastHitBy = null;
      if (fighter.damageBuffFrames > 0) fighter.damageBuffFrames -= 1;
      else fighter.damageMultiplier = 1;
      if (fighter.speedBuffFrames > 0) fighter.speedBuffFrames -= 1;
      else fighter.speedMultiplier = 1;
      if (fighter.jumpBuffFrames > 0) fighter.jumpBuffFrames -= 1;
      else fighter.jumpMultiplier = 1;
      if (fighter.defenseBuffFrames > 0) fighter.defenseBuffFrames -= 1;
      else fighter.defenseMultiplier = 1;
      fighter.projectileShieldFrames = Math.max(0, fighter.projectileShieldFrames - 1);
      if (fighter.state !== "shield" && fighter.shieldLockFrames === 0 && fighter.shield < fighter.definition.shieldHealth) {
        fighter.shield = Math.min(
          fighter.definition.shieldHealth,
          fighter.shield + fighter.definition.shieldRegen * FIXED_DT
        );
      }
    }
    updateMovement(fighter, input, direction) {
      const support = fighter.supportPlatform ? this.stage.platforms.find((platform) => platform.id === fighter.supportPlatform) : void 0;
      if (fighter.grounded && support?.kind === "platform" && input.pressed.has("down")) {
        fighter.grounded = false;
        fighter.supportPlatform = null;
        fighter.dropThroughFrames = 12;
        fighter.position.y -= 5;
        fighter.state = "fall";
        return;
      }
      if (input.pressed.has("jump")) {
        this.consumeBufferedAction(fighter, "jump");
        if (fighter.grounded || fighter.coyoteFrames > 0) {
          fighter.jumpSquatFrames = effectiveJumpSquatFrames(fighter.definition.jumpSquatFrames);
          fighter.fullHopRequested = input.held.has("jump");
          fighter.state = "jump-squat";
          return;
        } else if (fighter.jumpsRemaining > 0) {
          fighter.jumpsRemaining -= 1;
          fighter.shortHopReleaseFrames = 0;
          fighter.velocity.y = jumpSpeedForMinimumRise(
            fighter.definition.doubleJumpSpeed,
            fighter.definition.gravity,
            MIN_DOUBLE_JUMP_RISE
          ) * fighter.jumpMultiplier;
          fighter.fastFalling = false;
          fighter.fastFallInputFrames = 0;
          fighter.state = "jump";
          this.emit({ type: "jump", slot: fighter.slot, position: cloneVec(fighter.position), sound: "double-jump" });
        }
      }
      const speed = fighter.definition.runSpeed * fighter.speedMultiplier * GROUND_RUN_SPEED_MULTIPLIER;
      if (fighter.grounded) {
        if (direction.y < -0.55 && Math.abs(direction.y) >= Math.abs(direction.x)) {
          fighter.analogRunning = false;
          fighter.dashFrames = 0;
          fighter.turnFrames = 0;
          fighter.velocity.x = approach(
            fighter.velocity.x,
            0,
            fighter.definition.traction * FIXED_DT
          );
          fighter.state = "crouch";
        } else if (Math.abs(direction.x) > 0.08) {
          const directionSign = direction.x < 0 ? -1 : 1;
          const stickAmount = Math.abs(input.direction.x);
          const stickEffort = Math.min(1, Math.hypot(input.direction.x, input.direction.y));
          const running = !input.analog || stickAmount >= 0.45 && stickEffort >= (fighter.analogRunning ? 0.56 : 0.68);
          fighter.analogRunning = Boolean(input.analog && running);
          const changedFacing = directionSign !== fighter.facing && Math.abs(fighter.velocity.x) > 28;
          const directionAction = directionSign < 0 ? "left" : "right";
          const dashDancePivot = running && changedFacing && fighter.state === "dash" && fighter.dashFrames > 0 && input.pressed.has(directionAction);
          if (running && input.pressed.has(directionAction)) {
            fighter.dashFrames = fighter.definition.initialDashFrames;
            if (dashDancePivot || !changedFacing || Math.abs(fighter.velocity.x) <= 28) {
              const impulseMultiplier = input.analog ? 1 : DIGITAL_DASH_IMPULSE_MULTIPLIER;
              fighter.velocity.x = directionSign * fighter.definition.initialDashSpeed * fighter.speedMultiplier * impulseMultiplier;
            }
          }
          if (dashDancePivot) fighter.turnFrames = 0;
          else if (changedFacing) fighter.turnFrames = 5;
          const walkAmount = clamp(stickAmount / 0.72, 0, 1);
          const dashSpeed = fighter.definition.initialDashSpeed * fighter.speedMultiplier;
          const targetSpeed = running ? directionSign * (fighter.dashFrames > 0 ? dashSpeed : speed) * (input.analog ? Math.max(0.68, stickAmount) : 1) : directionSign * speed * (0.2 + walkAmount * 0.38);
          const reversingVelocity = Math.abs(fighter.velocity.x) > 28 && Math.sign(fighter.velocity.x) !== directionSign;
          fighter.velocity.x = approach(
            fighter.velocity.x,
            targetSpeed,
            fighter.definition.groundAcceleration * (reversingVelocity ? GROUND_REVERSAL_ACCELERATION_MULTIPLIER : 1) * FIXED_DT
          );
          fighter.facing = direction.x < 0 ? -1 : 1;
          if (fighter.turnFrames > 0) {
            fighter.turnFrames -= 1;
            fighter.state = "turn";
          } else if (running && fighter.dashFrames > 0) {
            fighter.dashFrames -= 1;
            fighter.state = "dash";
          } else {
            fighter.dashFrames = 0;
            fighter.state = running ? "run" : "walk";
          }
        } else {
          fighter.analogRunning = false;
          fighter.dashFrames = 0;
          fighter.turnFrames = 0;
          fighter.velocity.x = approach(
            fighter.velocity.x,
            0,
            fighter.definition.traction * GROUND_RELEASE_BRAKE_MULTIPLIER * FIXED_DT
          );
          fighter.state = "idle";
        }
      } else {
        this.applyAirDrift(fighter, input, 1);
        fighter.state = fighter.velocity.y > 0 ? "jump" : "fall";
      }
    }
    applyAirDrift(fighter, input, multiplier) {
      if (fighter.grounded) return;
      const direction = normalizedDirection(input);
      const target = direction.x * fighter.definition.airSpeed * fighter.speedMultiplier;
      fighter.velocity.x = approach(
        fighter.velocity.x,
        target,
        fighter.definition.airAcceleration * multiplier * FIXED_DT
      );
      if (Math.abs(direction.x) > 0.1 && !fighter.action) fighter.facing = direction.x < 0 ? -1 : 1;
    }
    chooseNormal(fighter, direction) {
      if (!fighter.grounded) {
        if (direction.y > 0.52) return "up-air";
        if (direction.y < -0.52) return "down-air";
        if (Math.abs(direction.x) > 0.42) {
          return direction.x * fighter.facing < 0 ? "back-air" : "forward-air";
        }
        return "neutral-air";
      }
      const smashDirection = fighter.smashDirectionFrames > 0 ? fighter.smashDirectionAction : null;
      if (!smashDirection && (fighter.state === "dash" || fighter.state === "run") && Math.abs(fighter.velocity.x) > fighter.definition.runSpeed * 0.35) {
        return "dash-attack";
      }
      if (direction.y > 0.52) {
        return smashDirection === "up" ? "up-smash" : "up-tilt";
      }
      if (direction.y < -0.52) {
        return smashDirection === "down" ? "down-smash" : "down-tilt";
      }
      if (Math.abs(direction.x) > 0.42) {
        fighter.facing = direction.x < 0 ? -1 : 1;
        return smashDirection === (direction.x < 0 ? "left" : "right") ? "forward-smash" : "forward-tilt";
      }
      return "jab";
    }
    chooseSpecial(direction) {
      if (direction.y > 0.5) return "up-special";
      if (direction.y < -0.5) return "down-special";
      if (Math.abs(direction.x) > 0.45) return "side-special";
      return "neutral-special";
    }
    startMove(fighter, name, input) {
      const move2 = fighter.definition.attacks[name];
      const button = name.endsWith("special") ? "special" : "attack";
      const initialDirection = normalizedDirection(input);
      const storedCharge = move2.storesCharge ? fighter.storedCharges[name] ?? 0 : 0;
      const maximumCharge = move2.maxChargeFrames ?? 1;
      fighter.action = {
        name,
        frame: 0,
        chargeFrames: storedCharge,
        charging: Boolean(
          move2.chargeable && input.held.has(button) && storedCharge < maximumCharge
        ),
        spawnedProjectile: false,
        hitTargets: /* @__PURE__ */ new Set(),
        lastHitFrame: /* @__PURE__ */ new Map(),
        hitCounts: /* @__PURE__ */ new Map(),
        startedGrounded: fighter.grounded,
        startedSupportPlatform: fighter.supportPlatform,
        specialPhase: name.endsWith("special") ? "startup" : null,
        lastSpecialDirection: Math.hypot(initialDirection.x, initialDirection.y) > 0.25 ? initialDirection : null,
        appliedSelfDamage: false
      };
      if (move2.projectile?.detonatesOnChargeRelease) {
        this.spawnProjectile(fighter, name, move2);
        fighter.action.spawnedProjectile = true;
      }
      fighter.state = "attack";
      this.emit({
        type: "attack",
        slot: fighter.slot,
        move: name,
        position: cloneVec(fighter.position),
        sound: name.includes("smash") ? "swing-heavy" : name.includes("special") ? "special" : "swing-light"
      });
    }
    updateActiveMove(fighter, input) {
      const action = fighter.action;
      if (!action) return;
      const move2 = fighter.definition.attacks[action.name];
      const button = action.name.endsWith("special") ? "special" : "attack";
      if (fighter.grounded && action.name === "jab" && action.frame < move2.startup && fighter.smashDirectionFrames > 0 && fighter.smashDirectionAction) {
        const smashName = fighter.smashDirectionAction === "up" ? "up-smash" : fighter.smashDirectionAction === "down" ? "down-smash" : "forward-smash";
        fighter.action = null;
        this.startMove(fighter, smashName, input);
        this.clearSmashDirection(fighter);
        return;
      }
      if (action.charging) {
        const maximum = move2.maxChargeFrames ?? 1;
        if (move2.storesCharge && input.pressed.has("shield")) {
          fighter.storedCharges[action.name] = action.chargeFrames;
          fighter.action = null;
          fighter.state = fighter.grounded ? "idle" : "fall";
          this.consumeBufferedAction(fighter, "shield");
          return;
        }
        if (input.held.has(button) && action.chargeFrames < maximum) {
          action.chargeFrames += 1;
          fighter.velocity.x = approach(fighter.velocity.x, 0, fighter.definition.traction * FIXED_DT);
          return;
        }
        if (move2.storesCharge && action.chargeFrames >= maximum) {
          fighter.storedCharges[action.name] = maximum;
          fighter.action = null;
          fighter.state = fighter.grounded ? "idle" : "fall";
          return;
        }
        action.charging = false;
        if (move2.projectile?.detonatesOnChargeRelease) {
          const projectile = this.projectiles.find(
            (candidate) => candidate.owner === fighter.slot && candidate.move === action.name
          );
          if (projectile) {
            projectile.powerScale = this.chargeScale(move2, action.chargeFrames);
            projectile.detonating = true;
            projectile.remainingFrames = Math.max(1, projectile.remainingFrames);
            projectile.velocity = { x: 0, y: 0 };
            this.emit({
              type: "attack-active",
              slot: fighter.slot,
              move: action.name,
              position: cloneVec(projectile.position)
            });
          }
        }
      }
      action.frame += 1;
      if (action.name.endsWith("special") && action.specialPhase !== "landing") {
        action.specialPhase = action.frame < move2.startup ? "startup" : action.frame < move2.startup + move2.active ? "active" : "recovery";
      }
      this.applySpecialMovement(fighter, action, move2, input);
      if (action.frame === Math.max(1, move2.startup)) {
        if (move2.storesCharge) fighter.storedCharges[action.name] = 0;
        if (move2.selfDamage && !action.appliedSelfDamage) {
          fighter.percent += move2.selfDamage;
          action.appliedSelfDamage = true;
        }
        if (move2.movement && !move2.specialMovement) {
          const direction = normalizedDirection(input);
          const horizontalSign = Math.abs(direction.x) > 0.25 ? Math.sign(direction.x) : fighter.facing;
          const authoredMovement = !action.startedGrounded && move2.airMovement ? move2.airMovement : move2.movement;
          fighter.velocity.x = Math.abs(authoredMovement.x) * horizontalSign;
          if (authoredMovement.y !== 0) {
            fighter.velocity.y = authoredMovement.y;
            fighter.grounded = false;
            fighter.supportPlatform = null;
          }
        }
        if (move2.projectile && !action.spawnedProjectile) {
          this.spawnProjectile(fighter, action.name, move2);
          action.spawnedProjectile = true;
        }
        this.emit({
          type: "attack-active",
          slot: fighter.slot,
          move: action.name,
          position: {
            x: fighter.position.x + move2.offset.x * fighter.facing,
            y: fighter.position.y + move2.offset.y
          }
        });
      }
      const totalFrames = move2.startup + move2.active + move2.recovery;
      if (action.frame >= totalFrames) {
        fighter.action = null;
        fighter.state = fighter.grounded ? "idle" : "fall";
      }
    }
    applySpecialMovement(fighter, action, move2, input) {
      const behavior = move2.specialMovement;
      if (!behavior) return;
      const inputDirection = normalizedDirection(input);
      const inputMagnitude = Math.hypot(inputDirection.x, inputDirection.y);
      const fallbackDirection = action.lastSpecialDirection ?? { x: 0, y: 1 };
      const direction = inputMagnitude > 0.25 ? inputDirection : fallbackDirection;
      const directionMagnitude = Math.hypot(direction.x, direction.y) || 1;
      const normalized = {
        x: direction.x / directionMagnitude,
        y: direction.y / directionMagnitude
      };
      if (behavior.kind === "authored-root-motion") {
        const totalFrames = Math.max(1, move2.startup + move2.active + move2.recovery);
        const current = sampleRootMotion(behavior.samples, action.frame / totalFrames);
        const previous2 = sampleRootMotion(
          behavior.samples,
          Math.max(0, action.frame - 1) / totalFrames
        );
        const worldScale = fighter.definition.size.height * SPRITE_VISUAL_TO_BODY_HEIGHT_RATIO;
        const verticalScale = worldScale * (!action.startedGrounded ? behavior.airVerticalMultiplier ?? 1 : 1);
        const authoredHorizontal = action.lastSpecialDirection?.x ?? 0;
        const horizontalSign = Math.abs(authoredHorizontal) > 0.25 ? Math.sign(authoredHorizontal) : fighter.facing;
        fighter.velocity = {
          x: (current.x - previous2.x) * worldScale * horizontalSign / FIXED_DT,
          y: (current.y - previous2.y) * verticalScale / FIXED_DT
        };
        if (Math.abs(fighter.velocity.y) > 0.01) {
          fighter.grounded = false;
          fighter.supportPlatform = null;
        }
        return;
      }
      if (behavior.kind === "steered-rise") {
        const startFrame2 = Math.max(1, move2.startup);
        if (action.frame < startFrame2) return;
        const groundSupport = action.startedSupportPlatform ? this.stage.platforms.find((platform) => platform.id === action.startedSupportPlatform) : void 0;
        const staysOnAuthoredGround = Boolean(
          action.startedGrounded && behavior.staysGroundedWhenStartedGrounded && groundSupport && platformContainsX(groundSupport, fighter.position.x)
        );
        if (action.frame === startFrame2) {
          fighter.velocity.x *= 0.42;
          if (!staysOnAuthoredGround) {
            fighter.velocity.y = behavior.riseSpeed;
            fighter.grounded = false;
            fighter.supportPlatform = null;
          }
          action.specialPhase = "active";
        }
        if (staysOnAuthoredGround && groundSupport) {
          fighter.grounded = true;
          fighter.supportPlatform = groundSupport.id;
          fighter.position.y = platformTop(groundSupport, fighter.position.x) + fighter.definition.size.height / 2;
          fighter.velocity.y = 0;
        }
        if (action.frame <= startFrame2 + behavior.steerFrames) {
          if (!staysOnAuthoredGround) {
            const riseProgress = clamp(
              (action.frame - startFrame2) / Math.max(1, behavior.steerFrames),
              0,
              1
            );
            const sustainedRiseSpeed = behavior.riseSpeed * (1 - riseProgress * 0.35);
            fighter.velocity.y = Math.max(fighter.velocity.y, sustainedRiseSpeed);
          }
          const horizontalInput = Math.abs(inputDirection.x) > 0.15 ? inputDirection.x : 0;
          const targetVelocity = horizontalInput * behavior.horizontalSpeed;
          fighter.velocity.x = approach(
            fighter.velocity.x,
            targetVelocity,
            behavior.horizontalSpeed * 0.16
          );
          if (horizontalInput !== 0) {
            fighter.facing = horizontalInput < 0 ? -1 : 1;
            action.lastSpecialDirection = {
              x: horizontalInput,
              y: action.startedGrounded && behavior.staysGroundedWhenStartedGrounded ? 0 : 1
            };
          }
        }
        return;
      }
      if (behavior.kind === "directional-bursts") {
        if (!behavior.frames.includes(action.frame)) return;
        fighter.velocity = {
          x: normalized.x * behavior.speed,
          y: normalized.y * behavior.speed
        };
        fighter.facing = normalized.x < -0.1 ? -1 : normalized.x > 0.1 ? 1 : fighter.facing;
        fighter.grounded = false;
        fighter.supportPlatform = null;
        action.lastSpecialDirection = normalized;
        action.specialPhase = "active";
        if (action.frame !== Math.max(1, move2.startup)) {
          this.emit({
            type: "attack-active",
            slot: fighter.slot,
            move: action.name,
            position: cloneVec(fighter.position)
          });
        }
        return;
      }
      if (behavior.kind === "directional-launch") {
        const startFrame2 = Math.max(1, move2.startup);
        if (action.frame === startFrame2 + DIRECTIONAL_LAUNCH_SUSTAIN_FRAMES) {
          fighter.velocity.x *= DIRECTIONAL_LAUNCH_EXIT_VELOCITY_RETENTION;
          fighter.velocity.y *= DIRECTIONAL_LAUNCH_EXIT_VELOCITY_RETENTION;
          return;
        }
        if (action.frame < startFrame2 || action.frame >= startFrame2 + DIRECTIONAL_LAUNCH_SUSTAIN_FRAMES) return;
        if (action.frame === startFrame2) action.lastSpecialDirection = normalized;
        const launchDirection = action.lastSpecialDirection ?? normalized;
        fighter.velocity = {
          x: launchDirection.x * behavior.speed,
          y: launchDirection.y * behavior.speed
        };
        fighter.facing = launchDirection.x < -0.1 ? -1 : launchDirection.x > 0.1 ? 1 : fighter.facing;
        fighter.grounded = false;
        fighter.supportPlatform = null;
        action.specialPhase = "active";
        return;
      }
      if (behavior.kind === "ground-steered") {
        const startFrame2 = Math.max(1, move2.startup);
        if (action.frame < startFrame2) return;
        const horizontalDirection = Math.abs(inputDirection.x) > 0.25 ? Math.sign(inputDirection.x) : fighter.facing;
        fighter.facing = horizontalDirection < 0 ? -1 : 1;
        fighter.velocity.x = behavior.speed * fighter.facing;
        if (action.startedGrounded && fighter.grounded) fighter.velocity.y = 0;
        action.lastSpecialDirection = { x: fighter.facing, y: 0 };
        action.specialPhase = "active";
        return;
      }
      const startFrame = Math.max(1, move2.startup);
      if (behavior.kind === "air-dive") {
        if (action.frame !== startFrame || action.startedGrounded) return;
        fighter.velocity.x *= 0.25;
        fighter.velocity.y = -behavior.diveSpeed;
        action.specialPhase = "active";
        return;
      }
      if (action.frame === startFrame) {
        fighter.velocity.x *= 0.2;
        fighter.velocity.y = action.startedGrounded ? behavior.riseSpeed : -behavior.diveSpeed;
        fighter.grounded = false;
        fighter.supportPlatform = null;
        action.specialPhase = "active";
        return;
      }
      if (action.startedGrounded && action.frame === startFrame + behavior.riseFrames) {
        fighter.velocity.x *= 0.2;
        fighter.velocity.y = -behavior.diveSpeed;
        action.specialPhase = "active";
        this.emit({
          type: "attack-active",
          slot: fighter.slot,
          move: action.name,
          position: cloneVec(fighter.position)
        });
      }
    }
    integrateFighter(fighter, input) {
      fighter.previousPosition = cloneVec(fighter.position);
      this.updateGroundSupport(fighter);
      if (!fighter.grounded && input.held.has("down") && normalizedDirection(input).y <= -0.45) {
        fighter.dropThroughFrames = Math.max(fighter.dropThroughFrames, 6);
      }
      const canFloat = Boolean(
        !fighter.grounded && fighter.definition.floatDurationFrames && fighter.floatFramesRemaining > 0 && input.held.has("jump") && fighter.velocity.y <= 0 && fighter.hitstunFrames === 0 && fighter.dodgeFrames === 0 && !fighter.airDodgeHelpless
      );
      fighter.floating = canFloat;
      if (canFloat) {
        fighter.floatFramesRemaining -= 1;
        fighter.velocity.y = 0;
        fighter.fastFalling = false;
        fighter.fastFallInputFrames = 0;
      }
      const usesAuthoredRootMotion = Boolean(
        fighter.action && fighter.definition.attacks[fighter.action.name].specialMovement?.kind === "authored-root-motion"
      );
      if (!fighter.grounded && !fighter.floating && !usesAuthoredRootMotion) {
        const authoredSpecialVelocity = Boolean(
          fighter.action?.specialPhase === "active" && fighter.definition.attacks[fighter.action.name].specialMovement
        );
        const fallLimit = authoredSpecialVelocity ? Number.POSITIVE_INFINITY : fighter.fastFalling ? fighter.definition.fastFallSpeed : fighter.definition.maxFallSpeed;
        fighter.velocity.y = Math.max(
          fighter.velocity.y - fighter.definition.gravity * FIXED_DT,
          -fallLimit
        );
      }
      const movementVelocity = this.fighterWorldVelocity(fighter);
      fighter.position.x += movementVelocity.x * FIXED_DT;
      fighter.position.y += movementVelocity.y * FIXED_DT;
      this.updateGroundSupport(fighter);
      const walkableGround = /* @__PURE__ */ new Set();
      if (fighter.grounded) {
        const footY = fighter.position.y - fighter.definition.size.height / 2;
        for (const platform of this.stage.platforms) {
          const top = platformTop(platform, fighter.position.x);
          const halfWidth = fighter.definition.size.width * 0.28;
          const bodyOverlaps = fighter.position.x + halfWidth >= platformLeft(platform) && fighter.position.x - halfWidth <= platformRight(platform);
          if (bodyOverlaps && top >= footY - 12 && top <= footY + 28) {
            walkableGround.add(platform.id);
          }
        }
      }
      this.resolveGroundVolumeCollision(fighter, walkableGround);
      if (fighter.grounded && fighter.supportPlatform) {
        const support = this.stage.platforms.find(
          (platform) => platform.id === fighter.supportPlatform
        );
        if (support) {
          fighter.position.y = platformTop(support, fighter.position.x) + fighter.definition.size.height / 2;
        }
      }
      if (!fighter.grounded && this.tryGrabLedge(fighter, input)) return;
      const collisionVelocity = this.fighterWorldVelocity(fighter);
      if (!fighter.grounded && collisionVelocity.y <= 0) {
        const halfHeight = fighter.definition.size.height / 2;
        const previousBottom = fighter.previousPosition.y - halfHeight;
        const currentBottom = fighter.position.y - halfHeight;
        let landing = null;
        let highestTop = Number.NEGATIVE_INFINITY;
        for (const platform of this.stage.platforms) {
          if (platform.kind === "platform" && fighter.dropThroughFrames > 0) continue;
          const previousTop = platformTop(platform, fighter.previousPosition.x);
          const top = platformTop(platform, fighter.position.x);
          const withinHorizontal = fighter.position.x + fighter.definition.size.width * 0.26 >= platform.position.x - platform.width / 2 && fighter.position.x - fighter.definition.size.width * 0.26 <= platform.position.x + platform.width / 2;
          if (withinHorizontal && previousBottom >= previousTop - 3 && currentBottom <= top && top > highestTop) {
            landing = platform;
            highestTop = top;
          }
        }
        if (landing) {
          const wasAirborne = !fighter.grounded;
          const impactSpeed = Math.abs(collisionVelocity.y);
          const landingAction = fighter.action;
          const wavedash = fighter.dodgeKind === "air" && fighter.dodgeFrames > 0;
          const teching = fighter.hitstunFrames > 0 && fighter.techable && fighter.techWindowFrames > 0;
          const lCancelled = Boolean(
            landingAction && AERIAL_NORMALS.has(landingAction.name) && fighter.lCancelFrames > 0
          );
          fighter.position.y = platformTop(landing, fighter.position.x) + halfHeight;
          fighter.velocity.y = 0;
          fighter.launchVelocity.y = 0;
          if (fighter.hitstunFrames > 0 && !teching) {
            fighter.velocity.x *= GROUND_HITSTUN_LANDING_VELOCITY_RETENTION;
            fighter.launchVelocity.x *= GROUND_HITSTUN_LANDING_VELOCITY_RETENTION;
          }
          fighter.grounded = true;
          fighter.supportPlatform = landing.id;
          fighter.jumpsRemaining = fighter.definition.maxJumps;
          fighter.floatFramesRemaining = fighter.definition.floatDurationFrames ?? 0;
          fighter.floating = false;
          fighter.fastFalling = false;
          fighter.fastFallInputFrames = 0;
          fighter.shortHopReleaseFrames = 0;
          fighter.airUpSpecialUsed = false;
          fighter.airDodgeUsed = false;
          fighter.airDodgeHelpless = false;
          fighter.coyoteFrames = 0;
          if (teching) {
            this.startGroundTech(fighter, input);
          } else if (wavedash) {
            fighter.dodgeFrames = 0;
            fighter.dodgeKind = null;
            fighter.wavedashFrames = WAVEDASH_LANDING_LAG_FRAMES;
            fighter.landingLagFrames = WAVEDASH_LANDING_LAG_FRAMES;
            fighter.state = "crouch";
          } else if (landingAction && AERIAL_NORMALS.has(landingAction.name)) {
            const baseLandingLag = landingLagFramesForAttack(
              fighter.definition.attacks[landingAction.name]
            );
            fighter.landingLagFrames = lCancelled ? Math.floor(baseLandingLag / 2) : baseLandingLag;
            fighter.action = null;
            fighter.state = "crouch";
          }
          fighter.lCancelFrames = 0;
          if (wasAirborne) {
            if (landingAction && fighter.definition.attacks[landingAction.name].specialMovement?.kind === "rise-then-dive") {
              landingAction.specialPhase = "landing";
            }
            this.emit({
              type: "land",
              slot: fighter.slot,
              position: cloneVec(fighter.position),
              impactSpeed,
              lCancelled,
              wavedash,
              sound: lCancelled ? "l-cancel" : wavedash ? "wavedash" : "land"
            });
          }
          if (!fighter.action && fighter.landingLagFrames === 0 && fighter.hitstunFrames === 0 && fighter.dodgeFrames === 0) {
            fighter.state = "idle";
          }
        }
      }
      if (!fighter.grounded && !fighter.action && fighter.hitstunFrames === 0 && fighter.dodgeFrames === 0) {
        fighter.state = this.fighterWorldVelocity(fighter).y > 0 ? "jump" : "fall";
      }
      fighter.launchVelocity = decayMeleeLaunchVelocity(fighter.launchVelocity);
    }
    updateGroundSupport(fighter) {
      if (!fighter.grounded) return;
      const footY = fighter.position.y - fighter.definition.size.height / 2;
      const currentSupport = fighter.supportPlatform ? this.stage.platforms.find((platform) => platform.id === fighter.supportPlatform) : void 0;
      const adjacent = this.stage.platforms.filter(
        (platform) => platformContainsX(platform, fighter.position.x) && platformTop(platform, fighter.position.x) >= footY - 12 && platformTop(platform, fighter.position.x) <= footY + 28
      ).sort(
        (a, b) => platformTop(b, fighter.position.x) - platformTop(a, fighter.position.x)
      )[0];
      if (adjacent) {
        fighter.supportPlatform = adjacent.id;
        fighter.position.y = platformTop(adjacent, fighter.position.x) + fighter.definition.size.height / 2;
        return;
      }
      if (currentSupport && platformContainsX(currentSupport, fighter.position.x)) {
        fighter.position.y = platformTop(currentSupport, fighter.position.x) + fighter.definition.size.height / 2;
        return;
      }
      const leavingGroundInHitstun = fighter.hitstunFrames > 0;
      fighter.grounded = false;
      fighter.supportPlatform = null;
      fighter.coyoteFrames = 6;
      if (leavingGroundInHitstun) {
        fighter.velocity.x *= GROUND_HITSTUN_EDGE_VELOCITY_RETENTION;
        fighter.launchVelocity.x *= GROUND_HITSTUN_EDGE_VELOCITY_RETENTION;
      }
      if (fighter.landingLagFrames > 0) {
        fighter.landingLagFrames = 0;
        fighter.wavedashFrames = 0;
        if (fighter.state === "crouch") fighter.state = "fall";
      }
    }
    /**
     * `ground` is a closed trapezoidal volume: its authored surface is the top,
     * `height` extrudes a parallel underside, and the two endpoints are solid
     * walls. One-way `platform` geometry deliberately never enters this path.
     */
    resolveGroundVolumeCollision(fighter, ignoredPlatformIds = /* @__PURE__ */ new Set(), _input = EMPTY_INPUT, allowTech = true) {
      const halfWidth = fighter.definition.size.width * 0.28;
      const halfHeight = fighter.definition.size.height / 2;
      const collision = findGroundVolumeCollision(
        this.stage.platforms,
        fighter.previousPosition,
        fighter.position,
        halfWidth,
        halfHeight,
        ignoredPlatformIds
      );
      if (!collision) return;
      if (collision.face === "bottom") {
        fighter.position.y = platformBottom(collision.platform, fighter.position.x) - halfHeight - 0.01;
        if (allowTech && fighter.hitstunFrames > 0 && fighter.techable && fighter.techWindowFrames > 0) {
          this.startWallTech(fighter, "ceiling");
          return;
        }
        fighter.velocity.y = Math.min(0, fighter.velocity.y);
        fighter.launchVelocity.y = Math.min(0, fighter.launchVelocity.y);
        return;
      }
      const edgeX = collision.face === "left" ? platformLeft(collision.platform) : platformRight(collision.platform);
      fighter.position.x = edgeX + (collision.face === "left" ? -halfWidth - 0.01 : halfWidth + 0.01);
      if (allowTech && fighter.hitstunFrames > 0 && fighter.techable && fighter.techWindowFrames > 0) {
        this.startWallTech(
          fighter,
          collision.face === "left" ? "wall-left" : "wall-right"
        );
        return;
      }
      fighter.velocity.x = 0;
      fighter.launchVelocity.x = 0;
    }
    tryGrabLedge(fighter, input) {
      const inputDirection = normalizedDirection(input);
      if (fighter.ledgeCooldownFrames > 0 || fighter.dodgeKind === "air" && fighter.dodgeFrames > 0 || this.fighterWorldVelocity(fighter).y > 260 || inputDirection.y < -0.7 || fighter.state === "hitstun") {
        return false;
      }
      const halfHeight = fighter.definition.size.height / 2;
      const halfWidth = fighter.definition.size.width * 0.28;
      for (const ledge of this.stage.ledges) {
        const { side, position: { x, y: ledgeY } } = ledge;
        const outward = side === "left" ? -1 : 1;
        const outwardDistance = (fighter.position.x - x) * outward;
        const bottom = fighter.position.y - halfHeight;
        const top = fighter.position.y + halfHeight;
        const occupied = this.fighters.some(
          (other) => other.slot !== fighter.slot && other.state === "ledge" && other.ledge === side
        );
        if (occupied || outwardDistance < -halfWidth * 0.35 || outwardDistance > halfWidth + LEDGE_HORIZONTAL_CATCH_BONUS || bottom > ledgeY + 20 || top < ledgeY - LEDGE_VERTICAL_CATCH_BONUS) {
          continue;
        }
        fighter.ledge = side;
        fighter.state = "ledge";
        fighter.grounded = false;
        fighter.supportPlatform = null;
        fighter.action = null;
        fighter.airUpSpecialUsed = false;
        fighter.airDodgeUsed = false;
        fighter.airDodgeHelpless = false;
        fighter.velocity = { x: 0, y: 0 };
        this.clearLaunchVelocity(fighter);
        fighter.ledgeHangFrames = LEDGE_MAX_HANG_FRAMES;
        const towardStage = side === "left" ? inputDirection.x > 0.35 : inputDirection.x < -0.35;
        fighter.ledgeDirectionReleased = inputDirection.y <= 0.35 && !towardStage;
        fighter.facing = -outward;
        fighter.position = {
          x: x + outward * (halfWidth + 2),
          y: ledgeY - halfHeight * 0.3
        };
        fighter.invulnerableFrames = Math.max(fighter.invulnerableFrames, 35);
        this.emit({ type: "ledge", slot: fighter.slot, position: cloneVec(fighter.position), sound: "ledge" });
        return true;
      }
      return false;
    }
    updateLedge(fighter, input) {
      const side = fighter.ledge;
      if (!side) {
        fighter.state = "fall";
        return;
      }
      const direction = normalizedDirection(input);
      const towardStage = side === "left" ? direction.x > 0.35 : direction.x < -0.35;
      const ledge = this.stage.ledges.find((candidate) => candidate.side === side);
      const support = ledge ? this.stage.platforms.find((platform) => platform.id === ledge.platformId) : void 0;
      const fallback = this.mainPlatform();
      const ledgePlatform = support ?? fallback;
      const ledgeX = ledge?.position.x ?? (side === "left" ? platformLeft(ledgePlatform) : platformRight(ledgePlatform));
      fighter.ledgeHangFrames = Math.max(0, fighter.ledgeHangFrames - 1);
      if (fighter.ledgeHangFrames === 0) {
        fighter.ledge = null;
        fighter.ledgeCooldownFrames = 35;
        fighter.position.y -= 8;
        fighter.velocity = { x: 0, y: -90 };
        fighter.jumpsRemaining = Math.max(fighter.jumpsRemaining, 1);
        fighter.state = "fall";
        return;
      }
      if (input.pressed.has("jump")) {
        this.consumeBufferedAction(fighter, "jump");
        fighter.ledge = null;
        fighter.ledgeHangFrames = 0;
        fighter.ledgeCooldownFrames = 30;
        fighter.velocity = { x: side === "left" ? 145 : -145, y: fighter.definition.jumpSpeed * 0.82 };
        fighter.state = "jump";
        this.emit({ type: "jump", slot: fighter.slot, position: cloneVec(fighter.position), sound: "ledge-jump" });
        return;
      }
      if (input.pressed.has("down") || direction.y < -0.65 && input.pressed.has("shield")) {
        fighter.ledge = null;
        fighter.ledgeHangFrames = 0;
        fighter.ledgeCooldownFrames = 35;
        fighter.position.y -= 8;
        fighter.velocity.y = -90;
        fighter.jumpsRemaining = Math.max(fighter.jumpsRemaining, 1);
        fighter.state = "fall";
        return;
      }
      const leaveLedgeOnStage = () => {
        fighter.ledge = null;
        fighter.ledgeHangFrames = 0;
        fighter.ledgeCooldownFrames = 25;
        fighter.grounded = true;
        fighter.supportPlatform = ledgePlatform.id;
        const landingX = ledgeX + (side === "left" ? fighter.definition.size.width * 0.62 : -fighter.definition.size.width * 0.62);
        fighter.position = {
          x: landingX,
          y: platformTop(ledgePlatform, landingX) + fighter.definition.size.height / 2
        };
        fighter.velocity = { x: 0, y: 0 };
        fighter.airUpSpecialUsed = false;
        fighter.state = "idle";
      };
      if (input.pressed.has("shield") || input.pressed.has("grab")) {
        this.consumeBufferedAction(
          fighter,
          input.pressed.has("shield") ? "shield" : "grab"
        );
        leaveLedgeOnStage();
        this.startDodge(fighter, { x: side === "left" ? 1 : -1, y: 0 });
        return;
      }
      if (input.pressed.has("attack")) {
        this.consumeBufferedAction(fighter, "attack");
        leaveLedgeOnStage();
        this.startMove(fighter, "forward-tilt", input);
        return;
      }
      const climbDirectionHeld = towardStage || direction.y > 0.35;
      if (!fighter.ledgeDirectionReleased) {
        if (!climbDirectionHeld) fighter.ledgeDirectionReleased = true;
        return;
      }
      if (climbDirectionHeld) {
        leaveLedgeOnStage();
      }
    }
    consumeTechWindow(fighter) {
      fighter.techWindowFrames = 0;
      fighter.techLockoutFrames = Math.max(
        fighter.techLockoutFrames,
        TECH_INPUT_LOCKOUT_FRAMES
      );
      fighter.techable = false;
      fighter.hitstunFrames = 0;
      fighter.action = null;
      fighter.landingLagFrames = 0;
      fighter.wavedashFrames = 0;
      this.clearLaunchVelocity(fighter);
      if (fighter.bufferedAction === "shield") this.clearBufferedAction(fighter);
    }
    startGroundTech(fighter, input) {
      this.consumeTechWindow(fighter);
      const direction = normalizedDirection(input);
      const rollDirection = Math.abs(direction.x) >= 0.35 ? Math.sign(direction.x) : 0;
      fighter.state = "dodge";
      fighter.dodgeFrames = TECH_NEUTRAL_FRAMES;
      fighter.invulnerableFrames = Math.max(
        fighter.invulnerableFrames,
        TECH_INVULNERABLE_FRAMES
      );
      let techKind = "neutral";
      if (rollDirection === 0) {
        fighter.dodgeKind = "spot";
        fighter.velocity.x = 0;
      } else {
        fighter.dodgeKind = rollDirection * fighter.facing > 0 ? "forward" : "back";
        fighter.velocity.x = rollDirection * 390;
        techKind = rollDirection < 0 ? "roll-left" : "roll-right";
      }
      this.emit({
        type: "dodge",
        slot: fighter.slot,
        position: cloneVec(fighter.position),
        techKind,
        sound: "dodge"
      });
    }
    startWallTech(fighter, techKind) {
      this.consumeTechWindow(fighter);
      fighter.grounded = false;
      fighter.supportPlatform = null;
      fighter.state = "dodge";
      fighter.dodgeKind = "air";
      fighter.dodgeFrames = TECH_NEUTRAL_FRAMES;
      fighter.invulnerableFrames = Math.max(
        fighter.invulnerableFrames,
        TECH_INVULNERABLE_FRAMES
      );
      if (techKind === "ceiling") {
        fighter.velocity = { x: fighter.velocity.x * 0.35, y: -180 };
      } else {
        const outward = techKind === "wall-left" ? -1 : 1;
        fighter.velocity = {
          x: outward * 220,
          y: Math.max(150, fighter.velocity.y * 0.25)
        };
      }
      this.emit({
        type: "dodge",
        slot: fighter.slot,
        position: cloneVec(fighter.position),
        techKind,
        sound: "dodge"
      });
    }
    startDodge(fighter, direction) {
      const airborne = !fighter.grounded;
      fighter.state = "dodge";
      fighter.action = null;
      this.clearLaunchVelocity(fighter);
      fighter.dodgeFrames = airborne ? 49 : 25;
      fighter.invulnerableFrames = airborne ? 26 : 15;
      if (airborne) {
        fighter.dodgeKind = "air";
        fighter.airDodgeUsed = true;
        fighter.airDodgeHelpless = true;
        const magnitude = Math.hypot(direction.x, direction.y);
        const boost = fighter.definition.runSpeed * fighter.speedMultiplier * AIR_DODGE_SPEED_MULTIPLIER;
        fighter.velocity = magnitude > 0.2 ? { x: direction.x * boost, y: direction.y * boost } : { x: 0, y: 0 };
        fighter.fastFalling = false;
      } else {
        if (Math.abs(direction.x) <= 0.15) {
          fighter.dodgeKind = "spot";
          fighter.velocity.x = 0;
        } else {
          const rollDirection = Math.sign(direction.x);
          fighter.dodgeKind = rollDirection * fighter.facing > 0 ? "forward" : "back";
          fighter.velocity.x = rollDirection * 455;
        }
      }
      this.emit({ type: "dodge", slot: fighter.slot, position: cloneVec(fighter.position), sound: "dodge" });
    }
    startGrab(fighter) {
      fighter.state = "grab";
      fighter.velocity.x *= 0.3;
      const target = this.fighters[slotOther(fighter.slot)];
      const horizontal = (target.position.x - fighter.position.x) * fighter.facing;
      const vertical = Math.abs(target.position.y - fighter.position.y);
      const grabbable = horizontal > -8 && horizontal < 86 && vertical < (fighter.definition.size.height + target.definition.size.height) * 0.46 && target.invulnerableFrames === 0 && target.state !== "ko" && target.state !== "grabbed" && target.state !== "ledge";
      if (!grabbable) {
        fighter.grabFrames = 23;
        return;
      }
      fighter.grabTarget = target.slot;
      fighter.grabFrames = 1;
      target.grabbedBy = fighter.slot;
      target.state = "grabbed";
      target.action = null;
      target.velocity = { x: 0, y: 0 };
      this.clearLaunchVelocity(target);
      target.grounded = false;
      target.supportPlatform = null;
      this.followGrabber(target);
      this.emit({
        type: "grab",
        slot: fighter.slot,
        target: target.slot,
        position: cloneVec(target.position),
        sound: "grab"
      });
    }
    followGrabber(fighter) {
      if (fighter.grabbedBy === null) {
        fighter.state = "fall";
        return;
      }
      const grabber = this.fighters[fighter.grabbedBy];
      if (grabber.grabTarget !== fighter.slot) {
        fighter.grabbedBy = null;
        fighter.state = "fall";
        return;
      }
      const grabDistance = (grabber.definition.size.width + fighter.definition.size.width) * 0.25;
      const grabberFeet = grabber.position.y - grabber.definition.size.height / 2;
      fighter.position = {
        x: grabber.position.x + grabber.facing * grabDistance,
        y: grabberFeet + fighter.definition.size.height / 2 + 4
      };
      fighter.previousPosition = cloneVec(fighter.position);
      fighter.facing = grabber.facing === 1 ? -1 : 1;
    }
    updateHeldGrab(fighter, input, targetInput) {
      const targetSlot = fighter.grabTarget;
      if (targetSlot === null) return;
      const target = this.fighters[targetSlot];
      fighter.grabFrames += 1;
      fighter.state = "grab";
      fighter.velocity.x = 0;
      this.followGrabber(target);
      let throwName = null;
      if (fighter.grabFrames > 3) {
        if (input.pressed.has("up")) throwName = "up";
        else if (input.pressed.has("down")) throwName = "down";
        else if (input.pressed.has("left") || input.pressed.has("right")) {
          const pressedHorizontal = input.pressed.has("left") ? -1 : 1;
          throwName = pressedHorizontal * fighter.facing < 0 ? "back" : "forward";
        } else if (input.pressed.has("attack") || input.pressed.has("grab")) {
          throwName = "forward";
        } else if (fighter.grabFrames >= 65) {
          throwName = "forward";
        }
      }
      if (throwName) this.performThrow(fighter, target, throwName, targetInput);
    }
    performThrow(fighter, target, name, targetInput) {
      const throwDefinition = fighter.definition.throws[name];
      target.grabbedBy = null;
      fighter.grabTarget = null;
      fighter.grabFrames = 16;
      fighter.throwAnimation = name;
      fighter.state = "grab";
      const throwDirection = name === "forward" ? fighter.facing : name === "back" ? -fighter.facing : 0;
      if (throwDirection !== 0) {
        const separation = (fighter.definition.size.width + target.definition.size.width) * 0.34 + 2;
        target.position.x = fighter.position.x + throwDirection * separation;
        target.previousPosition = cloneVec(target.position);
      }
      const baseAngle = throwDefinition.angle;
      const angle = fighter.facing === 1 ? baseAngle : (180 - baseAngle + 360) % 360;
      this.applyLaunch(
        target,
        fighter,
        throwDefinition.damage * fighter.damageMultiplier,
        angle,
        throwDefinition.baseKnockback,
        throwDefinition.knockbackGrowth,
        6,
        targetInput
      );
      this.emit({
        type: "throw",
        slot: fighter.slot,
        target: target.slot,
        position: cloneVec(target.position),
        value: throwDefinition.damage,
        damage: throwDefinition.damage,
        source: "throw",
        velocity: this.fighterWorldVelocity(target),
        sound: "throw"
      });
    }
    breakShield(fighter) {
      fighter.shield = fighter.definition.shieldHealth * 0.28;
      fighter.shieldLockFrames = 210;
      fighter.hitstunFrames = 135;
      fighter.techable = false;
      fighter.techWindowFrames = 0;
      fighter.state = "hitstun";
      fighter.grounded = false;
      fighter.supportPlatform = null;
      fighter.velocity = { x: 0, y: 430 };
      this.clearLaunchVelocity(fighter);
      this.emit({
        type: "shield-break",
        slot: fighter.slot,
        position: cloneVec(fighter.position),
        sound: "shield-break"
      });
    }
    respawnFighter(fighter) {
      const x = fighter.slot === 0 ? -150 : 150;
      fighter.position = { x, y: 390 };
      fighter.previousPosition = cloneVec(fighter.position);
      fighter.velocity = { x: 0, y: 0 };
      this.clearLaunchVelocity(fighter);
      fighter.percent = 0;
      fighter.state = "respawn";
      fighter.respawnFrames = 45;
      fighter.grounded = false;
      fighter.supportPlatform = null;
      fighter.jumpsRemaining = fighter.definition.maxJumps;
      fighter.fastFalling = false;
      fighter.fastFallInputFrames = 0;
      fighter.floatFramesRemaining = fighter.definition.floatDurationFrames ?? 0;
      fighter.floating = false;
      fighter.airUpSpecialUsed = false;
      fighter.airDodgeUsed = false;
      fighter.airDodgeHelpless = false;
      fighter.analogRunning = false;
      fighter.invulnerableFrames = 120;
      fighter.action = null;
      fighter.hitstopFrames = 0;
      fighter.hitstopElapsedFrames = 0;
      fighter.hitstunFrames = 0;
      fighter.launchBaseAngle = null;
      fighter.pendingHitstopDi = null;
      fighter.sdiRegion = null;
      fighter.asdiDirection = null;
      fighter.techWindowFrames = 0;
      fighter.techLockoutFrames = 0;
      fighter.techable = false;
      fighter.statusEffect = null;
      fighter.statusResistanceFrames = 0;
      fighter.lastHitMove = null;
      fighter.consecutiveHitMoveCount = 0;
      fighter.dodgeFrames = 0;
      fighter.dodgeKind = null;
      fighter.jumpSquatFrames = 0;
      fighter.fullHopRequested = true;
      fighter.shortHopReleaseFrames = 0;
      fighter.landingLagFrames = 0;
      fighter.wavedashFrames = 0;
      fighter.lCancelFrames = 0;
      this.clearBufferedAction(fighter);
      this.clearSmashDirection(fighter);
      fighter.dashFrames = 0;
      fighter.turnFrames = 0;
      fighter.tauntFrames = 0;
      fighter.attackLockFrames = 0;
      fighter.grabFrames = 0;
      fighter.throwAnimation = null;
      fighter.lastHitBy = null;
      fighter.lastHitFrames = 0;
      fighter.ledge = null;
      fighter.ledgeDirectionReleased = false;
      fighter.heldItem = null;
      fighter.itemUseFrames = 0;
      fighter.itemAction = null;
      fighter.damageMultiplier = 1;
      fighter.damageBuffFrames = 0;
      fighter.speedMultiplier = 1;
      fighter.speedBuffFrames = 0;
      fighter.jumpMultiplier = 1;
      fighter.jumpBuffFrames = 0;
      fighter.defenseMultiplier = 1;
      fighter.defenseBuffFrames = 0;
      fighter.projectileShieldFrames = 0;
      this.emit({ type: "respawn", slot: fighter.slot, position: cloneVec(fighter.position), sound: "respawn" });
    }
    resolveFighterOverlap() {
      const first = this.fighters[0];
      const second = this.fighters[1];
      const rolling = (fighter) => fighter.state === "dodge" && (fighter.dodgeKind === "forward" || fighter.dodgeKind === "back");
      if (first.state === "ko" || second.state === "ko" || first.state === "grabbed" || second.state === "grabbed" || first.state === "ledge" || second.state === "ledge" || rolling(first) || rolling(second)) {
        return;
      }
      const verticalDistance = Math.abs(first.position.y - second.position.y);
      const verticalLimit = (first.definition.size.height + second.definition.size.height) * 0.35;
      if (verticalDistance > verticalLimit) return;
      const minimumDistance = (first.definition.size.width + second.definition.size.width) * 0.34;
      const delta = second.position.x - first.position.x;
      if (Math.abs(delta) >= minimumDistance) return;
      const direction = delta === 0 ? 1 : Math.sign(delta);
      const correction = (minimumDistance - Math.abs(delta)) / 2;
      first.position.x -= direction * correction;
      second.position.x += direction * correction;
    }
    activeWorldHitboxes(fighter, action, move2) {
      const activeFrame = action.frame - move2.startup;
      return competitiveHitboxesForMove(action.name, move2, activeFrame).map((hitbox) => ({
        ...hitbox,
        position: {
          x: fighter.position.x + hitbox.offset.x * fighter.facing,
          y: fighter.position.y + hitbox.offset.y
        }
      }));
    }
    attackCanClank(fighter, action, move2) {
      const active = action.frame >= move2.startup && action.frame < move2.startup + move2.active;
      return Boolean(
        active && !action.charging && fighter.grounded && action.startedGrounded && !action.name.endsWith("special") && !move2.commandGrab && !move2.counters && (!move2.projectile || move2.alsoMelee)
      );
    }
    cancelAttackForClank(fighter, reboundFrames) {
      fighter.action = null;
      fighter.velocity.x *= 0.2;
      fighter.hitstopFrames = Math.max(fighter.hitstopFrames, 2);
      fighter.landingLagFrames = Math.max(fighter.landingLagFrames, reboundFrames);
      fighter.attackLockFrames = Math.max(fighter.attackLockFrames, reboundFrames);
      fighter.state = fighter.grounded ? "crouch" : "fall";
    }
    /** Melee ground attacks clank by post-multiplier damage, not a hidden priority stat. */
    resolveAttackClank() {
      const first = this.fighters[0];
      const second = this.fighters[1];
      const firstAction = first.action;
      const secondAction = second.action;
      if (!firstAction || !secondAction) return;
      const firstMove = first.definition.attacks[firstAction.name];
      const secondMove = second.definition.attacks[secondAction.name];
      if (!this.attackCanClank(first, firstAction, firstMove) || !this.attackCanClank(second, secondAction, secondMove)) return;
      const firstHitboxes = this.activeWorldHitboxes(first, firstAction, firstMove).sort((left, right) => right.priority - left.priority);
      const secondHitboxes = this.activeWorldHitboxes(second, secondAction, secondMove).sort((left, right) => right.priority - left.priority);
      const collision = firstHitboxes.flatMap((firstHitbox) => secondHitboxes.map((secondHitbox) => ({ firstHitbox, secondHitbox }))).find(({ firstHitbox, secondHitbox }) => distanceSquared(firstHitbox.position, secondHitbox.position) <= (firstHitbox.radius + secondHitbox.radius) ** 2);
      if (!collision) return;
      const firstDamage = firstMove.damage * collision.firstHitbox.damageMultiplier * this.chargeScale(firstMove, firstAction.chargeFrames);
      const secondDamage = secondMove.damage * collision.secondHitbox.damageMultiplier * this.chargeScale(secondMove, secondAction.chargeFrames);
      const reboundDamage = Math.max(firstDamage, secondDamage);
      const reboundFrames = meleeClankReboundFrames(reboundDamage);
      const outcome = meleeClankOutcome(firstDamage, secondDamage);
      if (outcome === "both") {
        this.cancelAttackForClank(first, reboundFrames);
        this.cancelAttackForClank(second, reboundFrames);
      } else if (outcome === "first") {
        this.cancelAttackForClank(first, reboundFrames);
      } else {
        this.cancelAttackForClank(second, reboundFrames);
      }
      this.emit({
        type: "clank",
        position: {
          x: (collision.firstHitbox.position.x + collision.secondHitbox.position.x) / 2,
          y: (collision.firstHitbox.position.y + collision.secondHitbox.position.y) / 2
        },
        value: reboundDamage,
        sound: "clank"
      });
    }
    resolveMeleeHits(inputs) {
      this.resolveAttackClank();
      const activeActions = [this.fighters[0].action, this.fighters[1].action];
      for (const attacker of this.fighters) {
        const action = activeActions[attacker.slot];
        if (!action || action.charging) continue;
        const move2 = attacker.definition.attacks[action.name];
        if (move2.projectile && !move2.alsoMelee || move2.counters || move2.damage <= 0 && (move2.absorbsProjectiles || move2.reflectsProjectiles)) continue;
        const firstActiveFrame = move2.startup;
        const lastActiveFrame = move2.startup + move2.active - 1;
        if (action.frame < firstActiveFrame || action.frame > lastActiveFrame) continue;
        const target = this.fighters[slotOther(attacker.slot)];
        const effectiveMove = move2;
        const maximumHits = Math.max(1, effectiveMove.multiHit ?? 1);
        const landedHits = action.hitCounts.get(target.slot) ?? 0;
        const lastHitFrame = action.lastHitFrame.get(target.slot);
        const rehitFrames = maximumHits > 1 ? Math.max(1, Math.floor((move2.active - 1) / (maximumHits - 1))) : move2.active;
        if (landedHits >= maximumHits || maximumHits === 1 && action.hitTargets.has(target.slot) || lastHitFrame !== void 0 && action.frame - lastHitFrame < rehitFrames || target.state === "ko" || target.state === "grabbed" || target.invulnerableFrames > 0) {
          continue;
        }
        if (effectiveMove.requiresFacingTarget && target.facing !== (target.position.x < attacker.position.x ? 1 : -1)) continue;
        const hitbox = this.activeWorldHitboxes(attacker, action, effectiveMove).filter((candidate) => circleIntersectsFighter(target, candidate.position, candidate.radius)).sort((left, right) => right.priority - left.priority)[0];
        if (!hitbox) continue;
        action.hitTargets.add(target.slot);
        action.hitCounts.set(target.slot, landedHits + 1);
        action.lastHitFrame.set(target.slot, action.frame);
        const chargeScale = this.chargeScale(move2, action.chargeFrames);
        const isFinisher = landedHits + 1 >= maximumHits;
        const damageScale = chargeScale / maximumHits * (maximumHits > 1 ? 1 : hitbox.damageMultiplier);
        const launchScale = maximumHits > 1 && !isFinisher ? chargeScale * 0.16 : chargeScale * (maximumHits > 1 ? 1 : hitbox.knockbackMultiplier);
        this.resolveAttackHit(
          attacker,
          target,
          effectiveMove,
          action.name,
          inputs[target.slot],
          damageScale,
          "melee",
          launchScale,
          maximumHits > 1 && !isFinisher,
          !move2.commandGrab
        );
      }
    }
    chargeScale(move2, chargeFrames) {
      if (!move2.chargeable) return 1;
      return 1 + clamp(chargeFrames / (move2.maxChargeFrames ?? 1), 0, 1) * 0.5;
    }
    refreshRecoveryAfterAirHit(target) {
      if (target.grounded) return;
      target.jumpsRemaining = Math.max(target.jumpsRemaining, 1);
      target.airUpSpecialUsed = false;
    }
    resolveAttackHit(attacker, target, move2, moveName, targetInput, damageScale = 1, source = "melee", launchScale = damageScale, intermediateMultiHit = false, canBeCountered = true, launchFacing = attacker.facing) {
      if (canBeCountered) {
        const counterAction = target.action;
        const counterMove = counterAction ? target.definition.attacks[counterAction.name] : null;
        const counterActive = Boolean(
          counterAction && counterMove?.counters && !counterAction.hitTargets.has(attacker.slot) && defensiveMoveActiveAtFrame(counterAction.frame, counterMove)
        );
        if (counterActive && counterAction && counterMove) {
          counterAction.hitTargets.add(attacker.slot);
          target.invulnerableFrames = Math.max(
            target.invulnerableFrames,
            counterMove.active + counterMove.recovery
          );
          const incomingDamage = move2.damage * damageScale;
          const counterScale = Math.max(
            1,
            incomingDamage * 1.2 / Math.max(1, counterMove.damage)
          );
          this.resolveAttackHit(
            target,
            attacker,
            counterMove,
            counterAction.name,
            EMPTY_INPUT,
            counterScale,
            "melee",
            counterScale,
            false,
            false
          );
          return;
        }
      }
      if (!move2.commandGrab && target.state === "shield" && target.shield > 0) {
        const shieldDamage = move2.shieldDamage * damageScale * attacker.damageMultiplier;
        target.shield = Math.max(0, target.shield - shieldDamage);
        target.shieldStunFrames = Math.max(target.shieldStunFrames, Math.round(4 + shieldDamage * 0.7));
        target.velocity.x += attacker.facing * Math.min(190, 35 + shieldDamage * 6);
        attacker.hitstopFrames = Math.max(attacker.hitstopFrames, Math.ceil(move2.hitstop * 0.7));
        target.hitstopFrames = Math.max(target.hitstopFrames, Math.ceil(move2.hitstop * 0.7));
        this.emit({
          type: "shield-hit",
          slot: attacker.slot,
          target: target.slot,
          move: moveName,
          position: cloneVec(target.position),
          value: shieldDamage,
          source,
          sound: "shield-hit"
        });
        if (target.shield <= 0) this.breakShield(target);
        return;
      }
      if (move2.statusEffect && target.statusEffect === null && target.statusResistanceFrames === 0 && (move2.statusEffect !== "bury" || target.grounded)) {
        this.refreshRecoveryAfterAirHit(target);
        const continuingSequence2 = target.hitstunFrames > 0 && target.lastHitBy === attacker.slot && target.lastHitMove === moveName;
        target.velocity = { x: 0, y: 0 };
        this.clearLaunchVelocity(target);
        target.launchBaseAngle = null;
        target.pendingHitstopDi = null;
        target.hitstopElapsedFrames = 0;
        target.sdiRegion = null;
        target.asdiDirection = null;
        target.techable = false;
        target.techWindowFrames = 0;
        target.action = null;
        target.state = "hitstun";
        target.hitstunFrames = Math.max(target.hitstunFrames, move2.statusFrames ?? 60);
        target.statusEffect = move2.statusEffect;
        target.lastHitBy = attacker.slot;
        target.lastHitMove = moveName;
        target.consecutiveHitMoveCount = continuingSequence2 ? target.consecutiveHitMoveCount + 1 : 1;
        target.lastHitFrames = 600;
        const damage2 = move2.damage * damageScale * attacker.damageMultiplier;
        target.percent = Math.max(0, target.percent + damage2 * target.defenseMultiplier);
        attacker.hitstopFrames = Math.max(attacker.hitstopFrames, move2.hitstop);
        target.hitstopFrames = Math.max(target.hitstopFrames, move2.hitstop + 1);
        this.emit({
          type: "hit",
          slot: attacker.slot,
          target: target.slot,
          move: moveName,
          position: cloneVec(target.position),
          value: damage2,
          damage: damage2,
          source,
          velocity: this.fighterWorldVelocity(target),
          sound: "special"
        });
        return;
      }
      const damage = move2.damage * damageScale * attacker.damageMultiplier;
      const baseAngle = launchFacing === 1 ? move2.angle : (180 - move2.angle + 360) % 360;
      const continuingSequence = (move2.multiHit ?? 1) === 1 && target.hitstunFrames > 0 && target.lastHitBy === attacker.slot && target.lastHitMove === moveName;
      const nextConsecutiveCount = continuingSequence ? target.consecutiveHitMoveCount + 1 : 1;
      const repeatedLock = continuingSequence && nextConsecutiveCount >= SAME_MOVE_LOCK_BREAK_HIT;
      const starterBaseScale = comboStarterBaseKnockbackScale(moveName, target.percent);
      const repeatedLaunchScale = repeatedLock ? SAME_MOVE_LOCK_BREAK_LAUNCH_MULTIPLIER : 1;
      this.applyLaunch(
        target,
        attacker,
        damage,
        baseAngle,
        move2.baseKnockback * starterBaseScale * launchScale * repeatedLaunchScale,
        move2.knockbackGrowth * launchScale * repeatedLaunchScale,
        move2.hitstun * (intermediateMultiHit ? 0.22 : repeatedLock ? 0.45 : 1),
        targetInput,
        intermediateMultiHit ? 8 : 0,
        intermediateMultiHit ? 3 : 7
      );
      if (intermediateMultiHit && moveName.endsWith("special") && attacker.definition.attacks[moveName].specialMovement) {
        const carrySpeed = Math.hypot(attacker.velocity.x, attacker.velocity.y);
        const carryScale = carrySpeed > 0 ? Math.min(0.92, 220 / carrySpeed) : 0;
        target.velocity = {
          x: attacker.velocity.x * carryScale,
          y: attacker.velocity.y * carryScale
        };
        this.clearLaunchVelocity(target);
        target.position = {
          x: attacker.position.x + move2.offset.x * attacker.facing * 0.28,
          y: attacker.position.y + move2.offset.y * 0.28
        };
        target.previousPosition = cloneVec(target.position);
      }
      target.lastHitMove = moveName;
      target.consecutiveHitMoveCount = nextConsecutiveCount;
      const hitstop = intermediateMultiHit ? Math.max(1, Math.round(move2.hitstop * 0.4)) : move2.hitstop;
      attacker.hitstopFrames = Math.max(attacker.hitstopFrames, hitstop);
      target.hitstopFrames = Math.max(
        target.hitstopFrames,
        intermediateMultiHit ? hitstop : hitstop + 1
      );
      if (move2.reversesFacing) {
        target.facing = target.facing === 1 ? -1 : 1;
      }
      this.emit({
        type: "hit",
        slot: attacker.slot,
        target: target.slot,
        move: moveName,
        position: cloneVec(target.position),
        value: damage,
        damage,
        source,
        velocity: this.fighterWorldVelocity(target),
        sound: !intermediateMultiHit && move2.damage >= 15 ? "hit-heavy" : !intermediateMultiHit && move2.damage >= 8 ? "hit-medium" : "hit-light"
      });
    }
    directionalInfluenceAngle(baseAngle, direction) {
      if (Math.hypot(direction.x, direction.y) <= 0.25) return baseAngle;
      const desired = Math.atan2(direction.y, direction.x) * 180 / Math.PI;
      const signedDifference = (desired - baseAngle + 540) % 360 - 180;
      return baseAngle + clamp(signedDifference, -18, 18);
    }
    /** Move during hitlag without applying gravity or allowing a capsule through stage geometry. */
    applyHitstopDisplacement(fighter, direction, distance) {
      const magnitude = Math.hypot(direction.x, direction.y);
      if (magnitude < 0.5 || distance <= 0) return;
      fighter.previousPosition = cloneVec(fighter.position);
      fighter.position = {
        x: fighter.position.x + direction.x / magnitude * distance,
        y: fighter.position.y + direction.y / magnitude * distance
      };
      this.resolveGroundVolumeCollision(fighter, /* @__PURE__ */ new Set(), EMPTY_INPUT, false);
      if (fighter.position.y >= fighter.previousPosition.y) return;
      const halfHeight = fighter.definition.size.height / 2;
      const previousBottom = fighter.previousPosition.y - halfHeight;
      const currentBottom = fighter.position.y - halfHeight;
      let highestTop = Number.NEGATIVE_INFINITY;
      for (const platform of this.stage.platforms) {
        const previousTop = platformTop(platform, fighter.previousPosition.x);
        const top = platformTop(platform, fighter.position.x);
        const overlaps = fighter.position.x + fighter.definition.size.width * 0.26 >= platformLeft(platform) && fighter.position.x - fighter.definition.size.width * 0.26 <= platformRight(platform);
        if (overlaps && previousBottom >= previousTop - 0.01 && currentBottom <= top && top > highestTop) {
          highestTop = top;
        }
      }
      if (highestTop !== Number.NEGATIVE_INFINITY) {
        fighter.position.y = highestTop + halfHeight;
      }
    }
    finishHitstopDi(fighter) {
      if (fighter.launchBaseAngle === null) {
        fighter.hitstopElapsedFrames = 0;
        fighter.sdiRegion = null;
        fighter.asdiDirection = null;
        return;
      }
      if (fighter.asdiDirection) {
        this.applyHitstopDisplacement(fighter, fighter.asdiDirection, ASDI_DISTANCE);
      }
      if (fighter.pendingHitstopDi) {
        const speed = Math.hypot(fighter.launchVelocity.x, fighter.launchVelocity.y);
        const angle = this.directionalInfluenceAngle(
          fighter.launchBaseAngle,
          fighter.pendingHitstopDi
        );
        const radians = angle * Math.PI / 180;
        fighter.launchVelocity = {
          x: Math.cos(radians) * speed,
          y: Math.sin(radians) * speed
        };
      }
      fighter.launchBaseAngle = null;
      fighter.pendingHitstopDi = null;
      fighter.hitstopElapsedFrames = 0;
      fighter.sdiRegion = null;
      fighter.asdiDirection = null;
    }
    applyLaunch(target, attacker, damage, angleDegrees, baseKnockback, growth, _baseHitstun, targetInput, minimumKnockback = 0, minimumHitstun = 7) {
      this.refreshRecoveryAfterAirHit(target);
      this.releaseGrabRelations(target);
      if (target.statusEffect) {
        target.statusResistanceFrames = Math.max(
          target.statusResistanceFrames,
          target.statusEffect === "bury" ? 90 : 45
        );
        target.statusEffect = null;
      }
      const effectiveDamage = damage * target.defenseMultiplier;
      target.percent = Math.max(0, target.percent + effectiveDamage);
      const knockback = Math.max(
        minimumKnockback,
        calculateMeleeKnockback({
          postHitPercent: target.percent,
          damage: effectiveDamage,
          weight: target.definition.weight,
          baseKnockback,
          knockbackGrowth: growth,
          ratio: target.defenseMultiplier
        })
      );
      const di = normalizedDirection(targetInput);
      target.launchBaseAngle = angleDegrees;
      target.pendingHitstopDi = Math.hypot(di.x, di.y) > 0.25 ? cloneVec(di) : null;
      target.hitstopElapsedFrames = 0;
      target.sdiRegion = sdiRegionForDirection(di);
      target.asdiDirection = sdiRegionForDirection(di) === null ? null : cloneVec(di);
      const angle = this.directionalInfluenceAngle(angleDegrees, di);
      target.velocity = { x: 0, y: 0 };
      target.launchVelocity = meleeLaunchVelocity(knockback, angle);
      target.grounded = false;
      target.supportPlatform = null;
      target.fastFalling = false;
      target.shortHopReleaseFrames = 0;
      target.action = null;
      target.grabFrames = 0;
      target.landingLagFrames = 0;
      target.wavedashFrames = 0;
      target.state = "hitstun";
      target.techable = knockback >= MELEE_TUMBLE_KNOCKBACK_THRESHOLD;
      target.hitstunFrames = Math.max(
        minimumHitstun,
        meleeHitstunFrames(knockback)
      );
      target.lastHitBy = attacker.slot;
      target.lastHitFrames = 600;
    }
    spawnProjectile(fighter, moveName, attack) {
      const definition = attack.projectile;
      if (!definition) return;
      if (definition.manualDetonation) {
        const existing = this.projectiles.find(
          (projectile2) => projectile2.owner === fighter.slot && projectile2.move === moveName && projectile2.definition.manualDetonation
        );
        if (existing) {
          existing.detonating = true;
          existing.remainingFrames = Math.max(1, existing.remainingFrames);
          existing.velocity = { x: 0, y: 0 };
          this.emit({
            type: "attack-active",
            slot: fighter.slot,
            move: moveName,
            position: cloneVec(existing.position)
          });
          return;
        }
      }
      const action = fighter.action;
      const chargeProgress = action && attack.chargeable ? clamp(action.chargeFrames / (attack.maxChargeFrames ?? 1), 0, 1) : 0;
      const storedChargeScaling = definition.storedChargeScaling;
      const scale = storedChargeScaling ? storedChargeScaling.minimumDamage / Math.max(1, attack.damage) + (1 - storedChargeScaling.minimumDamage / Math.max(1, attack.damage)) * chargeProgress : action ? this.chargeScale(attack, action.chargeFrames) : 1;
      const chargedSpeedScale = attack.chargeable ? 0.55 + chargeProgress * 0.45 : 1;
      const projectileRadius = storedChargeScaling ? storedChargeScaling.minimumRadius + (definition.radius - storedChargeScaling.minimumRadius) * chargeProgress : definition.radius;
      const vertical = Boolean(definition.vertical);
      const position = vertical ? { x: fighter.position.x, y: fighter.position.y + 320 } : {
        x: fighter.position.x + fighter.facing * (fighter.definition.size.width * 0.55 + projectileRadius),
        y: definition.restsOnGround ? fighter.position.y - fighter.definition.size.height / 2 + projectileRadius + 2 : fighter.position.y + attack.offset.y
      };
      const velocity = vertical ? { x: 0, y: -definition.speed } : {
        x: definition.speed * chargedSpeedScale * fighter.facing,
        y: definition.launchVelocityY ?? (definition.kind === "bomb" ? 210 : 0)
      };
      const projectile = {
        id: this.nextEntityId,
        owner: fighter.slot,
        kind: definition.kind,
        position,
        velocity,
        radius: projectileRadius,
        remainingFrames: effectiveProjectileLifetime(definition),
        rotation: 0,
        definition,
        move: moveName,
        attack,
        age: 0,
        bouncesRemaining: definition.bounces ?? 0,
        hitTargets: /* @__PURE__ */ new Set(),
        hitCounts: /* @__PURE__ */ new Map(),
        lastHitFrame: /* @__PURE__ */ new Map(),
        returning: false,
        powerScale: scale,
        detonating: false
      };
      this.nextEntityId += 1;
      this.projectiles.push(projectile);
      this.emit({
        type: "projectile",
        slot: fighter.slot,
        move: moveName,
        position: cloneVec(position),
        projectileKind: definition.kind,
        entityId: projectile.id,
        sound: `projectile-${definition.kind}`
      });
    }
    projectileLaunchFacing(projectile, target) {
      if (Math.abs(projectile.velocity.x) > 1) return projectile.velocity.x > 0 ? 1 : -1;
      const impactOffset = target.position.x - projectile.position.x;
      if (Math.abs(impactOffset) > 1) return impactOffset > 0 ? 1 : -1;
      const owner = this.fighters[projectile.owner];
      return owner.position.x <= target.position.x ? 1 : -1;
    }
    reflectProjectile(projectile, reflector, speedScale, powerScale = 1) {
      projectile.owner = reflector.slot;
      projectile.velocity = {
        x: -projectile.velocity.x * speedScale,
        y: -projectile.velocity.y * speedScale
      };
      if (Math.hypot(projectile.velocity.x, projectile.velocity.y) < 1) {
        projectile.velocity.x = reflector.facing * projectile.definition.speed * speedScale;
      }
      projectile.powerScale *= powerScale;
      projectile.age = 0;
      projectile.remainingFrames = effectiveProjectileLifetime(projectile.definition);
      projectile.returning = false;
      projectile.detonating = false;
      projectile.bouncesRemaining = projectile.definition.bounces ?? 0;
      projectile.hitTargets.clear();
      projectile.hitCounts.clear();
      projectile.lastHitFrame.clear();
      const magnitude = Math.max(1, Math.hypot(projectile.velocity.x, projectile.velocity.y));
      projectile.position.x += projectile.velocity.x / magnitude * 28;
      projectile.position.y += projectile.velocity.y / magnitude * 12;
    }
    updateProjectiles(inputs) {
      const survivors = [];
      for (const projectile of this.projectiles) {
        projectile.age += 1;
        projectile.remainingFrames -= 1;
        const owner = this.fighters[projectile.owner];
        const target = this.fighters[slotOther(projectile.owner)];
        if (projectile.definition.manualDetonation && projectile.remainingFrames <= 0) projectile.detonating = true;
        if (projectile.detonating) {
          projectile.velocity = { x: 0, y: 0 };
          const explosionScale = 1 + (projectile.powerScale - 1) * 0.45;
          projectile.radius = (projectile.definition.explosionRadius ?? projectile.radius) * explosionScale;
          projectile.remainingFrames = 0;
        }
        if (projectile.definition.controlledByOwner) {
          const direction = normalizedDirection(inputs[projectile.owner]);
          const magnitude = Math.hypot(direction.x, direction.y);
          if (magnitude > 0.25) {
            projectile.velocity = {
              x: direction.x / magnitude * projectile.definition.speed,
              y: direction.y / magnitude * projectile.definition.speed
            };
          }
        }
        if (projectile.definition.returns && projectile.age > projectile.definition.lifetimeFrames * 0.48) {
          if (!projectile.returning) {
            projectile.returning = true;
            projectile.hitTargets.clear();
            projectile.hitCounts.clear();
            projectile.lastHitFrame.clear();
          }
          const dx = owner.position.x - projectile.position.x;
          const dy = owner.position.y - projectile.position.y;
          const length = Math.max(1, Math.hypot(dx, dy));
          const desiredVelocity = {
            x: dx / length * projectile.definition.speed,
            y: dy / length * projectile.definition.speed
          };
          projectile.velocity.x = approach(
            projectile.velocity.x,
            desiredVelocity.x,
            PROJECTILE_RETURN_TURN_RATE
          );
          projectile.velocity.y = approach(
            projectile.velocity.y,
            desiredVelocity.y,
            PROJECTILE_RETURN_TURN_RATE
          );
          const returnSpeed = Math.hypot(projectile.velocity.x, projectile.velocity.y);
          if (returnSpeed > projectile.definition.speed) {
            projectile.velocity.x = projectile.velocity.x / returnSpeed * projectile.definition.speed;
            projectile.velocity.y = projectile.velocity.y / returnSpeed * projectile.definition.speed;
          }
          if (length < owner.definition.size.width * 0.6) continue;
        }
        if (projectile.definition.homing && target.state !== "ko") {
          const desired = Math.atan2(
            target.position.y - projectile.position.y,
            target.position.x - projectile.position.x
          );
          const speed = projectile.definition.speed;
          const turnRate = projectile.definition.homing ?? 8;
          projectile.velocity.x = approach(projectile.velocity.x, Math.cos(desired) * speed, turnRate);
          projectile.velocity.y = approach(projectile.velocity.y, Math.sin(desired) * speed, turnRate);
        }
        projectile.velocity.y -= projectile.definition.gravity * FIXED_DT;
        const previousX = projectile.position.x;
        const previousY = projectile.position.y;
        projectile.position.x += projectile.velocity.x * FIXED_DT;
        projectile.position.y += projectile.velocity.y * FIXED_DT;
        projectile.rotation = Math.atan2(projectile.velocity.y, projectile.velocity.x);
        if (projectile.definition.ownerDischargeRadius && distanceSquared(projectile.position, owner.position) <= (projectile.radius + Math.min(owner.definition.size.width, owner.definition.size.height) * 0.45) ** 2) {
          projectile.position = cloneVec(owner.position);
          projectile.radius = projectile.definition.ownerDischargeRadius;
          projectile.velocity = { x: 0, y: 0 };
          projectile.remainingFrames = 0;
          this.emit({
            type: "attack-active",
            slot: owner.slot,
            move: projectile.move,
            position: cloneVec(owner.position)
          });
        }
        const ownerLaunch = projectile.definition.ownerLaunchOnContact;
        if (ownerLaunch && projectile.age >= ownerLaunch.minimumAgeFrames && distanceSquared(projectile.position, owner.position) <= (projectile.radius + Math.min(owner.definition.size.width, owner.definition.size.height) * 0.42) ** 2) {
          const magnitude = Math.max(1, Math.hypot(projectile.velocity.x, projectile.velocity.y));
          owner.velocity = {
            x: projectile.velocity.x / magnitude * ownerLaunch.speed,
            y: projectile.velocity.y / magnitude * ownerLaunch.speed
          };
          owner.grounded = false;
          owner.supportPlatform = null;
          owner.fastFalling = false;
          if (owner.action?.name === projectile.move) owner.action.specialPhase = "active";
          this.emit({
            type: "attack-active",
            slot: owner.slot,
            move: projectile.move,
            position: cloneVec(owner.position)
          });
          continue;
        }
        const groundVolumeCollision = findGroundVolumeCollision(
          this.stage.platforms,
          { x: previousX, y: previousY },
          projectile.position,
          projectile.radius,
          projectile.radius
        );
        if (groundVolumeCollision) {
          if (groundVolumeCollision.face === "bottom") {
            projectile.position.y = platformBottom(groundVolumeCollision.platform, projectile.position.x) - projectile.radius - 0.01;
            if (projectile.bouncesRemaining > 0) {
              projectile.velocity.y = -Math.abs(projectile.velocity.y) * 0.68;
              projectile.bouncesRemaining -= 1;
            } else {
              projectile.remainingFrames = 0;
            }
          } else {
            const edgeX = groundVolumeCollision.face === "left" ? platformLeft(groundVolumeCollision.platform) : platformRight(groundVolumeCollision.platform);
            projectile.position.x = edgeX + (groundVolumeCollision.face === "left" ? -projectile.radius - 0.01 : projectile.radius + 0.01);
            if (projectile.bouncesRemaining > 0) {
              projectile.velocity.x = (groundVolumeCollision.face === "left" ? -1 : 1) * Math.abs(projectile.velocity.x) * 0.68;
              projectile.bouncesRemaining -= 1;
            } else {
              projectile.remainingFrames = 0;
            }
          }
        } else if (projectile.velocity.y < 0 && projectile.bouncesRemaining >= 0) {
          for (const platform of this.stage.platforms) {
            if (platform.kind === "platform") continue;
            const previousTop = platformTop(platform, previousX);
            const top = platformTop(platform, projectile.position.x);
            const inX = projectile.position.x >= platform.position.x - platform.width / 2 && projectile.position.x <= platform.position.x + platform.width / 2;
            if (inX && previousY - projectile.radius >= previousTop && projectile.position.y - projectile.radius <= top) {
              if (projectile.bouncesRemaining > 0) {
                projectile.position.y = top + projectile.radius;
                projectile.velocity.y = Math.abs(projectile.velocity.y) * 0.68;
                projectile.bouncesRemaining -= 1;
              } else if (projectile.kind === "bomb" || projectile.definition.restsOnGround) {
                projectile.position.y = top + projectile.radius;
                projectile.velocity = { x: 0, y: 0 };
              } else {
                projectile.remainingFrames = 0;
              }
              break;
            }
          }
        }
        const maximumHits = Math.max(1, projectile.attack.multiHit ?? 1);
        const landedHits = projectile.hitCounts.get(target.slot) ?? 0;
        const lastHitFrame = projectile.lastHitFrame.get(target.slot);
        const rehitFrames = maximumHits > 1 ? Math.max(2, Math.floor(projectile.attack.active / maximumHits)) : projectile.attack.active;
        const canHit = target.state !== "ko" && target.state !== "grabbed" && target.invulnerableFrames === 0 && landedHits < maximumHits && !projectile.hitTargets.has(target.slot) && (!projectile.definition.manualDetonation || projectile.detonating) && (lastHitFrame === void 0 || projectile.age - lastHitFrame >= rehitFrames);
        if (canHit && circleIntersectsFighter(target, projectile.position, projectile.radius)) {
          const targetAction = target.action;
          const defensiveMove = targetAction ? target.definition.attacks[targetAction.name] : null;
          const defensiveMoveActive = Boolean(
            targetAction && defensiveMove && defensiveMoveActiveAtFrame(targetAction.frame, defensiveMove)
          );
          if (defensiveMoveActive && defensiveMove?.counters && targetAction) {
            targetAction.hitTargets.add(owner.slot);
            target.invulnerableFrames = Math.max(
              target.invulnerableFrames,
              defensiveMove.active + defensiveMove.recovery
            );
            const counterHitbox = {
              x: target.position.x + defensiveMove.offset.x * target.facing,
              y: target.position.y + defensiveMove.offset.y
            };
            if (circleIntersectsFighter(owner, counterHitbox, defensiveMove.radius)) {
              const counterScale = Math.max(
                1,
                projectile.attack.damage * projectile.powerScale * 1.2 / Math.max(1, defensiveMove.damage)
              );
              this.resolveAttackHit(
                target,
                owner,
                defensiveMove,
                targetAction.name,
                inputs[owner.slot],
                counterScale,
                "melee",
                counterScale,
                false,
                false
              );
            }
            continue;
          }
          if (defensiveMoveActive && defensiveMove?.absorbsProjectiles && projectile.definition.absorbable) {
            const absorbedDamage = projectile.attack.damage * projectile.powerScale;
            target.percent = Math.max(0, target.percent - absorbedDamage * 0.45);
            this.emit({
              type: "shield-hit",
              slot: target.slot,
              target: owner.slot,
              position: cloneVec(projectile.position),
              sound: "shield-hit"
            });
            continue;
          }
          if (defensiveMoveActive && defensiveMove?.reflectsProjectiles) {
            this.reflectProjectile(projectile, target, 1.18, 1.16);
            this.emit({
              type: "shield-hit",
              slot: target.slot,
              target: owner.slot,
              position: cloneVec(projectile.position),
              sound: "projectile-reflect"
            });
            survivors.push(projectile);
            continue;
          }
          if (target.projectileShieldFrames > 0) {
            this.reflectProjectile(projectile, target, 1.08);
            this.emit({ type: "shield-hit", slot: target.slot, target: owner.slot, position: cloneVec(projectile.position), sound: "projectile-reflect" });
            survivors.push(projectile);
            continue;
          }
          const hitNumber = landedHits + 1;
          const isFinisher = hitNumber >= maximumHits;
          projectile.hitCounts.set(target.slot, hitNumber);
          projectile.lastHitFrame.set(target.slot, projectile.age);
          if (isFinisher) projectile.hitTargets.add(target.slot);
          const damageScale = projectile.powerScale / maximumHits;
          const launchScale = maximumHits > 1 && !isFinisher ? projectile.powerScale * 0.16 : projectile.powerScale;
          this.resolveAttackHit(
            owner,
            target,
            projectile.attack,
            projectile.move,
            inputs[target.slot],
            damageScale,
            "projectile",
            launchScale,
            maximumHits > 1 && !isFinisher,
            true,
            this.projectileLaunchFacing(projectile, target)
          );
          if ((!isFinisher || projectile.definition.returns) && projectile.remainingFrames > 0) survivors.push(projectile);
          continue;
        }
        const inWorld = projectile.position.x > this.stage.blastZone.left - 100 && projectile.position.x < this.stage.blastZone.right + 100 && projectile.position.y > this.stage.blastZone.bottom - 100 && projectile.position.y < this.stage.blastZone.top + 100;
        if (projectile.remainingFrames > 0 && inWorld) survivors.push(projectile);
      }
      this.projectiles = survivors;
    }
    itemIntervalFrames() {
      switch (this.config.itemFrequency) {
        case "low":
          return 860;
        case "high":
          return 340;
        case "medium":
          return 560;
      }
    }
    maybeSpawnItem() {
      if (!this.config.items || this.frame < this.nextItemFrame || this.items.length >= 3) return;
      const kind = ITEM_KINDS[Math.floor(this.random.next() * ITEM_KINDS.length)] ?? "vitality-fruit";
      this.spawnItem(
        kind,
        { x: -360 + this.random.next() * 720, y: 470 },
        { x: (this.random.next() - 0.5) * 70, y: 0 }
      );
      const jitter = 0.8 + this.random.next() * 0.45;
      this.nextItemFrame = this.frame + Math.round(this.itemIntervalFrames() * jitter);
    }
    tryPickupItem(fighter) {
      if (fighter.heldItem) return false;
      const pickupRadius = Math.max(fighter.definition.size.width, fighter.definition.size.height) * 0.48;
      const index = this.items.findIndex(
        (item3) => item3.mode === "world" && !isAutomaticItem(item3.kind) && distanceSquared(item3.position, fighter.position) <= (item3.radius + pickupRadius) ** 2
      );
      if (index < 0) return false;
      const [item2] = this.items.splice(index, 1);
      if (!item2) return false;
      const definition = ITEM_DEFINITIONS[item2.kind];
      fighter.heldItem = { kind: item2.kind, charges: definition.charges };
      fighter.state = "grab";
      fighter.itemUseFrames = 8;
      fighter.itemAction = "pickup";
      this.emit({
        type: "item-pickup",
        slot: fighter.slot,
        item: item2.kind,
        position: cloneVec(fighter.position),
        sound: "item-pickup"
      });
      return true;
    }
    useHeldItem(fighter, input, targetInput) {
      const held = fighter.heldItem;
      if (!held) return;
      const definition = ITEM_DEFINITIONS[held.kind];
      const target = this.fighters[slotOther(fighter.slot)];
      fighter.itemUseFrames = definition.effect === "bat" ? 24 : 13;
      fighter.itemAction = "attack";
      fighter.state = "attack";
      const direction = normalizedDirection(input);
      switch (definition.effect) {
        case "sword":
          this.applyItemStrike(fighter, target, definition.amount, 155, 42, 0.78, targetInput, "plasma-blade");
          break;
        case "bat":
          this.applyItemStrike(fighter, target, definition.amount, 132, 86, 1.18, targetInput, "power-bat");
          break;
        case "ray": {
          this.spawnProjectile(fighter, "neutral-special", ITEM_RAY_ATTACK);
          break;
        }
        case "flame": {
          this.spawnProjectile(fighter, "neutral-special", ITEM_FLAME_ATTACK);
          break;
        }
        case "bomb":
        case "shell":
        case "slip-trap":
        case "proximity-bomb":
        case "bumper":
        case "bury":
        case "stun":
        case "smoke":
          this.releaseActivatedItem(fighter, held.kind, direction);
          break;
        default:
          break;
      }
      held.charges -= 1;
      if (held.charges <= 0) fighter.heldItem = null;
      this.emit({
        type: "item-use",
        slot: fighter.slot,
        item: held.kind,
        position: cloneVec(fighter.position),
        value: definition.amount,
        sound: `item-${definition.effect}`
      });
    }
    applyItemStrike(attacker, target, damage, reach, baseKnockback, growth, targetInput, sound) {
      const horizontal = (target.position.x - attacker.position.x) * attacker.facing;
      const vertical = Math.abs(target.position.y - attacker.position.y);
      if (horizontal < -18 || horizontal > reach || vertical > 105 || target.invulnerableFrames > 0) return;
      this.applyLaunch(target, attacker, damage, attacker.facing > 0 ? 36 : 144, baseKnockback, growth, 12, targetInput);
      this.emit({
        type: "hit",
        slot: attacker.slot,
        target: target.slot,
        position: cloneVec(target.position),
        value: damage,
        damage,
        source: "item",
        velocity: this.fighterWorldVelocity(target),
        sound
      });
    }
    releaseActivatedItem(fighter, kind, direction) {
      const definition = ITEM_DEFINITIONS[kind];
      const trap = definition.category === "trap";
      const horizontal = Math.abs(direction.x) > 0.25 ? Math.sign(direction.x) : fighter.facing;
      const item2 = {
        id: this.nextEntityId,
        kind,
        position: {
          x: fighter.position.x + horizontal * (fighter.definition.size.width * 0.5 + 28),
          y: fighter.position.y + 22
        },
        velocity: trap ? { x: horizontal * 240, y: 160 } : { x: horizontal * (definition.effect === "shell" ? 460 : 360), y: 210 },
        radius: definition.effect === "bumper" ? 34 : 24,
        mode: trap ? "trap" : "thrown",
        owner: fighter.slot,
        age: 0,
        grounded: false,
        supportPlatform: null
      };
      this.nextEntityId += 1;
      this.items.push(item2);
    }
    updateItems(inputs) {
      const survivors = [];
      for (const item2 of this.items) {
        item2.age += 1;
        const previousX = item2.position.x;
        const previousY = item2.position.y;
        if (item2.grounded) {
          const support = this.findItemSupport(item2, item2.position.x);
          if (support) {
            item2.supportPlatform = support.id;
            item2.position.y = platformTop(support, item2.position.x) + item2.radius;
            item2.velocity.y = 0;
          } else {
            item2.grounded = false;
            item2.supportPlatform = null;
          }
        }
        if (!item2.grounded) {
          item2.velocity.y = Math.max(-600, item2.velocity.y - 1250 * FIXED_DT);
        }
        item2.position.x += item2.velocity.x * FIXED_DT;
        item2.position.y += item2.velocity.y * FIXED_DT;
        if (item2.grounded) {
          const support = this.findItemSupport(item2, item2.position.x);
          if (support) {
            item2.supportPlatform = support.id;
            item2.position.y = platformTop(support, item2.position.x) + item2.radius;
          } else {
            item2.grounded = false;
            item2.supportPlatform = null;
            item2.velocity.y = Math.max(-600, item2.velocity.y - 1250 * FIXED_DT);
            item2.position.y += item2.velocity.y * FIXED_DT;
          }
        }
        let blockedByGroundVolume = false;
        const walkableGround = /* @__PURE__ */ new Set();
        if (item2.grounded) {
          const footY = item2.position.y - item2.radius;
          for (const platform of this.stage.platforms) {
            const top = platformTop(platform, item2.position.x);
            const overlaps = item2.position.x + item2.radius >= platformLeft(platform) && item2.position.x - item2.radius <= platformRight(platform);
            if (overlaps && top >= footY - 12 && top <= footY + 30) {
              walkableGround.add(platform.id);
            }
          }
        }
        const collision = findGroundVolumeCollision(
          this.stage.platforms,
          { x: previousX, y: previousY },
          item2.position,
          item2.radius,
          item2.radius,
          walkableGround
        );
        if (collision) {
          blockedByGroundVolume = true;
          if (collision.face === "bottom") {
            item2.position.y = platformBottom(collision.platform, item2.position.x) - item2.radius - 0.01;
            item2.velocity.y = Math.min(0, item2.velocity.y);
          } else {
            const edgeX = collision.face === "left" ? platformLeft(collision.platform) : platformRight(collision.platform);
            item2.position.x = edgeX + (collision.face === "left" ? -item2.radius - 0.01 : item2.radius + 0.01);
            item2.velocity.x *= -0.45;
          }
        }
        if (!item2.grounded && !blockedByGroundVolume) {
          for (const platform of this.stage.platforms) {
            const previousTop = platformTop(platform, previousX);
            const top = platformTop(platform, item2.position.x);
            const inX = platformContainsX(platform, item2.position.x);
            if (inX && previousY - item2.radius >= previousTop && item2.position.y - item2.radius <= top) {
              item2.position.y = top + item2.radius;
              if (item2.mode === "trap") {
                item2.velocity = { x: 0, y: 0 };
                item2.grounded = true;
                item2.supportPlatform = platform.id;
              } else if (item2.kind === "ricochet-disc" && item2.mode === "thrown") {
                item2.velocity.y = 0;
                item2.grounded = true;
                item2.supportPlatform = platform.id;
              } else {
                const rebound = Math.abs(item2.velocity.y) * 0.28;
                item2.velocity.x *= 0.82;
                if (rebound < 28) {
                  item2.velocity.y = 0;
                  item2.grounded = true;
                  item2.supportPlatform = platform.id;
                } else {
                  item2.velocity.y = rebound;
                  item2.supportPlatform = null;
                }
              }
              break;
            }
          }
        }
        if (item2.mode === "world" && isAutomaticItem(item2.kind)) {
          let collector = null;
          for (const fighter of this.fighters) {
            if (fighter.state === "ko" || fighter.state === "grabbed") continue;
            const pickupRadius = Math.max(fighter.definition.size.width, fighter.definition.size.height) * 0.38;
            if (distanceSquared(item2.position, fighter.position) <= (item2.radius + pickupRadius) ** 2) {
              collector = fighter;
              break;
            }
          }
          if (collector) {
            this.applyAutomaticItem(collector, item2);
            continue;
          }
        }
        if (item2.mode !== "world" && item2.owner !== null) {
          const target = this.fighters[slotOther(item2.owner)];
          const hitsTarget = item2.kind === "proximity-mine" ? distanceSquared(item2.position, target.position) <= 95 ** 2 : circleIntersectsFighter(target, item2.position, item2.radius);
          if (target.state !== "ko" && target.invulnerableFrames === 0 && hitsTarget) {
            const consumed = this.applyActivatedItem(item2, target, inputs[target.slot]);
            if (consumed) continue;
          }
        }
        const lifetime = ITEM_DEFINITIONS[item2.kind].duration || 1800;
        if (item2.position.y > this.stage.blastZone.bottom && item2.age < lifetime) survivors.push(item2);
      }
      this.items = survivors;
    }
    findItemSupport(item2, worldX) {
      const footY = item2.position.y - item2.radius;
      return this.stage.platforms.filter(
        (platform) => platformContainsX(platform, worldX) && platformTop(platform, worldX) >= footY - 12 && platformTop(platform, worldX) <= footY + 30
      ).sort(
        (a, b) => platformTop(b, worldX) - platformTop(a, worldX)
      )[0] ?? null;
    }
    applyAutomaticItem(collector, item2) {
      const definition = ITEM_DEFINITIONS[item2.kind];
      const target = this.fighters[slotOther(collector.slot)];
      switch (definition.effect) {
        case "heal-small":
        case "heal-large":
          collector.percent = Math.max(0, collector.percent - definition.amount);
          break;
        case "power-up":
          collector.damageMultiplier = definition.amount;
          collector.damageBuffFrames = definition.duration;
          break;
        case "speed-up":
          collector.speedMultiplier = definition.amount;
          collector.speedBuffFrames = definition.duration;
          collector.jumpMultiplier = 1.25;
          collector.jumpBuffFrames = definition.duration;
          break;
        case "armor":
          collector.defenseMultiplier = definition.amount;
          collector.defenseBuffFrames = definition.duration;
          break;
        case "invincibility":
          collector.invulnerableFrames = Math.max(collector.invulnerableFrames, definition.duration);
          break;
        case "projectile-shield":
          collector.projectileShieldFrames = definition.duration;
          break;
        case "slow-time":
          target.speedMultiplier = definition.amount;
          target.speedBuffFrames = definition.duration;
          break;
        default:
          return;
      }
      this.emit({
        type: "item-use",
        slot: collector.slot,
        item: item2.kind,
        position: cloneVec(item2.position),
        value: definition.amount,
        sound: `item-${definition.effect}`
      });
    }
    applyActivatedItem(item2, target, targetInput) {
      const definition = ITEM_DEFINITIONS[item2.kind];
      const attacker = this.fighters[item2.owner ?? 0];
      const direction = target.position.x >= item2.position.x ? 1 : -1;
      this.releaseGrabRelations(target);
      switch (definition.effect) {
        case "bomb":
        case "proximity-bomb":
          this.applyLaunch(target, attacker, definition.amount, direction > 0 ? 48 : 132, 70, 1.02, 17, targetInput);
          break;
        case "shell":
          this.applyLaunch(target, attacker, definition.amount, direction > 0 ? 32 : 148, 54, 0.86, 13, targetInput);
          break;
        case "slip-trap":
          this.applyLaunch(target, attacker, definition.amount, direction > 0 ? 18 : 162, 24, 0.35, 24, targetInput);
          target.hitstunFrames = Math.max(target.hitstunFrames, 50);
          break;
        case "bumper":
          this.applyLaunch(target, attacker, definition.amount, direction > 0 ? 24 : 156, 72, 1.08, 18, targetInput);
          this.emit({
            type: "hit",
            slot: attacker.slot,
            target: target.slot,
            item: item2.kind,
            position: cloneVec(target.position),
            value: definition.amount,
            damage: definition.amount,
            source: "item",
            velocity: this.fighterWorldVelocity(target),
            sound: "item-bumper"
          });
          item2.owner = target.slot;
          return false;
        case "bury":
          this.refreshRecoveryAfterAirHit(target);
          target.percent += definition.amount * target.defenseMultiplier;
          target.velocity = { x: 0, y: 0 };
          this.clearLaunchVelocity(target);
          target.state = "hitstun";
          target.techable = false;
          target.techWindowFrames = 0;
          target.hitstunFrames = Math.max(target.hitstunFrames, 95);
          target.lastHitBy = attacker.slot;
          target.lastHitFrames = 600;
          break;
        case "stun":
          this.refreshRecoveryAfterAirHit(target);
          target.percent += definition.amount * target.defenseMultiplier;
          target.velocity = { x: 0, y: 0 };
          this.clearLaunchVelocity(target);
          target.state = "hitstun";
          target.techable = false;
          target.techWindowFrames = 0;
          target.hitstunFrames = Math.max(target.hitstunFrames, 105);
          target.lastHitBy = attacker.slot;
          target.lastHitFrames = 600;
          break;
        case "smoke":
          target.speedMultiplier = definition.amount;
          target.speedBuffFrames = definition.duration;
          break;
        default:
          return false;
      }
      this.emit({
        type: "hit",
        slot: attacker.slot,
        target: target.slot,
        item: item2.kind,
        position: cloneVec(target.position),
        value: definition.amount,
        damage: definition.amount,
        source: "item",
        velocity: this.fighterWorldVelocity(target),
        sound: `item-${definition.effect}`
      });
      return true;
    }
    resolveKnockouts() {
      const knockedOut = [];
      for (const fighter of this.fighters) {
        if (fighter.state === "ko" || fighter.stocks <= 0) continue;
        const outside = fighter.position.x < this.stage.blastZone.left || fighter.position.x > this.stage.blastZone.right || fighter.position.y < this.stage.blastZone.bottom || fighter.position.y > this.stage.blastZone.top;
        if (outside) knockedOut.push(fighter);
      }
      if (knockedOut.length === 0) return;
      for (const fighter of knockedOut) {
        const koVelocity = this.fighterWorldVelocity(fighter);
        this.releaseGrabRelations(fighter);
        fighter.stocks = Math.max(0, fighter.stocks - 1);
        if (fighter.lastHitBy !== null && fighter.lastHitBy !== fighter.slot) {
          this.kos[fighter.lastHitBy] += 1;
        }
        fighter.state = "ko";
        fighter.respawnFrames = 90;
        fighter.velocity = { x: 0, y: 0 };
        this.clearLaunchVelocity(fighter);
        fighter.action = null;
        fighter.hitstopFrames = 0;
        fighter.hitstopElapsedFrames = 0;
        fighter.hitstunFrames = 0;
        fighter.launchBaseAngle = null;
        fighter.pendingHitstopDi = null;
        fighter.sdiRegion = null;
        fighter.asdiDirection = null;
        fighter.techWindowFrames = 0;
        fighter.techable = false;
        fighter.ledge = null;
        this.dropHeldItem(fighter);
        this.emit({
          type: "ko",
          slot: fighter.slot,
          target: fighter.lastHitBy ?? void 0,
          position: cloneVec(fighter.position),
          value: fighter.stocks,
          velocity: koVelocity,
          sound: fighter.stocks === 0 ? "final-ko" : "ko"
        });
      }
      const firstOut = this.fighters[0].stocks <= 0;
      const secondOut = this.fighters[1].stocks <= 0;
      if (!firstOut && !secondOut) return;
      let winner;
      if (firstOut && !secondOut) winner = 1;
      else if (!firstOut && secondOut) winner = 0;
      else if (this.fighters[0].percent !== this.fighters[1].percent) {
        winner = this.fighters[0].percent < this.fighters[1].percent ? 0 : 1;
      } else {
        winner = this.kos[0] >= this.kos[1] ? 0 : 1;
      }
      this.finishMatch(winner);
    }
    playingFrames() {
      return Math.max(0, this.frame - this.options.countdownFrames);
    }
    resolveTimeLimit() {
      if (this.timeLimitFrames === null || this.suddenDeath || this.playingFrames() < this.timeLimitFrames) return;
      const firstStocks = this.fighters[0].stocks;
      const secondStocks = this.fighters[1].stocks;
      if (firstStocks !== secondStocks) {
        this.finishMatch(firstStocks > secondStocks ? 0 : 1);
        return;
      }
      this.startSuddenDeath();
    }
    startSuddenDeath() {
      this.suddenDeath = true;
      this.projectiles = [];
      this.items = [];
      const stageDefinition = getStageDefinition(this.config.stage);
      this.fighters = [
        this.createFighter(0, stageDefinition.spawns[0], true),
        this.createFighter(1, stageDefinition.spawns[1], true)
      ];
      for (const fighter of this.fighters) {
        fighter.stocks = 1;
        fighter.percent = 999;
      }
      this.emit({ type: "sudden-death", value: 999 });
    }
    releaseGrabRelations(fighter) {
      if (fighter.grabTarget !== null) {
        const target = this.fighters[fighter.grabTarget];
        target.grabbedBy = null;
        target.state = "fall";
        fighter.grabTarget = null;
      }
      if (fighter.grabbedBy !== null) {
        const grabber = this.fighters[fighter.grabbedBy];
        grabber.grabTarget = null;
        grabber.grabFrames = 14;
        fighter.grabbedBy = null;
      }
    }
    dropHeldItem(fighter) {
      const held = fighter.heldItem;
      if (!held) return;
      const item2 = {
        id: this.nextEntityId,
        kind: held.kind,
        position: cloneVec(fighter.position),
        velocity: { x: -fighter.facing * 110, y: 190 },
        radius: 24,
        mode: "world",
        owner: null,
        age: 0,
        grounded: false,
        supportPlatform: null
      };
      this.nextEntityId += 1;
      this.items.push(item2);
      fighter.heldItem = null;
    }
    finishMatch(winner) {
      this.phase = "finished";
      this.winner = winner;
      this.fighters[winner].state = "victory";
      this.result = {
        winner,
        durationMs: Math.max(0, (this.frame - this.options.countdownFrames) * FIXED_DT_MS),
        kos: [...this.kos]
      };
      this.emit({
        type: "match-end",
        slot: winner,
        winner,
        position: cloneVec(this.fighters[winner].position),
        sound: "victory"
      });
    }
    snapshotFighter(fighter) {
      const action = fighter.action;
      const move2 = action ? fighter.definition.attacks[action.name] : null;
      return {
        slot: fighter.slot,
        fighter: fighter.fighter,
        skin: fighter.skin,
        name: fighter.name,
        position: cloneVec(fighter.position),
        velocity: this.fighterWorldVelocity(fighter),
        facing: fighter.facing,
        percent: fighter.percent,
        stocks: fighter.stocks,
        state: fighter.state,
        grounded: fighter.grounded,
        fastFalling: fighter.fastFalling,
        jumpsRemaining: fighter.jumpsRemaining,
        shield: fighter.shield,
        maxShield: fighter.definition.shieldHealth,
        invulnerableFrames: fighter.invulnerableFrames,
        currentMove: action?.name ?? null,
        moveFrame: action?.frame ?? 0,
        specialPhase: action?.specialPhase ?? null,
        visualRotation: specialVisualRotation(fighter),
        hitstunFrames: fighter.hitstunFrames,
        statusEffect: fighter.statusEffect,
        respawnFrames: fighter.respawnFrames,
        charge: action && move2?.chargeable ? clamp(action.chargeFrames / (move2.maxChargeFrames ?? 1), 0, 1) : 0,
        grabTarget: fighter.grabTarget,
        grabbedBy: fighter.grabbedBy,
        grabFrames: fighter.grabFrames,
        dodgeKind: fighter.dodgeKind,
        throwAnimation: fighter.throwAnimation,
        ledge: fighter.ledge,
        size: { ...fighter.definition.size },
        heldItem: fighter.heldItem ? { ...fighter.heldItem } : null,
        itemAction: fighter.itemAction,
        activeEffects: {
          damageMultiplier: fighter.damageMultiplier,
          speedMultiplier: fighter.speedMultiplier,
          jumpMultiplier: fighter.jumpMultiplier,
          defenseMultiplier: fighter.defenseMultiplier,
          projectileShieldFrames: fighter.projectileShieldFrames
        }
      };
    }
    emit(event) {
      this.events.push({ ...event, frame: this.frame });
    }
  };

  // Engine/vendor/ai.ts
  var AI_DIFFICULTIES = {
    1: {
      reactionFrames: [18, 30],
      mistakeChance: 0.3,
      defendChance: 0.08,
      grabChance: 0.08,
      specialChance: 0.18,
      edgeGuardChance: 0.05
    },
    2: {
      reactionFrames: [8, 14],
      mistakeChance: 0.13,
      defendChance: 0.32,
      grabChance: 0.18,
      specialChance: 0.28,
      edgeGuardChance: 0.3
    },
    3: {
      reactionFrames: [3, 6],
      mistakeChance: 0.035,
      defendChance: 0.58,
      grabChance: 0.25,
      specialChance: 0.36,
      edgeGuardChance: 0.62
    }
  };
  var AIRandom = class {
    constructor(seed) {
      __publicField(this, "state");
      this.state = seed >>> 0 || 1831565813;
    }
    next() {
      this.state = Math.imul(this.state ^ this.state >>> 15, 1 | this.state);
      this.state ^= this.state + Math.imul(this.state ^ this.state >>> 7, 61 | this.state);
      return ((this.state ^ this.state >>> 14) >>> 0) / 4294967296;
    }
  };
  var clampAxis = (value) => Math.max(-1, Math.min(1, value));
  var directionActions = (direction) => {
    const held = /* @__PURE__ */ new Set();
    if (direction.x < -0.2) held.add("left");
    if (direction.x > 0.2) held.add("right");
    if (direction.y < -0.35) held.add("down");
    if (direction.y > 0.35) held.add("up");
    return held;
  };
  var actionForDirection = (direction) => {
    if (Math.abs(direction.y) > Math.abs(direction.x) && Math.abs(direction.y) > 0.35) {
      return direction.y > 0 ? "up" : "down";
    }
    if (Math.abs(direction.x) > 0.2) return direction.x > 0 ? "right" : "left";
    return null;
  };
  var projectileSpecialDirectionForFighter = (fighter, toward) => {
    const attacks = getFighterDefinition(fighter).attacks;
    if (attacks["neutral-special"].projectile) return { x: 0, y: 0 };
    if (attacks["side-special"].projectile) return { x: Math.sign(toward) || 1, y: 0 };
    if (attacks["up-special"].projectile) return { x: 0, y: 1 };
    if (attacks["down-special"].projectile) return { x: 0, y: -1 };
    return null;
  };
  var CpuController = class {
    constructor(slot, level, seed = 659918) {
      __publicField(this, "slot");
      __publicField(this, "level");
      __publicField(this, "random");
      __publicField(this, "previousHeld", /* @__PURE__ */ new Set());
      __publicField(this, "nextDecisionFrame", 0);
      __publicField(this, "shieldUntilFrame", 0);
      __publicField(this, "intent", {
        direction: { x: 0, y: 0 },
        action: null,
        flickDirection: false,
        shieldFrames: 0
      });
      this.slot = slot;
      this.level = level;
      this.random = new AIRandom(seed + slot * 97 + level * 7919);
    }
    next(snapshot2) {
      if (snapshot2.phase !== "playing") return this.buildFrame({ x: 0, y: 0 }, null, false);
      const self = snapshot2.fighters[this.slot];
      const opponent = snapshot2.fighters[this.slot === 0 ? 1 : 0];
      if (self.state === "ko" || self.state === "victory") {
        return this.buildFrame({ x: 0, y: 0 }, null, false);
      }
      if (this.needsRecovery(self)) {
        const recovery = this.recoveryIntent(self, snapshot2.frame);
        return this.buildFrame(recovery.direction, recovery.action, recovery.flickDirection);
      }
      if (self.state === "hitstun") {
        const di = {
          x: self.position.x > 0 ? -0.85 : 0.85,
          y: self.velocity.y < 0 ? 0.65 : -0.15
        };
        return this.buildFrame(di, null, false);
      }
      let action = null;
      let flickDirection = false;
      if (snapshot2.frame >= this.nextDecisionFrame) {
        this.intent = this.chooseIntent(self, opponent);
        const [minimum, maximum] = AI_DIFFICULTIES[this.level].reactionFrames;
        this.nextDecisionFrame = snapshot2.frame + minimum + Math.floor(this.random.next() * (maximum - minimum + 1));
        if (this.intent.shieldFrames > 0) {
          this.shieldUntilFrame = snapshot2.frame + this.intent.shieldFrames;
        }
        action = this.intent.action;
        flickDirection = this.intent.flickDirection;
      }
      if (snapshot2.frame < this.shieldUntilFrame) action = "shield";
      return this.buildFrame(this.intent.direction, action, flickDirection);
    }
    reset(seed = 659918) {
      this.random = new AIRandom(seed + this.slot * 97 + this.level * 7919);
      this.previousHeld.clear();
      this.nextDecisionFrame = 0;
      this.shieldUntilFrame = 0;
      this.intent = {
        direction: { x: 0, y: 0 },
        action: null,
        flickDirection: false,
        shieldFrames: 0
      };
    }
    chooseIntent(self, opponent) {
      const difficulty = AI_DIFFICULTIES[this.level];
      const dx = opponent.position.x - self.position.x;
      const dy = opponent.position.y - self.position.y;
      const horizontalDistance = Math.abs(dx);
      const distance = Math.hypot(dx, dy);
      const toward = dx === 0 ? self.facing : Math.sign(dx);
      const opponentThreatening = opponent.currentMove !== null && distance < (this.level === 3 ? 185 : 140) && opponent.hitstunFrames === 0;
      if (this.random.next() < difficulty.mistakeChance) {
        return {
          direction: { x: this.random.next() < 0.5 ? -toward : 0, y: 0 },
          action: this.random.next() < 0.35 ? "jump" : null,
          flickDirection: false,
          shieldFrames: 0
        };
      }
      if (opponentThreatening && this.random.next() < difficulty.defendChance) {
        const dodge = this.level === 3 && this.random.next() < 0.44;
        return {
          direction: dodge ? { x: -toward, y: self.grounded ? 0 : 0.35 } : { x: 0, y: 0 },
          action: "shield",
          flickDirection: dodge,
          shieldFrames: dodge ? 1 : 9 + this.level * 3
        };
      }
      const opponentOffstage = Math.abs(opponent.position.x) > 500 || opponent.position.y < -25;
      if (opponentOffstage && self.grounded && this.random.next() < difficulty.edgeGuardChance) {
        const edgeX = opponent.position.x < 0 ? -465 : 465;
        const edgeDelta = edgeX - self.position.x;
        if (Math.abs(edgeDelta) > 65) {
          return {
            direction: { x: Math.sign(edgeDelta), y: 0 },
            action: null,
            flickDirection: false,
            shieldFrames: 0
          };
        }
        return {
          direction: { x: toward, y: -0.75 },
          action: this.random.next() < 0.5 ? "attack" : "special",
          flickDirection: true,
          shieldFrames: 0
        };
      }
      if (distance < 82) {
        if (this.random.next() < difficulty.grabChance && opponent.invulnerableFrames === 0) {
          return {
            direction: { x: toward, y: 0 },
            action: "grab",
            flickDirection: false,
            shieldFrames: 0
          };
        }
        const vertical = dy > 42 ? 0.8 : dy < -38 ? -0.8 : 0;
        const useSmash = this.level >= 2 && opponent.percent > 82 && this.random.next() < 0.5;
        return {
          direction: { x: vertical === 0 ? toward : 0, y: vertical },
          action: "attack",
          flickDirection: useSmash,
          shieldFrames: 0
        };
      }
      if (distance < 190) {
        if (!self.grounded && Math.abs(dy) < 115) {
          return {
            direction: { x: toward, y: dy > 45 ? 0.75 : dy < -50 ? -0.75 : 0 },
            action: "attack",
            flickDirection: false,
            shieldFrames: 0
          };
        }
        if (this.random.next() < difficulty.specialChance) {
          return {
            direction: { x: toward, y: dy > 80 ? 0.7 : 0 },
            action: "special",
            flickDirection: false,
            shieldFrames: 0
          };
        }
        return {
          direction: { x: toward, y: 0 },
          action: "attack",
          flickDirection: this.level === 3 && opponent.percent > 100,
          shieldFrames: 0
        };
      }
      const rangedSpecialDirection = projectileSpecialDirectionForFighter(self.fighter, toward);
      if (rangedSpecialDirection && horizontalDistance < 620 && this.random.next() < difficulty.specialChance) {
        return {
          direction: rangedSpecialDirection,
          action: "special",
          flickDirection: false,
          shieldFrames: 0
        };
      }
      const platformDelta = dy > 105 ? 0.72 : 0;
      return {
        direction: { x: toward, y: platformDelta },
        action: platformDelta > 0 && self.grounded && this.random.next() < 0.42 ? "jump" : null,
        flickDirection: false,
        shieldFrames: 0
      };
    }
    needsRecovery(self) {
      return Math.abs(self.position.x) > 505 || self.position.y < -80;
    }
    recoveryIntent(self, frame) {
      const centerDirection = self.position.x > 0 ? -1 : 1;
      const upSpecial = getFighterDefinition(self.fighter).attacks["up-special"];
      const upSpecialMovement = upSpecial.movement;
      const authoredMovement = upSpecial.specialMovement;
      const hasPropulsiveUpSpecial = Boolean(
        upSpecialMovement && upSpecialMovement.y > 0 || authoredMovement && authoredMovement.kind !== "air-dive" && authoredMovement.kind !== "ground-steered"
      );
      const shouldUseSpecial = self.position.y < -185 || Math.abs(self.position.x) > 650 && self.jumpsRemaining === 0;
      if (hasPropulsiveUpSpecial && shouldUseSpecial && frame >= this.nextDecisionFrame) {
        this.nextDecisionFrame = frame + (this.level === 1 ? 25 : 12);
        return {
          direction: { x: centerDirection * 0.65, y: 1 },
          action: "special",
          flickDirection: true,
          shieldFrames: 0
        };
      }
      if (self.jumpsRemaining > 0 && self.velocity.y < 65 && frame >= this.nextDecisionFrame) {
        this.nextDecisionFrame = frame + (this.level === 1 ? 18 : 9);
        return {
          direction: { x: centerDirection, y: 0.7 },
          action: "jump",
          flickDirection: false,
          shieldFrames: 0
        };
      }
      return {
        direction: { x: centerDirection, y: self.velocity.y < -100 ? 0.55 : 0 },
        action: null,
        flickDirection: false,
        shieldFrames: 0
      };
    }
    buildFrame(rawDirection, action, flickDirection) {
      const direction = { x: clampAxis(rawDirection.x), y: clampAxis(rawDirection.y) };
      const held = directionActions(direction);
      if (action) held.add(action);
      const pressed = /* @__PURE__ */ new Set();
      const released = /* @__PURE__ */ new Set();
      for (const heldAction of held) {
        if (!this.previousHeld.has(heldAction)) pressed.add(heldAction);
      }
      for (const previousAction of this.previousHeld) {
        if (!held.has(previousAction)) released.add(previousAction);
      }
      if (action) pressed.add(action);
      if (flickDirection) {
        const directionAction = actionForDirection(direction);
        if (directionAction) pressed.add(directionAction);
      }
      this.previousHeld = new Set(held);
      return { held, pressed, released, direction };
    }
  };

  // Engine/bridge.ts
  var game;
  var bots;
  var previous;
  var clamp2 = (x, lo, hi) => Math.max(lo, Math.min(hi, x));
  function reset(seed = 42, stocks = 3, countdownFrames = 180) {
    game = new CombatGame({
      players: [
        { fighter: "pip", skin: "00", name: "Pip", slot: 0, cpu: true, cpuLevel: 3 },
        { fighter: "zip", skin: "00", name: "Zip", slot: 1, cpu: true, cpuLevel: 3 }
      ],
      stocks,
      timeLimitSeconds: 90,
      items: false,
      itemFrequency: "low",
      stage: "pond"
    }, { seed, countdownFrames });
    bots = [new CpuController(0, 3, seed), new CpuController(1, 3, seed + 7919)];
    previous = [/* @__PURE__ */ new Set(), /* @__PURE__ */ new Set()];
    return JSON.stringify(game.getSnapshot());
  }
  function couple(input, reading, frame, slot) {
    const drive = Number.isFinite(reading.drive) ? clamp2(reading.drive, 0, 1) : 0;
    const turn = Number.isFinite(reading.turn) ? clamp2(reading.turn, -1, 1) : 0;
    if (drive <= 0) return createEmptyInput();
    const held = new Set(input.held);
    const activeTicks = Math.max(1, Math.ceil(drive * 12));
    if ((frame + slot * 5) % 12 >= activeTicks) {
      held.delete("attack");
      held.delete("special");
      held.delete("grab");
    }
    const x = clamp2(input.direction.x * (0.55 + drive * 0.45) + turn * 0.12, -1, 1);
    held.delete("left");
    held.delete("right");
    if (x < -0.2) held.add("left");
    if (x > 0.2) held.add("right");
    return { held, pressed: new Set([...input.pressed].filter((a) => held.has(a))), released: /* @__PURE__ */ new Set(), direction: { x, y: input.direction.y }, analog: true };
  }
  function advance(readings) {
    const frames = [];
    for (let tick = 0; tick < 6; tick++) {
      const before = game.getSnapshot();
      if (before.phase === "finished") break;
      const inputs = bots.map((bot, i) => {
        const result = couple(bot.next(before), readings[i], before.frame, i);
        result.pressed = /* @__PURE__ */ new Set([...result.pressed, ...[...result.held].filter((a) => !previous[i].has(a))]);
        result.released = new Set([...previous[i]].filter((a) => !result.held.has(a)));
        previous[i] = new Set(result.held);
        return result;
      });
      frames.push(game.step(inputs));
    }
    return JSON.stringify(frames);
  }
  function snapshot() {
    return JSON.stringify(game.getSnapshot());
  }
  return __toCommonJS(bridge_exports);
})();
