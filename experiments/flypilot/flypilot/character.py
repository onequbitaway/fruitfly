"""Animate the credited Mixamo game character with glTF linear skinning.

This is a scripted fictional character. Its animation is not a brain output.
"""
import json
import struct
import numpy as np
from scipy.spatial.transform import Rotation
from .brain import ROOT

class WalkingCharacter:
    def __init__(self):
        self.path=ROOT/'assets/Soldier/Soldier.glb'
        raw=self.path.read_bytes();length=struct.unpack_from('<I',raw,12)[0]
        self.data=json.loads(raw[20:20+length]);self.blob=raw[28+length:]
        vertices=[];joints=[];weights=[];faces=[];materials=[];uvs=[];offset=0
        self.skins=self.data['skins'];self.inverses=[self.accessor(skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1) for skin in self.skins]
        skin_offsets=np.cumsum([0]+[len(skin['joints']) for skin in self.skins])
        for node in self.data['nodes']:
            if 'mesh' not in node:continue
            for primitive in self.data['meshes'][node['mesh']]['primitives']:
                attributes=primitive['attributes'];v=self.accessor(attributes['POSITION'])
                vertices.append(v);joints.append(self.accessor(attributes['JOINTS_0']).astype(int)+skin_offsets[node['skin']]);weights.append(self.accessor(attributes['WEIGHTS_0']))
                uvs.append(self.accessor(attributes['TEXCOORD_0']))
                f=self.accessor(primitive['indices']).reshape(-1,3).astype(int)+offset;faces.append(f)
                materials.extend([primitive['material']]*len(f));offset+=len(v)
        self.vertices=np.concatenate(vertices);self.joints=np.concatenate(joints);self.weights=np.concatenate(weights)
        self.faces=np.concatenate(faces);self.materials=np.array(materials);self.uv=np.concatenate(uvs)
        self.animation=next(a for a in self.data['animations'] if a.get('name')=='Walk')
        self.clips={}
        for animation in self.data['animations']:
            channels=[]
            for channel in animation['channels']:
                sampler=animation['samplers'][channel['sampler']]
                channels.append((channel['target']['node'],channel['target']['path'],self.accessor(sampler['input']).ravel(),self.accessor(sampler['output'])))
            self.clips[animation['name']]=(channels,max(float(c[2][-1]) for c in channels))
        self.channels,self.duration=self.clips['Walk']
        self.scale=1.;self.horizontal_origin=np.zeros(2)
        initial=self.pose(0);self.scale=1.76/np.ptp(initial[:,2]);initial=self.pose(0)
        self.horizontal_origin=initial[:,:2].mean(axis=0);initial=self.pose(0)
        self.floor=float(initial[:,2].min());self.reorder=None
        self.asset=ROOT/'runs/generated/walking-character.obj';self.asset.parent.mkdir(parents=True,exist_ok=True)
        definitions=[]
        for i,material in enumerate(self.data['materials']):
            color=material.get('pbrMetallicRoughness',{}).get('baseColorFactor',[.5,.5,.5,1])[:3]
            definition='newmtl material'+str(i)+'\nKd '+' '.join(map(str,color))+'\n'
            if texture:=material.get('pbrMetallicRoughness',{}).get('baseColorTexture'):
                image=self.data['images'][self.data['textures'][texture['index']]['source']]
                view=self.data['bufferViews'][image['bufferView']];texture_path=self.asset.parent/f'character-material-{i}.jpg'
                texture_path.write_bytes(self.blob[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']])
                definition+='map_Kd '+texture_path.name+'\n'
            definitions.append(definition)
        self.asset.with_suffix('.mtl').write_text(''.join(definitions))
        lines=['mtllib '+self.asset.with_suffix('.mtl').name]
        lines += ['v '+' '.join(map(str,p)) for p in initial]
        lines += ['vt '+str(p[0])+' '+str(1-p[1]) for p in self.uv]
        previous=None
        for face,material in zip(self.faces,self.materials):
            if previous!=material:lines.append('usemtl material'+str(material));previous=material
            lines.append('f '+' '.join(f'{i+1}/{i+1}' for i in face))
        self.asset.write_text('\n'.join(lines)+'\n')

    def accessor(self,index):
        a=self.data['accessors'][index];view=self.data['bufferViews'][a['bufferView']]
        dtype={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']]
        n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
        offset=view.get('byteOffset',0)+a.get('byteOffset',0)
        size=np.dtype(dtype).itemsize
        return np.ndarray((a['count'],n),dtype=dtype,buffer=self.blob,offset=offset,strides=(view.get('byteStride',n*size),size)).copy()

    def pose(self,time,clip='Walk'):
        values={}
        channels,duration=self.clips[clip]
        t=time%duration
        for node,path,times,outputs in channels:
            k=min(max(int(np.searchsorted(times,t))-1,0),len(times)-2)
            f=np.clip((t-times[k])/max(1e-9,times[k+1]-times[k]),0,1)
            a,b=outputs[k],outputs[k+1]
            if path=='rotation':
                if np.dot(a,b)<0:b=-b
                q=(1-f)*a+f*b;value=q/np.linalg.norm(q)
            else:value=(1-f)*a+f*b
            values[(node,path)]=value
        local=[]
        for i,node in enumerate(self.data['nodes']):
            if 'matrix' in node:m=np.array(node['matrix']).reshape(4,4).T
            else:
                m=np.eye(4);m[:3,:3]=Rotation.from_quat(values.get((i,'rotation'),node.get('rotation',[0,0,0,1]))).as_matrix()@np.diag(values.get((i,'scale'),node.get('scale',[1,1,1])))
                m[:3,3]=values.get((i,'translation'),node.get('translation',[0,0,0]))
            local.append(m)
        global_m={}
        def visit(i,parent):
            global_m[i]=parent@local[i]
            for child in self.data['nodes'][i].get('children',[]):visit(child,global_m[i])
        for root in self.data['scenes'][self.data.get('scene',0)]['nodes']:visit(root,np.eye(4))
        skin=np.stack([global_m[j]@inverse[k] for source,inverse in zip(self.skins,self.inverses) for k,j in enumerate(source['joints'])])
        transforms=(skin[self.joints]*self.weights[:,:,None,None]).sum(axis=1)
        homogeneous=np.column_stack([self.vertices,np.ones(len(self.vertices))])
        points=np.einsum('nij,nj->ni',transforms,homogeneous)[:,:3]
        # glTF Y up to room Z up. Rotate to walk along the street's +X axis.
        points=points[:,[0,2,1]]*np.array([1,-1,1])*self.scale
        points=points@Rotation.from_euler("z",270,degrees=True).as_matrix().T
        points[:,:2]-=self.horizontal_origin
        return points

    def bind(self,entity):
        from scipy.spatial import cKDTree
        self.entity=entity
        actual=entity.get_vverts().detach().cpu().numpy().reshape(-1,3)
        distances,self.reorder=cKDTree(self.pose(0)).query(actual)
        if np.max(distances)>2e-5:raise RuntimeError('Character vertex order could not be verified.')

    def update(self,time,position,heading=0,reaction=0):
        points=self.pose(time)
        if reaction:
            settled=self.pose(0,'Idle');points=(1-reaction)*points+reaction*settled
        points[:,2]-=float(points[:,2].min())
        if reaction:
            pivot=np.array([0,0,.95]);points=(points-pivot)@Rotation.from_euler('y',-.22*reaction).as_matrix().T+pivot
        points[:,2]-=float(points[:,2].min())
        points=points@Rotation.from_euler('z',heading).as_matrix().T+position
        self.entity.set_vverts(points[self.reorder])
        return points
