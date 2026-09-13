import numpy as np
from scipy.spatial.transform import Rotation
from flypilot.character import WalkingCharacter
from flypilot.outdoor import contact_vertex,outdoor_sensory


def test_contact_requires_animated_body_in_drone_envelope():
    assert contact_vertex([0,0,1.2],[1,0,0,0],[[.25,0,1.2]])==0
    assert contact_vertex([0,0,1.2],[1,0,0,0],[[.30,0,1.2]]) is None
    assert contact_vertex([0,0,1.2],[1,0,0,0],[[0,0,1.32]]) is None
    q=Rotation.from_euler('y',90,degrees=True).as_quat()
    assert contact_vertex([0,0,1.2],np.r_[q[3],q[:3]],[[0,0,1.44]])==0


def test_walk_is_bounded_repeatable_and_animated():
    character=WalkingCharacter()
    first=character.pose(0)
    middle=character.pose(character.duration*.4)
    np.testing.assert_allclose(character.pose(character.duration),first,atol=1e-8)
    assert 1.7<np.ptp(first[:,2])<1.8
    assert 1.6<np.ptp(middle[:,2])<1.9
    assert np.max(np.abs(middle-first))>.1
    assert np.max(np.abs(middle[:,:2]))<1


def test_game_camera_input_and_loss_gate():
    lost=outdoor_sensory(dict(found=False),'full')
    assert all(value==0 for value in lost.values())
    observation=dict(found=True,distance=4.,x=.5)
    full=outdoor_sensory(observation,'full');simple=outdoor_sensory(observation,'simple')
    assert full['visualLeft']<full['visualRight']
    assert full['odorLeft']==0
    assert simple['visualLeft']==0
    assert simple['odorRight']==full['visualRight']
