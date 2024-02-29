const virtio = @import("virtio.zig");

pub const VirtioDisk = struct {
    /// a set (not a ring) of DMA descriptors, with which the
    /// driver tells the device where to read and write individual
    /// disk operations. there are NUM descriptors.
    /// most commands consist of a "chain" (a linked list) of a couple of
    /// these descriptors.
    desc: *virtio.VirtqDesc,
    /// a ring in which the driver writes descriptor numbers
    /// that the driver would like the device to process.  it only
    /// includes the head descriptor of each chain. the ring has
    /// NUM elements.
    avail: *virtio.VirtqAvail,
    used: *virtio.VirtqUsed,


};
