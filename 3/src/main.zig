pub const std_options: std.Options = .{
    .enable_segfault_handler = true,
    .log_level = .info,
};

/// Combination Build Module and name
const std = @import("std");
const Data = @import("data");
const utils = @import("utils");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const GPA = std.heap.GeneralPurposeAllocator;
const ns2sec = utils.ns2sec;

const log = std.log.scoped(.AoC);
const print = std.debug.print;

pub fn main() !void {
    var gpa = GPA(.{}){};
    defer _ = gpa.deinit(); // Performs leak checking
    const alloc = gpa.allocator();

    var T = try std.time.Timer.start();

    const res1 = try part1(Data.input, alloc);
    log.info("Part 1 answer: << {d} >>", .{res1});
    log.info("Part 1 took {d:.6}s", .{ns2sec(T.lap())});

    const res2 = try part2(Data.input, alloc);
    log.info("Part 2 answer: << {d} >>", .{res2});
    log.info("Part 2 took {d:.6}s", .{ns2sec(T.lap())});
}

// ------------ Tests ------------

test "part1 test input" {
    std.testing.log_level = .debug;

    log.warn(" -- Running Tests --", .{});

    const answer: usize = 357;

    const alloc = std.testing.allocator;
    const res = try part1(Data.test_input, alloc);
    log.warn("[Test] Part 1: {d}", .{res});
    try std.testing.expect(res == answer);
}

test "part2 test input" {
    std.testing.log_level = .debug;

    const answer: usize = 3121910778619;

    const alloc = std.testing.allocator;
    const res = try part2(Data.test_input, alloc);
    log.warn("[Test] Part 2: {d}", .{res});
    try std.testing.expect(res == answer);
}

// ------------ Part 1 Solution ------------

pub fn part1(input: []const u8, alloc: Allocator) !usize {
    _ = alloc;
    var sum: usize = 0;
    var lines = utils.lines(input);
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        log.debug("parsing line: {s}", .{line});
        const result = largestBankCount(line, 2);
        const bank_value = cellsToNumber(&result);
        sum += bank_value;
        log.debug("new sum: {d}", .{sum});
    }

    return sum;
}

// ------------ Part 2 Solution ------------

pub fn part2(input: []const u8, alloc: Allocator) !usize {
    _ = alloc;
    var sum: usize = 0;
    var lines = utils.lines(input);

    while (lines.next()) |line| {
        if (line.len == 0) continue;
        log.debug("parsing line: {s}", .{line});
        const result = largestBankCount(line, 12);
        const bank_value = cellsToNumber(&result);
        sum += bank_value;
        log.debug("new sum: {d}", .{sum});
    }
    return sum;
}

// ------------ Common Functions ------------

const Cell = struct {
    value: usize,
    index: usize,
    found: bool,

    fn init() Cell {
        return .{ .value = 0, .index = 0, .found = false };
    }

    fn update(self: *Cell, value: usize, index: usize) void {
        self.value = value;
        self.index = index;
        self.found = true;
    }
};

fn cellsToNumber(cells: []const Cell) usize {
    var result: usize = 0;
    for (cells) |cell| {
        result = result * 10 + cell.value;
    }
    return result;
}

fn largestBankCount(line: []const u8, cell_count: comptime_int) [cell_count]Cell {
    log.debug("Target battery size: {d}", .{cell_count});

    var cells: [cell_count]Cell = undefined;

    var search_start: usize = 0;
    for (0..cell_count) |position| {
        const remaining_cells = cell_count - position;
        const search_end = line.len - remaining_cells + 1;

        const best_cell = findBestDigitInRange(line, search_start, search_end);
        cells[position] = best_cell;
        search_start = best_cell.index + 1;
    }

    return cells;
}

fn findBestDigitInRange(line: []const u8, start: usize, end: usize) Cell {
    var best_cell = Cell.init();
    for (start..end) |index| {
        // voodoo trickery to convert ascii to integer
        const digit = line[index] - '0';
        if (digit > best_cell.value) {
            best_cell.update(digit, index);
        }
    }
    return best_cell;
}
