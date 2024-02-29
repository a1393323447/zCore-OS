const std = @import("std");
const assert = @import("../assert.zig");

const VIRTIO_MMIO_MAGIC_VALUE: usize = 0x000;
const VIRTIO_MMIO_VERSION: usize = 0x004;
const VIRTIO_MMIO_DEVICE_ID: usize = 0x008;
const VIRTIO_MMIO_VENDOR_ID: usize = 0x00c;
const VIRTIO_MMIO_DEVICE_FEATURES: usize = 0x010;
const VIRTIO_MMIO_DRIVER_FEATURES: usize = 0x020;
const VIRTIO_MMIO_QUEUE_SEL: usize = 0x030;
const VIRTIO_MMIO_QUEUE_NUM_MAX: usize = 0x034;
const VIRTIO_MMIO_QUEUE_NUM: usize = 0x038;
const VIRTIO_MMIO_QUEUE_READY: usize = 0x044;
const VIRTIO_MMIO_QUEUE_NOTIFY: usize = 0x050;
const VIRTIO_MMIO_INTERRUPT_STATUS: usize = 0x060;
const VIRTIO_MMIO_INTERRUPT_ACK: usize = 0x064;
const VIRTIO_MMIO_STATUS: usize = 0x070;
const VIRTIO_MMIO_QUEUE_DESC_LOW: usize = 0x080;
const VIRTIO_MMIO_QUEUE_DESC_HIGH: usize = 0x084;
const VIRTIO_MMIO_DRIVER_DESC_LOW: usize = 0x090;
const VIRTIO_MMIO_DRIVER_DESC_HIGH: usize = 0x094;
const VIRTIO_MMIO_DEVICE_DESC_LOW: usize = 0x0a0;
const VIRTIO_MMIO_DEVICE_DESC_HIGH: usize = 0x0a4;

pub const VIRTIO_CONFIG_S_ACKNOWLEDGE: u32 = 1;
pub const VIRTIO_CONFIG_S_DRIVER: u32 = 2;
pub const VIRTIO_CONFIG_S_DRIVER_OK: u32 = 4;
pub const VIRTIO_CONFIG_S_FEATURES_OK: u32 = 8;
pub const VIRTIO_BLK_F_RO: u32 = 5;
pub const VIRTIO_BLK_F_SCSI: u32 = 7;
pub const VIRTIO_BLK_F_CONFIG_WCE: u32 = 11;
pub const VIRTIO_BLK_F_MQ: u32 = 12;
pub const VIRTIO_F_ANY_LAYOUT: u32 = 27;
pub const VIRTIO_RING_F_INDIRECT_DESC: u32 = 28;
pub const VIRTIO_RING_F_EVENT_IDX: u32 = 29;
pub const NUM: u32 = 8;

const VIRTIO0: usize = 0x10001000;
const VIRTIO_LEN: usize = 0x1000;

const VirtioDeviceRaw = struct {
    const Self = @This();
    fn mmio() []volatile u8 {
        const mmio_area: [*]volatile u8 = @ptrFromInt(VIRTIO0);
        return mmio_area[0..VIRTIO_LEN];
    }

    fn reg_ref(comptime T: type, offset: usize) *volatile T {
        return @ptrFromInt(@intFromPtr(&mmio()[offset]));
    }

    fn magic() *volatile u32 {
        return reg_ref(u32, VIRTIO_MMIO_MAGIC_VALUE);
    }

    fn version() *volatile u32 {
        return reg_ref(u32, VIRTIO_MMIO_VERSION);
    }

    fn device_id() *volatile u32 {
        return reg_ref(u32, VIRTIO_MMIO_DEVICE_ID);
    }

    fn vendor_id() *volatile u32 {
        return reg_ref(u32, VIRTIO_MMIO_VENDOR_ID);
    }

    fn device_features() *volatile u32 {
        return reg_ref(u32, VIRTIO_MMIO_DEVICE_FEATURES);
    }

    // device features sel

    fn driver_features() *volatile u32 {
        return reg_ref(u32, VIRTIO_MMIO_DRIVER_FEATURES);
    }

    // driver features sel

    fn queue_sel() *volatile u32 {
        return reg_ref(u32, VIRTIO_MMIO_QUEUE_SEL);
    }

    fn queue_num_max() *volatile u32 {
        return reg_ref(u32, VIRTIO_MMIO_QUEUE_NUM_MAX);
    }

    fn queue_num() *volatile u32 {
        return reg_ref(u32, VIRTIO_MMIO_QUEUE_NUM);
    }

    fn queue_ready() *volatile u32 {
        return reg_ref(u32, VIRTIO_MMIO_QUEUE_READY);
    }

    fn queue_notify() *volatile u32 {
        return reg_ref(u32, VIRTIO_MMIO_QUEUE_NOTIFY);
    }

    fn interrupt_status() *volatile u32 {
        return reg_ref(u32, VIRTIO_MMIO_INTERRUPT_STATUS);
    }

    fn interrupt_ack() *volatile u32 {
        return reg_ref(u32, VIRTIO_MMIO_INTERRUPT_ACK);
    }

    fn status() *volatile u32 {
        return reg_ref(u32, VIRTIO_MMIO_STATUS);
    }

    fn queue_desc_low() *volatile u32 {
        return reg_ref(u32, VIRTIO_MMIO_QUEUE_DESC_LOW);
    }

    fn queue_desc_high() *volatile u32 {
        return reg_ref(u32, VIRTIO_MMIO_QUEUE_DESC_HIGH);
    }

    fn driver_desc_low() *volatile u32 {
        return reg_ref(u32, VIRTIO_MMIO_DRIVER_DESC_LOW);
    }

    fn driver_desc_high() *volatile u32 {
        return reg_ref(u32, VIRTIO_MMIO_DRIVER_DESC_HIGH);
    }

    fn device_desc_low() *volatile u32 {
        return reg_ref(u32, VIRTIO_MMIO_DEVICE_DESC_LOW);
    }

    fn device_desc_high() *volatile u32 {
        return reg_ref(u32, VIRTIO_MMIO_DEVICE_DESC_HIGH);
    }
};

pub const VirtioDevice = struct {
    pub fn get_magic() u32 {
        return VirtioDeviceRaw.magic().*;
    }

    pub fn get_version() u32 {
        return VirtioDeviceRaw.version().*;
    }

    pub fn get_id() u32 {
        return VirtioDeviceRaw.device_id().*;
    }

    pub fn get_vendor_id() u32 {
        return VirtioDeviceRaw.vendor_id().*;
    }

    pub fn get_features() u32 {
        return VirtioDeviceRaw.device_features().*;
    }

    // device features sel

    pub fn set_driver_features(features: u32) void {
        VirtioDeviceRaw.driver_features().* = features;
    }

    // driver features sel

    pub fn set_queue_sel(queue_sel: u32) void {
        VirtioDeviceRaw.queue_sel().* = queue_sel;
    }

    pub fn get_queue_num_max() u32 {
        return VirtioDeviceRaw.queue_num_max().*;
    }

    pub fn set_queue_num(n: u32) void {
        VirtioDeviceRaw.queue_num().* = n;
    }

    pub fn get_queue_ready() u32 {
        return VirtioDeviceRaw.queue_ready().*;
    }

    pub fn set_queue_ready(ready: bool) void {
        VirtioDeviceRaw.queue_ready().* = @intFromBool(ready);
    }

    pub fn set_queue_notify(v: u32) void {
        VirtioDeviceRaw.queue_notify().* = v;
    }

    pub fn get_interrupt_status() u32 {
        return VirtioDeviceRaw.interrupt_status().*;
    }

    pub fn set_interrupt_ack(ack: u32) void {
        VirtioDeviceRaw.interrupt_ack().* = ack;
    }

    pub fn get_status() u32 {
        return VirtioDeviceRaw.status().*;
    }

    pub fn set_status(status: u32) void {
        VirtioDeviceRaw.status().* = status;
    }

    pub fn set_queue_desc_low(desc: u32) void {
        VirtioDeviceRaw.queue_desc_low().* = desc;
    }

    pub fn set_queue_desc_high(desc: u32) void {
        VirtioDeviceRaw.queue_desc_high().* = desc;
    }

    pub fn set_driver_desc_low(desc: u32) void {
        VirtioDeviceRaw.driver_desc_low().* = desc;
    }

    pub fn set_driver_desc_high(desc: u32) void {
        VirtioDeviceRaw.driver_desc_high().* = desc;
    }
};

pub const VRING_DESC_F_NEXT:  u32 = 1; // chained with another descriptor
pub const VRING_DESC_F_WRITE: u32 = 2; // device writes (vs read)
pub const VirtqDesc = extern struct {
    addr: usize,
    len: u32,
    flags: u16,
    next: u16,
};

// the (entire) avail ring, from the spec.
pub const VirtqAvail = struct  {
    flags: u16, // always zero
    idx: u16,   // driver will write ring[idx] next
    ring: [NUM]u16, // descriptor numbers of chain heads
    unused: u16,
};

// one entry in the "used" ring, with which the
// device tells the driver about completed requests.
pub const VirtqUsedElem = struct {
    id: u32,   // index of start of completed descriptor chain
    len: u32,
};

pub const VirtqUsed = struct {
    flags: u16,// always zero
    idx: u16,   // device increments when it adds a ring[] entry
    ring: [NUM]VirtqUsedElem,
};

// these are specific to virtio block devices, e.g. disks,
// described in Section 5.2 of the spec.

pub const VIRTIO_BLK_T_IN: u32 = 0;  // read
pub const VIRTIO_BLK_T_OUT: u32 = 1; // write

// the format of the first descriptor in a disk request.
// to be followed by two more descriptors containing
// the block, and a one-byte status.
pub const VirtioBlkReq = struct {
    ty: u32, // VIRTIO_BLK_T_IN or ..._OUT
    reserved: u32,
    sector: u64,
};
