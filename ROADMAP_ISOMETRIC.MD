# ROADMAP_ISOMETRIC.MD

## Project: Isometric Hill Climb Game
**Goal**: Build a hill climb game in an isometric view using Zig + WASM + WebGL, focusing on learning WebGL's 3D capabilities, procedural generation, and a smooth transition to WebGPU and full 3D in the future.

**Why Isometric?**
- Bridges 2D and 3D: Introduces 3D concepts (meshes, depth, matrices) while keeping gameplay manageable.
- Learning Focus: Prepares you for WebGPU and 3D with hands-on experience in WebGL’s pipeline.
- Visual Appeal: Adds depth and a modern twist to the classic hill climb formula.

---

## Roadmap

### Phase 1: Setup and Basic Rendering
**Objective**: Get an isometric scene running with a static truck and hill.
- **Tech**: Zig (logic), WASM (bridge), WebGL (rendering).
- **Steps**:
  1. **Zig Setup**:
     - Define a simple truck mesh (e.g., a box with wheels) as a vertex array with x, y, z coordinates.
     - Example:
       ```zig
       const Vertex = struct { x: f32, y: f32, z: f32 };
       var truck_vertices: [6]Vertex = undefined; // 2 triangles for body
       fn initTruck() void {
           truck_vertices[0] = .{ .x = 0.0, .y = 0.0, .z = 0.0 };
           truck_vertices[1] = .{ .x = 1.0, .y = 0.0, .z = 0.0 };
           truck_vertices[2] = .{ .x = 0.0, .y = 0.5, .z = 0.1 };
           truck_vertices[3] = .{ .x = 1.0, .y = 0.0, .z = 0.0 };
           truck_vertices[4] = .{ .x = 1.0, .y = 0.5, .z = 0.1 };
           truck_vertices[5] = .{ .x = 0.0, .y = 0.5, .z = 0.1 };
       }
       export fn getTruckVertices() [*]f32 {
           return @ptrCast(&truck_vertices);
       }
       ```
  2. **WebGL Setup**:
     - Initialize WebGL context via JavaScript/WASM glue.
     - Upload truck vertices to a vertex buffer.
     - Use an orthographic projection matrix with a 45° tilt for isometric view.
     - Example matrix setup (JS side):
       ```javascript
       const m = mat4.create();
       mat4.ortho(m, -5, 5, -5, 5, 0, 10); // Adjust bounds
       mat4.rotateX(m, m, -Math.PI / 4); // Tilt for isometric
       mat4.rotateZ(m, m, Math.PI / 4);
       ```
  3. **Basic Shader**:
     - Vertex shader: Transform vertices with the projection matrix.
     - Fragment shader: Flat color (e.g., red truck).
     - Render with `glDrawArrays(gl.TRIANGLES, 0, 6)`.
  4. **Hill**:
     - Generate a simple hill mesh (e.g., a series of connected triangles) in Zig.
     - Render it below the truck with a different color (e.g., green).

**Milestone**: Static isometric scene with a truck on a hill.

---

### Phase 2: Movement and Physics
**Objective**: Make the truck move across the hill with basic physics.
- **Steps**:
  1. **Truck Movement**:
     - Add a position vector in Zig (e.g., `var truckPos: [3]f32 = .{0, 0, 0};`).
     - Update position based on input (e.g., arrow keys via WASM exports).
     - Pass position as a uniform to the vertex shader for translation.
  2. **Hill Interaction**:
     - Procedurally generate hill vertices in Zig (e.g., a sine wave or random slopes).
     - Implement basic collision: Adjust truck’s y and z based on hill height at x.
     - Example: Linear interpolation between hill vertices.
  3. **Rotation**:
     - Tilt the truck mesh based on hill slope (simple angle calc in Zig, applied via a rotation matrix).

**Milestone**: Truck drives across a procedurally generated isometric hill, tilting with the terrain.

---

### Phase 3: Trees and Shadows
**Objective**: Add trees and dynamic shadows to enhance the isometric feel.
- **Steps**:
  1. **Tree Meshes**:
     - Define a tree as a trunk (thin rectangle) and canopy (triangle or trapezoid) in Zig.
     - Randomize height/position procedurally.
     - Render with a green shader.
  2. **Shadows**:
     - Create a shadow mesh (e.g., an oval quad) per tree.
     - Position it based on a virtual light source (e.g., offset x, z from tree base).
     - Use alpha blending (`glEnable(gl.BLEND)`) for semi-transparency.
     - Move shadow across truck mesh when overlapping (adjust position dynamically).
  3. **Shader Upgrade**:
     - Optional: Use a fragment shader to darken truck pixels under the shadow (pass shadow position as a uniform).

**Milestone**: Isometric scene with moving truck, trees, and shadows.

---

### Phase 4: Polish and Optimization
**Objective**: Refine visuals and performance for a playable demo.
- **Steps**:
  1. **Visuals**:
     - Add colors or gradients to shaders (e.g., truck details, hill texture).
     - Smooth out hill generation (e.g., Bezier curves).
  2. **Performance**:
     - Batch truck, hill, and trees into one vertex buffer if possible.
     - Minimize WASM-to-WebGL calls (e.g., update uniforms in bulk).
  3. **Gameplay**:
     - Add speed, friction, or fuel mechanics in Zig.

**Milestone**: Playable isometric hill climb demo.

---

### Phase 5: Transition to WebGPU
**Objective**: Port to WebGPU for better performance and 3D readiness.
- **Steps**:
  1. **WebGPU Setup**:
     - Replace WebGL with WebGPU bindings in Zig (e.g., `wgpu-zig` if available).
     - Adapt vertex buffers and shaders to WebGPU’s API.
  2. **Enhancements**:
     - Use compute shaders for procedural hill generation.
     - Add 3D camera (perspective projection) for a full 3D test.
  3. **3D Leap**:
     - Expand truck to a full 3D model (e.g., load a simple OBJ or define in Zig).
     - Let the camera rotate freely.

**Milestone**: WebGPU-powered isometric game, ready for 3D evolution.

---

## Recommendations
- **Start Isometric**: It’s the best balance of challenge and reward for your goals. Learn 3D WebGL concepts now, making WebGPU and 3D a natural next step.
- **Use Meshes First**: Begin with vertex-based meshes for truck, hill, and trees. They’re easier to grasp than shaders and scale well.
- **Add Shaders Later**: Experiment with fragment shaders for shadows or effects once comfortable (e.g., SDFs for smooth shapes).
- **Procedural Focus**: Leverage Zig for dynamic hill and tree generation—keep it flexible and fun.
- **Fallback**: If isometric bogs down, simplify to 2D side-scrolling temporarily, then reintroduce depth.

## Next Steps
- **Immediate**: Implement Phase 1—get a static truck and hill in isometric view.
- **Learning**: Study WebGL matrices (ortho projection) and basic GLSL shaders.
- **Ask**: Need help with Zig mesh code, WebGL setup, or physics? I’m here!

**Date**: March 13, 2025


----------

# Claude Amended Roadmap

## Optimized Language and API Approach

### Zig-Centric Architecture
**Objective**: Minimize JavaScript code while maximizing Zig/WASM usage.
- **Core Principle**: Keep all game logic, physics, and matrix math in Zig.
- **JavaScript Role**: Limited to essential WebGL context setup and render loop.

### Matrix Handling in Zig
- Replace JavaScript matrix operations with Zig implementations:
  ```zig
  // In Zig - create projection matrix
  fn createIsometricProjection() void {
      // Initialize orthographic projection
      projectionMatrix = [_]f32{
          2.0/(right-left), 0.0, 0.0, 0.0,
          0.0, 2.0/(top-bottom), 0.0, 0.0,
          0.0, 0.0, -2.0/(far-near), 0.0,
          -(right+left)/(right-left), -(top+bottom)/(top-bottom), -(far+near)/(far-near), 1.0
      };
      
      // Apply isometric rotations
      rotateX(&projectionMatrix, -std.math.pi / 4.0);
      rotateZ(&projectionMatrix, std.math.pi / 4.0);
  }
  
  // Export for WebGL shader uniforms
  export fn getProjectionMatrix() [*]f32 {
      return &projectionMatrix;
  }
  ```

### WebGL Integration Strategy
Consider these options for WebGL integration:

1. **Recommended Hybrid Approach**:
   - Define core rendering functions in Zig that JavaScript calls
   - Example:
     ```zig
     // Zig exports
     export fn createVertexBuffer(vertices: [*]f32, count: usize) u32 { ... }
     export fn drawScene() void { ... }
     ```
     ```javascript
     // JavaScript calls
     function render() {
       wasm.drawScene();
       requestAnimationFrame(render);
     }
     ```

2. **Alternative: Full Binding Layer**:
   - Create a complete WebGL binding API in JavaScript
   - Pass this API to Zig during initialization
   - Handle all rendering calls directly from Zig

### Phase 1 Enhancement: Initial WebGL Setup
- Add depth testing early: `gl.enable(gl.DEPTH_TEST)`
- Consider implementing a simple camera system in Zig
- Export buffer creation functions from Zig:
  ```zig
  export fn createMeshBuffer(vertices: [*]f32, count: usize) u32 {
      // Buffer creation logic
      return bufferId;
  }
  ```

### Phase 2 Enhancement: Physics and Collision
- Implement Verlet integration in Zig for smoother physics
- Add camera follow logic to keep truck centered
- Batch hill vertices for better performance

### Phase 4 Enhancement: Optimization Focus
- Implement frustum culling to avoid rendering off-screen objects
- Minimize WASM-JS boundary crossings by batching operations
- Consider using WebGL instancing for repeated objects (trees)

## Build and Development Considerations
- **Minimal Build Requirements**: For your minimal JS/HTML setup, Bun compilation offers little performance benefit
- **Development Focus**: Optimize within Zig rather than JS tooling
- **Critical Areas**:
  1. Efficient mesh representation
  2. Batched WebGL calls
  3. Minimized memory transfers across WASM boundary
  4. Optimized matrix operations for isometric view

## Next Steps Revised
1. Implement matrix math and projection setup in Zig
2. Create exported buffer and render functions in Zig
3. Set up a minimal JavaScript wrapper for WebGL context
4. Focus on game logic entirely within the Zig environment