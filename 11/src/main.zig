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

    const res2 = try part2(Data.input2, alloc);
    log.info("Part 2 answer: << {d} >>", .{res2});
    log.info("Part 2 took {d:.6}s", .{ns2sec(T.lap())});
}

// ------------ Tests ------------

test "part1 test input" {
    std.testing.log_level = .debug;

    log.warn(" -- Running Tests --", .{});

    const answer: usize = 5;

    const alloc = std.testing.allocator;
    const res = try part1(Data.test_input, alloc);
    log.warn("[Test] Part 1: {d}", .{res});
    try std.testing.expect(res == answer);
}

test "part2 test input" {
    std.testing.log_level = .debug;

    const answer: usize = 2;

    const alloc = std.testing.allocator;
    const res = try part2(Data.test_input2, alloc);
    log.warn("[Test] Part 2: {d}", .{res});
    try std.testing.expect(res == answer);
}

// ------------ Part 1 Solution ------------

pub fn part1(input: []const u8, alloc: Allocator) !usize {
    var graph: Graph = undefined;
    graph.init(alloc);
    defer graph.deinit();

    var vertex_cache = std.AutoHashMap([3]u8, Graph.Vertex).init(alloc);
    defer vertex_cache.deinit();

    const root_node_id: [3]u8 = .{ 'y', 'o', 'u' };
    const target_node_id: [3]u8 = .{ 'o', 'u', 't' };

    const nodes = try parseGraph(input, alloc, &graph, &vertex_cache, root_node_id, target_node_id);

    const path_count: usize = try pathCountFor(&graph, nodes.root, nodes.target);
    return path_count;
}

// ------------ Part 2 Solution ------------

pub fn part2(input: []const u8, alloc: Allocator) !usize {
    var graph: Graph = undefined;
    graph.init(alloc);
    defer graph.deinit();

    var vertex_cache = std.AutoHashMap([3]u8, Graph.Vertex).init(alloc);
    defer vertex_cache.deinit();

    const root_node_id: [3]u8 = .{ 's', 'v', 'r' };
    const target_node_id: [3]u8 = .{ 'o', 'u', 't' };
    const dac_node_id: [3]u8 = .{ 'd', 'a', 'c' };
    const fft_node_id: [3]u8 = .{ 'f', 'f', 't' };

    const nodes = try parseGraph(input, alloc, &graph, &vertex_cache, root_node_id, target_node_id);

    var memo = std.AutoHashMap(MemoKey, usize).init(alloc);
    defer memo.deinit();

    const path_count: usize = try pathCountForVia(&graph, nodes.root, nodes.target, dac_node_id, false, fft_node_id, false, &memo);
    return path_count;
}

// ------------ Common Functions ------------
fn parseGraph(
    input: []const u8,
    alloc: Allocator,
    graph: *Graph,
    vertex_cache: *std.AutoHashMap([3]u8, Graph.Vertex),
    root_node_id: [3]u8,
    target_node_id: [3]u8,
) !struct { root: Graph.Vertex, target: Graph.Vertex } {
    var root_node: Graph.Vertex = undefined;
    var target_node: Graph.Vertex = undefined;
    _ = alloc; // vertex_cache already has allocator

    var lines = utils.lines(input);
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var tokens = utils.tokenize(line, ":");
        const source = tokens.next().?;

        const source_node = try getOrInsertVertex(graph, vertex_cache, source);
        if (std.mem.eql(u8, &source_node.id.name, &root_node_id)) {
            root_node = source_node;
        }

        const destinations = tokens.next().?;
        var dest_iter = utils.tokenize(destinations, " ");
        while (dest_iter.next()) |destination| {
            const destination_node = try getOrInsertVertex(graph, vertex_cache, destination);

            if (std.mem.eql(u8, &destination_node.id.name, &target_node_id)) {
                target_node = destination_node;
            }

            _ = try graph.insertEdge(source_node, destination_node, Edge.init(source_node.id, destination_node.id), 1);
        }
    }

    return .{ .root = root_node, .target = target_node };
}

fn getOrInsertVertex(g: *Graph, cache: *std.AutoHashMap([3]u8, Graph.Vertex), name: []const u8) !Graph.Vertex {
    const key: [3]u8 = name[0..3].*;
    if (cache.get(key)) |existing| {
        return existing;
    }
    const vertex = try g.insertVertex(Node.init(name));
    try cache.put(key, vertex);
    return vertex;
}

fn pathCountFor(graph: *Graph, source_node: Graph.Vertex, target_node: Graph.Vertex) !usize {
    if (std.mem.eql(u8, &source_node.id.name, &target_node.id.name)) {
        return 1;
    }

    const outgoing = graph.adjacentVertices(source_node, .outgoing);
    var path_count: usize = 0;
    if (outgoing) |destination_nodes| {
        for (destination_nodes) |destination_node| {
            path_count += try pathCountFor(graph, destination_node, target_node);
        }
    }
    return path_count;
}

const MemoKey = struct {
    node: [3]u8,
    r1: bool,
    r2: bool,
};

fn pathCountForVia(graph: *Graph, source_node: Graph.Vertex, target_node: Graph.Vertex, requirement_1: [3]u8, requirement_1_passed: bool, requirement_2: [3]u8, requirement_2_passed: bool, memo: *std.AutoHashMap(MemoKey, usize)) !usize {
    var req_1_passed = requirement_1_passed;
    if (!req_1_passed and std.mem.eql(u8, &requirement_1, &source_node.id.name)) {
        req_1_passed = true;
    }

    var req_2_passed = requirement_2_passed;
    if (!req_2_passed and std.mem.eql(u8, &requirement_2, &source_node.id.name)) {
        req_2_passed = true;
    }

    if (std.mem.eql(u8, &source_node.id.name, &target_node.id.name)) {
        return if (req_1_passed and req_2_passed) 1 else 0;
    }

    const key = MemoKey{ .node = source_node.id.name, .r1 = req_1_passed, .r2 = req_2_passed };
    if (memo.get(key)) |cached| {
        return cached;
    }

    const outgoing = graph.adjacentVertices(source_node, .outgoing);
    var path_count: usize = 0;
    if (outgoing) |destination_nodes| {
        for (destination_nodes) |destination_node| {
            path_count += try pathCountForVia(graph, destination_node, target_node, requirement_1, req_1_passed, requirement_2, req_2_passed, memo);
        }
    }

    try memo.put(key, path_count);
    return path_count;
}

const Node = struct {
    name: [3]u8,

    fn init(name: []const u8) Node {
        return Node{ .name = name[0..3].* };
    }
};

const Edge = struct {
    src: Node,
    dst: Node,

    fn init(src: Node, dst: Node) Edge {
        return Edge{ .src = src, .dst = dst };
    }
};

const Graph = musubi.Musubi(Node, Edge, u8, .directed, .weighted);
