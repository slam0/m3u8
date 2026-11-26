#!/usr/bin/env python3
"""Generuje tekstury i ikony w stylu skeuomorficznym (skóra, len, papier, guziki).
Użycie: python3 tools/make_assets.py   (zapisuje do Resources/)"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'Resources')
rng = np.random.default_rng(6)


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


def emboss(height, strength=1.0):
    dx = np.roll(height, -1, 1) - np.roll(height, 1, 1)
    dy = np.roll(height, -1, 0) - np.roll(height, 1, 0)
    return (-(dx + dy) * strength)


def colorize(light, base, amount):
    base = np.array(base, dtype=float)
    img = base[None, None, :] * (1.0 + amount * light[:, :, None])
    return np.clip(img, 0, 255)


def to_img(arr):
    return Image.fromarray(arr.astype(np.uint8), 'RGB')


def save(img, name, scale2=True):
    """img jest w skali @2x; zapisujemy @2x i pomniejszoną wersję 1x."""
    img.save(os.path.join(OUT, name + '@2x.png'))
    w, h = img.size
    img.resize((max(1, w // 2), max(1, h // 2)), Image.LANCZOS).save(os.path.join(OUT, name + '.png'))


def leather(w, h, base, seed_shift=0, amount=0.55):
    n = norm(rng.standard_normal((h, w)))
    bump = blur(n, 1.3) + 0.5 * blur(n, 3.0)
    bump = norm(bump)
    light = np.clip(emboss(bump, 0.9), -2, 2) * 0.5
    grain = norm(blur(rng.standard_normal((h, w)), 0.6)) * 0.08
    return colorize(light + grain, base, amount * 0.5)


def vgrad(h, top, bottom):
    t = np.linspace(0, 1, h)[:, None, None]
    return np.array(top, float)[None, None, :] * (1 - t) + np.array(bottom, float)[None, None, :] * t


def stitch(img, y, color=(236, 218, 168), dash=12, gap=8, th=3, x0=0, x1=None):
    d = ImageDraw.Draw(img)
    x1 = img.size[0] if x1 is None else x1
    x = x0
    while x < x1:
        d.rectangle((x, y + 2, x + dash - 1, y + 2 + th - 1), fill=(24, 14, 8))      # cień pod nitką
        d.rectangle((x, y, x + dash - 1, y + th - 1), fill=color)
        x += dash + gap


# ---------- paski ze skóry ----------
def nav_bar():
    w, h = 640, 88
    L = leather(w, h, (86, 58, 40))
    g = vgrad(h, (1.28, 1.28, 1.28), (0.78, 0.78, 0.78))
    arr = np.clip(L * g, 0, 255)
    img = to_img(arr)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, w, 1), fill=(150, 112, 86))            # jasna krawędź u góry
    d.rectangle((0, h - 3, w, h - 1), fill=(22, 13, 8))        # ciemna krawędź na dole
    stitch(img, h - 15)
    save(img, 'nav_leather')


def header_strip():
    w, h = 640, 44
    L = leather(w, h, (66, 46, 34))
    arr = np.clip(L * vgrad(h, (1.18, 1.18, 1.18), (0.82, 0.82, 0.82)), 0, 255)
    img = to_img(arr)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, w, 1), fill=(128, 96, 74))
    d.rectangle((0, h - 2, w, h - 1), fill=(20, 12, 8))
    save(img, 'header_leather')


# ---------- tekstury tła ----------
def linen():
    s = 256
    a = norm(rng.standard_normal((s, s)))
    horiz = norm(blur(a, 7.0, 0.55))
    b = norm(rng.standard_normal((s, s)))
    vert = norm(blur(b, 0.55, 7.0))
    yy, xx = np.mgrid[0:s, 0:s]
    mask = (((xx // 4) + (yy // 4)) % 2) == 0
    t = np.where(mask, horiz, vert)
    t = norm(t + 0.35 * norm(blur(rng.standard_normal((s, s)), 0.5)))
    to_img(colorize(t * 0.5, (212, 202, 180), 0.10)).save(os.path.join(OUT, 'bg_linen@2x.png'))
    img = to_img(colorize(t * 0.5, (212, 202, 180), 0.10))
    img.resize((s // 2, s // 2), Image.LANCZOS).save(os.path.join(OUT, 'bg_linen.png'))


def paper():
    s = 256
    n = norm(blur(rng.standard_normal((s, s)), 0.7))
    fib = norm(blur(rng.standard_normal((s, s)), 3.0, 0.4))
    t = 0.7 * n + 0.3 * fib
    img = to_img(colorize(t * 0.5, (249, 243, 228), 0.025))
    img.save(os.path.join(OUT, 'bg_paper@2x.png'))
    img.resize((s // 2, s // 2), Image.LANCZOS).save(os.path.join(OUT, 'bg_paper.png'))


# ---------- guziki ----------
SS = 4


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


def button(mask, w, h, top, bottom, name, border=(24, 14, 8)):
    big = mask
    W, H = w * SS, h * SS
    body = Image.fromarray(np.repeat(vgrad(H, top, bottom), W, axis=1).astype(np.uint8), 'RGB')
    gloss = Image.new('L', (W, H), 0)
    gd = ImageDraw.Draw(gloss)
    gd.rectangle((0, 0, W, H // 2), fill=46)
    body = Image.composite(Image.new('RGB', (W, H), (255, 255, 255)), body, gloss)
    # obrys: maska minus jej zmniejszona wersja
    inner = big.filter(ImageFilter.MinFilter(2 * SS + 1))
    border_mask = Image.fromarray(np.clip(np.array(big, int) - np.array(inner, int), 0, 255).astype(np.uint8))
    body = Image.composite(Image.new('RGB', (W, H), border), body, border_mask)
    # jasny wewnętrzny rant u góry
    rim = Image.new('L', (W, H), 0)
    rim_in = inner.filter(ImageFilter.MinFilter(SS + 1))
    top_rim = np.clip(np.array(inner, int) - np.array(rim_in, int), 0, 255)
    top_rim[H // 3:, :] = 0
    body = Image.composite(Image.new('RGB', (W, H), (190, 150, 120)), body,
                           Image.fromarray((top_rim * 0.5).astype(np.uint8)))
    rgba = body.convert('RGBA')
    rgba.putalpha(big)
    rgba = rgba.resize((w, h), Image.LANCZOS)
    rgba.save(os.path.join(OUT, name + '@2x.png'))
    rgba.resize((w // 2, h // 2), Image.LANCZOS).save(os.path.join(OUT, name + '.png'))


def buttons():
    w, h = 60, 60
    m = mask_rounded(w, h, 10)
    button(m, w, h, (112, 82, 64), (58, 40, 30), 'btn_bar')
    button(m, w, h, (70, 50, 38), (38, 26, 20), 'btn_bar_pressed')
    wb = 76
    mb = mask_back(wb, h, 26, 9)
    button(mb, wb, h, (112, 82, 64), (58, 40, 30), 'btn_back')
    button(mb, wb, h, (70, 50, 38), (38, 26, 20), 'btn_back_pressed')


# ---------- ikona i ekrany startowe ----------
def icon_1024():
    S = 1024
    L = leather(S, S, (92, 62, 44), amount=0.6)
    img = to_img(np.clip(L * vgrad(S, (1.12,) * 3, (0.86,) * 3), 0, 255)).convert('RGBA')
    big = Image.new('RGBA', (S * 2, S * 2), (0, 0, 0, 0))   # rysujemy w 2x, by obrysy były gładkie
    d = ImageDraw.Draw(big)
    # anteny
    d.line((S * 0.80, S * 0.40, S * 1.0, S * 0.18), fill=(30, 20, 14, 255), width=22)
    d.line((S * 1.2, S * 0.40, S * 1.0, S * 0.18), fill=(30, 20, 14, 255), width=22)
    # korpus (drewno) i ekran
    d.rounded_rectangle((S * 0.30, S * 0.50, S * 1.70, S * 1.60), radius=150, fill=(34, 22, 15, 255))
    d.rounded_rectangle((S * 0.34, S * 0.54, S * 1.66, S * 1.56), radius=140, fill=(150, 104, 66, 255))
    d.rounded_rectangle((S * 0.44, S * 0.64, S * 1.56, S * 1.46), radius=100, fill=(20, 26, 36, 255))
    scr = Image.new('RGBA', big.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(scr)
    sd.rounded_rectangle((S * 0.46, S * 0.66, S * 1.54, S * 1.44), radius=92, fill=(46, 74, 104, 255))
    sd.rounded_rectangle((S * 0.46, S * 0.66, S * 1.54, S * 1.05), radius=92, fill=(86, 122, 158, 255))
    mask = Image.new('L', big.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((S * 0.46, S * 0.66, S * 1.54, S * 1.44), radius=92, fill=255)
    big = Image.alpha_composite(big, Image.composite(scr, Image.new('RGBA', big.size, (0, 0, 0, 0)), mask))
    d = ImageDraw.Draw(big)
    d.polygon([(S * 0.86, S * 0.84), (S * 0.86, S * 1.26), (S * 1.18, S * 1.05)], fill=(250, 240, 214, 255))
    # guziki
    for i, y in enumerate((0.78, 0.98)):
        d.ellipse((S * 1.60 - 4, S * y * 1.0, S * 1.60 + 26, S * y * 1.0 + 30), fill=(30, 20, 14, 255))
    big = big.resize((S, S), Image.LANCZOS)
    img = Image.alpha_composite(img, big)
    d = ImageDraw.Draw(img)
    # ręcznie szyty obrys wokół ikony
    for x in range(60, S - 60, 36):
        d.rectangle((x, 44, x + 20, 50), fill=(236, 218, 168, 255))
        d.rectangle((x, S - 50, x + 20, S - 44), fill=(236, 218, 168, 255))
    for y in range(60, S - 60, 36):
        d.rectangle((44, y, 50, y + 20), fill=(236, 218, 168, 255))
        d.rectangle((S - 50, y, S - 44, y + 20), fill=(236, 218, 168, 255))
    return img.convert('RGB')


def icons_and_launch(icon):
    for name, sz in (('Icon.png', 57), ('Icon@2x.png', 114), ('Icon-Small.png', 29), ('Icon-Small@2x.png', 58)):
        icon.resize((sz, sz), Image.LANCZOS).save(os.path.join(OUT, name))
    lin = Image.open(os.path.join(OUT, 'bg_linen@2x.png'))
    nav = Image.open(os.path.join(OUT, 'nav_leather@2x.png'))
    for w, h, name in ((640, 960, 'Default@2x.png'), (640, 1136, 'Default-568h@2x.png')):
        im = Image.new('RGB', (w, h))
        for y in range(0, h, lin.size[1]):
            for x in range(0, w, lin.size[0]):
                im.paste(lin, (x, y))
        im.paste(nav.crop((0, 0, w, 88)).resize((w, 88)), (0, 0))   # pasek skórzany pod status barem
        ic = icon.resize((256, 256), Image.LANCZOS)
        m = Image.new('L', (256, 256), 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, 255, 255), radius=46, fill=255)
        im.paste(ic, ((w - 256) // 2, (h - 256) // 2), m)
        im.save(os.path.join(OUT, name))
        if name == 'Default@2x.png':
            im.resize((w // 2, h // 2), Image.LANCZOS).save(os.path.join(OUT, 'Default.png'))


if __name__ == '__main__':
    nav_bar(); header_strip(); linen(); paper(); buttons()
    icons_and_launch(icon_1024())
    print('gotowe:', sorted(os.listdir(OUT)))
