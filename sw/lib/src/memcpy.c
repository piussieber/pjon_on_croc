// --------------------------------------------------
// Document:  memcpy.cpp
// Project:   PJON_ASIC/idma
// Function:  memcpy function working with the idma and the OBI-frontend for iDMA
// Autor:     Pius Sieber
// Date:      01.05.2025
// Comments:  -
// --------------------------------------------------
#include "memcpy.h"

// Memcpy without dma (From https://github.com/gcc-mirror/gcc/blob/master/libgcc/memcpy.c )
void *
memcpy (void *dest, const void *src, uint32_t len)
{
  char *d = dest;
  const char *s = src;
  while (len--)
    *d++ = *s++;
  return dest;
}

// Memcpy with dma
void * memcpy_dma (void *dest, const void *src, uint32_t len)
{
  *reg32(IDMA_BASE_ADDR, IDMA_SOURCE_OFFSET) = (uint32_t)src;// source
  *reg32(IDMA_BASE_ADDR, IDMA_DESTINATION_OFFSET) = (uint32_t)dest;// destination
  *reg32(IDMA_BASE_ADDR, IDMA_LENGTH_OFFSET) = len*4; // length & start

  while(*reg32(IDMA_BASE_ADDR, IDMA_DONE_OFFSET)==0x00); // wait for idma to complete the task

  return dest;
}