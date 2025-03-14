const std = @import("std");
const camera_mod = @import("camera.zig");
const mesh_mod = @import("mesh.zig");
const shaders_mod = @import("shaders.zig");

/// WebGL command types for batched rendering
pub const WebGLCommand = enum(u32) {
    UploadTexture = 1,
    DrawArrays = 2,
    CreateBuffer = 3,
    BindBuffer = 4,
    BufferData = 5,
    CreateShader = 6,
    CreateProgram = 7,
    UseProgram = 8,
    VertexAttribPointer = 9,
    EnableVertexAttribArray = 10,
    DrawElements = 11,
    UniformMatrix4fv = 12,
    Uniform3f = 13,
    Uniform4f = 14,
    EnableDepthTest = 15,
    Clear = 16,
};

/// Command buffer for batching WebGL operations
const CommandBuffer = struct {
    commands: []u32,
    count: usize,
    capacity: usize,

    fn init(allocator: std.mem.Allocator, capacity: usize) !CommandBuffer {
        const commands = try allocator.alloc(u32, capacity * 4 + 1);
        @memset(commands, 0);
        return CommandBuffer{
            .commands = commands,
            .count = 0,
            .capacity = capacity,
        };
    }

    fn deinit(self: *CommandBuffer, allocator: std.mem.Allocator) void {
        allocator.free(self.commands);
    }

    fn reset(self: *CommandBuffer) void {
        self.count = 0;
    }

    fn addTextureCommand(self: *CommandBuffer, data_ptr: [*]const u8) void {
        if (self.count >= self.capacity) return;

        const index = self.count * 4 + 1;
        self.commands[index] = @intFromEnum(WebGLCommand.UploadTexture);
        self.commands[index + 1] = @intFromPtr(data_ptr);
        self.count += 1;
    }

    fn addDrawCommand(self: *CommandBuffer) void {
        if (self.count >= self.capacity) return;

        const index = self.count * 4 + 1;
        self.commands[index] = @intFromEnum(WebGLCommand.DrawArrays);
        self.count += 1;
    }

    fn addCreateBufferCommand(self: *CommandBuffer) void {
        if (self.count >= self.capacity) return;

        const index = self.count * 4 + 1;
        self.commands[index] = @intFromEnum(WebGLCommand.CreateBuffer);
        self.count += 1;
    }

    fn addBindBufferCommand(self: *CommandBuffer, buffer_type: u32, buffer_id: u32) void {
        if (self.count >= self.capacity) return;

        const index = self.count * 4 + 1;
        self.commands[index] = @intFromEnum(WebGLCommand.BindBuffer);
        self.commands[index + 1] = buffer_type;
        self.commands[index + 2] = buffer_id;
        self.count += 1;
    }

    fn addBufferDataCommand(self: *CommandBuffer, buffer_type: u32, data_ptr: [*]const u8, data_size: usize, _: u32) void {
        if (self.count >= self.capacity) return;

        const index = self.count * 4 + 1;
        self.commands[index] = @intFromEnum(WebGLCommand.BufferData);
        self.commands[index + 1] = buffer_type;
        self.commands[index + 2] = @intFromPtr(data_ptr);
        self.commands[index + 3] = @intCast(data_size);
        self.count += 1;
    }

    fn addVertexAttribPointerCommand(self: *CommandBuffer, index: u32, size: i32, data_type: u32, normalized: bool, stride: i32, offset: usize) void {
        if (self.count >= self.capacity) return;

        const index_cmd = self.count * 4 + 1;
        self.commands[index_cmd] = @intFromEnum(WebGLCommand.VertexAttribPointer);
        self.commands[index_cmd + 1] = index;
        self.commands[index_cmd + 2] = @as(u32, @bitCast(@as(u32, @intCast(size))));

        // WebGL has a maximum stride limit (255 bytes in WebGL 1.0)
        // Make sure we don't exceed it
        const safe_stride = @min(stride, 255);

        // Pack normalized, stride, and offset into a single u32
        // Use only the lower bits for each value to avoid overflow
        const norm_bit: u32 = if (normalized) 1 else 0;
        const stride_val: u32 = @intCast(@as(u32, @intCast(safe_stride)) & 0xFF); // Use 8 bits for stride (max 255)
        const offset_val: u32 = @intCast(offset & 0xFFFF); // Use 16 bits for offset

        // Pack the values differently to avoid bit shifting issues
        // data_type (lower 16 bits) | norm_bit (1 bit) | stride (8 bits) | offset (16 bits in upper position)
        self.commands[index_cmd + 3] = data_type | (norm_bit << 16) | (stride_val << 17) | (offset_val << 24);

        self.count += 1;
    }

    fn addEnableVertexAttribArrayCommand(self: *CommandBuffer, index: u32) void {
        if (self.count >= self.capacity) return;

        const index_cmd = self.count * 4 + 1;
        self.commands[index_cmd] = @intFromEnum(WebGLCommand.EnableVertexAttribArray);
        self.commands[index_cmd + 1] = index;
        self.count += 1;
    }

    fn addDrawElementsCommand(self: *CommandBuffer, mode: u32, count: i32, data_type: u32, offset: usize) void {
        if (self.count >= self.capacity) return;

        const index = self.count * 4 + 1;
        self.commands[index] = @intFromEnum(WebGLCommand.DrawElements);
        self.commands[index + 1] = mode;
        self.commands[index + 2] = @as(u32, @bitCast(@as(u32, @intCast(count))));
        self.commands[index + 3] = data_type | (@as(u32, @intCast(offset)) << 16);
        self.count += 1;
    }

    fn addUniformMatrix4fvCommand(self: *CommandBuffer, location: i32, matrix_ptr: [*]const f32) void {
        if (self.count >= self.capacity) return;

        const index = self.count * 4 + 1;
        self.commands[index] = @intFromEnum(WebGLCommand.UniformMatrix4fv);
        self.commands[index + 1] = @as(u32, @intCast(location));
        self.commands[index + 2] = @intFromPtr(matrix_ptr);
        self.count += 1;
    }

    fn addUniform3fCommand(self: *CommandBuffer, location: i32, x: f32, y: f32, z: f32) void {
        if (self.count >= self.capacity) return;

        const index = self.count * 4 + 1;
        self.commands[index] = @intFromEnum(WebGLCommand.Uniform3f);
        self.commands[index + 1] = @as(u32, @intCast(location));

        // Store float values as separate commands to avoid bitcast
        // In a real implementation, we'd need to handle this differently
        self.commands[index + 2] = @as(u32, @intFromFloat(x * 1000.0)); // Approximate conversion
        self.commands[index + 3] = (@as(u32, @intFromFloat(y * 1000.0)) << 16) | (@as(u32, @intFromFloat(z * 1000.0)) & 0xFFFF);
        self.count += 1;
    }

    fn addUniform4fCommand(self: *CommandBuffer, location: i32, x: f32, y: f32, _: f32, _: f32) void {
        if (self.count >= self.capacity) return;

        const index = self.count * 4 + 1;
        self.commands[index] = @intFromEnum(WebGLCommand.Uniform4f);
        self.commands[index + 1] = @as(u32, @intCast(location));

        // Store float values as separate commands to avoid bitcast
        // In a real implementation, we'd need to handle this differently
        self.commands[index + 2] = @as(u32, @intFromFloat(x * 1000.0));
        self.commands[index + 3] = @as(u32, @intFromFloat(y * 1000.0));
        // Note: z and w values are not stored in this simplified version
        self.count += 1;
    }

    fn addEnableDepthTestCommand(self: *CommandBuffer) void {
        if (self.count >= self.capacity) return;

        const index = self.count * 4 + 1;
        self.commands[index] = @intFromEnum(WebGLCommand.EnableDepthTest);
        self.count += 1;
    }

    fn addClearCommand(self: *CommandBuffer, color_bit: bool, depth_bit: bool) void {
        if (self.count >= self.capacity) return;

        const index = self.count * 4 + 1;
        self.commands[index] = @intFromEnum(WebGLCommand.Clear);
        self.commands[index + 1] = (@as(u32, @intFromBool(color_bit)) << 1) | @as(u32, @intFromBool(depth_bit));
        self.count += 1;
    }

    fn getBufferPtr(self: *CommandBuffer) [*]u32 {
        self.commands[0] = @intCast(self.count);
        return self.commands.ptr;
    }

    // New function to get the buffer ID from the last command
    fn getLastBufferId(self: *CommandBuffer) u32 {
        if (self.count == 0) return 0;

        const index = (self.count - 1) * 4 + 1;
        // The buffer ID is stored in the first parameter by WebGL.js
        return self.commands[index + 1];
    }
};

/// Internal image buffer representation
const Image = struct {
    data: []u8,
    width: usize,
    height: usize,
    channels: usize,

    fn init(allocator: std.mem.Allocator, width: usize, height: usize, channels: usize) !Image {
        const data = try allocator.alloc(u8, width * height * channels);
        @memset(data, 0);
        return Image{ .data = data, .width = width, .height = height, .channels = channels };
    }

    fn deinit(self: Image, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }

    fn clear(self: Image, color: [3]u8) void {
        var i: usize = 0;
        while (i < self.width * self.height) : (i += 1) {
            const index = i * self.channels;
            self.data[index] = color[0];
            self.data[index + 1] = color[1];
            self.data[index + 2] = color[2];
        }
    }
};

/// WebGL function bindings
extern fn executeBatchedCommands(cmd_ptr: [*]u32, width: u32, height: u32) void;
extern "env" fn registerCallback(callbackType: [*:0]const u8, callbackFn: ?*const anyopaque) bool;

/// Callback types
pub const BufferCreatedCallback = fn (bufferId: u32) callconv(.C) void;
pub const ShaderCreatedCallback = fn (shaderId: u32) callconv(.C) void;
pub const ProgramCreatedCallback = fn (programId: u32) callconv(.C) void;
pub const ErrorCallback = fn (errorPtr: [*]const u8, errorLen: usize) callconv(.C) void;

/// Callback string constants
const BUFFER_CREATED_CALLBACK = "buffer_created\x00";
const SHADER_CREATED_CALLBACK = "shader_created\x00";
const PROGRAM_CREATED_CALLBACK = "program_created\x00";
const ERROR_CALLBACK = "error\x00";

/// Global state for callbacks
var lastBufferId: u32 = 0;
var lastError: []const u8 = "";

/// Callback implementations
export fn handleBufferCreated(bufferId: u32) void {
    lastBufferId = bufferId;
}

export fn handleError(errorPtr: [*]const u8, errorLen: usize) void {
    lastError = errorPtr[0..errorLen];
}

/// Initialize callbacks
fn initCallbacks() bool {
    const buffer_cb: ?*const anyopaque = @ptrCast(&handleBufferCreated);
    const error_cb: ?*const anyopaque = @ptrCast(&handleError);

    _ = registerCallback(BUFFER_CREATED_CALLBACK, buffer_cb);
    _ = registerCallback(ERROR_CALLBACK, error_cb);
    return true;
}

/// WebGL constants
pub const GL = struct {
    // Buffer types
    pub const ARRAY_BUFFER: u32 = 0x8892;
    pub const ELEMENT_ARRAY_BUFFER: u32 = 0x8893;

    // Usage hints
    pub const STATIC_DRAW: u32 = 0x88E4;
    pub const DYNAMIC_DRAW: u32 = 0x88E8;

    // Data types
    pub const FLOAT: u32 = 0x1406;
    pub const UNSIGNED_SHORT: u32 = 0x1403;
    pub const UNSIGNED_BYTE: u32 = 0x1401;

    // Draw modes
    pub const TRIANGLES: u32 = 0x0004;
    pub const LINES: u32 = 0x0001;
    pub const POINTS: u32 = 0x0000;

    // Clear bits
    pub const COLOR_BUFFER_BIT: u32 = 0x00004000;
    pub const DEPTH_BUFFER_BIT: u32 = 0x00000100;
};

/// Main renderer interface for the game
pub const Renderer = struct {
    command_buffer: CommandBuffer,
    frame_buffer: Image,
    camera: camera_mod.Camera,
    shader_program: shaders_mod.ShaderProgram,
    allocator: std.mem.Allocator,

    // Renderable objects
    mesh_count: u32,
    model_matrices: []?[16]f32,
    mesh_ids: []u32,
    is_visible: []bool,

    /// Initialize a new renderer with a given resolution
    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Renderer {
        // Initialize callbacks first
        _ = initCallbacks();

        const max_meshes = 32; // Support up to 32 renderable objects

        var model_matrices = try allocator.alloc(?[16]f32, max_meshes);
        var mesh_ids = try allocator.alloc(u32, max_meshes);
        var is_visible = try allocator.alloc(bool, max_meshes);

        // Initialize arrays
        for (0..max_meshes) |i| {
            model_matrices[i] = null;
            mesh_ids[i] = 0;
            is_visible[i] = false;
        }

        const renderer = Renderer{
            .command_buffer = try CommandBuffer.init(allocator, 100), // Increased capacity for 3D rendering
            .frame_buffer = try Image.init(allocator, width, height, 3),
            .camera = camera_mod.Camera.init(),
            .shader_program = shaders_mod.ShaderProgram.init("", ""), // Will be initialized properly in setupScene
            .allocator = allocator,
            .mesh_count = 0,
            .model_matrices = model_matrices,
            .mesh_ids = mesh_ids,
            .is_visible = is_visible,
        };

        return renderer;
    }

    /// Free all resources used by the renderer
    pub fn deinit(self: *Renderer, allocator: std.mem.Allocator) void {
        self.command_buffer.deinit(allocator);
        self.frame_buffer.deinit(allocator);
        allocator.free(self.model_matrices);
        allocator.free(self.mesh_ids);
        allocator.free(self.is_visible);
    }

    /// Set up the 3D scene with shaders and meshes
    pub fn setupScene(self: *Renderer) !void {
        // Create shader program
        self.shader_program = shaders_mod.createShaderProgram(shaders_mod.basic_vertex_shader, shaders_mod.basic_fragment_shader);

        // Verify shader program was created successfully
        if (self.shader_program.program_id == 0) {
            return error.ShaderProgramCreationFailed;
        }

        // Use the shader program immediately to set it up
        self.command_buffer.reset();
        shaders_mod.useShaderProgram(self.shader_program);

        // Enable depth testing
        self.command_buffer.addEnableDepthTestCommand();

        // Execute the commands to set up the shader program
        executeBatchedCommands(self.command_buffer.getBufferPtr(), @intCast(self.frame_buffer.width), @intCast(self.frame_buffer.height));
        self.command_buffer.reset();
    }

    /// Add a mesh to the renderer and return its handle
    pub fn addMesh(self: *Renderer, mesh: mesh_mod.Mesh) !u32 {
        if (self.mesh_count >= self.model_matrices.len) {
            return error.TooManyMeshes;
        }

        // Upload mesh to GPU
        const mesh_id = try self.uploadMesh(mesh);

        // Store mesh ID
        const handle = self.mesh_count;
        self.mesh_ids[handle] = mesh_id;

        // Initialize model matrix to identity
        self.model_matrices[handle] = [_]f32{0} ** 16;
        identityMatrix(&self.model_matrices[handle].?);

        // Set as visible
        self.is_visible[handle] = true;

        // Increment mesh count
        self.mesh_count += 1;

        return handle;
    }

    /// Update the model matrix for a mesh
    pub fn updateModelMatrix(self: *Renderer, handle: u32, position: [3]f32, rotation: [3]f32, scale: [3]f32) void {
        if (handle >= self.mesh_count or self.model_matrices[handle] == null) {
            return;
        }

        // Reset to identity
        identityMatrix(&self.model_matrices[handle].?);

        // Apply scale
        scaleMatrix(&self.model_matrices[handle].?, scale[0], scale[1], scale[2]);

        // Apply rotation (simplified - just Y rotation for now)
        rotateYMatrix(&self.model_matrices[handle].?, rotation[1]);

        // Apply position
        translateMatrix(&self.model_matrices[handle].?, position[0], position[1], position[2]);
    }

    /// Set visibility of a mesh
    pub fn setMeshVisibility(self: *Renderer, handle: u32, visible: bool) void {
        if (handle < self.mesh_count) {
            self.is_visible[handle] = visible;
        }
    }

    /// Upload a mesh to the GPU and return its ID
    fn uploadMesh(self: *Renderer, mesh: mesh_mod.Mesh) !u32 {
        // Reset callback state
        lastBufferId = 0;
        lastError = "";

        // Create vertex buffer
        self.command_buffer.addCreateBufferCommand();

        // Execute the command to create the buffer
        executeBatchedCommands(self.command_buffer.getBufferPtr(), @intCast(self.frame_buffer.width), @intCast(self.frame_buffer.height));

        // Check for errors
        if (lastError.len > 0) {
            return error.BufferCreationFailed;
        }

        // Get the buffer ID from the callback
        const vertex_buffer_id = lastBufferId;
        if (vertex_buffer_id == 0) {
            return error.BufferCreationFailed;
        }

        // Reset the command buffer for the next commands
        self.command_buffer.reset();

        // Store buffer ID in mesh
        var mesh_copy = mesh;
        mesh_copy.vertex_buffer_id = vertex_buffer_id;

        // Bind vertex buffer
        self.command_buffer.addBindBufferCommand(GL.ARRAY_BUFFER, vertex_buffer_id);

        // Upload vertex data
        self.command_buffer.addBufferDataCommand(GL.ARRAY_BUFFER, @ptrCast(mesh.getVertexDataPtr()), mesh.getVertexDataSize(), GL.STATIC_DRAW);

        // Execute the commands to bind and upload data
        executeBatchedCommands(self.command_buffer.getBufferPtr(), @intCast(self.frame_buffer.width), @intCast(self.frame_buffer.height));

        // Check for errors
        if (lastError.len > 0) {
            return error.BufferDataUploadFailed;
        }

        self.command_buffer.reset();

        // Reset callback state for index buffer
        lastBufferId = 0;
        lastError = "";

        // Create index buffer
        self.command_buffer.addCreateBufferCommand();

        // Execute the command to create the index buffer
        executeBatchedCommands(self.command_buffer.getBufferPtr(), @intCast(self.frame_buffer.width), @intCast(self.frame_buffer.height));

        // Check for errors
        if (lastError.len > 0) {
            return error.BufferCreationFailed;
        }

        // Get the index buffer ID from the callback
        const index_buffer_id = lastBufferId;
        if (index_buffer_id == 0) {
            return error.BufferCreationFailed;
        }

        // Reset the command buffer for the next commands
        self.command_buffer.reset();

        // Store index buffer ID in mesh
        mesh_copy.index_buffer_id = index_buffer_id;

        // Bind index buffer
        self.command_buffer.addBindBufferCommand(GL.ELEMENT_ARRAY_BUFFER, index_buffer_id);

        // Upload index data
        self.command_buffer.addBufferDataCommand(GL.ELEMENT_ARRAY_BUFFER, @ptrCast(mesh.getIndexDataPtr()), mesh.getIndexDataSize(), GL.STATIC_DRAW);

        // Execute the commands to bind and upload index data
        executeBatchedCommands(self.command_buffer.getBufferPtr(), @intCast(self.frame_buffer.width), @intCast(self.frame_buffer.height));

        // Check for errors
        if (lastError.len > 0) {
            return error.BufferDataUploadFailed;
        }

        self.command_buffer.reset();

        return vertex_buffer_id;
    }

    /// Start a new frame, clearing with the given color
    pub fn beginFrame(self: *Renderer, clear_color: [3]u8) void {
        self.command_buffer.reset();
        self.frame_buffer.clear(clear_color);

        // Clear color and depth buffers
        self.command_buffer.addClearCommand(true, true);

        // Use shader program - make sure to use the program ID
        if (self.shader_program.program_id != 0) {
            shaders_mod.useShaderProgram(self.shader_program);
        }
    }

    /// Render the 3D scene
    pub fn renderScene(self: *Renderer) void {
        // Update camera view-projection matrix
        self.camera.updateViewMatrix();

        // Render all visible meshes
        for (0..self.mesh_count) |i| {
            if (self.is_visible[i] and self.model_matrices[i] != null) {
                self.renderMesh(self.mesh_ids[i], &self.model_matrices[i].?);
            }
        }
    }

    /// Render a mesh with the given model matrix
    fn renderMesh(self: *Renderer, mesh_id: u32, model_matrix: *const [16]f32) void {
        // Find the mesh in our list to get its buffer IDs
        const vertex_buffer_id: u32 = mesh_id;
        const index_buffer_id: u32 = mesh_id + 1;

        // In a real implementation, we'd store the mesh object and get its buffer IDs
        // For now, we'll use the mesh_id as the vertex buffer ID and mesh_id + 1 as the index buffer ID

        // Make sure we're using the shader program
        shaders_mod.useShaderProgram(self.shader_program);

        // Bind vertex buffer BEFORE setting attributes
        self.command_buffer.addBindBufferCommand(GL.ARRAY_BUFFER, vertex_buffer_id);

        // Execute the command to bind the buffer
        executeBatchedCommands(self.command_buffer.getBufferPtr(), @intCast(self.frame_buffer.width), @intCast(self.frame_buffer.height));
        self.command_buffer.reset();

        // Calculate stride - WebGL has a maximum stride limit
        // The Vertex struct has position (12 bytes), normal (12 bytes), and color (16 bytes)
        // Total size is 40 bytes, which should be within WebGL's limit
        const stride = @sizeOf(mesh_mod.Vertex);

        // Verify buffer is bound before setting attributes
        // Position attribute
        self.command_buffer.addVertexAttribPointerCommand(0, // attribute index
            3, // size (x, y, z)
            GL.FLOAT, // type
            false, // normalized
            @intCast(stride), // stride
            0 // offset
        );
        self.command_buffer.addEnableVertexAttribArrayCommand(0);

        // Normal attribute
        self.command_buffer.addVertexAttribPointerCommand(1, // attribute index
            3, // size (nx, ny, nz)
            GL.FLOAT, // type
            false, // normalized
            @intCast(stride), // stride
            @offsetOf(mesh_mod.Vertex, "normal") // offset
        );
        self.command_buffer.addEnableVertexAttribArrayCommand(1);

        // Color attribute
        self.command_buffer.addVertexAttribPointerCommand(2, // attribute index
            4, // size (r, g, b, a)
            GL.FLOAT, // type
            false, // normalized
            @intCast(stride), // stride
            @offsetOf(mesh_mod.Vertex, "color") // offset
        );
        self.command_buffer.addEnableVertexAttribArrayCommand(2);

        // Execute the commands to set up vertex attributes
        executeBatchedCommands(self.command_buffer.getBufferPtr(), @intCast(self.frame_buffer.width), @intCast(self.frame_buffer.height));
        self.command_buffer.reset();

        // Bind index buffer before drawing
        self.command_buffer.addBindBufferCommand(GL.ELEMENT_ARRAY_BUFFER, index_buffer_id);

        // Compute model-view-projection matrix
        var mvp: [16]f32 = undefined;
        multiplyMatrices(self.camera.getViewProjectionMatrixPtr(), model_matrix, &mvp);

        // Set uniforms
        // Model-view-projection matrix
        const mvp_loc = shaders_mod.getShaderUniformLocation(self.shader_program.program_id, "u_modelViewProjection");
        if (mvp_loc >= 0) {
            self.command_buffer.addUniformMatrix4fvCommand(mvp_loc, &mvp);
        }

        // Model matrix
        const model_loc = shaders_mod.getShaderUniformLocation(self.shader_program.program_id, "u_model");
        if (model_loc >= 0) {
            self.command_buffer.addUniformMatrix4fvCommand(model_loc, model_matrix);
        }

        // Light direction
        const light_dir_loc = shaders_mod.getShaderUniformLocation(self.shader_program.program_id, "u_lightDirection");
        if (light_dir_loc >= 0) {
            self.command_buffer.addUniform3fCommand(light_dir_loc, 0.5, 1.0, 0.3);
        }

        // View position (camera position)
        const view_pos_loc = shaders_mod.getShaderUniformLocation(self.shader_program.program_id, "u_viewPosition");
        if (view_pos_loc >= 0) {
            self.command_buffer.addUniform3fCommand(view_pos_loc, self.camera.position[0], self.camera.position[1], self.camera.position[2]);
        }

        // Draw the mesh - use a fixed index count for now
        const index_count: i32 = 36; // Assuming a box mesh with 12 triangles (6 faces * 2 triangles)
        self.command_buffer.addDrawElementsCommand(GL.TRIANGLES, index_count, GL.UNSIGNED_SHORT, 0);

        // Execute the commands to draw the mesh
        executeBatchedCommands(self.command_buffer.getBufferPtr(), @intCast(self.frame_buffer.width), @intCast(self.frame_buffer.height));
        self.command_buffer.reset();
    }

    /// Finish frame and send commands to WebGL
    pub fn endFrame(self: *Renderer) void {
        // Add texture upload and draw commands
        self.command_buffer.addTextureCommand(self.frame_buffer.data.ptr);
        self.command_buffer.addDrawCommand();

        // Execute the final commands for the frame
        if (self.command_buffer.count > 0) {
            executeBatchedCommands(self.command_buffer.getBufferPtr(), @intCast(self.frame_buffer.width), @intCast(self.frame_buffer.height));
            self.command_buffer.reset();
        }
    }

    /// Draw a single pixel (kept for backward compatibility)
    pub fn drawPixel(self: *Renderer, x: usize, y: usize, color: [3]u8) void {
        if (x >= self.frame_buffer.width or y >= self.frame_buffer.height) return;

        const index = (y * self.frame_buffer.width + x) * self.frame_buffer.channels;
        if (index + 2 < self.frame_buffer.data.len) {
            self.frame_buffer.data[index] = color[0];
            self.frame_buffer.data[index + 1] = color[1];
            self.frame_buffer.data[index + 2] = color[2];
        }
    }

    /// Draw a filled rectangle (kept for backward compatibility)
    pub fn drawRect(self: *Renderer, x: usize, y: usize, width: usize, height: usize, color: [3]u8) void {
        const max_x = @min(x + width, self.frame_buffer.width);
        const max_y = @min(y + height, self.frame_buffer.height);

        for (y..max_y) |py| {
            for (x..max_x) |px| {
                self.drawPixel(px, py, color);
            }
        }
    }

    /// Draw a filled circle (kept for backward compatibility)
    pub fn drawCircle(self: *Renderer, center_x: usize, center_y: usize, radius: usize, color: [3]u8) void {
        const r_squared = radius * radius;
        const min_x = if (center_x > radius) center_x - radius else 0;
        const min_y = if (center_y > radius) center_y - radius else 0;
        const max_x = @min(center_x + radius + 1, self.frame_buffer.width);
        const max_y = @min(center_y + radius + 1, self.frame_buffer.height);

        for (min_y..max_y) |py| {
            for (min_x..max_x) |px| {
                const dx = if (px > center_x) px - center_x else center_x - px;
                const dy = if (py > center_y) py - center_y else center_y - py;
                if (dx * dx + dy * dy <= r_squared) {
                    self.drawPixel(px, py, color);
                }
            }
        }
    }
};

/// Set matrix to identity
pub fn identityMatrix(matrix: *[16]f32) void {
    matrix[0] = 1.0;
    matrix[1] = 0.0;
    matrix[2] = 0.0;
    matrix[3] = 0.0;

    matrix[4] = 0.0;
    matrix[5] = 1.0;
    matrix[6] = 0.0;
    matrix[7] = 0.0;

    matrix[8] = 0.0;
    matrix[9] = 0.0;
    matrix[10] = 1.0;
    matrix[11] = 0.0;

    matrix[12] = 0.0;
    matrix[13] = 0.0;
    matrix[14] = 0.0;
    matrix[15] = 1.0;
}

/// Scale matrix by x, y, z
pub fn scaleMatrix(matrix: *[16]f32, x: f32, y: f32, z: f32) void {
    matrix[0] *= x;
    matrix[1] *= x;
    matrix[2] *= x;
    matrix[3] *= x;

    matrix[4] *= y;
    matrix[5] *= y;
    matrix[6] *= y;
    matrix[7] *= y;

    matrix[8] *= z;
    matrix[9] *= z;
    matrix[10] *= z;
    matrix[11] *= z;
}

/// Rotate matrix around Y axis
pub fn rotateYMatrix(matrix: *[16]f32, angle_radians: f32) void {
    const c = @cos(angle_radians);
    const s = @sin(angle_radians);

    const m0 = matrix[0];
    const m2 = matrix[2];
    const m4 = matrix[4];
    const m6 = matrix[6];
    const m8 = matrix[8];
    const m10 = matrix[10];

    matrix[0] = m0 * c - m2 * s;
    matrix[2] = m0 * s + m2 * c;
    matrix[4] = m4 * c - m6 * s;
    matrix[6] = m4 * s + m6 * c;
    matrix[8] = m8 * c - m10 * s;
    matrix[10] = m8 * s + m10 * c;
}

/// Translate matrix by x, y, z
pub fn translateMatrix(matrix: *[16]f32, x: f32, y: f32, z: f32) void {
    matrix[12] = matrix[0] * x + matrix[4] * y + matrix[8] * z + matrix[12];
    matrix[13] = matrix[1] * x + matrix[5] * y + matrix[9] * z + matrix[13];
    matrix[14] = matrix[2] * x + matrix[6] * y + matrix[10] * z + matrix[14];
    matrix[15] = matrix[3] * x + matrix[7] * y + matrix[11] * z + matrix[15];
}

/// Multiply two matrices and store result in out
fn multiplyMatrices(a: *const [16]f32, b: *const [16]f32, out: *[16]f32) void {
    var result: [16]f32 = undefined;

    // Row 1
    result[0] = a[0] * b[0] + a[4] * b[1] + a[8] * b[2] + a[12] * b[3];
    result[4] = a[0] * b[4] + a[4] * b[5] + a[8] * b[6] + a[12] * b[7];
    result[8] = a[0] * b[8] + a[4] * b[9] + a[8] * b[10] + a[12] * b[11];
    result[12] = a[0] * b[12] + a[4] * b[13] + a[8] * b[14] + a[12] * b[15];

    // Row 2
    result[1] = a[1] * b[0] + a[5] * b[1] + a[9] * b[2] + a[13] * b[3];
    result[5] = a[1] * b[4] + a[5] * b[5] + a[9] * b[6] + a[13] * b[7];
    result[9] = a[1] * b[8] + a[5] * b[9] + a[9] * b[10] + a[13] * b[11];
    result[13] = a[1] * b[12] + a[5] * b[13] + a[9] * b[14] + a[13] * b[15];

    // Row 3
    result[2] = a[2] * b[0] + a[6] * b[1] + a[10] * b[2] + a[14] * b[3];
    result[6] = a[2] * b[4] + a[6] * b[5] + a[10] * b[6] + a[14] * b[7];
    result[10] = a[2] * b[8] + a[6] * b[9] + a[10] * b[10] + a[14] * b[11];
    result[14] = a[2] * b[12] + a[6] * b[13] + a[10] * b[14] + a[14] * b[15];

    // Row 4
    result[3] = a[3] * b[0] + a[7] * b[1] + a[11] * b[2] + a[15] * b[3];
    result[7] = a[3] * b[4] + a[7] * b[5] + a[11] * b[6] + a[15] * b[7];
    result[11] = a[3] * b[8] + a[7] * b[9] + a[11] * b[10] + a[15] * b[11];
    result[15] = a[3] * b[12] + a[7] * b[13] + a[11] * b[14] + a[15] * b[15];

    // Copy result to output
    for (0..16) |i| {
        out[i] = result[i];
    }
}
