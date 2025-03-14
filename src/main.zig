// A simple Hill Climber game built with Zig v0.14 targeting WebAssembly.

const std = @import("std");
const game_mod = @import("game.zig");
const models = @import("models.zig");
const renderer = @import("renderer/core.zig");
const audio = @import("audio.zig");
const input = @import("input.zig");

// WASM imports for browser interaction
extern "env" fn consoleLog(ptr: [*]const u8, len: usize) void;

// Global state
var allocator: std.mem.Allocator = undefined;
var game: game_mod.Game = undefined;

// Helper to log strings to browser console
fn logString(msg: []const u8) void {
    consoleLog(msg.ptr, msg.len);
}

// Initialize the WASM module
export fn init() void {
    // Initialize allocator
    allocator = std.heap.page_allocator;

    // Initialize game data
    game = game_mod.Game.init(allocator, models.GAME_WIDTH, models.GAME_HEIGHT) catch {
        logString("Failed to initialize game");
        return;
    };

    logString("Hill Climber initialized");
}

// Start or reset the game
export fn resetGame() void {
    _ = game.reset(allocator) catch {
        logString("Failed to reset game");
        return;
    };
    logString("Game reset");
}

// Update animation frame
export fn update(delta_time: f32) void {
    game.update(delta_time);
}

// Unified input handler for keyboard, mouse, and touch events
export fn handleInput(key_code: u8, is_press: bool) void {
    if (input.KeyCode.fromU8(key_code)) |key| {
        const action: input.InputAction = if (is_press) .Press else .Release;
        game.handleInput(key, action);
    }
}

// Handle pointer (mouse/touch) movement
export fn handlePointerMove(x: f32, y: f32) void {
    game.handlePointerMove(x, y);
}

// Handle pointer (mouse/touch) action
export fn handlePointerAction(button: u8, is_press: bool, x: f32, y: f32) void {
    if (input.KeyCode.fromU8(button)) |key| {
        if (key.isMouseButton() or key.isTouchEvent()) {
            const action: input.InputAction = if (is_press) .Press else .Release;
            game.handlePointerInput(key, action, x, y);
        }
    }
}

// Handle scroll wheel
export fn handleScroll(x: f32, y: f32) void {
    game.handleScroll(x, y);
}

// Clean up resources when the module is unloaded
export fn deinit() void {
    game.deinit(allocator);
    logString("Game resources freed");
}
