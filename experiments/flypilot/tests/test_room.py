import numpy as np
from flypilot.world import collision_reason

def test_room_guard_includes_panel_edges_floor_and_ceiling():
    assert collision_reason([0,0,1.2],[3,0,1.2]) is None
    assert collision_reason([4.9,0,1.2],[3,0,1.2])=="room boundary"
    assert collision_reason([0,0,.1],[3,0,1.2])=="room boundary"
    assert collision_reason([0,0,2.9],[3,0,1.2])=="room boundary"
    assert collision_reason([2.95,.39,1.55],[3,0,1.2])=="target panel"
    assert collision_reason([2.8,.55,1.2],[3,0,1.2],True)=="occlusion panel"
    assert collision_reason([np.nan,0,1.2],[3,0,1.2])=="invalid physics state"


def test_furnishings_and_target_stand_have_reset_guards():
    assert collision_reason([4.25,0,1.2],[3,0,1.2])=="workbench"
    assert collision_reason([3.35,2.1,1.2],[3,0,1.2])=="window plant"
    assert collision_reason([-.8,2.15,.45],[3,0,1.2])=="storage cabinet"
    assert collision_reason([3,0,.5],[3,0,1.2])=="target stand"
