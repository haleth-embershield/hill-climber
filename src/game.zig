const std = @import("std");
const models = @import("models.zig");
const renderer = @import("renderer/core.zig");
const audio = @import("audio.zig");
const camera = @import("renderer/camera.zig");

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
    truck: models.truck,
    terrain: models.Terrain,
    camera_x: f32,
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
    right_key_pressed: bool,
    left_key_pressed: bool,
    up_key_pressed: bool,
    down_key_pressed: bool,
    // Audio state
    is_muted: bool,
    alloc: std.mem.Allocator,
    width: u32,
    height: u32,
    game_over: bool,
    show_menu: bool,
    menu_selection: u32,
    camera: *camera.Camera,

    pub fn init(alloc: std.mem.Allocator, width: u32, height: u32) !Game {
        // Initialize audio system
        var audio_system = audio.AudioSystem.init();

        // Initialize truck with starting position and audio system
        const truck_instance = models.truck.init(50.0, 50.0, &audio_system);

        // Initialize renderer
        var game_renderer = try renderer.Renderer.init(alloc, width, height);
        try game_renderer.setupScene();

        // Initialize camera - allocate memory for it
        const camera_ptr = try alloc.create(camera.Camera);
        camera_ptr.* = camera.Camera.init();

        // Initialize terrain
        const terrain_instance = try models.Terrain.init(alloc, models.TERRAIN_LENGTH, 12345);

        return Game{
            .alloc = alloc,
            .width = width,
            .height = height,
            .truck = truck_instance,
            .renderer = game_renderer,
            .camera = camera_ptr,
            .score = 0,
            .game_over = false,
            .show_menu = true,
            .menu_selection = 0,
            .state = GameState.Menu,
            .terrain = terrain_instance,
            .camera_x = 0,
            .high_score = 0,
            .random_seed = 12345,
            .audio_system = audio_system,
            .menu_render_timer = 0,
            .pause_render_timer = 0,
            .gameover_render_timer = 0,
            .victory_render_timer = 0,
            .right_key_pressed = false,
            .left_key_pressed = false,
            .up_key_pressed = false,
            .down_key_pressed = false,
            .is_muted = false,
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

    pub fn reset(self: *Game, alloc: std.mem.Allocator) !void {
        // Update high score if needed
        if (self.score > self.high_score) {
            self.high_score = self.score;
        }

        // Deinitialize old terrain
        self.terrain.deinit(alloc);

        // Create new terrain with different seed
        self.random_seed += 1;
        self.terrain = try models.Terrain.init(alloc, models.TERRAIN_LENGTH, self.random_seed);

        // Reset Truck to starting position
        self.truck = models.truck.init(models.truck_SIZE * 2, models.GAME_HEIGHT / 2, &self.audio_system);

        // Reset camera and score
        self.camera_x = 0;
        self.score = 0;
        self.state = GameState.Playing;

        // Reset render timers
        self.menu_render_timer = 0;
        self.pause_render_timer = 0;
        self.gameover_render_timer = 0;
        self.victory_render_timer = 0;

        // Reset input state
        self.right_key_pressed = false;
        self.left_key_pressed = false;
        self.up_key_pressed = false;
        self.down_key_pressed = false;
    }

    pub fn update(self: *Game, delta_time: f32) void {
        // Cap delta time to prevent large jumps
        const capped_delta = @min(delta_time, 0.05);

        if (self.state == GameState.Menu) {
            // Only redraw menu occasionally to save performance
            self.menu_render_timer += capped_delta;
            self.renderMenu();
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
        if (self.right_key_pressed) {
            self.truck.accelerate(capped_delta);
        } else if (self.left_key_pressed) {
            // Apply brakes
            self.truck.velocity_x *= 0.95;
        } else {
            // Apply normal friction when not accelerating
            self.truck.velocity_x *= 0.98;
        }

        // Handle tilt controls
        if (self.up_key_pressed) {
            // Tilt truck backward (wheelie)
            self.truck.setTilt(-30.0);
        } else if (self.down_key_pressed) {
            // Tilt truck forward
            self.truck.setTilt(30.0);
        } else if (!self.up_key_pressed and !self.down_key_pressed) {
            // Return to neutral tilt gradually
            self.truck.setTilt(self.truck.tilt_factor * 0.8);
        }

        // Update truck
        self.truck.update(capped_delta, &self.terrain);

        // Update camera to follow truck
        if (self.truck.x > self.camera_x + models.GAME_WIDTH / 3) {
            self.camera_x = self.truck.x - models.GAME_WIDTH / 3;
        }

        // Check for out of fuel
        if (self.truck.fuel <= 0 and self.truck.velocity_x < 1.0) {
            self.gameOver();
            return;
        }

        // Check for reaching finish line
        if (self.truck.x >= self.terrain.finish_position) {
            self.victory();
            return;
        }

        // Update score based on distance traveled
        self.score = @intFromFloat(self.truck.x / 100.0);

        // Begin frame with a sky blue background
        self.renderer.beginFrame([_]u8{ 135, 206, 235 });

        // Render the 3D scene
        self.renderer.renderScene();

        // Finish frame
        self.renderer.endFrame();
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
        // Clear the screen with sky blue
        self.renderer.beginFrame(.{ 135, 206, 235 });

        // Draw terrain
        self.terrain.render(&self.renderer, self.camera_x);

        // Draw truck
        self.truck.render(&self.renderer, self.camera_x);

        // Draw HUD
        self.renderHUD();

        // Draw game state overlays
        if (self.state == GameState.GameOver) {
            self.renderGameOver();
        } else if (self.state == GameState.Paused) {
            self.renderPaused();
        } else if (self.state == GameState.Victory) {
            self.renderVictory();
        }

        // End frame
        self.renderer.endFrame();
    }

    fn renderHUD(self: *Game) void {
        // Draw fuel gauge
        const fuel_width = @as(usize, @intFromFloat(self.truck.fuel * 2.0));
        self.renderer.drawRect(10, 10, fuel_width, 20, .{ 255, 215, 0 });
        self.renderer.drawRect(10, 10, 200, 1, .{ 0, 0, 0 }); // Top border
        self.renderer.drawRect(10, 30, 200, 1, .{ 0, 0, 0 }); // Bottom border
        self.renderer.drawRect(10, 10, 1, 20, .{ 0, 0, 0 }); // Left border
        self.renderer.drawRect(210, 10, 1, 20, .{ 0, 0, 0 }); // Right border

        // Draw score
        const score_x = models.GAME_WIDTH - 100;
        self.renderer.drawRect(score_x, 10, 90, 20, .{ 0, 0, 0 });
        self.renderer.drawRect(score_x + 1, 11, 88, 18, .{ 255, 255, 255 });

        // Draw mute indicator if muted
        if (self.is_muted) {
            self.renderer.drawRect(models.GAME_WIDTH - 30, 40, 20, 20, .{ 255, 0, 0 });
        }
    }

    fn renderMenu(self: *Game) void {
        if (self.menu_render_timer < 0.1) return; // Redraw menu at 10 FPS
        self.menu_render_timer = 0;

        // Clear the screen with sky blue
        self.renderer.beginFrame(.{ 135, 206, 235 });

        // Draw a sample terrain
        self.terrain.render(&self.renderer, 0);

        // Draw a sample truck in the center
        const truck = models.truck.init(models.GAME_WIDTH / 2, models.GAME_HEIGHT / 2, &self.audio_system);
        truck.render(&self.renderer, 0);

        // End frame
        self.renderer.endFrame();
    }

    fn renderGameOver(self: *Game) void {
        // Draw semi-transparent overlay
        for (0..models.GAME_WIDTH) |x| {
            for (0..models.GAME_HEIGHT) |y| {
                if ((x + y) % 2 == 0) { // Checkerboard pattern
                    self.renderer.drawPixel(x, y, .{ 0, 0, 0 });
                }
            }
        }
    }

    fn renderPaused(self: *Game) void {
        // Draw semi-transparent overlay
        for (0..models.GAME_WIDTH) |x| {
            for (0..models.GAME_HEIGHT) |y| {
                if ((x + y) % 4 == 0) { // Sparse pattern
                    self.renderer.drawPixel(x, y, .{ 0, 0, 0 });
                }
            }
        }
    }

    fn renderVictory(self: *Game) void {
        // Draw semi-transparent overlay
        for (0..models.GAME_WIDTH) |x| {
            for (0..models.GAME_HEIGHT) |y| {
                if ((x + y) % 3 == 0) { // Different pattern
                    self.renderer.drawPixel(x, y, .{ 255, 215, 0 }); // Gold color
                }
            }
        }
    }

    pub fn handleJump(self: *Game) void {
        if (self.state == GameState.Menu) {
            // Start game if in menu
            self.state = GameState.Playing;
            // Reset render timers
            self.menu_render_timer = 0;
            self.pause_render_timer = 0;
            self.gameover_render_timer = 0;
            self.victory_render_timer = 0;
            return;
        }

        if (self.state == GameState.Paused) {
            // Resume game if paused
            self.state = GameState.Playing;
            // Reset render timers
            self.pause_render_timer = 0;
            return;
        }

        if (self.state == GameState.GameOver or self.state == GameState.Victory) {
            // Reset game if game over or victory
            // Reset render timers
            self.gameover_render_timer = 0;
            self.victory_render_timer = 0;
            _ = self.reset(std.heap.page_allocator) catch {
                // Handle error
                return;
            };
            return;
        }
    }

    // Input handlers for directional controls
    pub fn handleRightKeyDown(self: *Game) void {
        if (self.state == GameState.Playing) {
            self.right_key_pressed = true;
        }
    }

    pub fn handleRightKeyUp(self: *Game) void {
        self.right_key_pressed = false;
    }

    pub fn handleLeftKeyDown(self: *Game) void {
        if (self.state == GameState.Playing) {
            self.left_key_pressed = true;
        }
    }

    pub fn handleLeftKeyUp(self: *Game) void {
        self.left_key_pressed = false;
    }

    pub fn handleUpKeyDown(self: *Game) void {
        if (self.state == GameState.Playing) {
            self.up_key_pressed = true;
        }
    }

    pub fn handleUpKeyUp(self: *Game) void {
        self.up_key_pressed = false;
    }

    pub fn handleDownKeyDown(self: *Game) void {
        if (self.state == GameState.Playing) {
            self.down_key_pressed = true;
        }
    }

    pub fn handleDownKeyUp(self: *Game) void {
        self.down_key_pressed = false;
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
        self.terrain.deinit(alloc);
        self.renderer.deinit(alloc);
    }
};
