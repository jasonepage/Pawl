# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Builds the Pawl Kit setup card: kit/setup-card.html and kit/Pawl-Setup-Card.pdf.
# 4 x 6 inches, two sides (print double-sided, flip on the long edge).
#
#   pip install segno playwright
#   python3 kit/build_setup_card.py
#
# Run from the repo root. Images come from site/img so the card matches getpawl.com.

import base64
import pathlib
import segno

ROOT = pathlib.Path(__file__).resolve().parent.parent
KIT = ROOT / "kit"
IMG = ROOT / "site" / "img"
APP_STORE = "https://apps.apple.com/app/id6783119309"


def data_uri(path: pathlib.Path) -> str:
    return "data:image/svg+xml;base64," + base64.b64encode(path.read_bytes()).decode()


def qr_svg(url: str) -> str:
    qr = segno.make(url, error="m")
    svg = qr.svg_inline(scale=1, border=0, dark="#16300a", light=None, omitsize=True)
    return svg.replace("<svg ", '<svg role="img" aria-label="QR code for Pawl on the App Store" ', 1)


mark = data_uri(IMG / "pawl-mark.svg")
locked = data_uri(IMG / "mascot" / "pose-locked.svg")
waiting = data_uri(IMG / "mascot" / "pose-waiting.svg")
open_pose = data_uri(IMG / "mascot" / "pose-open.svg")

HTML = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Pawl Kit setup card</title>
<style>
  @page {{ size: 4in 6in; margin: 0; }}
  :root {{
    --green-100:#e6efdc; --green-200:#c9ddb4; --green-400:#4c7f1c; --green-500:#3c6a14;
    --green-700:#2c550d; --green-900:#16300a; --ink:#1b2416; --muted:#5b6653; --paper:#f7f8f3;
    --line:#dfe6d6; --gold:#c9a227;
  }}
  * {{ box-sizing: border-box; }}
  html, body {{ margin: 0; padding: 0; }}
  body {{ font-family: Inter, -apple-system, "Helvetica Neue", Arial, sans-serif; color: var(--ink);
         -webkit-print-color-adjust: exact; print-color-adjust: exact; }}
  .page {{ width: 4in; height: 6in; overflow: hidden; position: relative; page-break-after: always;
           background: var(--paper); display: flex; flex-direction: column; }}
  .page:last-child {{ page-break-after: auto; }}

  /* front header */
  .head {{ background: linear-gradient(135deg, var(--green-400) 0%, var(--green-500) 50%, var(--green-700) 100%);
           color: #fff; padding: 0.22in 0.26in 0.2in; display: flex; align-items: center; gap: 0.14in; }}
  .head img.mascot {{ width: 0.78in; height: 0.78in; flex: none; margin: -0.06in -0.04in -0.08in -0.08in; }}
  .brand {{ display: flex; align-items: center; gap: 5px; font-size: 8.5pt; font-weight: 600;
            color: var(--green-200); letter-spacing: .02em; }}
  .brand img {{ width: 13px; height: 13px; border-radius: 3px; }}
  h1 {{ margin: 3px 0 0; font-size: 19pt; line-height: 1.05; font-weight: 700; letter-spacing: -.01em; }}
  .head p {{ margin: 4px 0 0; font-size: 8pt; line-height: 1.35; color: #eef4e6; }}

  .body {{ padding: 0.16in 0.26in 0; flex: 1; display: flex; flex-direction: column; }}
  .step {{ display: grid; grid-template-columns: 0.27in 1fr; gap: 0.08in; padding: 0.085in 0;
           border-bottom: 1px solid var(--line); }}
  .step:last-of-type {{ border-bottom: 0; }}
  .n {{ width: 0.24in; height: 0.24in; border-radius: 50%; background: var(--green-500); color: #fff;
        font-weight: 700; font-size: 9pt; display: flex; align-items: center; justify-content: center; }}
  h2 {{ margin: 0; font-size: 10.5pt; line-height: 1.2; color: var(--green-700); font-weight: 700; }}
  .step p {{ margin: 2px 0 0; font-size: 8pt; line-height: 1.38; }}
  .install {{ display: grid; grid-template-columns: 1fr 0.78in; gap: 0.1in; align-items: center; }}
  .qr {{ background: #fff; border: 1px solid var(--line); border-radius: 6px; padding: 0.05in; }}
  .qr svg {{ width: 100%; height: auto; display: block; }}
  .note {{ font-size: 7pt; color: var(--muted); margin-top: 3px; line-height: 1.35; }}
  .gift {{ margin-top: auto; background: var(--green-100); border-radius: 6px; padding: 6px 8px;
           font-size: 7.5pt; line-height: 1.38; }}
  .gift b {{ color: var(--green-700); }}
  .over {{ padding: 0.1in 0 0.16in; font-size: 7.5pt; color: var(--muted);
           display: flex; justify-content: space-between; align-items: center; }}
  .over strong {{ color: var(--green-700); }}

  /* back */
  .back .body {{ padding-top: 0.24in; }}
  h3 {{ margin: 0 0 4px; font-size: 11pt; color: var(--green-700); font-weight: 700; }}
  .places {{ list-style: none; padding: 0; margin: 4px 0 0; display: grid; gap: 3px; }}
  .places li {{ font-size: 8pt; line-height: 1.32; background: #fff; border: 1px solid var(--line);
                border-left: 3px solid var(--green-500); border-radius: 5px; padding: 3px 7px; }}
  .places b {{ color: var(--green-700); }}
  .lead {{ font-size: 8pt; line-height: 1.38; margin: 0; }}
  .flow {{ display: grid; grid-template-columns: 1fr 10px 1fr 10px 1fr; align-items: stretch;
           margin: 6px 0 0; }}
  .flow .box {{ background: #fff; border: 1px solid var(--line); border-radius: 6px; padding: 4px 3px;
                text-align: center; font-size: 7pt; line-height: 1.25; }}
  .flow .box img {{ width: 0.42in; height: 0.42in; display: block; margin: 0 auto 1px; }}
  .flow .box b {{ display: block; font-size: 8pt; color: var(--green-700); }}
  .flow .arrow {{ align-self: center; text-align: center; color: var(--green-500); font-size: 9pt; }}
  .sec {{ margin-top: 0.13in; }}
  .small {{ font-size: 7.5pt; line-height: 1.38; margin: 0; }}
  .foot {{ margin-top: auto; background: var(--green-900); color: var(--green-200); padding: 0.12in 0.26in;
           font-size: 7.5pt; line-height: 1.4; }}
  .foot b {{ color: #fff; }}
</style>
</head>
<body>

<section class="page front">
  <div class="head">
    <img class="mascot" src="{locked}" alt="">
    <div>
      <div class="brand"><img src="{mark}" alt="">Pawl Kit</div>
      <h1>Set up Pawl</h1>
      <p>The key in this kit is the only thing that can unlock Pawl. Setup takes about five minutes.</p>
    </div>
  </div>
  <div class="body">
    <div class="step">
      <span class="n">1</span>
      <div class="install">
        <div>
          <h2>Install Pawl</h2>
          <p>It's free on the App Store. Scan the code with your iPhone camera, or search for <b>Pawl: App Blocker With a Key</b>.</p>
          <p class="note">Needs an iPhone 15 or newer, or an iPad with USB-C, on iOS 18 or later.</p>
        </div>
        <div class="qr">{qr_svg(APP_STORE)}</div>
      </div>
    </div>
    <div class="step">
      <span class="n">2</span>
      <div>
        <h2>Pick what to block</h2>
        <p>Choose the apps and sites you want out of reach. Apple Screen Time does the blocking, and Pawl never learns their names.</p>
      </div>
    </div>
    <div class="step">
      <span class="n">3</span>
      <div>
        <h2>Pair the key</h2>
        <p>When Pawl asks, plug the key into your phone's USB-C port and touch the key when your phone tells you to. Pawl remembers this key and only this key.</p>
      </div>
    </div>
    <div class="gift"><b>Giving this to someone?</b> Let them do the setup themselves. Pawl works best when the person chooses what to block.</div>
    <div class="over"><span><strong>4. Put the key out of reach.</strong> Turn over.</span><span>&#8594;</span></div>
  </div>
</section>

<section class="page back">
  <div class="body">
    <h3>4. Put the key out of reach</h3>
    <p class="lead">Distance is the whole point. Whoever holds the key decides when Pawl can open. Some places that work:</p>
    <ul class="places">
      <li><b>Someone you trust</b> across town, like a sister, a friend, or a partner.</li>
      <li><b>A time lock box</b> that won't open until its timer runs out.</li>
      <li><b>A bank safe deposit box</b> or <b>your desk at work.</b></li>
      <li><b>Mail it to a friend</b> and ask them to mail it back only when you ask.</li>
    </ul>

    <div class="sec">
      <h3>How unlocking works</h3>
      <div class="flow">
        <div class="box"><img src="{locked}" alt=""><b>Use the key</b>Tap Unlock, then the key</div>
        <div class="arrow">&#8594;</div>
        <div class="box"><img src="{waiting}" alt=""><b>Wait 15 min</b>Apps stay blocked</div>
        <div class="arrow">&#8594;</div>
        <div class="box"><img src="{open_pose}" alt=""><b>Open 30 min</b>Then they lock again</div>
      </div>
      <p class="small" style="margin-top:5px">Those are the starting times. You can change them in Settings. Making the wait longer happens right away. Making it shorter has to wait too.</p>
    </div>

    <div class="sec">
      <h3>If you lose the key</h3>
      <p class="small">Get any USB-C FIDO2 security key and pair it on Pawl's Unlock tab. It becomes your key after the wait.</p>
    </div>

    <div class="sec">
      <p class="small"><b>Pawl adds friction, not a wall.</b> The owner of a phone can still turn Screen Time off. Pawl makes the 1am choice slow. There's no account, and Pawl collects no data.</p>
    </div>
  </div>
  <div class="foot">
    <b>Questions?</b> getpawl.com/support &nbsp;·&nbsp; support@getpawl.com
  </div>
</section>

</body>
</html>
"""


def main() -> None:
    from playwright.sync_api import sync_playwright

    KIT.mkdir(exist_ok=True)
    html_path = KIT / "setup-card.html"
    html_path.write_text(HTML, encoding="utf-8")
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()
        page.goto(html_path.as_uri(), wait_until="networkidle")
        page.pdf(path=str(KIT / "Pawl-Setup-Card.pdf"), width="4in", height="6in",
                 print_background=True, prefer_css_page_size=True)
        browser.close()
    print("wrote", html_path.relative_to(ROOT), "and kit/Pawl-Setup-Card.pdf")


if __name__ == "__main__":
    main()
