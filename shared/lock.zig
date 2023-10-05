const atomic = @import("std").atomic;

pub const SpinLock = struct {
    locked: atomic.Atomic(bool),

    const Self = @This();

    const UNLOCKED: bool = false;
    const LOCKED: bool = true;

    pub fn init() Self {
        return Self{
            .locked = atomic.Atomic(bool).init(UNLOCKED),
        };
    }

    pub fn acquire(self: *Self) void {
        while (self.locked.compareAndSwap(
            UNLOCKED,
            LOCKED, 
            atomic.Ordering.Acquire, 
            atomic.Ordering.Monotonic)) |_| {
            while (self.locked.load(atomic.Ordering.Monotonic) == LOCKED) {
                // spin
            }
        }
    }

    pub fn release(self: *Self) void {
        self.locked.store(UNLOCKED, atomic.Ordering.Release);
    }

    pub fn holding(self: *Self) bool {
        return self.locked.load(atomic.Ordering.Unordered);
    }
};
