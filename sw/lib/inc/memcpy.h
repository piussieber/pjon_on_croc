// --------------------------------------------------
// Document:  memcpy.h
// Project:   PJON_ASIC/idma
// Function:  memcpy function working with the idma and the OBI-frontend for iDMA
// Autor:     Pius Sieber
// Date:      01.05.2025
// Comments:  -
// --------------------------------------------------
#include <stdint.h>
#include "idma_OBIfrontend.h"
#include "util_cpp.h"
void * memcpy_dma (void *dest, const void *src, uint32_t len);
void * memcpy (void *dest, const void *src, uint32_t len);