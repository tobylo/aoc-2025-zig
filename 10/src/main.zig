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

    const answer: usize = 7;

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
    var line_iter = utils.lines(input);
    while (line_iter.next()) |line| {
        if (line.len == 0) continue;

        var problem: Problem = .{};
        defer problem.deinit(alloc);

        var buttons: []Button = alloc.alloc(Button, 10);
        var button_idx: usize = 0;

        const tokens = utils.tokenize(line, " ");
        while (tokens.next()) |token| {
            if (token.len == 0) continue;

            switch (token[0]) {
                '[' => {
                    // lights
                    var target: []IndicatorLight = alloc.alloc(IndicatorLight, 10);
                    for (token[1 .. token.len - 2], 0..) |char, idx| {
                        const lit = char == '#';
                        target[idx] = .{ .idx = idx, .lit = lit };
                    }
                    problem.target = target;
                },
                '(' => {
                    // buttons
                    const toggles: []usize = alloc.alloc(usize, 10);
                    var toggle_iter = utils.tokenize(token, ",");
                    var idx: usize = 0;
                    while (toggle_iter.next()) |toggle| {
                        buttons[idx] = toggle - '0';
                        idx += 1;
                    }
                    buttons[button_idx] = Button{ .toggles = toggles };
                    button_idx += 1;
                },
                '{' => {
                    // jolt for later
                    continue;
                },
            }

            // simulate
            //var min_clicks: usize = 1000;
            for (0..5) |iteration| {
                problem.reset();

                _ = iteration;

                for (0..problem.buttons.len) |first_btn| {
                    problem.clickButton(first_btn);
                    if (problem.complete) {}
                }
            }
        }
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

const Problem = struct {
    target: []IndicatorLight,
    buttons: []Button,
    state: []IndicatorLight,
    clicks: usize = 0,
    complete: bool,

    fn reset(self: *Problem) void {
        self.clicks = 0;
        self.complete = false;
        for (self.state) |*light| {
            light.lit = false;
        }
    }

    fn deinit(self: *Problem, alloc: Allocator) void {
        alloc.free(self.target);
        for (self.buttons) |button| {
            button.deinit(alloc);
        }
        alloc.free(self.buttons);
        alloc.free(self.state);
    }

    fn clickButton(self: *Problem, button_index: usize) !void {
        if (button_index >= self.buttons.len) {
            return error.OutOfBound;
        }
        const button = self.buttons[button_index];
        for (button.toggles) |toggle_idx| {
            self.state[toggle_idx].toggle();
        }
        self.complete = std.meta.eql(self.target, self.state);
    }
};

const IndicatorLight = struct {
    idx: usize,
    lit: bool,

    fn toggle(self: *IndicatorLight) void {
        self.lit = !self.lit;
    }
};

const Button = struct {
    toggles: []usize,

    fn deinit(self: *Button, alloc: Allocator) void {
        alloc.free(self.toggles);
    }
};
