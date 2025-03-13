# Hill Climber

A retro-style hill climbing game built with Zig, WebAssembly, and WebGL. Race your vehicle up procedurally generated terrain, navigate challenging obstacles, and reach the highest peaks!

## Game Features

- **Pixel Art Sprites**: Retro-style vehicles and environment elements rendered using pixel array art
- **Procedural Generation**: Dynamically generated terrain, obstacles, and environments for endless gameplay
- **Physics-Based Gameplay**: Realistic vehicle physics with suspension, gravity, and terrain interaction
- **Multiple Vehicles**: Choose from different vehicles (bikes, trucks, etc.) with unique handling characteristics
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
  ├── main.zig       (WASM exports and initialization)
  ├── game.zig       (Game state and logic)
  ├── entities.zig   (Game objects like vehicles and terrain)
  ├── renderer.zig   (WebGL rendering system)
  ├── physics.zig    (Vehicle and terrain physics)
  ├── procedural.zig (Procedural generation systems)
  ├── sprites.zig    (Pixel array sprite definitions)
  ├── audio.zig      (Audio system)
  └── assets/        (Game assets to be bundled into WASM)
web/
  ├── index.html     (Main game page)
  ├── webgl.js       (WebGL initialization)
  └── assets/        (General assets to be served)
```

## Implementation Highlights

### Pixel Array Sprites

The game uses pixel arrays for rendering sprites, allowing for efficient memory usage and retro aesthetics:

```zig
// Example pixel array for a motorcycle sprite
const MOTORCYCLE_SPRITE = [_][_]u8{
    .{0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0},
    .{0,0,0,0,0,1,2,2,2,1,0,0,0,0,0,0},
    // ... more rows ...
    .{0,3,3,3,3,0,0,0,0,0,3,3,3,3,0,0},
};
```

### Procedural Terrain

The game generates terrain procedurally, creating unique landscapes each time you play:

```zig
// Generate terrain with varying difficulty
terrain = generateTerrainSegment(allocator, seed, length, difficulty);
```

## Development Roadmap

- [x] Basic vehicle physics and controls
- [x] Simple procedural terrain generation
- [x] Pixel array sprite rendering system
- [ ] Generate bike/truck with pixel art array (Sprites as Pixel Array)
- [ ] Generate trees and rocks procedurally (Pixel Array function based on params + seed)
- [ ] Procedurally generate terrain (include multiple types with different frictions/attributes)
- [ ] Add multiple vehicle types with different characteristics
- [ ] Implement game progression and difficulty scaling
- [ ] Add sound effects and background music
- [ ] Implement a scoring and achievement system
- [ ] Add mobile touch controls

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Built with the Zig programming language
- Based on the [zig-wasm-webgl](https://github.com/haleth-embershield/zig-wasm-webgl) template
- Inspired by classic hill climbing games
- WebAssembly and WebGL communities