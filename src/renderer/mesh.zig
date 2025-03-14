const std = @import("std");

/// Vertex structure for 3D meshes
pub const Vertex = struct {
    position: [3]f32, // x, y, z
    normal: [3]f32, // nx, ny, nz
    color: [4]f32, // r, g, b, a

    /// Create a new vertex with position, normal, and color
    pub fn init(pos: [3]f32, norm: [3]f32, col: [4]f32) Vertex {
        return Vertex{
            .position = pos,
            .normal = norm,
            .color = col,
        };
    }
};

/// Mesh structure for 3D objects
pub const Mesh = struct {
    vertices: []Vertex,
    indices: []u16,
    vertex_buffer_id: u32,
    index_buffer_id: u32,
    allocator: std.mem.Allocator,

    /// Create a new mesh with vertices and indices
    pub fn init(allocator: std.mem.Allocator, vertices: []const Vertex, indices: []const u16) !Mesh {
        // Allocate memory for vertices and indices
        const vertex_copy = try allocator.alloc(Vertex, vertices.len);
        const index_copy = try allocator.alloc(u16, indices.len);

        // Copy data
        @memcpy(vertex_copy, vertices);
        @memcpy(index_copy, indices);

        return Mesh{
            .vertices = vertex_copy,
            .indices = index_copy,
            .vertex_buffer_id = 0,
            .index_buffer_id = 0,
            .allocator = allocator,
        };
    }

    /// Free mesh resources
    pub fn deinit(self: *Mesh) void {
        self.allocator.free(self.vertices);
        self.allocator.free(self.indices);
    }

    /// Get raw vertex data pointer for WebGL
    pub fn getVertexDataPtr(self: *const Mesh) [*]const f32 {
        return @ptrCast(self.vertices.ptr);
    }

    /// Get vertex data size in bytes
    pub fn getVertexDataSize(self: *const Mesh) usize {
        return self.vertices.len * @sizeOf(Vertex);
    }

    /// Get raw index data pointer for WebGL
    pub fn getIndexDataPtr(self: *const Mesh) [*]const u16 {
        return self.indices.ptr;
    }

    /// Get index data size in bytes
    pub fn getIndexDataSize(self: *const Mesh) usize {
        return self.indices.len * @sizeOf(u16);
    }

    /// Get vertex count
    pub fn getVertexCount(self: *const Mesh) usize {
        return self.vertices.len;
    }

    /// Get index count
    pub fn getIndexCount(self: *const Mesh) usize {
        return self.indices.len;
    }
};

/// Create a simple box mesh
pub fn createBox(allocator: std.mem.Allocator, width: f32, height: f32, depth: f32, color: [4]f32) !Mesh {
    const half_width = width / 2.0;
    const half_height = height / 2.0;
    const half_depth = depth / 2.0;

    // Define the 8 corners of the box
    const vertices = [_]Vertex{
        // Front face
        Vertex.init([_]f32{ -half_width, -half_height, half_depth }, [_]f32{ 0, 0, 1 }, color),
        Vertex.init([_]f32{ half_width, -half_height, half_depth }, [_]f32{ 0, 0, 1 }, color),
        Vertex.init([_]f32{ half_width, half_height, half_depth }, [_]f32{ 0, 0, 1 }, color),
        Vertex.init([_]f32{ -half_width, half_height, half_depth }, [_]f32{ 0, 0, 1 }, color),

        // Back face
        Vertex.init([_]f32{ -half_width, -half_height, -half_depth }, [_]f32{ 0, 0, -1 }, color),
        Vertex.init([_]f32{ -half_width, half_height, -half_depth }, [_]f32{ 0, 0, -1 }, color),
        Vertex.init([_]f32{ half_width, half_height, -half_depth }, [_]f32{ 0, 0, -1 }, color),
        Vertex.init([_]f32{ half_width, -half_height, -half_depth }, [_]f32{ 0, 0, -1 }, color),

        // Top face
        Vertex.init([_]f32{ -half_width, half_height, -half_depth }, [_]f32{ 0, 1, 0 }, color),
        Vertex.init([_]f32{ -half_width, half_height, half_depth }, [_]f32{ 0, 1, 0 }, color),
        Vertex.init([_]f32{ half_width, half_height, half_depth }, [_]f32{ 0, 1, 0 }, color),
        Vertex.init([_]f32{ half_width, half_height, -half_depth }, [_]f32{ 0, 1, 0 }, color),

        // Bottom face
        Vertex.init([_]f32{ -half_width, -half_height, -half_depth }, [_]f32{ 0, -1, 0 }, color),
        Vertex.init([_]f32{ half_width, -half_height, -half_depth }, [_]f32{ 0, -1, 0 }, color),
        Vertex.init([_]f32{ half_width, -half_height, half_depth }, [_]f32{ 0, -1, 0 }, color),
        Vertex.init([_]f32{ -half_width, -half_height, half_depth }, [_]f32{ 0, -1, 0 }, color),

        // Right face
        Vertex.init([_]f32{ half_width, -half_height, -half_depth }, [_]f32{ 1, 0, 0 }, color),
        Vertex.init([_]f32{ half_width, half_height, -half_depth }, [_]f32{ 1, 0, 0 }, color),
        Vertex.init([_]f32{ half_width, half_height, half_depth }, [_]f32{ 1, 0, 0 }, color),
        Vertex.init([_]f32{ half_width, -half_height, half_depth }, [_]f32{ 1, 0, 0 }, color),

        // Left face
        Vertex.init([_]f32{ -half_width, -half_height, -half_depth }, [_]f32{ -1, 0, 0 }, color),
        Vertex.init([_]f32{ -half_width, -half_height, half_depth }, [_]f32{ -1, 0, 0 }, color),
        Vertex.init([_]f32{ -half_width, half_height, half_depth }, [_]f32{ -1, 0, 0 }, color),
        Vertex.init([_]f32{ -half_width, half_height, -half_depth }, [_]f32{ -1, 0, 0 }, color),
    };

    // Define the indices for the 12 triangles (6 faces, 2 triangles each)
    const indices = [_]u16{
        // Front face
        0,  1,  2,  0,  2,  3,
        // Back face
        4,  5,  6,  4,  6,  7,
        // Top face
        8,  9,  10, 8,  10, 11,
        // Bottom face
        12, 13, 14, 12, 14, 15,
        // Right face
        16, 17, 18, 16, 18, 19,
        // Left face
        20, 21, 22, 20, 22, 23,
    };

    return Mesh.init(allocator, &vertices, &indices);
}

/// Create a simple cylinder mesh
pub fn createCylinder(allocator: std.mem.Allocator, radius: f32, height: f32, segments: u32, color: [4]f32) !Mesh {
    const segment_count = @max(segments, 8); // Minimum 8 segments
    const vertex_count = segment_count * 4 + 2; // 2 circles * segment_count + 2 centers
    const index_count = segment_count * 12; // 2 circles * segment_count * 3 + 2 caps * segment_count * 3

    // Allocate memory for vertices and indices
    var vertices = try allocator.alloc(Vertex, vertex_count);
    var indices = try allocator.alloc(u16, index_count);

    // Top and bottom center points
    vertices[0] = Vertex.init([_]f32{ 0, height / 2, 0 }, [_]f32{ 0, 1, 0 }, color);
    vertices[1] = Vertex.init([_]f32{ 0, -height / 2, 0 }, [_]f32{ 0, -1, 0 }, color);

    // Generate vertices for the cylinder
    var i: u32 = 0;
    while (i < segment_count) : (i += 1) {
        const angle = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(segment_count)) * std.math.tau;
        const x = radius * @cos(angle);
        const z = radius * @sin(angle);

        // Top rim
        const top_idx = i * 2 + 2;
        vertices[top_idx] = Vertex.init([_]f32{ x, height / 2, z }, [_]f32{ x, 0, z }, color);

        // Bottom rim
        const bottom_idx = i * 2 + 3;
        vertices[bottom_idx] = Vertex.init([_]f32{ x, -height / 2, z }, [_]f32{ x, 0, z }, color);

        // Indices for top cap
        const top_cap_idx = i * 3;
        indices[top_cap_idx] = 0; // Top center
        indices[top_cap_idx + 1] = @intCast(top_idx);
        indices[top_cap_idx + 2] = if (i == segment_count - 1) 2 else @intCast(top_idx + 2);

        // Indices for bottom cap
        const bottom_cap_idx = (segment_count + i) * 3;
        indices[bottom_cap_idx] = 1; // Bottom center
        indices[bottom_cap_idx + 1] = if (i == segment_count - 1) 3 else @intCast(bottom_idx + 2);
        indices[bottom_cap_idx + 2] = @intCast(bottom_idx);

        // Indices for side - first triangle
        const side_idx = (2 * segment_count + i * 2) * 3;
        indices[side_idx] = @intCast(top_idx);
        indices[side_idx + 1] = @intCast(bottom_idx);
        indices[side_idx + 2] = if (i == segment_count - 1) 3 else @intCast(bottom_idx + 2);

        // Indices for side - second triangle
        const side2_idx = (2 * segment_count + i * 2 + 1) * 3;
        indices[side2_idx] = @intCast(top_idx);
        indices[side2_idx + 1] = if (i == segment_count - 1) 3 else @intCast(bottom_idx + 2);
        indices[side2_idx + 2] = if (i == segment_count - 1) 2 else @intCast(top_idx + 2);
    }

    return Mesh{
        .vertices = vertices,
        .indices = indices,
        .vertex_buffer_id = 0,
        .index_buffer_id = 0,
        .allocator = allocator,
    };
}

/// Create a simple plane mesh
pub fn createPlane(allocator: std.mem.Allocator, width: f32, depth: f32, color: [4]f32) !Mesh {
    const half_width = width / 2.0;
    const half_depth = depth / 2.0;

    // Define the 4 corners of the plane
    const vertices = [_]Vertex{
        Vertex.init([_]f32{ -half_width, 0, -half_depth }, [_]f32{ 0, 1, 0 }, color),
        Vertex.init([_]f32{ half_width, 0, -half_depth }, [_]f32{ 0, 1, 0 }, color),
        Vertex.init([_]f32{ half_width, 0, half_depth }, [_]f32{ 0, 1, 0 }, color),
        Vertex.init([_]f32{ -half_width, 0, half_depth }, [_]f32{ 0, 1, 0 }, color),
    };

    // Define the indices for the 2 triangles
    const indices = [_]u16{ 0, 1, 2, 0, 2, 3 };

    return Mesh.init(allocator, &vertices, &indices);
}

/// Create a simple hill mesh with a sine wave pattern
pub fn createHill(allocator: std.mem.Allocator, width: f32, depth: f32, height: f32, segments: u32, color: [4]f32) !Mesh {
    const segment_count = @max(segments, 4); // Minimum 4 segments
    const vertex_count = (segment_count + 1) * (segment_count + 1);
    const index_count = segment_count * segment_count * 6; // 2 triangles per grid cell

    // Allocate memory for vertices and indices
    var vertices = try allocator.alloc(Vertex, vertex_count);
    var indices = try allocator.alloc(u16, index_count);

    // Generate vertices for the hill
    var z: u32 = 0;
    while (z <= segment_count) : (z += 1) {
        var x: u32 = 0;
        while (x <= segment_count) : (x += 1) {
            const x_pos = ((@as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(segment_count))) - 0.5) * width;
            const z_pos = ((@as(f32, @floatFromInt(z)) / @as(f32, @floatFromInt(segment_count))) - 0.5) * depth;

            // Generate height using a sine wave pattern
            const dist = @sqrt(x_pos * x_pos + z_pos * z_pos) / (width / 2.0);
            const y_pos = @sin(dist * 3.0) * height * (1.0 - dist);

            // Calculate normal
            const normal_x = -@cos(dist * 3.0) * 3.0 * height * (1.0 - dist) * x_pos / (width / 2.0) / (width / 2.0);
            const normal_z = -@cos(dist * 3.0) * 3.0 * height * (1.0 - dist) * z_pos / (width / 2.0) / (width / 2.0);
            const normal_y = 1.0;
            const normal_length = @sqrt(normal_x * normal_x + normal_y * normal_y + normal_z * normal_z);

            // Set vertex
            const vertex_idx = z * (segment_count + 1) + x;
            vertices[vertex_idx] = Vertex.init([_]f32{ x_pos, y_pos, z_pos }, [_]f32{ normal_x / normal_length, normal_y / normal_length, normal_z / normal_length }, color);

            // Generate indices for triangles
            if (x < segment_count and z < segment_count) {
                const index_base = (z * segment_count + x) * 6;
                const top_left = z * (segment_count + 1) + x;
                const top_right = top_left + 1;
                const bottom_left = (z + 1) * (segment_count + 1) + x;
                const bottom_right = bottom_left + 1;

                // First triangle (top-left, bottom-left, bottom-right)
                indices[index_base] = @as(u16, @intCast(top_left));
                indices[index_base + 1] = @as(u16, @intCast(bottom_left));
                indices[index_base + 2] = @as(u16, @intCast(bottom_right));

                // Second triangle (top-left, bottom-right, top-right)
                indices[index_base + 3] = @as(u16, @intCast(top_left));
                indices[index_base + 4] = @as(u16, @intCast(bottom_right));
                indices[index_base + 5] = @as(u16, @intCast(top_right));
            }
        }
    }

    return Mesh{
        .vertices = vertices,
        .indices = indices,
        .vertex_buffer_id = 0,
        .index_buffer_id = 0,
        .allocator = allocator,
    };
}

/// Create a simple truck mesh (box body with cylinder wheels)
pub fn createTruck(allocator: std.mem.Allocator, body_color: [4]f32, wheel_color: [4]f32) !Mesh {
    // Create body (box)
    var body_mesh = try createBox(allocator, 2.0, 1.0, 3.0, body_color);
    defer body_mesh.deinit();

    // Create wheels (cylinders)
    var wheel1_mesh = try createCylinder(allocator, 0.5, 0.3, 12, wheel_color);
    defer wheel1_mesh.deinit();

    var wheel2_mesh = try createCylinder(allocator, 0.5, 0.3, 12, wheel_color);
    defer wheel2_mesh.deinit();

    var wheel3_mesh = try createCylinder(allocator, 0.5, 0.3, 12, wheel_color);
    defer wheel3_mesh.deinit();

    var wheel4_mesh = try createCylinder(allocator, 0.5, 0.3, 12, wheel_color);
    defer wheel4_mesh.deinit();

    // Calculate total vertex and index counts
    const total_vertices = body_mesh.getVertexCount() +
        wheel1_mesh.getVertexCount() +
        wheel2_mesh.getVertexCount() +
        wheel3_mesh.getVertexCount() +
        wheel4_mesh.getVertexCount();

    const total_indices = body_mesh.getIndexCount() +
        wheel1_mesh.getIndexCount() +
        wheel2_mesh.getIndexCount() +
        wheel3_mesh.getIndexCount() +
        wheel4_mesh.getIndexCount();

    // Allocate memory for combined mesh
    var vertices = try allocator.alloc(Vertex, total_vertices);
    var indices = try allocator.alloc(u16, total_indices);

    // Copy body vertices and indices
    var vertex_offset: usize = 0;
    var index_offset: usize = 0;

    // Copy body
    @memcpy(vertices[vertex_offset .. vertex_offset + body_mesh.getVertexCount()], body_mesh.vertices);

    // Adjust body indices and copy
    for (0..body_mesh.getIndexCount()) |i| {
        indices[index_offset + i] = body_mesh.indices[i];
    }

    vertex_offset += body_mesh.getVertexCount();
    index_offset += body_mesh.getIndexCount();

    // Position and copy wheel 1 (front-left)
    for (0..wheel1_mesh.getVertexCount()) |i| {
        var vertex = wheel1_mesh.vertices[i];
        // Rotate wheel to be perpendicular to the truck
        const temp = vertex.position[1];
        vertex.position[1] = vertex.position[2];
        vertex.position[2] = -temp;

        // Position wheel
        vertex.position[0] -= 0.8; // Left side
        vertex.position[1] -= 0.3; // Below body
        vertex.position[2] += 0.8; // Front

        vertices[vertex_offset + i] = vertex;
    }

    // Adjust wheel 1 indices and copy
    for (0..wheel1_mesh.getIndexCount()) |i| {
        indices[index_offset + i] = wheel1_mesh.indices[i] + @as(u16, @intCast(vertex_offset));
    }

    vertex_offset += wheel1_mesh.getVertexCount();
    index_offset += wheel1_mesh.getIndexCount();

    // Position and copy wheel 2 (front-right)
    for (0..wheel2_mesh.getVertexCount()) |i| {
        var vertex = wheel2_mesh.vertices[i];
        // Rotate wheel to be perpendicular to the truck
        const temp = vertex.position[1];
        vertex.position[1] = vertex.position[2];
        vertex.position[2] = -temp;

        // Position wheel
        vertex.position[0] += 0.8; // Right side
        vertex.position[1] -= 0.3; // Below body
        vertex.position[2] += 0.8; // Front

        vertices[vertex_offset + i] = vertex;
    }

    // Adjust wheel 2 indices and copy
    for (0..wheel2_mesh.getIndexCount()) |i| {
        indices[index_offset + i] = wheel2_mesh.indices[i] + @as(u16, @intCast(vertex_offset));
    }

    vertex_offset += wheel2_mesh.getVertexCount();
    index_offset += wheel2_mesh.getIndexCount();

    // Position and copy wheel 3 (rear-left)
    for (0..wheel3_mesh.getVertexCount()) |i| {
        var vertex = wheel3_mesh.vertices[i];
        // Rotate wheel to be perpendicular to the truck
        const temp = vertex.position[1];
        vertex.position[1] = vertex.position[2];
        vertex.position[2] = -temp;

        // Position wheel
        vertex.position[0] -= 0.8; // Left side
        vertex.position[1] -= 0.3; // Below body
        vertex.position[2] -= 0.8; // Rear

        vertices[vertex_offset + i] = vertex;
    }

    // Adjust wheel 3 indices and copy
    for (0..wheel3_mesh.getIndexCount()) |i| {
        indices[index_offset + i] = wheel3_mesh.indices[i] + @as(u16, @intCast(vertex_offset));
    }

    vertex_offset += wheel3_mesh.getVertexCount();
    index_offset += wheel3_mesh.getIndexCount();

    // Position and copy wheel 4 (rear-right)
    for (0..wheel4_mesh.getVertexCount()) |i| {
        var vertex = wheel4_mesh.vertices[i];
        // Rotate wheel to be perpendicular to the truck
        const temp = vertex.position[1];
        vertex.position[1] = vertex.position[2];
        vertex.position[2] = -temp;

        // Position wheel
        vertex.position[0] += 0.8; // Right side
        vertex.position[1] -= 0.3; // Below body
        vertex.position[2] -= 0.8; // Rear

        vertices[vertex_offset + i] = vertex;
    }

    // Adjust wheel 4 indices and copy
    for (0..wheel4_mesh.getIndexCount()) |i| {
        indices[index_offset + i] = wheel4_mesh.indices[i] + @as(u16, @intCast(vertex_offset));
    }

    return Mesh{
        .vertices = vertices,
        .indices = indices,
        .vertex_buffer_id = 0,
        .index_buffer_id = 0,
        .allocator = allocator,
    };
}
