pub const std_options: std.Options = .{
    .enable_segfault_handler = true,
    .log_level = .info,
};

/// Combination Build Module and name
const std = @import("std");
const Data = @import("data");
const utils = @import("utils");
const musubi = @import("musubi");

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

    const answer: i128 = 50;

    const alloc = std.testing.allocator;
    const res = try part1(Data.test_input, alloc);
    log.warn("[Test] Part 1: {d}", .{res});
    try std.testing.expect(res == answer);
}

test "part2 test input" {
    std.testing.log_level = .debug;

    const answer: i64 = 24;

    const alloc = std.testing.allocator;
    const res = try part2(Data.test_input, alloc);
    log.warn("[Test] Part 2: {d}", .{res});
    try std.testing.expect(res == answer);
}

// ------------ Part 1 Solution ------------

pub fn part1(input: []const u8, alloc: Allocator) !i128 {
    var graph: Graph = .{};
    graph.init(alloc);
    defer graph.deinit();

    var line_iter = utils.lines(input);
    while (line_iter.next()) |line| {
        if (line.len == 0) continue;
        var parts = std.mem.splitScalar(u8, line, ',');
        _ = try graph.insertVertex(Point{ .x = try std.fmt.parseInt(i32, parts.next().?, 10), .y = try std.fmt.parseInt(i32, parts.next().?, 10) });
    }

    var edges: ArrayList(Graph.Edge) = try ArrayList(Graph.Edge).initCapacity(alloc, std.math.pow(usize, graph.vertexCount(), 2));
    defer edges.deinit(alloc);
    for (graph.vertices()) |vertex| {
        log.debug("vertex: {any}", .{vertex});

        for (graph.vertices()) |neighbor| {
            if (std.meta.eql(vertex.id, neighbor.id)) continue;

            const distance = calculateDistance(vertex.id, neighbor.id);
            const edge = try graph.makeEdge(vertex, neighbor, .{ .src = vertex.id, .dst = neighbor.id }, distance);
            edges.appendAssumeCapacity(edge);
            log.debug("edge defined: {any}", .{edge});
        }
    }

    // Sort edges by weight
    std.mem.sort(Graph.Edge, edges.items, {}, struct {
        pub fn impl(_: void, a: Graph.Edge, b: Graph.Edge) bool {
            return a.weight > b.weight;
        }
    }.impl);

    log.debug("sorted edges:", .{});
    for (edges.items) |edge| {
        log.debug("edge: {any}", .{edge});
    }

    var largest_area: i128 = 0;
    for (edges.items) |edge| {
        const area = calculateArea(edge);
        log.debug("area: {d}", .{area});
        largest_area = @max(largest_area, area);
    }

    return largest_area;
}

// ------------ Part 2 Solution ------------
pub fn part2(input: []const u8, alloc: Allocator) !i64 {
    var red_tiles: std.ArrayList(Point) = .empty;
    defer red_tiles.deinit(alloc);

    var line_iter = utils.lines(input);
    while (line_iter.next()) |line| {
        if (line.len == 0) continue;

        var parts = utils.tokenize(line, ",");
        const x = try std.fmt.parseInt(i32, parts.next().?, 10);
        const y = try std.fmt.parseInt(i32, parts.next().?, 10);
        const point = Point{ .x = x, .y = y };
        try red_tiles.append(alloc, point);
        log.debug("initial point: {any}", .{point});
    }

    var edges: std.ArrayList(Edge) = .empty;
    defer edges.deinit(alloc);

    for (red_tiles.items, 0..) |p1, i| {
        const p2 = red_tiles.items[(i + 1) % red_tiles.items.len];
        const edge: Edge = .{ .p1 = p1, .p2 = p2, .is_vertical = (p1.x == p2.x) };
        log.debug("edge: {any}", .{edge});
        try edges.append(alloc, edge);
    }

    var vert_edges: std.ArrayList(Edge) = .empty;
    var horiz_edges: std.ArrayList(Edge) = .empty;
    defer vert_edges.deinit(alloc);
    defer horiz_edges.deinit(alloc);

    for (edges.items) |e| {
        if (e.is_vertical) {
            try vert_edges.append(alloc, e);
        } else {
            try horiz_edges.append(alloc, e);
        }
    }

    var max_area: i64 = 0;
    for (red_tiles.items, 0..) |r1, i| {
        for (red_tiles.items[i + 1 ..]) |r2| {
            if (r1.x == r2.x or r1.y == r2.y) continue;

            const min_x = @min(r1.x, r2.x);
            const max_x = @max(r1.x, r2.x);
            const min_y = @min(r1.y, r2.y);
            const max_y = @max(r1.y, r2.y);

            log.debug("x: [{d}-{d}] | y: [{d}-{d}]", .{ min_x, max_x, min_y, max_y });

            if (isRectangleInValidArea(min_x, max_x, min_y, max_y, vert_edges.items, horiz_edges.items, red_tiles.items)) {
                const area = (max_x - min_x + 1) * (max_y - min_y + 1);
                log.debug("rectangle is inside valid area, size: {d}", .{area});
                max_area = @max(max_area, area);
            }
        }
    }

    std.debug.print("Part 2: {}\n", .{max_area});
    return max_area;
}

// ------------ Common Functions ------------
fn calculateArea(edge: Graph.Edge) i128 {
    const width = edge.destination.id.x - edge.origin.id.x + 1;
    const height = edge.destination.id.y - edge.origin.id.y + 1;
    const abs_width: i128 = @abs(width);
    const abs_height: i128 = @abs(height);
    return abs_width * abs_height;
}

fn calculateDistance(a: Point, b: Point) i64 {
    const x = @as(f64, @floatFromInt(a.x - b.x));
    const y = @as(f64, @floatFromInt(a.y - b.y));
    //log.debug("x: {d} | y: {d} | z: {d}", .{ x, y, z });
    return @as(i64, @intFromFloat(@sqrt(std.math.pow(f64, x, 2) + std.math.pow(f64, y, 2))));
}

const Edge = struct {
    p1: Point,
    p2: Point,
    is_vertical: bool,
};
const Point = struct {
    x: i64,
    y: i64,
};

const EdgeId = struct {
    src: Point,
    dst: Point,
};

const Graph = musubi.Musubi(Point, EdgeId, i64, .undirected, .weighted);

fn isRectangleInValidArea(
    min_x: i64,
    max_x: i64,
    min_y: i64,
    max_y: i64,
    vert_edges: []const Edge,
    horiz_edges: []const Edge,
    boundary: []const Point,
) bool {
    // Check all 4 corners are inside or on the polygon
    const corners = [_]Point{
        .{ .x = min_x, .y = min_y },
        .{ .x = min_x, .y = max_y },
        .{ .x = max_x, .y = min_y },
        .{ .x = max_x, .y = max_y },
    };

    for (corners) |c| {
        if (!isInsideBoundary(c, vert_edges, boundary)) {
            return false;
        }
    }

    // Check no polygon edge crosses through the interior of the rectangle
    // A vertical polygon edge at x=edge_x crossing y in [min_y, max_y]
    // invalidates if min_x < edge_x < max_x
    for (vert_edges) |edge| {
        const edge_x = edge.p1.x;
        const edge_y_min = @min(edge.p1.y, edge.p2.y);
        const edge_y_max = @max(edge.p1.y, edge.p2.y);

        if (edge_x > min_x and edge_x < max_x) {
            if (edge_y_min < max_y and edge_y_max > min_y) {
                return false;
            }
        }
    }

    for (horiz_edges) |edge| {
        const edge_y = edge.p1.y;
        const edge_x_min = @min(edge.p1.x, edge.p2.x);
        const edge_x_max = @max(edge.p1.x, edge.p2.x);

        if (edge_y > min_y and edge_y < max_y) {
            if (edge_x_min < max_x and edge_x_max > min_x) {
                return false;
            }
        }
    }

    return true;
}

fn isInsideBoundary(corner_point: Point, vert_edges: []const Edge, bounday: []const Point) bool {
    for (bounday) |boundary_point| {
        if (corner_point.x == boundary_point.x and corner_point.y == boundary_point.y) return true;
    }

    // ray casting for interior check
    var edge_crossings: u32 = 0;
    for (vert_edges) |e| {
        const edge_x = e.p1.x;
        const edge_y_min = @min(e.p1.y, e.p2.y);
        const edge_y_max = @max(e.p1.y, e.p2.y);

        if (edge_x > corner_point.x and corner_point.y >= edge_y_min and corner_point.y < edge_y_max) {
            edge_crossings += 1;
            log.debug("ray crossed bounday {d} time(s)!", .{edge_crossings});
        }
    }

    // odd number of crossings means inside
    return (edge_crossings % 2) == 1;
}
