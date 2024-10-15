const std = @import("std");
const Client = @import("client.zig");

const Room = @This();

alloc: std.mem.Allocator,
lock: std.Thread.RwLock,
clients: std.AutoHashMap(*Client, void),

pub fn init(alloc: std.mem.Allocator) Room {
    return .{
        .alloc = alloc,
        .lock = std.Thread.RwLock{},
        .clients = std.AutoHashMap(*Client, void).init(alloc),
    };
}

pub fn deinit(self: *Room) void {
    defer self.clients.deinit();
    var it = self.clients.iterator();
    while (it.next()) |entry| {
        const client = entry.key_ptr.*;
        client.deinit();
    }
}

pub fn add(self: *Room, client: *Client) !void {
    self.lock.lock();
    defer self.lock.unlock();
    try self.clients.put(client, {});
}

pub fn remove(self: *Room, client: *Client) void {
    self.lock.lock();
    defer self.lock.unlock();
    _ = self.clients.remove(client);
    client.deinit();
}

pub fn broadcast(self: *Room, msg: []const u8) !void {
    self.lock.lock();
    defer self.lock.unlock();

    var it = self.clients.iterator();
    while (it.next()) |entry| {
        const client = entry.key_ptr.*;
        _ = try client.stream.writeAll(msg);
    }
}
