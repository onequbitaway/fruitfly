import argparse
from pathlib import Path
from .brain import ROOT

def main():
    parser=argparse.ArgumentParser(description="FlyPilot. A fixed fly brain with a trained drone readout.")
    sub=parser.add_subparsers(dest="command",required=True)
    for command in ["run","train","evaluate","record"]:
        p=sub.add_parser(command)
        p.add_argument("--mode",choices=["full","simple"],default="full")
        p.add_argument("--scene",choices=["outdoor","studio"],default="outdoor")
        if command in ["run","train","record"]:
            p.add_argument("--reference",type=Path,help="Local reference image. Derived data stays in private/.")
        if command=="train":
            p.add_argument("--samples",type=int,default=360)
            p.add_argument("--seed",type=int,default=2026)
            p.add_argument("--epochs",type=int,default=800)
        if command in ["evaluate","record"]: p.add_argument("--seconds",type=float,default=20)
        if command=="evaluate": p.add_argument("--seeds",type=int,nargs="+",default=[503,607,709])
        if command in ["run","record"]:
            p.add_argument("--seed",type=int,default=101)
            p.add_argument("--checkpoint",type=Path)
        if command=="record": p.add_argument("--output",type=Path,default=ROOT/"runs/demo-full")
        if command=="run":
            p.add_argument("--port",type=int,default=0,help="Local port. Zero selects a free port.")
            p.add_argument("--no-open",action="store_true")
    p=sub.add_parser("check")
    p.add_argument("folder",type=Path)
    p.add_argument("--brain-only",action="store_true")
    p=sub.add_parser("render")
    p.add_argument("folder",type=Path)
    p.add_argument("--output",type=Path)
    p.add_argument("--blender",type=Path)
    sub.add_parser("test")
    args=parser.parse_args()
    if getattr(args,"reference",None):
        args.scene="studio"
        args.reference=args.reference.expanduser().resolve()
        if not args.reference.is_file(): parser.error("The reference image does not exist.")
        if args.command in ["run","record"] and not args.checkpoint:
            args.checkpoint=ROOT/"private"/(args.mode+".json")
        if args.command=="record": args.output=ROOT/"private"/("recording-"+args.mode)
    if args.command=="train":
        from .training import train
        train(args.mode,args.samples,args.seed,args.epochs,args.reference,args.scene)
    elif args.command=="evaluate":
        from .experiment import evaluate
        evaluate(args.mode,args.seconds,args.seeds,scene=args.scene)
    elif args.command=="record":
        from .experiment import Experiment,run_episode
        experiment=Experiment(args.mode,seed=args.seed,reference=args.reference,checkpoint=args.checkpoint,scene=args.scene)
        try: run_episode(experiment,args.seconds,args.output,True)
        finally: experiment.close()
    elif args.command=="check":
        from .replay import check
        check(args.folder,not args.brain_only)
    elif args.command=="render":
        from .cinematic import render_recording
        render_recording(args.folder,args.output,args.blender)
    elif args.command=="test":
        import pytest
        raise SystemExit(pytest.main([str(ROOT/"tests"),"-q"]))
    elif args.command=="run":
        from .server import run
        run(args.mode,args.seed,args.port,not args.no_open,args.reference,args.checkpoint,args.scene)

if __name__=="__main__": main()
