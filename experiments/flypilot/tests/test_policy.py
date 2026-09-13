import numpy as np
from flypilot.brain import sensory
from flypilot.policy import fit, Readout

def test_optimization_and_dependency_on_brain():
    rng=np.random.default_rng(29)
    features=rng.normal(100,20,(100,4))
    labels=np.column_stack([.003*(features[:,0]+features[:,1]-200), .005*(features[:,0]-features[:,1])])
    fitted=fit(features,labels,["a","b","c","d"],"full",epochs=800)
    assert fitted["curve"][-1]["mse"]<fitted["curve"][0]["mse"]*.01
    model=Readout(fitted)
    assert np.linalg.norm(model.predict([80,120,100,100])-model.predict([120,80,100,100]))>.3

def test_lost_sensory_input_is_zero():
    assert all(value==0 for value in sensory(dict(found=False),"full").values())
