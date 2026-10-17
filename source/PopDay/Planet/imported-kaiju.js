import * as T from './assets/three.module.js';
import {GLTFLoader} from './assets/addons/loaders/GLTFLoader.js';
export async function createKaiju(){
 const root=new T.Group(),muzzle=new T.Group();root.add(muzzle);const names=['01_ORIGINAL_SMALL','02_ORIGINAL_LARGE','03_BLUE_AWAKENING','04_VIOLET_OVERLOAD','05_CRIMSON_LOTUS'];const cache=new Map();let current=null,form=0,requested=0,actionName='Walk',lastPhase=0;
 async function load(i){if(!cache.has(i))cache.set(i,new GLTFLoader().loadAsync('./assets/levels/'+names[i]+'.glb').then(g=>{g.scene.scale.setScalar(1.15/6.7289567);g.scene.visible=false;root.add(g.scene);return{g,mixer:new T.AnimationMixer(g.scene),action:null}}));return cache.get(i)}
 function play(name,force=false){actionName=name;if(!current)return;const c=current.g.animations.find(c=>c.name===name)||current.g.animations[0];if(!force&&current.action?.getClip()===c)return;current.mixer.stopAllAction();current.action=current.mixer.clipAction(c).reset().play();}
 async function setForm(i){i=Math.max(0,Math.min(4,i));form=i;const ticket=++requested;const next=await load(i);if(ticket!==requested)return;root.attach(muzzle);if(current)current.g.scene.visible=false;current=next;next.level=i;next.g.scene.visible=true;play(actionName,true);muzzle.quaternion.identity();muzzle.scale.setScalar(1);updateMuzzle();root.userData.level=i;}
 function updateMuzzle(){if(!current)return;root.updateMatrixWorld(true);let body=null;current.g.scene.traverse(o=>{if(o.isSkinnedMesh&&(!body||o.geometry.attributes.position.count>body.geometry.attributes.position.count))body=o;});if(!body)return;
 const activeForm=current.level??0;const samples=activeForm<2?[99,833,924,933]:activeForm===2?[112,872,962,972]:[112,873,963,973];const center=new T.Vector3(),v=new T.Vector3();for(const index of samples){body.getVertexPosition(index,v);center.add(body.localToWorld(v));}center.multiplyScalar(1/samples.length);root.worldToLocal(center);center.y-=.025*[.7,1,1.25,1.5,1.8][activeForm];muzzle.position.copy(center);
 }
 await setForm(0);
 return{root,muzzle,setForm,play,animate(phase,moving,attack,breathing,charge,jawOpen,dt=.016,roarTime=null,walkSpeed=1){if(!current)return;let name=roarTime!==null||breathing||jawOpen?'Roar':attack>0?'Attack':moving?'Walk':actionName;if(moving)name='Walk';play(name);if(roarTime!==null){current.mixer.setTime(Math.min(roarTime,current.action.getClip().duration-.001));}else current.mixer.update(moving?dt*walkSpeed:breathing||jawOpen||attack>0?dt:0);updateMuzzle();lastPhase=phase;}};
}
