/*
 * Zastępcze pliki SDK (.tbd), z których budujemy aplikację na GitHubie, nie wymieniają kilku
 * podstawowych funkcji C. Linker kończył wtedy pracę błędem "Undefined symbols: _memcpy".
 * Dlatego te funkcje mamy tutaj własne (tak samo jak w aplikacji Rozkład). Każda ma optnone,
 * żeby kompilator nie zamienił pętli z powrotem na wywołanie memcpy/memset
 * (to byłaby nieskończona rekurencja).
 */
#include <stddef.h>

#define M3U_PLAIN __attribute__((optnone, noinline))

M3U_PLAIN void *memcpy(void *dst, const void *src, size_t n)
{
    unsigned char *d = (unsigned char *)dst;
    const unsigned char *s = (const unsigned char *)src;
    while (n--) *d++ = *s++;
    return dst;
}

M3U_PLAIN void *memset(void *dst, int c, size_t n)
{
    unsigned char *d = (unsigned char *)dst;
    while (n--) *d++ = (unsigned char)c;
    return dst;
}

M3U_PLAIN int memcmp(const void *a, const void *b, size_t n)
{
    const unsigned char *x = (const unsigned char *)a;
    const unsigned char *y = (const unsigned char *)b;
    while (n--) {
        if (*x != *y) return (int)*x - (int)*y;
        x++;
        y++;
    }
    return 0;
}
