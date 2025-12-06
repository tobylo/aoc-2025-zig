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

    var res2 = try part2_structs(Data.input, alloc);
    defer res2.deinit(alloc);
    const sum = res2.solve();
    log.info("Part 2 answer: << {d} >>", .{sum});
    log.info("Part 2 took {d:.6}s", .{ns2sec(T.lap())});
}

// ------------ Tests ------------

test "part1 test input" {
    std.testing.log_level = .debug;

    log.warn(" -- Running Tests --", .{});

    const answer: usize = 4277556;

    const alloc = std.testing.allocator;
    const res = try part1(Data.test_input, alloc);
    log.warn("[Test] Part 1: {d}", .{res});
    try std.testing.expect(res == answer);
}

test "part2 test input" {
    std.testing.log_level = .debug;

    const answer: usize = 3263827;

    const alloc = std.testing.allocator;
    var res = try part2_structs(Data.test_input, alloc);
    defer res.deinit(alloc);
    const value = res.solve();
    log.warn("[Test] Part 2: {d}", .{value});
    try std.testing.expect(value == answer);
}

// ------------ Part 1 Solution ------------

const TokenIterator = std.mem.TokenIterator(u8, .any);

pub fn part1(input: []const u8, alloc: Allocator) !usize {
    var sum: usize = 0;

    var rows: ArrayList(ArrayList([]const u8)) = .empty;
    defer {
        for (0..rows.items.len) |i| {
            rows.items[i].deinit(alloc);
        }
        rows.deinit(alloc);
    }

    var lines = utils.tokenize(input, "\n");
    while (lines.next()) |line| {
        var row: ArrayList([]const u8) = .empty;
        var tokens = utils.tokenize(line, " ");
        while (tokens.next()) |token| {
            try row.append(alloc, token);
        }
        try rows.append(alloc, row);
    }

    const col_count = rows.items[0].items.len;
    const operation_row = rows.items[rows.items.len - 1];

    for (0..col_count) |col_idx| {
        const operation = operation_row.items[col_idx][0];
        log.debug("column {d}: operation = {c}", .{ col_idx, operation });

        var part_sum: usize = 0;
        for (rows.items[0 .. rows.items.len - 1], 0..) |row, row_idx| {
            if (col_idx >= row.items.len) continue;

            const num = try std.fmt.parseUnsigned(usize, row.items[col_idx], 10);
            //const num = @as([]u8, row.items[col_idx]) - '0';
            log.debug("column {d}, row {d}: number = {d}", .{ col_idx, row_idx, num });

            if (row_idx == 0) {
                part_sum = num;
            } else {
                if (operation == '+') {
                    log.debug("column {d}: adding {d} to {d}", .{ col_idx, num, part_sum });
                    part_sum += num;
                } else {
                    log.debug("column {d}: multiplying {d} with {d}", .{ col_idx, num, part_sum });
                    part_sum *= num;
                }
            }
        }

        log.debug("column {d}: sum: {d}", .{ col_idx, part_sum });
        sum += part_sum;
    }

    return sum;
}

// ------------ Part 2 Solution ------------

pub fn part2_wrong_misread(input: []const u8, alloc: Allocator) !usize {
    var sum: usize = 0;

    var rows: ArrayList(ArrayList([]const u8)) = .empty;
    defer {
        for (0..rows.items.len) |i| {
            rows.items[i].deinit(alloc);
        }
        rows.deinit(alloc);
    }

    var lines = utils.tokenize(input, "\n");
    while (lines.next()) |line| {
        var row: ArrayList([]const u8) = .empty;
        var tokens = utils.tokenize(line, " ");
        while (tokens.next()) |token| {
            try row.append(alloc, token);
        }
        try rows.append(alloc, row);
    }

    const col_count = rows.items[0].items.len;
    const operation_row = rows.items[rows.items.len - 1];

    for (0..col_count) |col_idx| {
        const operation = operation_row.items[col_idx][0];
        log.debug("column {d}: operation = {c}", .{ col_idx, operation });

        var max_digit_count: usize = 0;
        // there will be as many numbers as the longest number in the column
        for (rows.items[0 .. rows.items.len - 1]) |row| {
            if (col_idx >= row.items.len) continue;
            if (row.items[col_idx].len > max_digit_count) {
                max_digit_count = row.items[col_idx].len;
            }
        }
        log.debug("column {d}: longest cephalopod number {d}", .{ col_idx, max_digit_count });

        var part_sum: usize = 0;
        var digit_pos: usize = 0;

        while (digit_pos < max_digit_count) : (digit_pos += 1) {
            var cephalopod_number_buf: [10]u8 = undefined;
            var buf_len: usize = 0;

            for (rows.items[0 .. rows.items.len - 1]) |row| {
                if (col_idx >= row.items.len) continue;

                const num_str = row.items[col_idx];

                if (digit_pos < num_str.len) {
                    const actual_digit_idx = num_str.len - 1 - digit_pos;
                    cephalopod_number_buf[buf_len] = num_str[actual_digit_idx];
                    buf_len += 1;
                }
            }

            if (buf_len > 0) {
                const num = try std.fmt.parseUnsigned(usize, cephalopod_number_buf[0..buf_len], 10);
                log.debug("column {d}, digit_pos {d}: cephalopod number = {d}", .{ col_idx, digit_pos, num });

                if (digit_pos == 0) {
                    part_sum = num;
                } else {
                    if (operation == '+') {
                        log.debug("column {d}: adding {d} to {d}", .{ col_idx, num, part_sum });
                        part_sum += num;
                    } else {
                        log.debug("column {d}: multiplying {d} with {d}", .{ col_idx, num, part_sum });
                        part_sum *= num;
                    }
                }
            }
        }

        log.debug("column {d}: sum: {d}", .{ col_idx, part_sum });
        sum += part_sum;
    }

    return sum;
}

pub fn part2_structs(input: []const u8, alloc: Allocator) !CephalopodProblems {
    var lines_iter = utils.lines(input);
    const lines_count = lines_iter.rest().len - 1;

    var lines = try ArrayList([]const u8).initCapacity(alloc, lines_count);
    defer lines.deinit(alloc);

    while (lines_iter.next()) |line| {
        if (line.len == 0) continue;
        lines.appendAssumeCapacity(line);
    }

    // max_line_len will hold the length of the longest line (i.e. col_index + 1)
    var max_line_len: usize = 0;
    for (lines.items) |line| {
        max_line_len = @max(max_line_len, line.len);
    }
    log.debug("max line length: {d}", .{max_line_len});

    const operatorLine = lines.items[lines.items.len - 1];
    const problem_count = std.mem.count(u8, operatorLine, "+") + std.mem.count(u8, operatorLine, "*");

    var problems: CephalopodProblems = try CephalopodProblems.init(alloc, problem_count);
    errdefer problems.deinit(alloc);

    var col_index: usize = max_line_len;
    var values = try ArrayList(usize).initCapacity(alloc, 10);
    defer values.deinit(alloc);

    var operator: ?Operator = null;

    var digits = try ArrayList(u8).initCapacity(alloc, lines_count);
    defer digits.deinit(alloc);

    while (col_index > 0) {
        // avoid having to deal with usize/isize casting and since col_index starts at max_len
        col_index -= 1;

        var is_col_separator = true;
        for (lines.items) |line| {
            if (col_index >= line.len) continue;

            if (line[col_index] != ' ') {
                is_col_separator = false;
                break;
            }
        }
        if (is_col_separator) {
            log.debug("found separator col: {d}", .{col_index});

            if (operator != null and values.items.len > 0) {
                log.debug("problem parsed! {d} problems with operator {any}", .{ values.items.len, operator.? });
                problems.addProblem(Problem{
                    .values = try values.toOwnedSlice(alloc),
                    .operator = operator.?,
                });
                values.clearRetainingCapacity();
            }

            continue;
        }

        for (lines.items) |line| {
            if (col_index >= line.len) continue;

            if (std.ascii.isDigit(line[col_index])) {
                log.debug("found digit {c} in col {d} / line {any}", .{ line[col_index], col_index, line });
                digits.appendAssumeCapacity(line[col_index]);
            } else if (line[col_index] == '*') {
                operator = .multiply;
            } else if (line[col_index] == '+') {
                operator = .add;
            } else if (line[col_index] == ' ' and digits.items.len > 0) {
                // end of current number
                log.debug("found empty cell in col {d}, number ended!", .{col_index});
                const number = try std.fmt.parseUnsigned(usize, digits.items, 10);
                _ = try values.append(alloc, number);
                digits.clearRetainingCapacity();
            }
        }

        if (digits.items.len > 0) {
            log.debug("empty cell in col {d}, number ended!", .{col_index});
            const number = try std.fmt.parseUnsigned(usize, digits.items, 10);
            _ = try values.append(alloc, number);
        }
    }

    if (operator != null and values.items.len > 0) {
        log.debug("problem parsed! {d} problems with operator {any}", .{ values.items.len, operator.? });
        problems.addProblem(Problem{
            .values = try values.toOwnedSlice(alloc),
            .operator = operator.?,
        });
        values = try ArrayList(usize).initCapacity(alloc, 10);
    }

    return problems;
}

// ------------ Common Functions ------------

pub const Operator = enum {
    add,
    multiply,
};

pub const Problem = struct {
    values: []usize,
    operator: Operator,

    pub fn deinit(self: *Problem, alloc: Allocator) void {
        alloc.free(self.values);
    }

    pub fn solve(self: Problem) usize {
        var sum: usize = 0;
        log.debug("solving {any}", .{self});

        for (self.values, 0..) |value, index| {
            if (index == 0) {
                sum = value;
            } else {
                switch (self.operator) {
                    .add => sum += value,
                    .multiply => sum *= value,
                }
            }
        }
        log.debug("solved {d}", .{sum});
        return sum;
    }
};

pub const CephalopodProblems = struct {
    problems: ArrayList(Problem) = .empty,

    pub fn init(alloc: Allocator, capacity: usize) !CephalopodProblems {
        return CephalopodProblems{
            .problems = try ArrayList(Problem).initCapacity(alloc, capacity),
        };
    }

    pub fn deinit(self: *CephalopodProblems, alloc: Allocator) void {
        for (self.problems.items) |*problem| {
            problem.deinit(alloc);
        }
        self.problems.deinit(alloc);
    }

    pub fn addProblem(self: *CephalopodProblems, problem: Problem) void {
        self.problems.appendAssumeCapacity(problem);
    }

    pub fn solve(self: CephalopodProblems) usize {
        var sum: usize = 0;

        for (0..self.problems.items.len) |idx| {
            sum += self.problems.items[idx].solve();
        }

        return sum;
    }
};
