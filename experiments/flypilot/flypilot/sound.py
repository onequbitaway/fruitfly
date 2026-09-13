"""Deterministic game sound effects from recorded motors and the contact timestamp."""
import gzip
import json
from pathlib import Path
import subprocess
import wave
import numpy as np
import imageio_ffmpeg

def add_sound(folder,video='flypilot-full-map.mp4',combat=False):
    folder=Path(folder)
    with gzip.open(folder/'trace.jsonl.gz','rt') as stream:frames=[json.loads(line) for line in stream]
    rate=48000;duration=len(frames)/10;t=np.arange(round(duration*rate))/rate
    times=np.array([f['before']['time'] for f in frames]);rpm=np.array([np.mean(f['motors']) for f in frames])
    frequency=np.interp(t,times,rpm)*2/60
    phase=np.cumsum(frequency)*2*np.pi/rate
    distance=np.array([np.linalg.norm(np.array(f['before'].get('overviewEye',[0,-6,2]))-f['before']['position']) for f in frames])
    level=np.interp(t,times,.28/np.sqrt(1+distance))
    rng=np.random.default_rng(2026);noise=rng.standard_normal(len(t))
    wind=np.convolve(noise,np.ones(100)/100,mode='same')*.06
    signal=level*(np.sin(phase)*.6+np.sin(2*phase)*.18+np.sin(3*phase)*.08)+wind
    contact=next((e['time'] for f in frames for e in f['state']['events'] if e['type']=='character contact'),None)
    if contact is not None:
        tau=np.maximum(0,t-contact);envelope=np.where(t>=contact,np.exp(-tau/0.055),0)
        signal+=envelope*(.34*np.sin(2*np.pi*82*tau)+.11*noise)
        if combat:
            signal*=np.where(t<contact,1,np.exp(-tau*20))
            onset=(t>=contact).astype(float)
            rumble=np.convolve(noise,np.ones(55)/55,mode='same')
            signal+=onset*(.7*np.exp(-tau*8)*np.sin(2*np.pi*(48*tau-8*tau*tau))
                +.36*np.exp(-tau*22)*noise+.8*np.exp(-tau*3)*rumble)
            signal+=onset*.04*np.exp(-tau*1.8)*noise
    fade=np.minimum(1,t/.15)*np.minimum(1,(duration-t)/.18);signal*=fade
    samples=(np.clip(signal,-.95,.95)*32767).astype('<i2')
    audio=folder/'sound.wav'
    with wave.open(str(audio),'wb') as out:
        out.setnchannels(1);out.setsampwidth(2);out.setframerate(rate);out.writeframes(samples.tobytes())
    target=folder/video;temporary=target.with_name(target.stem+'-audio.mp4')
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-y','-loglevel','error','-i',str(target),'-i',str(audio),'-map','0:v:0','-map','1:a:0','-c:v','copy','-c:a','aac','-b:a','128k','-shortest','-movflags','+faststart',str(temporary)],check=True)
    temporary.replace(target)
    (folder/'sound.json').write_text(json.dumps(dict(description='Synthesized game effects. Motor buzz follows recorded RPM. Contact sound uses the recorded event. Not measured acoustics.',combatExplosion=combat,seed=2026,sampleRate=rate,duration=duration,contactTime=contact),indent=2)+'\n')
