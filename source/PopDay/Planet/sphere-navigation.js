import * as T from './assets/three.module.js';
export const FORM_SIZES=[.7,1,1.25,1.5,1.8];
export function taskLocation(id,salt=0){
 let h=2166136261;for(const c of `${id}:${salt}`)h=Math.imul(h^c.charCodeAt(0),16777619)>>>0;
 const random=()=>{h=(Math.imul(h,1664525)+1013904223)>>>0;return h/4294967296;};
 return new T.Vector3().setFromSphericalCoords(1,Math.acos(2*random()-1),2*Math.PI*random());
}
export class SphereNavigator{
 constructor(normal,radius,random=Math.random){this.normal=normal.clone().normalize();this.radius=radius;this.random=random;this.heading=new T.Vector3(1,0,0).projectOnPlane(this.normal).normalize();this.desired=this.heading.clone();this.turnIn=0;this.route=[];this.routeKey="";this.routeRetry=0;}
 step(dt,destination=null,stopDistance=0,speed=.85,obstacles=[],footprint=0){
 this.routeRetry=Math.max(0,this.routeRetry-dt);
 let remaining=destination?this.normal.angleTo(destination)*this.radius:Infinity;
 if(destination&&remaining<=stopDistance+(obstacles.length?.015:.001))return {moving:false,arrived:true,distance:remaining};
 const barriers=obstacles.map(o=>({normal:o.normal,radius:(o.radius+footprint)/this.radius}));
 let waypoint=destination;
 if(destination&&barriers.length){
 const key=destination.toArray().join(',')+':'+stopDistance+':'+barriers.map(o=>o.normal.toArray().join(',')+':'+o.radius).join(';');
 if(key!==this.routeKey||(!this.route.length&&this.routeRetry<=0)){this.route=planSurfaceRoute(this.normal,destination,stopDistance/this.radius,barriers);this.routeKey=key;this.routeRetry=this.route.length?0:2;}
 while(this.route.length&&this.normal.angleTo(this.route[0])<(this.route.length===1?.001:.025))this.route.shift();
 waypoint=this.route[0];if(!waypoint)return {moving:false,arrived:false,distance:remaining};
 if(!clearArc(this.normal,waypoint,barriers)){this.routeKey='';return {moving:false,arrived:false,distance:remaining};}
 }
 if(waypoint){this.desired.copy(waypoint).projectOnPlane(this.normal);if(this.desired.lengthSq()<1e-8)this.desired.copy(this.heading);this.desired.normalize();}
 else{this.turnIn-=dt;if(this.turnIn<=0){this.turnIn=4+this.random()*5;this.desired.copy(this.heading).applyAxisAngle(this.normal,(this.random()-.5)*Math.PI*1.6);}}
 if(!destination&&barriers.length){
 const look=.35+speed*.8/this.radius;
 const choices=[0,.4,-.4,.8,-.8,1.2,-1.2,1.6,-1.6,2.2,-2.2,Math.PI];
 const safe=choices.map(angle=>this.desired.clone().applyAxisAngle(this.normal,angle)).find(dir=>clearArc(this.normal,surfaceStep(this.normal,dir,look),barriers));
 if(safe)this.desired.copy(safe);else return {moving:false,arrived:false,distance:remaining};
 }
 const turn=Math.atan2(this.normal.dot(new T.Vector3().crossVectors(this.heading,this.desired)),this.heading.dot(this.desired));
 this.heading.applyAxisAngle(this.normal,T.MathUtils.clamp(turn,-dt*1.5,dt*1.5)).normalize();
 // Turn in place before approaching a task, keeping the route on the sphere.
 if(destination&&Math.abs(turn)>.12)return {moving:false,arrived:false,distance:remaining};
 let step=Math.min(speed*dt,Math.max(0,remaining-stopDistance))/this.radius;
 if(waypoint)step=Math.min(step,this.normal.angleTo(waypoint));
 if(barriers.length&&!clearArc(this.normal,surfaceStep(this.normal,this.heading,step),barriers))return {moving:false,arrived:false,distance:remaining};
 const before=this.normal.clone(),axis=new T.Vector3().crossVectors(before,this.heading).normalize();this.normal.applyAxisAngle(axis,step).normalize();
 const transport=new T.Quaternion().setFromUnitVectors(before,this.normal);this.heading.applyQuaternion(transport).projectOnPlane(this.normal).normalize();this.desired.applyQuaternion(transport).projectOnPlane(this.normal).normalize();
 remaining=destination?this.normal.angleTo(destination)*this.radius:Infinity;
 return {moving:step>0,arrived:destination&&(remaining<=stopDistance+.001||barriers.length>0&&!this.route.length&&remaining<=stopDistance+.15),distance:remaining};
 }
}
export function cameraDistance(form,aspect){return 3.8*FORM_SIZES[form]*Math.max(1,1/Math.max(.4,aspect));}

function surfaceStep(normal,direction,angle){return normal.clone().multiplyScalar(Math.cos(angle)).addScaledVector(direction,Math.sin(angle)).normalize();}
export function arcClearance(a,b,center){
 const length=a.angleTo(b);if(length<1e-9)return a.angleTo(center);
 const direction=b.clone().addScaledVector(a,-a.dot(b)).normalize();
 const closest=Math.atan2(center.dot(direction),center.dot(a));
 let distance=Math.min(a.angleTo(center),b.angleTo(center));
 if(closest>=0&&closest<=length)distance=Math.min(distance,surfaceStep(a,direction,closest).angleTo(center));
 return distance;
}
export function clearArc(a,b,barriers){return barriers.every(o=>{
 const initial=a.angleTo(o.normal);
 // Growth can enlarge a collider around the current position: only permit outward escape.
 if(initial<o.radius-.00001){const dir=b.clone().addScaledVector(a,-a.dot(b));return dir.dot(o.normal)<=1e-9&&b.angleTo(o.normal)>=initial-.000001;}
 return arcClearance(a,b,o.normal)>=o.radius-.000001;
});}
function ring(center,angle,count=12){let tangent=new T.Vector3(1,0,0).projectOnPlane(center);if(tangent.lengthSq()<.01)tangent.set(0,1,0).projectOnPlane(center);tangent.normalize();return Array.from({length:count},(_,i)=>surfaceStep(center,tangent.clone().applyAxisAngle(center,i*Math.PI*2/count),angle));}
export function planSurfaceRoute(start,target,stopAngle,barriers){
 const free=p=>barriers.every(o=>p.angleTo(o.normal)>=o.radius+.0001);
 const goals=ring(target,stopAngle+.002).filter(free);
 if(!goals.length)return [];
 const direct=goals.filter(g=>clearArc(start,g,barriers)).sort((a,b)=>start.angleTo(a)-start.angleTo(b));
 if(direct.length)return [direct[0]];
 const nodes=[start.clone(),...goals];const goalCount=goals.length;
 for(const obstacle of barriers)nodes.push(...ring(obstacle.normal,obstacle.radius*1.08+.012).filter(free));
 const cost=nodes.map(()=>Infinity),previous=nodes.map(()=>-1),open=new Set([0]),closed=new Set();cost[0]=0;
 const heuristic=i=>Math.min(...goals.map(g=>nodes[i].angleTo(g)));
 while(open.size){let best=-1,bestCost=Infinity;for(const i of open){const score=cost[i]+heuristic(i);if(score<bestCost){best=i;bestCost=score;}}
 if(best>0&&best<=goalCount){const path=[];for(let i=best;i>0;i=previous[i])path.unshift(nodes[i]);return path;}
 open.delete(best);closed.add(best);
 for(let j=1;j<nodes.length;j++){if(closed.has(j))continue;const estimate=cost[best]+nodes[best].angleTo(nodes[j]);if(estimate>=cost[j]||!clearArc(nodes[best],nodes[j],barriers))continue;cost[j]=estimate;previous[j]=best;open.add(j);}
 }
 return [];
}
