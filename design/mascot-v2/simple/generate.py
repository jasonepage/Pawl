#!/usr/bin/env python3
"""Pawl mascot v2, simplification pass. Flat shapes only.
Character: flat brass key, two triangle ears, two heavy half-lidded eyes, two cream brow strokes, one cream mustache."""
import pathlib, base64

OUT = pathlib.Path(__file__).parent / "simple"
OUT.mkdir(exist_ok=True)
G400, G500, G700 = "#4c7f1c", "#3c6a14", "#2c550d"

PAL = {
  "color": dict(gold="#d4a62c", lid="#8a6612", ink="#1a1714", white="#fffdf5", cream="#f6f0dc"),
  "dark":  dict(gold="#e0b23a", lid="#8a6612", ink="#1a1714", white="#fffdf5", cream="#f6f0dc"),
  "tint":  dict(gold="#c8c8c8", lid="#505050", ink="#141414", white="#ffffff", cream="#f2f2f2"),
}

def face(p):
    g = p["gold"]
    out = ""
    # ears: two plain triangles
    out += f'<path d="M178 92 L198 26 L246 64 Z" fill="{g}"/><path d="M334 92 L314 26 L266 64 Z" fill="{g}"/>'
    # bow
    out += f'<circle cx="256" cy="150" r="108" fill="{g}"/>'
    # eyes: white disc, pupil, then the lid (bow color) covering the top half, with a dark lid edge
    for cx in (224, 288):
        out += (f'<circle cx="{cx}" cy="150" r="24" fill="{p["white"]}"/>'
                f'<circle cx="{cx+2}" cy="158" r="11" fill="{p["ink"]}"/>'
                f'<path d="M{cx-26} 146 Q{cx} 160 {cx+26} 146 L{cx+26} 120 L{cx-26} 120 Z" fill="{g}"/>'
                f'<path d="M{cx-24} 147 Q{cx} 160 {cx+24} 147" stroke="{p["lid"]}" stroke-width="6" stroke-linecap="round" fill="none"/>')
    # brows: two short flat strokes, inner ends lower
    bw = f'stroke="{p["cream"]}" stroke-width="16" stroke-linecap="round" fill="none"'
    out += f'<path d="M200 106 L244 114" {bw}/><path d="M268 114 L312 106" {bw}/>'
    # mustache: one flat shape
    out += f'<path d="M204 196 Q256 184 308 196 Q290 216 256 208 Q222 216 204 196 Z" fill="{p["cream"]}"/>'
    return out

def paw(x, y, g, rot):
    return (f'<g transform="translate({x} {y}) rotate({rot})"><circle r="27" fill="{g}"/>'
            f'<circle cx="-18" cy="-20" r="11" fill="{g}"/><circle cx="0" cy="-27" r="11" fill="{g}"/><circle cx="18" cy="-20" r="11" fill="{g}"/></g>')

def mascot(pose, pal="color"):
    p = PAL[pal]; g = p["gold"]
    out = f'<path fill="{g}" d="M230 236 L230 476 L316 476 L316 444 L282 444 L282 420 L316 420 L316 388 L282 388 L282 236 Z"/>'
    out += face(p)
    if pose == "resisted":
        out += f'<path d="M240 336 L172 282" stroke="{g}" stroke-width="30" stroke-linecap="round"/>' + paw(160, 272, g, -50)
    return out

def svg(body, vb="0 0 512 512"):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}">{body}</svg>'

def icon(v):
    if v == "light":
        back = (f'<defs><linearGradient id="lbg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{G400}"/><stop offset=".5" stop-color="{G500}"/><stop offset="1" stop-color="{G700}"/></linearGradient></defs>'
                f'<rect width="1024" height="1024" fill="url(#lbg)"/>'); pal = "color"
    elif v == "dark":
        back = ""; pal = "dark"
    else:
        back = ('<defs><linearGradient id="tbg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#313131"/><stop offset="1" stop-color="#141414"/></linearGradient></defs>'
                '<rect width="1024" height="1024" fill="url(#tbg)"/>'); pal = "tint"
    return svg(back + f'<g transform="translate(512 556) scale(3.5) translate(-256 -150)">{face(PAL[pal])}</g>', vb="0 0 1024 1024")

for po in ("locked", "resisted"):
    (OUT / f"pose-{po}.svg").write_text(svg(mascot(po)))
for v in ("light", "dark", "tinted"):
    (OUT / f"icon-{v}.svg").write_text(icon(v))

cur = pathlib.Path("/mnt/user-data/uploads/Pawl-iOS/Pawl/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
cur_b64 = base64.b64encode(cur.read_bytes()).decode()
li, di, ti = icon("light"), icon("dark"), icon("tinted")
sw = svg(mascot("resisted")); lk = svg(mascot("locked"))
page = f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Pawl: simplified</title>
<style>
body{{margin:0;background:#f7f8f3;color:#1b2416;font:17px/1.55 -apple-system,BlinkMacSystemFont,"SF Pro Text",Helvetica,Arial,sans-serif;padding:16px}}
h1{{font-size:24px;margin:8px 0 4px}} h2{{font-size:19px;color:{G700};margin:22px 0 8px}} p{{margin:0 0 10px}} .muted{{color:#5b6653;font-size:15px}}
.home{{display:flex;gap:16px;align-items:flex-end;background:linear-gradient(160deg,#243b5a,#0f1a2b);border-radius:14px;padding:14px 12px 10px;flex-wrap:wrap}}
.app{{display:flex;flex-direction:column;align-items:center;gap:4px;color:#fff;font-size:11px}}
.ico{{width:60px;height:60px;border-radius:13.5px;overflow:hidden}} .ico svg,.ico img{{width:100%;height:100%;display:block}}
.sysdark{{background:linear-gradient(#313131,#141414)}}
.small .ico{{width:29px;height:29px;border-radius:6.5px}}
.big{{display:flex;gap:10px}} .big .ico{{width:110px;height:110px;border-radius:25px}}
.poses{{display:flex;gap:10px}} figure{{margin:0;flex:1;background:#e6efdc;border-radius:14px;padding:10px;text-align:center}} figure svg{{width:100%;height:auto}} figcaption{{font-size:13px;color:#5b6653}}
</style></head><body>
<h1>Pawl: simplified</h1>
<p class="muted">Flat brass, two ears, two droopy eyes, two brow strokes, one mustache. Nothing else.</p>
<h2>Home screen, 60 pt and 29 pt</h2>
<div class="home">
  <div class="app"><div class="ico">{li}</div><span>new</span></div>
  <div class="app"><div class="ico"><img src="data:image/png;base64,{cur_b64}" alt=""></div><span>today</span></div>
  <div class="app"><div class="ico sysdark">{di}</div><span>dark</span></div>
  <div class="app"><div class="ico">{ti}</div><span>tinted</span></div>
  <div class="app small"><div class="ico">{li}</div><span>29</span></div>
  <div class="app small"><div class="ico sysdark">{di}</div><span>dark</span></div>
  <div class="app small"><div class="ico">{ti}</div><span>tint</span></div>
  <div class="app small"><div class="ico">{sw}</div><span>swipe</span></div>
</div>
<h2>The three icon files, large</h2>
<div class="big"><div class="ico">{li}</div><div class="ico sysdark">{di}</div><div class="ico">{ti}</div></div>
<h2>Poses</h2>
<div class="poses"><figure>{lk}<figcaption>locked</figcaption></figure><figure>{sw}<figcaption>resisted: the swipe</figcaption></figure></div>
</body></html>'''
(OUT / "index.html").write_text(page)
print("ok")
