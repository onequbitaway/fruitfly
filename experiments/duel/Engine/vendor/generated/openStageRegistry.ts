// Original Fruitfly stage. Native code draws these exact collision surfaces.
export const OPEN_STAGE_IDS = ['pond'] as const;
export const DEFAULT_STAGE_ID = 'pond';
export const OPEN_STAGE_PACKS = [{
  id: 'pond', identity: {displayName: 'The pond', series: 'Fruitfly', description: 'Three leaves. Two flies.'},
  gameplay: {
    platforms: [
      {id:'main', x:0, y:-36, width:1000, height:72, kind:'ground'},
      {id:'left', x:-265, y:165, width:225, height:18, kind:'platform'},
      {id:'right', x:265, y:165, width:225, height:18, kind:'platform'},
      {id:'top', x:0, y:330, width:200, height:18, kind:'platform'}
    ],
    ledges: [{platformId:'main',side:'left'},{platformId:'main',side:'right'}],
    spawns: [{x:-185,y:65},{x:185,y:65}],
    blastZone: {left:-980,right:980,top:900,bottom:-600}
  },
  render:{kind:'2d',art:{width:1280,height:900,originPx:{x:640,y:530},worldUnitsPerPixel:1.55}},
  runtime:{previewUrl:'',thumbnailUrl:'',arenaUrl:'',backdropUrl:''},
  colors:{edge:'#164459',surface:'#388768',body:'#24624B',shadow:'#164459'},
  license:{id:'MIT',attribution:'Fruitfly contributors'}
}];
