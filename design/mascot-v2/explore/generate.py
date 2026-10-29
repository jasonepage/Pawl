#!/usr/bin/env python3
"""Pawl mascot v2: exploration. Four directions, two poses each, plus an icon mock.
All flat vector, no outlines, no filters (Xcode's SVG support does not do filters)."""
import pathlib, html

OUT = pathlib.Path(__file__).parent / "explore"
OUT.mkdir(exist_ok=True)

G400, G500, G700, G900, G100 = "#4c7f1c", "#3c6a14", "#2c550d", "#16300a", "#e6efdc"
INK = "#1a1714"

def svg(body, defs="", vb="0 0 512 512"):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}">'
            f'<defs>{defs}</defs>{body}</svg>')

def hourglass(x, y, color, glow=None):
    s = ""
    if glow:
        s += f'<circle cx="{x}" cy="{y}" r="60" fill="url(#{glow})"/>'
    s += (f'<path fill="{color}" d="M{x-30} {y-40} h60 v12 l-24 28 l24 28 v12 h-60 v-12 l24-28 l-24-28 z"/>'
          f'<path fill="{INK}" opacity=".18" d="M{x-30} {y-40} h60 v12 l-24 28 h-12 l-24-28 z"/>')
    return s

# ---------------------------------------------------------------- A: Brass, remade
def A(pose):
    defs = f'''
    <linearGradient id="aBrass" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#f1cf5e"/><stop offset=".55" stop-color="#d4a62c"/><stop offset="1" stop-color="#9c7514"/></linearGradient>
    <radialGradient id="aGlow"><stop offset="0" stop-color="#ffe9a0" stop-opacity=".55"/><stop offset="1" stop-color="#ffe9a0" stop-opacity="0"/></radialGradient>'''
    body = f'<circle cx="256" cy="150" r="190" fill="url(#aGlow)"/>'
    # shaft with a gentle stoop, bits to the right
    body += (f'<path fill="url(#aBrass)" d="M228 236 Q210 350 234 476 L316 476 L316 444 L268 444 L268 420 L316 420 L316 388 L266 388 '
             f'Q270 320 284 236 Z"/>')
    body += f'<circle cx="256" cy="150" r="108" fill="url(#aBrass)"/>'
    body += f'<ellipse cx="226" cy="108" rx="40" ry="24" fill="#fff6d2" opacity=".35"/>'
    # eyebrows, bushy and white
    body += (f'<path d="M198 108 Q222 92 244 106" stroke="#fbf3dc" stroke-width="18" stroke-linecap="round" fill="none"/>'
             f'<path d="M268 106 Q290 92 314 108" stroke="#fbf3dc" stroke-width="18" stroke-linecap="round" fill="none"/>')
    if pose == "waiting":
        body += (f'<path d="M206 146 Q224 162 242 146" stroke="{INK}" stroke-width="12" stroke-linecap="round" fill="none"/>'
                 f'<path d="M270 146 Q288 162 306 146" stroke="{INK}" stroke-width="12" stroke-linecap="round" fill="none"/>')
    else:
        body += (f'<circle cx="224" cy="146" r="24" fill="#fffdf5"/><circle cx="288" cy="146" r="24" fill="#fffdf5"/>'
                 f'<circle cx="228" cy="150" r="12" fill="{INK}"/><circle cx="292" cy="150" r="12" fill="{INK}"/>')
    # mustache
    body += f'<path fill="#fbf3dc" d="M196 192 Q226 176 256 192 Q286 176 316 192 Q296 224 256 206 Q216 224 196 192 Z"/>'
    if pose == "waiting":
        body += hourglass(418, 120, "#d4a62c")
    return svg(body, defs)

# ---------------------------------------------------------------- B: Stout green keeper
def B(pose):
    defs = f'''
    <linearGradient id="bGreen" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#6aa32e"/><stop offset=".5" stop-color="{G500}"/><stop offset="1" stop-color="{G900}"/></linearGradient>
    <linearGradient id="bGold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f1cf5e"/><stop offset="1" stop-color="#b58a1a"/></linearGradient>'''
    body = ""
    # thick short shaft, big bits
    body += (f'<path fill="url(#bGreen)" d="M222 250 L222 440 Q222 462 244 462 L348 462 L348 426 L300 426 L300 400 L348 400 L348 364 L300 364 '
             f'L300 250 Z"/>')
    body += f'<rect x="136" y="48" width="240" height="214" rx="82" fill="url(#bGreen)"/>'
    body += f'<ellipse cx="200" cy="96" rx="44" ry="22" fill="#ffffff" opacity=".18"/>'
    # spectacles
    body += (f'<circle cx="220" cy="156" r="34" fill="#fffdf5"/><circle cx="292" cy="156" r="34" fill="#fffdf5"/>'
             f'<circle cx="220" cy="156" r="34" fill="none" stroke="url(#bGold)" stroke-width="10"/>'
             f'<circle cx="292" cy="156" r="34" fill="none" stroke="url(#bGold)" stroke-width="10"/>'
             f'<path d="M254 152 Q256 144 258 152" stroke="#d4a62c" stroke-width="8" stroke-linecap="round" fill="none"/>')
    if pose == "waiting":
        body += (f'<path d="M206 158 Q220 170 234 158" stroke="{INK}" stroke-width="10" stroke-linecap="round" fill="none"/>'
                 f'<path d="M278 158 Q292 170 306 158" stroke="{INK}" stroke-width="10" stroke-linecap="round" fill="none"/>')
    else:
        body += f'<circle cx="224" cy="160" r="13" fill="{INK}"/><circle cx="296" cy="160" r="13" fill="{INK}"/>'
    # white brows and walrus mustache
    body += (f'<path d="M190 112 Q214 100 236 110" stroke="#f4f1e6" stroke-width="16" stroke-linecap="round" fill="none"/>'
             f'<path d="M276 110 Q298 100 322 112" stroke="#f4f1e6" stroke-width="16" stroke-linecap="round" fill="none"/>')
    body += f'<path fill="#f4f1e6" d="M186 206 Q220 190 256 204 Q292 190 326 206 Q306 244 256 222 Q206 244 186 206 Z"/>'
    if pose == "waiting":
        body += hourglass(432, 110, "#d4a62c")
    return svg(body, defs)

# ---------------------------------------------------------------- C: Trefoil skeleton key, dusk
def C(pose):
    defs = f'''
    <linearGradient id="cBrass" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#e9c452"/><stop offset=".6" stop-color="#c0901f"/><stop offset="1" stop-color="#7d5a0e"/></linearGradient>
    <radialGradient id="cGlow"><stop offset="0" stop-color="#9fd25a" stop-opacity=".45"/><stop offset="1" stop-color="#9fd25a" stop-opacity="0"/></radialGradient>'''
    body = f'<circle cx="256" cy="160" r="200" fill="url(#cGlow)"/>'
    # thin shaft, ornate bit
    body += (f'<path fill="url(#cBrass)" d="M242 240 L242 478 L326 478 L326 448 L290 448 L290 430 L312 430 L312 404 L290 404 L290 386 '
             f'L270 386 L270 240 Z"/>')
    body += f'<rect x="228" y="236" width="56" height="22" rx="8" fill="url(#cBrass)"/>'
    # trefoil bow
    body += (f'<circle cx="256" cy="98" r="60" fill="url(#cBrass)"/>'
             f'<circle cx="192" cy="168" r="58" fill="url(#cBrass)"/>'
             f'<circle cx="320" cy="168" r="58" fill="url(#cBrass)"/>'
             f'<circle cx="256" cy="160" r="78" fill="url(#cBrass)"/>')
    body += f'<ellipse cx="236" cy="74" rx="26" ry="14" fill="#fff6d2" opacity=".4"/>'
    body += (f'<path d="M212 124 Q232 110 250 122" stroke="#fbf3dc" stroke-width="14" stroke-linecap="round" fill="none"/>'
             f'<path d="M262 122 Q280 110 300 124" stroke="#fbf3dc" stroke-width="14" stroke-linecap="round" fill="none"/>')
    if pose == "waiting":
        body += (f'<path d="M218 156 Q232 170 246 156" stroke="{INK}" stroke-width="10" stroke-linecap="round" fill="none"/>'
                 f'<path d="M266 156 Q280 170 294 156" stroke="{INK}" stroke-width="10" stroke-linecap="round" fill="none"/>')
    else:
        body += (f'<circle cx="232" cy="156" r="19" fill="#fffdf5"/><circle cx="280" cy="156" r="19" fill="#fffdf5"/>'
                 f'<circle cx="235" cy="159" r="9" fill="{INK}"/><circle cx="283" cy="159" r="9" fill="{INK}"/>')
    body += f'<path fill="#fbf3dc" d="M208 194 Q232 182 256 194 Q280 182 304 194 Q288 220 256 206 Q224 220 208 194 Z"/>'
    if pose == "waiting":
        body += hourglass(420, 110, "#c0901f")
    return svg(body, defs)

# ---------------------------------------------------------------- D: Nightlight
def D(pose):
    defs = f'''
    <radialGradient id="dLamp" cx=".4" cy=".35" r=".75"><stop offset="0" stop-color="#fffbe6"/><stop offset=".7" stop-color="#ffe08a"/><stop offset="1" stop-color="#f0c35a"/></radialGradient>
    <radialGradient id="dGlow"><stop offset="0" stop-color="#ffe27a" stop-opacity=".6"/><stop offset=".5" stop-color="#ffe27a" stop-opacity=".18"/><stop offset="1" stop-color="#ffe27a" stop-opacity="0"/></radialGradient>
    <linearGradient id="dBody" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#5f9a28"/><stop offset="1" stop-color="{G700}"/></linearGradient>'''
    body = f'<circle cx="256" cy="150" r="215" fill="url(#dGlow)"/>'
    body += (f'<path fill="url(#dBody)" d="M220 236 L220 436 Q220 468 252 468 L330 468 L330 432 L292 432 L292 404 L330 404 L330 368 L292 368 '
             f'L292 236 Z"/>')
    body += f'<circle cx="256" cy="150" r="104" fill="url(#dLamp)"/>'
    body += (f'<path d="M200 112 Q224 98 246 110" stroke="{G700}" stroke-width="17" stroke-linecap="round" fill="none"/>'
             f'<path d="M266 110 Q288 98 312 112" stroke="{G700}" stroke-width="17" stroke-linecap="round" fill="none"/>')
    if pose == "waiting":
        body += (f'<path d="M208 150 Q224 166 240 150" stroke="{G900}" stroke-width="13" stroke-linecap="round" fill="none"/>'
                 f'<path d="M272 150 Q288 166 304 150" stroke="{G900}" stroke-width="13" stroke-linecap="round" fill="none"/>')
    else:
        body += f'<ellipse cx="224" cy="150" rx="15" ry="19" fill="{G900}"/><ellipse cx="288" cy="150" rx="15" ry="19" fill="{G900}"/>'
        body += f'<circle cx="229" cy="143" r="5" fill="#fffbe6"/><circle cx="293" cy="143" r="5" fill="#fffbe6"/>'
    body += f'<path fill="{G700}" d="M198 196 Q228 180 256 196 Q284 180 314 196 Q294 226 256 210 Q218 226 198 196 Z"/>'
    if pose == "waiting":
        body += hourglass(420, 118, "#ffe08a", glow="dGlow")
    return svg(body, defs)

DIRS = {
 "A": ("Old Brass, remade", A, "The same old brass key, drawn properly. Upright, a soft gold halo, big eyes, white bushy brows and a white mustache. The closest to today.",
       dict(bg=f'<linearGradient id="ibg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{G400}"/><stop offset=".5" stop-color="{G500}"/><stop offset="1" stop-color="{G700}"/></linearGradient>', rot=-26, scale=2.15, dx=-50, dy=-30)),
 "B": ("The Stout Keeper", B, "A short, thick key in Pawl green with gold spectacles. Built like a gatekeeper: wide head, big teeth, nothing fragile about him.",
       dict(bg=f'<linearGradient id="ibg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f3f7ea"/><stop offset="1" stop-color="{G100}"/></linearGradient>', rot=0, scale=2.2, dx=0, dy=-14)),
 "C": ("The Skeleton Key", C, "A real old skeleton key with a clover head, thin and a little fancy, in a green dusk glow. The most 'old' of the four.",
       dict(bg=f'<linearGradient id="ibg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{G700}"/><stop offset="1" stop-color="#0d1d06"/></linearGradient>', rot=-28, scale=2.1, dx=-40, dy=-30, stars=True)),
 "D": ("Nightlight", D, "A chunky deep green key whose head glows like a small lamp. For the 1am moment: the one light that is still on. Dark eyes read at any size.",
       dict(bg=f'<linearGradient id="ibg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{G900}"/><stop offset="1" stop-color="#0b1a05"/></linearGradient>', rot=0, scale=2.2, dx=0, dy=-14)),
}

def icon(key):
    name, fn, blurb, opt = DIRS[key]
    inner = fn("locked")
    # pull the inner svg body out (strip outer svg wrapper, keep defs)
    inner_defs = inner.split("<defs>")[1].split("</defs>")[0]
    inner_body = inner.split("</defs>")[1].rsplit("</svg>", 1)[0]
    stars = ""
    if opt.get("stars"):
        pts = [(120,140,9),(880,120,7),(930,380,5),(140,760,6),(820,820,8),(520,80,5),(80,460,4),(960,600,5)]
        stars = "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#fff6d2" opacity=".55"/>' for x,y,r in pts)
    s = opt["scale"]; rot = opt["rot"]
    body = (f'<rect width="1024" height="1024" rx="226" fill="url(#ibg)"/>{stars}'
            f'<g transform="translate({512+opt["dx"]} {512+opt["dy"]}) rotate({rot}) scale({s}) translate(-256 -256)">{inner_body}</g>')
    return svg(body, opt["bg"] + inner_defs, vb="0 0 1024 1024")

current_icon = pathlib.Path("/mnt/user-data/uploads/Pawl-iOS/Pawl/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
import base64
cur_b64 = base64.b64encode(current_icon.read_bytes()).decode()

cards = ""
for k,(name, fn, blurb, opt) in DIRS.items():
    locked, waiting, ic = fn("locked"), fn("waiting"), icon(k)
    (OUT / f"{k}-locked.svg").write_text(locked)
    (OUT / f"{k}-waiting.svg").write_text(waiting)
    (OUT / f"{k}-icon.svg").write_text(ic)
    cards += f'''
<section class="card">
  <h2><span class="tag">{k}</span>{html.escape(name)}</h2>
  <p>{html.escape(blurb)}</p>
  <div class="poses">
    <figure>{locked}<figcaption>locked</figcaption></figure>
    <figure>{waiting}<figcaption>waiting</figcaption></figure>
  </div>
  <div class="home">
    <div class="app"><div class="ico">{ic}</div><span>Pawl</span></div>
    <div class="app"><div class="ico"><img src="data:image/png;base64,{cur_b64}" alt="current icon"></div><span>today</span></div>
    <div class="app small"><div class="ico">{ic}</div><span>29 pt</span></div>
    <div class="app small"><div class="ico">{locked}</div><span>mascot</span></div>
  </div>
</section>'''

page = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Pawl mascot: four directions</title>
<style>
:root{{--paper:#f7f8f3;--ink:#1b2416;--muted:#5b6653;--g7:{G700};--g1:{G100}}}
body{{margin:0;background:var(--paper);color:var(--ink);font:17px/1.55 -apple-system,BlinkMacSystemFont,"SF Pro Text",Helvetica,Arial,sans-serif;padding:16px}}
h1{{font-size:24px;margin:8px 0 4px}} .lead{{color:var(--muted);margin:0 0 18px}}
.card{{background:#fff;border:1px solid #dfe6d6;border-radius:18px;padding:16px;margin:0 0 18px}}
h2{{font-size:20px;margin:0 0 6px;color:var(--g7)}} .tag{{display:inline-block;background:var(--g7);color:#fff;border-radius:8px;padding:0 9px;margin-right:8px}}
.card p{{margin:0 0 12px;font-size:16px}}
.poses{{display:flex;gap:12px}} figure{{margin:0;flex:1;background:var(--g1);border-radius:14px;padding:10px;text-align:center}}
figure svg{{width:100%;height:auto;max-height:170px}} figcaption{{font-size:13px;color:var(--muted)}}
.home{{margin-top:12px;display:flex;gap:18px;align-items:flex-end;background:linear-gradient(160deg,#243b5a,#0f1a2b);border-radius:14px;padding:14px 14px 10px}}
.app{{display:flex;flex-direction:column;align-items:center;gap:4px;color:#fff;font-size:11px}}
.app .ico{{width:60px;height:60px;border-radius:13.5px;overflow:hidden}} .app .ico svg,.app .ico img{{width:100%;height:100%;display:block}}
.app.small .ico{{width:29px;height:29px;border-radius:6.5px}}
.foot{{color:var(--muted);font-size:15px}}
</style></head><body>
<h1>Pawl mascot: four directions</h1>
<p class="lead">Each one is shown in two poses, then on a dark home screen at real size (60 pt) next to today's icon, with a 29 pt version beside it. Reply with the letter you want finished, or mix ("B body with D glow").</p>
{cards}
<p class="foot">All four keep the rules: clearly a key, an old man, flat shapes with no outlines, vector only, readable at 29 pt. The icon in each card is a mock to show the direction, not the final file.</p>
</body></html>'''
(OUT / "index.html").write_text(page)
print("wrote", OUT)
