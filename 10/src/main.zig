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
    var min_clicks: usize = 0;

    var line_iter = utils.lines(input);
    while (line_iter.next()) |line| {
        if (line.len == 0) continue;

        var problem: Problem = Problem.init();
        defer problem.deinit(alloc);

        var tokens = utils.tokenize(line, " ");
        while (tokens.next()) |token| {
            if (token.len == 0) continue;
            log.debug("parsing token: {s}", .{token});

            switch (token[0]) {
                '[' => {
                    // lights
                    log.debug("found target", .{});
                    const num_lights = std.mem.count(u8, token, ".") + std.mem.count(u8, token, "#");
                    var lights = try Lights.init(alloc, num_lights);
                    for (token[1 .. token.len - 1]) |char| {
                        const lit = char == '#';
                        lights.addLight(lit);
                    }
                    log.debug("parsed target: {any}", .{lights});
                    problem.setTarget(lights);
                },
                '(' => {
                    // buttons
                    log.debug("found button", .{});
                    var button: Button = try Button.init(alloc, problem.target.num_lights);
                    const num_count = std.mem.count(u8, token, ",") + 1;

                    if (num_count == 1) {
                        const num_string = token[1 .. token.len - 1];
                        log.debug("parsing toggle: {s}", .{num_string});
                        button.addToggle(try std.fmt.parseInt(u8, num_string, 10));
                    } else {
                        const slice = token[1 .. token.len - 1];
                        var toggle_iter = utils.tokenize(slice, ",");
                        while (toggle_iter.next()) |toggle| {
                            log.debug("parsing toggle: {s}", .{toggle});
                            button.addToggle(try std.fmt.parseInt(u8, toggle, 10));
                        }
                    }
                    log.debug("parsed button: {any}", .{button});
                    try problem.addButton(alloc, button);
                },
                '{' => {
                    // jolt for later
                    continue;
                },
                else => unreachable,
            }
        }

        // simulate
        //var min_clicks: usize = 1000;
        const result = try problem.solve(alloc);
        min_clicks += result;
    }

    return min_clicks;
}

// ------------ Part 2 Solution ------------

pub fn part2(input: []const u8, alloc: Allocator) !usize {
    _ = alloc;
    _ = input;
    return 0;
}

// ------------ Common Functions ------------

const Problem = struct {
    target: Lights,
    buttons: ArrayList(Button) = .empty,

    button_count: usize,

    pub fn init() Problem {
        return .{
            .target = undefined,
            .buttons = .empty,
            .button_count = 0,
        };
    }

    fn reset(self: *Problem, alloc: Allocator) void {
        self.button_count = 0;
        for (self.buttons.items) |*button| {
            button.deinit(alloc);
        }
        self.buttons.clearAndFree(alloc);
        self.target.deinit(alloc);
    }

    fn deinit(self: *Problem, alloc: Allocator) void {
        self.target.deinit(alloc);
        for (self.buttons.items) |*button| {
            button.deinit(alloc);
        }
        self.buttons.deinit(alloc);
    }

    pub fn setTarget(self: *Problem, target: Lights) void {
        self.target = target;
    }

    pub fn addButton(self: *Problem, alloc: Allocator, button: Button) !void {
        try self.buttons.append(alloc, button);
        self.button_count += 1;
    }

    pub fn solve(self: *Problem, alloc: Allocator) !usize {
        log.debug("time to solve..", .{});
        // build bit rows
        var rows: std.ArrayList([]u1) = .empty;
        defer {
            for (rows.items) |row| {
                alloc.free(row);
            }
            rows.deinit(alloc);
        }

        for (0..self.target.num_lights) |light_idx| {
            // each row contains the toggle state of all buttons and the target light state
            var row = try alloc.alloc(u1, self.button_count + 1);
            @memset(row, 0);
            for (0..self.button_count) |button_idx| {
                row[button_idx] = self.buttons.items[button_idx].toggles[light_idx];
            }

            // last column contains the target light state
            row[self.button_count] = self.target.lights[light_idx];
            try rows.append(alloc, row);
        }

        log.debug("Problem rows:", .{});
        for (rows.items) |row| {
            log.debug("{any}", .{row});
        }

        // Track which column is the pivot for each row (-1 means no pivot)
        var pivot_col = try alloc.alloc(isize, rows.items.len);
        defer alloc.free(pivot_col);
        @memset(pivot_col, -1);

        var current_row: usize = 0; // Track which row we're placing pivots into

        for (0..self.button_count) |col_idx| {
            if (current_row >= rows.items.len) break; // No more rows to process

            log.debug("working on column: {d}, current_row: {d}", .{ col_idx, current_row });
            for (rows.items) |row| {
                log.debug("{any}", .{row});
            }

            // Step 1: find the pivot (search from current_row downward)
            var pivot_row_idx: usize = std.math.maxInt(usize);
            for (current_row..rows.items.len) |row_idx| {
                if (rows.items[row_idx][col_idx] == 1) {
                    pivot_row_idx = row_idx;
                    break;
                }
            }
            if (pivot_row_idx == std.math.maxInt(usize)) {
                // No pivot found in this column, skip it (don't increment current_row)
                continue;
            }

            log.debug("pivot found on row: {d} [{any}]", .{ pivot_row_idx, rows.items[pivot_row_idx] });

            // Step 2: swap pivot row with current_row
            if (pivot_row_idx != current_row) {
                const temp = rows.items[current_row];
                rows.items[current_row] = rows.items[pivot_row_idx];
                rows.items[pivot_row_idx] = temp;

                log.debug("swapped pivot row <> row {d}", .{current_row});
                for (rows.items) |row| {
                    log.debug("{any}", .{row});
                }
            }

            // Step 3: eliminate pivot column in all other rows
            log.debug("will XOR the pivot with the other rows", .{});
            for (0..rows.items.len) |row_idx| {
                if (row_idx == current_row) continue; // skip pivot row itself
                if (rows.items[row_idx][col_idx] == 1) {
                    log.debug("P: {any}", .{rows.items[current_row]});
                    log.debug("{d}: {any}", .{ row_idx, rows.items[row_idx] });
                    for (0..self.button_count + 1) |xor_idx| {
                        rows.items[row_idx][xor_idx] ^= rows.items[current_row][xor_idx];
                    }
                    log.debug("=> {any}", .{rows.items[row_idx]});
                }
            }

            pivot_col[current_row] = @intCast(col_idx); // pivot column for the current row
            current_row += 1; // Move to next row for next pivot

            log.debug("status after elimination:", .{});
            for (rows.items) |row| {
                log.debug("{any}", .{row});
            }
        }

        // Analyze the solution

        // Check for inconsistency
        for (rows.items) |row| {
            var all_zeros = true;
            for (0..self.button_count) |col| {
                if (row[col] == 1) {
                    all_zeros = false;
                    break;
                }
            }
            if (all_zeros and row[self.button_count] == 1) {
                log.err("invalid solution!", .{});
                return error.NoSolution;
            }
        }

        // Identify free variables (columns without pivots)
        var is_pivot_col = try alloc.alloc(bool, self.button_count);
        defer alloc.free(is_pivot_col);
        @memset(is_pivot_col, false);
        for (0..current_row) |r| {
            if (pivot_col[r] >= 0) {
                is_pivot_col[@intCast(pivot_col[r])] = true;
            }
        }

        var free_vars: std.ArrayList(usize) = .empty;
        defer free_vars.deinit(alloc);
        for (0..self.button_count) |col| {
            if (!is_pivot_col[col]) {
                try free_vars.append(alloc, col);
            }
        }

        log.debug("Pivot columns: {any}", .{pivot_col[0..current_row]});
        log.debug("Free variables: {any}", .{free_vars.items});

        // Try all combinations of free variables to find minimum button presses
        var min_buttons: usize = std.math.maxInt(usize);
        const num_free = free_vars.items.len;
        const num_combinations: usize = @as(usize, 1) << @intCast(num_free);

        for (0..num_combinations) |combo| {
            var solution = try alloc.alloc(u1, self.button_count);
            defer alloc.free(solution);
            @memset(solution, 0);

            // Set free variables according to this combination
            for (0..num_free) |i| {
                const bit: u1 = @intCast((combo >> @intCast(i)) & 1);
                solution[free_vars.items[i]] = bit;
            }

            // Back-substitute to find pivot variables (go backwards through rows)
            var i: usize = current_row;
            while (i > 0) {
                i -= 1;
                const pc: usize = @intCast(pivot_col[i]);
                var val = rows.items[i][self.button_count];
                // XOR with all other variables in this row (except the pivot itself)
                for (0..self.button_count) |col| {
                    if (col != pc and rows.items[i][col] == 1) {
                        val ^= solution[col];
                    }
                }
                solution[pc] = val;
            }

            // Count buttons pressed in this solution
            var count: usize = 0;
            for (solution) |s| {
                count += s;
            }
            log.debug("Combo {d}: solution {any} -> {d} buttons", .{ combo, solution, count });
            min_buttons = @min(min_buttons, count);
        }

        log.debug("Minimum buttons pressed: {d}", .{min_buttons});
        return min_buttons;
    }
};

const Lights = struct {
    lights: []u1,
    num_lights: usize,

    pub fn init(alloc: Allocator, num_lights: usize) !Lights {
        return Lights{
            .lights = try alloc.alloc(u1, num_lights),
            .num_lights = 0,
        };
    }

    pub fn deinit(self: *Lights, alloc: Allocator) void {
        alloc.free(self.lights);
    }

    pub fn addLight(self: *Lights, lit: bool) void {
        self.lights[self.num_lights] = @bitCast(lit);
        self.num_lights += 1;
    }
};

const Button = struct {
    toggles: []u1,

    pub fn init(alloc: Allocator, num_lights: usize) !Button {
        const toggles = try alloc.alloc(u1, num_lights);
        @memset(toggles, 0);

        return Button{
            .toggles = toggles,
        };
    }

    pub fn deinit(self: *Button, alloc: Allocator) void {
        alloc.free(self.toggles);
    }

    pub fn addToggle(self: *Button, light_number: usize) void {
        self.toggles[light_number] = 1;
    }
};
