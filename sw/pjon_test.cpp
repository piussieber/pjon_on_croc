// Copyright (c) 2025 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0/
//
// Authors:
// - Pius Sieber <pisieber@student.ethz.ch>

#define SWBB_MODE 1
#define CROC
#include <cstdint>

#include <c_functions.h>
#include <cstring>
#include "./lib/inc/PJON/src/PJON_PJDL_HW.h"

#define USER_ROM_BASE_ADDR 0x20000000

void receiver_function(uint8_t *payload, uint16_t length, const PJON_Packet_Info &info) {
    printf("received: %x\n", payload[0]);
    uart_write_flush();
  };

int main() {
    uart_init(); // setup the uart peripheral

    PJON_PJDL_HW bus(1); // start pjon-bus with device id 1

    printf("start\n");
    uart_write_flush();

    uint32_t str[4];
    for(uint8_t i =0; i<4; ++i){
        //printf("ROM-Byte%x:, 0x%x\n", i, *reg32(USER_ROM_BASE_ADDR, i*4));
        //uart_write_flush();
        str[i]=*reg32(USER_ROM_BASE_ADDR, i << 2);

    }
    printf("ROM-Read: %s\n", str);
    uart_write_flush();


    bus.begin();

    bus.set_acknowledge(false);
    bus.set_receiver(receiver_function);
    bus.set_router(false);

    if(bus.send_packet(1, "A", 1) == PJON_BUSY) {
        printf("BUS BUSY\n");
        uart_write_flush();
    }else{
        printf("sent_PacketA\n");
        uart_write_flush();
    }

    bus.set_acknowledge(true);

    uint8_t answer = bus.send_packet(1, "B", 1);
    if(answer == PJON_BUSY) {
        printf("BUS BUSY\n");
        uart_write_flush();
    }else if(answer == PJON_ACK) {
        printf("sent_PacketB, ack received\n");
        uart_write_flush();
    }else{
        printf("sent_PacketB, NO ack received!, answer: %x\n", answer);
        uart_write_flush();
    }

    printf("ready to receive\n");
    uart_write_flush();

    uint16_t response;
    for(uint16_t i = 0; i < 10; i++) {
        response = bus.receive(1000);
        if(response!=0xFFFF){
            break;
        }
    }
    for(uint16_t i = 0; i < 10; i++) {
        response = bus.receive(1000);
        if(response!=0xFFFF){
            break;
        }
    }

    delay(2);

    return 1;
}
