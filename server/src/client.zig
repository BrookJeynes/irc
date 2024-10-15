const std = @import("std");
const Room = @import("room.zig");

pub const client_msg_max_len: u16 = 1024;
pub const client_username_max_len: u8 = 9;
pub const client_exit_msg = "exit";

const Client = @This();

alloc: std.mem.Allocator,
arena: std.heap.ArenaAllocator,
stream: std.net.Stream,
username: []const u8,
room: *Room,

pub fn init(alloc: std.mem.Allocator, stream: std.net.Stream, username: []const u8, room: *Room) !Client {
    return .{
        .alloc = alloc,
        .arena = std.heap.ArenaAllocator.init(alloc),
        .stream = stream,
        .username = try alloc.dupe(u8, username),
        .room = room,
    };
}

pub fn deinit(self: *Client) void {
    defer self.stream.close();
    defer self.alloc.free(self.username);
}

pub fn run(self: *Client) !void {
    var server_msg_buf: [Client.client_msg_max_len]u8 = undefined;
    var client_reader = self.stream.reader();

    try self.room.broadcast(try std.fmt.bufPrint(&server_msg_buf, "Server: {s} joined the channel.\n", .{self.username}));

    while (true) {
        var client_msg_buf: [client_msg_max_len]u8 = undefined;

        const bytes = try client_reader.read(&client_msg_buf);
        if (bytes == client_msg_max_len) {
            continue;
        }
        const message = std.mem.trim(u8, client_msg_buf[0..bytes], " \n");

        if (std.mem.eql(u8, message, client_exit_msg) or bytes == 0) {
            try self.room.broadcast(try std.fmt.bufPrint(&server_msg_buf, "Server: {s} left the channel.\n", .{self.username}));
            self.room.remove(self);
            break;
        }

        try self.room.broadcast(try std.fmt.bufPrint(&server_msg_buf, "{s}: {s}\n", .{ self.username, message }));
    }
}
