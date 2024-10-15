const std = @import("std");
const Room = @import("room.zig");
const Client = @import("client.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const address = std.net.Address.parseIp("127.0.0.1", 6969) catch unreachable;
    var server = try address.listen(.{ .reuse_port = true });
    defer server.deinit();

    const addr = server.listen_address;
    std.debug.print("Listening on port {}\n", .{addr.getPort()});

    var room = Room.init(alloc);
    defer room.deinit();

    while (true) {
        var client_stream = try server.accept();
        errdefer client_stream.stream.close();

        // Retrieve username as the first message sent from the client.
        var username_buf: [Client.client_username_max_len]u8 = undefined;
        const username_len = try client_stream.stream.read(&username_buf);
        if (username_len > Client.client_username_max_len) return error.NicknameTooLarge;
        const username = username_buf[0..username_len];

        const client = try alloc.create(Client);
        client.* = try Client.init(alloc, client_stream.stream, username, &room);
        try room.add(client);

        _ = try std.Thread.spawn(.{}, Client.run, .{client});
    }
}
