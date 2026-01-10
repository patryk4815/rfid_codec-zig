const std = @import("std");

// Binary Pulse Length Coding
pub const Config = struct {
    gap: u8,
    zero: u8,
    one: u8,
    eof: u8,
};

pub fn encode(config: Config, bits: []const u1, out_samples: []u1) usize {
    var idx: usize = 0;

    for (bits) |bit| {
        const total: u8 = switch (bit) {
            0 => config.zero,
            1 => config.one,
        };

        const ones = config.gap;
        const zeros = total - ones;

        if (idx + total > out_samples.len) @panic("Output buffer too small");

        for (0..ones) |_| {
            out_samples[idx] = 1;
            idx += 1;
        }
        for (0..zeros) |_| {
            out_samples[idx] = 0;
            idx += 1;
        }
    }

    // EOF
    if (config.eof > 0) {
        const total: u8 = config.eof;
        const ones = config.gap;
        const zeros = total - ones;

        if (idx + total > out_samples.len) @panic("Output buffer too small");

        for (0..ones) |_| {
            out_samples[idx] = 1;
            idx += 1;
        }
        for (0..zeros) |_| {
            out_samples[idx] = 0;
            idx += 1;
        }
    }
    return idx;
}

pub fn encodeStruct(config: Config, comptime T: type, data: T, out_samples: []u1) usize {
    const bits = @bitSizeOf(T);
    const IntT = std.meta.Int(.unsigned, bits);
    const value: IntT = @bitCast(data);
    comptime {
        if (bits > 64) {
            @compileError("bits too big?");
        }
    }

    var buf: [bits]u1 = @splat(0);
    for (0..bits) |i| {
        // TODO: bug? when bits is too big?
        buf[i] = @truncate((value >> @truncate(bits-1-i)) & 1);
    }
    // emp_data <<= 1;
    // temp_data |= @truncate((value >> (bits-1-i)) & 1);//
    return encode(config,buf[0..], out_samples);
}
