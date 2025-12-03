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
    var largest: [1]u8 = undefined;
    var second_largest: [1]u8 = undefined;
    while (lines.next()) |line| {
        // Process each line here
        log.debug("parsing line: {s}", .{line});
        const result = largestBank(line);
        log.debug("result: {any}", .{result});
        const first = std.fmt.bufPrint(&largest, "{d}", .{result.largest.value}) catch "0";
        const second = std.fmt.bufPrint(&second_largest, "{d}", .{result.secondLargest.value}) catch "0";

        const value: [2]u8 = [2]u8{ first[0], second[0] };
        sum += std.fmt.parseInt(usize, &value, 10) catch 0;
        log.debug("new sum: {d}", .{sum});
    }

    return sum;
}

// ------------ Part 2 Solution ------------

pub fn part2(input: []const u8, alloc: Allocator) !usize {
    var sum: usize = 0;
    var lines = utils.lines(input);
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var string_value: [12]u8 = undefined;
        log.debug("parsing line: {s}", .{line});
        const result = largestBankCount2(line, 12);
        log.debug("result: {any}", .{result});

        var list: std.ArrayList(Cell) = .empty;
        defer list.deinit(alloc);

        for (result) |cell| {
            try list.append(alloc, cell);
        }
        std.mem.sort(Cell, list.items, {}, cmpByCellIndex);

        var buf: [1]u8 = undefined;
        for (list.items, 0..) |cell, i| {
            log.debug("building value: [{d}]={d} (found at {d})", .{ i, cell.value, cell.index });
            const char_value = std.fmt.bufPrint(&buf, "{d}", .{cell.value}) catch "0";
            string_value[i] = char_value[0];
        }
        log.debug("value as string: {s}", .{string_value});
        sum += std.fmt.parseInt(usize, &string_value, 10) catch 0;
        log.debug("new sum: {d}", .{sum});
    }
    return sum;
}

// ------------ Common Functions ------------

fn cmpByCellIndex(context: void, a: Cell, b: Cell) bool {
    _ = context;
    return a.index < b.index;
}

const Cell = struct {
    value: usize,
    index: usize,
    found: bool,

    fn init() Cell {
        return .{ .value = 0, .index = undefined, .found = false };
    }

    fn update(self: *Cell, value: usize, index: usize) void {
        self.value = value;
        self.index = index;
        self.found = true;
    }
};
fn largestBank(line: []const u8) struct { largest: Cell, secondLargest: Cell } {
    var largest: Cell = Cell.init();
    var secondLargest: Cell = Cell.init();
    var index: usize = 0;
    var iterator = std.mem.window(u8, line, 1, 1);
    while (iterator.next()) |slice| {
        log.debug("slice: {s}", .{slice});
        const value = std.fmt.parseInt(usize, slice, 10) catch 0;
        if (value > largest.value and index != line.len - 1) {
            log.debug("new largest: {d} at index {d}", .{ value, index });
            secondLargest.value = 0;
            largest.update(value, index);
        } else if (value > secondLargest.value) {
            log.debug("new second largest: {d} at index {d}", .{ value, index });
            secondLargest.update(value, index);
        }
        index += 1;
    }

    return .{ .largest = largest, .secondLargest = secondLargest };
}

fn largestBankCount2(line: []const u8, cell_count: comptime_int) [cell_count]Cell {
    log.debug("target battery size: {d}", .{cell_count});

    var cells: [cell_count]Cell = undefined;
    for (&cells) |*cell| {
        cell.* = Cell.init();
    }

    log.debug("result array initiated!", .{});
    var target: i8 = 9;
    while (target >= 0) {
        log.debug("looking for target: {d}", .{target});
        var buf: [1]u8 = undefined;
        const char = std.fmt.bufPrint(&buf, "{d}", .{target}) catch unreachable;
        log.debug("target char: {s}", .{char});

        var source_index: isize = @intCast(line.len - 1);
        while (source_index >= 0) : (source_index -= 1) {
            log.debug("looking at {c} at index {d}", .{ line[@intCast(source_index)], source_index });
            if (char[0] == line[@intCast(source_index)]) {
                var cell_index: isize = @intCast(cell_count - 1);
                while (cell_index >= 0) : (cell_index -= 1) {
                    const cell = &cells[@intCast(cell_index)];
                    if (cell.value < target) {
                        log.debug("bank value {d} at index {d} is larger than cell index {d} which has value {d}", .{ target, source_index, cell_index, cell.value });
                        cell.update(@intCast(target), @intCast(source_index));
                        if (foundCount(&cells) == cell_count) {
                            log.debug("found all cells!", .{});
                            return cells;
                        }
                        break;
                    }
                }
            }
        }
        target -= 1;
    }

    return cells;
}

fn largestBankCount(line: []const u8, cell_count: comptime_int) [cell_count]Cell {
    log.debug("target battery size: {d}", .{cell_count});

    var cells: [cell_count]Cell = undefined;
    for (&cells) |*cell| {
        cell.* = Cell.init();
    }

    std.mem.reverse(u8, line);

    log.debug("result array initiated!", .{});
    var target: i8 = 9;
    var iterator = std.mem.window(u8, line, 1, 1);
    while (target >= 0) {
        log.debug("looking for target: {d}", .{target});
        iterator.reset();
        var bank_index: usize = 0;
        var buf: [1]u8 = undefined;
        const char = std.fmt.bufPrint(&buf, "{d}", .{target}) catch unreachable;
        log.debug("target char: {s}", .{char});
        while (iterator.next()) |slice| {
            log.debug("looking at {s} at index {d}", .{ slice, bank_index });
            if (std.mem.eql(u8, char, slice)) {
                var cell_index: isize = @intCast(cell_count - 1);
                while (cell_index >= 0) : (cell_index -= 1) {
                    const cell = &cells[@intCast(cell_index)];
                    if (cell.value < target and cell.index > bank_index) {
                        log.debug("bank value {d} at index {d} is larger than cell index {d} which has value {d}", .{ target, bank_index, cell_index, cell.value });
                        cell.update(@intCast(target), bank_index);
                        if (foundCount(&cells) == cell_count) {
                            log.debug("found all cells!", .{});
                            return cells;
                        }
                        break;
                    }
                }
            }
            bank_index += 1;
        }
        target -= 1;
    }

    return cells;
}

fn foundCount(cells: []Cell) usize {
    var count: usize = 0;
    for (cells) |cell| {
        if (cell.found) {
            count += 1;
        }
    }
    return count;
}
