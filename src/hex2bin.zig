const std = @import("std");

fn usage() !void {
    std.debug.warn("usage: INPUT.hex OUTPUT.bin\n");
    return error.Usage;
}

pub fn main() !void {
    // we never free anything
    var direct_allocator = std.heap.DirectAllocator.init();
    var arena_allocator = std.heap.ArenaAllocator.init(&direct_allocator.allocator);
    const allocator = &arena_allocator.allocator;

    var args = std.os.args();
    _ = try (args.next(allocator) ?? return usage());
    const input_path_str = try (args.next(allocator) ?? return usage());
    const output_path_str = try (args.next(allocator) ?? return usage());
    if (args.next(allocator) != null) return usage();

    var input_file = try std.os.File.openRead(allocator, input_path_str);
    defer input_file.close();

    var output_file = try std.os.File.openWrite(allocator, output_path_str);
    defer output_file.close();

    var translator: Translator = undefined;
    translator.init(input_path_str, &input_file, &output_file, allocator);
    try translator.doIt();
}

const Translator = struct {
    const Self = this;

    input_path_str: []const u8,
    input_file: &std.os.File,
    input_file_stream: std.io.FileInStream,
    buffered_input_stream: std.io.BufferedInStream(std.io.FileInStream.Error),
    input: &std.io.InStream(std.io.FileInStream.Error),

    output_file: &std.os.File,
    output_file_stream: std.io.FileOutStream,
    buffered_output_stream: std.io.BufferedOutStream(std.io.FileOutStream.Error),
    output: &std.io.OutStream(std.io.FileOutStream.Error),

    allocator: &std.mem.Allocator,
    line_number: usize,
    column_number: usize,
    output_cursor: usize,
    put_back: ?u8,

    pub fn init(self: &Self, input_path_str: []const u8, input_file: &std.os.File, output_file: &std.os.File, allocator: &std.mem.Allocator) void {
        // FIXME: return a new object once we have https://github.com/zig-lang/zig/issues/287

        self.input_path_str = input_path_str;
        self.input_file = input_file;
        self.input_file_stream = std.io.FileInStream.init(self.input_file);
        self.buffered_input_stream = std.io.BufferedInStream(std.io.FileInStream.Error).init(&self.input_file_stream.stream);
        self.input = &self.buffered_input_stream.stream;

        self.output_file = output_file;
        self.output_file_stream = std.io.FileOutStream.init(self.output_file);
        self.buffered_output_stream = std.io.BufferedOutStream(std.io.FileOutStream.Error).init(&self.output_file_stream.stream);
        self.output = &self.buffered_output_stream.stream;

        self.line_number = 1;
        self.column_number = 0;
        self.output_cursor = 0;
        self.allocator = allocator;
    }

    pub fn doIt(self: &Self) !void {
        defer self.buffered_output_stream.flush() catch {};
        var too_close_for_nibble = false;
        while (true) {
            var c = self.readByte() catch |err| switch (err) {
                error.EndOfStream => {
                    // only allow EOF at the beginning of a line
                    if (self.column_number == 0) break;
                    return err;
                },
                else => return err,
            };

            if (parseNibble(c)) |nibble| {
                // hex encoded byte
                if (too_close_for_nibble) return self.parseError();
                // next char must be the rest of the byte
                const byteValue = (u8(nibble) << 4) |
                    u8(parseNibble(self.readByte() catch '-') ?? return self.parseError());
                try self.writeByte(byteValue);
                // and then a char which is not a hex byte
                too_close_for_nibble = true;
                continue;
            }
            too_close_for_nibble = false;

            if (c == ';') {
                // comment
                while (true) {
                    c = try self.readByte();
                    if (c == '\n') break;
                }
                // then do the newline handling below

            } else if (c == ':') {
                // offset directive
                if ('0' != try self.readByte()) return self.parseError();
                if ('x' != try self.readByte()) return self.parseError();
                var claimed_offset = try self.parseU64Hex();
                if (claimed_offset != self.output_cursor) {
                    // TODO: more specific error
                    return self.parseError();
                }
                too_close_for_nibble = true;
                continue;
            }

            // some other character
            switch (c) {
                ' ' => {},
                '\n' => {
                    self.line_number += 1;
                    self.column_number = 0;
                },
                else => return self.parseError(),
            }
        }
    }

    fn readByte(self: &Self) !u8 {
        const b = if (self.put_back) |b| b: {
            self.put_back = null;
            break :b b;
        } else try self.input.readByte();
        self.column_number += 1;
        return b;
    }
    fn putBackByte(self: &Self, b: u8) void {
        std.debug.assert(self.put_back == null);
        self.put_back = b;
        self.column_number -= 1;
    }

    fn writeByte(self: &Self, b: u8) !void {
        try self.output.writeByte(b);
        self.output_cursor += 1;
    }

    fn parseError(self: &Self) !void {
        std.debug.warn("{}:{}:{}: error: parse error\n", self.input_path_str, self.line_number, self.column_number);
        return error.ParseError;
    }

    fn parseU64Hex(self: &Self) !u64 {
        var result: u64 = 0;
        var nibble_count: u32 = 0;
        while (nibble_count < 16) : (nibble_count += 1) {
            const c = try self.readByte();
            if (parseNibble(c)) |nibble| {
                result *= 16;
                result += nibble;
            } else {
                self.putBackByte(c);
                break;
            }
        }
        return result;
    }
};

fn parseNibble(c: u8) ?u4 {
    if ('0' <= c and c <= '9')
        return u4(c - '0');
    if ('A' <= c and c <= 'F')
        return u4(c - 'A') + 10;
    if ('a' <= c and c <= 'f')
        return u4(c - 'a') + 10;
    return null;
}
