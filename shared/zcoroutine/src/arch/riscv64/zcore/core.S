.section .text
.global switchCtx
.global switchToNext
.global initCall
.align  2
# x10: cur_ctx_ptr
# x11: next_ctx_ptr
switchCtx:
    # save cur context
    sd  x8,  0*8(x10)
    sd  x9,  1*8(x10)
    sd x18,  2*8(x10)
    sd x19,  3*8(x10)
    sd x20,  4*8(x10)
    sd x21,  5*8(x10)
    sd x22,  6*8(x10)
    sd x23,  7*8(x10)
    sd x24,  8*8(x10)
    sd x25,  9*8(x10)
    sd x26, 10*8(x10)
    sd x27, 11*8(x10)
    sd  sp, 12*8(x10)
    sd  ra, 13*8(x10)

    # load next context
    ld  x8,  0*8(x11)
    ld  x9,  1*8(x11)
    ld x18,  2*8(x11)
    ld x19,  3*8(x11)
    ld x20,  4*8(x11)
    ld x21,  5*8(x11)
    ld x22,  6*8(x11)
    ld x23,  7*8(x11)
    ld x24,  8*8(x11)
    ld x25,  9*8(x11)
    ld x26, 10*8(x11)
    ld x27, 11*8(x11)
    ld  sp, 12*8(x11)
    ld  t1, 13*8(x11)
    jr  t1

switchToNext:
    ld  x8,  0*8(x10)
    ld  x9,  1*8(x10)
    ld x18,  2*8(x10)
    ld x19,  3*8(x10)
    ld x20,  4*8(x10)
    ld x21,  5*8(x10)
    ld x22,  6*8(x10)
    ld x23,  7*8(x10)
    ld x24,  8*8(x10)
    ld x25,  9*8(x10)
    ld x26, 10*8(x10)
    ld x27, 11*8(x10)
    ld  sp, 12*8(x10)
    ld  t1, 13*8(x10)
    jr  t1

# x10: args_ptr
# x11: typeSafeCall function address
# x12: curr_ctx_ptr
# x13: next_ctx_ptr
initCall:
    # save cur context
    sd  x8,  0*8(x12)
    sd  x9,  1*8(x12)
    sd x18,  2*8(x12)
    sd x19,  3*8(x12)
    sd x20,  4*8(x12)
    sd x21,  5*8(x12)
    sd x22,  6*8(x12)
    sd x23,  7*8(x12)
    sd x24,  8*8(x12)
    sd x25,  9*8(x12)
    sd x26, 10*8(x12)
    sd x27, 11*8(x12)
    sd  sp, 12*8(x12)
    sd  ra, 13*8(x12)

    # load coroutine stack
    ld sp, 12*8(x13)

    # call typeSafeCall function
    jalr   x11
