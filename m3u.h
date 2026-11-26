/* Parser list M3U / M3U8 (IPTV). Czysty C, bez Foundation - dzięki temu da się go
 * testować na komputerze, a w aplikacji używa go M3UList.m. */
#ifndef M3U_H
#define M3U_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Jeden kanał z listy. Teksty są zakończone zerem i ważne tylko w czasie wywołania. */
typedef void (*m3u_entry_cb)(void *ctx, const char *name, const char *group,
                             const char *logo, const char *url);

/* Zwraca 1, jeśli tekst to pojedynczy strumień HLS (media playlist albo master playlist:
 * zawiera znaczniki #EXT-X-...), a nie lista kanałów. Taki adres odtwarzamy wprost. */
int m3u_is_hls(const char *text, size_t len);

/* Czyta listę kanałów i dla każdego wpisu woła cb. Zwraca liczbę wpisów.
 * Obsługuje: BOM, końce linii CRLF/CR/LF, #EXTINF z atrybutami (tvg-name, tvg-logo,
 * group-title, w cudzysłowach lub bez), #EXTGRP, linie #EXTVLCOPT (pomijane)
 * oraz zwykłe listy samych adresów (bez #EXTM3U). */
int m3u_parse(const char *text, size_t len, m3u_entry_cb cb, void *ctx);

#ifdef __cplusplus
}
#endif

#endif
