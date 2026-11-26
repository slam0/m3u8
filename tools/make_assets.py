#!/usr/bin/env python3
"""Generuje tekstury i ikony w ciemnogranatowym stylu skeuomorficznym (iOS 6):
ciemny len, błyszczące granatowe paski i guziki, karty kafelków.
Użycie: python3 tools/make_assets.py   (zapisuje do Resources/)"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'Resources')
rng = np.random.default_rng(11)
SS = 4


# ---------- narzędzia ----------
def blur(a, sx, sy=None):
    """Rozmycie gaussowskie przez FFT; brzegi zawijane, więc tekstury łączą się bez szwów."""
    sy = sx if sy is None else sy
    h, w = a.shape
    fx = np.fft.fftfreq(w)[None, :]
    fy = np.fft.fftfreq(h)[:, None]
    k = np.exp(-2 * np.pi ** 2 * ((sx * fx) ** 2 + (sy * fy) ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * k))


def norm(a):
    a = a - a.mean()
    return a / (a.std() + 1e-9)


def vgrad(h, top, bottom):
    t = np.linspace(0, 1, h)[:, None, None]
    return np.array(top, float)[None, None, :] * (1 - t) + np.array(bottom, float)[None, None, :] * t


def grad_img(w, h, top, bottom):
    return Image.fromarray(np.repeat(vgrad(h, top, bottom), w, axis=1).astype(np.uint8), 'RGB')


def save2x(img, name):
    """img jest w skali @2x; zapisujemy @2x i pomniejszoną wersję 1x."""
    img.save(os.path.join(OUT, name + '@2x.png'))
    w, h = img.size
    img.resize((max(1, w // 2), max(1, h // 2)), Image.LANCZOS).save(os.path.join(OUT, name + '.png'))


def hline(img, y, color, h=2, alpha=1.0):
    ov = Image.new('RGBA', img.size, (0, 0, 0, 0))
    ImageDraw.Draw(ov).rectangle((0, y, img.size[0], y + h - 1), fill=color + (int(255 * alpha),))
    base = img.convert('RGBA')
    return Image.alpha_composite(base, ov).convert('RGB')


def brushed(w, h, amount=0.05):
    n = norm(blur(rng.standard_normal((h, w)), 8.0, 0.5))
    return 1.0 + amount * n


# ---------- tła i paski ----------
def linen():
    s = 256
    horiz = norm(blur(norm(rng.standard_normal((s, s))), 7.0, 0.55))
    vert = norm(blur(norm(rng.standard_normal((s, s))), 0.55, 7.0))
    yy, xx = np.mgrid[0:s, 0:s]
    mask = (((xx // 4) + (yy // 4)) % 2) == 0
    t = np.where(mask, horiz, vert)
    t = norm(t + 0.35 * norm(blur(rng.standard_normal((s, s)), 0.5)))
    base = np.array((20, 28, 46), float)
    arr = np.clip(base[None, None, :] * (1.0 + 0.16 * t[:, :, None]), 0, 255)
    img = Image.fromarray(arr.astype(np.uint8), 'RGB')
    img.save(os.path.join(OUT, 'bg_linen@2x.png'))
    img.resize((s // 2, s // 2), Image.LANCZOS).save(os.path.join(OUT, 'bg_linen.png'))



def main_bg(W=640, H=1136, save=True):
    """Tło ekranów: gładki niebieski gradient, poświata u góry i błysk w kształcie uśmiechu. Bez tekstury.
    Wymiary dobieramy do ekranu (pionowy/poziomy, telefon/iPad), więc obraz nie jest rozciągany."""
    k = H / 1136.0                      # skala pionowa (wzorzec: 640x1136)
    s = min(W, H) / 640.0               # skala grubości linii
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    t = yy / (H - 1)
    top = np.array([58, 128, 232], np.float32); mid = np.array([24, 78, 186], np.float32); bot = np.array([8, 36, 108], np.float32)
    a = np.clip(t / 0.55, 0, 1)[..., None]; b = np.clip((t - 0.55) / 0.45, 0, 1)[..., None]
    img = np.where(t[..., None] < 0.55, top * (1 - a) + mid * a, mid * (1 - b) + bot * b)
    r = np.sqrt(((xx - W / 2) / (W * 0.75)) ** 2 + ((yy + 80 * k) / (620 * k)) ** 2)
    img = img + (np.clip(1 - r, 0, 1) ** 1.6)[..., None] * np.array([46, 62, 70], np.float32)
    img = np.clip(img, 0, 255)
    cx, cy, rx, ry = W / 2, -520.0 * k, 980.0 / 640.0 * W, 960.0 * k
    d = (np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2) - 1.0) * ry
    band = np.clip(1 - np.clip(d / (26.0 * s), 0, 1), 0, 1)
    gloss = band * (0.10 + 0.16 * np.clip(1 - yy / (470.0 * k), 0, 1))
    img = img + gloss[..., None] * (255 - img)
    prof = np.exp(-((xx - W / 2) / (W * 0.46)) ** 2)
    line = np.exp(-(d / (1.6 * s)) ** 2) * prof * 0.95
    line2 = np.exp(-((d + 9 * s) / (1.2 * s)) ** 2) * prof * 0.30
    halo = np.exp(-(d / (14.0 * s)) ** 2) * prof * 0.16
    img = img + np.clip(line + line2 + halo, 0, 1)[..., None] * (255 - img)
    vr = np.sqrt(((xx - W / 2) / (W * 0.8)) ** 2 + ((yy - H * 0.45) / (H * 0.8)) ** 2)
    img = img * (1 - 0.30 * np.clip(vr - 0.55, 0, 1) ** 1.3)[..., None]
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), 'RGB')
    if save:
        im.save(os.path.join(OUT, 'bg_main@2x.png'))
        im.resize((W // 2, H // 2), Image.LANCZOS).save(os.path.join(OUT, 'bg_main.png'))
    return im


def sized_backgrounds():
    """Osobne tła dla iPada (pion i poziom) i dla telefonu w poziomie: @2x oraz @1x."""
    for name, w1, h1 in (('bg_pad_p', 768, 1024), ('bg_pad_l', 1024, 768), ('bg_phone_l', 568, 320)):
        im = main_bg(w1 * 2, h1 * 2, save=False)
        im.save(os.path.join(OUT, name + '@2x.png'))
        im.resize((w1, h1), Image.LANCZOS).save(os.path.join(OUT, name + '.png'))


def nav_bar():
    w, h = 640, 88
    g = vgrad(h, (62, 90, 146), (16, 26, 58))
    arr = np.clip(g * brushed(w, h)[:, :, None], 0, 255)
    img = Image.fromarray(arr.astype(np.uint8), 'RGB')
    gloss = Image.new('L', (w, h), 0)
    ImageDraw.Draw(gloss).rectangle((0, 0, w, h // 2), fill=26)
    img = Image.composite(Image.new('RGB', (w, h), (255, 255, 255)), img, gloss)
    img = hline(img, 0, (150, 180, 236), 2, 0.9)
    img = hline(img, h - 6, (40, 100, 205), 2, 0.9)       # niebieska żyłka
    img = hline(img, h - 4, (4, 8, 20), 4, 1.0)           # ciemny cień pod paskiem
    save2x(img, 'nav_bar')


def strip(name, top, bottom, light, dark):
    w, h = 640, 44
    arr = np.clip(vgrad(h, top, bottom) * brushed(w, h, 0.04)[:, :, None], 0, 255)
    img = Image.fromarray(arr.astype(np.uint8), 'RGB')
    img = hline(img, 0, light, 2)
    img = hline(img, h - 2, dark, 2)
    save2x(img, name)


def stretch_row(name, top, bottom, light, dark, w=8, h=120, alpha=1.0):
    img = grad_img(w, h, top, bottom)
    img = hline(img, 0, light, 2)
    img = hline(img, 2, (255, 255, 255), 1, 0.04)
    img = hline(img, h - 2, dark, 2)
    rgba = img.convert('RGBA')
    al = np.full((h, w), int(255 * alpha), np.uint8)
    al[0:2, :] = 255; al[h - 2:, :] = 255          # linie zostają kryjące
    rgba.putalpha(Image.fromarray(al))
    save2x(rgba, name)


# ---------- guziki i karty ----------
def mask_rounded(w, h, r):
    m = Image.new('L', (w * SS, h * SS), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w * SS - 1, h * SS - 1), radius=r * SS, fill=255)
    return m


def mask_back(w, h, tip, r):
    m = Image.new('L', (w * SS, h * SS), 0)
    d = ImageDraw.Draw(m)
    mid = h * SS / 2
    d.polygon([(0, mid), (tip * SS, 0), (w * SS, 0), (w * SS, h * SS), (tip * SS, h * SS)], fill=255)
    k = int(r * SS) | 1
    m = m.filter(ImageFilter.MinFilter(k)).filter(ImageFilter.MaxFilter(k))
    return m.filter(ImageFilter.GaussianBlur(SS * 0.6))


def glossy(mask, w, h, top, bottom, name, border, rim, gloss=44, border_px=2):
    big = mask
    W, H = w * SS, h * SS
    body = grad_img(W, H, top, bottom)
    gl = Image.new('L', (W, H), 0)
    ImageDraw.Draw(gl).rectangle((0, 0, W, int(H * 0.48)), fill=gloss)
    body = Image.composite(Image.new('RGB', (W, H), (255, 255, 255)), body, gl)
    inner = big.filter(ImageFilter.MinFilter(border_px * SS + 1))
    border_mask = Image.fromarray(np.clip(np.array(big, int) - np.array(inner, int), 0, 255).astype(np.uint8))
    body = Image.composite(Image.new('RGB', (W, H), border), body, border_mask)
    rim_in = inner.filter(ImageFilter.MinFilter(SS + 1))
    top_rim = np.clip(np.array(inner, int) - np.array(rim_in, int), 0, 255)
    top_rim[H // 3:, :] = 0
    body = Image.composite(Image.new('RGB', (W, H), rim), body, Image.fromarray((top_rim * 0.6).astype(np.uint8)))
    rgba = body.convert('RGBA')
    rgba.putalpha(big)
    rgba = rgba.resize((w, h), Image.LANCZOS)
    rgba.save(os.path.join(OUT, name + '@2x.png'))
    rgba.resize((w // 2, h // 2), Image.LANCZOS).save(os.path.join(OUT, name + '.png'))


def buttons():
    w, h = 60, 60
    m = mask_rounded(w, h, 10)
    glossy(m, w, h, (96, 128, 190), (30, 48, 100), 'btn_bar', (6, 10, 24), (176, 200, 244))
    glossy(m, w, h, (50, 72, 130), (16, 26, 60), 'btn_bar_pressed', (6, 10, 24), (110, 140, 200), gloss=20)
    wb = 76
    mb = mask_back(wb, h, 26, 9)
    glossy(mb, wb, h, (96, 128, 190), (30, 48, 100), 'btn_back', (6, 10, 24), (176, 200, 244))
    glossy(mb, wb, h, (50, 72, 130), (16, 26, 60), 'btn_back_pressed', (6, 10, 24), (110, 140, 200), gloss=20)


def tile_card():
    w, h = 192, 240
    glossy(mask_rounded(w, h, 18), w, h, (40, 66, 124), (16, 30, 72), 'tile_card', (5, 9, 20), (112, 140, 196), gloss=22)
    for suf in ('@2x.png', '.png'):
        pth = os.path.join(OUT, 'tile_card' + suf)
        im = Image.open(pth).convert('RGBA')
        a = im.split()[3].point(lambda v: int(v * 0.84))
        im.putalpha(a); im.save(pth)


def icons_bar():
    """Białe glify na przyciski paska: lista i kafelki (maska alfa)."""
    s = 44
    big = Image.new('RGBA', (s * SS, s * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    for i in range(3):
        y = (9 + i * 11) * SS
        d.rounded_rectangle((6 * SS, y, 11 * SS, y + 5 * SS), radius=SS, fill=(255, 255, 255, 255))
        d.rounded_rectangle((14 * SS, y, 38 * SS, y + 5 * SS), radius=SS, fill=(255, 255, 255, 255))
    big.resize((s, s), Image.LANCZOS).save(os.path.join(OUT, 'ico_list@2x.png'))
    big.resize((s // 2, s // 2), Image.LANCZOS).save(os.path.join(OUT, 'ico_list.png'))
    big = Image.new('RGBA', (s * SS, s * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    for r in range(2):
        for c in range(2):
            x, y = (7 + c * 16) * SS, (7 + r * 16) * SS
            d.rounded_rectangle((x, y, x + 14 * SS, y + 14 * SS), radius=3 * SS, fill=(255, 255, 255, 255))
    big.resize((s, s), Image.LANCZOS).save(os.path.join(OUT, 'ico_grid@2x.png'))
    big.resize((s // 2, s // 2), Image.LANCZOS).save(os.path.join(OUT, 'ico_grid.png'))


# ---------- ikona aplikacji i ekrany startowe ----------
def icon_1024():
    """Ikona od użytkownika (tools/icon_src.png); gdy jej brak, rysujemy domyślną."""
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'icon_src.png')
    if os.path.exists(p):
        return Image.open(p).convert('RGB').resize((1024, 1024), Image.LANCZOS)
    return icon_1024_default()


def icon_1024_default():
    S = 1024
    n = norm(rng.standard_normal((S, S)))
    t = norm(blur(n, 0.7))
    arr = np.clip(vgrad(S, (40, 60, 108), (14, 22, 48)) * (1.0 + 0.05 * t[:, :, None]), 0, 255)
    img = Image.fromarray(arr.astype(np.uint8), 'RGB').convert('RGBA')
    big = Image.new('RGBA', (S * 2, S * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    d.line((S * 0.86, S * 0.44, S * 1.02, S * 0.16), fill=(190, 205, 230, 255), width=22)
    d.line((S * 1.18, S * 0.44, S * 1.02, S * 0.16), fill=(190, 205, 230, 255), width=22)
    d.rounded_rectangle((S * 0.26, S * 0.46, S * 1.74, S * 1.64), radius=170, fill=(6, 10, 22, 255))
    frame = Image.new('RGBA', big.size, (0, 0, 0, 0))
    frame.paste(Image.fromarray(np.repeat(vgrad(big.size[1], (236, 240, 248), (150, 160, 184)), big.size[0], axis=1).astype(np.uint8), 'RGB'))
    fm = Image.new('L', big.size, 0)
    ImageDraw.Draw(fm).rounded_rectangle((S * 0.29, S * 0.49, S * 1.71, S * 1.61), radius=158, fill=255)
    big = Image.composite(frame, big, fm)
    d = ImageDraw.Draw(big)
    d.rounded_rectangle((S * 0.40, S * 0.60, S * 1.60, S * 1.50), radius=110, fill=(8, 14, 30, 255))
    scr = Image.fromarray(np.repeat(vgrad(big.size[1], (96, 168, 255), (22, 64, 160)), big.size[0], axis=1).astype(np.uint8), 'RGB').convert('RGBA')
    sm = Image.new('L', big.size, 0)
    ImageDraw.Draw(sm).rounded_rectangle((S * 0.42, S * 0.62, S * 1.58, S * 1.48), radius=100, fill=255)
    big = Image.composite(scr, big, sm)
    d = ImageDraw.Draw(big)
    d.polygon([(S * 0.88, S * 0.86), (S * 0.88, S * 1.24), (S * 1.20, S * 1.05)], fill=(250, 252, 255, 255))
    gl = Image.new('RGBA', big.size, (0, 0, 0, 0))
    ImageDraw.Draw(gl).rounded_rectangle((S * 0.42, S * 0.62, S * 1.58, S * 1.02), radius=100, fill=(255, 255, 255, 46))
    gm = Image.new('L', big.size, 0)
    ImageDraw.Draw(gm).rounded_rectangle((S * 0.42, S * 0.62, S * 1.58, S * 1.48), radius=100, fill=255)
    gl.putalpha(Image.fromarray((np.array(gl.split()[3], int) * np.array(gm, int) // 255).astype(np.uint8)))
    big = Image.alpha_composite(big, gl)
    big = big.resize((S, S), Image.LANCZOS)
    img = Image.alpha_composite(img, big)
    return img.convert('RGB')



def setup_assets():
    """Grafiki ekranu konfiguracji: szklany panel, duży przycisk, ikona z połyskiem, miniatury układów."""
    # szklany panel (rozciągliwy) - zwykły i zaznaczony
    for name, a, border, bw in (('glass_panel', 128, (180, 210, 255, 80), 2), ('glass_panel_sel', 168, (150, 215, 255, 255), 4)):
        w = h = 96; k = 4
        m = Image.new('L', (w * k, h * k), 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, w * k - 1, h * k - 1), radius=24 * k, fill=255)
        body = Image.new('RGBA', (w * k, h * k), (10, 30, 90, a))
        hl = Image.new('RGBA', (w * k, h * k), (0, 0, 0, 0)); ImageDraw.Draw(hl).rounded_rectangle((6 * k, 6 * k, (w - 6) * k, int(h * 0.46) * k), radius=18 * k, fill=(255, 255, 255, 26))
        body = Image.alpha_composite(body, hl)
        ring = Image.new('RGBA', (w * k, h * k), (0, 0, 0, 0)); ImageDraw.Draw(ring).rounded_rectangle((0, 0, w * k - 1, h * k - 1), radius=24 * k, outline=border, width=bw * k)
        body = Image.alpha_composite(body, ring); body.putalpha(Image.fromarray((np.array(body.split()[3], int) * np.array(m, int) // 255).astype(np.uint8)))
        body = body.resize((w, h), Image.LANCZOS); body.save(os.path.join(OUT, name + '@2x.png')); body.resize((w // 2, h // 2), Image.LANCZOS).save(os.path.join(OUT, name + '.png'))
    # duży przycisk niebieski
    m = mask_rounded(96, 88, 18)
    glossy(m, 96, 88, (92, 160, 250), (24, 72, 178), 'btn_main', (6, 20, 70), (200, 224, 255), gloss=60)
    glossy(m, 96, 88, (52, 104, 196), (14, 44, 120), 'btn_main_pressed', (6, 20, 70), (140, 180, 235), gloss=30)
    # ikona aplikacji z zaokrągleniem i połyskiem (do ekranów powitalnych)
    ic = icon_1024().resize((260, 260), Image.LANCZOS).convert('RGBA'); k = 4
    mk = Image.new('L', (260 * k, 260 * k), 0); ImageDraw.Draw(mk).rounded_rectangle((0, 0, 260 * k - 1, 260 * k - 1), radius=int(260 * k * 0.2237), fill=255); mk = mk.resize((260, 260), Image.LANCZOS)
    gl = Image.new('RGBA', (260, 260), (0, 0, 0, 0)); ImageDraw.Draw(gl).ellipse((-90, -247, 350, 130), fill=(255, 255, 255, 50))
    gl.putalpha(Image.fromarray((np.array(gl.split()[3], int) * np.array(mk, int) // 255).astype(np.uint8)))
    ic = Image.alpha_composite(ic, gl); ic.putalpha(mk); ic.save(os.path.join(OUT, 'setup_icon@2x.png')); ic.resize((130, 130), Image.LANCZOS).save(os.path.join(OUT, 'setup_icon.png'))
    # miniatury układów: lista i kafelki (110x150 pt)
    def mini(name, grid):
        w, h = 220, 300; im = Image.new('RGBA', (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
        if grid:
            for q in range(4):
                cx, cy = 16 + (q % 2) * 98, 16 + (q // 2) * 140
                d.rounded_rectangle((cx, cy, cx + 90, cy + 124), radius=14, fill=(30, 64, 140, 255), outline=(150, 190, 250, 255), width=2); d.rounded_rectangle((cx + 12, cy + 12, cx + 78, cy + 64), radius=10, fill=(235, 244, 255, 255)); d.rectangle((cx + 14, cy + 82, cx + 76, cy + 92), fill=(210, 228, 255, 255))
        else:
            for q in range(5):
                cy = 14 + q * 56; d.rounded_rectangle((12, cy, 208, cy + 48), radius=10, fill=(30, 64, 140, 255), outline=(150, 190, 250, 255), width=2); d.rounded_rectangle((20, cy + 8, 52, cy + 40), radius=7, fill=(235, 244, 255, 255)); d.rectangle((64, cy + 18, 190, cy + 28), fill=(210, 228, 255, 255))
        im.save(os.path.join(OUT, name + '@2x.png')); im.resize((w // 2, h // 2), Image.LANCZOS).save(os.path.join(OUT, name + '.png'))
    mini('setup_list', False); mini('setup_grid', True)


def icons_and_launch(icon):
    for name, sz in (('Icon.png', 57), ('Icon@2x.png', 114), ('Icon-Small.png', 29), ('Icon-Small@2x.png', 58)):
        icon.resize((sz, sz), Image.LANCZOS).save(os.path.join(OUT, name))
    bgm = Image.open(os.path.join(OUT, 'bg_main@2x.png'))
    nav = Image.open(os.path.join(OUT, 'nav_bar@2x.png'))
    for w, h, name in ((640, 960, 'Default@2x.png'), (640, 1136, 'Default-568h@2x.png')):
        im = bgm.crop((0, 0, w, h)).copy()
        im.paste(nav, (0, 0))
        ic = icon.resize((256, 256), Image.LANCZOS)
        m = Image.new('L', (256, 256), 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, 255, 255), radius=46, fill=255)
        im.paste(ic, ((w - 256) // 2, (h - 256) // 2), m)
        im.save(os.path.join(OUT, name))
        if name == 'Default@2x.png':
            im.resize((w // 2, h // 2), Image.LANCZOS).save(os.path.join(OUT, 'Default.png'))


def rail_glyphs():
    """Ikonki przycisków paska bocznego iPada (białe, z przezroczystością); 26 pt = 26 px @1x i 52 px @2x."""
    import math
    K = 8                                  # rysujemy w 8-krotnym powiększeniu i zmniejszamy
    S = 52 * K
    WHT = (238, 243, 252, 255)

    def canvas():
        im = Image.new('RGBA', (S, S), (0, 0, 0, 0)); return im, ImageDraw.Draw(im)

    def box(*a): return tuple(int(v * K) for v in a)

    def save(im, name):
        big = im.resize((52, 52), Image.LANCZOS)
        big.save(os.path.join(OUT, name + '@2x.png'))
        big.resize((26, 26), Image.LANCZOS).save(os.path.join(OUT, name + '.png'))

    im, d = canvas()                                            # lista
    for k in range(3): d.rounded_rectangle(box(4, 10 + k * 13, 48, 17 + k * 13), radius=3 * K, fill=WHT)
    save(im, 'rail_list')

    im, d = canvas()                                            # gwiazdka
    pts = []
    for i in range(10):
        r = 24 if i % 2 == 0 else 10
        a = -math.pi / 2 + i * math.pi / 5
        pts.append((26 * K + r * K * math.cos(a), 27 * K + r * K * math.sin(a)))
    d.polygon(pts, fill=(255, 210, 80, 255))
    save(im, 'rail_star')

    im, d = canvas()                                            # kategorie (4 kwadraty)
    for i in range(2):
        for j in range(2): d.rounded_rectangle(box(4 + i * 24, 4 + j * 24, 24 + i * 24, 24 + j * 24), radius=4 * K, fill=WHT)
    save(im, 'rail_cat')

    im, d = canvas()                                            # lupa
    d.ellipse(box(5, 5, 33, 33), outline=WHT, width=5 * K)
    d.line(box(30, 30, 46, 46), fill=WHT, width=6 * K)
    save(im, 'rail_search')

    im, d = canvas()                                            # układ (kafelek + linie)
    for i in range(3):
        d.rounded_rectangle(box(4, 6 + i * 16, 18, 16 + i * 16), radius=3 * K, fill=WHT)
        d.rounded_rectangle(box(24, 9 + i * 16, 48, 13 + i * 16), radius=2 * K, fill=WHT)
    save(im, 'rail_layout')

    im, d = canvas()                                            # odśwież
    d.arc(box(6, 6, 46, 46), 40, 320, fill=WHT, width=5 * K)
    d.polygon([(int(44 * K), int(4 * K)), (int(46 * K), int(24 * K)), (int(28 * K), int(18 * K))], fill=WHT)
    save(im, 'rail_refresh')

    im, d = canvas()                                            # plus
    d.rounded_rectangle(box(4, 22, 48, 30), radius=3 * K, fill=WHT)
    d.rounded_rectangle(box(22, 4, 30, 48), radius=3 * K, fill=WHT)
    save(im, 'rail_plus')


def ipad_icons_and_launch(icon):
    for name, sz in (('Icon-72.png', 72), ('Icon-72@2x.png', 144), ('Icon-Small-50.png', 50), ('Icon-Small-50@2x.png', 100)):
        icon.resize((sz, sz), Image.LANCZOS).save(os.path.join(OUT, name))
    nav = Image.open(os.path.join(OUT, 'nav_bar@2x.png')).convert('RGBA')
    for w, h, name in ((768, 1024, 'Default-Portrait~ipad.png'), (1536, 2048, 'Default-Portrait@2x~ipad.png'),
                       (1024, 768, 'Default-Landscape~ipad.png'), (2048, 1536, 'Default-Landscape@2x~ipad.png')):
        scale = 2 if '@2x' in name else 1
        im = main_bg(w, h, save=False).convert('RGBA')
        im.alpha_composite(nav.resize((w, nav.height * scale // 2), Image.LANCZOS), (0, 0))
        side = 128 * scale
        ic = icon.resize((side, side), Image.LANCZOS).convert('RGBA')
        m = Image.new('L', (side, side), 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, side - 1, side - 1), radius=side * 46 // 256, fill=255)
        im.paste(ic, ((w - side) // 2, (h - side) // 2), m)
        im.convert('RGB').save(os.path.join(OUT, name))


if __name__ == '__main__':
    for old in ('nav_leather', 'header_leather', 'bg_paper'):
        for suf in ('.png', '@2x.png'):
            p = os.path.join(OUT, old + suf)
            if os.path.exists(p):
                os.remove(p)
    bg = main_bg(); nav_bar()
    strip('header_bar', (54, 82, 138), (28, 46, 94), (118, 150, 210), (6, 10, 24))
    stretch_row('cell_bg', (24, 40, 92), (16, 30, 76), (86, 120, 190), (6, 12, 34), alpha=0.58)
    stretch_row('cell_sel', (66, 134, 236), (30, 84, 190), (160, 204, 255), (12, 38, 98), alpha=0.92)
    buttons(); tile_card(); icons_bar(); setup_assets()
    icons_and_launch(icon_1024())
    sized_backgrounds(); ipad_icons_and_launch(icon_1024()); rail_glyphs()
    print('gotowe:', sorted(os.listdir(OUT)))
