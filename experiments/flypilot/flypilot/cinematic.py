"""Export the actual Genesis scene for a higher-quality local Blender render."""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image

def export_scene(world,folder):
    folder=Path(folder);folder.mkdir(parents=True,exist_ok=True)
    textures=folder/'textures';textures.mkdir(exist_ok=True)
    def texture(value):
        if value is None:return None
        if hasattr(value,'color'):return dict(color=list(value.color))
        pixels=np.asarray(value.image_array)
        if pixels.dtype!=np.uint8:pixels=np.clip(pixels*255,0,255).astype(np.uint8)
        if pixels.ndim==3 and pixels.shape[2]==1:pixels=pixels[:,:,0]
        name=hashlib.sha256(pixels.tobytes()).hexdigest()+'.png';path=textures/name
        if not path.exists():Image.fromarray(pixels).save(path)
        return dict(file='textures/'+name,factor=list(value.image_color),encoding=value.encoding)
    parts=[]
    for ei,entity in enumerate(world.scene.entities):
        vertices=entity.get_vverts().detach().cpu().numpy().reshape(-1,3);offset=0
        role='character' if entity is world.person else 'drone' if entity is world.drone else 'shell' if entity is world.shell else 'lens' if entity is world.lens else 'static'
        for gi,geometry in enumerate(entity.vgeoms):
            n=geometry.n_vverts;name=f'entity-{ei}-part-{gi}'
            arrays=dict(vertices=vertices[offset:offset+n].astype(np.float32),faces=geometry.init_vfaces.astype(np.int32))
            if geometry.uvs is not None:arrays['uv']=geometry.uvs.astype(np.float32)
            np.savez_compressed(folder/(name+'.npz'),**arrays)
            surface=geometry.surface
            material={key:texture(getattr(surface,key+'_texture',None)) for key in ['diffuse','normal','roughness','metallic']}
            parts.append(dict(name=name,role=role,entity=ei,vertexStart=offset,vertexCount=n,material=material))
            offset+=n
    world.overview_frame()
    state=world.state()
    manifest=dict(parts=parts,state=state,sceneVersion=world.scene_version,
        smoke=world.smoke,overviewEye=world.overview_eye.tolist(),overviewLook=world.overview_look.tolist(),overviewFov=55)
    (folder/'scene.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return manifest

def capture_recording(recording,folder):
    """Replay a real run and export the exact visible vertices at each recorded instant."""
    import gzip
    from .experiment import Experiment
    recording=Path(recording);folder=Path(folder)
    with gzip.open(recording/'trace.jsonl.gz','rt') as stream:frames=[json.loads(line) for line in stream]
    first=frames[0]
    if first['scene']!='outdoor':raise ValueError('Enhanced rendering requires an outdoor battle-map recording.')
    experiment=Experiment(first['mode'],first['controller'],first['seed'],checkpoint=recording/'checkpoint.json',scene=first['scene'])
    try:
        scene=export_scene(experiment.world,folder)
        entities={part['entity'] for part in scene['parts'] if part['role']!='static'}
        poses=folder/'poses';poses.mkdir(exist_ok=True)
        output=[]
        for saved in frames:
            world=experiment.world;world.update_visuals()
            data={str(index):world.scene.entities[index].get_vverts().detach().cpu().numpy().reshape(-1,3).astype(np.float32) for index in entities}
            path=poses/f"{saved['index']:05}.npz";np.savez_compressed(path,**data)
            actual,_,_=experiment.step()
            assert actual['brain']['rateHash']==saved['brain']['rateHash']
            assert actual['input']==saved['input'] and actual['cameraHash']==saved['cameraHash']
            assert actual['sensorHash']==saved['sensorHash']
            np.testing.assert_allclose(actual['state']['position'],saved['state']['position'],atol=2e-5,rtol=0)
            assert actual['state']['events']==saved['state']['events']
            output.append(dict(index=saved['index'],time=saved['before']['time'],overviewEye=saved['before']['overviewEye'],overviewLook=saved['before']['overviewLook'],overviewFov=saved['before']['overviewFov'],rateHash=saved['brain']['rateHash'],verticesHash=hashlib.sha256(path.read_bytes()).hexdigest()))
            if saved['index']%25==0:print('Exported verified frame',saved['index'],flush=True)
        (folder/'frames.json').write_text(json.dumps(output,indent=2)+'\n')
    finally:experiment.close()

def assemble(recording,rendered,output):
    """Combine rendered world frames with the original camera, rates, and physical path."""
    import gzip
    import shutil
    import imageio.v2 as imageio
    from .recording import Instruments
    from .sound import add_sound
    recording,rendered,output=map(Path,[recording,rendered,output]);output.mkdir(parents=True,exist_ok=True)
    with gzip.open(recording/'trace.jsonl.gz','rt') as stream:frames=[json.loads(line) for line in stream]
    timings=json.loads((rendered/'render-times.json').read_text());assert len(timings)==len(frames)
    instruments=Instruments(json.loads((recording/'metadata.json').read_text()));path=[];hashes=[];saved_contact=False
    movie=imageio.get_writer(str(output/'flypilot-cinematic.mp4'),fps=10,codec='libx264',macro_block_size=8,quality=8,ffmpeg_log_level='error')
    world_movie=imageio.get_writer(str(output/'battle-map.mp4'),fps=10,codec='libx264',macro_block_size=8,quality=8,ffmpeg_log_level='error')
    try:
        for frame,timing in zip(frames,timings):
            index=frame['index'];assert index==timing['index']
            world=np.asarray(Image.open(rendered/f'{index:05}.png').convert('RGB'))
            camera=np.asarray(Image.open(recording/'camera'/f'{index:05}.png').convert('RGB'))
            assert hashlib.sha256(camera.tobytes()).hexdigest()==frame['cameraHash']
            frame['before'].update(overviewEye=timing['eye'],overviewLook=timing['look'],overviewFov=timing['fov'])
            frame['renderer']='Blender 5.2.1';frame['renderWallSeconds']=timing['renderWallSeconds']
            path.append(frame['state']['position'])
            composed=instruments.compose(world,camera,frame,path)
            movie.append_data(composed);world_movie.append_data(world)
            if index in [0,50]:Image.fromarray(composed).save(output/('opening.png' if index==0 else 'preview.png'))
            if frame['before'].get('contact') and not saved_contact:
                Image.fromarray(composed).save(output/'contact.png');saved_contact=True
            hashes.append(dict(index=index,worldHash=hashlib.sha256(world.tobytes()).hexdigest(),rateHash=frame['brain']['rateHash']))
    finally:movie.close();world_movie.close()
    # Audio uses the original motor trace. It is a programmed game effect.
    shutil.copy2(recording/'trace.jsonl.gz',output/'trace.jsonl.gz')
    add_sound(output,'flypilot-cinematic.mp4');add_sound(output,'battle-map.mp4')
    (output/'render-provenance.json').write_text(json.dumps(dict(renderer='Blender 5.2.1 / Cycles / Metal',samples=16,frames=len(frames),fps=10,sourceTraceHash=hashlib.sha256((recording/'trace.jsonl.gz').read_bytes()).hexdigest(),renderWallSeconds=timings[-1]['renderWallSeconds'],frameHashes=hashes),indent=2)+'\n')
    return output

def render_recording(recording,output=None,blender=None):
    import os
    import shutil
    import subprocess
    from .brain import ROOT
    recording=Path(recording).resolve()
    output=Path(output).resolve() if output else ROOT/'runs'/(recording.name+'-cinematic')
    candidates=[blender,os.environ.get('FLYPILOT_BLENDER'),shutil.which('blender'),'/Applications/Blender.app/Contents/MacOS/Blender',str(ROOT/'runs/tools/Blender.app/Contents/MacOS/Blender')]
    executable=next((str(p) for p in candidates if p and Path(p).is_file()),None)
    if not executable:raise RuntimeError('Install Blender 5.2.1. Or set FLYPILOT_BLENDER to its executable path.')
    version=subprocess.check_output([executable,'--version'],text=True).splitlines()[0]
    if not version.startswith('Blender 5.2.1 '):
        raise RuntimeError(f'Use Blender 5.2.1 for this renderer. Found: {version}')
    export=output/'local-scene';images=output/'world-frames'
    capture_recording(recording,export)
    subprocess.run([executable,'--background','--factory-startup','--python',str(ROOT/'scripts/render-cinematic.py'),'--',str(export),str(images)],check=True)
    assemble(recording,images,output)
    shutil.copy2(export/'battle-map.glb',output/'battle-map.glb')
    print('Rendered recorded flight:',output,flush=True)
