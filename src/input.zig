const std = @import("std");

/// Key codes that match JavaScript key codes
pub const KeyCode = enum(u8) {
    // Arrow keys
    ArrowRight = 39,
    ArrowLeft = 37,
    ArrowUp = 38,
    ArrowDown = 40,

    // Letters
    KeyA = 65,
    KeyB = 66,
    KeyC = 67,
    KeyD = 68,
    KeyE = 69,
    KeyF = 70,
    KeyG = 71,
    KeyH = 72,
    KeyI = 73,
    KeyJ = 74,
    KeyK = 75,
    KeyL = 76,
    KeyM = 77,
    KeyN = 78,
    KeyO = 79,
    KeyP = 80,
    KeyQ = 81,
    KeyR = 82,
    KeyS = 83,
    KeyT = 84,
    KeyU = 85,
    KeyV = 86,
    KeyW = 87,
    KeyX = 88,
    KeyY = 89,
    KeyZ = 90,

    // Numbers (top row)
    Digit0 = 48,
    Digit1 = 49,
    Digit2 = 50,
    Digit3 = 51,
    Digit4 = 52,
    Digit5 = 53,
    Digit6 = 54,
    Digit7 = 55,
    Digit8 = 56,
    Digit9 = 57,

    // Special keys
    Space = 32,
    Enter = 13,
    Tab = 9,
    Escape = 27,
    Backspace = 8,
    Delete = 46,
    Insert = 45,
    Home = 36,
    End = 35,
    PageUp = 33,
    PageDown = 34,

    // Modifier keys
    ShiftLeft = 16,
    ControlLeft = 17,
    AltLeft = 18,
    MetaLeft = 91, // Windows/Command key
    ShiftRight = 19,
    ControlRight = 20,
    AltRight = 21,
    MetaRight = 92,

    // Function keys
    F1 = 112,
    F2 = 113,
    F3 = 114,
    F4 = 115,
    F5 = 116,
    F6 = 117,
    F7 = 118,
    F8 = 119,
    F9 = 120,
    F10 = 121,
    F11 = 122,
    F12 = 123,

    // Mouse buttons (using high values to avoid conflicts)
    MouseLeft = 200,
    MouseMiddle = 201,
    MouseRight = 202,
    MouseBack = 203,
    MouseForward = 204,

    // Touch events (using high values to avoid conflicts)
    TouchPrimary = 210,
    TouchSecondary = 211,

    pub fn fromU8(value: u8) ?KeyCode {
        return std.meta.intToEnum(KeyCode, value) catch null;
    }

    pub fn isMouseButton(self: KeyCode) bool {
        return switch (self) {
            .MouseLeft, .MouseMiddle, .MouseRight, .MouseBack, .MouseForward => true,
            else => false,
        };
    }

    pub fn isTouchEvent(self: KeyCode) bool {
        return switch (self) {
            .TouchPrimary, .TouchSecondary => true,
            else => false,
        };
    }
};

/// Input action types
pub const InputAction = enum(u8) {
    Press,
    Release,
    Move, // For mouse/touch movement
    Scroll, // For mouse wheel
};

/// Mouse/Touch position data
pub const PointerData = struct {
    x: f32,
    y: f32,
    delta_x: f32 = 0,
    delta_y: f32 = 0,
    scroll_x: f32 = 0,
    scroll_y: f32 = 0,
};

/// Input state tracking using bitsets and pointer data
pub const InputState = struct {
    // Use a u256 bitset to track key states (1 = pressed, 0 = released)
    // This gives us plenty of room for all keys, mouse buttons, and touch events
    key_states: std.bit_set.IntegerBitSet(256),

    // Track the last known pointer position
    pointer: PointerData,

    pub fn init() InputState {
        return .{
            .key_states = std.bit_set.IntegerBitSet(256).initEmpty(),
            .pointer = PointerData{
                .x = 0,
                .y = 0,
            },
        };
    }

    pub fn isKeyPressed(self: *const InputState, key: KeyCode) bool {
        return self.key_states.isSet(@intFromEnum(key));
    }

    pub fn setKeyState(self: *InputState, key: KeyCode, is_pressed: bool) void {
        const bit = @intFromEnum(key);
        if (is_pressed) {
            self.key_states.set(bit);
        } else {
            self.key_states.unset(bit);
        }
    }

    pub fn updatePointer(self: *InputState, x: f32, y: f32) void {
        // Calculate delta from last position
        const delta_x = x - self.pointer.x;
        const delta_y = y - self.pointer.y;

        // Update pointer data
        self.pointer = .{
            .x = x,
            .y = y,
            .delta_x = delta_x,
            .delta_y = delta_y,
            .scroll_x = self.pointer.scroll_x,
            .scroll_y = self.pointer.scroll_y,
        };
    }

    pub fn updateScroll(self: *InputState, x: f32, y: f32) void {
        self.pointer.scroll_x = x;
        self.pointer.scroll_y = y;
    }

    pub fn getPointerPosition(self: *const InputState) PointerData {
        return self.pointer;
    }

    pub fn reset(self: *InputState) void {
        self.key_states = std.bit_set.IntegerBitSet(256).initEmpty();
        self.pointer = PointerData{
            .x = 0,
            .y = 0,
        };
    }
};
