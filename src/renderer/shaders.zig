const std = @import("std");

/// WebGL shader types
pub const ShaderType = enum(u32) {
    Vertex = 0x8B31, // GL_VERTEX_SHADER
    Fragment = 0x8B30, // GL_FRAGMENT_SHADER
};

/// Shader program for rendering
pub const ShaderProgram = struct {
    program_id: u32,
    vertex_shader_id: u32,
    fragment_shader_id: u32,

    /// Create a new shader program
    pub fn init(_: []const u8, _: []const u8) ShaderProgram {
        return ShaderProgram{
            .program_id = 0,
            .vertex_shader_id = 0,
            .fragment_shader_id = 0,
        };
    }
};

/// Basic vertex shader for 3D rendering with position, normal, and color
pub const basic_vertex_shader =
    \\attribute vec3 a_position;
    \\attribute vec3 a_normal;
    \\attribute vec4 a_color;
    \\
    \\uniform mat4 u_modelViewProjection;
    \\uniform mat4 u_model;
    \\
    \\varying vec3 v_normal;
    \\varying vec4 v_color;
    \\varying vec3 v_position;
    \\
    \\void main() {
    \\    // Transform position to clip space
    \\    gl_Position = u_modelViewProjection * vec4(a_position, 1.0);
    \\    
    \\    // Pass normal and color to fragment shader
    \\    v_normal = mat3(u_model) * a_normal;
    \\    v_color = a_color;
    \\    
    \\    // Pass world position for lighting
    \\    v_position = (u_model * vec4(a_position, 1.0)).xyz;
    \\}
;

/// Basic fragment shader with simple directional lighting
pub const basic_fragment_shader =
    \\precision mediump float;
    \\
    \\varying vec3 v_normal;
    \\varying vec4 v_color;
    \\varying vec3 v_position;
    \\
    \\uniform vec3 u_lightDirection;
    \\uniform vec3 u_viewPosition;
    \\
    \\void main() {
    \\    // Normalize vectors
    \\    vec3 normal = normalize(v_normal);
    \\    vec3 lightDir = normalize(u_lightDirection);
    \\    
    \\    // Ambient lighting
    \\    float ambientStrength = 0.3;
    \\    vec3 ambient = ambientStrength * v_color.rgb;
    \\    
    \\    // Diffuse lighting
    \\    float diff = max(dot(normal, lightDir), 0.0);
    \\    vec3 diffuse = diff * v_color.rgb;
    \\    
    \\    // Specular lighting
    \\    float specularStrength = 0.5;
    \\    vec3 viewDir = normalize(u_viewPosition - v_position);
    \\    vec3 reflectDir = reflect(-lightDir, normal);
    \\    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32.0);
    \\    vec3 specular = specularStrength * spec * vec3(1.0, 1.0, 1.0);
    \\    
    \\    // Combine lighting
    \\    vec3 result = ambient + diffuse + specular;
    \\    gl_FragColor = vec4(result, v_color.a);
    \\}
;

/// Simple vertex shader for flat color rendering
pub const simple_vertex_shader =
    \\attribute vec3 a_position;
    \\attribute vec4 a_color;
    \\
    \\uniform mat4 u_modelViewProjection;
    \\
    \\varying vec4 v_color;
    \\
    \\void main() {
    \\    gl_Position = u_modelViewProjection * vec4(a_position, 1.0);
    \\    v_color = a_color;
    \\}
;

/// Simple fragment shader for flat color rendering
pub const simple_fragment_shader =
    \\precision mediump float;
    \\
    \\varying vec4 v_color;
    \\
    \\void main() {
    \\    gl_FragColor = v_color;
    \\}
;

/// WebGL function bindings for shader operations
extern fn createShader(shader_type: u32, source_ptr: [*]const u8, source_len: usize) u32;
extern fn createProgram(vertex_shader_id: u32, fragment_shader_id: u32) u32;
extern fn deleteShader(shader_id: u32) void;
extern fn deleteProgram(program_id: u32) void;
extern fn useProgram(program_id: u32) void;
extern fn getUniformLocation(program_id: u32, name_ptr: [*]const u8, name_len: usize) i32;
extern fn setUniformMatrix4fv(location: i32, value_ptr: [*]const f32) void;
extern fn setUniform3f(location: i32, x: f32, y: f32, z: f32) void;
extern fn setUniform4f(location: i32, x: f32, y: f32, z: f32, w: f32) void;

/// Create and compile a shader
pub fn compileShader(shader_type: ShaderType, source: []const u8) u32 {
    return createShader(@intFromEnum(shader_type), source.ptr, source.len);
}

/// Create a shader program from vertex and fragment shaders
pub fn createShaderProgram(vertex_source: []const u8, fragment_source: []const u8) ShaderProgram {
    const vertex_shader_id = compileShader(.Vertex, vertex_source);
    const fragment_shader_id = compileShader(.Fragment, fragment_source);
    const program_id = createProgram(vertex_shader_id, fragment_shader_id);

    return ShaderProgram{
        .program_id = program_id,
        .vertex_shader_id = vertex_shader_id,
        .fragment_shader_id = fragment_shader_id,
    };
}

/// Use a shader program for rendering
pub fn useShaderProgram(program: ShaderProgram) void {
    useProgram(program.program_id);
}

/// Delete a shader program and its shaders
pub fn deleteShaderProgram(program: *ShaderProgram) void {
    deleteShader(program.vertex_shader_id);
    deleteShader(program.fragment_shader_id);
    deleteProgram(program.program_id);

    program.vertex_shader_id = 0;
    program.fragment_shader_id = 0;
    program.program_id = 0;
}

/// Set a 4x4 matrix uniform in a shader
pub fn setMatrix4Uniform(program_id: u32, name: []const u8, matrix: *const [16]f32) void {
    const location = getUniformLocation(program_id, name.ptr, name.len);
    if (location >= 0) {
        setUniformMatrix4fv(location, matrix.ptr);
    }
}

/// Set a vec3 uniform in a shader
pub fn setVec3Uniform(program_id: u32, name: []const u8, x: f32, y: f32, z: f32) void {
    const location = getUniformLocation(program_id, name.ptr, name.len);
    if (location >= 0) {
        setUniform3f(location, x, y, z);
    }
}

/// Set a vec4 uniform in a shader
pub fn setVec4Uniform(program_id: u32, name: []const u8, x: f32, y: f32, z: f32, w: f32) void {
    const location = getUniformLocation(program_id, name.ptr, name.len);
    if (location >= 0) {
        setUniform4f(location, x, y, z, w);
    }
}
