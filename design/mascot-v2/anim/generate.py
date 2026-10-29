#!/usr/bin/env python3
"""Pawl mascot v2: flat face, fixed mustache and brows, animated states. Zero gradients anywhere."""
import pathlib, base64, json

OUT = pathlib.Path(__file__).parent / "anim"
OUT.mkdir(exist_ok=True)
GREEN = "#366215"

PAL = {
  "color": dict(gold="#cb9f24", dark="#af8320", cream="#f0e0c0", white="#f0e0c0", ring="#806010", lid="#b18725", ink="#1a1714", app="#d8dde6", app2="#b7c0cc", red="#d9534f", key="#4c7f1c", keyplug="#c9ced6"),
  "dark":  dict(gold="#d6aa2c", dark="#b88a22", cream="#f0e0c0", white="#f0e0c0", ring="#806010", lid="#b18725", ink="#1a1714", app="#d8dde6", app2="#b7c0cc", red="#d9534f", key="#4c7f1c", keyplug="#c9ced6"),
  "tint":  dict(gold="#c4c4c4", dark="#a0a0a0", cream="#f4f4f4", white="#f4f4f4", ring="#555555", lid="#a8a8a8", ink="#141414", app="#dddddd", app2="#bbbbbb", red="#999999", key="#aaaaaa", keyplug="#dddddd"),
}

_CLIP = 0
TRACED = json.loads(pathlib.Path(__file__).with_name("traced.json").read_text())
LID_TOP = 156.5

def _paths(key, color, cls=""):
    c = f' class="{cls}"' if cls else ""
    return "".join(f'<path{c} d="{d}" fill="{color}"/>' for d in TRACED[key])

def face(p, cls=""):
    """The whole key, traced from the reference. Lids are separate so they can blink."""
    out = f'<g class="head {cls}">'
    out += _paths("body", p["gold"]) + _paths("innerear", p["dark"]) + _paths("stemdark", p["dark"])
    # eyes, measured from the reference along scanlines: true circles
    for side, cx in (("l", 210.1), ("r", 301.9)):
        cy = 185.6
        global _CLIP; _CLIP += 1; cid = f"eye{_CLIP}"
        out += f'<clipPath id="{cid}"><circle cx="{cx}" cy="{cy}" r="29.3"/></clipPath>'
        out += f'<circle cx="{cx}" cy="{cy}" r="29.3" fill="{p["white"]}"/>'
        out += f'<circle cx="{cx}" cy="186" r="15.9" fill="{p["ink"]}"/>'
        out += (f'<g clip-path="url(#{cid})"><g class="lid lid-{side}" style="transform-origin:{cx}px 156.3px">'
                f'<rect x="{cx-30}" y="156.3" width="60" height="26.3" fill="{p["lid"]}"/>'
                f'<rect x="{cx-30}" y="182.6" width="60" height="3.4" fill="{p["dark"]}"/></g></g>')
        out += f'<circle cx="{cx}" cy="{cy}" r="32.1" fill="none" stroke="{p["ring"]}" stroke-width="5.6"/>'
        out += (f'<path class="shut shut-{side}" d="M{cx-20} {cy+4} Q{cx} {cy+22} {cx+20} {cy+4}" fill="none" '
                f'stroke="{p["ring"]}" stroke-width="6" stroke-linecap="round" opacity="0"/>')
    bw = f'stroke="{p["cream"]}" stroke-width="9.8" stroke-linecap="round" fill="none"'
    out += f'<path d="M189.8 140.4 L237.7 133.8" {bw}/><path d="M274.3 133.8 L322.2 140.4" {bw}/>'
    out += _paths("mustache", p["cream"])
    return out + "</g>"

def mitten(p, cls="mitt"):
    g = p["gold"]; c = p["cream"]
    return (f'<g class="{cls}"><circle r="36" fill="{g}"/>'
            f'<circle cx="-22" cy="-24" r="14" fill="{g}"/><circle cx="0" cy="-32" r="14" fill="{g}"/><circle cx="22" cy="-24" r="14" fill="{g}"/>'
            f'<circle cx="-22" cy="-24" r="6" fill="{c}"/><circle cx="0" cy="-32" r="6" fill="{c}"/><circle cx="22" cy="-24" r="6" fill="{c}"/>'
            f'<ellipse cy="6" rx="15" ry="12" fill="{c}"/></g>')

def paw_arm(p, cls="paw", extra=""):
    g = p["gold"]
    return (f'<g class="{cls}" style="transform-origin:250px 340px">{extra}'
            f'<path d="M250 340 L182 282" stroke="{g}" stroke-width="30" stroke-linecap="round"/>'
            f'<g transform="translate(160 272) rotate(-50)"><circle r="27" fill="{g}"/>'
            f'<circle cx="-18" cy="-20" r="11" fill="{g}"/><circle cx="0" cy="-27" r="11" fill="{g}"/><circle cx="18" cy="-20" r="11" fill="{g}"/></g></g>')

def shaft(p):
    return ""

def app_tile(p, cls):
    return (f'<g class="{cls}"><rect x="-30" y="-30" width="60" height="60" rx="14" fill="{p["app"]}"/>'
            f'<rect x="-16" y="-12" width="32" height="7" rx="3.5" fill="{p["app2"]}"/><rect x="-16" y="4" width="24" height="7" rx="3.5" fill="{p["app2"]}"/>'
            f'<circle cx="24" cy="-24" r="9" fill="{p["red"]}"/></g>')

def svg(body, css="", vb="0 0 512 512", cls=""):
    style = f"<style>{css}</style>" if css else ""
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}" class="{cls}">{style}{body}</svg>'

P = PAL["color"]
CLOSED = 2.1

def state(name):
    """Returns (svg, caption)."""
    pre = f".{name} "
    base = f"{pre}*{{transform-box:view-box}}"
    if name == "idle":
        css = base + f'''{pre}.lid{{animation:{name}-blink 4s infinite}}
{pre}.shut{{animation:{name}-shut 4s infinite}}
@keyframes {name}-shut{{0%,95%{{opacity:0}}95.5%,96.2%{{opacity:1}}96.8%,100%{{opacity:0}}}}
{pre}.shut{{animation:{name}-shut 4s infinite}}
@keyframes {name}-blink{{0%,93%{{transform:scaleY(1)}}95.5%{{transform:scaleY({CLOSED})}}98%{{transform:scaleY(1)}}}}
@keyframes {name}-shut{{0%,95%{{opacity:0}}95.5%,96.2%{{opacity:1}}96.8%,100%{{opacity:0}}}}'''
        body = shaft(P) + face(P)
        return svg(body, css, cls=name), "Idle: one slow blink every four seconds."
    if name == "swipe":
        T = "2.6s"
        css = base + f'''{pre}.mitt{{animation:{name}-paw {T} infinite;transform:translate(-80px,310px)}}
{pre}.tile{{animation:{name}-tile {T} infinite;opacity:0}}
{pre}.lid{{animation:{name}-eyes {T} infinite}}
@keyframes {name}-paw{{
  0%,18%{{transform:translate(-80px,310px) rotate(0deg);animation-timing-function:cubic-bezier(.3,.7,.4,1)}}
  38%{{transform:translate(236px,310px) rotate(0deg);animation-timing-function:cubic-bezier(.4,0,.6,1)}}
  47%{{transform:translate(196px,318px) rotate(-18deg);animation-timing-function:cubic-bezier(.1,.9,.2,1)}}
  55%{{transform:translate(372px,296px) rotate(24deg);animation-timing-function:cubic-bezier(.5,0,.3,1)}}
  70%{{transform:translate(330px,306px) rotate(8deg);animation-timing-function:cubic-bezier(.4,0,.6,1)}}
  100%{{transform:translate(-80px,310px) rotate(0deg)}}}}
@keyframes {name}-tile{{
  0%{{opacity:0;transform:translate(600px,300px) rotate(0deg);animation-timing-function:cubic-bezier(.2,.8,.3,1)}}
  6%{{opacity:1}}
  24%,52%{{opacity:1;transform:translate(402px,300px) rotate(0deg);animation-timing-function:cubic-bezier(.1,.8,.3,1)}}
  66%{{opacity:1;transform:translate(640px,160px) rotate(160deg)}}
  67%,100%{{opacity:0;transform:translate(640px,160px)}}}}
@keyframes {name}-eyes{{
  0%,46%{{transform:scaleY(1)}}52%,62%{{transform:scaleY(.5)}}80%,100%{{transform:scaleY(1)}}}}'''
        body = app_tile(P, "tile") + shaft(P) + face(P) + mitten(P)
        return svg(body, css, cls=name), "Swipe: a paw comes in, winds up, bats the app off the table, drifts back out. Eyes go wide for the hit."
    if name == "locked":
        css = base + f'''{pre}.lid{{transform:scaleY({CLOSED})}}
{pre}.shut{{opacity:1}}
{pre}.body{{animation:{name}-breathe 3.2s ease-in-out infinite;transform-origin:256px 476px}}
{pre}.head{{animation:{name}-nod 3.2s ease-in-out infinite;transform-origin:256px 430px}}
{pre}.z{{opacity:0;animation:{name}-z 3.2s ease-out infinite;font:700 44px -apple-system,Helvetica,Arial,sans-serif;fill:{P["ink"]}}}
{pre}.z2{{animation-delay:1.1s;font-size:30px}}
@keyframes {name}-breathe{{0%,100%{{transform:scaleY(1)}}50%{{transform:scaleY(1.015)}}}}
@keyframes {name}-nod{{0%,100%{{transform:rotate(-1.5deg)}}50%{{transform:rotate(1.5deg)}}}}
@keyframes {name}-z{{0%{{opacity:0;transform:translate(0,0)}}20%{{opacity:.9}}100%{{opacity:0;transform:translate(26px,-70px)}}}}'''
        lock = (f'<g transform="translate(420 420)"><rect x="-34" y="-10" width="68" height="54" rx="12" fill="{P["ink"]}"/>'
                f'<path d="M-20 -10 V-26 a20 20 0 0 1 40 0 V-10" fill="none" stroke="{P["ink"]}" stroke-width="12" stroke-linecap="round"/>'
                f'<circle cy="16" r="7" fill="{P["gold"]}"/></g>')
        body = f'<g class="body">{shaft(P)}{face(P)}</g>' + lock + f'<text class="z" x="372" y="110">z</text><text class="z z2" x="396" y="130">z</text>'
        return svg(body, css, cls=name), "Locked: asleep on the job. The door stays locked."
    if name == "waiting":
        css = base + f'''{pre}.hg{{animation:{name}-flip 3s ease-in-out infinite;transform-origin:430px 120px}}
{pre}.lid{{animation:{name}-blink 5s infinite}}
{pre}.shut{{animation:{name}-shut 5s infinite}}
@keyframes {name}-shut{{0%,95%{{opacity:0}}95.5%,96.2%{{opacity:1}}96.8%,100%{{opacity:0}}}}
@keyframes {name}-flip{{0%,70%{{transform:rotate(0)}}85%,100%{{transform:rotate(180deg)}}}}
@keyframes {name}-blink{{0%,93%{{transform:scaleY(1)}}95.5%{{transform:scaleY({CLOSED})}}98%{{transform:scaleY(1)}}}}'''
        hg = (f'<g class="hg"><path fill="{P["gold"]}" d="M400 80 h60 v12 l-24 28 l24 28 v12 h-60 v-12 l24-28 l-24-28 z"/>'
              f'<path fill="{P["ink"]}" opacity=".18" d="M400 80 h60 v12 l-24 28 h-12 l-24-28 z"/></g>')
        body = shaft(P) + face(P) + hg
        return svg(body, css, cls=name), "Waiting: fifteen minutes on the clock. He waits. The hourglass does the work."
    if name == "blocked":
        css = base + f'''{pre}.lid-r{{transform:scaleY({CLOSED})}}
{pre}.shut-r{{opacity:1}}
{pre}.shut-l{{animation:{name}-shutl 4.5s infinite}}
{pre}.lid-l{{animation:{name}-eye 4.5s infinite;transform:scaleY({CLOSED})}}
@keyframes {name}-shutl{{0%,26%{{opacity:1}}28%,84%{{opacity:0}}87%,100%{{opacity:1}}}}
{pre}.mitt{{transform:translate(372px,570px);animation:{name}-paw 4.5s infinite}}
{pre}.tile{{opacity:0;animation:{name}-tile 4.5s infinite}}
@keyframes {name}-eye{{0%,24%{{transform:scaleY({CLOSED})}}30%,80%{{transform:scaleY(1)}}86%,100%{{transform:scaleY({CLOSED})}}}}
@keyframes {name}-paw{{0%,32%{{transform:translate(372px,570px);animation-timing-function:cubic-bezier(.2,.9,.3,1)}}42%,80%{{transform:translate(372px,300px);animation-timing-function:cubic-bezier(.5,0,.7,.4)}}92%,100%{{transform:translate(372px,570px)}}}}
@keyframes {name}-tile{{0%,12%{{opacity:0;transform:translate(560px,300px)}}22%,76%{{opacity:1;transform:translate(468px,300px)}}84%,100%{{opacity:0;transform:translate(560px,300px)}}}}'''
        body = app_tile(P, "tile") + shaft(P) + face(P) + mitten(P)
        return svg(body, css, cls=name), "Blocked app opened: one eye opens. A paw comes up. Stop."
    if name == "unlocked":
        css = base + f'''{pre}.mitt{{transform:translate(130px,570px);animation:{name}-paw 4s infinite}}
{pre}.lid{{animation:{name}-blink 4s infinite}}
{pre}.shut{{animation:{name}-shut 4s infinite}}
@keyframes {name}-shut{{0%,95%{{opacity:0}}95.5%,96.2%{{opacity:1}}96.8%,100%{{opacity:0}}}}
@keyframes {name}-paw{{0%,15%{{transform:translate(130px,570px);animation-timing-function:cubic-bezier(.2,.9,.3,1)}}35%,70%{{transform:translate(130px,300px);animation-timing-function:cubic-bezier(.5,0,.7,.4)}}90%,100%{{transform:translate(130px,570px)}}}}
{pre}.shut{{animation:{name}-shut 4s infinite}}
@keyframes {name}-shut{{0%,47%{{opacity:0}}49%,61%{{opacity:1}}63%,100%{{opacity:0}}}}
@keyframes {name}-blink{{0%,40%{{transform:scaleY(1)}}48%{{transform:scaleY({CLOSED})}}62%{{transform:scaleY({CLOSED})}}70%{{transform:scaleY(1)}}}}'''
        # a small security key, offered out past the paw once the arm is raised
        skey = (f'<g transform="translate(-6 -6) rotate(-30)"><rect x="-40" y="-14" width="56" height="28" rx="8" fill="{P["key"]}"/>'
                f'<rect x="12" y="-8" width="22" height="16" rx="3" fill="{P["keyplug"]}"/><circle cx="-18" r="7" fill="{P["gold"]}"/></g>')
        body = shaft(P) + face(P) + mitten(P).replace('</g>', skey + '</g>')
        return svg(body, css, cls=name), "Unlocked with the key: he hands it over, a slow nod, and off it goes."

def state_halo():
    name="halo"; pre=f".{name} "
    css = f"{pre}*{{transform-box:view-box}}" + f'''{pre}.halo{{animation:{name}-halo 4s ease-in-out infinite}}
{pre}.lid{{animation:{name}-blink 4s infinite}}
{pre}.shut{{animation:{name}-shut 4s infinite}}
@keyframes {name}-shut{{0%,95%{{opacity:0}}95.5%,96.2%{{opacity:1}}96.8%,100%{{opacity:0}}}}
@keyframes {name}-halo{{0%,100%{{transform:translateY(0)}}50%{{transform:translateY(-8px)}}}}
@keyframes {name}-blink{{0%,93%{{transform:scaleY(1)}}95.5%{{transform:scaleY({CLOSED})}}98%{{transform:scaleY(1)}}}}'''
    halo = f'<ellipse class="halo" cx="256" cy="48" rx="58" ry="13" fill="none" stroke="{P["cream"]}" stroke-width="11"/>'
    body = shaft(P) + face(P) + halo
    return svg(body, css, cls=name), "Angel: a halo floats over him while he keeps the lock. That is all it does."

def icon(v):
    pal = {"light": "color", "dark": "dark", "tinted": "tint"}[v]
    back = {"light": f'<rect width="1024" height="1024" fill="{GREEN}"/>', "dark": "", "tinted": '<rect width="1024" height="1024" fill="#1f1f1f"/>'}[v]
    q = PAL[pal]
    return svg(back + f'<g transform="translate(512 522) scale(2.0) translate(-256 -247)">{shaft(q)}{face(q)}</g>', vb="0 0 1024 1024")

for v in ("light", "dark", "tinted"):
    (OUT / f"icon-{v}.svg").write_text(icon(v))
ref = pathlib.Path("/mnt/user-data/attachments/48710e8f-0a7f-5c09-ab98-f8e278efe66a/857c96b0-image.png")
ref_b64 = base64.b64encode(ref.read_bytes()).decode()
full_icon = f'<img src="data:image/png;base64,{ref_b64}" alt="reference">'
(OUT / "pose-locked.svg").write_text(svg(shaft(P) + face(P)))
(OUT / "pose-resisted.svg").write_text(svg(shaft(P) + face(P) + f'<g transform="translate(372 296) rotate(24)">{mitten(P)}</g>'))

cur = pathlib.Path("/mnt/user-data/uploads/Pawl-iOS/Pawl/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
cur_b64 = base64.b64encode(cur.read_bytes()).decode()
li, di, ti = icon("light"), icon("dark"), icon("tinted")
cards = ""
for n in ("idle", "swipe", "locked", "waiting", "blocked", "unlocked", "halo"):
    s, cap = state_halo() if n == "halo" else state(n)
    (OUT / f"state-{n}.svg").write_text(s)
    cards += f'<figure>{s}<figcaption><b>{n}</b><br>{cap}</figcaption></figure>'
page = f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Pawl, in motion</title>
<style>
body{{margin:0;background:#f7f8f3;color:#1b2416;font:17px/1.55 -apple-system,BlinkMacSystemFont,"SF Pro Text",Helvetica,Arial,sans-serif;padding:16px}}
h1{{font-size:24px;margin:8px 0 4px}} h2{{font-size:19px;color:#2c550d;margin:22px 0 8px}} p{{margin:0 0 10px}} .muted{{color:#5b6653;font-size:15px}}
.home{{display:flex;gap:16px;align-items:flex-end;background:#182a44;border-radius:14px;padding:14px 12px 10px;flex-wrap:wrap}}
.app{{display:flex;flex-direction:column;align-items:center;gap:4px;color:#fff;font-size:11px}}
.ico{{width:60px;height:60px;border-radius:13.5px;overflow:hidden}} .ico svg,.ico img{{width:100%;height:100%;display:block}}
.sysdark{{background:#222}} .small .ico{{width:29px;height:29px;border-radius:6.5px}}
.big{{display:flex;gap:10px}} .big .ico{{width:110px;height:110px;border-radius:25px}}
.states{{display:grid;grid-template-columns:1fr 1fr;gap:10px}} figure{{margin:0;background:#e6efdc;border-radius:14px;padding:10px;text-align:center}} figure svg{{width:100%;height:auto}} figcaption{{font-size:13px;color:#5b6653;line-height:1.3}}
@media (prefers-reduced-motion:reduce){{svg *{{animation:none!important}}}}
</style></head><body>
<h1>Pawl, in motion</h1>
<p class="muted">Flat colors only, no gradients anywhere. Handlebar mustache, two angled brows. The animation does the charm.</p>
<h2>Home screen, 60 pt and 29 pt</h2>
<div class="home">
  <div class="app"><div class="ico">{li}</div><span>new</span></div>
  <div class="app"><div class="ico"><img src="data:image/png;base64,{cur_b64}" alt=""></div><span>today</span></div>
  <div class="app"><div class="ico sysdark">{di}</div><span>dark</span></div>
  <div class="app"><div class="ico">{ti}</div><span>tinted</span></div>
  <div class="app"><div class="ico">{full_icon}</div><span>reference</span></div>
  <div class="app small"><div class="ico">{li}</div><span>29</span></div>
  <div class="app small"><div class="ico sysdark">{di}</div><span>dark</span></div>
  <div class="app small"><div class="ico">{ti}</div><span>tint</span></div>
  <div class="app small"><div class="ico">{full_icon}</div><span>ref</span></div>
</div>
<h2>Animated states</h2>
<div class="states">{cards}</div>
<h2>The three icon files, large</h2>
<div class="big"><div class="ico">{li}</div><div class="ico sysdark">{di}</div><div class="ico">{ti}</div></div>
</body></html>'''
(OUT / "index.html").write_text(page)
print("ok, gradients in output:", sum(f.read_text().count("Gradient") for f in OUT.glob("*.svg")))
