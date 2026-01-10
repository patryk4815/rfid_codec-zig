const std = @import("std");

pub const BPLCConfig = struct {
    gap: u8,
    zero: u8,
    one: u8,
    eof: u8,
};

// Binary Pulse Length Coding
pub const BPLC = struct {
    config: BPLCConfig,

    pub fn encode(self: BPLC, bits: []const u1, out_samples: []u1) usize {
        var idx: usize = 0;

        for (bits) |bit| {
            const total: u8 = switch (bit) {
                0 => self.config.zero,
                1 => self.config.one,
            };

            const ones = self.config.gap;
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
        if (self.config.eof > 0) {
            const total: u8 = self.config.eof;
            const ones = self.config.gap;
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

    pub fn encodeStruct(self: BPLC, comptime T: type, data: T, out_samples: []u1) usize {
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
        return self.encode(buf[0..], out_samples);
    }
};
