"""Loopback-only UI. All simulator work stays on the main thread."""
from __future__ import annotations
import json
import queue
import threading
import time
import webbrowser
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from .brain import ROOT
from .experiment import Experiment
from .recording import jpeg_bytes

def run(mode="full",seed=101,port=0,open_browser=True,reference=None,checkpoint=None,scene="outdoor"):
    commands=queue.Queue()
    shared=dict(status="Loading the scene and brain.",running=False,mode=mode,image=None,frame=None,error=None)
    lock=threading.Lock()
    allowed={"/":("index.html","text/html"),"/app.js":("app.js","application/javascript"),"/style.css":("style.css","text/css")}
    class Handler(BaseHTTPRequestHandler):
        def log_message(self,*_): pass
        def send(self,status,content,kind):
            self.send_response(status)
            self.send_header("Content-Type",kind)
            self.send_header("Content-Length",str(len(content)))
            self.send_header("Cache-Control","no-store")
            self.send_header("X-Content-Type-Options","nosniff")
            self.send_header("Content-Security-Policy","default-src 'self'; img-src 'self' blob:; style-src 'self'; script-src 'self'; connect-src 'self'; frame-ancestors 'none'")
            self.end_headers()
            try: self.wfile.write(content)
            except (BrokenPipeError,ConnectionResetError): pass
        def do_GET(self):
            route=self.path.split("?")[0]
            if route in allowed:
                file,kind=allowed[route]
                return self.send(200,(ROOT/"web"/file).read_bytes(),kind)
            if route=="/frame.jpg":
                with lock: image=shared["image"]
                return self.send(200 if image else 204,image or b"","image/jpeg")
            if route=="/state":
                with lock: state={k:v for k,v in shared.items() if k!="image"}
                return self.send(200,json.dumps(state,allow_nan=False).encode(),"application/json")
            return self.send(404,b"Not found.","text/plain")
        def do_POST(self):
            # A cross-site page cannot add this header without a denied preflight.
            if self.path!="/command" or self.headers.get("X-FlyPilot")!="1":
                return self.send(403,b"Use the local FlyPilot controls.","text/plain")
            try:
                size=int(self.headers.get("Content-Length","0"))
                if size<1 or size>1024: raise ValueError()
                payload=json.loads(self.rfile.read(size))
                if not isinstance(payload,dict): raise ValueError()
                if payload.get("command") not in ["start","pause","reset","mode"]: raise ValueError()
                if payload["command"]=="mode" and payload.get("mode") not in ["full","simple"]: raise ValueError()
            except (ValueError,TypeError): return self.send(400,b"Invalid control.","text/plain")
            commands.put(payload)
            self.send(202,b'{"accepted":true}',"application/json")
    http=ThreadingHTTPServer(("127.0.0.1",port),Handler)
    threading.Thread(target=http.serve_forever,daemon=True).start()
    url=f"http://127.0.0.1:{http.server_port}"
    print(f"Open {url}. Press Control-C here to close FlyPilot.",flush=True)
    if open_browser: webbrowser.open(url)
    experiment=None
    paused=True
    def start_experiment(chosen):
        nonlocal experiment,mode
        if experiment: experiment.close();experiment=None
        mode=chosen
        with lock: shared.update(status="Loading the scene and brain.",mode=mode,error=None,image=None,frame=None,running=False)
        experiment=Experiment(mode,seed=seed,reference=reference,checkpoint=checkpoint,scene=scene)
        with lock: shared.update(status="Ready. Select Start.")
    try:
        start_experiment(mode)
        while True:
            try:
                payload=commands.get(timeout=.05 if paused else .001)
                command=payload["command"]
                if command=="pause": paused=True
                elif command=="start":
                    if experiment is None: start_experiment(mode)
                    paused=False
                elif command=="reset":
                    if experiment is None: start_experiment(mode)
                    else: experiment.reset(seed)
                    paused=True
                    with lock: shared.update(frame=None,image=None,error=None)
                elif command=="mode":
                    paused=True
                    start_experiment(payload["mode"])
                with lock: shared.update(running=not paused,status="Paused." if paused else "Running.")
            except queue.Empty: pass
            except Exception as error:
                paused=True
                if experiment: experiment.close();experiment=None
                with lock: shared.update(error=str(error),status="Flight stopped. Select Reset.",running=False)
            if paused: continue
            try:
                cycle_start=time.monotonic()
                old_wall=experiment.wall_total
                frame,camera,overview=experiment.step(overview=True)
                picture=experiment.instruments.compose(overview,camera,frame,experiment.world.path,live=True)
                slim=dict(time=frame["brain"]["time"],activeCells=frame["brain"]["activeCells"],
                    cells=experiment.brain.metadata["cells"],scene=scene,centerError=frame["centerError"],
                    distanceError=frame["distanceError"],status=frame["status"],wallSeconds=frame["wallSeconds"],
                    boundaryEvents=sum(e["type"]!="character contact" for e in frame["state"]["events"]),rateHash=frame["brain"]["rateHash"])
                encoded=jpeg_bytes(picture)
                experiment.wall_total=old_wall+time.monotonic()-cycle_start
                with lock: shared.update(image=encoded,frame=slim,status=frame["status"],running=True)
                if frame["state"].get("contact") and experiment.world.time>=experiment.world.contact["time"]+2:
                    paused=True
                    with lock: shared.update(running=False,status="Contact. Select Reset for a new run.")
                # Avoid unbounded history during a long live session.
                if len(experiment.frames)>600: experiment.frames=experiment.frames[-600:]
                if len(experiment.world.path)>2000: experiment.world.path=experiment.world.path[-2000:]
            except Exception as error:
                paused=True
                with lock: shared.update(error=str(error),status="Flight stopped. Select Reset.",running=False)
                if experiment: experiment.close();experiment=None
    except KeyboardInterrupt: pass
    except Exception as error:
        with lock: shared.update(error=str(error),status="Setup failed. Check the terminal.",running=False)
        print(str(error),flush=True)
        raise
    finally:
        if experiment: experiment.close()
        http.shutdown()
        http.server_close()
