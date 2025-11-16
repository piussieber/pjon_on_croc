// --------------------------------------------------
// Document:  idma_OBIfrontend.h
// Project:   PJON_ASIC/idma
// Function:  constants definitions for the OBI-frontend for the iDMA
// Autor:     Pius Sieber
// Date:      01.05.2025
// Comments:  -
// --------------------------------------------------
#define IDMA_BASE_ADDR 0x20002000
#define IDMA_LENGTH_OFFSET 4 // read & write  // writing to this register starts the dma execution
#define IDMA_SOURCE_OFFSET 8 // read & write
#define IDMA_DESTINATION_OFFSET 12 // read & write
                             // register 16 shouldn't be used at the moment
#define IDMA_STATUS_OFFSET 20 // read only
#define IDMA_DONE_OFFSET 24 // read only
