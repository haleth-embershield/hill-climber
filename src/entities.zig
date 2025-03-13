const std = @import("std");
const renderer = @import("renderer.zig");
const audio = @import("audio.zig");

// Game constants
pub const GRAVITY: f32 = 1000.0;
pub const BIKE_ACCELERATION: f32 = 300.0;
pub const BIKE_MAX_SPEED: f32 = 300.0;
pub const BIKE_SIZE: f32 = 30.0;
pub const WHEEL_SIZE: f32 = 15.0;
pub const TERRAIN_SEGMENT_WIDTH: f32 = 50.0;
pub const FUEL_CONSUMPTION_RATE: f32 = 10.0; // Fuel units per second
pub const INITIAL_FUEL: f32 = 100.0;

// Game dimensions
pub const GAME_WIDTH: usize = 800;
pub const GAME_HEIGHT: usize = 600;
pub const TERRAIN_LENGTH: usize = 50; // Number of terrain segments to generate

// Bike entity
pub const Bike = struct {
    x: f32,
    y: f32,
    velocity_x: f32,
    velocity_y: f32,
    rotation: f32,
    fuel: f32,
    is_on_ground: bool,
    audio_system: *audio.AudioSystem,
    tilt_factor: f32, // Added to track manual tilt

    pub fn init(x: f32, y: f32, audio_system: *audio.AudioSystem) Bike {
        return Bike{
            .x = x,
            .y = y,
            .velocity_x = 0,
            .velocity_y = 0,
            .rotation = 0,
            .fuel = INITIAL_FUEL,
            .is_on_ground = false,
            .audio_system = audio_system,
            .tilt_factor = 0,
        };
    }

    pub fn update(self: *Bike, delta_time: f32, terrain: *Terrain) void {
        // Apply gravity if not on ground
        if (!self.is_on_ground) {
            self.velocity_y += GRAVITY * delta_time;
        }

        // Update position
        self.x += self.velocity_x * delta_time;
        self.y += self.velocity_y * delta_time;

        // Check collision with terrain
        const terrain_height = terrain.getHeightAt(self.x);

        // If below terrain, move up to terrain level and stop vertical movement
        if (self.y + WHEEL_SIZE > terrain_height) {
            self.y = terrain_height - WHEEL_SIZE;
            self.velocity_y = 0;
            self.is_on_ground = true;

            // Calculate rotation based on terrain slope
            const next_height = terrain.getHeightAt(self.x + 10);
            const slope = (next_height - terrain_height) / 10.0;
            const terrain_angle = std.math.atan(slope) * (180.0 / std.math.pi);

            // Combine terrain angle with manual tilt
            self.rotation = terrain_angle + self.tilt_factor;

            // Apply physics effects based on tilt
            if (self.tilt_factor < -20.0 and self.velocity_x > 50.0) {
                // Wheelie gives slight boost
                self.velocity_x += 20.0 * delta_time;
            } else if (self.tilt_factor > 20.0 and self.velocity_x > 50.0) {
                // Forward tilt improves downhill speed
                if (terrain_angle < 0) {
                    self.velocity_x += 30.0 * delta_time;
                }
            }

            // Gradually reduce tilt factor when on ground
            self.tilt_factor *= 0.95;
        } else {
            self.is_on_ground = false;

            // In air, tilt affects vertical velocity slightly
            self.velocity_y += self.tilt_factor * delta_time * 5.0;
        }

        // Consume fuel when moving
        if (self.velocity_x > 0) {
            self.fuel -= FUEL_CONSUMPTION_RATE * delta_time * (self.velocity_x / BIKE_MAX_SPEED);
            if (self.fuel < 0) self.fuel = 0;
        }

        // Clamp position to prevent going out of bounds
        self.x = std.math.clamp(self.x, BIKE_SIZE / 2, @as(f32, @floatFromInt(GAME_WIDTH * 5)) - BIKE_SIZE / 2);
        self.y = std.math.clamp(self.y, BIKE_SIZE / 2, @as(f32, @floatFromInt(GAME_HEIGHT)) - BIKE_SIZE / 2);
    }

    pub fn accelerate(self: *Bike, delta_time: f32) void {
        if (self.fuel <= 0) return; // Can't accelerate without fuel

        self.velocity_x += BIKE_ACCELERATION * delta_time;
        if (self.velocity_x > BIKE_MAX_SPEED) self.velocity_x = BIKE_MAX_SPEED;

        // Play engine sound
        if (self.is_on_ground) {
            self.audio_system.playSound(.Jump); // Reuse jump sound for now
        }
    }

    pub fn setTilt(self: *Bike, tilt_amount: f32) void {
        self.tilt_factor = tilt_amount;
    }

    pub fn render(self: Bike, renderer_obj: *renderer.Renderer, camera_x: f32) void {
        const screen_x: usize = @intFromFloat(@max(0, @min(self.x - camera_x, @as(f32, @floatFromInt(GAME_WIDTH - 1)))));
        const screen_y: usize = @intFromFloat(@max(0, @min(self.y, @as(f32, @floatFromInt(GAME_HEIGHT - 1)))));

        // Draw bike body (rectangle)
        const body_width: usize = @intFromFloat(BIKE_SIZE);
        const body_height: usize = @intFromFloat(BIKE_SIZE / 2);

        // Draw bike as a simple shape for now
        renderer_obj.drawRect(screen_x - body_width / 2, screen_y - body_height / 2, body_width, body_height, .{ 255, 0, 0 });

        // Draw wheels
        const wheel_radius: usize = @intFromFloat(WHEEL_SIZE);
        renderer_obj.drawCircle(screen_x - body_width / 3, screen_y + body_height / 2, wheel_radius, .{ 50, 50, 50 });
        renderer_obj.drawCircle(screen_x + body_width / 3, screen_y + body_height / 2, wheel_radius, .{ 50, 50, 50 });
    }
};

// Terrain entity
pub const Terrain = struct {
    heights: []f32,
    length: usize,
    finish_position: f32,

    pub fn init(allocator: std.mem.Allocator, length: usize, seed: u32) !Terrain {
        var heights = try allocator.alloc(f32, length);

        // Generate terrain with hills
        var random_seed = seed;
        var prev_height: f32 = @floatFromInt(GAME_HEIGHT - 100);

        for (0..length) |i| {
            // Simple random number generator
            random_seed = random_seed *% 1664525 +% 1013904223;
            const random_val = @as(f32, @floatFromInt(random_seed % 100)) / 100.0;

            // Gradually vary the height
            const height_change = (random_val - 0.5) * 30.0;
            prev_height += height_change;

            // Add occasional hills
            if (i % 10 == 0 and i > 10) {
                prev_height -= 50.0; // Create a valley before a hill
            } else if (i % 10 == 5 and i > 10) {
                prev_height += 80.0; // Create a hill
            }

            // Ensure height stays within reasonable bounds
            prev_height = std.math.clamp(prev_height, @as(f32, @floatFromInt(GAME_HEIGHT / 2)), @as(f32, @floatFromInt(GAME_HEIGHT - 50)));

            heights[i] = prev_height;
        }

        // Set finish position near the end
        const finish_position = @as(f32, @floatFromInt(length - 5)) * TERRAIN_SEGMENT_WIDTH;

        return Terrain{
            .heights = heights,
            .length = length,
            .finish_position = finish_position,
        };
    }

    pub fn deinit(self: *Terrain, allocator: std.mem.Allocator) void {
        allocator.free(self.heights);
    }

    pub fn getHeightAt(self: Terrain, x: f32) f32 {
        const segment_index = @as(usize, @intFromFloat(x / TERRAIN_SEGMENT_WIDTH));

        if (segment_index >= self.length - 1) {
            return self.heights[self.length - 1];
        }

        // Linear interpolation between points
        const segment_progress = (x - @as(f32, @floatFromInt(segment_index)) * TERRAIN_SEGMENT_WIDTH) / TERRAIN_SEGMENT_WIDTH;
        const height1 = self.heights[segment_index];
        const height2 = self.heights[segment_index + 1];

        return height1 + (height2 - height1) * segment_progress;
    }

    pub fn render(self: Terrain, renderer_obj: *renderer.Renderer, camera_x: f32) void {
        const start_segment = @as(usize, @intFromFloat(camera_x / TERRAIN_SEGMENT_WIDTH));
        const visible_segments = GAME_WIDTH / @as(usize, @intFromFloat(TERRAIN_SEGMENT_WIDTH)) + 2;
        const end_segment = @min(start_segment + visible_segments, self.length - 1);

        // Draw terrain segments
        for (start_segment..end_segment) |i| {
            const x1 = @as(f32, @floatFromInt(i)) * TERRAIN_SEGMENT_WIDTH - camera_x;
            const y1 = self.heights[i];
            const x2 = @as(f32, @floatFromInt(i + 1)) * TERRAIN_SEGMENT_WIDTH - camera_x;
            const y2 = self.heights[i + 1];

            // Draw terrain segment as a filled polygon
            const screen_x1: usize = @intFromFloat(@max(0, @min(x1, @as(f32, @floatFromInt(GAME_WIDTH)))));
            const screen_y1: usize = @intFromFloat(@max(0, @min(y1, @as(f32, @floatFromInt(GAME_HEIGHT)))));
            const screen_x2: usize = @intFromFloat(@max(0, @min(x2, @as(f32, @floatFromInt(GAME_WIDTH)))));
            const screen_y2: usize = @intFromFloat(@max(0, @min(y2, @as(f32, @floatFromInt(GAME_HEIGHT)))));

            // Draw line from (x1,y1) to (x2,y2)
            self.drawLine(renderer_obj, screen_x1, screen_y1, screen_x2, screen_y2, .{ 0, 100, 0 });

            // Fill everything below the line to the bottom of the screen
            const max_y = GAME_HEIGHT;
            const min_y1 = @min(screen_y1, max_y);
            const min_y2 = @min(screen_y2, max_y);

            // Fill the area under the terrain
            for (screen_x1..screen_x2 + 1) |x| {
                // Linear interpolation to find y at this x
                const progress = if (screen_x2 > screen_x1)
                    @as(f32, @floatFromInt(x - screen_x1)) / @as(f32, @floatFromInt(screen_x2 - screen_x1))
                else
                    0.0;

                // Calculate interpolated y position
                const y_float = @as(f32, @floatFromInt(min_y1)) + progress * (@as(f32, @floatFromInt(min_y2)) - @as(f32, @floatFromInt(min_y1)));
                const y = @as(usize, @intFromFloat(y_float));

                // Draw vertical line from terrain to bottom
                for (y..max_y) |py| {
                    renderer_obj.drawPixel(x, py, .{ 139, 69, 19 });
                }
            }
        }

        // Draw finish line
        const finish_x = self.finish_position - camera_x;
        if (finish_x >= 0 and finish_x < GAME_WIDTH) {
            const screen_finish_x: usize = @intFromFloat(finish_x);
            renderer_obj.drawRect(screen_finish_x - 5, 0, 10, GAME_HEIGHT, .{ 255, 255, 255 });
        }
    }

    // Helper function to draw a line
    fn drawLine(self: Terrain, renderer_obj: *renderer.Renderer, x1: usize, y1: usize, x2: usize, y2: usize, color: [3]u8) void {
        _ = self;

        // Bresenham's line algorithm
        const dx: isize = @as(isize, @intCast(x2)) - @as(isize, @intCast(x1));
        const dy: isize = @as(isize, @intCast(y2)) - @as(isize, @intCast(y1));

        const abs_dx = if (dx < 0) -dx else dx;
        const abs_dy = if (dy < 0) -dy else dy;

        var x: isize = @intCast(x1);
        var y: isize = @intCast(y1);

        // Draw first pixel
        renderer_obj.drawPixel(@intCast(@as(usize, @intCast(x))), @intCast(@as(usize, @intCast(y))), color);

        if (abs_dx > abs_dy) {
            // Line is more horizontal than vertical
            var err: isize = @divTrunc(abs_dx, 2);
            const step_y: isize = if (dy < 0) -1 else 1;

            if (dx < 0) {
                // Swap points to always go from left to right
                x = @intCast(x2);
                y = @intCast(y2);

                for (0..@intCast(abs_dx)) |_| {
                    x += 1;
                    err -= abs_dy;
                    if (err < 0) {
                        y -= step_y;
                        err += abs_dx;
                    }
                    renderer_obj.drawPixel(@intCast(@as(usize, @intCast(x))), @intCast(@as(usize, @intCast(y))), color);
                }
            } else {
                for (0..@intCast(abs_dx)) |_| {
                    x += 1;
                    err -= abs_dy;
                    if (err < 0) {
                        y += step_y;
                        err += abs_dx;
                    }
                    renderer_obj.drawPixel(@intCast(@as(usize, @intCast(x))), @intCast(@as(usize, @intCast(y))), color);
                }
            }
        } else {
            // Line is more vertical than horizontal
            var err: isize = @divTrunc(abs_dy, 2);
            const step_x: isize = if (dx < 0) -1 else 1;

            if (dy < 0) {
                // Swap points to always go from top to bottom
                x = @intCast(x2);
                y = @intCast(y2);

                for (0..@intCast(abs_dy)) |_| {
                    y += 1;
                    err -= abs_dx;
                    if (err < 0) {
                        x -= step_x;
                        err += abs_dy;
                    }
                    renderer_obj.drawPixel(@intCast(@as(usize, @intCast(x))), @intCast(@as(usize, @intCast(y))), color);
                }
            } else {
                for (0..@intCast(abs_dy)) |_| {
                    y += 1;
                    err -= abs_dx;
                    if (err < 0) {
                        x += step_x;
                        err += abs_dy;
                    }
                    renderer_obj.drawPixel(@intCast(@as(usize, @intCast(x))), @intCast(@as(usize, @intCast(y))), color);
                }
            }
        }
    }
};
