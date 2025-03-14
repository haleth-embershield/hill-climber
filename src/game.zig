const std = @import("std");
const models = @import("models.zig");
const renderer = @import("renderer/core.zig");
const audio = @import("audio.zig");
const camera = @import("renderer/camera.zig");
const mesh = @import("renderer/mesh.zig");
const input = @import("input.zig");

// Game state enum
pub const GameState = enum {
    Menu,
    Playing,
    Paused,
    GameOver,
    Victory,
};

// Game data structure
pub const Game = struct {
    state: GameState,
    score: u32,
    high_score: u32,
    random_seed: u32,
    // Rendering resources
    renderer: renderer.Renderer,
    // Audio system
    audio_system: audio.AudioSystem,
    // Performance optimization timers
    menu_render_timer: f32,
    pause_render_timer: f32,
    gameover_render_timer: f32,
    victory_render_timer: f32,
    // Input state
    input_state: input.InputState,
    // Audio state
    is_muted: bool,
    alloc: std.mem.Allocator,
    width: u32,
    height: u32,
    game_over: bool,
    show_menu: bool,
    menu_selection: u32,
    camera: *camera.Camera,

    // Game objects
    truck: models.Vehicle,
    terrain: models.Terrain,

    pub fn init(alloc: std.mem.Allocator, width: u32, height: u32) !Game {
        // Initialize audio system
        const audio_system = audio.AudioSystem.init();

        // Initialize renderer
        var game_renderer = try renderer.Renderer.init(alloc, width, height);

        // Set up shaders and other rendering resources
        try game_renderer.setupScene();

        // Initialize camera - allocate memory for it
        const camera_ptr = try alloc.create(camera.Camera);
        camera_ptr.* = camera.Camera.init();

        // Create meshes
        // Truck mesh
        const body_color = [_]f32{ 0.8, 0.2, 0.2, 1.0 }; // Red
        const wheel_color = [_]f32{ 0.2, 0.2, 0.2, 1.0 }; // Dark gray
        var truck_mesh = try mesh.createTruck(alloc, body_color, wheel_color);
        defer truck_mesh.deinit();

        // Terrain mesh
        const terrain_color = [_]f32{ 0.3, 0.7, 0.3, 1.0 }; // Green
        var terrain_mesh = try mesh.createHill(alloc, 10.0, 10.0, 3.0, 20, terrain_color);
        defer terrain_mesh.deinit();

        // Add meshes to renderer
        const truck_handle = try game_renderer.addMesh(truck_mesh);
        const terrain_handle = try game_renderer.addMesh(terrain_mesh);

        // Create game objects
        const truck = models.Vehicle.init(truck_handle);
        const terrain = models.Terrain.init(terrain_handle, 10.0, 10.0, 3.0);

        // Set initial truck position
        var truck_instance = truck;
        truck_instance.model.setPosition(0.0, 0.0, 0.0);
        truck_instance.is_on_ground = true; // Set truck as already on ground

        return Game{
            .alloc = alloc,
            .width = width,
            .height = height,
            .renderer = game_renderer,
            .camera = camera_ptr,
            .score = 0,
            .game_over = false,
            .show_menu = true,
            .menu_selection = 0,
            .state = GameState.Menu,
            .high_score = 0,
            .random_seed = 12345,
            .audio_system = audio_system,
            .menu_render_timer = 0,
            .pause_render_timer = 0,
            .gameover_render_timer = 0,
            .victory_render_timer = 0,
            .input_state = input.InputState.init(),
            .is_muted = false,
            .truck = truck_instance,
            .terrain = terrain,
        };
    }

    // Simple random number generator
    fn random(self: *Game) u32 {
        self.random_seed = self.random_seed *% 1664525 +% 1013904223;
        return self.random_seed;
    }

    // Get random value in range [min, max)
    fn randomInRange(self: *Game, min: u32, max: u32) u32 {
        return min + (self.random() % (max - min));
    }

    pub fn reset(self: *Game, _: std.mem.Allocator) !void {
        // Update high score if needed
        if (self.score > self.high_score) {
            self.high_score = self.score;
        }

        // Reset truck to starting position
        self.truck.model.setPosition(0.0, 0.0, 0.0);
        self.truck.model.setRotation(0.0, 0.0, 0.0);
        self.truck.velocity = [_]f32{ 0.0, 0.0, 0.0 };
        self.truck.fuel = models.INITIAL_FUEL;

        // Reset score
        self.score = 0;
        self.state = GameState.Playing;

        // Reset render timers
        self.menu_render_timer = 0;
        self.pause_render_timer = 0;
        self.gameover_render_timer = 0;
        self.victory_render_timer = 0;

        // Reset input state
        self.input_state.reset();
    }

    pub fn update(self: *Game, delta_time: f32) void {
        // Cap delta time to prevent large jumps
        const capped_delta = @min(delta_time, 0.05);

        if (self.state == GameState.Menu) {
            // Only redraw menu occasionally to save performance
            self.menu_render_timer += capped_delta;
            if (self.menu_render_timer >= 0.1) { // Redraw at 10 FPS
                self.menu_render_timer = 0;
                self.renderMenu();
            }
            return;
        }

        if (self.state == GameState.Victory) {
            // Update victory screen
            self.victory_render_timer += capped_delta;
            if (self.victory_render_timer >= 0.2) { // Redraw at 5 FPS
                self.victory_render_timer = 0;
                self.renderGame();
            }
            return;
        }

        if (self.state != GameState.Playing) {
            // Update timers for other states
            if (self.state == GameState.GameOver) {
                self.gameover_render_timer += capped_delta;
                if (self.gameover_render_timer >= 0.2) { // Redraw at 5 FPS
                    self.gameover_render_timer = 0;
                    self.renderGame();
                }
            } else if (self.state == GameState.Paused) {
                self.pause_render_timer += capped_delta;
                if (self.pause_render_timer >= 0.5) { // Redraw at 2 FPS
                    self.pause_render_timer = 0;
                    self.renderGame();
                }
            }
            return;
        }

        // Handle input for truck movement
        const right_pressed = self.input_state.isKeyPressed(.ArrowRight) or self.input_state.isKeyPressed(.KeyD);
        const left_pressed = self.input_state.isKeyPressed(.ArrowLeft) or self.input_state.isKeyPressed(.KeyA);
        const up_pressed = self.input_state.isKeyPressed(.ArrowUp) or self.input_state.isKeyPressed(.KeyW);
        const down_pressed = self.input_state.isKeyPressed(.ArrowDown) or self.input_state.isKeyPressed(.KeyS);

        if (right_pressed) {
            // Accelerate forward
            const forward_dir = [_]f32{ 1.0, 0.0, 0.0 };
            self.truck.accelerate(forward_dir, models.truck_ACCELERATION, capped_delta);

            // Make sure camera follows immediately when accelerating
            const camera_offset = [_]f32{ 14.43, 14.43, 14.43 };
            self.camera.followTarget(self.truck.model.position, camera_offset);
        } else if (left_pressed) {
            // Apply brakes
            self.truck.velocity[0] *= 0.95;
        } else {
            // Apply normal friction when not accelerating
            self.truck.velocity[0] *= 0.98;
        }

        // Handle tilt controls
        if (up_pressed) {
            // Tilt truck backward (wheelie)
            self.truck.model.rotation[0] = -30.0;
        } else if (down_pressed) {
            // Tilt truck forward
            self.truck.model.rotation[0] = 30.0;
        } else if (!up_pressed and !down_pressed) {
            // Return to neutral tilt gradually
            self.truck.model.rotation[0] *= 0.8;
        }

        // Update truck physics
        self.truck.update(capped_delta);

        // Always ensure camera follows truck after position update
        // Use a fixed offset for isometric view
        const camera_offset = [_]f32{ 14.43, 14.43, 14.43 };
        self.camera.followTarget(self.truck.model.position, camera_offset);

        // Check for out of fuel
        if (self.truck.fuel <= 0 and self.truck.velocity[0] < 1.0) {
            self.gameOver();
            return;
        }

        // Update score based on distance traveled
        self.score = @intFromFloat(self.truck.model.position[0] / 10.0);

        // Update renderer with current object states
        self.truck.updateRenderer(&self.renderer);
        self.terrain.updateRenderer(&self.renderer);

        // Render the game
        self.renderGame();
    }

    fn gameOver(self: *Game) void {
        if (self.state == GameState.GameOver) return;

        self.state = GameState.GameOver;
        if (!self.is_muted) {
            self.audio_system.playSound(.Fail);
        }

        // Update high score if needed
        if (self.score > self.high_score) {
            self.high_score = self.score;
        }
    }

    fn victory(self: *Game) void {
        if (self.state == GameState.Victory) return;

        self.state = GameState.Victory;
        if (!self.is_muted) {
            self.audio_system.playSound(.Jump); // Reuse jump sound for victory
        }

        // Update high score if needed
        if (self.score > self.high_score) {
            self.high_score = self.score;
        }
    }

    fn renderGame(self: *Game) void {
        // Update camera to follow the truck
        const camera_offset = [_]f32{ 14.43, 14.43, 14.43 }; // Isometric view offset
        self.camera.followTarget(self.truck.model.position, camera_offset);

        // Make sure the camera's view matrix is updated
        self.camera.updateViewMatrix();

        // Clear the screen with sky blue
        self.renderer.beginFrame(.{ 135, 206, 235 });

        // Render the 3D scene
        self.renderer.renderScene();

        // End frame
        self.renderer.endFrame();
    }

    fn renderMenu(self: *Game) void {
        // Position camera for menu view
        const menu_position = [_]f32{ 0.0, 0.0, 0.0 }; // Center position
        const camera_offset = [_]f32{ 14.43, 14.43, 14.43 }; // Isometric view offset
        self.camera.followTarget(menu_position, camera_offset);

        // Clear the screen with sky blue
        self.renderer.beginFrame(.{ 135, 206, 235 });

        // Render a static scene for the menu
        self.renderer.renderScene();

        // End frame
        self.renderer.endFrame();
    }

    /// Handle input events from JavaScript
    pub fn handleInput(self: *Game, key: input.KeyCode, action: input.InputAction) void {
        // Update input state
        self.input_state.setKeyState(key, action == .Press);

        // Handle special keys that trigger immediate actions
        if (action == .Press) {
            switch (key) {
                .KeyR => {
                    _ = self.reset(self.alloc) catch {};
                },
                .KeyP => {
                    self.togglePause();
                },
                .KeyM => {
                    self.toggleMute();
                },
                .Space => {
                    if (self.state == .GameOver) {
                        _ = self.reset(self.alloc) catch {};
                    }
                },
                else => {},
            }
        }
    }

    /// Handle pointer (mouse/touch) movement
    pub fn handlePointerMove(self: *Game, x: f32, y: f32) void {
        self.input_state.updatePointer(x, y);
    }

    /// Handle pointer (mouse/touch) input events
    pub fn handlePointerInput(self: *Game, key: input.KeyCode, action: input.InputAction, x: f32, y: f32) void {
        // Update pointer position
        self.input_state.updatePointer(x, y);

        // Update input state for the button/touch
        self.input_state.setKeyState(key, action == .Press);

        // Handle specific pointer actions based on game state
        if (action == .Press) {
            switch (self.state) {
                .Menu => {
                    // Handle menu selection
                    if (key == .MouseLeft or key == .TouchPrimary) {
                        self.handleMenuClick(x, y);
                    }
                },
                .GameOver => {
                    // Restart game on click when game over
                    if (key == .MouseLeft or key == .TouchPrimary) {
                        _ = self.reset(self.alloc) catch {};
                    }
                },
                else => {},
            }
        }
    }

    /// Handle scroll wheel input
    pub fn handleScroll(self: *Game, x: f32, y: f32) void {
        self.input_state.updateScroll(x, y);
    }

    /// Handle menu click/touch
    fn handleMenuClick(self: *Game, x: f32, y: f32) void {
        // TODO: Implement real menu click handling when a menu is implemented *in* webgl (not html)
        // Basic menu hit testing
        if (y < @as(f32, @floatFromInt(self.height)) / 2.0) {
            // Start game when clicking upper half
            _ = self.reset(self.alloc) catch {};
        }
        if (x < @as(f32, @floatFromInt(self.width)) / 2.0) {
            // Start game when clicking right half
            _ = self.reset(self.alloc) catch {};
        }
    }

    pub fn togglePause(self: *Game) void {
        if (self.state == GameState.Playing) {
            self.state = GameState.Paused;
            self.pause_render_timer = 0;
        } else if (self.state == GameState.Paused) {
            self.state = GameState.Playing;
        }
    }

    pub fn toggleMute(self: *Game) void {
        self.is_muted = !self.is_muted;
    }

    pub fn deinit(self: *Game, alloc: std.mem.Allocator) void {
        self.renderer.deinit(alloc);
        alloc.destroy(self.camera);
    }
};
