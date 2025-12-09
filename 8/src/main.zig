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

const log = std.log.scoped(.day8);
const print = std.debug.print;

pub fn main() !void {
    var gpa = GPA(.{}){};
    defer _ = gpa.deinit(); // Performs leak checking
    const alloc = gpa.allocator();

    var T = try std.time.Timer.start();

    const res1 = try part1(Data.input, alloc, 1000);
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

    const answer: usize = 40;

    const alloc = std.testing.allocator;
    const res = try part1(Data.test_input, alloc, 10);
    log.warn("[Test] Part 1: {d}", .{res});
    try std.testing.expect(res == answer);
}

test "part2 test input" {
    std.testing.log_level = .debug;

    const answer: usize = 25272;

    const alloc = std.testing.allocator;
    const res = try part2(Data.test_input, alloc);
    log.warn("[Test] Part 2: {d}", .{res});
    try std.testing.expect(res == answer);
}

// ------------ Part 1 Solution ------------
pub fn part1(input: []const u8, alloc: Allocator, num_connections: usize) !usize {
    var graph: Graph = .{};
    graph.init(alloc);
    defer graph.deinit();

    var line_iter = utils.lines(input);
    while (line_iter.next()) |line| {
        if (line.len == 0) continue;

        var coords = std.mem.splitScalar(u8, line, ',');
        const x = try std.fmt.parseInt(i32, coords.next().?, 10);
        const y = try std.fmt.parseInt(i32, coords.next().?, 10);
        const z = try std.fmt.parseInt(i32, coords.next().?, 10);

        const vertex = VertexId{ .x = x, .y = y, .z = z };
        const v = try graph.insertVertex(vertex);
        log.debug("vertex added: {any}", .{v});
    }

    var edges = try constructEdges(alloc, &graph);
    defer edges.deinit(alloc);

    sortEdges(edges);

    var i: usize = 0;
    while (i < num_connections) {
        const edge = edges.pop() orelse break;

        // edge already defined (probably inverse)
        if (graph.gotEdgeIfEdge(edge)) {
            continue;
        }

        var connection_tree = try graph.connectionTree(edge.origin, .dij);
        defer connection_tree.deinit();

        const distance = connection_tree.getDistanceTo(edge.destination);
        if (distance != Graph.inf) {
            log.debug("circuit already exists between {any} and {any} with a distance of {any}", .{ edge.origin, edge.destination, distance });
        }

        try graph.insertEdgeIfEdge(edge);
        log.debug("inserted edge between {any} and {any} with weight {any}", .{ edge.origin, edge.destination, edge.weight });
        i += 1;
    }

    var seen = std.AutoHashMap(VertexId, void).init(alloc);
    defer seen.deinit();

    var circuit_sizes: std.ArrayList(usize) = .empty;
    defer circuit_sizes.deinit(alloc);

    for (graph.vertices()) |vertex| {
        if (seen.contains(vertex.id)) {
            log.debug("vertex already seen and counted for: {any}", .{vertex});
            continue;
        }

        var connection_tree = try graph.connectionTree(vertex, .dij);
        defer connection_tree.deinit();

        seen.put(vertex.id, {}) catch unreachable;
        var circuit_size: usize = 1; // starting node included
        for (connection_tree.discovered.dij.values()) |connected| {
            if (connected.weight == Graph.inf) continue;
            circuit_size += 1;
            seen.put(connected.edge.destination.id, {}) catch unreachable;
            seen.put(connected.edge.origin.id, {}) catch unreachable;
            log.debug("{any} | source: {any} | destination: {any}, | weight: {any}", .{ vertex, connected.edge.origin, connected.edge.destination, connected.weight });
        }
        log.debug("found circuit of size: {d}", .{circuit_size});
        circuit_sizes.append(alloc, circuit_size) catch unreachable;
        //log.debug("tree: {any}", .{connection_tree});
    }

    std.mem.sort(usize, circuit_sizes.items, {}, struct {
        pub fn impl(_: void, a: usize, b: usize) bool {
            return a > b;
        }
    }.impl);

    for (circuit_sizes.items) |size| {
        log.debug("sorted circuit size: {d}", .{size});
    }

    var sum: usize = 1;
    for (0..3) |circuit_idx| {
        sum *= circuit_sizes.items[circuit_idx];
    }

    return sum;
}

// ------------ Part 2 Solution ------------
fn parseVertices(input: []const u8, graph: *Graph) !void {
    var line_iter = utils.lines(input);
    while (line_iter.next()) |line| {
        if (line.len == 0) continue;

        var coords = std.mem.splitScalar(u8, line, ',');
        const x = try std.fmt.parseInt(i32, coords.next().?, 10);
        const y = try std.fmt.parseInt(i32, coords.next().?, 10);
        const z = try std.fmt.parseInt(i32, coords.next().?, 10);

        const vertex = VertexId{ .x = x, .y = y, .z = z };
        const v = try graph.insertVertex(vertex);
        log.debug("vertex added: {any}", .{v});
    }
}

pub fn part2(input: []const u8, alloc: Allocator) !i128 {
    var graph: Graph = .{};
    graph.init(alloc);
    defer graph.deinit();

    try parseVertices(input, &graph);

    var edges = try constructEdges(alloc, &graph);
    defer edges.deinit(alloc);

    sortEdges(edges);

    var completing_edge: ?Graph.Edge = null;
    while (true) {
        const edge = edges.pop() orelse break;

        // edge already defined (probably inverse)
        if (graph.gotEdgeIfEdge(edge)) {
            continue;
        }

        try graph.insertEdgeIfEdge(edge);
        log.debug("inserted edge between {any} and {any} with weight {any}", .{ edge.origin, edge.destination, edge.weight });
        var connection_tree = try graph.connectionTree(edge.origin, .dij);
        defer connection_tree.deinit();

        var connection_count: usize = 1;
        for (connection_tree.discovered.dij.values()) |connected| {
            if (connected.weight == Graph.inf) continue;
            connection_count += 1;
        }
        if (connection_count == graph.vertexCount()) {
            log.debug("connected tree count: {d}, vertex count: {d}", .{ connection_tree.getAllConnected().len, graph.vertexCount() });
            log.debug("circuit completed by {any}", .{edge});
            completing_edge = edge;
            break;
        }
    }

    if (completing_edge) |edge| {
        return @as(i128, @intCast(edge.origin.id.x)) * @as(i128, @intCast(edge.destination.id.x));
    }

    return error.NoSolution;
}

// ------------ Common Functions ------------
//
fn sortEdges(edges: ArrayList(Graph.Edge)) void {
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
}

fn constructEdges(alloc: Allocator, graph: *Graph) !ArrayList(Graph.Edge) {
    var edges: ArrayList(Graph.Edge) = try ArrayList(Graph.Edge).initCapacity(alloc, std.math.pow(usize, graph.vertexCount(), 2));
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
    return edges;
}

fn calculateDistance(a: VertexId, b: VertexId) f64 {
    const x = @as(f64, @floatFromInt(a.x - b.x));
    const y = @as(f64, @floatFromInt(a.y - b.y));
    const z = @as(f64, @floatFromInt(a.z - b.z));
    //log.debug("x: {d} | y: {d} | z: {d}", .{ x, y, z });
    return @sqrt(std.math.pow(f64, x, 2) + std.math.pow(f64, y, 2) + std.math.pow(f64, z, 2));
}

const VertexId = struct {
    x: i32,
    y: i32,
    z: i32,
};

const EdgeId = struct {
    src: VertexId,
    dst: VertexId,
};

const Graph = musubi.Musubi(VertexId, EdgeId, f64, .undirected, .weighted);

test "Calculate distance" {
    std.testing.log_level = .debug;
    const a = VertexId{ .x = 162, .y = 817, .z = 812 };
    const b = VertexId{ .x = 984, .y = 92, .z = 344 };

    const distance = calculateDistance(a, b);
    std.debug.print("distance: {d:.3}", .{distance});
}
