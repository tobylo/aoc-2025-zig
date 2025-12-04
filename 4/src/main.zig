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
    std.testing.log_level = .info;

    log.warn(" -- Running Tests --", .{});

    const answer: usize = 13;

    const alloc = std.testing.allocator;
    const res = try part1(Data.test_input, alloc);
    log.warn("[Test] Part 1: {d}", .{res});
    try std.testing.expect(res == answer);
}

test "part2 test input" {
    std.testing.log_level = .info;

    const answer: usize = 43;

    const alloc = std.testing.allocator;
    const res = try part2(Data.test_input, alloc);
    log.warn("[Test] Part 2: {d}", .{res});
    try std.testing.expect(res == answer);
}

// ------------ Part 1 Solution ------------

pub fn part2(input: []const u8, alloc: Allocator) !usize {
    var lines = utils.lines(input);

    const width = lines.peek().?.len;
    const height = std.mem.count(u8, input, "\n");
    log.debug("rows: {d}, cols: {d}", .{ height, lines.peek().?.len });

    var grid = try Grid(Cell).init(alloc, width, height);
    defer grid.deinit();

    var row: usize = 0;
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        for (line, 0..) |char, col| {
            log.debug("line #{d}: {c}", .{ row, char });
            grid.set(col, row, Cell.init(col, row, char));
        }
        row += 1;
    }

    const limit = 4;
    var accessable_count: usize = 0;

    while (true) {
        var picked_in_iteration: usize = 0;
        for (grid.data) |*cell| {
            if (!cell.is_roll) continue;
            // find all neighbors
            var roll_count: usize = 0;
            for (grid.get_neighbors_of(cell.*)) |maybe_neighbor| {
                if (maybe_neighbor) |neighbor| {
                    log.debug("found neighbor of {d}:{d} | {d}:{d}, is roll: {any}", .{ cell.row, cell.col, neighbor.row, neighbor.col, neighbor.is_roll });
                    if (neighbor.is_roll) roll_count += 1;
                }
            }
            log.debug("the space: {d}:{d} has {d} neighbors of type roll", .{ cell.row, cell.col, roll_count });
            if (roll_count < limit) {
                grid.pick(cell);
                picked_in_iteration += 1;
            }
        }
        accessable_count += picked_in_iteration;
        if (picked_in_iteration == 0) break;
    }

    return accessable_count;
}

// ------------ Part 2 Solution ------------

pub fn part1(input: []const u8, alloc: Allocator) !usize {
    var lines = utils.lines(input);

    const height = std.mem.count(u8, input, "\n");
    const width = lines.peek().?.len;
    log.debug("rows: {d}, cols: {d}", .{ height, lines.peek().?.len });

    var grid = try Grid(Cell).init(alloc, width, height);
    defer grid.deinit();

    var row: usize = 0;
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        for (line, 0..) |char, col| {
            log.debug("line #{d}: {c}", .{ row, char });
            grid.set(col, row, Cell.init(col, row, char));
        }
        row += 1;
    }

    const limit = 4;
    var accessable_count: usize = 0;

    for (grid.data) |cell| {
        if (!cell.is_roll) continue;

        // find all neighbors
        var roll_count: usize = 0;
        for (grid.get_neighbors_of(cell)) |maybe_neighbor| {
            if (maybe_neighbor) |neighbor| {
                log.debug("found neighbor of {d}:{d} | {d}:{d}, is roll: {any}", .{ cell.row, cell.col, neighbor.row, neighbor.col, neighbor.is_roll });
                if (neighbor.is_roll) roll_count += 1;
            }
        }
        log.debug("the space: {d}:{d} has {d} neighbors of type roll", .{ cell.row, cell.col, roll_count });
        if (roll_count < limit) accessable_count += 1;
    }

    return accessable_count;
}

// ------------ Common Functions ------------
//
//

fn Grid(comptime T: type) type {
    return struct {
        data: []T,
        width: usize,
        height: usize,
        allocator: Allocator,

        const Self = @This();

        pub fn init(alloc: Allocator, width: usize, height: usize) !Self {
            const data = try alloc.alloc(T, width * height);
            return Self{
                .data = data,
                .width = width,
                .height = height,
                .allocator = alloc,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.data);
        }

        pub fn get(self: Self, col: usize, row: usize) T {
            return self.data[row * self.width + col];
        }

        pub fn set(self: *Self, col: usize, row: usize, value: T) void {
            self.data[row * self.width + col] = value;
        }

        pub fn pick(self: *Self, cell: *Cell) void {
            cell.pick();
            self.data[cell.row * self.width + cell.col] = cell.*;
        }

        pub fn get_neighbors_of(self: *Self, space: Cell) [8]?Cell {
            var neighbors = [_]?Cell{null} ** 8;
            var index: usize = 0;

            const min_row = if (space.row == 0) 0 else space.row - 1;
            const max_row = if (space.row == self.height - 1) space.row else space.row + 1;
            const min_col = if (space.col == 0) 0 else space.col - 1;
            const max_col = if (space.col == self.width - 1) space.col else space.col + 1;

            for (min_row..max_row + 1) |row| {
                for (min_col..max_col + 1) |col| {
                    if (row == space.row and col == space.col) continue;
                    neighbors[index] = self.get(col, row);
                    index += 1;
                }
            }

            return neighbors;
        }
    };
}

const Cell = struct {
    row: usize,
    col: usize,
    content: u8,
    is_roll: bool,

    pub fn init(col: usize, row: usize, content: u8) Cell {
        return Cell{
            .row = row,
            .col = col,
            .content = content,
            .is_roll = content == "@"[0],
        };
    }

    const Self = @This();

    pub fn pick(self: *Self) void {
        self.content = '.';
        self.is_roll = false;
    }

    pub fn format(self: Cell, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("Space {{ row = {d}, col = {d}, content = {c}, is_roll = {} }}", .{ self.row, self.col, self.content, self.is_roll });
    }
};
