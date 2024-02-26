//! RISC-V registers

fn bits_from(v: anytype, comptime start: usize, comptime end: usize) @TypeOf(v) {
    const TOTAL_BITS = @bitSizeOf(@TypeOf(v));
    return (v << (TOTAL_BITS - end)) >> (TOTAL_BITS - end + start - 1);
}

/// hart (core) id registers
pub const mhartid = struct {
    pub inline fn read() usize {
        return asm volatile (
            \\ csrr %[ret], mhartid
            : [ret] "=r" (-> usize),
        );
    }
};

/// Machine Status Register, mstatus
pub const mstatus = struct {
    // Machine Status Register bit
    const MPP_MASK: usize = 3 << 11;
    const MIE: usize = 1 << 3;

    pub const MPP = enum(usize) {
        Machine = 3,
        Supervisor = 1,
        User = 0,
    };

    pub inline fn _read() usize {
        return asm volatile (
            \\ csrr %[ret], mstatus 
            : [ret] "=r" (-> usize),
        );
    }

    inline fn _write(bits: usize) void {
        asm volatile (
            \\ csrw mstatus, %[bits]
            :
            : [bits] "r" (bits),
        );
    }

    pub inline fn set_mpp(mpp: MPP) void {
        var value = _read();
        value &= !MPP_MASK;
        value |= mpp << 11;
        _write(value);
    }

    pub inline fn set_mie() void {
        asm volatile (
            \\ csrs mstatus, %[MIE]
            :
            : [MIE] "i" (MIE),
        );
    }

    pub inline fn set_sie() void {
        asm volatile (
            \\ csrs mstatus, %[MIE]
            :
            : [MIE] "i" (MIE),
        );
    }
};

/// machine exception program counter, holds the
/// instruction address to which a return from
/// exception will go.
pub const mepc = struct {
    pub fn write(x: usize) void {
        asm volatile (
            \\ csrw mepc, %[x]
            :
            : [x] "r" (x),
        );
    }
};

/// Supervisor Status Register, sstatus
pub const sstatus = struct {
    // Supervisor Status Register bit
    const SPP_MASK: usize = 1 << 8; // Previous mode, 1=Supervisor, 0=user
    const SPIE: usize = 1 << 5; // Supervisor Previous Interrupt Enable
    const SIE: usize = 1 << 1; // Supervisor Interrupt Enable

    pub const Sstatus = packed struct {
        bits: usize,

        const Self = @This();
        pub inline fn sie(self: Self) bool {
            return self.bits & SIE != 0;
        }

        pub inline fn spp(self: Self) SPP {
            return switch (self.bits & SPP_MASK) {
                0 => SPP.User,
                _ => SPP.Supervisor,
            };
        }

        pub inline fn restore(self: Self) void {
            _write(self.bits);
        }
    };

    pub const SPP = enum(usize) {
        Supervisor = 1,
        User = 0,
    };

    pub inline fn set_sie() void {
        _set(SIE);
    }

    pub inline fn clear_sie() void {
        _clear(SIE);
    }

    pub inline fn set_spie() void {
        _set(SPIE);
    }

    pub inline fn set_spp(spp: SPP) void {
        switch (spp) {
            SPP.Supervisor => _set(SPP_MASK),
            SPP.User => _clear(SPP_MASK),
        }
    }

    pub inline fn read() Sstatus {
        var bits: usize = asm (
            \\ csrr %[ret], sstatus
            : [ret] "=r" (-> usize),
        );

        return Sstatus{ .bits = bits };
    }

    inline fn _write(bits: usize) void {
        asm volatile (
            \\ csrw sstatus, %[bits]
            :
            : [bits] "r" (bits),
        );
    }

    inline fn _set(bits: usize) void {
        asm volatile (
            \\ csrs sstatus, %[bits]
            :
            : [bits] "r" (bits),
        );
    }

    inline fn _clear(bits: usize) void {
        asm volatile (
            \\ csrc sstatus, %[bits]
            :
            : [bits] "r" (bits),
        );
    }
};

const TMode = enum(usize) {
    Diret = 0,
    Vectored = 1,
};

/// Supervisor Trap-Vector Base Address
/// low two bits are mode.
pub const stvec = struct {
    pub const TrapMode = TMode;

    pub inline fn write(addr: usize, mode: TrapMode) void {
        asm volatile (
            \\ csrw stvec, %[mode_bit]
            :
            : [mode_bit] "r" (addr + @intFromEnum(mode)),
        );
    }
};

/// Machine-mode interrupt vector
pub const mtvec = struct {
    pub const TrapMode = TMode;

    pub inline fn write(addr: usize, mode: TrapMode) void {
        asm volatile (
            \\ csrw mtvec, %[mode_bit]
            :
            : [mode_bit] "r" (addr + @intFromEnum(mode)),
        );
    }
};

/// mscratch register
pub const mscratch = struct {
    pub inline fn write(bits: usize) void {
        asm volatile (
            \\ csrw mscratch, %[bits]
            :
            : [bits] "r" (bits),
        );
    }
};

/// Supervisor Trap Cause
pub const scause = struct {
    pub inline fn read() Scause {
        const bits = asm volatile (
            \\ csrr %[ret], scause
            : [ret] "=r" (-> usize),
        );

        return Scause { .bits = bits };
    }

    pub const Scause = struct {
        bits: usize,

        const Self = @This();

        const nbit: usize = @sizeOf(usize) * 8 - 1;
        const bit: usize = 1 << nbit;

        pub inline fn code(self: Self) usize {
            return self.bits & ~bit;
        }

        pub inline fn cause(self: Self) Trap {
            if (self.is_interrupt()) {
                return Trap{ .interrupt = Interrupt.from(self.code()) };
            } else {
                return Trap{ .exception = Exception.from(self.code()) };
            }
        }

        pub inline fn is_interrupt(self: Self) bool {
            return (self.bits >> nbit) == 1;
        }

        pub inline fn is_exception(self: Self) bool {
            return !self.is_interrupt();
        }
    };

    pub const Trap = union(enum) {
        interrupt: Interrupt,
        exception: Exception,
    };

    pub const Interrupt = enum {
        UserSoft,
        VirtualSupervisorSoft,
        SupervisorSoft,
        UserTimer,
        VirtualSupervisorTimer,
        SupervisorTimer,
        UserExternal,
        VirtualSupervisorExternal,
        SupervisorExternal,
        Unknown,

        const Self = @This();

        pub inline fn from(nr: usize) Self {
            return switch (nr) {
                0 => Interrupt.UserSoft,
                1 => Interrupt.SupervisorSoft,
                2 => Interrupt.VirtualSupervisorSoft,
                4 => Interrupt.UserTimer,
                5 => Interrupt.SupervisorTimer,
                6 => Interrupt.VirtualSupervisorTimer,
                8 => Interrupt.UserExternal,
                9 => Interrupt.SupervisorExternal,
                10 => Interrupt.VirtualSupervisorExternal,
                else => Interrupt.Unknown,
            };
        }
    };

    pub const Exception = enum {
        InstructionMisaligned,
        InstructionFault,
        IllegalInstruction,
        Breakpoint,
        LoadFault,
        StoreMisaligned,
        StoreFault,
        UserEnvCall,
        VirtualSupervisorEnvCall,
        InstructionPageFault,
        LoadPageFault,
        StorePageFault,
        InstructionGuestPageFault,
        LoadGuestPageFault,
        VirtualInstruction,
        StoreGuestPageFault,
        Unknown,

        const Self = @This();

        pub inline fn from(nr: usize) Self {
            return switch (nr) {
                0 => Exception.InstructionMisaligned,
                1 => Exception.InstructionFault,
                2 => Exception.IllegalInstruction,
                3 => Exception.Breakpoint,
                5 => Exception.LoadFault,
                6 => Exception.StoreMisaligned,
                7 => Exception.StoreFault,
                8 => Exception.UserEnvCall,
                12 => Exception.InstructionPageFault,
                13 => Exception.LoadPageFault,
                15 => Exception.StorePageFault,
                else => Exception.Unknown,
            };
        }
    };
};

pub const satp = struct {
    pub const Mode = enum(u8) {
        Bare = 0,
        Sv39 = 8,
        Sv48 = 9,
        Sv57 = 10,
        Sv64 = 11,
    };

    pub inline fn write(bits: usize) void {
        asm volatile (
            \\ csrw satp, %[bits]
            :
            : [bits] "r" (bits),
        );
    }

    pub const Satp = struct {
        bits: usize,

        const Self = @This();
        pub inline fn read() Self {
            var bits: usize = asm (
                \\ csrr %[ret], satp
                : [ret] "=r" (-> usize),
            );

            return Satp { .bits = bits };
        }

        pub inline fn write_to(self: Self) void {
            write(self.bits);
        }

        pub fn mode(self: Self) Mode {
            return switch (bits_from(self.bits, 60, 64)) {
                0 => Mode.Bare,
                8 => Mode.Sv39,
                9 => Mode.Sv48,
                10 => Mode.Sv57,
                11 => Mode.Sv64,
                else => unreachable,
            };
        }

        pub fn asid(self: Self) usize {
            return bits_from(self.bits, 44, 60);
        }

        pub fn ppn(self: Self) usize {
            return bits_from(self.bits, 0, 44);
        }
    };
};

pub const stval = struct {
    pub inline fn read() usize {
        return asm volatile (
            \\ csrr %[ret], stval
            : [ret] "=r" (-> usize),
        );
    }
};

pub const time = struct {
    pub inline fn read() usize {
        return asm volatile (
            \\ rdtime %[ret]
            : [ret] "=r" (-> usize),
        );
    }
};

pub const sie = struct {
    pub fn set_timer() void {
        asm volatile (
            \\ csrs sie, %[bits]
            :
            : [bits] "r" (1<<5),
        );
    }

    pub fn clear_timer() void {
        asm volatile (
            \\ csrc sie, %[bits]
            :
            : [bits] "r" (1<<5),
        );
    }
};
