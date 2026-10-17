import * as T from './assets/three.module.js';
// Front three-quarter view with an 18-degree downward glance, like the reference.
export function idleShot(normal,forward,right,size,aspect){
 const focus=normal.clone().multiplyScalar(4.5+.65*size);
 const distance=(2.5*size+.3)*1.10*1.20*Math.max(1,1/Math.max(.7,aspect));
 const side=forward.clone().multiplyScalar(.819152).addScaledVector(right,.573576).normalize();
 const position=focus.clone().addScaledVector(side,distance).addScaledVector(normal,distance*Math.tan(T.MathUtils.degToRad(18)));
 return {position,focus};
}
