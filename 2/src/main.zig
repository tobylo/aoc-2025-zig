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

    const answer: usize = 1227775554;

    const alloc = std.testing.allocator;
    const res = try part1(Data.test_input, alloc);
    log.warn("[Test] Part 1: {d}", .{res});
    try std.testing.expect(res == answer);
}

test "part2 test input" {
    std.testing.log_level = .debug;

    const answer: usize = 4174379265;

    const alloc = std.testing.allocator;
    const res = try part2(Data.test_input, alloc);
    log.warn("[Test] Part 2: {d}", .{res});
    try std.testing.expect(res == answer);
}

// ------------ Part 1 Solution ------------

pub fn part1(input: []const u8, alloc: Allocator) !usize {
    var result: usize = 0;
    var lines = utils.lines(input);
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var ranges = utils.tokenize(line, ",");
        while (ranges.next()) |range| {
            if (range.len == 0) continue;
            var values = utils.tokenize(range, "-");

            const first = try std.fmt.parseInt(usize, values.next().?, 10);
            const last = try std.fmt.parseInt(usize, values.next().?, 10);

            log.debug("range {d} - {d}", .{ first, last });

            for (first..last + 1) |value| {
                log.debug("to parse: {d}", .{value});
                if (isFakeValuePartOne(value, alloc)) {
                    result += value;
                }
            }
        }
    }

    return result;
}

// ------------ Part 2 Solution ------------

pub fn part2(input: []const u8, alloc: Allocator) !usize {
    _ = alloc;

    var sum: usize = 0;
    var lines = utils.lines(input);
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var ranges = utils.tokenize(line, ",");
        while (ranges.next()) |range| {
            if (range.len == 0) continue;
            var values = utils.tokenize(range, "-");

            const first = try std.fmt.parseInt(usize, values.next().?, 10);
            const last = try std.fmt.parseInt(usize, values.next().?, 10);

            log.debug("range {d} - {d}", .{ first, last });

            for (first..last + 1) |value| {
                log.debug("to parse: {d}", .{value});
                if (isFakeValue(value)) {
                    sum += value;
                }
            }
        }
    }
    return sum;
}

// ------------ Common Functions ------------
fn isFakeValuePartOne(value: usize, alloc: Allocator) bool {
    _ = alloc;

    var buf: [64]u8 = undefined;
    const stringified = std.fmt.bufPrint(&buf, "{d}", .{value}) catch unreachable;

    if (stringified.len % 2 != 0) return false;

    const mid = stringified.len / 2;
    const first_half = stringified[0..mid];
    const second_half = stringified[mid..];
    log.debug("comparing {s} agaings {s}", .{ first_half, second_half });
    return std.mem.eql(u8, first_half, second_half);
}

fn isFakeValue(value: usize) bool {
    var buf: [32]u8 = undefined;
    const stringified = std.fmt.bufPrint(&buf, "{d}", .{value}) catch unreachable;
    for (1..stringified.len / 2 + 1) |pattern_len| {
        if (@mod(stringified.len, pattern_len) != 0) continue;

        var pattern_iterator = std.mem.window(u8, stringified, pattern_len, pattern_len);
        const target_pattern = pattern_iterator.next().?;

        log.debug("pattern target: {s}", .{target_pattern});
        var pattern_matched = true;
        while (pattern_iterator.next()) |next| {
            log.debug("comparing {s} against {s}", .{ target_pattern, next });
            if (!std.mem.eql(u8, next, target_pattern)) {
                pattern_matched = false;
                break;
            }
        }
        if (pattern_matched) {
            log.debug("pattern {s} matched for {d}", .{ target_pattern, value });
            return true;
        }
    }

    return false;
}
