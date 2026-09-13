"""A small trained linear readout. No camera coordinates enter predict()."""
from __future__ import annotations
import json
import numpy as np
from .brain import ROOT

class Readout:
    def __init__(self, checkpoint):
        if not isinstance(checkpoint, dict): checkpoint = json.loads(checkpoint.read_text())
        self.checkpoint = checkpoint
        self.mean = np.array(checkpoint["mean"])
        self.scale = np.array(checkpoint["scale"])
        self.weights = np.array(checkpoint["weights"])
        self.indices = np.array(checkpoint["featureIndices"])

    def predict(self, brain_features):
        raw = np.asarray(brain_features, dtype=float)[self.indices]
        x = np.append((raw-self.mean)/self.scale, 1)
        out = x @ self.weights
        return np.clip(out, self.checkpoint.get("outputMin",[-.35,-.65]), self.checkpoint.get("outputMax",[.65,.65]))

def load(mode,scene="studio"):
    path = ROOT / "weights" / (mode + ("-outdoor" if scene=="outdoor" else "") + ".json")
    if not path.exists(): raise ValueError(f"No {mode} weights. Run ./flypilot.sh train --mode {mode}.")
    return Readout(path)

def fit(features, labels, feature_names, mode, seed=2026, epochs=800, learning_rate=.04):
    """Full-batch gradient descent on standardized calculated rates and a bias."""
    # Sensory means give robust low-latency rates. DNa02 adds downstream activity.
    # Simple lacks DNa02, so it is trained separately on smell-proxy rates.
    indices = [0, 1, 2, 3] if mode == "full" else [0, 1]
    raw = np.asarray(features)[:, indices]
    labels = np.asarray(labels)
    mean = raw.mean(axis=0)
    scale = np.maximum(raw.std(axis=0), 1)
    x = np.column_stack([(raw-mean)/scale, np.ones(len(raw))])
    rng = np.random.default_rng(seed)
    weights = rng.normal(0, .04, (x.shape[1], 2))
    initial = weights.copy()
    curve = []
    for epoch in range(epochs+1):
        err = x@weights-labels
        if epoch % 20 == 0: curve.append(dict(epoch=epoch, mse=float(np.mean(err**2))))
        if epoch < epochs:
            penalty = .001*weights
            penalty[-1] = 0
            weights -= learning_rate * (2*x.T@err/len(x)+penalty)
    checkpoint = dict(version=1, mode=mode, seed=seed, epochs=epochs, learningRate=learning_rate,
                      trainingSamples=len(x), featureIndices=indices,
                      featureNames=[feature_names[i] for i in indices], mean=mean.tolist(), scale=scale.tolist(),
                      initialWeights=initial.tolist(), weights=weights.tolist(), curve=curve,
                      method="Supervised imitation; full-batch gradient descent; MSE; L2=0.001",
                      teacher="Camera servo before actuator limits: forward=0.65*(range-1.8); yaw=-1.1*x. Runtime clips to [-0.35,0.65] m/s and +/-0.65 rad/s.",
                      fixed="MaleCNS graph and BrainCore neuron equations. No synaptic plasticity.")
    return checkpoint
