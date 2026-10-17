import * as THREE from './assets/three.module.js';
import {createKaiju} from './imported-kaiju.js';
import {createAtomicBreath} from './atomic-breath.js';
import {SphereNavigator,taskLocation,FORM_SIZES,cameraDistance} from './sphere-navigation.js';
import {WALK_SPEED,COMPLETION_SPEED,roarSequence} from './completion-sequence.js';
import {createDailyCelebration,celebrationPhase} from './daily-celebration.js';
import {idleShot} from './idle-camera.js';
import {createFrameClock} from './frame-clock.js';
import {dragOrbit} from './free-orbit.js';
import {celebrationShot} from './celebration-camera.js';
const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches;
const radius=4.5;
const BUILDING_SCALE=1.2,BUILDING_RADIUS=.18*BUILDING_SCALE;
function point(lat,lon,r=radius){return new THREE.Vector3(Math.cos(lat)*Math.sin(lon)*r,Math.sin(lat)*r,Math.cos(lat)*Math.cos(lon)*r)}
function worldTexture(){const c=document.createElement('canvas');c.width=1024;c.height=512;const g=c.getContext('2d');g.fillStyle='#176da4';g.fillRect(0,0,1024,512);g.strokeStyle='#277eae';g.lineWidth=1;for(let x=0;x<1024;x+=64){g.beginPath();g.moveTo(x,0);g.lineTo(x,512);g.stroke()}for(let y=0;y<512;y+=64){g.beginPath();g.moveTo(0,y);g.lineTo(1024,y);g.stroke()}g.fillStyle='#4e985b';const land=[[[80,70],[220,55],[290,110],[245,185],[178,225],[143,169],[70,147]],[[229,237],[296,256],[320,324],[277,441],[237,374],[210,283]],[[439,102],[532,75],[604,100],[606,180],[547,198],[492,143]],[[505,191],[613,211],[635,290],[570,381],[519,323],[479,245]],[[605,89],[785,57],[939,112],[908,211],[808,241],[743,190],[665,210]],[[817,326],[914,304],[958,358],[897,394],[821,378]]];land.forEach(p=>{g.beginPath();p.forEach(([x,y],i)=>i?g.lineTo(x,y):g.moveTo(x,y));g.closePath();g.fill()});const tex=new THREE.CanvasTexture(c);tex.colorSpace=THREE.SRGBColorSpace;return tex}
const mat=(color,extra={})=>new THREE.MeshStandardMaterial({color,roughness:.8,...extra});
function box(w,h,d,material){return new THREE.Mesh(new THREE.BoxGeometry(w,h,d),material)}
function label(text){const c=document.createElement('canvas');c.width=256;c.height=64;const g=c.getContext('2d');g.font='600 27px -apple-system,sans-serif';g.textAlign='center';g.fillStyle='#edeef1';g.fillText(text,128,42);const m=new THREE.SpriteMaterial({map:new THREE.CanvasTexture(c),transparent:true,depthTest:true});const sprite=new THREE.Sprite(m);sprite.scale.set(.56,.14,1);return sprite}
async function start(host,mini=false){
 const scene=new THREE.Scene(),camera=new THREE.PerspectiveCamera(43,1,.1,50);
 const renderer=new THREE.WebGLRenderer({alpha:true,antialias:true,preserveDrawingBuffer:false});renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));host.append(renderer.domElement);
 const globe=new THREE.Group();scene.add(globe);
 scene.add(new THREE.HemisphereLight(0xe6eeff,0x454550,2.5));const sun=new THREE.DirectionalLight(0xffffff,3);sun.position.set(-3,7,4);scene.add(sun);
 globe.add(new THREE.Mesh(new THREE.SphereGeometry(radius,64,40),mat(0xffffff,{map:worldTexture()})));
 const buildings=new THREE.Group();globe.add(buildings);
 const facades=[mat(0x919ba7),mat(0x58616f),mat(0x727e8d)],roof=mat(0xc2cad3),glass=mat(0xc3d4e5,{emissive:0x627e98,emissiveIntensity:.35});
 function tower(task,lat,lon,decor=false){const g=new THREE.Group();g.scale.setScalar(BUILDING_SCALE);g.position.copy(point(lat,lon));g.quaternion.setFromUnitVectors(new THREE.Vector3(0,1,0),g.position.clone().normalize());g.userData={task,lat,lon,decor};buildings.add(g);const h=task.reward>=40?.60:task.reward>=20?.38:.22;const w=.21;
 if(task.done){for(let k=0;k<4;k++){const block=box(.09,.06,.09,facades[1]);block.position.set((k%2-.5)*.13,.04,(Math.floor(k/2)-.5)*.12);block.rotation.z=(k-1)*.25;g.add(block)}}else{const block=box(w,h,w,facades[task.reward%3]);block.position.y=h/2;g.add(block);const cap=box(w+.018,.024,w+.018,roof);cap.position.y=h;g.add(cap);const windowMatrices=[];for(let y=.075;y<h-.02;y+=.08)for(let x=-.06;x<.08;x+=.06){windowMatrices.push(new THREE.Matrix4().makeTranslation(x,y,w/2+.004));windowMatrices.push(new THREE.Matrix4().makeRotationY(Math.PI/2).setPosition(w/2+.004,y,x));}if(windowMatrices.length){const geometry=new THREE.BoxGeometry(.03,.038,.004);const windows=new THREE.InstancedMesh(geometry,glass,windowMatrices.length);windowMatrices.forEach((matrix,i)=>windows.setMatrixAt(i,matrix));g.add(windows);}const equipment=box(.07,.055,.09,facades[1]);equipment.position.set(.025,h+.04,0);g.add(equipment);}
 if(!mini&&!decor){const l=label(task.reward+' XP');l.position.y=h+.16;g.add(l)}return g;}
 let pendingTasks=[];const locations=new Map();
 function location(id){if(!locations.has(id)){let n;for(let salt=0;salt<100;salt++){n=taskLocation(id,salt);if(n.angleTo(point(.96,-.4,1))>.45&&[...locations.values()].every(other=>n.angleTo(other)>.32))break;}locations.set(id,n);}return locations.get(id);}
 function taskTower(task){const n=location(task.id);return tower(task,Math.asin(n.y),Math.atan2(n.x,n.z));}
 function rebuild(){const tasks=window.planetState().tasks;const known=new Set(tasks.map(t=>t.id));pendingTasks=pendingTasks.filter(e=>!e.id||known.has(e.id));if(target&&target.userData.task.id!=="preview"&&!known.has(target.userData.task.id)){buildings.remove(target);target=null;attack=null;}if(window.planetState().celebration?.valid===false){celebrationPending=false;if(celebration)finishCelebration();}const ids=new Set(tasks.filter(t=>!t.done).map(t=>t.id));for(const b of [...buildings.children])if(!ids.has(b.userData.task.id)&&b!==target&&!pendingTasks.some(t=>t.id===b.userData.task.id))buildings.remove(b);tasks.forEach((t,i)=>{if(!t.done&&!buildings.children.some(b=>b.userData.task.id===t.id))taskTower(t);});}
 // Subscribe after the attack state is initialized below.
 const kaiju=new THREE.Group(),model=await createKaiju();kaiju.add(model.root);globe.add(kaiju);
 const shadow=new THREE.Mesh(new THREE.CircleGeometry(.22,24),new THREE.MeshBasicMaterial({color:0x101318,transparent:true,opacity:.3}));shadow.rotation.x=-Math.PI/2;shadow.position.y=.012;kaiju.add(shadow);
 const breath=createAtomicBreath();model.muzzle.add(breath.group);
 let form=0,lastForm=-1,travel=0,last=0,attack=null,target=null,particles=[],celebration=null,celebrationPending=false;
 const anchor=point(.96,-.4,1),navigator=new SphereNavigator(anchor,radius);
 const viewTangent=new THREE.Vector3(2.8,7.1,8.6).projectOnPlane(anchor).normalize();
 const cameraFocus=new THREE.Vector3();
 let cameraInitialized=false,drag=null,manualOverride=false,framingShift=0,centerTracking=false;
 const orbit=new THREE.Spherical(),manualOrientation=new THREE.Quaternion(),manualFocus=new THREE.Vector3();
 const canvas=renderer.domElement;
 canvas.addEventListener('dblclick',e=>{
   if(celebration)return;
   const bounds=canvas.getBoundingClientRect(),pointer=new THREE.Vector2((e.clientX-bounds.left)/bounds.width*2-1,1-(e.clientY-bounds.top)/bounds.height*2);
   camera.updateMatrixWorld(true);globe.updateMatrixWorld(true);
   const ray=new THREE.Raycaster();ray.setFromCamera(pointer,camera);
   if(!ray.intersectObject(globe.children[0],false).length)return;
   drag=null;manualOverride=false;centerTracking=true;orbit.radius=Math.max(13,radius+cameraDistance(form,camera.aspect));
 });
 canvas.addEventListener('pointerdown',e=>{if(e.button!==0||attack||celebration)return;if(!manualOverride){manualOrientation.copy(camera.quaternion);manualFocus.copy(cameraFocus);orbit.radius=camera.position.distanceTo(cameraFocus);}manualOverride=true;centerTracking=false;drag={x:e.clientX,y:e.clientY};canvas.setPointerCapture(e.pointerId);});
 canvas.addEventListener('pointermove',e=>{if(!drag)return;dragOrbit(manualOrientation,e.clientX-drag.x,e.clientY-drag.y);drag={x:e.clientX,y:e.clientY};});
 canvas.addEventListener('pointerup',()=>{drag=null;});canvas.addEventListener('pointercancel',()=>{drag=null;});
 canvas.addEventListener('wheel',e=>{e.preventDefault();if(attack||celebration)return;if(!manualOverride){manualOrientation.copy(camera.quaternion);manualFocus.copy(cameraFocus);orbit.radius=camera.position.distanceTo(cameraFocus);}manualOverride=true;centerTracking=false;orbit.radius=Math.max(1.2,Math.min(30,orbit.radius*Math.exp(e.deltaY*.002)));},{passive:false});
 const debrisMat=mat(0xa3a9b2);
 function debris(position){for(let i=0;i<20;i++){const m=box(.04+Math.random()*.06,.045,.05,debrisMat);m.position.copy(position);scene.add(m);particles.push({m,v:new THREE.Vector3((Math.random()-.5)*1.2,.7+Math.random(),(Math.random()-.5)*1.2),life:1.1})}}
 function trigger(kind,id=null){kind="fire";
 if(attack||celebration){pendingTasks.push({kind,id});return;}
 target=buildings.children.find(b=>b.userData.task.id===id)||(!id?buildings.children[0]:null);
 if(!target&&id){const tasks=window.planetState().tasks,i=tasks.findIndex(t=>t.id===id);if(i>=0)target=taskTower({...tasks[i],done:false});}
 if(!target&&!id){const offset=(.9*FORM_SIZES[form]+.5)/radius;const preview=navigator.normal.clone().multiplyScalar(Math.cos(offset)).addScaledVector(navigator.heading,Math.sin(offset)).normalize();target=tower({id:"preview",reward:40,done:false},Math.asin(preview.y),Math.atan2(preview.x,preview.z),true);}
 if(!target)return;
 attack={kind,time:0,hit:false,phase:'approach'};model.play('Walk',true);
 }
 rebuild();window.addEventListener('planet-update',rebuild);
 if(!mini){document.getElementById('resetform').onclick=resetForm;window.addEventListener('planet-celebrate',()=>{celebrationPending=true;});window.addEventListener('planet-attack',e=>trigger(e.detail.kind,e.detail.id));}

 function resetForm(){
 window.resetGrowth();
 celebrationPending=false;pendingTasks=[];if(target){buildings.remove(target);target=null;}attack=null;finishCelebration();
 for(const p of particles){scene.remove(p.m);p.m.geometry.dispose();}particles=[];
 breath.update(0,0,form,FORM_SIZES[form]);model.play('Walk',true);lastForm=-1;rebuild();
 }
 function finishCelebration(){celebration?.scene.dispose();celebration=null;buildings.visible=true;const note=document.getElementById('celebration-note');if(note){note.hidden=true;note.style.opacity='0';}lastForm=-1;}
 function resize(){const r=host.getBoundingClientRect();renderer.setSize(r.width,r.height,false);camera.aspect=r.width/Math.max(1,r.height);camera.updateProjectionMatrix()}new ResizeObserver(resize).observe(host);resize();
 const frameClock=createFrameClock(frame);
 function frame(t){const elapsed=last?Math.min((t-last)/1000,.05):0;last=t;const dt=elapsed;
 if(!attack&&!celebration&&pendingTasks.length){const next=pendingTasks.shift();trigger(next.kind,next.id);}
 if(celebrationPending&&!attack&&!pendingTasks.length&&!celebration){celebrationPending=false;buildings.visible=false;celebration={time:0,scene:createDailyCelebration(globe,navigator.normal.clone(),navigator.heading.clone(),tower,reduced)};}

 const xp=window.planetState().growthXP??window.planetState().xp;form=celebration?4:xp>=700?4:xp>=300?3:xp>=100?2:xp>=40?1:0;if(form!==lastForm){if(attack?.phase==='attack')attack.time=6;model.setForm(form);lastForm=form;}
 const size=FORM_SIZES[form],footprint=.9*size;let moving=false;
 const obstacles=buildings.children.filter(b=>!(b===target&&attack?.hit)).map(b=>({normal:b.position.clone().normalize(),radius:BUILDING_RADIUS}));
 if(!celebration&&attack?.phase==='approach'&&target){const destination=target.position.clone().normalize();const stop=footprint+BUILDING_RADIUS+.14;
 const route=navigator.step(dt,destination,stop,COMPLETION_SPEED,obstacles,footprint);moving=route.moving;
 if(route.arrived){attack.phase='attack';attack.time=0;model.play('Roar',true);}
 }else if(!reduced&&!attack&&!celebration){moving=navigator.step(dt,null,0,WALK_SPEED,obstacles,footprint).moving;}
 if(moving)travel+=dt;
 const normal=navigator.normal,p=normal.clone().multiplyScalar(radius+.015);kaiju.position.copy(p);
 const forward=navigator.heading,right=new THREE.Vector3().crossVectors(normal,forward).normalize();kaiju.quaternion.setFromRotationMatrix(new THREE.Matrix4().makeBasis(right,normal,forward));
 const idle=idleShot(normal,forward,right,size,camera.aspect);
 if(!cameraInitialized){camera.position.copy(idle.position);cameraFocus.copy(idle.focus);camera.up.copy(normal);camera.lookAt(cameraFocus);cameraInitialized=true;orbit.radius=camera.position.distanceTo(cameraFocus);}
 const following=Boolean(attack||celebration||!manualOverride);
 const preparingBreath=Boolean(celebration);
 const blend=1-Math.exp(-dt*2.5);
 if(preparingBreath){
   // Camera below the chest, facing upward from eleven o'clock.
   if(!celebration.framing||celebration.aspect!==camera.aspect){celebration.framing=celebrationShot(normal,forward,right,size,celebration.scene.framingPoints,camera.aspect);celebration.aspect=camera.aspect;}
   const {position:shotPosition,focus:shotFocus}=celebration.framing;
   camera.position.lerp(shotPosition,1-Math.exp(-dt*2.5));
   cameraFocus.lerp(shotFocus,1-Math.exp(-dt*2.5));
   camera.up.lerp(normal,1-Math.exp(-dt*2.5)).normalize();

 }else if(!following){
   const manualBlend=1-Math.exp(-dt*18),distance=THREE.MathUtils.lerp(camera.position.distanceTo(manualFocus),orbit.radius,manualBlend);
   camera.quaternion.slerp(manualOrientation,manualBlend);
   camera.position.set(0,0,distance).applyQuaternion(camera.quaternion).add(manualFocus);
   camera.up.set(0,1,0).applyQuaternion(camera.quaternion);cameraFocus.copy(manualFocus);
 }else{

   camera.position.lerp(idle.position,blend);
   cameraFocus.lerp(idle.focus,blend);
   camera.up.lerp(normal,blend).normalize();
 }
 framingShift=THREE.MathUtils.lerp(framingShift,0,1-Math.exp(-dt*2.5));
 if(framingShift>.001){const bounds=host.getBoundingClientRect(),w=Math.max(1,bounds.width),h=Math.max(1,bounds.height);camera.setViewOffset(w,h,-w/6*framingShift,0,w,h);}else camera.clearViewOffset();
 if(following||preparingBreath)camera.lookAt(cameraFocus);
 host.dataset.orbit=following?'reference-three-quarter':[orbit.theta,orbit.phi,orbit.radius].join(',');
 let swing=0,breathing=false,chargeLevel=0,jawOpen=0,breathPower=0,roarTime=null;
 if(attack?.phase==='attack'){attack.time+=dt;const a=attack.time,sequence=roarSequence(a);roarTime=a;breathing=sequence.emitting;breathPower=sequence.power;

 if(sequence.impact&&!attack.hit&&target){attack.hit=true;globe.updateMatrixWorld(true);debris(target.getWorldPosition(new THREE.Vector3()));target.children.forEach(c=>c.visible=false);for(let k=0;k<5;k++){const r=box(.085,.04,.085,debrisMat);r.position.set((k%3-1)*.09,.025,(Math.floor(k/3)-.5)*.1);target.add(r)}}if(sequence.finished){attack=null;if(target){buildings.remove(target);target=null;}rebuild();if(pendingTasks.length){const next=pendingTasks.shift();trigger(next.kind,next.id);}}}
 if(celebration){
 if(model.root.userData.level===4)celebration.time+=dt;
 const state=celebration.scene.update(celebration.time,dt);host.dataset.celebrationRemaining=String(state.remaining);
 if(!reduced&&celebration.time>=2.5){roarTime=Math.min(state.roarTime,5.999);breathing=state.power>0;breathPower=state.power;}
 const note=document.getElementById('celebration-note');if(note){note.hidden=!state.note;note.style.opacity=state.note?'1':'0';}
 if(state.finished)finishCelebration();
 }
 model.animate(travel*5,moving,swing,breathing,chargeLevel,jawOpen,dt,roarTime,attack?.phase==='approach'?3:1);if(breathPower>0&&(target||celebration)){globe.updateMatrixWorld(true);const aim=celebration?globe.localToWorld(celebration.scene.aim(celebration.time)):target.localToWorld(new THREE.Vector3(0,.2,0));const direction=model.muzzle.worldToLocal(aim).normalize();breath.group.quaternion.setFromUnitVectors(new THREE.Vector3(0,0,1),direction);}breath.update(travel+(attack?.time??celebration?.time??0),breathPower,form,size);if(celebration&&breathPower>0){breath.group.scale.x*=2;breath.group.scale.y*=2;}
 particles=particles.filter(d=>{d.life-=dt;if(d.life<=0){scene.remove(d.m);d.m.geometry.dispose();return false}d.v.y-=dt*2.7;d.m.position.addScaledVector(d.v,dt);d.m.rotation.x+=dt*4;d.m.scale.setScalar(Math.min(1,d.life*2));return true});host.dataset.buildings=String(buildings.children.filter(b=>!b.userData.task.done&&b!==target).length+(target&&!attack?.hit?1:0));host.dataset.celebration=celebration?celebrationPhase(celebration.time):"idle";host.dataset.attack=attack?.kind??"idle";host.dataset.phase=attack?.phase??"wander";host.dataset.position=navigator.normal.toArray().join(",");host.dataset.heading=navigator.heading.toArray().join(",");host.dataset.form=String(form);host.dataset.clearance=String(Math.min(...obstacles.map(o=>navigator.normal.angleTo(o.normal)*radius-footprint-o.radius)));host.dataset.cameraDistance=String(cameraDistance(form,camera.aspect));host.dataset.breath=String(breathPower);host.dataset.roarTime=String(roarTime??0);host.dataset.speed=String(attack?.phase==='approach'?COMPLETION_SPEED:WALK_SPEED);renderer.render(scene,camera);if(!window.sceneFrames)window.sceneFrames=0;window.sceneFrames++;
 if(window.sceneFrames===1){camera.updateMatrixWorld(true);const visible=p.clone().project(camera);window.webkit?.messageHandlers?.diagnostics?.postMessage(JSON.stringify({camera:camera.position.toArray(),aspect:camera.aspect,kaijuScreen:visible.toArray(),radius:orbit.radius,form,frames:window.sceneFrames}));}
 frameClock.schedule()}frame(performance.now());
}
start(document.getElementById('planet-main')).then(()=>dispatchEvent(new Event('planet-ready'))).catch(e=>{document.getElementById('planet-main').textContent='3D 模型加载失败';console.error(e)});
