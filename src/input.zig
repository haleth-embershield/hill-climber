const std = @import("std");

/// Key codes that match JavaScript key codes
pub const KeyCode = enum(u8) {
    ArrowRight = 39,
    ArrowLeft = 37,
    ArrowUp = 38,
    ArrowDown = 40,
    KeyD = 68,
    KeyA = 65,
    KeyW = 87,
    KeyS = 83,
    KeyR = 82,
    KeyP = 80,
    KeyM = 77,
    Space = 32,

    pub fn fromU8(value: u8) ?KeyCode {
        return std.meta.intToEnum(KeyCode, value) catch null;
    }
};

/// Input action types
pub const InputAction = enum(u8) {
    Press,
    Release,
};

/// Input state tracking using a simple bitset
pub const InputState = struct {
    // Use a u64 bitset to track key states (1 = pressed, 0 = released)
    key_states: u64,

    pub fn init() InputState {
        return .{
            .key_states = 0,
        };
    }

    pub fn isKeyPressed(self: *const InputState, key: KeyCode) bool {
        const bit = @intFromEnum(key);
        return (self.key_states & (@as(u64, 1) << @intCast(bit))) != 0;
    }

    pub fn setKeyState(self: *InputState, key: KeyCode, is_pressed: bool) void {
        const bit = @intFromEnum(key);
        if (is_pressed) {
            self.key_states |= (@as(u64, 1) << @intCast(bit));
        } else {
            self.key_states &= ~(@as(u64, 1) << @intCast(bit));
        }
    }

    pub fn reset(self: *InputState) void {
        self.key_states = 0;
    }
};
