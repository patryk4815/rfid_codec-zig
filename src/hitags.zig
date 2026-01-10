const std = @import("std");

const CRC_PRESET = 0xFF;
const CRC_POLYNOM = 0x1D;
fn crcUpdate2(crc: u8, data: u8, data_width: u3, poly: u8) u8 {
    var new_crc = crc;
    new_crc ^= data << (7 - data_width);

    for (0..@as(u8, data_width)+1) |_| {
        if ((new_crc & 0x80) != 0) {
            new_crc = (new_crc << 1) ^ poly;
        } else {
            new_crc <<= 1;
        }
    }

    return new_crc;
}

pub fn crc8(comptime T: type, value: T) u8 {
    var crc_value: u8 = CRC_PRESET;
    var temp_data: u8 = 0;
    var n: u8 = 0;
    const bits = @bitSizeOf(T);

    inline for (0..bits-8) |i| {
        temp_data <<= 1;
        temp_data |= @truncate((value >> (bits-1-i)) & 1);
        n += 1;

        if (n == 8) {
            crc_value = crcUpdate2(crc_value, temp_data, @truncate(n-1), CRC_POLYNOM);
            n = 0;
            temp_data = 0;
        }
    }
    if (n > 0) {
        crc_value = crcUpdate2(crc_value, temp_data, @truncate(n-1), CRC_POLYNOM);
    }
    return crc_value;
}

test "hitags crc8 test" {
    const x = crc8(u45, 0b0_0000_0010_1100_0110_1000_0000_1101_1011_0100_00000000);
    try std.testing.expectEqual(0x9E, x);

    const y = crc8(u45, 0b1_1111_0010_1100_0110_1000_0000_1101_1011_0100_00000000);
    try std.testing.expectEqual(0xC, y);

    const z = crc8(u41, 0b1_0010_1100_0110_1000_0000_1101_1011_0100_00000000);
    try std.testing.expectEqual(0xDC, z);

    const a = crc8(u40, 0b0010_1100_0110_1000_0000_1101_1011_0100_00000000);
    try std.testing.expectEqual(0x41, a);

    const Request1 = packed struct(u20) {
        Crc: u8 = 0,
        Padr: u8,
        Cmd: u4 = 0b1000,
    };
    var cmd1 = Request1{
        .Padr = 0b11110000,
    };
    cmd1.Crc = crc8(u20, @bitCast(cmd1));
    try std.testing.expectEqual(0b1000, @as(u4, @bitCast(cmd1.Cmd)));
    try std.testing.expectEqual(0b11110000, @as(u8, @bitCast(cmd1.Padr)));
    try std.testing.expectEqual(0b11111001, @as(u8, @bitCast(cmd1.Crc)));
    try std.testing.expectEqual(0b1000_11110000_11111001, @as(u20, @bitCast(cmd1)));

    const Request2 = packed struct(u45) {
        Crc: u8 = 0,
        Uid: u32,
        Cmd: u5 = 0b00000,
    };
    const cmd2 = Request2{
        .Uid = 0b10000000_11000000_11100000_11110000,
    };
    try std.testing.expectEqual(0b000000_10000000_11000000_11100000_11110000_00000000, @as(u45, @bitCast(cmd2)));
    try std.testing.expectEqual(0b000000_10000000_11000000_11100000_11110000_00000000, @as(u45, @bitCast(cmd2)));
}
