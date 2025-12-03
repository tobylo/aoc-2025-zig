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

const Result = struct {
    batteries: usize,
    jolt: usize,
};

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

    const answer: usize = 0;

    const alloc = std.testing.allocator;
    const res = try part1(Data.test_input, alloc);
    log.warn("[Test] Part 1: {d}", .{res});
    try std.testing.expect(res == answer);
}

test "part2 test input" {
    std.testing.log_level = .debug;

    const answer: usize = 0;

    const alloc = std.testing.allocator;
    const res = try part2(Data.test_input, alloc);
    log.warn("[Test] Part 2: {d}", .{res});
    try std.testing.expect(res == answer);
}

// ------------ Part 1 Solution ------------

pub fn part1(input: []const u8, alloc: Allocator) !usize {
    _ = alloc;

    var lines = utils.lines(input);
    while (lines.next()) |line| {
        // Process each line here
    }

    return 0;
}

// ------------ Part 2 Solution ------------

pub fn part2(input: []const u8, alloc: Allocator) !usize {
    _ = alloc;
    _ = input;
    return 0;
}

// ------------ Common Functions ------------
const Cell = struct {
    value: usize,
    index: usize,
};
fn largestBank(line: []const u8) struct { largest: Cell, secondLargest: Cell } {
    var largest: Cell = .{ .value = 0, .index = 0 };
    var secondLargest: Cell = .{ .value = 0, .index = 0 };
    var index = 0;
    var iterator = std.mem.window(u8, line, 1, 1);
    while (iterator.next()) |window| {
        const value = std.fmt.parseInt(usize, window, 10) catch 0;
        if (value > largest.value and index != line.len - 1) {
            secondLargest = largest;
            largest = .{ .value = value, .index = index };
        } else if (value > secondLargest.value) {
            secondLargest = .{ .value = value, .index = index };
        }
        index += 1;
    }

    return .{ .largest = largest, .secondLargest = secondLargest };
}
