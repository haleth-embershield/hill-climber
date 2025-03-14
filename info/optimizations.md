Based on the code you've shared, your renderer.zig already has a few important optimizations for WebGL:

Command Batching: You've implemented a command buffer system (CommandBuffer) that batches WebGL operations rather than making individual calls. This significantly reduces the overhead of JS-to-WASM calls by sending multiple commands at once.
Buffer Reuse: You're reusing the same command buffer and frame buffer across frames, avoiding constant reallocation.
Single Draw Call: Your renderer combines all rendering into a single texture and issues just one draw call per frame (in endFrame() with addDrawCommand()), which is very efficient for WebGL.
Optimized Memory Layout: Your command buffer uses a compact, fixed-stride memory layout that's efficient to process on the JavaScript side with the executeBatchedCommands function.
Minimal State Changes: The code avoids unnecessary WebGL state changes by uploading the entire frame as a texture and drawing it all at once.
Bounds Checking: All drawing functions include bounds checking to prevent buffer overruns, which could cause crashes or undefined behavior.

When you transition to isometric 3D with WebGL, you'll want to preserve these optimizations while adding 3D-specific ones. For example, you might want to implement frustum culling, depth sorting for transparent objects, and instanced rendering for repeated geometry.