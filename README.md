# Czytnik M3U

Aplikacja na iOS 6 (jailbreak, armv7) do czytania playlist M3U/M3U8: lista playlist, kanały z grupami,
wyszukiwarka, ulubione i odtwarzanie HLS przez natywny odtwarzacz.

- Parser listy: `m3u.c` (czysty C, testy w `tests/m3u_test.c`:
  `clang -o /tmp/t tests/m3u_test.c m3u.c && /tmp/t`).
- Budowanie: Theos + GitHub Actions (`.github/workflows/build.yml`), identycznie jak w Rozkładzie.
- Ograniczenia: tylko HLS (H.264) przez http/https. Szczegóły w `CZYTAJ-TO.txt`.
