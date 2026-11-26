#!/usr/bin/env python3
"""Zamienia duży plik programu TV (XMLTV, .xml albo .xml.gz) na mały JSON dla aplikacji iSat.

Wynik: {"v":1,"generated":<epoch>,"c":[{"n":["nazwa kanału",...],"p":[[start,stop,"tytuł"],...]},...]}
Zostają tylko programy z okna od 2 godzin temu do 30 godzin do przodu; czasy w sekundach UTC.
Użycie: build_epg.py wejście wyjście.json"""
import gzip, json, sys, time, calendar, re
import xml.etree.ElementTree as ET

BEFORE, AHEAD = 2 * 3600, 30 * 3600


def to_epoch(s):
    """'20261126200000 +0300' -> sekundy UTC (czas bez strefy traktujemy jako UTC)."""
    s = s.strip()
    m = re.match(r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?\s*([+-]\d{4})?', s)
    if not m:
        return None
    y, mo, d, h, mi, se = (int(m.group(i) or 0) for i in range(1, 7))
    t = calendar.timegm((y, mo, d, h, mi, se))
    z = m.group(7)
    if z:
        off = (int(z[1:3]) * 3600 + int(z[3:5]) * 60) * (1 if z[0] == '+' else -1)
        t -= off
    return t


def main(src, dst):
    opener = gzip.open if src.endswith('.gz') else open
    now = int(time.time())
    lo, hi = now - BEFORE, now + AHEAD
    names, progs = {}, {}
    total_prog = 0
    with opener(src, 'rb') as f:
        for ev, el in ET.iterparse(f, events=('end',)):
            if el.tag == 'channel':
                cid = el.get('id')
                names[cid] = [(dn.text or '').strip() for dn in el.findall('display-name') if (dn.text or '').strip()]
                el.clear()
            elif el.tag == 'programme':
                total_prog += 1
                a, b = to_epoch(el.get('start') or ''), to_epoch(el.get('stop') or '')
                if a is not None and b is not None and b >= lo and a <= hi:
                    t = el.find('title')
                    title = ((t.text if t is not None else '') or '').strip()[:120]
                    if title:
                        progs.setdefault(el.get('channel'), []).append([a, b, title])
                el.clear()
    out = []
    for cid, plist in progs.items():
        ns = names.get(cid) or [cid]
        plist.sort()
        out.append({'n': ns, 'p': plist})
    out.sort(key=lambda c: c['n'][0].lower())
    data = {'v': 1, 'generated': now, 'c': out}
    with open(dst, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
    size = len(json.dumps(data, ensure_ascii=False, separators=(',', ':')).encode('utf-8'))
    print('kanałów w pliku źródłowym: %d, z programem w oknie: %d, wszystkich programów: %d, wynik: %.2f MB'
          % (len(names), len(out), total_prog, size / 1048576.0))
    for c in out[:8]:
        p = c['p'][0]
        print('  próbka:', c['n'], '->', p[2], time.strftime('%H:%M', time.gmtime(p[0])) + ' UTC')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
