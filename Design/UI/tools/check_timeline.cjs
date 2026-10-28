/* Synthetic events only; monotonic real-time poll plus explicit event-boundary assertions. */
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {performance}=require('node:perf_hooks');
const FloatingNotes=require('../floating-notes.js');
(async()=>{
 const cases=[],check=(name,fn)=>{fn();cases.push({name,status:'pass'});};
 check('same pressID and repeated held event do not multiply',()=>{const n=new FloatingNotes();assert(n.strike('a','keyA',0));assert(!n.strike('a','keyA',10));assert.equal(n.sample(100).length,1);});
 check('white/black multiple notes and restrike have independent IDs',()=>{const n=new FloatingNotes();n.strike('a','keyA',0);n.strike('b','commandLeft',0);n.strike('a2','keyA',30);assert.equal(n.sample(100).length,3);assert.equal(n.sample(700).length,1);assert.equal(n.sample(730).length,0);});
 check('stale event time cannot reintroduce an old press',()=>{const n=new FloatingNotes();n.strike('a2','keyA',30);assert(!n.strike('a','keyA',0));});
 check('distinct press IDs can share a quantized monotonic timestamp',()=>{const n=new FloatingNotes();assert(n.strike('a','keyA',10));assert(n.strike('b','keyA',10));assert.equal(n.sample(20).length,2);});
 check('700ms deadline is exact in timeline, fade-in/out and rise match spec',()=>{const n=new FloatingNotes();n.strike('a','keyA',0);assert.equal(n.sample(0)[0].opacity,0);assert.equal(n.sample(100)[0].opacity,1);assert.equal(n.sample(350)[0].opacity,.875);assert.equal(n.sample(350)[0].rise,21);assert(n.sample(699)[0].opacity>0);assert.equal(n.sample(700).length,0);});
 check('hiding clears immediately; hidden events never replay',()=>{const n=new FloatingNotes();n.strike('a','keyA',0);n.setHidden(true);assert.equal(n.sample(5).length,0);assert(!n.strike('b','keyS',10));n.setHidden(false);assert.equal(n.sample(20).length,0);assert(n.strike('c','keyD',21));});
 check('reduced motion stays at origin and ends at 200ms',()=>{const n=new FloatingNotes();n.setReduced(true);n.strike('a','keyA',0);assert.equal(n.sample(100)[0].rise,0);assert.equal(n.sample(100)[0].opacity,.5);assert.equal(n.sample(200).length,0);});
 check('expired instances are reclaimed without altering newer ones',()=>{const n=new FloatingNotes();for(let i=0;i<1000;i++){n.strike(String(i),'key'+i%64,i*10);n.sample(i*10);}assert(n.instances.size<=70);n.sample(11000);assert.equal(n.instances.size,0);assert.equal(n.latestByKey.size,64);});
 const timeline=new FloatingNotes(),start=performance.now();timeline.strike('realtime','keyA',start);
 const samples=[];let lastVisible=0,observedEmpty=null;
 await new Promise(resolve=>{const timer=setInterval(()=>{const now=performance.now(),elapsed=now-start;const frames=timeline.sample(now);samples.push({elapsedMs:elapsed,visibleInstances:frames.length,opacity:frames[0]?.opacity??0,risePt:frames[0]?.rise??0});if(frames.length)lastVisible=elapsed;else{observedEmpty=elapsed;clearInterval(timer);resolve();}},10);});
 assert(observedEmpty>=700&&observedEmpty<1000);
 const report={status:'pass',runtime:process.version,platform:process.platform,architecture:process.arch,date:'2026-10-28 Asia/Shanghai',scope:'Node execution of same preview timeline with synthetic events. This is real monotonic timing, not browser paint or production App measurement.',cases,realTime:{logicalDeadlineMs:700,lastObservedVisibleMs:lastVisible,firstObservedEmptyMs:observedEmpty,pollPeriodMs:10,samples}};
 fs.writeFileSync(path.resolve(__dirname,'../qa/timeline.json'),JSON.stringify(report,null,2)+'\n');
 console.log(`Timeline: ${cases.length} cases passed; real-time first empty ${observedEmpty.toFixed(3)}ms.`);
})().catch(e=>{console.error(e);process.exit(1);});
