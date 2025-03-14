const std = @import("std");
const renderer = @import("renderer/core.zig");
const audio = @import("audio.zig");
const mesh = @import("renderer/mesh.zig");

// Game constants
pub const GRAVITY: f32 = 9.81;
pub const truck_ACCELERATION: f32 = 5.0;
pub const truck_MAX_SPEED: f32 = 20.0;
pub const FUEL_CONSUMPTION_RATE: f32 = 0.5; // Fuel units per second
pub const INITIAL_FUEL: f32 = 100.0;

// Game dimensions
pub const GAME_WIDTH: usize = 800;
pub const GAME_HEIGHT: usize = 600;

// Model types
pub const ModelType = enum {
    Truck,
    Terrain,
    Obstacle,
};

// 3D Model structure
pub const Model = struct {
    mesh_handle: u32,
    position: [3]f32,
    rotation: [3]f32,
    scale: [3]f32,
    model_type: ModelType,

    pub fn init(mesh_handle: u32, model_type: ModelType) Model {
        return Model{
            .mesh_handle = mesh_handle,
            .position = [_]f32{ 0.0, 0.0, 0.0 },
            .rotation = [_]f32{ 0.0, 0.0, 0.0 },
            .scale = [_]f32{ 1.0, 1.0, 1.0 },
            .model_type = model_type,
        };
    }

    pub fn setPosition(self: *Model, x: f32, y: f32, z: f32) void {
        self.position = [_]f32{ x, y, z };
    }

    pub fn setRotation(self: *Model, x: f32, y: f32, z: f32) void {
        self.rotation = [_]f32{ x, y, z };
    }

    pub fn setScale(self: *Model, x: f32, y: f32, z: f32) void {
        self.scale = [_]f32{ x, y, z };
    }

    pub fn updateRenderer(self: Model, renderer_obj: *renderer.Renderer) void {
        renderer_obj.updateModelMatrix(self.mesh_handle, self.position, self.rotation, self.scale);
    }
};

// Vehicle data
pub const Vehicle = struct {
    model: Model,
    velocity: [3]f32,
    fuel: f32,
    is_on_ground: bool,

    pub fn init(mesh_handle: u32) Vehicle {
        return Vehicle{
            .model = Model.init(mesh_handle, .Truck),
            .velocity = [_]f32{ 0.0, 0.0, 0.0 },
            .fuel = INITIAL_FUEL,
            .is_on_ground = false,
        };
    }

    pub fn update(self: *Vehicle, delta_time: f32) void {
        // Apply physics
        self.model.position[0] += self.velocity[0] * delta_time;
        self.model.position[1] += self.velocity[1] * delta_time;
        self.model.position[2] += self.velocity[2] * delta_time;

        // Apply gravity if not on ground
        if (!self.is_on_ground) {
            self.velocity[1] -= GRAVITY * delta_time;
        }

        // Consume fuel when moving
        if (std.math.sqrt(self.velocity[0] * self.velocity[0] +
            self.velocity[2] * self.velocity[2]) > 0.1)
        {
            self.fuel -= FUEL_CONSUMPTION_RATE * delta_time;
            if (self.fuel < 0.0) self.fuel = 0.0;
        }

        // Simple ground collision
        if (self.model.position[1] < 0.0) {
            self.model.position[1] = 0.0;
            self.velocity[1] = 0.0;
            self.is_on_ground = true;
        } else if (self.model.position[1] > 0.0) {
            // If somehow above ground, apply gravity
            self.is_on_ground = false;
        }
    }

    pub fn accelerate(self: *Vehicle, direction: [3]f32, force: f32, delta_time: f32) void {
        if (self.fuel <= 0.0) return;

        // Normalize direction
        const length = std.math.sqrt(direction[0] * direction[0] +
            direction[1] * direction[1] +
            direction[2] * direction[2]);

        if (length > 0.001) {
            const normalized = [_]f32{
                direction[0] / length,
                direction[1] / length,
                direction[2] / length,
            };

            // Apply acceleration
            self.velocity[0] += normalized[0] * force * delta_time;
            self.velocity[1] += normalized[1] * force * delta_time;
            self.velocity[2] += normalized[2] * force * delta_time;

            // Cap speed
            const speed = std.math.sqrt(self.velocity[0] * self.velocity[0] +
                self.velocity[1] * self.velocity[1] +
                self.velocity[2] * self.velocity[2]);

            if (speed > truck_MAX_SPEED) {
                const scale = truck_MAX_SPEED / speed;
                self.velocity[0] *= scale;
                self.velocity[1] *= scale;
                self.velocity[2] *= scale;
            }
        }
    }

    pub fn updateRenderer(self: Vehicle, renderer_obj: *renderer.Renderer) void {
        self.model.updateRenderer(renderer_obj);
    }
};

// Terrain data
pub const Terrain = struct {
    model: Model,
    width: f32,
    depth: f32,
    height_scale: f32,

    pub fn init(mesh_handle: u32, width: f32, depth: f32, height_scale: f32) Terrain {
        var terrain = Terrain{
            .model = Model.init(mesh_handle, .Terrain),
            .width = width,
            .depth = depth,
            .height_scale = height_scale,
        };

        // Set initial position and scale
        terrain.model.setPosition(0.0, 0.0, 0.0);
        terrain.model.setScale(1.0, 1.0, 1.0);

        return terrain;
    }

    pub fn updateRenderer(self: Terrain, renderer_obj: *renderer.Renderer) void {
        self.model.updateRenderer(renderer_obj);
    }
};
