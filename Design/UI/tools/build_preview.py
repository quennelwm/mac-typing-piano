#!/usr/bin/env python3
"""Create review assets from read-only mapping and native glyph geometry. Stdlib only."""
from pathlib import Path
import copy
import hashlib
import html
import json

ROOT = Path(__file__).resolve().parents[3]
UI = ROOT / 'Design/UI'
KEYMAP = ROOT / 'contracts/keymap.ansi64.v0.1.json'
keymap = json.loads(KEYMAP.read_text())
layouts = json.loads((UI / 'qa/layouts.json').read_text())

PALETTE = {
    'white': {'rest': ['#FEFDFB', '#EEEDE9'], 'pressed': ['#E7E5DF', '#D8D6D1'], 'front': {'rest': '#D5D3CE', 'pressed': '#C3C1BC'}, 'label': '#595959'},
    'black': {'rest': ['#424346', '#242528'], 'pressed': ['#303134', '#1B1C1F'], 'front': {'rest': '#17181B', 'pressed': '#141518'}, 'label': '#CDCDCD'},
}

def dump(path, obj):
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + '\n')

def surface(color, state, w, h, gid):
    p = PALETTE[color]
    radius, front = (1.2, 2) if color == 'black' else (1, 2.5)
    highlight = '#58595C' if color == 'black' else '#FFFFFF'
    return f'''<defs><linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1"><stop stop-color="{p[state][0]}"/><stop offset="1" stop-color="{p[state][1]}"/></linearGradient><clipPath id="{gid}-clip"><rect width="{w}" height="{h}" rx="{radius}"/></clipPath></defs>
<g clip-path="url(#{gid}-clip)"><rect width="{w}" height="{h}" fill="url(#{gid})"/><rect y="{h-front}" width="{w}" height="{front}" fill="{p['front'][state]}"/><path d="M1 .5H{w-1}" fill="none" stroke="{highlight}" stroke-width=".5"/></g>'''

assets = []
for color, w, h in [('white', 32, 50), ('black', 19, 32)]:
    for state in ['rest', 'pressed']:
        name = f'{color}-{state}'
        path = UI / f'components/{name}.svg'
        path.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">\n' + surface(color, state, w, h, name) + '\n</svg>\n')
        assets.append({'id': name, 'path': str(path.relative_to(UI)), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'byteSize': path.stat().st_size, 'format': 'svg', 'pixelWidth': None, 'pixelHeight': None, 'scale': None, 'notApplicable': 'Vector, no fixed raster dimensions or backing scale.', 'viewBox': [0, 0, w, h], 'contentRectPt': [0, 0, w, h], 'capInsetsPt': {'top': 1.5, 'left': 1.5, 'bottom': 3, 'right': 1.5}, 'anchor': {'x': 0.5, 'y': 0, 'units': 'normalized'}, 'state': state, 'transparency': True, 'licenseRef': 'SOURCE_AND_LICENSE.md#original-design', 'role': 'key-face-without-labels', 'rendering': 'Prefer parameterized path drawing to preserve corner radii; do not stretch glyphs.'})

for name, w, h, body, cap, role in [
    ('base', 1000, 56, '<rect width="1000" height="56" rx="3" fill="#353638"/><rect x="1" y="1" width="998" height="53" rx="2" fill="#71716E"/>', [3,3,3,3], 'base'),
    ('shadow', 23, 37, '<defs><filter id="s" x="-30%" y="-30%" width="160%" height="170%"><feGaussianBlur stdDeviation=".75"/></filter></defs><rect x="2" y="3" width="19" height="32" rx="1.2" fill="#000000" opacity=".3" filter="url(#s)"/>', None, 'black-key-shadow')]:
    path = UI / f'components/{name}.svg'
    path.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>\n')
    assets.append({'id': name, 'path': str(path.relative_to(UI)), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'byteSize': path.stat().st_size, 'format':'svg','pixelWidth':None,'pixelHeight':None,'scale':None,'notApplicable':'Vector; shadow is parameterized and not nine-sliced.','viewBox':[0,0,w,h],'contentRectPt': [2,2,19,32] if name=='shadow' else [0,0,w,h], 'capInsetsPt': dict(zip(['top','left','bottom','right'],cap)) if cap else None, 'anchor': {'x':0.5,'y':0,'units':'normalized'},'state':'rest','transparency':True,'licenseRef':'SOURCE_AND_LICENSE.md#original-design','role':role})

for size in [16,18]:
    for scale in [1,2]:
        path=UI/f'components/icons/menu-note-{size}@{scale}x.png'
        assets.append({'id':f'menu-note-{size}-{scale}x','path':str(path.relative_to(UI)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'byteSize':path.stat().st_size,'format':'png','pixelWidth':size*scale,'pixelHeight':size*scale,'scale':scale,'contentRectPt':[0,0,size,size],'capInsetsPt':None,'anchor':{'x':.5,'y':.5,'units':'normalized'},'state':'template','transparency':True,'licenseRef':'SOURCE_AND_LICENSE.md#字体','role':'status-item-template','templateImage':True})

theme = copy.deepcopy(json.loads((ROOT / 'contracts/ui.theme.example.json').read_text()))
theme.update({'themeVersion':'quiet-ivory-u001.0.3','artifactState':'design_proposal','assets':assets,'sourceMapping':{'path':'contracts/keymap.ansi64.v0.1.json','mappingVersion':keymap['mappingVersion'],'sha256':hashlib.sha256(KEYMAP.read_bytes()).hexdigest()},'readinessNote':'U-001 candidate only; PM-002 approval and native product integration pending. CR-001 label toggle/menu CR-002 floating notes and CR-003 icon/volume slider included. No system setting is changed.'})
theme['labels'].update({'sideFontSizePt':6.5, 'sideMarkerMode':'separate_upper_right_text','whiteColorHex':'#595959','blackColorHex':'#CDCDCD','userToggleAllowed':True,'mainOpticalOffsetWithSidePt':-0.6,'sideRightInsetPt':1.1,'sideInkGapAboveMainPt':{'black':0.6,'white':-2},'fontWeight':'medium','fontStrategy':'system UI font with verified OS fallback; no font binaries distributed'})
theme['geometry'].update({'outerInsetHorizontalPt':2,'keyTopPt':2,'whiteFaceHeightPt':50,'blackFaceHeightPt':32,'whiteGapPt':0.7,'restKeyBottomPt':52,'depressedKeyBottomPt':54,'heightScope':'Only 56pt rendered and checked in U-001; 48–76pt range remains unverified.'})
theme['candidateParameters']={'schemaNote':'Additional candidate metadata requires PM/Code acceptance; no contract file changed.','palette':PALETTE,'blackShadow':{'rest':{'offsetPt':[0,1],'blurPt':1.5,'opacity':0.3},'pressed':{'offsetPt':[0,0.5],'blurPt':0.5,'opacity':0.18}},'mainEntry':'macOS status item and drop-down menu','menuIcon':{'glyph':'♪','sizesPt':[16,18],'isTemplate':True,'accessibleName':'打字钢琴','animateOnTyping':False},'volumeControl':{'kind':'horizontal-slider','rangePercent':[0,100],'target':'application-audio-bus','independentOfSoundToggle':True,'systemVolumeUnchanged':True},'dockAutoHide':{'initialPreference':True,'controls':'macOS Dock setting, separately from piano avoidance','offWarning':'关闭自动隐藏后，Dock 可能与底部钢琴重叠或遮挡。仍要关闭吗？','cancelLabel':'保持自动隐藏','confirmLabel':'仍然关闭','runtimeImplemented':False},'labelsOff':'Hide label layer only; retain key geometry and press animation.'}
theme['motion']['floatingNote'].update({'colorHex':'#626C66','haloColorHex':'#FFFFFF','haloBlurPt':1.25,'easingFormula':'1 - (1 - t)^3','timeDomain':'normalized t in [0,1]'})
dump(UI/'theme.candidate.json', theme)

# Embedded data is generated from the canonical read-only mapping; no browser fetch/server required.
embedded = {'mappingVersion':keymap['mappingVersion'],'layouts':layouts['layouts'],'scenarios':layouts['scenarios'],'palette':PALETTE,'themeVersion':theme['themeVersion']}
(UI/'preview-data.js').write_text('window.UI_REVIEW_DATA = ' + json.dumps(embedded,ensure_ascii=False,separators=(',',':')) + ';\n')

# Standalone SVG snapshots are review-only composites; assets above carry no text.
for layout in layouts['layouts']:
    w = layout['widthPt']
    for state, pressed_ids in layouts['scenarios'].items():
        pressed = set(pressed_ids)
        parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="56" viewBox="0 0 {w} 56" role="img" aria-label="64键钢琴 {state}">', '<rect width="100%" height="56" rx="3" fill="#353638"/><rect x="1" y="1" width="'+str(w-2)+'" height="53" rx="2" fill="#71716E"/>']
        for color in ['white','black']:
            for key in layout['keys']:
                if key['color'] != color: continue
                x,y,kw,kh = key['rectPt']; down=key['physicalKeyID'] in pressed
                dy = (1.5 if color=='black' else 2) if down else 0
                parts.append(f'<g transform="translate(0 {dy})"><g transform="translate({x} {y})">'+surface(color,'pressed' if down else 'rest',kw,kh,f"g{key['midiNote']}")+'</g><g class="label-layer">')
                for label in key['labels']:
                    parts.append(f'<text x="{label["x"]}" y="{label["baselineY"]}" font-family="-apple-system, BlinkMacSystemFont, system-ui, sans-serif" font-weight="500" font-size="{label["fontSizePt"]}" fill="{PALETTE[color]["label"]}">{html.escape(label["text"])}</text>')
                parts.append('</g></g>')
        parts.append('</svg>')
        (UI/f'previews/piano-{w}-{state}.svg').write_text('\n'.join(parts)+'\n')
print(f'Generated {len(assets)} composable assets (6 SVG + 4 PNG), theme candidate, derived viewer data and 9 SVG snapshots.')
