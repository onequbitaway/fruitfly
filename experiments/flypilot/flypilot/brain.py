"""Local Swift process. A failure stops the loop; restart always resets time."""
from __future__ import annotations
import base64
import json
import queue
import subprocess
import threading
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT.parent / "full-map" / "Data"

class BrainError(RuntimeError):
    pass

class Brain:
    def __init__(self, mode="full", seed=7, timeout=30, executable=None, cpu=False):
        if mode not in ("full", "simple"):
            raise ValueError("Choose full or simple.")
        self.mode, self.timeout, self.seed = mode, timeout, seed
        self.executable = Path(executable or ROOT / ".build/release/FlyBrainService")
        self.cpu, self.process, self.serial = cpu, None, 0
        self.start()

    def start(self):
        self.lines = queue.Queue()
        command = [str(self.executable), str(DATA), self.mode] + (["--cpu"] if self.cpu else [])
        try:
            self.process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                            stderr=subprocess.PIPE, text=True, bufsize=1)
        except OSError as e:
            raise BrainError("The brain service could not start. Run ./setup.sh.") from e
        def read(pipe, out):
            for line in pipe:
                out.put(line)
            out.put(None)
        self.errors = queue.Queue()
        self.reader = threading.Thread(target=read, args=(self.process.stdout, self.lines), daemon=True)
        self.error_reader = threading.Thread(target=read, args=(self.process.stderr, self.errors), daemon=True)
        self.reader.start()
        self.error_reader.start()
        try:
            self.metadata = self._read()
            if self.metadata.get("protocol") != 1 or not self.metadata.get("ready"):
                raise BrainError("The brain protocol does not match.")
            expected = 166700 if self.mode == "full" else 3745
            if self.metadata["cells"] != expected:
                raise BrainError("The brain has the wrong cell count.")
            self.reset(self.seed)
        except BaseException:
            self.close(force=True)
            raise

    def _read(self):
        try:
            line = self.lines.get(timeout=self.timeout)
        except queue.Empty as e:
            self.close(force=True)
            raise BrainError("The brain timed out. The flight stopped. Reset to start a new run.") from e
        if line is None:
            error = []
            while not self.errors.empty():
                value = self.errors.get_nowait()
                if value: error.append(value.strip())
            raise BrainError("The brain process stopped. " + " ".join(error))
        try:
            return json.loads(line)
        except ValueError as e:
            raise BrainError("The brain sent invalid data.") from e

    def request(self, command, **payload):
        if self.process is None or self.process.poll() is not None:
            raise BrainError("The brain process is not running. Reset to start a new run.")
        self.serial += 1
        try:
            self.process.stdin.write(json.dumps(dict(id=self.serial, command=command, **payload), allow_nan=False) + "\n")
            self.process.stdin.flush()
        except (OSError, BrokenPipeError) as e:
            raise BrainError("The brain process stopped.") from e
        result = self._read()
        if result.get("id") != self.serial or not result.get("ok"):
            raise BrainError(result.get("error", "The brain reply does not match."))
        return result

    def reset(self, seed=None):
        if seed is not None: self.seed = seed
        return self.request("reset", seed=self.seed)

    def restart(self, seed=None):
        self.close()
        if seed is not None: self.seed = seed
        self.start()

    def step(self, inputs, full_rates=False):
        return self.request("step", input=inputs, fullRates=full_rates)

    def close(self, force=False):
        p = self.process
        if p is None: return
        if p.poll() is None:
            try:
                if not force:
                    p.stdin.write(json.dumps({"id": 0, "command": "quit"}) + "\n")
                    p.stdin.flush()
                    p.wait(timeout=2)
                else: p.terminate()
            except (OSError, subprocess.TimeoutExpired): p.terminate()
            try: p.wait(timeout=2)
            except subprocess.TimeoutExpired:
                p.kill()
                p.wait()
        for pipe in [p.stdin, p.stdout, p.stderr]:
            if pipe: pipe.close()
        self.process = None

    def __enter__(self): return self
    def __exit__(self, *_): self.close()

def rates_from_sample(sample):
    return np.frombuffer(base64.b64decode(sample["ratesF32LE"]), dtype="<f4")

def sensory(observation, mode):
    """Chosen encoding, not a biological retina. No pose reaches this adapter."""
    left = right = 0.0
    if observation["found"]:
        # Sum carries apparent range. Difference carries image direction.
        range_error = np.clip((observation["distance"] - 1.8) / 2.0, -1, 1)
        base = 100 + 40 * range_error
        horizontal = np.clip(observation["x"], -1, 1)
        left = float(np.clip(base - 45 * horizontal, 0, 200))
        right = float(np.clip(base + 45 * horizontal, 0, 200))
    return dict(odorLeft=left if mode == "simple" else 0,
                odorRight=right if mode == "simple" else 0,
                visualLeft=left if mode == "full" else 0,
                visualRight=right if mode == "full" else 0, taste=0, feeding=0)
