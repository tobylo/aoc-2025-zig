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

const log = std.log.scoped(.day7);
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

    const answer: usize = 21;

    const alloc = std.testing.allocator;
    const res = try part1(Data.test_input, alloc);
    log.warn("[Test] Part 1: {d}", .{res});
    try std.testing.expect(res == answer);
}

test "part2 test input" {
    std.testing.log_level = .debug;

    const answer: usize = 40;

    const alloc = std.testing.allocator;
    const res = try part2(Data.test_input, alloc);
    log.warn("[Test] Part 2: {d}", .{res});
    try std.testing.expect(res == answer);
}

// ------------ Part 1 Solution ------------

pub fn part1(input: []const u8, alloc: Allocator) !usize {
    var grid = try parseGrid(input, alloc);
    defer grid.deinit(alloc);

    try grid.markVisited(alloc);

    var visited_split_count: usize = 0;
    for (0..grid.height) |y| {
        for (0..grid.width) |x| {
            const cell_idx = y * grid.width + x;
            if (grid.cells[cell_idx] == '^' and grid.isVisited(x, y)) {
                visited_split_count += 1;
            }
        }
    }
    return visited_split_count;
}

// ------------ Part 2 Solution ------------

pub fn part2(input: []const u8, alloc: Allocator) !usize {
    var grid = try parseGrid(input, alloc);
    defer grid.deinit(alloc);
    try grid.simulatePaths(alloc);
    return grid.timeline_count;
}

// ------------ Common Functions ------------
fn parseGrid(input: []const u8, alloc: Allocator) !Grid {
    var line_iter = utils.lines(input);
    var line_count: usize = 0;
    var line_len: usize = 0;

    while (line_iter.next()) |line| {
        if (line.len == 0) continue;
        line_len = @max(line_len, line.len);
        line_count += 1;
    }

    var grid = try Grid.init(alloc, line_len, line_count);

    var y: usize = 0;
    line_iter.reset();
    while (line_iter.next()) |line| {
        if (line.len == 0) continue;
        for (line, 0..) |c, x| {
            grid.cells[y * grid.width + x] = c;
            if (c == 'S') {
                grid.start_x = x;
                grid.start_y = y;
            }
        }
        y += 1;
    }

    log.debug("grid parsed: {any}", .{grid});

    return grid;
}

const Grid = struct {
    width: usize,
    height: usize,
    cells: []u8,
    visited: []u1,
    start_x: usize,
    start_y: usize,
    timeline_count: u64,

    pub fn init(alloc: Allocator, width: usize, height: usize) !Grid {
        const size = width * height;
        const cells = try alloc.alloc(u8, size);
        const visited = try alloc.alloc(u1, size);
        @memset(visited, 0);

        return Grid{
            .width = width,
            .height = height,
            .cells = cells,
            .visited = visited,
            .start_x = 0,
            .start_y = 0,
            .timeline_count = 0,
        };
    }

    pub fn deinit(self: *Grid, alloc: Allocator) void {
        alloc.free(self.cells);
        alloc.free(self.visited);
    }

    pub fn isVisited(self: *const Grid, x: usize, y: usize) bool {
        if (x >= self.width or y >= self.height) return false;
        return self.visited[y * self.width + x] == 1;
    }

    // Traverse the grid from the start cell going down, marking visited cells
    pub fn markVisited(self: *Grid, alloc: Allocator) !void {
        var queue: ArrayList(struct { x: usize, y: usize }) = .empty;
        defer queue.deinit(alloc);

        try queue.append(alloc, .{ .x = self.start_x, .y = self.start_y + 1 });
        while (queue.items.len > 0) {
            const pos = queue.pop() orelse continue;
            if (pos.x >= self.width or pos.y >= self.height) {
                continue;
            }

            const cell_idx = pos.y * self.width + pos.x;

            if (self.visited[cell_idx] == 1) {
                continue;
            }
            self.visited[cell_idx] = 1;

            const cell = self.cells[cell_idx];
            switch (cell) {
                '.' => {
                    if (pos.y + 1 < self.height) {
                        try queue.append(alloc, .{ .x = pos.x, .y = pos.y + 1 });
                    }
                },
                '^' => {
                    if (pos.x > 0) {
                        // mark x-1 as visited, queue next row (skipping over processing of neighbor)
                        self.visited[pos.y * self.width + (pos.x - 1)] = 1;
                        if (pos.y + 1 < self.height) {
                            try queue.append(alloc, .{ .x = pos.x - 1, .y = pos.y + 1 });
                        }
                    }
                    if (pos.x + 1 < self.width) {
                        // mark x+1 as visited, queue next row (skipping over processing of neighbor)
                        self.visited[pos.y * self.width + (pos.x + 1)] = 1;
                        if (pos.y + 1 < self.height) {
                            try queue.append(alloc, .{ .x = pos.x + 1, .y = pos.y + 1 });
                        }
                    }
                },
                else => {},
            }
        }
    }

    // Simulates all paths from the bottom going up no matter if they will reach the start cell
    pub fn simulatePaths(self: *Grid, alloc: Allocator) !void {
        // paths[idx] = number of unique timelines exiting from cell idx going down
        const paths = try alloc.alloc(u64, self.width * self.height);
        defer alloc.free(paths);
        @memset(paths, 0);

        // Process from bottom to top
        var row: usize = self.height;
        while (row > 0) {
            row -= 1;
            for (0..self.width) |x| {
                const idx = row * self.width + x;
                const cell = self.cells[idx];

                // path count from cell one row below, if outside of grid, take the value 1
                const path_value_below: u64 = if (row + 1 >= self.height) 1 else paths[(row + 1) * self.width + x];

                switch (cell) {
                    '.', 'S' => {
                        // empty cells and start take value from one row below
                        paths[idx] = path_value_below;
                        if (cell == 'S') {
                            log.debug("{d}:{d}: reached start cell, total paths found: {d}", .{ row, x, path_value_below });
                        }
                    },
                    '^' => {
                        // splitter: sum paths from left and right branches
                        var left_side_paths: u64 = undefined;
                        if (x == 0 or row + 1 > self.height) {
                            // timeline ended either at left side or bottom
                            left_side_paths = 1;
                        } else {
                            left_side_paths = paths[(row + 1) * self.width + (x - 1)];
                        }

                        var right_side_paths: u64 = undefined;
                        if (x + 1 >= self.width or row + 1 >= self.height) {
                            // timeline ended either at right side or bottom
                            right_side_paths = 1;
                        } else {
                            right_side_paths = paths[(row + 1) * self.width + (x + 1)];
                        }
                        paths[idx] = left_side_paths + right_side_paths;
                        log.debug("{d}:{d}: found splitter cell, combining left ({d}) and right ({d}) paths => {d}", .{ row, x, left_side_paths, right_side_paths, paths[idx] });
                    },
                    else => {
                        paths[idx] = path_value_below;
                    },
                }
            }
        }

        // Answer is number of paths reaching the start cell
        self.timeline_count = paths[self.start_x];
    }
};
