import * as T from './assets/three.module.js';
export function celebrationShot(normal,forward,right,size,points,aspect){
 const all=[...points,normal.clone().multiplyScalar(4.515),normal.clone().multiplyScalar(4.5+1.15*size)];
 const box=new T.Box3().setFromPoints(all),focus=box.getCenter(new T.Vector3());
 // Keep the lens below the chest and its gaze angled upward.
 const height=4.5+.34*size;
 focus.addScaledVector(normal,Math.max(0,height+.45*size-focus.dot(normal)));
 const tangent=forward.clone().multiplyScalar(.866).addScaledVector(right,-.5).normalize();
 const camera=new T.PerspectiveCamera(43,aspect,.1,80);camera.up.copy(normal);
 let distance=3*size+2,position;
 for(let attempt=0;attempt<50;attempt++){
   position=normal.clone().multiplyScalar(height).addScaledVector(tangent,distance);
   camera.position.copy(position);camera.lookAt(focus);camera.updateMatrixWorld(true);
   if(all.every(point=>{const p=point.clone().project(camera);return p.z<1&&p.z>-1&&Math.abs(p.x)<.70&&Math.abs(p.y)<.70;}))break;
   distance*=1.08;
 }
 // Center the composition and move 20% closer along the same viewing ray.
 position.lerp(focus,.2);
 return {position,focus};
}
