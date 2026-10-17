// WebKit may suspend animation callbacks while a desktop surface is covered.
// Keep a low-frequency fallback; visible animation still follows the display.
export function createFrameClock(callback,api=globalThis){
 let animation=null,timer=null;
 function tick(time){api.cancelAnimationFrame(animation);api.clearTimeout(timer);callback(time);}
 return {schedule(){animation=api.requestAnimationFrame(tick);timer=api.setTimeout(()=>tick(api.performance.now()),1000);}};
}
