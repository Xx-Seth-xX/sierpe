const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});
const Vec2f = @Vector(2, f32);
inline fn toRayVec2(from: Vec2f) ray.Vector2 {
    return ray.Vector2{ .x = from[0], .y = from[1] };
}

// inline fn vector2(x: f32, y: f32) ray.Vector2 {
//     return ray.Vector2{ .x = x, .y = y };
// }

const Direction = enum(i8) {
    Up = 0,
    Right,
    Down,
    Left,
};

const screen_width = 800;
const screen_height = 800;
const window_title = "Sierpe";
const target_fps = 60;

fn drawTube(origin: Vec2f, end: Vec2f, width: f32, color: ray.Color) void {
    // leftup_most := origin - [2]f32{width, width}/2;
    // size := end + [2]f32{width, width}/2 - leftup_most;
    if (origin[0] > end[0] or origin[1] > end[1]) {
        const leftup_most = toRayVec2(end - Vec2f{ width / 2, width / 2 });
        const size = toRayVec2(origin + Vec2f{ width, width } - end);
        // std.log.info("l: {}, s: {}", .{ leftup_most, size });
        ray.DrawRectangleV(leftup_most, size, color);
    } else {
        const leftup_most = toRayVec2(origin - Vec2f{ width / 2, width / 2 });
        const size = toRayVec2(end + Vec2f{ width, width } - origin);
        // std.log.info("l: {}, s: {}", .{ leftup_most, size });
        ray.DrawRectangleV(leftup_most, size, color);
    }
}

const Snake = struct {
    const Self = @This();
    const width = 20;
    const color = ray.RED;
    const head_color = ray.BLACK;
    const speed = 200; // px per second
    const Pivots = std.DoublyLinkedList(Pivot);
    const Pivot = struct {
        pos: Vec2f,
        dir: Direction,
    };
    alloc: std.mem.Allocator,
    head: Vec2f,
    dir: Direction,
    pivots: Pivots,
    length: f32,

    fn init(alloc: std.mem.Allocator, head: Vec2f, length: f32, dir: Direction) !Self {
        var self = Self{
            .alloc = alloc,
            .head = head,
            .dir = dir,
            .length = length,
            .pivots = Self.Pivots{},
        };
        const first_piv_pos = head + switch (dir) {
            .Up => Vec2f{ 0, Snake.speed },
            .Right => Vec2f{ -Snake.speed, 0 },
            .Down => Vec2f{ 0, -Snake.speed },
            .Left => Vec2f{ Snake.speed, 0 },
        };
        const first_node = try alloc.create(Self.Pivots.Node);
        first_node.data = Self.Pivot{ .dir = dir, .pos = first_piv_pos };
        self.pivots.append(first_node);
        return self;
    }
    fn deinit(self: *Self) void {
        // Clean up any remaining pivots in linked list
        var pos_current = self.pivots.first;
        while (pos_current) |current| {
            self.pivots.remove(current);
            pos_current = current.next;
            self.alloc.destroy(current);
        }
    }
    fn draw(self: *Self) void {
        var begin = self.head;
        var next_piv = self.pivots.first;
        while (next_piv) |aux| {
            const end = aux.data.pos;
            drawTube(begin, end, Snake.width, Snake.color);
            begin = end;
            next_piv = aux.next;
        }
        ray.DrawRectangleV(
            toRayVec2(self.head - Vec2f{ width / 2, width / 2 }),
            ray.Vector2{ .x = width, .y = width },
            Snake.head_color,
        );
    }

    fn updateInput(self: *Self) !void {
        var new_dir: i8 = @intFromEnum(self.dir);
        if (ray.IsKeyPressed(ray.KEY_D)) {
            new_dir += 1;
            if (new_dir < 0) {
                new_dir = 3;
            } else if (new_dir > 3) {
                new_dir = 0;
            }
            // const pivot = Self.Pivots.Node{ .data = Vec2f{ self.head[0], self.head[1] } };
            const new_node = try self.alloc.create(Self.Pivots.Node);
            new_node.data = .{ .pos = self.head, .dir = @enumFromInt(new_dir) };
            self.pivots.prepend(new_node);
        } else if (ray.IsKeyPressed(ray.KEY_A)) {
            new_dir -= 1;
            if (new_dir < 0) {
                new_dir = 3;
            } else if (new_dir > 3) {
                new_dir = 0;
            }
            // const pivot = Self.Pivots.Node{ .data = Vec2f{ self.head[0], self.head[1] } };
            const new_node = try self.alloc.create(Self.Pivots.Node);
            new_node.data = .{ .pos = self.head, .dir = @enumFromInt(new_dir) };
            self.pivots.prepend(new_node);
        }
        self.dir = @enumFromInt(new_dir);
    }
    fn update(self: *Self, dt: f32) !void {
        try self.updateInput();
        switch (self.dir) {
            .Up => self.head += Vec2f{ 0, -Snake.speed * dt },
            .Right => self.head += Vec2f{ Snake.speed * dt, 0 },
            .Down => self.head += Vec2f{ 0, Snake.speed * dt },
            .Left => self.head += Vec2f{ -Snake.speed * dt, 0 },
        }

        var current_length = self.length;

        var prev_pivot = Self.Pivot{ .pos = self.head, .dir = self.dir };
        var _next_node = self.pivots.first;
        while (_next_node) |next_node| {
            const next_pivot = next_node.data;
            var vecdiff = prev_pivot.pos - next_pivot.pos;
            vecdiff *= vecdiff;
            const distance = @sqrt(@reduce(.Add, vecdiff));
            current_length -= distance;

            if (distance < Snake.width / 3 and next_node.prev != null) {
                self.pivots.remove(next_node);
                self.alloc.destroy(next_node);
                break;
            }

            if (current_length < 0.0) {
                switch (next_node.data.dir) {
                    .Up => next_node.data.pos += Vec2f{ 0, -Snake.speed * dt },
                    .Right => next_node.data.pos += Vec2f{ Snake.speed * dt, 0 },
                    .Down => next_node.data.pos += Vec2f{ 0, Snake.speed * dt },
                    .Left => next_node.data.pos += Vec2f{ -Snake.speed * dt, 0 },
                }
            }

            prev_pivot = next_pivot;
            _next_node = next_node.next;
        }
    }
};

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    ray.InitWindow(screen_width, screen_height, window_title);
    ray.SetTargetFPS(target_fps);
    defer ray.CloseWindow();

    var snake = try Snake.init(alloc, Vec2f{ 100, 100 }, 500.0, Direction.Down);
    defer snake.deinit();

    while (!ray.WindowShouldClose()) {
        const dt = ray.GetFrameTime();
        ray.BeginDrawing();
        ray.ClearBackground(ray.RAYWHITE);
        try snake.update(dt);
        snake.draw();
        ray.EndDrawing();
    }
    return 0;
}
