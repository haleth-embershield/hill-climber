We are using Zig v0.14 to create a WASM game. We can use some of the std library like math, but WASM is freestanding so no OS specific features. We want this game to be optimized, not sloppy. This is a demo to showcase zig + wasm + webgl so for now we can keep it simple (models and game assets do not need to be crazy detailed to start)

We want to do as much as possible in ZIG and WASM, we do not want to use the index.html or webgl.js. We will only use those two files for WASM glue to connect our zig game to the browser enviroment.

**IMPORTANT:**
- We want to reuse our rendering and other code in future projects. So keep the rendering engine and code project-agnostic and professional so future projects can benefit from the work we did here!
- You're a great developer, we are excited to work with you!