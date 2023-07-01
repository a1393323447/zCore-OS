.align 3
    .section .data
    .global _num_app
_num_app:
    .quad 3
    .quad app_0_start
    .quad app_1_start
    .quad app_2_start
    # .quad app_3_start
    # .quad app_4_start
    .quad app_2_end

.section .data
    .global app_0_start
    .global app_0_end
app_0_start:
    .incbin "zig-out/bin/power.bin" # TODO
app_0_end:

.section .data
    .global app_1_start
    .global app_1_end
app_1_start:
    .incbin "zig-out/bin/store_fault.bin" # TODO
app_1_end:

.section .data
    .global app_2_start
    .global app_2_end
app_2_start:
    .incbin "zig-out/bin/hello_world.bin" # TODO
app_2_end:

# .section .data
#     .global app_3_start
#     .global app_3_end
# app_3_start:
#     .incbin "zig-out/bin/{1}.bin" # TODO
# app_3_end:

# .section .data
#     .global app_4_start
#     .global app_4_end
# app_4_start:
#     .incbin "zig-out/bin/{1}.bin" # TODO
# app_4_end: