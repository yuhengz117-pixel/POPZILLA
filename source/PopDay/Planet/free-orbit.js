import * as T from './assets/three.module.js';
// Rotate around the camera's own screen axes, without latitude limits.
export function dragOrbit(orientation,dx,dy){
 const turn=new T.Quaternion().setFromEuler(new T.Euler(-dy*.008,-dx*.008,0,'YXZ'));
 return orientation.multiply(turn).normalize();
}
