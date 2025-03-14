const std = @import("std");
const math = std.math;

/// Camera for isometric view
pub const Camera = struct {
    // Projection matrix (4x4)
    projection: [16]f32,
    // View matrix (4x4)
    view: [16]f32,
    // Combined view-projection matrix
    view_projection: [16]f32,
    // Camera position
    position: [3]f32,
    // Camera rotation (in radians)
    rotation: [3]f32,
    // Camera target (look-at point)
    target: [3]f32,

    /// Initialize a new isometric camera
    pub fn init() Camera {
        // Calculate position for true isometric view (approx 25 units away)
        // Using 1/sqrt(3) ≈ 0.577 for each axis gives a unit vector in isometric direction
        const distance = 25.0;
        const iso_factor = 0.577;

        var camera = Camera{
            .projection = [_]f32{0} ** 16,
            .view = [_]f32{0} ** 16,
            .view_projection = [_]f32{0} ** 16,
            .position = [_]f32{ distance * iso_factor, distance * iso_factor, distance * iso_factor },
            .rotation = [_]f32{ -math.pi / 4.0, 0, math.pi / 4.0 }, // Classic isometric angles
            .target = [_]f32{ 0, 0, 0 }, // Look at origin
        };

        // Initialize with identity matrices
        identityMatrix(&camera.projection);
        identityMatrix(&camera.view);
        identityMatrix(&camera.view_projection);

        // Set up initial matrices
        camera.updateViewMatrix();
        camera.setOrthographicProjection(-15, 15, -15, 15, 0.1, 100.0); // Wider view frustum to see more
        camera.updateViewProjectionMatrix();

        return camera;
    }

    /// Set orthographic projection matrix
    pub fn setOrthographicProjection(self: *Camera, left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) void {
        // Clear matrix
        for (0..16) |i| {
            self.projection[i] = 0;
        }

        // Set orthographic projection values
        self.projection[0] = 2.0 / (right - left);
        self.projection[5] = 2.0 / (top - bottom);
        self.projection[10] = -2.0 / (far - near);
        self.projection[12] = -(right + left) / (right - left);
        self.projection[13] = -(top + bottom) / (top - bottom);
        self.projection[14] = -(far + near) / (far - near);
        self.projection[15] = 1.0;

        // Update combined matrix
        self.updateViewProjectionMatrix();
    }

    /// Update the view matrix based on position and rotation
    pub fn updateViewMatrix(self: *Camera) void {
        // Start with identity matrix
        identityMatrix(&self.view);

        // Create a look-at matrix to ensure camera points at the target (origin)
        lookAt(self.position[0], self.position[1], self.position[2], self.target[0], self.target[1], self.target[2], 0, 1, 0, // Up vector (Y-up)
            &self.view);

        // Apply any additional rotations if needed
        // Note: lookAt already handles rotation, so only use these if you need additional rotation
        // rotateMatrixX(&self.view, self.rotation[0]);
        // rotateMatrixY(&self.view, self.rotation[1]);
        // rotateMatrixZ(&self.view, self.rotation[2]);

        // Update combined matrix
        self.updateViewProjectionMatrix();
    }

    /// Update the combined view-projection matrix
    pub fn updateViewProjectionMatrix(self: *Camera) void {
        // Multiply projection * view
        multiplyMatrices(&self.projection, &self.view, &self.view_projection);
    }

    /// Get pointer to the view-projection matrix for shaders
    pub fn getViewProjectionMatrixPtr(self: *Camera) *const [16]f32 {
        return &self.view_projection;
    }

    /// Update camera to follow a target position
    pub fn followTarget(self: *Camera, target_position: [3]f32, offset: [3]f32) void {
        // Update camera target
        self.target[0] = target_position[0];
        self.target[1] = target_position[1];
        self.target[2] = target_position[2];

        // Update camera position to maintain the same relative position
        self.position[0] = target_position[0] + offset[0];
        self.position[1] = target_position[1] + offset[1];
        self.position[2] = target_position[2] + offset[2];

        // Update view matrix with new position and target
        self.updateViewMatrix();
    }

    /// Rotate the camera 90 degrees around the vertical axis (Y-axis)
    /// This maintains the same distance and isometric angle but shifts to a different viewpoint
    pub fn rotateIsometricView(self: *Camera) void {
        // Store the current distance from target
        const dx = self.position[0] - self.target[0];
        // const dy = self.position[1] - self.target[1];
        const dz = self.position[2] - self.target[2];
        // const distance = math.sqrt(dx * dx + dy * dy + dz * dz);

        // Rotate 90 degrees around Y axis (swap and negate X and Z components)
        const old_x = dx;
        const old_z = dz;

        // Calculate new position after 90-degree rotation
        self.position[0] = self.target[0] - old_z; // -Z becomes new X
        self.position[2] = self.target[2] + old_x; // X becomes new Z

        // Y component stays the same in a Y-axis rotation

        // Update view matrix with the new position
        self.updateViewMatrix();
    }
};

/// Look-at function to create view matrix
fn lookAt(eyeX: f32, eyeY: f32, eyeZ: f32, targetX: f32, targetY: f32, targetZ: f32, upX: f32, upY: f32, upZ: f32, view: *[16]f32) void {
    // Calculate forward vector (normalized direction from eye to target)
    var fx = targetX - eyeX;
    var fy = targetY - eyeY;
    var fz = targetZ - eyeZ;

    // Normalize forward vector
    const f_len = math.sqrt(fx * fx + fy * fy + fz * fz);
    if (f_len > 0.00001) {
        fx /= f_len;
        fy /= f_len;
        fz /= f_len;
    }

    // Calculate right vector with cross product (forward × up)
    var rx = fy * upZ - fz * upY;
    var ry = fz * upX - fx * upZ;
    var rz = fx * upY - fy * upX;

    // Normalize right vector
    const r_len = math.sqrt(rx * rx + ry * ry + rz * rz);
    if (r_len > 0.00001) {
        rx /= r_len;
        ry /= r_len;
        rz /= r_len;
    }

    // Recalculate up vector with cross product (right × forward)
    const ux = ry * fz - rz * fy;
    const uy = rz * fx - rx * fz;
    const uz = rx * fy - ry * fx;

    // Set the view matrix
    view[0] = rx;
    view[1] = ux;
    view[2] = -fx;
    view[3] = 0.0;

    view[4] = ry;
    view[5] = uy;
    view[6] = -fy;
    view[7] = 0.0;

    view[8] = rz;
    view[9] = uz;
    view[10] = -fz;
    view[11] = 0.0;

    view[12] = -(rx * eyeX + ry * eyeY + rz * eyeZ);
    view[13] = -(ux * eyeX + uy * eyeY + uz * eyeZ);
    view[14] = fx * eyeX + fy * eyeY + fz * eyeZ;
    view[15] = 1.0;
}

/// Set matrix to identity
fn identityMatrix(matrix: *[16]f32) void {
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

/// Translate matrix by x, y, z
fn translateMatrix(matrix: *[16]f32, x: f32, y: f32, z: f32) void {
    matrix[12] = matrix[0] * x + matrix[4] * y + matrix[8] * z + matrix[12];
    matrix[13] = matrix[1] * x + matrix[5] * y + matrix[9] * z + matrix[13];
    matrix[14] = matrix[2] * x + matrix[6] * y + matrix[10] * z + matrix[14];
    matrix[15] = matrix[3] * x + matrix[7] * y + matrix[11] * z + matrix[15];
}

/// Rotate matrix around X axis
fn rotateMatrixX(matrix: *[16]f32, angle: f32) void {
    const c = math.cos(angle);
    const s = math.sin(angle);

    const m1 = matrix[4];
    const m2 = matrix[5];
    const m3 = matrix[6];
    const m4 = matrix[7];
    const m5 = matrix[8];
    const m6 = matrix[9];
    const m7 = matrix[10];
    const m8 = matrix[11];

    matrix[4] = m1 * c + m5 * s;
    matrix[5] = m2 * c + m6 * s;
    matrix[6] = m3 * c + m7 * s;
    matrix[7] = m4 * c + m8 * s;
    matrix[8] = m5 * c - m1 * s;
    matrix[9] = m6 * c - m2 * s;
    matrix[10] = m7 * c - m3 * s;
    matrix[11] = m8 * c - m4 * s;
}

/// Rotate matrix around Y axis
fn rotateMatrixY(matrix: *[16]f32, angle: f32) void {
    const c = math.cos(angle);
    const s = math.sin(angle);

    const m1 = matrix[0];
    const m2 = matrix[1];
    const m3 = matrix[2];
    const m4 = matrix[3];
    const m5 = matrix[8];
    const m6 = matrix[9];
    const m7 = matrix[10];
    const m8 = matrix[11];

    matrix[0] = m1 * c - m5 * s;
    matrix[1] = m2 * c - m6 * s;
    matrix[2] = m3 * c - m7 * s;
    matrix[3] = m4 * c - m8 * s;
    matrix[8] = m1 * s + m5 * c;
    matrix[9] = m2 * s + m6 * c;
    matrix[10] = m3 * s + m7 * c;
    matrix[11] = m4 * s + m8 * c;
}

/// Rotate matrix around Z axis
fn rotateMatrixZ(matrix: *[16]f32, angle: f32) void {
    const c = math.cos(angle);
    const s = math.sin(angle);

    const m1 = matrix[0];
    const m2 = matrix[1];
    const m3 = matrix[2];
    const m4 = matrix[3];
    const m5 = matrix[4];
    const m6 = matrix[5];
    const m7 = matrix[6];
    const m8 = matrix[7];

    matrix[0] = m1 * c + m5 * s;
    matrix[1] = m2 * c + m6 * s;
    matrix[2] = m3 * c + m7 * s;
    matrix[3] = m4 * c + m8 * s;
    matrix[4] = m5 * c - m1 * s;
    matrix[5] = m6 * c - m2 * s;
    matrix[6] = m7 * c - m3 * s;
    matrix[7] = m8 * c - m4 * s;
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
