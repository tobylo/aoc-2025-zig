pub const std_options: std.Options = .{
    .enable_segfault_handler = true,
    .log_level = .info,
};

/// Combination Build Module and name
const std = @import("std");
const Data = @import("data");
const utils = @import("utils");
const set = @import("ziglangSet");

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

    const res2 = try part2_stack_allocations(Data.input);
    log.info("Part 2 answer: << {d} >>", .{res2});
    log.info("Part 2 took {d:.6}s", .{ns2sec(T.lap())});

    _ = try part2_less_allocations(Data.input, alloc);
    log.info("Part 2 with less allocations took {d:.6}s", .{ns2sec(T.lap())});

    _ = try part2_stack_allocations(Data.input);
    log.info("Part 2 with stack allocations took {d:.6}s", .{ns2sec(T.lap())});

    _ = try part2_stack_allocations_optimized(Data.input);
    log.info("Part 2 with stack allocations optimized took {d:.6}s", .{ns2sec(T.lap())});
}

// ------------ Tests ------------

test "part1 test input" {
    std.testing.log_level = .debug;

    log.warn(" -- Running Tests --", .{});

    const answer: usize = 3;

    const alloc = std.testing.allocator;
    const res = try part1(Data.test_input, alloc);
    log.warn("[Test] Part 1: {d}", .{res});
    try std.testing.expect(res == answer);
}

test "part2 test input" {
    std.testing.log_level = .debug;

    const answer: usize = 14;

    _ = std.testing.allocator;
    const res = try part2_stack_allocations(Data.test_input);
    log.warn("[Test] Part 2: {d}", .{res});
    try std.testing.expect(res == answer);
}

// ------------ Part 1 Solution ------------

pub fn part1(input: []const u8, alloc: Allocator) !usize {
    var parts = std.mem.splitSequence(u8, input, "\n\n");
    const range_lines = parts.next().?;

    var ranges = try getRanges(range_lines, alloc);
    defer ranges.deinit(alloc);

    const id_lines = parts.next().?;
    var ids = try getIds(id_lines, alloc);
    defer ids.deinit(alloc);

    log.debug("Ranges count: {d} | IDs count: {d}", .{ ranges.items.len, ids.items.len });

    var valid_count: usize = 0;
    for (ids.items) |id| {
        var found = false;
        for (ranges.items) |range| {
            if (range.contains(id)) {
                log.debug("id {d} is contained in range {d} - {d}", .{ id, range.start, range.end });
                valid_count += 1;
                found = true;
                break;
            }
        }
    }

    return valid_count;
}

// ------------ Part 2 Solution ------------

pub fn part2_stack_allocations_optimized(input: []const u8) !usize {
    var parts = std.mem.splitSequence(u8, input, "\n\n");
    const range_lines = parts.next().?;

    var T = try std.time.Timer.start();
    const sum = try getRangesStackSumOptimized(range_lines);
    log.info("Part 2 with stack allocations optimized (excl parsing) took {d:.6}ns", .{T.lap()});
    return sum;
}

pub fn part2_stack_allocations(input: []const u8) !usize {
    var parts = std.mem.splitSequence(u8, input, "\n\n");
    const range_lines = parts.next().?;

    var T = try std.time.Timer.start();
    const sum = try getRangesStackSum(range_lines);
    log.info("Part 2 with stack allocations (excl parsing) took {d:.6}ns", .{T.lap()});
    return sum;
}

pub fn part2_less_allocations(input: []const u8, alloc: Allocator) !usize {
    var parts = std.mem.splitSequence(u8, input, "\n\n");
    const range_lines = parts.next().?;

    var T = try std.time.Timer.start();
    const res = try getRangeSum(range_lines, alloc);

    log.info("Part 2 with less allocations (excl parsing) took {d:.6}ns", .{T.lap()});
    return res;
}

pub fn part2(input: []const u8, alloc: Allocator) !usize {
    var parts = std.mem.splitSequence(u8, input, "\n\n");
    const range_lines = parts.next().?;

    var ranges = try getNonOverlappingRanges(range_lines, alloc);
    defer ranges.deinit(alloc);

    var unique_ids_count: usize = 0;
    for (ranges.items) |range| {
        log.debug("range: {any}", .{range});
        unique_ids_count += range.end - range.start + 1;
    }
    log.debug("unique ids: {d}", .{unique_ids_count});
    return unique_ids_count;
}

// ------------ Common Functions ------------

fn getRangeSum(input: []const u8, alloc: Allocator) !usize {
    var ranges = try getRanges(input, alloc);
    defer ranges.deinit(alloc);

    std.mem.sort(Range, ranges.items, {}, struct {
        fn lessThan(_: void, a: Range, b: Range) bool {
            return a.start < b.start;
        }
    }.lessThan);

    var sum: usize = 0;
    var current_range = ranges.items[0];
    // if the ranges overlap, merge them
    for (ranges.items[1..]) |range| {
        if (range.start > current_range.end + 1) {
            sum += current_range.end - current_range.start + 1;
            current_range = range;
        } else {
            current_range.end = @max(current_range.end, range.end);
        }
    }
    sum += current_range.end - current_range.start + 1;
    return sum;
}

fn getRangesStackSum(input: []const u8) !usize {
    var lines = utils.lines(input);

    var ranges_buffer: [2048]Range = undefined;
    var range_count: usize = 0;

    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var parts = utils.split(line, "-");
        const start = try std.fmt.parseUnsigned(usize, parts.next().?, 10);
        const end = try std.fmt.parseUnsigned(usize, parts.next().?, 10);
        const range_item = Range.init(start, end);
        ranges_buffer[range_count] = range_item;
        range_count += 1;
    }

    std.mem.sort(Range, ranges_buffer[0..range_count], {}, struct {
        fn lessThan(_: void, a: Range, b: Range) bool {
            return a.start < b.start;
        }
    }.lessThan);

    var sum: usize = 0;
    var current_range = ranges_buffer[0];
    // if the ranges overlap, merge them
    for (ranges_buffer[1..range_count]) |range| {
        if (range.start > current_range.end + 1) {
            sum += current_range.end - current_range.start + 1;
            current_range = range;
        } else {
            current_range.end = @max(current_range.end, range.end);
        }
    }
    sum += current_range.end - current_range.start + 1;
    return sum;
}

fn getRangesStackSumOptimized(input: []const u8) !usize {
    var ranges_buffer: [2048]Range = undefined;
    var range_count: usize = 0;

    var i: usize = 0;
    while (i < input.len) {
        // Skip whitespace/newlines
        while (i < input.len and (input[i] == '\n' or input[i] == '\r' or input[i] == ' ')) : (i += 1) {}
        if (i >= input.len) break;

        // Parse start manually
        var start: usize = 0;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
            start = start * 10 + (input[i] - '0');
        }

        i += 1; // Skip '-'

        // Parse end manually
        var end: usize = 0;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
            end = end * 10 + (input[i] - '0');
        }

        ranges_buffer[range_count] = .{ .start = start, .end = end };
        range_count += 1;
    }

    // ... rest of the function stays the same
    std.mem.sort(Range, ranges_buffer[0..range_count], {}, struct {
        fn lessThan(_: void, a: Range, b: Range) bool {
            return a.start < b.start;
        }
    }.lessThan);

    var sum: usize = 0;
    var current_range = ranges_buffer[0];
    for (ranges_buffer[1..range_count]) |range| {
        if (range.start > current_range.end + 1) {
            sum += current_range.end - current_range.start + 1;
            current_range = range;
        } else {
            current_range.end = @max(current_range.end, range.end);
        }
    }
    sum += current_range.end - current_range.start + 1;
    return sum;
}

fn getNonOverlappingRanges(input: []const u8, alloc: Allocator) !std.ArrayList(Range) {
    var ranges = try getRanges(input, alloc);
    defer ranges.deinit(alloc);

    std.mem.sort(Range, ranges.items, {}, struct {
        fn lessThan(_: void, a: Range, b: Range) bool {
            return a.start < b.start;
        }
    }.lessThan);

    var non_overlapping_ranges = try std.ArrayList(Range).initCapacity(alloc, ranges.items.len);
    var current_range = ranges.items[0];

    // if the ranges overlap, merge them
    for (ranges.items[1..]) |range| {
        if (range.start > current_range.end + 1) {
            try non_overlapping_ranges.append(alloc, current_range);
            current_range = range;
        } else {
            current_range.end = @max(current_range.end, range.end);
        }
    }
    try non_overlapping_ranges.append(alloc, current_range);

    return non_overlapping_ranges;
}

fn getRanges(input: []const u8, alloc: Allocator) !std.ArrayList(Range) {
    var ranges = try std.ArrayList(Range).initCapacity(alloc, input.len);

    var lines = utils.lines(input);
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var parts = utils.split(line, "-");
        const start = try std.fmt.parseUnsigned(usize, parts.next().?, 10);
        const end = try std.fmt.parseUnsigned(usize, parts.next().?, 10);
        const range_item = Range.init(start, end);
        try ranges.append(alloc, range_item);
        log.debug("range: {any}", .{range_item});
    }

    return ranges;
}

fn getIds(input: []const u8, alloc: Allocator) !std.ArrayList(usize) {
    var ids = try std.ArrayList(usize).initCapacity(alloc, input.len);
    var id_iter = utils.lines(input);
    while (id_iter.next()) |id| {
        if (id.len == 0) continue;
        const id_num = try std.fmt.parseInt(usize, id, 10);
        log.debug("adding id: {d}", .{id_num});
        try ids.append(alloc, id_num);
    }

    return ids;
}

const Range = struct {
    start: usize,
    end: usize,

    pub fn init(start: usize, end: usize) Range {
        return Range{ .start = start, .end = end };
    }

    pub fn contains(self: Range, value: usize) bool {
        return self.start <= value and self.end >= value;
    }

    pub fn overlaps(self: Range, other: Range) bool {
        return self.start <= other.end and self.end >= other.start;
    }
};
