const std = @import("std");

pub const Tag = struct {
    data: [10]u4,
    row_parity: [10]u1,
    col_parity: [4]u1,
};

pub fn decode(bits: []const u1) !Tag {
    if (bits.len != 64)
        return error.InvalidLength;

    // preamble
    for (bits[0..9]) |b| {
        if (b != 1)
            return error.InvalidPreamble;
    }

    // stop bit
    if (bits[63] != 0)
        return error.InvalidStopBit;

    var result: Tag = undefined;
    var pos: usize = 9;

    // dane + parzystość wierszy
    for (0..10) |i| {
        var nibble: u4 = 0;
        var parity: u1 = 0;

        for (0..4) |j| {
            _ = j;
            const bit = bits[pos];
            pos += 1;

            nibble = (nibble << 1) | bit;
            parity ^= bit;
        }

        const pbit = bits[pos];
        pos += 1;

        if (parity != pbit)
            return error.RowParityError;

        result.data[i] = nibble;
        result.row_parity[i] = pbit;
    }

    // parzystość kolumn
    for (0..4) |col| {
        var parity: u1 = 0;
        for (0..10) |row| {
            parity ^= @truncate((result.data[row] >> @truncate(3 - col)) & 1);
        }

        const pbit = bits[pos];
        pos += 1;

        if (parity != pbit)
            return error.ColumnParityError;

        result.col_parity[col] = pbit;
    }

    return result;
}

pub fn encode(em: Tag, out_bits: []u1) !void {
    if (out_bits.len != 64)
        return error.InvalidLength;

    var pos: usize = 0;

    // preamble
    for (0..9) |_| {
        out_bits[pos] = 1;
        pos += 1;
    }

    // dane + parzystość wierszy
    for (0..10) |i| {
        var parity: u1 = 0;

        for (0..4) |j| {
            const bit: u1 = @truncate((em.data[i] >> @truncate(3 - j)) & 1);
            out_bits[pos] = bit;
            pos += 1;
            parity ^= bit;
        }

        out_bits[pos] = parity;
        pos += 1;
    }

    // parzystość kolumn
    for (0..4) |col| {
        var parity: u1 = 0;
        for (0..10) |row| {
            parity ^= @truncate((em.data[row] >> @truncate(3 - col)) & 1);
        }
        out_bits[pos] = parity;
        pos += 1;
    }

    // stop bit
    out_bits[pos] = 0;
}

test "parse" {
    const tag_expected = Tag{
        .data = .{ 0x0, 0x6, 0x0, 0x0, 0x1, 0x2, 0x5, 0x9, 0xE, 0x3 },
        .row_parity = .{0, 0, 0, 0, 1, 1, 0, 0, 1, 0},
        .col_parity = .{0,1,0,0},
    };
    const bits = [_]u1{1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,1,0,1,0,1,0,1,0,1,0,0,1,0,1,1,1,0,1,0,0,1,1,0,0,1,0,0,0};
    const parsed = try decode(bits[0..]);

    try std.testing.expectEqualSlices(u4, tag_expected.data[0..], parsed.data[0..]);
    try std.testing.expectEqualSlices(u1, tag_expected.row_parity[0..], parsed.row_parity[0..]);
    try std.testing.expectEqualSlices(u1, tag_expected.col_parity[0..], parsed.col_parity[0..]);

    var out_bits: [64]u1 = @splat(0);
    try encode(tag_expected, out_bits[0..]);
    try std.testing.expectEqualSlices(u1, bits[0..], out_bits[0..]);
}

test "round-trip build & parse" {
    const tag = Tag{
        .data = .{ 0x0, 0xF, 0x0, 0x1, 0x8, 0x4, 0xA, 0x2, 0x3, 0xB },
        .row_parity = undefined,
        .col_parity = undefined,
    };

    var bits: [64]u1 = undefined;

    // Budujemy bity z tagu
    try encode(tag, bits[0..]);

    // Parsujemy z powrotem
    const parsed = try decode(bits[0..]);

    // Porównanie danych
    try std.testing.expectEqualSlices(u4, tag.data[0..], parsed.data[0..]);
}

test "invalid preamble detection" {
    var bits: [64]u1 = @splat(0);

    // wypełniamy błędnym preamble (pierwszy bit = 0)
    for (bits[0..]) |*b| b.* = 1;
    bits[0] = 0;  // błąd preamble
    bits[63] = 0; // stop bit

    const e = decode(bits[0..]);
    try std.testing.expect(e == error.InvalidPreamble);
}

test "invalid stop bit detection" {
    const tag = Tag{
        .data = .{ 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0x0 },
        .row_parity = undefined,
        .col_parity = undefined,
    };

    var bits: [64]u1 = undefined;
    try encode(tag, bits[0..]);

    bits[63] = 1; // err stop bit

    const e = decode(bits[0..]);
    try std.testing.expect(e == error.InvalidStopBit);
}

test "row parity error detection" {
    const tag = Tag{
        .data = .{ 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 0x0, 0x1, 0x2, 0x3 },
        .row_parity = undefined,
        .col_parity = undefined,
    };

    var bits: [64]u1 = undefined;
    try encode(tag, bits[0..]);

    bits[10] ^= 1; // wprowadzamy błąd w parzystości wiersza (2-gi nibble)

    const e = decode(bits[0..]);
    try std.testing.expect(e == error.RowParityError);
}

test "column parity error detection" {
    const tag = Tag{
        .data = .{ 0x1,0x2,0x3,0x4,0x5,0x6,0x7,0x8,0x9,0xA },
        .row_parity = undefined,
        .col_parity = undefined,
    };

    var bits: [64]u1 = undefined;
    try encode(tag, bits[0..]);

    bits[59] ^= 1; // wprowadzamy błąd w parzystości kolumn (pierwsza kolumna)

    const e = decode(bits[0..]);
    try std.testing.expect(e == error.ColumnParityError);
}
