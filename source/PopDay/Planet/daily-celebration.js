import * as T from './assets/three.module.js';
import {BREATH_START,roarSequence} from './completion-sequence.js';
export const CELEBRATION_END=16;
export function celebrationPhase(time){return time<1.25?'evolve':time<2.5?'rise':time<8.5?'breath':time<CELEBRATION_END?'eruption':'finished';}
export function createDailyCelebration(globe,normal,forward,makeTower,reduced=false){
 const group=new T.Group();globe.add(group);const towers=[];const sideways=new T.Vector3().crossVectors(normal,forward).normalize();
 for(let i=0;i<36;i++){
  const row=Math.floor(i/9),column=i%9,angle=(column-4)*.14;
  const direction=forward.clone().applyAxisAngle(normal,angle),arc=.46+row*.095;
  const n=normal.clone().multiplyScalar(Math.cos(arc)).addScaledVector(direction,Math.sin(arc)).normalize();
  const g=makeTower({id:'celebration-'+i,reward:[10,20,40][i%3],done:false},Math.asin(n.y),Math.atan2(n.x,n.z),true);group.add(g);
  towers.push({g,height:(.8+(i%5)*.18)*g.scale.y,hit:false});g.scale.y=.001;g.visible=!reduced;
 }
 const geometry=new T.BufferGeometry(),positions=new Float32Array(2400*3),colors=new Float32Array(2400*3);geometry.setAttribute('position',new T.BufferAttribute(positions,3));geometry.setAttribute('color',new T.BufferAttribute(colors,3));
 let glow=null;if(typeof document!=='undefined'){const canvas=document.createElement('canvas');canvas.width=canvas.height=32;const ctx=canvas.getContext('2d'),gradient=ctx.createRadialGradient(16,16,0,16,16,16);gradient.addColorStop(0,'rgba(255,255,255,1)');gradient.addColorStop(.25,'rgba(255,255,255,.8)');gradient.addColorStop(1,'rgba(255,255,255,0)');ctx.fillStyle=gradient;ctx.fillRect(0,0,32,32);glow=new T.CanvasTexture(canvas);}
 const material=new T.PointsMaterial({map:glow,size:.08,vertexColors:true,transparent:true,blending:T.AdditiveBlending,depthWrite:false});const stars=new T.Points(geometry,material);stars.frustumCulled=false;group.add(stars);let particles=[];
 const volcanoes=[],basalt=new T.MeshStandardMaterial({color:0x292321,roughness:1}),lava=new T.MeshStandardMaterial({color:0xff5b12,emissive:0xff3500,emissiveIntensity:2,roughness:.7});
 const coneGeometry=new T.CylinderGeometry(.12,.46,.58,16,1,true),rimGeometry=new T.TorusGeometry(.12,.035,6,16),coreGeometry=new T.CircleGeometry(.115,16);
 for(let i=0;i<6;i++){
   const direction=forward.clone().applyAxisAngle(normal,((i%3)-1)*.44),arc=.35+Math.floor(i/3)*.32;
   const n=normal.clone().multiplyScalar(Math.cos(arc)).addScaledVector(direction,Math.sin(arc)).normalize();
   const g=new T.Group();g.position.copy(n).multiplyScalar(4.5);g.quaternion.setFromUnitVectors(new T.Vector3(0,1,0),n);group.add(g);g.visible=false;
   const cone=new T.Mesh(coneGeometry,basalt);cone.position.y=.29;g.add(cone);
   const rim=new T.Mesh(rimGeometry,lava);rim.rotation.x=Math.PI/2;rim.position.y=.58;g.add(rim);
   const core=new T.Mesh(coreGeometry,lava);core.rotation.x=-Math.PI/2;core.position.y=.57;g.add(core);
   for(let k=0;k<4;k++){
     const a=k*Math.PI/2+i*.5,points=[new T.Vector3(.12*Math.cos(a),.58,.12*Math.sin(a)),new T.Vector3(.27*Math.cos(a),.29,.27*Math.sin(a)),new T.Vector3(.47*Math.cos(a),.025,.47*Math.sin(a))];
     g.add(new T.Mesh(new T.TubeGeometry(new T.CatmullRomCurve3(points),8,.018,4,false),lava));
   }
   volcanoes.push({g,normal:n,origin:n.clone().multiplyScalar(5.1),start:7.8+i*.18,carry:0});
 }
 function lavaJet(volcano,count){
   for(let i=0;i<count;i++){
     const sideways=new T.Vector3(Math.random()-.5,Math.random()-.5,Math.random()-.5).projectOnPlane(volcano.normal).multiplyScalar(.9);
     const velocity=volcano.normal.clone().multiplyScalar(2.1+Math.random()*.9).add(sideways);
     particles.push({p:volcano.origin.clone(),v:velocity,c:new T.Color(i%3===0?0xffc43b:0xff4d0a),life:1.7+Math.random()*.4,gravity:volcano.normal});
   }
 }
 function burst(origin,color,count,speed,life){for(let i=0;i<count;i++){const v=new T.Vector3(Math.random()-.5,Math.random()-.5,Math.random()-.5).normalize().multiplyScalar(speed*(.4+Math.random()*.6));particles.push({p:origin.clone(),v,c:new T.Color(color),life,max:life});}}
 function update(time,dt){
  for(let i=0;i<towers.length;i++){
   const item=towers[i],rise=T.MathUtils.smoothstep(time,1.25+(i%9)*.035,2.5);
   const hitAt=2.5+BREATH_START+.22+i*.075;
   item.g.scale.y=Math.max(.001,rise*item.height);
   if(time>=hitAt&&!item.hit){item.hit=true;item.g.visible=false;if(!reduced)burst(item.g.position.clone().addScaledVector(item.g.position.clone().normalize(),.25),0xff944b,18,.65,1.4);}
  }
  for(const volcano of volcanoes){
   volcano.g.visible=time>=7.1;
   volcano.g.scale.setScalar(Math.max(.001,T.MathUtils.smoothstep(time,7.1,7.8)));
   if(!reduced&&time>=volcano.start&&time<14){volcano.carry+=dt*48;const count=Math.floor(volcano.carry);volcano.carry-=count;if(count)lavaJet(volcano,count);}
  }
  particles=particles.filter(p=>{if(!reduced){p.life-=dt;p.v.addScaledVector(p.gravity??normal,-dt*(p.gravity?3.4:.35));p.p.addScaledVector(p.v,dt);}return p.life>0;});
  particles.slice(0,2400).forEach((p,i)=>{p.p.toArray(positions,i*3);const fade=Math.min(1,p.life/.6);colors[i*3]=p.c.r*fade;colors[i*3+1]=p.c.g*fade;colors[i*3+2]=p.c.b*fade;});geometry.setDrawRange(0,Math.min(2400,particles.length));geometry.attributes.position.needsUpdate=true;geometry.attributes.color.needsUpdate=true;
  return {remaining:towers.filter(t=>!t.hit).length,finished:time>=CELEBRATION_END,roarTime:Math.max(0,time-2.5),power:!reduced&&time>=2.5?roarSequence(time-2.5).power:0,note:time>=7.6,volcanoes:volcanoes.filter(v=>v.g.visible).length,lavaParticles:particles.filter(p=>p.gravity).length};
 }
 function aim(time){const progress=T.MathUtils.clamp((time-2.5-BREATH_START)/2.7,0,1);const index=Math.min(35,Math.floor(progress*36));return towers[index].g.position.clone().addScaledVector(towers[index].g.position.clone().normalize(),.25);}
 function dispose(){globe.remove(group);group.traverse(o=>{if(o.geometry&&!o.geometry.userData.shared)o.geometry.dispose();});material.dispose();basalt.dispose();lava.dispose();glow?.dispose();particles=[];}
 const framingPoints=[...towers.flatMap(({g,height})=>[g.position.clone(),g.position.clone().addScaledVector(g.position.clone().normalize(),Math.max(1.8,.7*height))]),...volcanoes.flatMap(v=>[v.g.position.clone(),v.origin.clone().addScaledVector(v.normal,1.8)])];
 return {update,aim,dispose,framingPoints};
}
