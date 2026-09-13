"""Original, deterministic game VFX. These effects do not alter flight physics."""
import math
import bpy
import numpy as np
from mathutils import Vector


def solid(name,color,roughness=.65,metallic=0):
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    shader=mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=(*color,1)
    shader.inputs['Roughness'].default_value=roughness
    shader.inputs['Metallic'].default_value=metallic
    return mat


def sphere(name,material):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1)
    obj=bpy.context.object;obj.name=name;obj.data.materials.append(material)
    for face in obj.data.polygons:face.use_smooth=True
    obj.hide_render=True
    return obj


def smoke_material(name):
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    nodes=mat.node_tree.nodes;nodes.clear();links=mat.node_tree.links
    out=nodes.new('ShaderNodeOutputMaterial');volume=nodes.new('ShaderNodeVolumePrincipled')
    volume.inputs['Color'].default_value=(.055,.042,.033,1)
    volume.inputs['Emission Color'].default_value=(1,.16,.013,1)
    volume.inputs['Anisotropy'].default_value=.15
    coords=nodes.new('ShaderNodeTexCoord');noise=nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value=5;noise.inputs['Detail'].default_value=4
    links.new(coords.outputs['Generated'],noise.inputs['Vector'])
    radius=nodes.new('ShaderNodeVectorMath');radius.operation='DISTANCE';radius.inputs[1].default_value=(.5,.5,.5)
    links.new(coords.outputs['Generated'],radius.inputs[0])
    fall=nodes.new('ShaderNodeMapRange');fall.clamp=True
    for key,value in [('From Min',.18),('From Max',.5),('To Min',1),('To Max',0)]:fall.inputs[key].default_value=value
    links.new(radius.outputs['Value'],fall.inputs['Value'])
    shape=nodes.new('ShaderNodeMath');shape.operation='MULTIPLY'
    billows=nodes.new('ShaderNodeValToRGB')
    billows.color_ramp.elements[0].position=.38;billows.color_ramp.elements[1].position=.65
    links.new(noise.outputs['Fac'],billows.inputs['Fac'])
    links.new(fall.outputs['Result'],shape.inputs[0]);links.new(billows.outputs['Color'],shape.inputs[1])
    density=nodes.new('ShaderNodeMath');density.operation='MULTIPLY';density.inputs[1].default_value=8
    links.new(shape.outputs[0],density.inputs[0]);links.new(density.outputs[0],volume.inputs['Density'])
    fire=nodes.new('ShaderNodeMath');fire.operation='MULTIPLY'
    links.new(shape.outputs[0],fire.inputs[0]);links.new(fire.outputs[0],volume.inputs['Emission Strength'])
    links.new(volume.outputs['Volume'],out.inputs['Volume'])
    return mat,fire,density,noise


class CombatEffects:
    def __init__(self,contact):
        self.contact=contact;self.origin=np.array(contact['position']);self.rng=np.random.default_rng(720)
        self.clouds=[]
        for i in range(5):
            mat,fire,density,noise=smoke_material('Blast smoke '+str(i))
            obj=sphere('Blast cloud '+str(i),mat)
            offset=self.rng.normal(0,.28,3);offset[2]=abs(offset[2])
            self.clouds.append((obj,offset,fire,density,noise))
        self.blood=[];blood=solid('Dark red blood',(.045,.0007,.001),.4)
        for i in range(60):
            obj=sphere('Blood spray '+str(i),blood)
            velocity=np.array([self.rng.uniform(.6,3.4),self.rng.uniform(-2.2,1.8),self.rng.uniform(.2,3.8)])
            size=self.rng.uniform(.012,.038)
            self.blood.append((obj,velocity,size))
        self.fragments=[]
        self.sparks=[]
        spark_mat=solid('Hot sparks',(1,.18,.015),.25)
        spark_shader=spark_mat.node_tree.nodes.get('Principled BSDF')
        spark_shader.inputs['Emission Color'].default_value=(1,.23,.015,1)
        spark_shader.inputs['Emission Strength'].default_value=10
        for i in range(26):
            obj=sphere('Spark '+str(i),spark_mat)
            velocity=self.rng.normal(0,2.7,3);velocity[2]=abs(velocity[2])
            self.sparks.append((obj,velocity))
        wreck=solid('Drone wreck',(.09,.085,.07),.8,.2)
        shell=solid('Broken shell',(.43,.40,.35),.65,.1)
        for i in range(22):
            bpy.ops.mesh.primitive_cube_add(size=1)
            obj=bpy.context.object;obj.name='Drone fragment '+str(i);obj.data.materials.append(shell if i%3 else wreck)
            obj.hide_render=True;obj.scale=self.rng.uniform(.025,.1,3)*[1,1,.25]
            velocity=self.rng.normal(0,1.6,3);velocity[2]=self.rng.uniform(1,3)
            self.fragments.append((obj,velocity,self.rng.normal(0,4,3)))
        self.stains=[]
        for i in range(24):
            obj=sphere('Blood stain '+str(i),blood)
            for vertex in obj.data.vertices:
                angle=math.atan2(vertex.co.y,vertex.co.x)
                irregular=1+.18*math.sin(5*angle+i)+.11*math.cos(9*angle-i)
                vertex.co.x*=irregular;vertex.co.y*=irregular
            offset=np.array([self.rng.normal(1.1,.5),self.rng.normal(0,.35),0])
            scale=self.rng.uniform(.06,.23,2)
            self.stains.append((obj,offset,scale))
        bpy.ops.object.light_add(type='POINT',location=self.origin)
        self.flash=bpy.context.object;self.flash.name='Explosion flash';self.flash.data.color=(1,.24,.045);self.flash.data.shadow_soft_size=.8
        self.flash.data.energy=0

    def update(self,time):
        tau=time-self.contact['time'];active=tau>=-1e-7;tau=max(0,tau)
        for i,(obj,offset,fire,density,noise) in enumerate(self.clouds):
            obj.hide_render=not active
            growth=.12+.62*(1-math.exp(-tau*8))
            obj.location=self.origin+offset*(1+tau*.6)+[tau*.18,0,tau*.7]
            obj.scale=np.array([1,.9,1.1])*(growth+tau*.18)*(1+(i%3)*.12)
            obj.rotation_euler=(tau*.25,i*.7,tau*.3)
            fire.inputs[1].default_value=12*math.exp(-tau*12)*(1+.15*(i%2)) if active else 0
            density.inputs[1].default_value=5*math.exp(-tau*.75)
            noise.inputs['Scale'].default_value=5+tau*2
        self.flash.data.energy=2200*math.exp(-tau*14) if active else 0
        for obj,velocity in self.sparks:
            obj.hide_render=not active or tau>.5
            obj.location=self.origin+velocity*tau+[0,0,-3*tau*tau]
            obj.scale=(.008,.008,.045)
            obj.rotation_euler=Vector(velocity).to_track_quat('Z','Y').to_euler()
        for obj,velocity,size in self.blood:
            position=self.origin+np.array([.18,0,.12])+velocity*tau+[0,0,-3.3*tau*tau]
            obj.hide_render=bool(not active or position[2]<.145 or tau>1.3)
            obj.location=position;obj.scale=(size,size,size*2.5)
            direction=Vector(velocity+[0,0,-6.6*tau]);obj.rotation_euler=direction.to_track_quat('Z','Y').to_euler()
        for obj,velocity,spin in self.fragments:
            position=self.origin+velocity*tau+[0,0,-4.9*tau*tau]
            position[2]=max(.15,position[2]);obj.location=position
            obj.rotation_euler=spin*min(tau,.7);obj.hide_render=not active
        for obj,offset,scale in self.stains:
            obj.hide_render=not active or tau<.28
            obj.location=self.origin+offset;obj.location.z=.143
            growth=min(1,max(0,(tau-.28)*2))
            obj.scale=(scale[0]*growth,scale[1]*growth,.004)

    def fallen_vertices(self,vertices,time):
        tau=time-self.contact['time']
        if tau<=0:return vertices
        fraction=min(1,tau/.72);ease=fraction*fraction*(3-2*fraction)
        angle=1.53*ease
        c,s=math.cos(angle),math.sin(angle)
        rotation=np.array([[c,0,s],[0,1,0],[-s,0,c]])
        center=np.array(self.contact['characterPoint']);center[2]=.93
        points=(vertices-center)@rotation.T+center+[.62*ease,.12*ease,0]
        # Keep the posed body above the pavement. This is a programmed fall.
        points[:,2]-=(float(points[:,2].min())-.15)*ease
        # Settle the posed limbs against the ground during the final part of the fall.
        points[:,2]=.15+(points[:,2]-.15)*(1-.48*ease)
        return points
