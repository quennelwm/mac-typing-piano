/* Pure design-preview timeline. Event IDs and times here are synthetic. No input or audio APIs. */
(function(root){
  'use strict';
  class FloatingNotes {
    constructor(){this.instances=new Map();this.latestByKey=new Map();this.hidden=false;this.reduced=false;}
    strike(pressID,keyID,eventTime){
      const last=this.latestByKey.get(keyID);
      if(last&&(last.pressID===pressID||eventTime<last.eventTime))return false;
      this.latestByKey.set(keyID,{pressID,eventTime});
      if(this.hidden)return false;
      this.instances.set(pressID,{pressID,keyID,start:eventTime,duration:this.reduced?200:700,reduced:this.reduced});
      return true;
    }
    sample(now){
      const frames=[];
      for(const [id,n]of this.instances){
        const t=now-n.start;
        if(t>=n.duration){this.instances.delete(id);continue;}
        if(t<0)continue;
        const fraction=t/n.duration;
        frames.push({...n,elapsed:t,rise:n.reduced?0:24*(1-Math.pow(1-fraction,3)),opacity:n.reduced?1-fraction:Math.min(1,t/60,(700-t)/400)});
      }
      return frames;
    }
    setHidden(hidden){this.hidden=hidden;if(hidden)this.instances.clear();}
    setReduced(value){if(value!==this.reduced)this.instances.clear();this.reduced=value;}
    clear(){this.instances.clear();}
    reset(){this.clear();this.latestByKey.clear();}
  }
  if(typeof module==='object'&&module.exports)module.exports=FloatingNotes;else root.FloatingNotes=FloatingNotes;
})(typeof window==='object'?window:globalThis);
