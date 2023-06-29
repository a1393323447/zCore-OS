export fn _kmain() noreturn {
    while (true) {
        asm volatile ("wfi");
    }
}
