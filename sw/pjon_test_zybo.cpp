// Copyright (c) 2024 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0/
//
// Authors:
// - Pius Sieber <pisieber@student.ethz.ch>

#define SWBB_MODE 1
#define CROC
#define CROC_FGPA
#include <cstdint>
//#include "memcpy.h"
//#include "/foss/tools/riscv-gnu-toolchain/riscv64-unknown-elf/include/string.h"

extern "C" {
    //void * memcpy (void *dest, const void *src, uint32_t len);
    //void * memcpy (void *__restrict, const void *__restrict, size_t);

    void printf(const char *fmt, ...);

    void gpio_set_direction(uint32_t mask, uint32_t direction); // 1: output
    void gpio_enable(uint32_t mask);
    void gpio_disable(uint32_t mask);

    void gpio_write(uint32_t value);
    void gpio_toggle(uint32_t mask);
    uint32_t gpio_read(void);

    void gpio_enable_rising_interrupts(uint32_t mask);
    void gpio_enable_falling_interrupts(uint32_t mask);
    void gpio_disable_interrupts(uint32_t mask);
    uint32_t gpio_get_interrupt_status(void);

    void gpio_pin_set_output(uint8_t gpio_pin);
    void gpio_pin_set_input(uint8_t gpio_pin);
    void gpio_pin_enable(uint8_t gpio_pin);
    void gpio_pin_disable(uint8_t gpio_pin);

    void gpio_pin_set(uint8_t gpio_pin);
    void gpio_pin_clear(uint8_t gpio_pin);
    void gpio_pin_toggle(uint8_t gpio_pin);
    uint8_t gpio_pin_read(uint8_t gpio_pin);

    void gpio_pin_enable_rising_interrupt(uint8_t gpio_pin);
    void gpio_pin_enable_falling_interrupt(uint8_t gpio_pin);
    void gpio_pin_disable_interrupts(uint8_t gpio_pin);
    uint8_t gpio_pin_get_interrupt_status(uint8_t gpio_pin);

    void uart_init();

    int uart_read_ready();

    void uart_write(uint8_t byte);

    void uart_write_str(void *src, uint32_t len);

    void uart_write_flush();

    uint8_t uart_read();

    void uart_read_str(void *dst, uint32_t len);

    void putchar(char byte);

    char getchar();

    void * memcpy_dma (void *dest, const void *src, uint32_t len);

    uint8_t uart_read ();
}

#include <cstdint>
#include <cstring>
#include "./lib/inc/PJON/src/PJON_PJDL_HW.h"

PJON_PJDL_HW bus(1);

void receiver_function(uint8_t *payload, uint16_t length, const PJON_Packet_Info &info) {
    // Print received data in the serial monitor
    //for(uint16_t i = 0; i < length; i++)
    //  Serial.print(payload[i]);
    printf("received: %x\n", payload[0]);
    uart_write_flush();
    if(payload[0] == 65){
        gpio_pin_toggle(2);
    }
    delay(20);
        if(payload[0] == 66){
        gpio_pin_toggle(1);
    }
    delay(20);
  };

int main() {
    uart_init(); // setup the uart peripheral
    printf("start\n");
    uart_write_flush();

    gpio_pin_set_output(2);
    gpio_pin_set_output(1);
    gpio_pin_enable(1);
    gpio_pin_enable(2);
    gpio_pin_enable(3);
    gpio_pin_set_input(3);


    //printf("crc:%x\n",PJON_crc8::roll(0x06, PJON_crc8::roll(0x00, PJON_crc8::roll(0x01, 0))));
    //uart_write_flush

    // memcpy_test
    int test_src[20];
    int test_dst[20];
    test_src[0] = 0x00000001;
    test_src[1] = 0x00000402; // last bit set
    test_src[2] = 0x00000001;
    test_src[3] = 0x00000402; // last bit set
    test_src[4] = 0x00000605; // ack-request, 5 repetitions of keeping the bus alive
    test_src[19] = 0x12345678;

    memcpy_dma(test_dst, test_src, 20);

    printf("test_dst: %x\n", test_dst[19]);
    uart_write_flush();

    bus.begin();

    bus.set_shared_network(false);
    bus.set_crc_32(false);
    bus.set_acknowledge(false);
    bus.include_sender_info(false);
    //bus.include_port(false); // library not included
    //bus.include_packet_id(false); // library not included
    bus.include_mac(false);
    bus.set_receiver(receiver_function);
    bus.set_router(false);
    bus.set_communication_mode(PJON_HALF_DUPLEX);
    bus.set_id(1); // ToDo: check wy we have to reset this id here (is 0 without this line)

    bool sent = false;
    uint32_t last_change = millis();

    while (1) {
        /*if(bus.send_packet(2, "A", 1) == PJON_BUSY) {
            printf("BUS BUSY\n");
            uart_write_flush();
        }else {
            printf("sent_PacketA\n");
            uart_write_flush();
        }

        delay(500);*/
        /*if(last_change + 1000 < millis()) {
          last_change = millis();
          bus.send_packet(2, "A", 1);
        }*/

        /*if((gpio_pin_read(2) == true) && (sent==false)){
          gpio_pin_toggle(2);
          bus.send_packet(2, "A", 1);
          sent = true;
        }
        if(gpio_pin_read(2)==false){
          sent = false;
        }*/
        bus.receive();

        /*uint16_t response;
        for(uint16_t i = 0; i < 10; i++) {
            response = bus.receive(1000);
            if(response!=0xFFFF){
                break;
            }
        }*/
    }

    //printf("receiving_code: %x\n", response);
    //uart_write_flush();

    while (1);

    return 1;
}
