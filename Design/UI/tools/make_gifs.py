#!/usr/bin/env python3
"""Encode deterministic native frames using already-installed Pillow; does not install packages."""
from pathlib import Path
from PIL import Image
ui = Path(__file__).resolve().parents[1]
for name in ['single','multi','labels-off','reduced']:
    frames=[Image.open(ui/f'qa/frames/{name}-{t}.png').convert('RGB') for t in range(0,701,20)]
    frames[0].save(ui/f'previews/floating-{name}.gif',save_all=True,append_images=frames[1:],duration=20,optimize=False,disposal=2)
    for frame in frames: frame.close()
print('4 one-shot GIFs encoded; 720ms container; effect lifetime 700ms / reduced 200ms.')
