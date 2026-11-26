#include "../m3u.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define MAXE 64
static struct { char n[300], g[300], l[300], u[300]; } E[MAXE];
static int N;
static void cb(void *c, const char *n, const char *g, const char *l, const char *u)
{
    (void)c;
    if (N < MAXE) { snprintf(E[N].n, 300, "%s", n); snprintf(E[N].g, 300, "%s", g); snprintf(E[N].l, 300, "%s", l); snprintf(E[N].u, 300, "%s", u); }
    N++;
}
static int fails;
#define CHECK(c) do { if (!(c)) { printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); fails++; } } while (0)
static int parse(const char *s) { N = 0; return m3u_parse(s, strlen(s), cb, NULL); }

int main(void)
{
    /* typowa lista IPTV */
    CHECK(parse("#EXTM3U\r\n#EXTINF:-1 tvg-id=\"a\" tvg-name=\"TVP 1 HD\" tvg-logo=\"http://x/l.png\" group-title=\"Polska, Info\",TVP 1 HD\r\nhttp://s/1.m3u8\r\n"
                "#EXTINF:-1 group-title=\"Sport\",Eleven, Sports 1\nhttps://s/2.m3u8?t=a,b\n") == 2);
    CHECK(!strcmp(E[0].n, "TVP 1 HD") && !strcmp(E[0].g, "Polska, Info") && !strcmp(E[0].l, "http://x/l.png") && !strcmp(E[0].u, "http://s/1.m3u8"));
    CHECK(!strcmp(E[1].n, "Sports 1") && !strcmp(E[1].g, "Sport") && !strcmp(E[1].u, "https://s/2.m3u8?t=a,b"));

    /* BOM, #EXTGRP, #EXTVLCOPT, puste linie, stary CR */
    CHECK(parse("\xEF\xBB\xBF#EXTM3U\r#EXTINF:0,Kanał ąę\r#EXTGRP:Filmy\r#EXTVLCOPT:http-user-agent=X\r\r rtmp://h/live \r") == 1);
    CHECK(!strcmp(E[0].n, "Kanał ąę") && !strcmp(E[0].g, "Filmy") && !strcmp(E[0].u, "rtmp://h/live"));

    /* sama lista adresów, bez nagłówka */
    CHECK(parse("http://a/1.m3u8\nhttp://a/2.m3u8\n") == 2);
    CHECK(!strcmp(E[0].n, "http://a/1.m3u8") && E[0].g[0] == 0);

    /* brak nazwy: bierzemy tvg-name; atrybuty bez cudzysłowów i z apostrofami */
    CHECK(parse("#EXTINF:-1 tvg-name=Radio_X group-title='Muzyka' tvg-logo=http://l/i.png,\nhttp://a/r\n") == 1);
    CHECK(!strcmp(E[0].n, "Radio_X") && !strcmp(E[0].g, "Muzyka") && !strcmp(E[0].l, "http://l/i.png"));

    /* wielkie litery w kluczach, dane nie przechodzą na następny wpis */
    CHECK(parse("#EXTINF:-1 GROUP-TITLE=\"A\",Jeden\nhttp://a/1\nhttp://a/2\n") == 2);
    CHECK(!strcmp(E[0].g, "A") && E[1].g[0] == 0 && !strcmp(E[1].n, "http://a/2"));

    /* śmieci: linie bez adresu pomijamy; pusty tekst */
    CHECK(parse("#EXTM3U\nto nie jest adres\n") == 0);
    CHECK(parse("") == 0);

    /* wykrywanie HLS */
    CHECK(m3u_is_hls("#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-STREAM-INF:BANDWIDTH=1\nhttp://a/b.m3u8\n", 70));
    const char *list = "#EXTM3U\n#EXTINF:-1,X\nhttp://a/1\n";
    CHECK(!m3u_is_hls(list, strlen(list)));
    const char *key = "#EXTINF:-1 tvg-name=\"#EXT-X-FAKE\",X\nhttp://a/1\n";
    CHECK(!m3u_is_hls(key, strlen(key)));

    /* bardzo długi adres i nazwa nie wywracają parsera */
    char *big = malloc(20000);
    strcpy(big, "#EXTINF:-1,");
    memset(big + 11, 'N', 5000); strcpy(big + 5011, "\nhttp://");
    memset(big + 5019, 'u', 9000); strcpy(big + 14019, "\n");
    CHECK(parse(big) == 1);
    CHECK(strlen(E[0].n) < 1024 && strlen(E[0].u) < 4096);
    free(big);

    printf(fails ? "BŁĘDY: %d\n" : "OK\n", fails);
    return fails != 0;
}
