# Hill Climber Technical Documentation

## Rendering Pipeline

This document outlines the rendering pipeline and architecture of the Hill Climber game, explaining the design decisions and separation of concerns.

## Architecture Overview

The game is built with a clear separation of concerns, following these principles:

1. **Game Logic**: Managed by `game.zig`
2. **Game Objects**: Defined in `models.zig`
3. **Rendering**: Handled by the renderer module (`renderer/core.zig`)
4. **Mesh Creation**: Defined in `renderer/mesh.zig`
5. **Camera Management**: Handled by `renderer/camera.zig`
6. **Shader Management**: Handled by `renderer/shaders.zig`

This separation allows for better code organization, reusability, and maintainability.

## Rendering Pipeline Flow

The rendering pipeline follows these steps:

1. **Initialization**:
   - Game initializes the renderer
   - Meshes are created in `mesh.zig`
   - Meshes are uploaded to the GPU via the renderer
   - Game objects are created with references to mesh handles

2. **Game Loop**:
   - Game logic updates object positions and states
   - Game objects update their internal state (physics, collisions)
   - Game objects update the renderer with their current state
   - Renderer draws the scene

3. **Rendering**:
   - Renderer clears the screen
   - Renderer applies camera transformations
   - Renderer draws all visible meshes with their current model matrices
   - Renderer presents the frame

## Input System

The game uses a unified input system that handles keyboard, mouse, and touch events in a consistent way. The system is designed to be:

1. **Project Agnostic**: The input system is not tied to any specific game mechanics
2. **Efficient**: Uses bitsets for state tracking
3. **Cross-Platform**: Handles both desktop and mobile input methods
4. **Type-Safe**: Uses enums for key codes and actions

### Input Architecture

The input system consists of these main components:

1. **KeyCode Enum** (`input.zig`):
   - Maps all possible input sources to unique codes
   - Includes keyboard keys (A-Z, 0-9, arrows, etc.)
   - Mouse buttons (Left, Middle, Right, Back, Forward)
   - Touch events (Primary, Secondary)

```zig
pub const KeyCode = enum(u8) {
    // Arrow keys
    ArrowRight = 39,
    ArrowLeft = 37,
    // ... more key definitions ...
    
    // Mouse buttons (200-204)
    MouseLeft = 200,
    MouseRight = 202,
    
    // Touch events (210-211)
    TouchPrimary = 210,
    TouchSecondary = 211,
};
```

2. **Input State Tracking** (`input.zig`):
   - Uses `std.bit_set.IntegerBitSet(256)` for efficient state tracking
   - Tracks current pointer position and movement deltas
   - Maintains scroll wheel state

```zig
pub const InputState = struct {
    key_states: std.bit_set.IntegerBitSet(256),
    pointer: PointerData,
    
    pub fn isKeyPressed(self: *const InputState, key: KeyCode) bool {
        return self.key_states.isSet(@intFromEnum(key));
    }
};
```

3. **Input Actions** (`input.zig`):
   - Defines possible input actions (Press, Release, Move, Scroll)
   - Used to communicate input state changes

```zig
pub const InputAction = enum(u8) {
    Press,
    Release,
    Move,
    Scroll,
};
```

### Input Flow

1. **JavaScript Event Handling** (`web/main.js`):
   - Captures raw browser events (keydown, mousedown, touchstart, etc.)
   - Translates browser events to our custom key codes
   - Calls appropriate WASM functions with normalized data

2. **WASM Input Processing** (`main.zig`):
   - Receives normalized input events from JavaScript
   - Routes input to the game's input handler

3. **Game Input Handling** (`game.zig`):
   - Updates input state based on received events
   - Processes input based on current game state
   - Maps input to game actions

### Example Usage

```zig
// Check for keyboard input
if (input_state.isKeyPressed(.ArrowRight) or input_state.isKeyPressed(.KeyD)) {
    // Move right
}

// Handle mouse/touch position
const pointer = input_state.getPointerPosition();
const mouse_x = pointer.x;
const mouse_y = pointer.y;

// Check for mouse buttons
if (input_state.isKeyPressed(.MouseLeft)) {
    // Handle left click
}
```

### Design Benefits

1. **Unified Interface**: All input types (keyboard, mouse, touch) are handled through the same interface
2. **State Management**: Efficient tracking of input states using bitsets
3. **Type Safety**: Enum-based key codes prevent errors from invalid key values
4. **Platform Independence**: Input system works the same way regardless of input method
5. **Easy Extension**: New input types can be added by extending the KeyCode enum

## Component Responsibilities

### Game (game.zig)

The Game module is responsible for:
- Managing game state (menu, playing, paused, etc.)
- Handling user input
- Updating game objects
- Coordinating the rendering process

```zig
// Game update loop
pub fn update(self: *Game, delta_time: f32) void {
    // Update game objects
    self.truck.update(delta_time);
    
    // Update renderer with current object states
    self.truck.updateRenderer(&self.renderer);
    self.terrain.updateRenderer(&self.renderer);
    
    // Render the game
    self.renderGame();
}
```

### Models (models.zig)

The Models module defines game objects and their behavior:
- `Model`: Base structure for all 3D objects
- `Vehicle`: Player-controlled vehicle with physics
- `Terrain`: Game terrain

```zig
// Model structure
pub const Model = struct {
    mesh_handle: u32,
    position: [3]f32,
    rotation: [3]f32,
    scale: [3]f32,
    model_type: ModelType,
    
    // Methods to manipulate the model
    pub fn setPosition(self: *Model, x: f32, y: f32, z: f32) void {
        self.position = [_]f32{ x, y, z };
    }
    
    // Update the renderer with current state
    pub fn updateRenderer(self: Model, renderer_obj: *renderer.Renderer) void {
        renderer_obj.updateModelMatrix(self.mesh_handle, self.position, self.rotation, self.scale);
    }
};
```

### Renderer (renderer/core.zig)

The Renderer module handles all rendering operations:
- Managing WebGL context and commands
- Uploading meshes to the GPU
- Maintaining model matrices for all objects
- Rendering the scene

```zig
// Renderer structure
pub const Renderer = struct {
    // Renderable objects
    mesh_count: u32,
    model_matrices: []?[16]f32,
    mesh_ids: []u32,
    is_visible: []bool,
    
    // Add a mesh to the renderer
    pub fn addMesh(self: *Renderer, mesh: mesh_mod.Mesh) !u32 {
        // Upload mesh to GPU and return a handle
    }
    
    // Update model matrix for a mesh
    pub fn updateModelMatrix(self: *Renderer, handle: u32, position: [3]f32, rotation: [3]f32, scale: [3]f32) void {
        // Update the model matrix for the specified mesh
    }
    
    // Render the scene
    pub fn renderScene(self: *Renderer) void {
        // Render all visible meshes
    }
};
```

### Mesh (renderer/mesh.zig)

The Mesh module defines 3D geometry:
- Vertex and index data for meshes
- Functions to create standard shapes (box, cylinder, etc.)
- Functions to create game-specific meshes (truck, terrain)

```zig
// Mesh structure
pub const Mesh = struct {
    vertices: []Vertex,
    indices: []u16,
    
    // Get vertex data for WebGL
    pub fn getVertexDataPtr(self: *const Mesh) [*]const f32 {
        return @ptrCast(self.vertices.ptr);
    }
};

// Create a truck mesh
pub fn createTruck(allocator: std.mem.Allocator, body_color: [4]f32, wheel_color: [4]f32) !Mesh {
    // Create a truck mesh from basic shapes
}
```

## Design Decisions

### 1. Separation of Rendering from Game Logic

We've separated the rendering code from the game logic to:
- Make the code more maintainable
- Allow for easier changes to the rendering system
- Make the code more reusable for future projects

### 2. Generic Renderer with Object Handles

Instead of hardcoding specific objects in the renderer, we use a generic approach:
- Meshes are added to the renderer and assigned handles
- Game objects store these handles
- Game objects update the renderer with their current state

This approach allows for:
- Adding/removing objects dynamically
- Changing object visibility
- Supporting any number of objects (up to a predefined limit)

### 3. Model-View-Controller Pattern

The architecture follows a loose MVC pattern:
- **Model**: Game objects in `models.zig`
- **View**: Rendering in `renderer/core.zig`
- **Controller**: Game logic in `game.zig`

### 4. Matrix Math in Renderer

All matrix operations are defined in the renderer module:
- `identityMatrix`: Reset a matrix to identity
- `translateMatrix`: Apply translation to a matrix
- `rotateYMatrix`: Apply Y-axis rotation to a matrix
- `scaleMatrix`: Apply scaling to a matrix

This keeps all transformation logic in one place and makes it reusable.

## Optimization Considerations

1. **Batched Rendering**:
   - Commands are batched to reduce WebGL API calls
   - The command buffer is sent to WebGL in a single operation

2. **Visibility Culling**:
   - Objects can be marked as invisible to skip rendering
   - Only visible objects are processed during rendering

3. **Memory Management**:
   - Meshes are uploaded to the GPU once during initialization
   - Only model matrices are updated each frame

## Future Improvements

1. **Scene Graph**:
   - Implement a hierarchical scene graph for parent-child relationships
   - Allow objects to be attached to other objects

2. **Frustum Culling**:
   - Add frustum culling to skip rendering objects outside the camera view

3. **Instanced Rendering**:
   - Use instanced rendering for multiple instances of the same mesh

4. **Shader Variants**:
   - Support multiple shader programs for different visual effects

## Conclusion

This architecture provides a solid foundation for the Hill Climber game while keeping the code organized, maintainable, and reusable for future projects. The clear separation of concerns allows for easier debugging and extension of the codebase. 