const std = @import("std");
const c = @cImport({
    @cInclude("time.h");
});

fn printUsage() void {
    std.debug.print("Usage: pomodoro_zig [OPTIONS]\n", .{});
    std.debug.print("Options:\n", .{});
    std.debug.print("  -t, --time <minutes>    Set timer duration in minutes (default: 25)\n", .{});
    std.debug.print("  -s, --seconds <seconds> Set timer duration in seconds (overrides minutes)\n", .{});
    std.debug.print("  -m, --message <text>    Custom completion message (default: 'Time's up!')\n", .{});
    std.debug.print("  -h, --help             Show this help message\n", .{});
    std.debug.print("\nExamples:\n", .{});
    std.debug.print("  pomodoro_zig -t 15                    # 15 minute timer\n", .{});
    std.debug.print("  pomodoro_zig -s 90                    # 90 second timer\n", .{});
    std.debug.print("  pomodoro_zig -t 5 -m \"Break time!\"    # 5 minutes with custom message\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip();

    var duration_seconds: f64 = 25.0 * 60.0;
    var completion_message: []const u8 = "Time's up!";

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            printUsage();
            return;
        } else if (std.mem.eql(u8, arg, "-t") or std.mem.eql(u8, arg, "--time")) {
            if (args.next()) |minutes_str| {
                const minutes = std.fmt.parseFloat(f64, minutes_str) catch {
                    std.debug.print("Error: Invalid minutes value '{s}'\n", .{minutes_str});
                    return;
                };
                if (minutes <= 0) {
                    std.debug.print("Error: Minutes must be positive\n", .{});
                    return;
                }
                duration_seconds = minutes * 60.0;
            } else {
                std.debug.print("Error: --time requires a value\n", .{});
                return;
            }
        } else if (std.mem.eql(u8, arg, "-s") or std.mem.eql(u8, arg, "--seconds")) {
            if (args.next()) |seconds_str| {
                duration_seconds = std.fmt.parseFloat(f64, seconds_str) catch {
                    std.debug.print("Error: Invalid seconds value '{s}'\n", .{seconds_str});
                    return;
                };
                if (duration_seconds <= 0) {
                    std.debug.print("Error: Seconds must be positive\n", .{});
                    return;
                }
            } else {
                std.debug.print("Error: --seconds requires a value\n", .{});
                return;
            }
        } else if (std.mem.eql(u8, arg, "-m") or std.mem.eql(u8, arg, "--message")) {
            if (args.next()) |message| {
                completion_message = message;
            } else {
                std.debug.print("Error: --message requires a value\n", .{});
                return;
            }
        } else {
            std.debug.print("Error: Unknown argument '{s}'\n", .{arg});
            printUsage();
            return;
        }
    }

    // const total_minutes = @as(u32, @intFromFloat(duration_seconds / 60.0));
    // const remaining_seconds = @as(u32, @intFromFloat(@mod(duration_seconds, 60.0)));
    //
    // std.debug.print("Starting timer: {d:0>2}:{d:0>2}\n", .{ total_minutes, remaining_seconds });
    std.debug.print("\x1b[33mWORKING COMMENCE NOW!!!\n", .{});

    const stdout = std.io.getStdOut().writer();
    var timer = try std.time.Timer.start();

    const total_width: usize = 30;
    const bar_chars = [_][]const u8{ " ", "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█" };
    const steps_per_block = bar_chars.len - 1;

    try stdout.print("\n\n", .{});

    var last_update_time: u64 = 0;
    const update_interval_ms = 500;

    while (true) {
        const elapsed_ns = timer.read();
        const elapsed_secs = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, std.time.ns_per_s);

        if (elapsed_secs >= duration_seconds) break;

        const current_time_ms = elapsed_ns / 1_000_000;

        if (current_time_ms - last_update_time >= update_interval_ms) {
            const bar_fill_ratio = elapsed_secs / duration_seconds;
            const bar_fill = bar_fill_ratio * @as(f64, total_width * steps_per_block);
            const total_steps: usize = @as(usize, @intFromFloat(bar_fill));
            const full_blocks = total_steps / steps_per_block;
            const partial_block_index = total_steps % steps_per_block;

            const time_left = duration_seconds - elapsed_secs;
            const seconds_left: u64 = @intFromFloat(time_left);
            const minutes = seconds_left / 60;
            const seconds = seconds_left % 60;

            const now_utc = std.time.timestamp();
            const edt_offset = -4 * 3600;
            const now_local = now_utc + edt_offset;

            const hour_24 = @as(u32, @intCast(@divTrunc(@mod(now_local, 86400), 3600)));
            const current_min = @as(u32, @intCast(@divTrunc(@mod(now_local, 3600), 60)));

            const is_pm = hour_24 >= 12;
            const hour_12 = if (hour_24 == 0) 12 else if (hour_24 > 12) hour_24 - 12 else hour_24;
            const am_pm = if (is_pm) "PM" else "AM";

            try stdout.print("\x1b[2A\x1b[2K", .{});
            try stdout.print("Time: {d:0>2}:{d:0>2} {s} | {d:0>2}:{d:0>2} left\n", .{ hour_12, current_min, am_pm, minutes, seconds });

            try stdout.print("\x1b[2K", .{});
            try stdout.print("[", .{});
            try stdout.print("\x1b[32m", .{});

            var i: usize = 0;
            while (i < total_width) : (i += 1) {
                if (i < full_blocks) {
                    try stdout.print("█", .{});
                } else if (i == full_blocks) {
                    try stdout.print("{s}", .{bar_chars[partial_block_index]});
                } else {
                    try stdout.print(" ", .{});
                }
            }

            try stdout.print("\x1b[0m", .{});
            try stdout.print("] {d:.1}%\n", .{bar_fill_ratio * 100.0});

            last_update_time = current_time_ms;
        }

        std.time.sleep(50_000_000);
    }

    const now_utc = std.time.timestamp();
    const edt_offset = -4 * 3600;
    const now_local = now_utc + edt_offset;

    const hour_24 = @as(u32, @intCast(@divTrunc(@mod(now_local, 86400), 3600)));
    const current_min = @as(u32, @intCast(@divTrunc(@mod(now_local, 3600), 60)));
    const current_sec = @as(u32, @intCast(@mod(now_local, 60)));

    const is_pm = hour_24 >= 12;
    const hour_12 = if (hour_24 == 0) 12 else if (hour_24 > 12) hour_24 - 12 else hour_24;
    const am_pm = if (is_pm) "PM" else "AM";

    try stdout.print("\x1b[2A\x1b[2K", .{});
    try stdout.print("Time: {d:0>2}:{d:0>2}:{d:0>2} {s} | 00:00 left\n", .{ hour_12, current_min, current_sec, am_pm });

    try stdout.print("\x1b[2K", .{});
    try stdout.print("[", .{});
    try stdout.print("\x1b[32m", .{});

    var i: usize = 0;
    while (i < total_width) : (i += 1) {
        try stdout.print("█", .{});
    }

    try stdout.print("\x1b[0m", .{});
    try stdout.print("] 100.0%\n", .{});

    try stdout.print("{s}\n", .{completion_message});
}
