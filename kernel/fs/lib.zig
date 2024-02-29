const std = @import("std");
const virtio = @import("virtio.zig");
const console = @import("../console.zig");
const assert = @import("../assert.zig");

const VirtioDevice = virtio.VirtioDevice;

const VirtioDeviceStatus = enum(u32) {
    ACKNOWLEDGE = 1 << 0,
    DRIVER = 1 << 1,
    DRIVER_OK = 1 << 2,
    FEATURES_OK = 1 << 3,
};



pub fn init_disck() void {
    assert.assert_eq(VirtioDevice.get_magic(), std.mem.readIntLittle(u32, "virt"), @src());
    assert.assert_eq(VirtioDevice.get_version(), 2, @src());
    assert.assert_eq(VirtioDevice.get_id(), 2, @src());
    assert.assert_eq(VirtioDevice.get_vendor_id(), std.mem.readIntLittle(u32, "QEMU"), @src());

    var status: u32 = 0;
    // reset device
    VirtioDevice.set_status(status);
    // set ACKNOWLEDGE status bit
    status |= @intFromEnum(VirtioDeviceStatus.ACKNOWLEDGE);
    VirtioDevice.set_status(status);
    // set DRIVER status bit
    status |= @intFromEnum(VirtioDeviceStatus.DRIVER);
    VirtioDevice.set_status(status);

    // TODO: 重构
    // negotiate features
    var features: u32 = VirtioDevice.get_features();
    const bit: u32 = 1;
    features &= ~(bit << virtio.VIRTIO_BLK_F_RO);
    features &= ~(bit << virtio.VIRTIO_BLK_F_SCSI);
    features &= ~(bit << virtio.VIRTIO_BLK_F_CONFIG_WCE);
    features &= ~(bit << virtio.VIRTIO_BLK_F_MQ);
    features &= ~(bit << virtio.VIRTIO_F_ANY_LAYOUT);
    features &= ~(bit << virtio.VIRTIO_RING_F_EVENT_IDX);
    features &= ~(bit << virtio.VIRTIO_RING_F_INDIRECT_DESC);
    VirtioDevice.set_driver_features(features);

    // tell device that feature negotiation is complete.
    status |= @intFromEnum(VirtioDeviceStatus.FEATURES_OK);
    VirtioDevice.set_status(status);

    // re-read status to ensure FEATURES_OK is set.
    status = VirtioDevice.get_status();
    if(status & @intFromEnum(VirtioDeviceStatus.FEATURES_OK) == 0) {
        @panic("virtio disk FEATURES_OK unset");
    }

    // initialize queue 0
    VirtioDevice.set_queue_sel(0);
    // ensure queue 0 is not in use
    if (VirtioDevice.get_queue_ready() == 1) {
        @panic("virtio disk should not be ready");
    }
    // check maximum queue size
    var max: u32 = VirtioDevice.get_queue_num_max();
    if (max == 0) {
        @panic("virtio disk has no queue 0");
    } else if (max < 8) {
        @panic("virtio disk max queue too short");
    } else {
        console.logger.info("[Disk]: max queue {d}", .{max});
    }

    // allocate and zero queue memory
}
