const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const exe = b.addExecutable("hex2bin", "src/hex2bin.zig");
    exe.setBuildMode(b.standardReleaseOptions());
    b.default_step.dependOn(&exe.step);
}
