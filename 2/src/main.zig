pub const std_options: std.Options = .{
    .enable_segfault_handler = true,
    .log_level = .info,
};

const std = @import("std");
const Data = @import("data");
const utils = @import("utils");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const GPA = std.heap.GeneralPurposeAllocator;
const ns2sec = utils.ns2sec;

const log = std.log.scoped(.AOC);

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

    const answer: usize = 2;

    const alloc = std.testing.allocator;
    const res = try part1(Data.test_input, alloc);
    log.warn("[Test] Part 1: {d}", .{res});
    try std.testing.expect(res == answer);
}

test "part2 test input" {
    std.testing.log_level = .debug;

    const answer: usize = 4;

    const alloc = std.testing.allocator;
    const res = try part2(Data.test_input, alloc);
    log.warn("[Test] Part 2: {d}", .{res});
    try std.testing.expect(res == answer);
}

// ------------ Part 1 Solution ------------

const Direction = enum { unknown, increasing, decreasing };

pub fn part1(input: []const u8, alloc: Allocator) !usize {
    _ = alloc;

    var lines = utils.lines(input);
    var safe_count: usize = 0;

    while (lines.next()) |line| {
        log.debug("{s}: ", .{line});
        var iter = utils.tokenize(line, " ");

        var safe = false;
        var direction: Direction = .unknown;
        var prev_val: ?usize = null;
        while (iter.next()) |str_val| {
            const val = try std.fmt.parseInt(usize, str_val, 10);
            if (prev_val == null) {
                prev_val = val;
                continue;
            }

            const prev: usize = prev_val.?;
            if (direction == .unknown) {
                direction = if (val > prev) Direction.increasing else Direction.decreasing;
            }

            if (direction == Direction.increasing and val < prev) {
                safe = false;
                log.debug("NOT SAFE (direction changed)\n", .{});
                break;
            } else if (direction == Direction.decreasing and val > prev) {
                safe = false;
                log.debug("NOT SAFE (direction changed)\n", .{});
                break;
            }

            const delta = @abs(@as(isize, @intCast(prev)) - @as(isize, @intCast(val)));
            if (delta < 1 or delta > 3) {
                safe = false;
                log.debug("NOT SAFE (delta {d} out of range)\n", .{delta});
                break;
            }
            prev_val = val;
            safe = true;
        }
        if (safe) {
            log.debug("SAFE!\n", .{});
            safe_count += 1;
        }
    }
    return safe_count;
}

// ------------ Part 2 Solution ------------

pub fn part2(input: []const u8, alloc: Allocator) !usize {
    var safe_count: usize = 0;
    var lines = utils.lines(input);
    while (lines.next()) |line| {
        const safe = isSafe(line, alloc) catch false;
        if (safe) safe_count += 1;
    }
    return safe_count;
}

// ------------ Common Functions ------------

fn isSafe(line: []const u8, alloc: Allocator) !bool {
    var list: ArrayList(usize) = .empty;
    defer list.deinit(alloc);

    var iter = utils.tokenize(line, " ");
    while (iter.next()) |token| {
        const val: usize = try std.fmt.parseInt(usize, token, 10);
        try list.append(alloc, val);
    }

    log.debug("{s}: ", .{line});
    var safe = isSafeBranch(&list, null);
    if (safe) return safe;
    for (list.items, 0..) |_, iteration| {
        log.debug("{s}: ", .{line});
        safe = isSafeBranch(&list, iteration);
        if (safe) return safe;
    }
    return false;
}

fn isSafeBranch(list: *ArrayList(usize), iteration: ?usize) bool {
    var direction = Direction.unknown;
    var prev_val: ?usize = null;
    var safe = false;

    var run: isize = -1;
    if (iteration != null) run = @intCast(iteration.?);
    log.debug("[{any}]: ", .{run});

    for (list.items, 0..) |val, i| {
        if (i == iteration) continue;

        if (prev_val == null) {
            prev_val = val;
            continue;
        }

        const prev: usize = prev_val.?;
        if (direction == .unknown) {
            direction = if (val > prev) Direction.increasing else Direction.decreasing;
        }

        if (direction == Direction.increasing and val < prev) {
            safe = false;
            log.debug("NOT SAFE (direction changed)\n", .{});
            break;
        } else if (direction == Direction.decreasing and val > prev) {
            safe = false;
            log.debug("NOT SAFE (direction changed)\n", .{});
            break;
        }

        const delta = @abs(@as(isize, @intCast(prev)) - @as(isize, @intCast(val)));
        if (delta < 1 or delta > 3) {
            safe = false;
            log.debug("NOT SAFE (delta {d} out of range)\n", .{delta});
            break;
        }
        prev_val = val;
        safe = true;
    }

    if (safe) {
        log.debug("SAFE\n", .{});
    }
    return safe;
}
