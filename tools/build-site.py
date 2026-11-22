# Builds site/index.html, site/get.html and site/give.html from shared parts
# (menu, footer, kit cards, questions) so the three pages stay matched.
# Run from the repo root: python3 tools/build-site.py site
import re, sys, os
site = sys.argv[1]
APP = "https://apps.apple.com/app/id6783119309"
USBC = "https://buy.stripe.com/7sY28keT72zn4XzfP6enS03"
BADGE = '<a class="badge" href="https://apps.apple.com/app/id6783119309" aria-label="Download on the App Store">\n        <svg viewBox="0 0 120 40" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true">\n          <rect width="120" height="40" rx="6" fill="#000"/>\n          <rect x=".5" y=".5" width="119" height="39" rx="5.5" fill="none" stroke="#a6a6a6"/>\n          <g fill="#fff">\n            <path d="M24.77 20.3a4.95 4.95 0 0 1 2.36-4.15 5.07 5.07 0 0 0-3.99-2.16c-1.68-.18-3.31 1-4.16 1-.87 0-2.19-.98-3.61-.95a5.32 5.32 0 0 0-4.47 2.73c-1.93 3.35-.49 8.27 1.36 10.98.93 1.33 2.01 2.81 3.43 2.75 1.39-.06 1.9-.88 3.58-.88 1.66 0 2.14.88 3.59.85 1.49-.02 2.43-1.33 3.32-2.67a11 11 0 0 0 1.52-3.09 4.78 4.78 0 0 1-2.93-4.41z"/>\n            <path d="M22.04 12.21a4.87 4.87 0 0 0 1.11-3.49 4.96 4.96 0 0 0-3.21 1.66 4.64 4.64 0 0 0-1.14 3.36 4.1 4.1 0 0 0 3.24-1.53z"/>\n            <text x="35" y="15.5" font-family="-apple-system,Helvetica,Arial,sans-serif" font-size="7.2" letter-spacing=".1">Download on the</text>\n            <text x="35" y="30" font-family="-apple-system,Helvetica,Arial,sans-serif" font-size="15.5" font-weight="600" letter-spacing="-.2">App Store</text>\n          </g>\n        </svg>\n      </a>'
LIGHT = "https://buy.stripe.com/9B600c6mBgqdey9gTaenS04"

def head_of(name, extra_fix=None):
    s = open(f"{site}/{name}", encoding="utf-8").read()
    h = s[:s.index("</head>")]
    h = re.sub(r'<link rel="stylesheet"[^>]*>\s*', '', h)
    h = h.rstrip() + '\n<link rel="stylesheet" href="/pawl.css">\n<link rel="stylesheet" href="/home.css?v=6">\n</head>\n'
    if extra_fix: h = extra_fix(h)
    return h

NAV = f'''<nav class="home-nav" aria-label="Main navigation">
  <div class="home-wrap nav-inner">
    <a class="home-brand" href="/" aria-label="Pawl home"><img src="/img/kiki-icon-192.png" alt="" width="42" height="42"><span>Pawl</span></a>
    <div class="nav-links">
      <a href="/#how">How it works</a>
      <a href="/get">Get a kit</a>
      <a href="/give">Give one</a>
      <a href="/about">About</a>
      <a class="nav-button" href="{APP}">Get the app</a>
    </div>
  </div>
</nav>
'''

FOOTER = '''<footer class="home-footer"><div class="home-wrap footer-grid"><div class="footer-brand"><img src="/img/kiki-icon-192.png" alt="" width="52" height="52"><div><strong>Pawl</strong><span>App blocker with a key</span></div></div><div class="footer-links"><a href="/#how">How it works</a><a href="/get">Get a kit</a><a href="/give">Give one</a><a href="/about">About</a><a href="/support">Support</a><a href="/privacy">Privacy</a><a href="https://github.com/jasonepage/Pawl">GitHub</a></div><p class="footer-note">Pawl adds friction. It does not make anything impossible.</p><p class="copyright">&copy; 2026 Jason Page</p></div></footer>

<script>
  (function () {
    var sel = document.getElementById('phone-model');
    if (sel) sel.addEventListener('change', function () {
      var v = sel.value, out = document.getElementById('phone-result');
      var u = document.getElementById('usb-c-kit'), l = document.getElementById('lightning-kit');
      u.classList.toggle('dim', v === 'lightning' || v === 'old'); l.classList.toggle('dim', v === 'usbc' || v === 'old');
      out.textContent = v === 'usbc' ? 'Your iPhone takes the USB-C Kit.' : v === 'lightning' ? 'Your iPhone takes the Lightning Kit.' : v === 'old' ? 'Pawl needs iOS 18, which this iPhone cannot run.' : '';
    });
    var nav = document.querySelector('.home-nav');
    function updateNav() { nav.classList.toggle('scrolled', window.scrollY > 16); }
    updateNav();
    window.addEventListener('scroll', updateNav, { passive: true });
  })();
</script>
</body>
</html>
'''

def kits(title, intro, extra=""):
    return f'''  <section id="kits" class="quick-buy" aria-labelledby="kits-title">
    <div class="home-wrap">
      <div class="quick-buy-heading">
        <div><p class="section-index">Kits</p><h2 id="kits-title">{title}</h2></div>
        <p>{intro}</p>
      </div>

      <div class="phone-picker"><label for="phone-model">Pick your iPhone</label><select id="phone-model"><option value="">Choose a model</option>
        <optgroup label="USB-C Kit"><option value="usbc">iPhone Duo</option><option value="usbc">iPhone 18 Pro</option><option value="usbc">iPhone 18 Pro Max</option><option value="usbc">iPhone 17e</option><option value="usbc">iPhone 17</option><option value="usbc">iPhone 17 Pro</option><option value="usbc">iPhone 17 Pro Max</option><option value="usbc">iPhone Air</option><option value="usbc">iPhone 16e</option><option value="usbc">iPhone 16</option><option value="usbc">iPhone 16 Plus</option><option value="usbc">iPhone 16 Pro</option><option value="usbc">iPhone 16 Pro Max</option><option value="usbc">iPhone 15</option><option value="usbc">iPhone 15 Plus</option><option value="usbc">iPhone 15 Pro</option><option value="usbc">iPhone 15 Pro Max</option><option value="usbc">Newer than these</option></optgroup>
        <optgroup label="Lightning Kit"><option value="lightning">iPhone 14</option><option value="lightning">iPhone 14 Plus</option><option value="lightning">iPhone 14 Pro</option><option value="lightning">iPhone 14 Pro Max</option><option value="lightning">iPhone SE (3rd generation)</option><option value="lightning">iPhone 13</option><option value="lightning">iPhone 13 mini</option><option value="lightning">iPhone 13 Pro</option><option value="lightning">iPhone 13 Pro Max</option><option value="lightning">iPhone 12</option><option value="lightning">iPhone 12 mini</option><option value="lightning">iPhone 12 Pro</option><option value="lightning">iPhone 12 Pro Max</option><option value="lightning">iPhone SE (2nd generation)</option><option value="lightning">iPhone 11</option><option value="lightning">iPhone 11 Pro</option><option value="lightning">iPhone 11 Pro Max</option><option value="lightning">iPhone XS</option><option value="lightning">iPhone XS Max</option><option value="lightning">iPhone XR</option></optgroup>
        <option value="old">Older than iPhone XR</option></select><p id="phone-result" class="phone-result" aria-live="polite"></p></div>
      <div class="quick-products">
        <article id="usb-c-kit" class="quick-product featured-product">
          <div class="product-badge">Most iPhones today</div>
          <img src="/img/connector-usbc.svg" alt="USB-C is a small rounded oval connector." width="640" height="260">
          <div class="quick-product-copy"><p class="phone-fit">USB-C Kit</p><h3>iPhone 15 or newer</h3><div class="quick-price"><strong>$49</strong><span>+ $5.95 shipping</span></div><a href="{USBC}" class="buy-now">Buy the USB-C Kit</a></div>
        </article>
        <article id="lightning-kit" class="quick-product">
          <img src="/img/connector-lightning.svg" alt="Lightning is a narrow flat connector with visible metal contacts." width="640" height="260">
          <div class="quick-product-copy"><p class="phone-fit">Lightning Kit</p><h3>iPhone 14 or older</h3><div class="quick-price"><strong>$119</strong><span>+ $5.95 shipping</span></div><a href="{LIGHT}" class="buy-now">Buy the Lightning Kit</a></div>
        </article>
      </div>
      <p class="quick-buy-note">Not sure which iPhone? Open Settings, then General, then About. US shipping only. Needs iOS 18 or newer.</p>{extra}
    </div>
  </section>
'''

PRICE = '''
      <details class="price-details"><summary>Why does the Lightning Kit cost more?</summary><p>The key is most of the price. Yubico sells the Lightning key for $85 and the USB-C key for $29. The rest covers the card, packing, payment fees, shipping it out, help, and app updates. Key prices are Yubico's and can change.</p></details>'''

def questions(items, links=True):
    rows = "".join(f'<div><strong>{q}</strong><p>{a}</p></div>' for q, a in items)
    lk = '<div class="facts-links"><a href="/privacy">Privacy policy</a><a href="https://github.com/jasonepage/Pawl">Source on GitHub</a><a href="/about#limits">See what Pawl does not promise</a></div>' if links else ''
    return f'''  <section class="facts-section" aria-labelledby="facts-title">
    <div class="home-wrap facts-grid">
      <div><p class="section-index">Questions</p><h2 id="facts-title">Plain facts.</h2></div>
      <div class="fact-list">{rows}</div>
      {lk}
    </div>
  </section>
'''

Q = [
  ("What if I lose the key?", "Pair a new key in the Pawl app. It takes over only after a wait, so a spare key is never a shortcut."),
  ("Why a key and not an NFC sticker?", "A sticker can be copied with another phone. A key cannot. Its secret never leaves the chip."),
  ("How long do apps stay open?", "30 minutes by default, then they block again. You can change that time in the app."),
  ("Do I need an account?", "No account and no tracking. Pawl does not collect what you block or browse. The code is public."),
  ("Shipping and returns", "Kits ship to US addresses within 3 business days. Full refund within 30 days if the key is unopened."),
]

def hero(eyebrow, h1, lead, actions, img, alt, note="", small=False, extra_art=""):
    cls = "home-hero page-hero" if small else "home-hero"
    return f'''  <header class="{cls}">
    <div class="home-wrap hero-grid">
      <div class="hero-copy">
        <p class="eyebrow"><span class="eyebrow-dot" aria-hidden="true"></span> {eyebrow}</p>
        <h1>{h1}</h1>
        <p class="hero-lead">{lead}</p>
        <div class="hero-actions">{actions}</div>{note}
      </div>
      <div class="hero-art">
        <div class="hero-orbit orbit-one" aria-hidden="true"></div>
        <div class="hero-orbit orbit-two" aria-hidden="true"></div>
        <img src="{img}" alt="{alt}" width="1536" height="1024">{extra_art}
      </div>
    </div>
  </header>
'''

TRUST = '\n        <ul class="trust-list" aria-label="Pawl privacy facts"><li>One-time purchase</li><li>No account</li><li>No tracking</li></ul>'

# ---------- HOME ----------
home = head_of("index.html") + '<body class="home-page">\n\n' + NAV + '\n<main>\n'
home += hero("The app blocker with a key", "Block the app.<br>Hide the key.",
  "The blocker you cannot undo from your phone. Keep the physical key somewhere inconvenient. To unblock, you have to go get it.",
  BADGE + '\n          <a class="text-link" href="/get">Get a kit</a>',
  "/img/onboarding/welcome.webp", "Kiki, a calm tabby cat, sitting behind a green USB-C security key.", TRUST)
home += '''
  <section id="how" class="how-section" aria-labelledby="how-title">
    <div class="home-wrap">
      <div class="section-heading"><p class="section-index">How it works</p><h2 id="how-title">Three steps.</h2></div>
      <div class="story-steps">
        <article class="story-card"><div class="story-art"><img src="/img/scenes/pick-blocks.webp" alt="Kiki chooses one of three blank app tiles beside a phone." width="1536" height="1024" loading="lazy"></div><div class="story-copy"><span>1</span><h3>Pick what to block</h3><p>The apps and sites you keep opening.</p></div></article>
        <article class="story-card"><div class="story-art"><img src="/img/scenes/hide-key.webp" alt="A hand puts the green Pawl key into a high drawer while Kiki watches." width="1536" height="1024" loading="lazy"></div><div class="story-copy"><span>2</span><h3>Hide the key</h3><p>Somewhere inconvenient, or with someone you trust. It cannot be copied.</p></div></article>
        <article class="story-card"><div class="story-art"><img src="/img/scenes/wait-relock.webp" alt="Kiki waits beside the green Pawl key and an hourglass as apps open briefly, then close again." width="1536" height="1024" loading="lazy"></div><div class="story-copy"><span>3</span><h3>Open for a while</h3><p>With the key, your apps open for a while, then block again. You can add a wait too.</p></div></article>
      </div>
    </div>
  </section>

'''
home += '''  <section class="quote-section" aria-label="App Store review">
    <div class="home-wrap"><figure class="quote-card"><blockquote>"Super helpful for blocking apps and setting up a really nice way to be productive."</blockquote><figcaption>Webfoot85, <a href="https://apps.apple.com/app/id6783119309">App Store review</a></figcaption></figure></div>
  </section>
'''
home += '\n' + questions(Q) + '</main>\n\n' + FOOTER

# ---------- GET ----------
gs = open(f"{site}/get.html", encoding="utf-8").read()
banner = re.search(r'<div id="order-received".*?</div>\n<script>.*?</script>\n', gs, re.S).group(0)
get = head_of("get.html") + '<body class="home-page">\n\n' + banner + '\n' + NAV + '\n<main>\n'
get += hero("Pawl kits", "Pick your kit.",
  "Each kit has a Yubico key that plugs into your iPhone, a printed setup card, and the free Pawl app. No subscription.",
  '<a class="store-button" href="#kits"><span><small>From $49</small>See the kits</span></a>',
  "/img/scenes/kit-open.webp", "An open Pawl kit with the green security key and setup card inside while Kiki peeks over the box.", small=True)
get += '\n' + kits("Which iPhone do you have?", "Pick your phone and we send the right key.", PRICE)
get += '\n' + questions(Q) + '</main>\n\n' + FOOTER

# ---------- GIVE ----------
give = head_of("give.html", lambda h: h.replace('content="#a74632"', 'content="#18340f"')) + '<body class="home-page">\n\n' + NAV + '\n<main>\n'
give += hero("A gift for someone who asked", "Give someone<br>a little distance.",
  "For a friend who wants help. They pick what to block. You can hold the key.",
  '<a class="store-button" href="#kits"><span><small>From $49</small>Get a kit</span></a>',
  "/img/scenes/handoff.webp", "One person hands the green Pawl security key to another while Kiki watches beside a face-down phone.",
  note='\n        <p class="give-note">No monitoring. Pawl sends you nothing about what they do.</p>', small=True)
give += '\n' + kits("Which iPhone do they have?", "Pick their phone and we send the right key.")
give += '\n' + questions([
  ("Ask first", "Pawl is for someone who wants the friction. It is not parental control or a way to watch them."),
  ("What if they lose the key?", "They pair a new key in the app. It takes over only after a wait."),
  ("Shipping and returns", "Kits ship to US addresses within 3 business days. Full refund within 30 days if the key is unopened."),
], links=False) + '</main>\n\n' + FOOTER

give = give.replace(">Pick your iPhone</label>", ">Pick their iPhone</label>")
for name, body in [("index.html", home), ("get.html", get), ("give.html", give)]:
    open(f"{site}/{name}", "w", encoding="utf-8").write(body)
print("ok")
