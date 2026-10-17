import * as THREE from './assets/three.module.js';
export function createAtomicBreath(){
 const group=new THREE.Group();group.visible=false;
 const uniforms={time:{value:0},power:{value:1},tint:{value:new THREE.Color(0x49bcff)}};
 const vertex=`varying vec2 vUv;varying float vR;uniform float time;uniform float power;
 void main(){vUv=uv;vec3 p=position;float z=(position.y+1.1)/2.2;float ripple=1.0+.11*sin(z*45.0-time*22.0)+.08*sin(z*67.0+time*31.0+atan(position.z,position.x)*5.0);float taper=.42+z*.62;p.xz*=ripple*taper;vR=length(p.xz);gl_Position=projectionMatrix*modelViewMatrix*vec4(p,1.0);}`;
 const fragment=`varying vec2 vUv;uniform float time;uniform float power;uniform vec3 tint;
 float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
 void main(){float streams=.55+.45*sin(vUv.x*52.0+vUv.y*45.0-time*20.0);float turbulence=hash(floor(vec2(vUv.x*48.0,vUv.y*50.0-time*16.0)));float end=smoothstep(0.0,.06,vUv.y)*(1.0-smoothstep(.83,1.0,vUv.y));float alpha=(.25+streams*.36+turbulence*.22)*end*power;gl_FragColor=vec4(tint*(1.0+streams*.9),alpha);}`;
 const plume=new THREE.Mesh(new THREE.CylinderGeometry(.19,.19,2.2,40,24,true),new THREE.ShaderMaterial({uniforms,vertexShader:vertex,fragmentShader:fragment,transparent:true,blending:THREE.AdditiveBlending,depthWrite:false,side:THREE.DoubleSide}));plume.rotation.x=Math.PI/2;plume.position.z=1.1;group.add(plume);
 const ribbons=[];for(let j=0;j<4;j++){const material=new THREE.MeshBasicMaterial({color:j?0xb2edff:0xf2fdff,transparent:true,opacity:j?.65:.95,blending:THREE.AdditiveBlending,depthWrite:false});const g=new THREE.CylinderGeometry(j?.018:.047,j?.014:.025,2.1,12,18,true);const mesh=new THREE.Mesh(g,material);mesh.rotation.x=Math.PI/2;mesh.position.z=1.04;group.add(mesh);ribbons.push(mesh);}
 const glowCanvas=document.createElement('canvas');glowCanvas.width=glowCanvas.height=128;const ctx=glowCanvas.getContext('2d');const gradient=ctx.createRadialGradient(64,64,0,64,64,64);gradient.addColorStop(0,'rgba(255,255,255,1)');gradient.addColorStop(.16,'rgba(122,211,255,.8)');gradient.addColorStop(.5,'rgba(36,141,255,.23)');gradient.addColorStop(1,'rgba(0,60,255,0)');ctx.fillStyle=gradient;ctx.fillRect(0,0,128,128);
 const glowMap=new THREE.CanvasTexture(glowCanvas),muzzle=new THREE.Sprite(new THREE.SpriteMaterial({map:glowMap,transparent:true,blending:THREE.AdditiveBlending,depthWrite:false}));muzzle.scale.set(.43,.43,1);muzzle.position.z=.01;group.add(muzzle);
 const light=new THREE.PointLight(0x55bbff,2,2.4);light.position.z=.15;group.add(light);
 const sparks=[];for(let i=0;i<64;i++){const sprite=new THREE.Sprite(new THREE.SpriteMaterial({map:glowMap,transparent:true,blending:THREE.AdditiveBlending,depthWrite:false}));group.add(sprite);sparks.push(sprite)}
 const ringGeo=new THREE.TorusGeometry(.08,.005,6,40),rings=[];for(let i=0;i<7;i++){const ring=new THREE.Mesh(ringGeo,new THREE.MeshBasicMaterial({color:0x81d2ff,transparent:true,opacity:.3,blending:THREE.AdditiveBlending,depthWrite:false}));group.add(ring);rings.push(ring)}
 return {group,update(time,power,form=0,size=1){const burning=form===4;const tint=form===3?0xb54fff:burning?0xff4928:form===2?0x249dff:0x89d8ff;group.scale.setScalar(size);group.visible=power>.01;uniforms.time.value=time;uniforms.power.value=power;uniforms.tint.value.setHex(tint);light.color.setHex(tint);light.intensity=power*3;muzzle.material.color.setHex(tint);muzzle.material.opacity=power;muzzle.scale.setScalar(.22+Math.sin(time*31)*.025);
  ribbons.forEach((mesh,j)=>{mesh.material.color.setHex(j?tint:0xffffff);mesh.material.opacity=(j?.55:.95)*power;mesh.position.x=Math.sin(time*18+j)*.025*j;mesh.position.y=Math.cos(time*15+j)*.02*j;});
  sparks.forEach((s,i)=>{const u=(time*1.6+i/64)%1,z=u*2.2,r=.05+u*.2;s.position.set(Math.sin(i*2.4+time*8)*r,Math.cos(i*3.6+time*7)*r,z);s.scale.setScalar((.05+.07*u)*power);s.material.opacity=(1-u)*power;s.material.color.setHex(tint);});
  rings.forEach((r,i)=>{const u=(time*1.9+i/7)%1;r.position.z=u*2.1;r.scale.setScalar(.5+u*2);r.rotation.z=time*2+i;r.material.color.setHex(tint);r.material.opacity=(1-u)*.25*power;});
 }};
}
