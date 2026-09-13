"""Reference portrait matching. Receives pixels and camera calibration only."""
from __future__ import annotations
import cv2
import numpy as np
from .brain import ROOT

class PortraitMatcher:
    def __init__(self, reference=None, panel_width=0.8, fov=60, resolution=(480, 360)):
        self.path = reference or ROOT / "assets/portrait.png"
        self.reference = cv2.imread(str(self.path))
        if self.reference is None:
            raise ValueError("The reference image could not be read.")
        self.gray = cv2.resize(cv2.cvtColor(self.reference, cv2.COLOR_BGR2GRAY), (192,192))
        self.orb = cv2.ORB_create(nfeatures=1800, scaleFactor=1.15, nlevels=12,
                                edgeThreshold=8, patchSize=15, fastThreshold=7)
        self.keys, self.descriptors = self.orb.detectAndCompute(self.gray, None)
        if self.descriptors is None or len(self.keys) < 15:
            raise ValueError("The reference image needs more visible detail.")
        self.matcher = cv2.BFMatcher(cv2.NORM_HAMMING)
        self.width = panel_width
        self.fx = resolution[1] / (2 * np.tan(np.deg2rad(fov / 2)))
        self.intrinsics=np.array([[self.fx,0,resolution[0]/2],[0,self.fx,resolution[1]/2],[0,0,1]],dtype=float)

    def measure(self, rgb):
        h, w = rgb.shape[:2]
        gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)
        keys, desc = self.orb.detectAndCompute(gray, None)
        empty = dict(found=False, x=0.0, distance=0.0, confidence=0.0, box=None)
        if desc is None or len(keys) < 8: return empty
        matches = self.matcher.knnMatch(self.descriptors, desc, k=2)
        good = [pair[0] for pair in matches if len(pair) == 2 and pair[0].distance < .73 * pair[1].distance]
        if len(good) < 9: return empty
        src = np.float32([self.keys[m.queryIdx].pt for m in good])
        dst = np.float32([keys[m.trainIdx].pt for m in good])
        cv2.setRNGSeed(0)
        H, mask = cv2.findHomography(src, dst, cv2.RANSAC, 3.0)
        if H is None or mask is None: return empty
        inliers = int(mask.sum())
        if inliers < 8 or inliers / len(good) < .45: return empty
        rh, rw = self.gray.shape
        corners = np.float32([[0, 0], [rw-1, 0], [rw-1, rh-1], [0, rh-1]])
        box = cv2.perspectiveTransform(corners[None], H)[0]
        if not np.isfinite(box).all() or not cv2.isContourConvex(box): return empty
        area = cv2.contourArea(box)
        if area < 250 or area > w*h*.85: return empty
        sides = np.linalg.norm(np.roll(box, -1, axis=0) - box, axis=1)
        if min(sides) < 10 or max(sides) / min(sides) > 3: return empty
        center = box.mean(axis=0)
        if not (0 <= center[0] < w and 0 <= center[1] < h): return empty
        # Recover range from the known square and camera calibration. Apparent
        # width alone overestimates range when the camera sees the panel obliquely.
        a=self.width/2
        object_points=np.float32([[-a,a,0],[a,a,0],[a,-a,0],[-a,-a,0]])
        ok,rvec,tvec=cv2.solvePnP(object_points,box,self.intrinsics,None,flags=cv2.SOLVEPNP_IPPE)
        if not ok or tvec[2,0]<=0: return empty
        projected,_=cv2.projectPoints(object_points,rvec,tvec,self.intrinsics,None)
        if np.mean(np.linalg.norm(projected[:,0]-box,axis=1))>3: return empty
        distance=float(np.linalg.norm(tvec))
        if not .4<distance<8: return empty
        return dict(found=True, x=float((center[0] - w/2)/(w/2)),
                    distance=distance,
                    confidence=float(inliers/len(good)), inliers=inliers, box=box.tolist())

def teacher(observation):
    """Conventional camera servo. Used only for imitation labels and baseline."""
    if not observation["found"]: return np.zeros(2)
    return np.array([np.clip(.65*(observation["distance"]-1.8), -.35, .65),
                     np.clip(-1.1*observation["x"], -.65, .65)])
