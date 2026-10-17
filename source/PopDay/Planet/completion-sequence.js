export const WALK_SPEED=.85;
export const COMPLETION_SPEED=WALK_SPEED*3;
// Begin at the inspected mouth-opening peak; continue through the closing/recovery phase.
export const ROAR_DURATION=6;
export const BREATH_START=2.05;
export const BREATH_END=ROAR_DURATION;
export const IMPACT_TIME=2.30;
export function roarSequence(time){
 const emitting=time>BREATH_START&&time<BREATH_END;
 const power=emitting?Math.min((time-BREATH_START)/.10,1,(BREATH_END-time)/.12):0;
 return {power,emitting,impact:time>=IMPACT_TIME,finished:time>=ROAR_DURATION};
}
