/* Independent UI review only. No physical keyboard events, capture, storage, audio or system calls. */
'use strict';
const D = window.UI_REVIEW_DATA;
const $ = id => document.getElementById(id);
let volumePercent=50;
let width = 1000, labelsOn = true, dockAutoHide = true, pianoOn = true, paused = false;
let hiddenReasons = new Set(), reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
let scenarioGeneration = 0, scheduled = [], currentState = 'rest';
const visual = new Map();
const floating = new FloatingNotes();let noteSequence=0,noteFrame=null;
function clearNotes(){floating.clear();if(noteFrame!==null)cancelAnimationFrame(noteFrame);noteFrame=null;const layer=$('floatingLayer');if(layer)layer.innerHTML='';}
function drawNotes(now=performance.now()){
  const frames=floating.sample(now),layout=D.layouts.find(l=>l.widthPt===width);
  const layer=$('floatingLayer');
  if(layer)layer.innerHTML=frames.map(n=>{const k=layout.keys.find(k=>k.physicalKeyID===n.keyID);const x=k.rectPt[0]+k.rectPt[2]/2;return `<text x="${x}" y="${-2-n.rise}" text-anchor="middle" font-size="12" font-weight="500" fill="#626C66" stroke="#FFFFFF" stroke-opacity=".9" stroke-width="1.25" paint-order="stroke" opacity="${n.opacity}">♪</text>`;}).join('');
  noteFrame=floating.instances.size?requestAnimationFrame(drawNotes):null;
}
function strikeNote(id,time){if(floating.strike(`preview-${++noteSequence}`,id,time)&&noteFrame===null)noteFrame=requestAnimationFrame(drawNotes);}
const motion = { press:45, release:100, minimumPulse:45 };
const escapeText = x => String(x).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
function surface(k,state) {
  const [x,y,w,h]=k.rectPt, p=D.palette[k.color], black=k.color==='black', id=`${k.midiNote}-${state}`;
  const radius=black?1.2:1, front=black?2:2.5;
  return `<g transform="translate(${x} ${y})"><defs><linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop stop-color="${p[state][0]}"/><stop offset="1" stop-color="${p[state][1]}"/></linearGradient><clipPath id="${id}-clip"><rect width="${w}" height="${h}" rx="${radius}"/></clipPath></defs><g clip-path="url(#${id}-clip)"><rect width="${w}" height="${h}" fill="url(#${id})"/><rect y="${h-front}" width="${w}" height="${front}" fill="${p.front[state]}"/><path d="M1 .5H${w-1}" stroke="${black?'#58595C':'#FFFFFF'}" stroke-width=".5"/></g></g>`;
}
function render() {
  const layout=D.layouts.find(l=>l.widthPt===width);
  const keys=[...layout.keys.filter(k=>k.color==='white'),...layout.keys.filter(k=>k.color==='black')];
  $('pianoHost').innerHTML=`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="104" viewBox="0 -48 ${width} 104" role="img" aria-label="64键钢琴，模拟视觉状态"><rect width="${width}" height="56" rx="3" fill="#353638"/><rect x="1" y="1" width="${width-2}" height="53" rx="2" fill="#71716E"/>${keys.map(k=>`<g class="key ${k.color}" data-key="${k.physicalKeyID}" data-midi="${k.midiNote}" style="--down:${k.color==='black'?1.5:2}px"><title>${escapeText(k.accessibleName)} · MIDI ${k.midiNote}</title><g class="rest-face">${surface(k,'rest')}</g><g class="pressed-face">${surface(k,'pressed')}</g><g class="label-layer" fill="${D.palette[k.color].label}" font-family="-apple-system,BlinkMacSystemFont,system-ui,sans-serif" font-weight="500">${k.labels.map(l=>`<text x="${l.x}" y="${l.baselineY}" font-size="${l.fontSizePt}">${escapeText(l.text)}</text>`).join('')}</g></g>`).join('')}<g id="floatingLayer" aria-hidden="true" pointer-events="none"></g></svg>`;
  for (const element of document.querySelectorAll('.key')){element.addEventListener('pointerdown',()=>setDown(element.dataset.key,true));element.addEventListener('pointerup',()=>setDown(element.dataset.key,false));element.addEventListener('pointerleave',()=>{if(visual.get(element.dataset.key)?.pressed)setDown(element.dataset.key,false);});}
  for (const k of keys) if (!visual.has(k.physicalKeyID)) visual.set(k.physicalKeyID,{generation:0,pressed:false,visualDown:false,pressedAt:0,timer:null});
  for (const [id,s] of visual) keyElement(id)?.classList.toggle('is-down',s.visualDown);
  $('pianoHost').classList.toggle('hide-labels',!labelsOn);
  $('pianoHost').classList.toggle('is-hidden',hiddenReasons.size>0);
}
const keyElement = id => document.querySelector(`.key[data-key="${id}"]`);
function schedule(fn,ms) { const generation=scenarioGeneration;const t=setTimeout(()=>{scheduled=scheduled.filter(x=>x!==t);if(generation===scenarioGeneration) fn();},ms);scheduled.push(t); }
function reset() {
  clearNotes();
  scenarioGeneration++; scheduled.forEach(clearTimeout); scheduled=[];
  hiddenReasons.delete('dock-demo');floating.setHidden(hiddenReasons.size>0);$('pianoHost').classList.toggle('is-hidden',hiddenReasons.size>0);
  for (const [id,s] of visual) {clearTimeout(s.timer);s.timer=null;s.generation++;s.pressed=false;s.visualDown=false;keyElement(id)?.classList.remove('is-down');}
}
function setDown(id,on) {
  const s=visual.get(id);if(!s || (on && paused))return;
  const now=performance.now();s.generation++;const generation=s.generation;clearTimeout(s.timer);s.timer=null;
  // Repeated 'down' in a held state does not restart the animation.
  if(on&&s.pressed)return;
  s.pressed=on;
  if(on) {s.pressedAt=now;s.visualDown=true;strikeNote(id,now);keyElement(id)?.classList.add('is-down');return;}
  const remaining=reduced?0:Math.max(0,motion.minimumPulse-(now-s.pressedAt));
  const release=()=>{if(s.generation!==generation||s.pressed)return;s.visualDown=false;s.timer=null;keyElement(id)?.classList.remove('is-down');};
  if(remaining>0)s.timer=setTimeout(release,remaining);else release();
}
function applyScenario(state) {
  reset();currentState=state;D.scenarios[state].forEach(id=>setDown(id,true));
  document.querySelectorAll('[data-state]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.state===state)));
  $('stageState').textContent={rest:'静止',single:'单键按下 · A',multi:'多键保持 · 左右修饰键独立'}[state];
  $('feedback').textContent='合成状态 · 不读取真实键盘。按下 45ms，回弹 100ms；声音尾音不决定回弹。';
}
function setVisibility(reason,hidden) {
  if(hidden)hiddenReasons.add(reason);else hiddenReasons.delete(reason);
  floating.setHidden(hiddenReasons.size>0);if(hiddenReasons.size>0)clearNotes();
  // Hidden model keeps current pressed state; when restoring, snap to the latest snapshot.
  if(hiddenReasons.size===0) {
    $('pianoHost').classList.add('reduce-motion');
    for(const [id,s] of visual){clearTimeout(s.timer);s.timer=null;s.generation++;s.visualDown=s.pressed;keyElement(id)?.classList.toggle('is-down',s.pressed);}
    void $('pianoHost').getBoundingClientRect();$('pianoHost').classList.remove('reduce-motion');
  }
  $('pianoHost').classList.toggle('is-hidden',hiddenReasons.size>0);
}
function checked(id,value) {$(id).setAttribute('aria-checked',String(value));$(id).querySelector('.tick').textContent=value?'✓':'';}
function setLabels(value) {labelsOn=value;$('pianoHost').classList.toggle('hide-labels',!labelsOn);checked('labelsItem',value);$('labelsToggle').setAttribute('aria-pressed',String(value));$('labelsToggle').textContent=`标签：${value?'显示':'关闭'}`;$('feedback').textContent=value?'标签已显示 · 文字来自统一 keymap。':'标签已关闭 · 仅隐藏独立文字层，琴键与按压状态保持不变。';}
function setMenu(on) {$('menu').hidden=!on;$('statusItem').setAttribute('aria-expanded',String(on));}
function chooseWidth(value) {width=value;render();$('widthMenuValue').textContent=`${width}pt`;document.querySelectorAll('[data-width]').forEach(b=>b.setAttribute('aria-pressed',String(Number(b.dataset.width)===width)));}
function setReduced(value) {reduced=value;floating.setReduced(value);clearNotes();document.body.classList.toggle('reduce-motion',value);$('reduceMotion').checked=value;if(value)for(const [id,s]of visual){if(!s.pressed){clearTimeout(s.timer);s.timer=null;s.generation++;s.visualDown=false;keyElement(id)?.classList.remove('is-down');}}}
$('statusItem').onclick=()=>setMenu($('menu').hidden);
$('labelsItem').onclick=()=>setLabels(!labelsOn);
$('labelsToggle').onclick=()=>setLabels(!labelsOn);
$('dockItem').onclick=()=>{if(dockAutoHide){setMenu(false);$('dockWarning').showModal();}else{dockAutoHide=true;checked('dockItem',true);$('feedback').textContent='演示偏好：Dock 自动隐藏开启；实际系统设置未更改。';}};
$('keepDock').onclick=()=>{$('dockWarning').close();$('feedback').textContent='保持开启 · 预览没有更改当前系统设置。';$('statusItem').focus();};
$('disableDock').onclick=()=>{dockAutoHide=false;checked('dockItem',false);$('dockWarning').close();$('feedback').textContent='演示偏好：Dock 自动隐藏关闭；钢琴避让策略仍独立保留。实际系统设置未更改。';$('statusItem').focus();};
$('dockWarning').addEventListener('cancel',()=>{$('feedback').textContent='已取消 · 保持 Dock 自动隐藏开启（演示偏好）。';});
$('volumeSlider').oninput=e=>{volumePercent=Math.min(100,Math.max(0,Math.round(Number(e.target.value)||0)));$('volumeValue').textContent=`${volumePercent}%`;$('feedback').textContent=`应用音量 ${volumePercent}%（仅演示）；不改变声音开关、动画或系统音量。`;};
$('soundItem').onclick=()=>{checked('soundItem',$('soundItem').getAttribute('aria-checked')!=='true');$('feedback').textContent='声音开关仅作菜单示意；此预览始终没有声音。';};
$('pianoItem').onclick=()=>{pianoOn=!pianoOn;checked('pianoItem',pianoOn);setVisibility('user',!pianoOn);};
$('pauseItem').onclick=()=>{paused=!paused;reset();setVisibility('paused',paused);$('pauseItem').children[1].textContent=paused?'恢复全部':'暂停全部';$('feedback').textContent=paused?'合成演示已暂停并清空状态。':'已恢复，从空状态开始。';};
$('quitItem').onclick=()=>{setMenu(false);reset();$('feedback').textContent='退出项仅作菜单示意；设计预览保持打开。';};
$('reduceMotion').onchange=e=>setReduced(e.target.checked);
matchMedia('(prefers-reduced-motion: reduce)').addEventListener('change',e=>setReduced(e.matches));
for(const b of document.querySelectorAll('[data-width]'))b.onclick=()=>chooseWidth(Number(b.dataset.width));
for(const b of document.querySelectorAll('[data-state]'))b.onclick=()=>applyScenario(b.dataset.state);
$('helpItem').onclick=()=>{$('feedback').textContent='菜单设计示意：日常入口为菜单栏；首次正式运行需说明系统 Dock 自动隐藏影响。权限与关于信息按需打开轻量窗口。';setMenu(false);};
$('noteSingle').onclick=()=>{reset();setDown('keyA',true);schedule(()=>setDown('keyA',false),180);$('stageState').textContent='单键小音符 · 700ms';};
$('noteMulti').onclick=()=>{reset();['keyA','commandLeft','space','digit8','shiftRight'].forEach(id=>setDown(id,true));schedule(()=>['keyA','commandLeft','space','digit8','shiftRight'].forEach(id=>setDown(id,false)),180);$('stageState').textContent='多键小音符 · 黑白键独立';};
$('shortTap').onclick=()=>{reset();setDown('keyA',true);schedule(()=>setDown('keyA',false),20);$('stageState').textContent='20ms 短按';$('feedback').textContent='合成 A：0ms down、20ms up；真实模型立即松开，视觉最短展示至 45ms 后回弹。';};
$('restrike').onclick=()=>{reset();setDown('commandLeft',true);schedule(()=>setDown('commandLeft',false),20);schedule(()=>setDown('commandLeft',true),30);schedule(()=>setDown('commandLeft',false),120);$('stageState').textContent='快速重击 · 左 Command';$('feedback').textContent='合成：0ms 按下 / 20ms 松开 / 30ms 再按 / 120ms 松开。新一代状态取消旧释放。';};
$('hideDemo').onclick=()=>{reset();setVisibility('dock-demo',true);$('stageState').textContent='隐藏 → 当前状态恢复';schedule(()=>setDown('keyA',true),100);schedule(()=>setDown('keyA',false),200);schedule(()=>setDown('shiftRight',true),300);schedule(()=>{setVisibility('dock-demo',false);$('feedback').textContent='仅恢复仍保持的右 Shift；隐藏期间已结束的 A 不补播。声音开关未改变。';},800);};
// Synthetic visual-only cases, for review evidence; never fed with real input.
window.UIReview={floating,snapshot:()=>({volumePercent,width,labelsOn,dockAutoHide,pianoOn,paused,reduced,hiddenReasons:[...hiddenReasons],pressed:[...visual].filter(([,s])=>s.pressed).map(([id])=>id),visualDown:[...visual].filter(([,s])=>s.visualDown).map(([id])=>id),pendingDemoTimers:scheduled.length,floatingNotes:floating.instances.size,floatingFramePending:noteFrame!==null}),reset,setDown,setVisibility,setLabels,setReduced,chooseWidth,applyScenario};
render();setReduced(reduced);
$('previewGallery').innerHTML=D.layouts.map(l=>`<article class="gallery-row"><h3>${l.widthPt} × 56pt</h3>${['rest','single','multi'].map(state=>`<figure><figcaption>${{rest:'静止',single:'单键',multi:'多键'}[state]} · 2x 文件按逻辑尺寸显示</figcaption><a href="previews/piano-${l.widthPt}-${state}@2x.png"><img src="previews/piano-${l.widthPt}-${state}@2x.png" width="${l.widthPt}" height="56" alt="${l.widthPt}pt，${state}，64 键带标签原生渲染"></a></figure>`).join('')}</article>`).join('');
