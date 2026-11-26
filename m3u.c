#include "m3u.h"
#include <string.h>
#include <stdlib.h>

#define FIELD 1024

static int ieq_n(const char *a, const char *b, size_t n)
{
    for (size_t i = 0; i < n; i++) {
        char x = a[i], y = b[i];
        if (x >= 'A' && x <= 'Z') x = (char)(x + 32);
        if (y >= 'A' && y <= 'Z') y = (char)(y + 32);
        if (x != y) return 0;
    }
    return 1;
}

static int starts_ci(const char *s, size_t len, const char *prefix)
{
    size_t n = strlen(prefix);
    return len >= n && ieq_n(s, prefix, n);
}

static void trim(const char **s, size_t *len)
{
    while (*len && (**s == ' ' || **s == '\t')) { (*s)++; (*len)--; }
    while (*len && ((*s)[*len - 1] == ' ' || (*s)[*len - 1] == '\t')) (*len)--;
}

static void put(char *dst, const char *src, size_t n)
{
    if (n >= FIELD) n = FIELD - 1;
    memcpy(dst, src, n);
    dst[n] = 0;
}

/* Szuka atrybutu key="wartość" (lub key=wartość) w opisie #EXTINF. */
static int attr(const char *s, size_t len, const char *key, char *out)
{
    size_t kl = strlen(key);
    out[0] = 0;
    for (size_t i = 0; i + kl < len; i++) {
        if (i > 0 && s[i - 1] != ' ' && s[i - 1] != '\t' && s[i - 1] != ',' && s[i - 1] != ':') continue;
        if (!ieq_n(s + i, key, kl)) continue;
        size_t j = i + kl;
        while (j < len && s[j] == ' ') j++;
        if (j >= len || s[j] != '=') continue;
        j++;
        while (j < len && s[j] == ' ') j++;
        size_t a, b;
        if (j < len && (s[j] == '"' || s[j] == '\'')) {
            char q = s[j++];
            a = j;
            while (j < len && s[j] != q) j++;
            b = j;
        } else {
            a = j;
            while (j < len && s[j] != ' ' && s[j] != '\t' && s[j] != ',') j++;
            b = j;
        }
        put(out, s + a, b - a);
        return 1;
    }
    return 0;
}

/* Nazwa kanału to tekst po ostatnim przecinku poza cudzysłowami. */
static void title_of(const char *s, size_t len, char *out)
{
    int quote = 0;
    char q = 0;
    size_t comma = (size_t)-1;
    for (size_t i = 0; i < len; i++) {
        if (quote) { if (s[i] == q) quote = 0; }
        else if (s[i] == '"' || s[i] == '\'') { quote = 1; q = s[i]; }
        else if (s[i] == ',') comma = i;
    }
    out[0] = 0;
    if (comma == (size_t)-1) return;
    const char *t = s + comma + 1;
    size_t tl = len - comma - 1;
    trim(&t, &tl);
    put(out, t, tl);
}

static int looks_like_url(const char *s, size_t len)
{
    for (size_t i = 0; i + 2 < len && i < 16; i++)
        if (s[i] == ':' && s[i + 1] == '/' && s[i + 2] == '/') return i > 0;
    return 0;
}

int m3u_is_hls(const char *text, size_t len)
{
    for (size_t i = 0; i + 6 < len; i++) {
        if (text[i] == '#' && (i == 0 || text[i - 1] == '\n' || text[i - 1] == '\r') &&
            ieq_n(text + i, "#EXT-X-", 7)) return 1;
    }
    return 0;
}

int m3u_parse(const char *text, size_t len, m3u_entry_cb cb, void *ctx)
{
    char name[FIELD], group[FIELD], logo[FIELD], tmp[FIELD], url[FIELD * 4];
    int have = 0, count = 0;
    size_t pos = 0;
    name[0] = group[0] = logo[0] = 0;

    if (len >= 3 && (unsigned char)text[0] == 0xEF && (unsigned char)text[1] == 0xBB && (unsigned char)text[2] == 0xBF) pos = 3;

    while (pos < len) {
        size_t start = pos;
        while (pos < len && text[pos] != '\n' && text[pos] != '\r') pos++;
        const char *line = text + start;
        size_t ll = pos - start;
        while (pos < len && (text[pos] == '\n' || text[pos] == '\r')) pos++;
        trim(&line, &ll);
        if (!ll) continue;

        if (line[0] == '#') {
            if (starts_ci(line, ll, "#EXTINF:")) {
                const char *d = line + 8;
                size_t dl = ll - 8;
                name[0] = group[0] = logo[0] = 0;
                attr(d, dl, "group-title", group);
                {
                    /* różne listy nazywają logo różnie */
                    static const char *const keys[] = { "tvg-logo", "tvg_logo", "logo", "tvg-logo-small", "tvg-icon", "icon", "logo_url", "logo-url", NULL };
                    for (int k = 0; keys[k] && !logo[0]; k++) attr(d, dl, keys[k], logo);
                }
                title_of(d, dl, name);
                if (!name[0] && attr(d, dl, "tvg-name", tmp)) put(name, tmp, strlen(tmp));
                have = 1;
            } else if (starts_ci(line, ll, "#EXTGRP:")) {
                const char *g = line + 8;
                size_t gl = ll - 8;
                trim(&g, &gl);
                if (!group[0]) put(group, g, gl);
            }
            continue;
        }

        if (!looks_like_url(line, ll)) continue;
        size_t n = ll < sizeof(url) - 1 ? ll : sizeof(url) - 1;
        memcpy(url, line, n);
        url[n] = 0;
        cb(ctx, name[0] ? name : url, group, logo, url);
        count++;
        have = 0;
        name[0] = group[0] = logo[0] = 0;
    }
    (void)have;
    return count;
}
