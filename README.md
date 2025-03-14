# Isometric Hill Climber

A hill climbing game built with Zig, WebAssembly, and WebGL. Race your vehicle up procedurally generated terrain, navigate challenging obstacles, and reach the highest peaks!

## Game Features

- **Procedural Generation**: Dynamically generated terrain, obstacles, and environments for endless gameplay
- **Physics-Based Gameplay**: Realistic vehicle physics with suspension, gravity, and terrain interaction
- **Progressive Difficulty**: Increasingly challenging terrain as you advance

## Getting Started

### Prerequisites

- Zig 0.14.0 or later

### Building and Running

```bash
# Build and run the project (starts a local web server)
zig build run

# Just build and deploy without running the server
zig build deploy
```

## Game Controls

- **Arrow Up/Down**: Accelerate/Brake
- **Arrow Left/Right**: Tilt vehicle
- **R**: Reset vehicle position
- **P**: Pause game
- **M**: Toggle mute audio
- **1-3**: Select different vehicles

## Project Structure

```
src/
  ├── main.zig         (WASM exports and initialization)
  ├── game.zig         (Game state and logic)
  ├── models.zig       (Game objects like vehicles and terrain)
  ├── renderer/        (WebGL rendering system)
  │   ├── core.zig     (Main rendering functionality)
  │   ├── camera.zig   (Camera positioning and projection)
  │   ├── shaders.zig  (Shader programs and uniforms)
  │   └── mesh.zig     (Mesh creation and management)
  ├── physics.zig      (Vehicle and terrain physics)
  ├── procedural.zig   (Procedural generation systems)
  ├── audio.zig        (Audio system)
  └── assets/          (Game assets to be bundled into WASM)
      ├── audio/       (Audio files)
      └── shaders/     (GLSL shader code)
```

## Implementation Highlights



### Procedural Terrain

The game generates terrain procedurally, creating unique landscapes each time you play:


## Development Roadmap

### Phase 1: Setup and Basic Rendering
- [ ] Set up WebGL context and Zig WASM bridge (see @core.zig)
- [ ] Implement basic matrix math in Zig (projection, rotation)
- [ ] Create simple truck mesh with vertex buffer
- [ ] Add isometric projection (45° tilt)
- [ ] Generate and render basic hill mesh
- [ ] Set up depth testing and basic shaders

### Phase 2: Movement and Physics
- [ ] Add truck position and rotation handling
- [ ] Implement basic physics (gravity, friction)
- [ ] Add keyboard controls for truck movement
- [ ] Generate procedural hill terrain (sine waves/slopes)
- [ ] Add hill collision detection and response
- [ ] Make truck tilt based on hill slope

### Phase 3: Visual Enhancement
- [ ] Add procedurally generated trees
- [ ] Implement tree shadows and transparency
- [ ] Improve truck and terrain shaders
- [ ] Add basic particle effects (dust, exhaust)
- [ ] Implement smooth camera follow

### Phase 4: Polish and Features
- [ ] Optimize rendering with batching
- [ ] Add multiple vehicle types
- [ ] Implement scoring system
- [ ] Add sound effects and music
- [ ] Add touch controls for mobile
- [ ] Polish visuals and gameplay feel

### Phase 5: Future Enhancements
- [ ] Port to WebGPU
- [ ] Add compute shader terrain generation
- [ ] Expand to full 3D with free camera
- [ ] Add multiplayer support
- [ ] Implement advanced visual effects

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Built with the Zig programming language
- Based on the [zig-wasm-webgl](https://github.com/haleth-embershield/zig-wasm-webgl) template
- Inspired by classic hill climbing games
- WebAssembly and WebGL communities