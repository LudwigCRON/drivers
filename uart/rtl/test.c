#include "stdio.h"
#include "stdlib.h"
#include "stdint.h"

typedef struct toto_ports_t
{
    union
    {
        struct test
        {
            // -- first byte ---
            unsigned int enable : 1;
            unsigned int reserved_0 : 1;
            unsigned int soc_source : 2;
            unsigned int sos_source : 2;
            // --- second byte ---
            unsigned int averaging : 4;
            unsigned int reserved_1 : 6;
            // --- remainin ---
            unsigned int reserved_2 : 16;
        } fields;
        struct
        {
            uint8_t llsb;
            uint8_t lmsb;
            uint8_t mlsb;
            uint8_t mmsb;
        } bytes;
        struct
        {
            uint16_t lsw;
            uint16_t msw;
        } words;
        uint32_t dword;
    } cfg;
};

void debug_toto(const struct toto_ports_t *toto)
{
    printf("Size of toto_ports_t %lu\n", sizeof(*toto));
    printf("%lx: 0x%08X\n", &toto->cfg, toto->cfg.dword);
    printf("%lx: 0x%04X\n", &toto->cfg.words, toto->cfg.words.lsw);
    printf("%lx: 0x%04X\n", &toto->cfg.words, toto->cfg.words.msw);
    printf("%lx: 0x%02X\n", &toto->cfg.bytes, toto->cfg.bytes.llsb);
    printf("%lx: 0x%02X\n", &toto->cfg.bytes, toto->cfg.bytes.lmsb);
    printf("%lx: 0x%02X\n", &toto->cfg.bytes, toto->cfg.bytes.mlsb);
    printf("%lx: 0x%02X\n", &toto->cfg.bytes, toto->cfg.bytes.mmsb);
}

void main(void)
{
    struct toto_ports_t toto = {.cfg.dword = 0};
    debug_toto(&toto);
    toto.cfg.bytes.llsb = 0x01u;
    toto.cfg.bytes.lmsb = 0x02u;
    toto.cfg.words.msw = 0xF800u;
    debug_toto(&toto);
    toto.cfg.fields.enable = 1u;
    toto.cfg.fields.averaging = 4u;
    toto.cfg.fields.soc_source = 3u;
    toto.cfg.fields.sos_source = 3u;
    debug_toto(&toto);
}