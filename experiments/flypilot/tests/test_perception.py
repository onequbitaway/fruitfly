from pathlib import Path
import cv2
import numpy as np
from flypilot.perception import PortraitMatcher

def test_match_camera_pixels_and_range():
    rgb=cv2.cvtColor(cv2.imread(str(Path(__file__).parent/"fixtures/portrait-camera.png")),cv2.COLOR_BGR2RGB)
    matcher=PortraitMatcher()
    result=matcher.measure(rgb)
    assert result["found"]
    assert 2.5<result["distance"]<2.9
    assert .03<result["x"]<.1
    assert matcher.measure(np.full_like(rgb,100))["found"] is False
    hidden=rgb.copy()
    hidden[120:240,190:320]=100
    assert matcher.measure(hidden)["found"] is False

def test_unrelated_texture_is_not_reference():
    rng=np.random.default_rng(19)
    image=rng.integers(0,256,(360,480,3),dtype=np.uint8)
    assert PortraitMatcher().measure(image)["found"] is False
