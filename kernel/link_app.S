.align 3
    .section .data
    .global _num_app
_num_app:
    .quad 13
    .quad app_0_start
    .quad app_1_start
    .quad app_2_start
    .quad app_3_start
    .quad app_4_start
    .quad app_5_start
    .quad app_6_start
    .quad app_7_start
    .quad app_8_start
    .quad app_9_start
    .quad app_10_start
    .quad app_11_start
    .quad app_12_start
    .quad app_12_end

.global _app_names
_app_names:
    .string "forktest_0"
    .string "initproc"
    .string "mmap_0"
    .string "munmap_0"
    .string "power_3"
    .string "power_5"
    .string "power_7"
    .string "sleep"
    .string "spawn_0"
    .string "spawn_1"
    .string "stack_overflow"
    .string "test_getpid"
    .string "user_shell"

.section .data
    .global app_0_start
    .global app_0_end
app_0_start:
    .incbin "zig-out/forktest_0"
app_0_end:

.section .data
    .global app_1_start
    .global app_1_end
app_1_start:
    .incbin "zig-out/initproc"
app_1_end:

.section .data
    .global app_2_start
    .global app_2_end
app_2_start:
    .incbin "zig-out/mmap_0"
app_2_end:

.section .data
    .global app_3_start
    .global app_3_end
app_3_start:
    .incbin "zig-out/munmap_0"
app_3_end:

.section .data
    .global app_4_start
    .global app_4_end
app_4_start:
    .incbin "zig-out/power_3"
app_4_end:

.section .data
    .global app_5_start
    .global app_5_end
app_5_start:
    .incbin "zig-out/power_5"
app_5_end:

.section .data
    .global app_6_start
    .global app_6_end
app_6_start:
    .incbin "zig-out/power_7"
app_6_end:

.section .data
    .global app_7_start
    .global app_7_end
app_7_start:
    .incbin "zig-out/sleep"
app_7_end:

.section .data
    .global app_8_start
    .global app_8_end
app_8_start:
    .incbin "zig-out/spawn_0"
app_8_end:

.section .data
    .global app_9_start
    .global app_9_end
app_9_start:
    .incbin "zig-out/spawn_1"
app_9_end:

.section .data
    .global app_10_start
    .global app_10_end
app_10_start:
    .incbin "zig-out/stack_overflow"
app_10_end:

.section .data
    .global app_11_start
    .global app_11_end
app_11_start:
    .incbin "zig-out/test_getpid"
app_11_end:

.section .data
    .global app_12_start
    .global app_12_end
app_12_start:
    .incbin "zig-out/user_shell"
app_12_end:
