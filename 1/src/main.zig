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

const Direction = enum {
    Left,
    Right,
};

const Outcome = struct {
    position: isize,
    ticks: usize,

    fn init(ticks: usize) Outcome {
        return Outcome{ .position = undefined, .ticks = ticks };
    }

    fn increase(self: *Outcome) void {
        self.ticks += 1;
    }

    fn setPosition(self: *Outcome, position: isize) void {
        self.position = position;
    }
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

    const answer: usize = 3;

    const alloc = std.testing.allocator;
    const res = try part1(Data.test_input, alloc);
    log.warn("[Test] Part 1: {d}", .{res});
    try std.testing.expect(res == answer);
}

test "part2 test input" {
    std.testing.log_level = .debug;

    const answer: usize = 6;

    const alloc = std.testing.allocator;
    const res = try part2(Data.test_input, alloc);
    log.warn("[Test] Part 2: {d}", .{res});
    try std.testing.expect(res == answer);
}

// ------------ Part 1 Solution ------------

pub fn part1(input: []const u8, alloc: Allocator) !usize {
    _ = alloc;

    var lines = utils.lines(input);

    var current: isize = 50;
    var count: usize = 0;

    while (lines.next()) |line| {
        if (line.len == 0) continue;

        log.debug("line: {s}", .{line});

        const direction = line[0];
        const amount = try std.fmt.parseInt(isize, line[1..], 10);

        switch (direction) {
            'L' => {
                current -= amount;
            },
            'R' => {
                current += amount;
            },
            else => unreachable,
        }
        current = @mod(current, 100);

        if (current == 0) {
            count += 1;
        }
        log.debug("direction: {c}, amount: {d}, current: {d}", .{ direction, amount, current });
    }

    return count;
}

// ------------ Part 2 Solution ------------

pub fn part2(input: []const u8, alloc: Allocator) !usize {
    _ = alloc;

    var lines = utils.lines(input);

    var current: isize = 50;
    var count: usize = 0;

    while (lines.next()) |line| {
        if (line.len == 0) continue;

        const direction = line[0];
        const amount = try std.fmt.parseInt(isize, line[1..], 10);

        var d: Direction = undefined;
        d = switch (direction) {
            'L' => .Left,
            'R' => .Right,
            else => unreachable,
        };
        const result = countTicks(current, d, amount);
        log.debug("{any}", .{result});
        current = result.position;
        count += result.ticks;
    }

    return count;
}

fn countTicks(start_value: isize, direction: Direction, value: isize) Outcome {
    log.debug("start value: {d}, direction: {any}, value: {d}", .{ start_value, direction, value });
    var result = Outcome.init(@abs(@divFloor(value, 100)));
    switch (direction) {
        .Left => {
            result.setPosition(@mod(start_value - value, 100));
            if (result.position == 0 or (start_value != 0 and result.position > start_value)) {
                result.increase();
                log.debug("tick: 1", .{});
            }
        },
        .Right => {
            result.setPosition(@mod(start_value + value, 100));
            if (result.position == 0 or (start_value != 0 and result.position < start_value)) {
                result.increase();
                log.debug("tick: 1", .{});
            }
        },
    }

    return result;
}

// ------------ Common Functions ------------
