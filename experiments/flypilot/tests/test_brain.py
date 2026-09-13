import hashlib
import json
import time
import numpy as np
import pytest
from flypilot.brain import Brain, BrainError, DATA, sensory, rates_from_sample

def test_full_counts_exact_rates_repeat_and_independence():
    inputs=sensory(dict(found=True,x=.35,distance=2.6),"full")
    with Brain("full",71) as a, Brain("full",99) as b:
        assert a.metadata["cells"]==166700
        assert a.metadata["connections"]==25582938
        assert a.metadata["contacts"]==124177617
        initial=b.request("snapshot")
        one=a.step(inputs,True)
        assert b.request("snapshot")["rateHash"]==initial["rateHash"]
        two=a.step(inputs,True)
        a.reset(71)
        assert a.step(inputs)["rateHash"]==one["rateHash"]
        assert a.step(inputs)["rateHash"]==two["rateHash"]
        rates=rates_from_sample(two)
        assert len(rates)==166700
        assert hashlib.sha256(rates.tobytes()).hexdigest()==two["rateHash"]
        assert sum(rates>0)==two["activeCells"]
        for point,rate in zip(a.metadata["plot"],two["plotRates"]):
            assert rates[point["index"]]==rate
        meta=json.loads((DATA/"neurons.json").read_text())
        visual=a.metadata["channels"]["visual"]
        for side,column in [(-1,0),(1,1)]:
            expected=np.mean([float(rates[i]) for i in visual if meta["sides"][i]==side])
            assert two["features"][column]==pytest.approx(expected,abs=1e-10)
        process=a.process
    assert process.poll()==0

def test_simple_proxy_reset_restart_and_error():
    inputs=sensory(dict(found=True,x=-.4,distance=2.2),"simple")
    assert inputs["visualLeft"]==0 and inputs["odorLeft"]>0
    with Brain("simple",7) as brain:
        assert brain.metadata["cells"]==3745
        first=brain.step(inputs)
        with pytest.raises(BrainError): brain.request("bogus")
        bad=dict(inputs,odorLeft=-1)
        with pytest.raises(BrainError): brain.step(bad)
        brain.restart(7)
        assert first["rateHash"]==brain.step(inputs)["rateHash"]
        brain.process.kill()
        brain.process.wait()
        with pytest.raises(BrainError): brain.step(inputs)

def test_missing_service_and_timeout(tmp_path):
    with pytest.raises(BrainError,match="could not start"):
        Brain(executable=tmp_path/"missing")
    executable=tmp_path/"slow"
    executable.write_text("#!/bin/sh\nexec sleep 10\n")
    executable.chmod(0o755)
    start=time.monotonic()
    with pytest.raises(BrainError,match="timed out"):
        Brain(executable=executable,timeout=.1)
    assert time.monotonic()-start<3

def test_seed_changes_activity():
    inputs=sensory(dict(found=True,x=.5,distance=3),"full")
    with Brain("full",19) as b:
        first=b.step(inputs)["rateHash"]
        b.reset(20)
        assert b.step(inputs)["rateHash"]!=first
