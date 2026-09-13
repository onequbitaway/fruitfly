"""Draw instruments from a saved physics frame and exact calculated cell rates."""
from __future__ import annotations
import io
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from .brain import ROOT
from .room import OVERVIEW_EYE, OVERVIEW_LOOK, OVERVIEW_FOV

def font(size, bold=False):
    candidates=["/System/Library/Fonts/Avenir Next.ttc", "/System/Library/Fonts/Supplemental/Arial.ttf"]
    for name in candidates:
        try: return ImageFont.truetype(name,size,index=(2 if bold else 7) if "Avenir" in name else 0)
        except OSError: pass
    return ImageFont.load_default(size=size)

INK="#132d46"
BLUE="#2976ba"
CORAL="#de6848"
PAPER="#eaf0f6"

class Instruments:
    def __init__(self, metadata):
        self.metadata=metadata
        p=np.array([point["position"] for point in metadata["plot"]],dtype=float)
        x,z=p[:,0],p[:,2]
        # One projection with published positions. No point has a made-up position.
        self.positions=np.column_stack([(x-x.min())/max(1,np.ptp(x)), (z-z.min())/max(1,np.ptp(z))])

    def compose(self, overview, camera, frame, path, live=False):
        outdoor=frame.get("scene")=="outdoor"
        ink="#e7ecec" if outdoor else INK
        accent="#a8c7ce" if outdoor else BLUE
        paper="#11191d" if outdoor else PAPER
        panel="#202c31" if outdoor else "#ffffff"
        plot_background="#0b1216" if outdoor else INK
        im=Image.new("RGB",(1920,1080),paper)
        d=ImageDraw.Draw(im)
        d.text((32,20),"FlyPilot",font=font(43,True),fill=ink)
        d.text((258,37),"Battle map · a fruit-fly brain model at the controls" if outdoor else "A fruit-fly brain model at the controls",font=font(25),fill=ink)
        mode="Full map" if self.metadata["mode"]=="full" else "Simple · smell proxy"
        d.text((1340,21),mode,font=font(30,True),fill=accent)
        d.text((1340,58),f'{self.metadata["cells"]:,} calculated cells',font=font(19),fill=ink)
        im.paste(Image.fromarray(overview).resize((1280,800)),(24,108))
        im.paste(Image.fromarray(camera).resize((564,423)),(1332,108))
        d=ImageDraw.Draw(im)
        eye=np.array(frame["before"].get("overviewEye",OVERVIEW_EYE)); direction=np.array(frame["before"].get("overviewLook",OVERVIEW_LOOK))-eye
        direction/=np.linalg.norm(direction)
        right=np.cross(direction,[0,0,1]);right/=np.linalg.norm(right)
        up=np.cross(right,direction)
        focal=800/(2*np.tan(np.deg2rad(frame["before"].get("overviewFov",OVERVIEW_FOV)/2)))
        def world_point(point):
            delta=np.asarray(point)-eye;depth=np.dot(delta,direction)
            return (24+640+focal*np.dot(delta,right)/depth,108+400-focal*np.dot(delta,up)/depth)
        visible_path=[world_point(p) for p in path if np.dot(np.asarray(p)-eye,direction)>.1]
        # Draw the path in a clipped overlay so offscreen points cannot cover instruments.
        overlay=Image.new("RGBA",(1280,800))
        od=ImageDraw.Draw(overlay)
        if len(visible_path)>1: od.line([(x-24,y-108) for x,y in visible_path],fill=(41,118,186,160),width=3)
        im.paste(overlay,(24,108),overlay)
        d=ImageDraw.Draw(im)
        x,y=world_point(frame["before"]["position"])
        if not outdoor and 45<x<1283 and 129<y<887:
            d.ellipse((x-15,y-15,x+15,y+15),outline="#ffffff",width=2)
            d.ellipse((x-3,y-3,x+3,y+3),fill=accent)
            d.text((x+23,y-15),"DRONE",font=font(16,True),fill="#ffffff",stroke_width=1,stroke_fill=ink)
        if outdoor and frame["before"].get("contact"):
            x,y=world_point(frame["before"]["contact"]["characterPoint"])
            d.ellipse((x-22,y-22,x+22,y+22),outline=CORAL,width=4)
            d.rounded_rectangle((44,182,280,235),radius=8,fill=CORAL)
            d.text((60,192),"IMPACT" if frame.get('combatEffects') else "CONTACT",font=font(29,True),fill="#ffffff")
        d.rounded_rectangle((44,128,315 if outdoor else 262,165),radius=8,fill=panel)
        view_label="Battle map · Cycles" if frame.get("renderer") else "Battle map · flight view" if outdoor else "Studio · flight view"
        d.text((57,133),view_label,font=font(21),fill=ink)
        obs=frame["observation"]
        d.text((1338,543),"Sensor camera" if frame.get("renderer") else "Drone camera",font=font(25,True),fill=ink)
        d.text((1710,547),"Target found" if obs["found"] else "Target lost",font=font(21),fill=accent if obs["found"] else CORAL)
        if obs.get("box"):
            box=[(1332+point[0]*564/camera.shape[1],108+point[1]*423/camera.shape[0]) for point in obs["box"]]
            d.line(box+[box[0]],fill=CORAL,width=2)
        d.rounded_rectangle((1332,594,1896,908),radius=12,fill=plot_background)
        d.text((1352,607),"Calculated activity",font=font(25,True),fill="#ffffff")
        for (x,y),rate in zip(self.positions,frame["brain"]["plotRates"]):
            px=1363+x*498;py=653+y*216
            color="#425970" if rate<=0 else (int(120+min(rate,100)*1.02),int(89+min(rate,100)*.15),72)
            r=.75 if rate<=0 else 1.3
            d.ellipse((px-r,py-r,px+r,py+r),fill=color)
        d.text((1352,879),"Cell rates · fixed 0–100+ Hz scale",font=font(17),fill="#c8d9e8")
        # A small plan view shows actual physical coordinates, separate from the room camera.
        rect=(1060,783,1282,886)
        d.rounded_rectangle((1047,750,1292,896),radius=8,fill=panel)
        d.text((1060,756),"Flight path",font=font(17,True),fill=ink)
        def project(p):
            return (rect[0]+(p[0]+3)/(38 if outdoor else 7)*(rect[2]-rect[0]),rect[3]-(p[1]+(2 if outdoor else 2.5))/(6 if outdoor else 5)*(rect[3]-rect[1]))
        if len(path)>1: d.line([project(p) for p in path],fill=accent,width=2)
        for point,color,r in [(frame["state"]["position"],BLUE,4),(frame["state"]["target"],CORAL,5)]:
            x,y=project(point);d.ellipse((x-r,y-r,x+r,y+r),fill=color)
        b=frame["brain"]
        items=[("Model time",f'{b["time"]:.1f} s'),("Active cells",f'{b["activeCells"]:,}'),
               ("Character range" if outdoor else "Range error",f'{frame["distanceError"]:.2f} m'),("Center error",f'{frame["centerError"]:.2f}'),
               ("Forward",f'{frame["action"][0]:.2f} m/s'),("Turn",f'{frame["action"][1]:.2f} rad/s')]
        for i,(label,value) in enumerate(items):
            x=34+i*216
            d.text((x,935),label,font=font(18),fill="#91a3ac" if outdoor else "#59718b")
            d.text((x,963),value,font=font(27,True),fill=ink)
        d.text((1338,935),"Fixed brain wiring · trained output map",font=font(23,True),fill=ink)
        d.text((1338,972),frame["status"],font=font(23),fill=accent)
        kind="Live calculation" if live else "Recorded run · 1× simulation time"
        timing=f'{kind} · {frame["wallSeconds"]:.1f} s model-run wall time'
        if frame.get("renderer"):timing+=f' · Render {frame["renderWallSeconds"]:.1f} s'
        else:timing+=" · Genesis 1.4.0"
        d.text((34,1040),timing,font=font(20),fill=ink)
        footer="Recorded approach · programmed impact" if frame.get('combatEffects') else "Game camera sensors + flight stabilizer" if outdoor else "Camera matcher + programmed flight stabilizer"
        d.text((1338,1040),footer,font=font(19),fill=ink)
        return np.asarray(im)

def jpeg_bytes(rgb):
    buf=io.BytesIO()
    Image.fromarray(rgb).save(buf,format="JPEG",quality=88)
    return buf.getvalue()
