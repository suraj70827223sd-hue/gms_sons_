#!/usr/bin/env bash
set -euo pipefail
# Deploys the existing Android-bundled GMS website as an installable PWA.
mkdir -p /tmp/gms-repair-app site
base64 --decode android-secure/source.b64 > /tmp/gms-repair-source.zip
unzip -q /tmp/gms-repair-source.zip -d /tmp/gms-repair-app
cp -a /tmp/gms-repair-app/app/src/main/assets/www/. site/
cp /tmp/gms-repair-app/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png site/icon-192.png
python3 - <<'PY'
from pathlib import Path
import json, subprocess, sys
site = Path('site')
head = '''  <meta name="theme-color" content="#071d40">
  <link rel="manifest" href="/manifest.webmanifest">
  <link rel="apple-touch-icon" href="/icon-192.png">
  <meta name="apple-mobile-web-app-capable" content="yes">
'''
index = site.joinpath('index.html')
html = index.read_text(encoding='utf-8')
if 'manifest.webmanifest' not in html:
    html = html.replace('</head>', head + '</head>')
if "serviceWorker.register" not in html:
    html = html.replace('</body>', '<script>if ("serviceWorker" in navigator) window.addEventListener("load",()=>navigator.serviceWorker.register("/service-worker.js").catch(()=>{}));</script></body>')
index.write_text(html, encoding='utf-8')
# Resample the original Android app icon if Pillow is available; fallback
# keeps a usable 192px icon without claiming a 512px resource.
has_512 = False
try:
    from PIL import Image
    img = Image.open(site / 'icon-192.png').convert('RGBA')
    img.resize((512,512), Image.Resampling.LANCZOS).save(site / 'icon-512.png')
    has_512 = True
except ImportError:
    pass
icons = [{"src":"/icon-192.png","sizes":"192x192","type":"image/png","purpose":"any maskable"}]
if has_512:
    icons.append({"src":"/icon-512.png","sizes":"512x512","type":"image/png","purpose":"any maskable"})
manifest = {"name":"GMS SONS TRADERS Secure Repair Hub","short_name":"GMS Repair Hub","description":"Electronics repair guides and WhatsApp repair enquiries","start_url":"/","scope":"/","display":"standalone","background_color":"#071d40","theme_color":"#071d40","icons":icons}
(site/'manifest.webmanifest').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
(site/'service-worker.js').write_text('''const CACHE="gms-repair-hub-v1";
self.addEventListener("install", e=>e.waitUntil(caches.open(CACHE).then(c=>c.addAll(["/","/index.html","/style.css","/app.js","/auth.js","/protection.css","/protection.js","/assets/logo.jpg"]))));
self.addEventListener("activate",e=>e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k))))));
self.addEventListener("fetch",e=>{const u=new URL(e.request.url);if(e.request.method!=="GET"||u.origin!==location.origin)return;e.respondWith(fetch(e.request).catch(()=>caches.match(e.request)))});
''')
(site/'_headers').write_text('''/*
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: camera=(), microphone=(), geolocation=()
  X-Frame-Options: DENY
''')
(site/'privacy.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Privacy Policy | GMS SONS TRADERS</title><style>body{font:16px/1.6 system-ui,sans-serif;max-width:760px;margin:40px auto;padding:0 20px;color:#17304d}h1{line-height:1.2}a{color:#1451a4}</style><h1>Privacy Policy — GMS SONS TRADERS Repair Hub</h1><p>Last updated: 14 October 2026</p><p>We use your email address for one-time-code sign-in through Supabase authentication. Supabase may process login-related technical information to provide authentication and account security. The site also uses browser storage for your preferences, repair-guide progress, and locally saved repair-enquiry drafts.</p><p>If you choose to request a repair, your name, phone number, device, and issue details are used to prepare a WhatsApp message. The message is not sent to our shop unless you choose to send it in WhatsApp. WhatsApp processes messages under its own privacy terms. Your booking draft may remain stored on this device until you delete it.</p><p>We do not knowingly sell information collected through this app. The website does not intentionally run advertising trackers. You may clear locally saved drafts from the app or your browser storage. To discuss enquiries or request assistance, contact GMS SONS TRADERS at <a href="tel:+919839157145">+91 98391 57145</a>.</p><p>This policy covers this website/app and may be updated as functionality changes.</p><p><a href="/">Back to Repair Hub</a></p></html>''',encoding='utf-8')
print('PWA build ready:', len(list(site.rglob('*'))), 'entries', 'icons512='+str(has_512))
PY
