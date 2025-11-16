// --------------------------------------------------
// Document:  c_functions.h
// Project:   PJON_ASIC/croc
// Function:  definitions of c functions to be used in cpp-code
// Autor:     Pius Sieber
// Date:      14.07.2025
// Comments:  -
// --------------------------------------------------
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