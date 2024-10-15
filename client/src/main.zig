const std = @import("std");

const client_msg_max_len: u16 = 1024;
const client_username_max_len: u8 = 9;
const client_exit_msg = "exit";

pub fn retrieveMessages(stream: std.net.Stream) !void {
    var stream_reader = stream.reader();

    while (true) {
        var client_msg_buf: [client_msg_max_len]u8 = undefined;

        const bytes = try stream_reader.read(&client_msg_buf);
        std.debug.print("{s}", .{client_msg_buf[0..bytes]});
    }
}

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();

    var args = std.process.args();
    _ = args.skip();

    const port: u16 = 6969;
    const username = args.next() orelse return error.MissingNickname;
    if (username.len > client_username_max_len) return error.NicknameTooLarge;

    const peer = try std.net.Address.parseIp4("127.0.0.1", port);

    std.debug.print("Connecting to {}\n", .{peer});
    const stream = try std.net.tcpConnectToAddress(peer);
    defer stream.close();
    var stream_writer = stream.writer();

    _ = try std.Thread.spawn(.{}, retrieveMessages, .{stream});

    // Send username to server. This will always be the first message sent.
    try stream_writer.writeAll(username);

    while (true) {
        var client_msg_buf: [client_msg_max_len]u8 = undefined;

        std.debug.print("> ", .{});
        const bytes = try stdin.read(&client_msg_buf);
        if (bytes == client_msg_max_len) {
            std.debug.print("[ERROR] Message is too large to send.", .{});
            continue;
        }
        const message = std.mem.trim(u8, client_msg_buf[0..bytes], " \n");
        if (std.mem.eql(u8, message, client_exit_msg)) break;

        try stream_writer.writeAll(message);
    }
}
