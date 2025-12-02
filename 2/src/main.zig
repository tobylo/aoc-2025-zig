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
    var invalidIds: std.ArrayList(usize) = .empty;
    defer invalidIds.deinit(alloc);

    var lines = utils.lines(input);
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var ranges = utils.tokenize(line, ",");
        while (ranges.next()) |range| {
            if (range.len == 0) continue;
            var values = utils.tokenize(range, "-");

            const first = try std.fmt.parseInt(usize, values.next().?, 10);
            const last = try std.fmt.parseInt(usize, values.next().?, 10);

            //log.debug("range {d} - {d}", .{ first, last });

            for (first..last + 1) |value| {
                //log.debug("to parse: {d}", .{value});
                if (isFakeValuePartOne(value, alloc)) {
                    try invalidIds.append(alloc, value);
                }
            }
        }
    }

    var sum: usize = 0;
    while (invalidIds.pop()) |invalid| {
        log.debug("invalid id: {d}", .{invalid});
        sum += invalid;
    }
    return sum;
}

// ------------ Part 2 Solution ------------

pub fn part2(input: []const u8, alloc: Allocator) !usize {
    var invalidIds: std.ArrayList(usize) = .empty;
    defer invalidIds.deinit(alloc);

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
                //log.debug("to parse: {d}", .{value});
                if (isFakeValue(value, alloc)) {
                    try invalidIds.append(alloc, value);
                }
            }
        }
    }

    var sum: usize = 0;
    while (invalidIds.pop()) |invalid| {
        log.debug("invalid id: {d}", .{invalid});
        sum += invalid;
    }
    return sum;
}

// ------------ Common Functions ------------
fn isFakeValuePartOne(value: usize, alloc: Allocator) bool {
    const stringified = std.fmt.allocPrint(alloc, "{d}", .{value}) catch unreachable;
    defer alloc.free(stringified);

    const first_half = stringified[0 .. stringified.len / 2];
    const second_half = stringified[(stringified.len / 2)..];
    log.debug("comparing {s} agaings {s}", .{ first_half, second_half });
    return std.mem.eql(u8, first_half, second_half);
}

fn isFakeValue(value: usize, alloc: Allocator) bool {
    const stringified = std.fmt.allocPrint(alloc, "{d}", .{value}) catch unreachable;
    defer alloc.free(stringified);
    for (0..stringified.len / 2) |i| {
        var iterator = std.mem.window(u8, stringified, i + 1, i + 1);
        var pattern_matched = true;
        const pattern = iterator.next().?;
        if (@mod(stringified.len, pattern.len) != 0) continue;
        //log.debug("pattern target: {s}", .{pattern});
        while (iterator.next()) |next| {
            // log.debug("comparing {s} against {s}", .{ pattern, next });
            if (std.mem.eql(u8, next, pattern) == false) {
                pattern_matched = false;
                break;
            }
        }
        if (pattern_matched) {
            log.debug("pattern {s} matched for {d}", .{ pattern, value });
            return true;
        }
    }

    return false;
}
