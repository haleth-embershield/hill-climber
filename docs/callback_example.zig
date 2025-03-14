const std = @import("std");

// Import the renderer core module
const renderer = @import("../src/renderer/core.zig");

// Define callback function types
pub const BufferCreatedCallback = fn (bufferId: u32) callconv(.C) void;
pub const ShaderCreatedCallback = fn (shaderId: u32) callconv(.C) void;
pub const ProgramCreatedCallback = fn (programId: u32) callconv(.C) void;
pub const ErrorCallback = fn (errorPtr: [*]const u8, errorLen: usize) callconv(.C) void;

// External JavaScript functions
extern fn registerCallback(callbackType: [*]const u8, callbackFn: ?*const anyopaque) bool;

// Callback string constants
const BUFFER_CREATED_CALLBACK = "buffer_created";
const SHADER_CREATED_CALLBACK = "shader_created";
const PROGRAM_CREATED_CALLBACK = "program_created";
const ERROR_CALLBACK = "error";

// Global state to store resource IDs returned from callbacks
var lastBufferId: u32 = 0;
var lastShaderId: u32 = 0;
var lastProgramId: u32 = 0;
var lastError: []const u8 = "";

// Callback implementations
export fn handleBufferCreated(bufferId: u32) void {
    // Store the buffer ID for later use
    lastBufferId = bufferId;
    std.debug.print("Buffer created with ID: {d}\n", .{bufferId});
}

export fn handleShaderCreated(shaderId: u32) void {
    // Store the shader ID for later use
    lastShaderId = shaderId;
    std.debug.print("Shader created with ID: {d}\n", .{shaderId});
}

export fn handleProgramCreated(programId: u32) void {
    // Store the program ID for later use
    lastProgramId = programId;
    std.debug.print("Program created with ID: {d}\n", .{programId});
}

export fn handleError(errorPtr: [*]const u8, errorLen: usize) void {
    // Convert the error message to a Zig string
    const errorMsg = errorPtr[0..errorLen];
    lastError = errorMsg;
    std.debug.print("WebGL error: {s}\n", .{errorMsg});
}

// Initialize the callback system
pub fn initCallbacks() bool {
    // Register all callbacks with JavaScript
    _ = registerCallback(BUFFER_CREATED_CALLBACK.ptr, @ptrCast(&handleBufferCreated));
    _ = registerCallback(SHADER_CREATED_CALLBACK.ptr, @ptrCast(&handleShaderCreated));
    _ = registerCallback(PROGRAM_CREATED_CALLBACK.ptr, @ptrCast(&handleProgramCreated));
    _ = registerCallback(ERROR_CALLBACK.ptr, @ptrCast(&handleError));
    return true;
}

// Example of creating a buffer using the command buffer system
pub fn createBufferExample(commandBuffer: *renderer.CommandBuffer) u32 {
    // Reset the last buffer ID
    lastBufferId = 0;

    // Add a create buffer command to the command buffer
    commandBuffer.addCreateBufferCommand();

    // Execute the command buffer
    // Note: In a real implementation, you would call executeBatchedCommands here

    // Return the buffer ID that was set by the callback
    return lastBufferId;
}

// Example of how to use the callback system in a renderer
pub fn rendererExample() void {
    // Initialize callbacks
    _ = initCallbacks();

    // Create a command buffer
    var commandBuffer = renderer.CommandBuffer.init(std.heap.page_allocator, 100) catch {
        std.debug.print("Failed to create command buffer\n", .{});
        return;
    };
    defer commandBuffer.deinit(std.heap.page_allocator);

    // Create a buffer
    const bufferId = createBufferExample(&commandBuffer);

    // Use the buffer ID
    if (bufferId != 0) {
        std.debug.print("Successfully created buffer with ID: {d}\n", .{bufferId});

        // Bind the buffer
        commandBuffer.addBindBufferCommand(renderer.GL_ARRAY_BUFFER, bufferId);

        // Add more commands...
    } else {
        std.debug.print("Failed to create buffer\n", .{});
    }
}
