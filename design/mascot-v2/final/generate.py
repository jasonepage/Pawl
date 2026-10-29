#!/usr/bin/env python3
"""Pawl mascot v2, final direction: an old brass key in a kitten costume.
Flat vector, no outlines, no filters. Seven poses, three icon variants."""
import pathlib, base64, html

OUT = pathlib.Path(__file__).parent / "final"
OUT.mkdir(exist_ok=True)
G400, G500, G700, G900, G100 = "#4c7f1c", "#3c6a14", "#2c550d", "#16300a", "#e6efdc"

# Palettes. "tint" is the grayscale one for the tinted icon.
PAL = {
  "color": dict(b1="#f1cf5e", b2="#d4a62c", b3="#9c7514", lid="#cc9d26", lidline="#7d5c0e", bag="#b08420",
                ink="#1a1714", white="#fffdf5", fur="#f6f0dc", suit="#e4ddc6", suit2="#c6bc9f", pink="#e6b3a4",
                glow="#ffe9a0", tile="#d8dde6", tile2="#b7c0cc", spark="#ffe27a"),
  "dark":  dict(b1="#f6d86f", b2="#dcae34", b3="#a67c17", lid="#caa02a", lidline="#7d5c0e", bag="#b08420",
                ink="#1a1714", white="#fffdf5", fur="#f6f0dc", suit="#e4ddc6", suit2="#c6bc9f", pink="#e6b3a4",
                glow="#ffe9a0", tile="#d8dde6", tile2="#b7c0cc", spark="#ffe27a"),
  "tint":  dict(b1="#f2f2f2", b2="#cfcfcf", b3="#8c8c8c", lid="#bdbdbd", lidline="#5a5a5a", bag="#9a9a9a",
                ink="#141414", white="#ffffff", fur="#f4f4f4", suit="#e6e6e6", suit2="#bfbfbf", pink="#d9d9d9",
                glow="#ffffff", tile="#dddddd", tile2="#bbbbbb", spark="#f0f0f0"),
}

def defs(p, pid):
    return (f'<linearGradient id="{pid}brass" x1="0" y1="0" x2="1" y2="1">'
            f'<stop offset="0" stop-color="{p["b1"]}"/><stop offset=".55" stop-color="{p["b2"]}"/><stop offset="1" stop-color="{p["b3"]}"/></linearGradient>'
            f'<radialGradient id="{pid}glow"><stop offset="0" stop-color="{p["glow"]}" stop-opacity=".5"/><stop offset="1" stop-color="{p["glow"]}" stop-opacity="0"/></radialGradient>')

def sparkle(x, y, s, c):
    return f'<path fill="{c}" d="M{x} {y-s} Q{x} {y} {x+s} {y} Q{x} {y} {x} {y+s} Q{x} {y} {x-s} {y} Q{x} {y} {x} {y-s} Z"/>'

def hourglass(x, y, c, ink):
    return (f'<path fill="{c}" d="M{x-30} {y-40} h60 v12 l-24 28 l24 28 v12 h-60 v-12 l24-28 l-24-28 z"/>'
            f'<path fill="{ink}" opacity=".18" d="M{x-30} {y-40} h60 v12 l-24 28 h-12 l-24-28 z"/>')

def paw(x, y, p, pid, rot=0):
    return (f'<g transform="translate({x} {y}) rotate({rot})"><circle r="27" fill="url(#{pid}brass)"/>'
            f'<circle cx="-18" cy="-20" r="11" fill="url(#{pid}brass)"/><circle cx="0" cy="-27" r="11" fill="url(#{pid}brass)"/><circle cx="18" cy="-20" r="11" fill="url(#{pid}brass)"/></g>')

def mascot(pose, pal="color", pid="m", glow=True, face_only=False):
    p = PAL[pal]
    B = f"url(#{pid}brass)"
    out = ""
    if pose == "nokey":
        # Ghost outline: the same silhouette, dashed, no face.
        st = f'fill="none" stroke="{p["b2"]}" stroke-width="13" stroke-linejoin="round" stroke-linecap="round" stroke-dasharray="34 22"'
        out += f'<circle cx="256" cy="150" r="108" {st}/>'
        out += f'<path d="M184 70 L200 22 L240 58" {st}/><path d="M328 70 L312 22 L272 58" {st}/>'
        out += f'<path d="M228 256 Q212 350 234 476 L316 476 L316 444 L268 444 L268 420 L316 420 L316 388 L266 388 Q270 330 284 256" {st}/>'
        return out
    straight = pose == "open"
    if face_only:
        return out + face(pose, p, B)
    # shaft and chunky teeth
    if straight:
        out += (f'<path fill="{B}" d="M230 236 L230 476 L316 476 L316 444 L282 444 L282 420 L316 420 L316 388 L282 388 L282 236 Z"/>')
    else:
        out += (f'<path fill="{B}" d="M228 236 Q210 350 234 476 L316 476 L316 444 L268 444 L268 420 L316 420 L316 388 L266 388 Q270 320 284 236 Z"/>')
    out += face(pose, p, B)
    # pose extras
    if pose == "waiting":
        out += hourglass(432, 120, p["b2"], p["ink"])
    if pose == "resisted":
        # the swipe: arm up and out, paw batting a grey app tile off to the left
        out += f'<path d="M238 300 L166 238" stroke="{B}" stroke-width="30" stroke-linecap="round" fill="none"/>'
        out += paw(154, 226, p, pid, rot=-50)
    if pose == "slip":
        out += f'<path d="M238 340 L186 346" stroke="{B}" stroke-width="30" stroke-linecap="round" fill="none"/>'
        out += paw(172, 350, p, pid, rot=-90)
    return out

def face(pose, p, B):
    out = ""
    # ears (costume) behind the bow
    out += (f'<path d="M184 84 L200 22 L244 62 Z" fill="{p["suit"]}" stroke="{p["suit"]}" stroke-width="16" stroke-linejoin="round"/>'
            f'<path d="M328 84 L312 22 L268 62 Z" fill="{p["suit"]}" stroke="{p["suit"]}" stroke-width="16" stroke-linejoin="round"/>'
            f'<path d="M196 74 L204 44 L228 64 Z" fill="{p["pink"]}"/><path d="M316 74 L308 44 L284 64 Z" fill="{p["pink"]}"/>')
    # bow
    out += f'<circle cx="256" cy="150" r="108" fill="{B}"/>'
    out += f'<ellipse cx="222" cy="104" rx="42" ry="22" fill="{p["white"]}" opacity=".22"/>'
    # whiskers
    wk = f'stroke="{p["fur"]}" stroke-width="7" stroke-linecap="round" fill="none"'
    out += (f'<path d="M196 190 L156 184" {wk}/><path d="M196 206 L158 214" {wk}/>'
            f'<path d="M316 190 L356 184" {wk}/><path d="M316 206 L354 214" {wk}/>')
    # eyes: baggy, half lidded
    for cx, look in ((224, 1), (288, 1)):
        if pose == "waiting":
            out += f'<path d="M{cx-18} 150 Q{cx} 162 {cx+18} 150" stroke="{p["ink"]}" stroke-width="11" stroke-linecap="round" fill="none"/>'
        else:
            px = cx + (6 if pose == "open" else 2)
            py = 156 if pose != "streak" else 152
            out += f'<circle cx="{cx}" cy="150" r="24" fill="{p["white"]}"/>'
            out += f'<circle cx="{px}" cy="{py}" r="11" fill="{p["ink"]}"/>'
            lidy = 146 if pose == "streak" else 150
            out += f'<path d="M{cx-26} {lidy-4} Q{cx} {lidy+8} {cx+26} {lidy-4} L{cx+26} 122 L{cx-26} 122 Z" fill="{p["lid"]}"/>'
            out += f'<path d="M{cx-24} {lidy-3} Q{cx} {lidy+8} {cx+24} {lidy-3}" stroke="{p["lidline"]}" stroke-width="5" stroke-linecap="round" fill="none"/>'
        # bag under the eye
        out += f'<path d="M{cx-18} 178 Q{cx} 188 {cx+18} 178" stroke="{p["bag"]}" stroke-width="6" stroke-linecap="round" fill="none" opacity=".75"/>'
    # eyebrows: fuzzy, heavy, low. Inner ends sit lower (unimpressed).
    dy = -6 if pose == "streak" else 0
    bw = f'stroke="{p["fur"]}" stroke-width="16" stroke-linecap="round" fill="none"'
    out += f'<path d="M198 {104+dy} Q220 {94+dy} 244 {108+dy}" {bw}/><path d="M268 {108+dy} Q292 {94+dy} 314 {104+dy}" {bw}/>'
    for x, y in ((204, 102+dy), (230, 98+dy), (282, 98+dy), (308, 102+dy)):
        out += f'<circle cx="{x}" cy="{y}" r="10" fill="{p["fur"]}"/>'
    # mustache: fuzzy, wide, flat. The mouth is a flat line under it.
    out += f'<path d="M226 222 L286 222" stroke="{p["ink"]}" stroke-width="6" stroke-linecap="round" opacity=".7"/>'
    out += (f'<path fill="{p["fur"]}" d="M204 198 Q230 186 256 198 Q282 186 308 198 Q296 222 256 212 Q216 222 204 198 Z"/>'
            f'<circle cx="208" cy="202" r="8" fill="{p["fur"]}"/><circle cx="304" cy="202" r="8" fill="{p["fur"]}"/>'
            f'<circle cx="228" cy="212" r="7" fill="{p["fur"]}"/><circle cx="284" cy="212" r="7" fill="{p["fur"]}"/>')
    return out

def svg(body, d, vb="0 0 512 512"):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}"><defs>{d}</defs>{body}</svg>'

POSES = ["locked", "waiting", "open", "nokey", "resisted", "streak", "slip"]
MEAN = {"locked": "on guard, apps blocked", "waiting": "the wait is running", "open": "apps open for now",
        "nokey": "no key paired yet", "resisted": "rode out an urge: the swipe", "streak": "a milestone, a bit of sparkle",
        "slip": "after a slip: steady, we keep going"}

for pose in POSES:
    (OUT / f"pose-{pose}.svg").write_text(svg(mascot(pose), defs(PAL["color"], "m")))

# ---- icons
def icon(variant):
    pid = "i" + variant[0]
    if variant == "light":
        p = PAL["color"]
        bg = (f'<linearGradient id="{pid}bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="{G400}"/><stop offset=".5" stop-color="{G500}"/><stop offset="1" stop-color="{G700}"/></linearGradient>')
        back = f'<rect width="1024" height="1024" fill="url(#{pid}bg)"/>'
        g = True
    elif variant == "dark":
        p = PAL["dark"]; bg = ""; back = ""; g = True     # transparent: iOS adds its own dark background
    else:
        p = PAL["tint"]
        bg = f'<linearGradient id="{pid}bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#313131"/><stop offset="1" stop-color="#141414"/></linearGradient>'
        back = f'<rect width="1024" height="1024" fill="url(#{pid}bg)"/>'   # fully opaque grayscale
        g = False
    body = mascot("locked", pal="color" if variant == "light" else ("dark" if variant == "dark" else "tint"), pid=pid, glow=g, face_only=True)
    inner = f'<g transform="translate(512 556) scale(3.5) translate(-256 -150)">{body}</g>'
    return svg(back + inner, bg + defs(p, pid), vb="0 0 1024 1024")

for v in ("light", "dark", "tinted"):
    (OUT / f"icon-{v}.svg").write_text(icon(v))

# ---- preview page
cur = pathlib.Path("/mnt/user-data/uploads/Pawl-iOS/Pawl/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
cur_b64 = base64.b64encode(cur.read_bytes()).decode()
figs = "".join(f'<figure>{svg(mascot(po), defs(PAL["color"], "m"))}<figcaption><b>{po}</b><br>{MEAN[po]}</figcaption></figure>' for po in POSES)
li, di, ti = icon("light"), icon("dark"), icon("tinted")
dark_wrap = f'<div class="ico sysdark">{di}</div>'
page = f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Pawl: the old cat</title>
<style>
body{{margin:0;background:#f7f8f3;color:#1b2416;font:17px/1.55 -apple-system,BlinkMacSystemFont,"SF Pro Text",Helvetica,Arial,sans-serif;padding:16px}}
h1{{font-size:24px;margin:8px 0 4px}} h2{{font-size:19px;color:{G700};margin:22px 0 8px}} p{{margin:0 0 10px}} .muted{{color:#5b6653;font-size:15px}}
.poses{{display:grid;grid-template-columns:1fr 1fr;gap:10px}} figure{{margin:0;background:{G100};border-radius:14px;padding:10px;text-align:center}}
figure svg{{width:100%;height:auto}} figcaption{{font-size:13px;color:#5b6653;line-height:1.3}}
.home{{display:flex;gap:16px;align-items:flex-end;background:linear-gradient(160deg,#243b5a,#0f1a2b);border-radius:14px;padding:14px 12px 10px;flex-wrap:wrap}}
.home.light{{background:linear-gradient(160deg,#cfd8e6,#eef1f6)}} .home.light .app{{color:#1b2416}}
.app{{display:flex;flex-direction:column;align-items:center;gap:4px;color:#fff;font-size:11px}}
.ico{{width:60px;height:60px;border-radius:13.5px;overflow:hidden}} .ico svg,.ico img{{width:100%;height:100%;display:block}}
.sysdark{{background:linear-gradient(#313131,#141414)}} .systint{{background:linear-gradient(#5b7a3a,#2a3d18)}}
.small .ico{{width:29px;height:29px;border-radius:6.5px}}
.big{{display:flex;gap:10px}} .big .ico{{width:110px;height:110px;border-radius:25px}}
</style></head><body>
<h1>Pawl: the old cat</h1>
<p class="muted">A brass key in a kitten costume he did not ask for. Half-lidded, flat mouth, no grin. Tap nothing, just look.</p>
<h2>Home screen, 60 pt and 29 pt</h2>
<div class="home">
  <div class="app"><div class="ico">{li}</div><span>new</span></div>
  <div class="app"><div class="ico"><img src="data:image/png;base64,{cur_b64}" alt=""></div><span>today</span></div>
  <div class="app small"><div class="ico">{li}</div><span>29 pt</span></div>
  <div class="app small"><div class="ico">{svg(mascot("locked"), defs(PAL["color"], "m"))}</div><span>mascot</span></div>
  <div class="app"><div class="ico sysdark">{di}</div><span>dark</span></div>
  <div class="app"><div class="ico">{ti}</div><span>tinted</span></div>
</div>
<p class="muted" style="margin-top:8px">Dark is the key on a transparent background (iOS adds the dark gradient). Tinted is fully opaque grayscale; iOS paints it in the color the person picked.</p>
<h2>The three icon files, large</h2>
<div class="big"><div class="ico">{li}</div><div class="ico sysdark">{di}</div><div class="ico">{ti}</div></div>
<h2>Seven poses</h2>
<div class="poses">{figs}</div>
</body></html>'''
(OUT / "index.html").write_text(page)
print("ok")
