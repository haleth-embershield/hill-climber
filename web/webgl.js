// WebGL interface for WASM Game

// Global WebGL context and resources
let gl = null;
let texture = null;
let shaderProgram = null;
let vertexBuffer = null;
let indexBuffer = null;

// Store resources by ID for reference
const glResources = {
    buffers: {},
    shaders: {},
    programs: {}
};

// Check if WebGL is supported by the browser
function isWebGLSupported() {
    try {
        const canvas = document.createElement('canvas');
        return !!(window.WebGLRenderingContext && 
            (canvas.getContext('webgl') || canvas.getContext('experimental-webgl')));
    } catch(e) {
        return false;
    }
}

// Initialize WebGL context and resources
function initWebGL(canvas) {
    try {
        // Initialize WebGL context
        gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');
        if (!gl) {
            console.error('WebGL not supported');
            return false;
        }

        // Set up viewport
        gl.viewport(0, 0, canvas.width, canvas.height);
        gl.clearColor(0.0, 0.0, 0.0, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT);

        // Create shader program
        const vertexShader = createShader(gl, gl.VERTEX_SHADER, `
            attribute vec2 aPosition;
            attribute vec2 aTexCoord;
            varying vec2 vTexCoord;
            void main() {
                gl_Position = vec4(aPosition, 0.0, 1.0);
                vTexCoord = aTexCoord;
            }
        `);

        const fragmentShader = createShader(gl, gl.FRAGMENT_SHADER, `
            precision mediump float;
            varying vec2 vTexCoord;
            uniform sampler2D uTexture;
            void main() {
                gl_FragColor = texture2D(uTexture, vTexCoord);
            }
        `);

        shaderProgram = createProgram(gl, vertexShader, fragmentShader);
        gl.useProgram(shaderProgram);

        // Create vertex buffer for a fullscreen quad
        const positions = [
            -1.0, -1.0,
            1.0, -1.0,
            -1.0, 1.0,
            1.0, 1.0
        ];

        const texCoords = [
            0.0, 1.0,
            1.0, 1.0,
            0.0, 0.0,
            1.0, 0.0
        ];

        // Create and bind position buffer
        const positionBuffer = gl.createBuffer();
        gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
        gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(positions), gl.STATIC_DRAW);
        const positionLocation = gl.getAttribLocation(shaderProgram, 'aPosition');
        gl.enableVertexAttribArray(positionLocation);
        gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 0, 0);

        // Create and bind texture coordinate buffer
        const texCoordBuffer = gl.createBuffer();
        gl.bindBuffer(gl.ARRAY_BUFFER, texCoordBuffer);
        gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(texCoords), gl.STATIC_DRAW);
        const texCoordLocation = gl.getAttribLocation(shaderProgram, 'aTexCoord');
        gl.enableVertexAttribArray(texCoordLocation);
        gl.vertexAttribPointer(texCoordLocation, 2, gl.FLOAT, false, 0, 0);

        // Create texture
        texture = gl.createTexture();
        gl.bindTexture(gl.TEXTURE_2D, texture);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

        // Create a 1x1 black texture as a placeholder
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, 1, 1, 0, gl.RGB, gl.UNSIGNED_BYTE, new Uint8Array([0, 0, 0]));

        return true;
    } catch (e) {
        console.error('WebGL initialization error:', e);
        return false;
    }
}

// Helper function to create a shader
function createShader(gl, type, source) {
    const shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);

    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
        console.error('Shader compilation error:', gl.getShaderInfoLog(shader));
        gl.deleteShader(shader);
        return null;
    }

    return shader;
}

// Helper function to create a shader program
function createProgram(gl, vertexShader, fragmentShader) {
    const program = gl.createProgram();
    gl.attachShader(program, vertexShader);
    gl.attachShader(program, fragmentShader);
    gl.linkProgram(program);

    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
        console.error('Program linking error:', gl.getProgramInfoLog(program));
        return null;
    }

    return program;
}

// Render a frame with the given texture data
function renderFrame(textureData, width, height) {
    if (!gl || !texture) {
        console.error('WebGL not initialized');
        return false;
    }

    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGB, gl.UNSIGNED_BYTE, textureData);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);

    return true;
}

// Execute batched WebGL commands
function executeBatchedCommands(commandBuffer, width, height, zigMemory) {
    if (!gl) {
        console.error('WebGL not initialized');
        return false;
    }
    
    // Parse command buffer from WASM memory
    const buffer = new Uint8Array(zigMemory.buffer);
    const commands = new Uint32Array(zigMemory.buffer, commandBuffer, 1);
    const numCommands = commands[0];
    
    // Command format: [opcode, param1, param2, ...] 
    const commandData = new Uint32Array(zigMemory.buffer, commandBuffer + 4, numCommands * 4);
    
    // Execute commands in batch
    for (let i = 0; i < numCommands; i++) {
        const cmdIndex = i * 4;
        const opcode = commandData[cmdIndex];
        
        switch(opcode) {
            case 1: // Texture upload (UploadTexture)
                const dataPtr = commandData[cmdIndex + 1];
                const frameData = new Uint8Array(zigMemory.buffer, dataPtr, width * height * 3);
                
                gl.bindTexture(gl.TEXTURE_2D, texture);
                gl.texImage2D(
                    gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, 
                    gl.RGB, gl.UNSIGNED_BYTE, frameData
                );
                break;
                
            case 2: // Draw call (DrawArrays)
                gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
                break;
                
            case 3: // CreateBuffer
                // Create a new buffer and store it
                const newBuffer = gl.createBuffer();
                if (!newBuffer) {
                    console.error('Failed to create WebGL buffer');
                    break;
                }
                
                // Generate a buffer ID
                const bufferId = Object.keys(glResources.buffers).length + 1;
                glResources.buffers[bufferId] = newBuffer;
                
                // Store the buffer ID in the command data so Zig can read it
                // This is a hack to return the buffer ID to Zig
                // In a real implementation, we'd use a proper return value mechanism
                commandData[cmdIndex + 1] = bufferId;
                
                console.log('Created buffer with ID:', bufferId);
                break;
                
            case 4: // BindBuffer
                const bufferType = commandData[cmdIndex + 1];
                const bufferIdToBind = commandData[cmdIndex + 2];
                const bufferToBind = glResources.buffers[bufferIdToBind];
                
                if (bufferToBind) {
                    gl.bindBuffer(bufferType, bufferToBind);
                    console.log('Bound buffer ID:', bufferIdToBind, 'to target:', bufferType);
                } else {
                    console.error('Invalid buffer ID:', bufferIdToBind);
                }
                break;
                
            case 5: // BufferData
                const bufferTypeForData = commandData[cmdIndex + 1];
                const dataPointer = commandData[cmdIndex + 2];
                const dataSize = commandData[cmdIndex + 3];
                
                // Check if we have a buffer bound to the target
                const boundBuffer = gl.getParameter(bufferTypeForData === GL_CONSTANTS.GL_ARRAY_BUFFER ? 
                    gl.ARRAY_BUFFER_BINDING : gl.ELEMENT_ARRAY_BUFFER_BINDING);
                
                if (boundBuffer) {
                    const bufferData = new Uint8Array(zigMemory.buffer, dataPointer, dataSize);
                    gl.bufferData(bufferTypeForData, bufferData, gl.STATIC_DRAW);
                    console.log('Uploaded', dataSize, 'bytes to buffer type:', bufferTypeForData);
                } else {
                    console.error('No buffer bound to target:', bufferTypeForData);
                }
                break;
                
            case 6: // CreateShader
                // Not implemented in this simplified version
                break;
                
            case 7: // CreateProgram
                // Not implemented in this simplified version
                break;
                
            case 8: // UseProgram
                const programId = commandData[cmdIndex + 1];
                gl.useProgram(glResources.programs[programId] || shaderProgram);
                break;
                
            case 9: // VertexAttribPointer
                const attrIndex = commandData[cmdIndex + 1];
                const size = commandData[cmdIndex + 2];
                const packedParams = commandData[cmdIndex + 3];
                const dataType = packedParams & 0xFFFF;
                const normalized = ((packedParams >> 16) & 0x1) === 1;
                const stride = (packedParams >> 17) & 0x7FFF;
                const offset = (packedParams >> 24) & 0xFFFF;
                
                // Make sure we have a buffer bound before setting attributes
                if (gl.getParameter(gl.ARRAY_BUFFER_BINDING) === null) {
                    console.error('No ARRAY_BUFFER bound when calling vertexAttribPointer');
                    break;
                }
                
                gl.vertexAttribPointer(attrIndex, size, dataType, normalized, stride, offset);
                break;
                
            case 10: // EnableVertexAttribArray
                const attrIndexEnable = commandData[cmdIndex + 1];
                gl.enableVertexAttribArray(attrIndexEnable);
                break;
                
            case 11: // DrawElements
                const mode = commandData[cmdIndex + 1];
                const count = commandData[cmdIndex + 2];
                const packedDrawParams = commandData[cmdIndex + 3];
                const drawType = packedDrawParams & 0xFFFF;
                const drawOffset = (packedDrawParams >> 16) * 2; // Offset in bytes for index buffer
                
                gl.drawElements(mode, count, drawType, drawOffset);
                break;
                
            case 12: // UniformMatrix4fv
                const matLocationId = commandData[cmdIndex + 1];
                const matrixPtr = commandData[cmdIndex + 2];
                const matrixData = new Float32Array(zigMemory.buffer, matrixPtr, 16);
                
                // Check if location is valid (non-negative)
                if (matLocationId >= 0) {
                    // Get the actual WebGLUniformLocation from our map
                    const actualLocation = glResources.uniformLocations ? 
                        glResources.uniformLocations[matLocationId] : null;
                    
                    if (actualLocation !== undefined && actualLocation !== null) {
                        gl.uniformMatrix4fv(actualLocation, false, matrixData);
                    } else {
                        console.warn('Invalid uniform location ID:', matLocationId);
                    }
                } else {
                    console.warn('Invalid uniform location ID:', matLocationId);
                }
                break;
                
            case 13: // Uniform3f
                const vec3LocationId = commandData[cmdIndex + 1];
                const xScaled = commandData[cmdIndex + 2];
                const packedYZ = commandData[cmdIndex + 3];
                
                // Convert back from scaled integers to floats
                const x = xScaled / 1000.0;
                const y = ((packedYZ >> 16) & 0xFFFF) / 1000.0;
                const z = (packedYZ & 0xFFFF) / 1000.0;
                
                // Check if location is valid (non-negative)
                if (vec3LocationId >= 0) {
                    // Get the actual WebGLUniformLocation from our map
                    const actualLocation = glResources.uniformLocations ? 
                        glResources.uniformLocations[vec3LocationId] : null;
                    
                    if (actualLocation !== undefined && actualLocation !== null) {
                        gl.uniform3f(actualLocation, x, y, z);
                    } else {
                        console.warn('Invalid uniform location ID:', vec3LocationId);
                    }
                } else {
                    console.warn('Invalid uniform location ID:', vec3LocationId);
                }
                break;
                
            case 14: // Uniform4f
                const vec4LocationId = commandData[cmdIndex + 1];
                const xVal = commandData[cmdIndex + 2];
                const yVal = commandData[cmdIndex + 3];
                
                // Convert back from scaled integers to floats
                const x4 = xVal / 1000.0;
                const y4 = yVal / 1000.0;
                // Note: z and w values are not properly handled in this simplified version
                const z4 = 0.0;
                const w4 = 1.0;
                
                // Check if location is valid (non-negative)
                if (vec4LocationId >= 0) {
                    // Get the actual WebGLUniformLocation from our map
                    const actualLocation = glResources.uniformLocations ? 
                        glResources.uniformLocations[vec4LocationId] : null;
                    
                    if (actualLocation !== undefined && actualLocation !== null) {
                        gl.uniform4f(actualLocation, x4, y4, z4, w4);
                    } else {
                        console.warn('Invalid uniform location ID:', vec4LocationId);
                    }
                } else {
                    console.warn('Invalid uniform location ID:', vec4LocationId);
                }
                break;
                
            case 15: // EnableDepthTest
                gl.enable(gl.DEPTH_TEST);
                break;
                
            case 16: // Clear
                const clearBits = commandData[cmdIndex + 1];
                let clearMask = 0;
                
                if ((clearBits & 0x2) !== 0) {
                    clearMask |= gl.COLOR_BUFFER_BIT;
                }
                
                if ((clearBits & 0x1) !== 0) {
                    clearMask |= gl.DEPTH_BUFFER_BIT;
                }
                
                gl.clear(clearMask);
                break;
                
            default:
                console.error('Unknown WebGL command:', opcode);
                break;
        }
    }
    
    return true;
}

// Clear the canvas
function clearCanvas() {
    if (!gl) {
        console.error('WebGL not initialized');
        return;
    }

    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
}

// Helper to extract float values from WebGL commands
function extractFloat(value) {
    const buffer = new ArrayBuffer(4);
    const view = new DataView(buffer);
    view.setUint32(0, value, true);
    return view.getFloat32(0, true);
}

// Define WebGL constants for use in JavaScript
const GL_CONSTANTS = {
    // Buffer types
    GL_ARRAY_BUFFER: 0x8892,
    GL_ELEMENT_ARRAY_BUFFER: 0x8893,
    
    // Drawing modes
    GL_POINTS: 0x0000,
    GL_LINES: 0x0001,
    GL_TRIANGLES: 0x0004,
    GL_TRIANGLE_STRIP: 0x0005,
    
    // Data types
    GL_UNSIGNED_BYTE: 0x1401,
    GL_UNSIGNED_SHORT: 0x1403,
    GL_FLOAT: 0x1406,
    
    // Usage hints
    GL_STATIC_DRAW: 0x88E4,
    GL_DYNAMIC_DRAW: 0x88E8,
    
    // Clear bits
    GL_COLOR_BUFFER_BIT: 0x4000,
    GL_DEPTH_BUFFER_BIT: 0x0100
};

// Create a shader with the given source
function createShaderForWasm(shaderType, shaderSource) {
    if (!gl) {
        console.error('WebGL not initialized');
        return 0;
    }
    
    const shader = gl.createShader(shaderType);
    gl.shaderSource(shader, shaderSource);
    gl.compileShader(shader);
    
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
        console.error('Shader compile error:', gl.getShaderInfoLog(shader));
        gl.deleteShader(shader);
        return 0;
    }
    
    // Store in resources
    const shaderId = Object.keys(glResources.shaders).length + 1;
    glResources.shaders[shaderId] = shader;
    return shaderId;
}

// Create a program from two shaders
function createProgramForWasm(vertexShaderId, fragmentShaderId) {
    if (!gl) {
        console.error('WebGL not initialized');
        return 0;
    }
    
    const vertexShader = glResources.shaders[vertexShaderId];
    const fragmentShader = glResources.shaders[fragmentShaderId];
    
    if (!vertexShader || !fragmentShader) {
        console.error('Invalid shader IDs:', vertexShaderId, fragmentShaderId);
        return 0;
    }
    
    const program = gl.createProgram();
    gl.attachShader(program, vertexShader);
    gl.attachShader(program, fragmentShader);
    gl.linkProgram(program);
    
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
        console.error('Program link error:', gl.getProgramInfoLog(program));
        gl.deleteProgram(program);
        return 0;
    }
    
    // Store in resources
    const programId = Object.keys(glResources.programs).length + 1;
    glResources.programs[programId] = program;
    return programId;
}

// Delete a shader
function deleteShaderForWasm(shaderId) {
    if (!gl) {
        console.error('WebGL not initialized');
        return;
    }
    
    const shader = glResources.shaders[shaderId];
    if (shader) {
        gl.deleteShader(shader);
        delete glResources.shaders[shaderId];
    }
}

// Delete a program
function deleteProgramForWasm(programId) {
    if (!gl) {
        console.error('WebGL not initialized');
        return;
    }
    
    const program = glResources.programs[programId];
    if (program) {
        gl.deleteProgram(program);
        delete glResources.programs[programId];
    }
}

// Use a program
function useProgramForWasm(programId) {
    if (!gl) {
        console.error('WebGL not initialized');
        return;
    }
    
    const program = glResources.programs[programId] || null;
    gl.useProgram(program);
}

// Get uniform location
function getUniformLocationForWasm(programId, uniformName) {
    if (!gl) {
        console.error('WebGL not initialized');
        return -1;
    }
    
    const program = glResources.programs[programId];
    if (!program) {
        console.error('Invalid program ID:', programId);
        return -1;
    }
    
    const location = gl.getUniformLocation(program, uniformName);
    if (location === null) {
        console.warn(`Uniform ${uniformName} not found in program ${programId}`);
        return -1;
    }
    
    // Store the location in a map and return its index
    if (!glResources.uniformLocations) {
        glResources.uniformLocations = {};
        glResources.nextUniformLocationId = 1;
    }
    
    const locationId = glResources.nextUniformLocationId++;
    glResources.uniformLocations[locationId] = location;
    
    return locationId;
}

// Get attribute location
function getAttribLocationForWasm(programId, attribName) {
    if (!gl) {
        console.error('WebGL not initialized');
        return -1;
    }
    
    const program = glResources.programs[programId];
    if (!program) {
        console.error('Invalid program ID:', programId);
        return -1;
    }
    
    return gl.getAttribLocation(program, attribName);
}

// Set uniform matrix 4x4
function setUniformMatrix4fvForWasm(locationId, matrixData) {
    if (!gl) {
        console.error('WebGL not initialized');
        return;
    }
    
    // Get the actual WebGLUniformLocation from our map
    const actualLocation = glResources.uniformLocations ? 
        glResources.uniformLocations[locationId] : null;
    
    if (actualLocation !== undefined && actualLocation !== null) {
        gl.uniformMatrix4fv(actualLocation, false, matrixData);
    } else {
        console.warn('Invalid uniform location ID:', locationId);
    }
}

// Set uniform vec3
function setUniform3fForWasm(locationId, x, y, z) {
    if (!gl) {
        console.error('WebGL not initialized');
        return;
    }
    
    // Get the actual WebGLUniformLocation from our map
    const actualLocation = glResources.uniformLocations ? 
        glResources.uniformLocations[locationId] : null;
    
    if (actualLocation !== undefined && actualLocation !== null) {
        gl.uniform3f(actualLocation, x, y, z);
    } else {
        console.warn('Invalid uniform location ID:', locationId);
    }
}

// Set uniform vec4
function setUniform4fForWasm(locationId, x, y, z, w) {
    if (!gl) {
        console.error('WebGL not initialized');
        return;
    }
    
    // Get the actual WebGLUniformLocation from our map
    const actualLocation = glResources.uniformLocations ? 
        glResources.uniformLocations[locationId] : null;
    
    if (actualLocation !== undefined && actualLocation !== null) {
        gl.uniform4f(actualLocation, x, y, z, w);
    } else {
        console.warn('Invalid uniform location ID:', locationId);
    }
}

// Export the WebGL interface
window.WebGLInterface = {
    init: initWebGL,
    renderFrame: renderFrame,
    executeBatch: executeBatchedCommands,
    clearCanvas: clearCanvas,
    isSupported: isWebGLSupported,
    
    // Shader and program functions
    createShader: createShaderForWasm,
    createProgram: createProgramForWasm,
    deleteShader: deleteShaderForWasm,
    deleteProgram: deleteProgramForWasm,
    useProgram: useProgramForWasm,
    
    // Uniform and attribute functions
    getUniformLocation: getUniformLocationForWasm,
    getAttribLocation: getAttribLocationForWasm,
    setUniformMatrix4fv: setUniformMatrix4fvForWasm,
    setUniform3f: setUniform3fForWasm,
    setUniform4f: setUniform4fForWasm,
    
    // Export WebGL constants
    GL_ARRAY_BUFFER: GL_CONSTANTS.GL_ARRAY_BUFFER,
    GL_ELEMENT_ARRAY_BUFFER: GL_CONSTANTS.GL_ELEMENT_ARRAY_BUFFER,
    GL_POINTS: GL_CONSTANTS.GL_POINTS,
    GL_LINES: GL_CONSTANTS.GL_LINES,
    GL_TRIANGLES: GL_CONSTANTS.GL_TRIANGLES,
    GL_TRIANGLE_STRIP: GL_CONSTANTS.GL_TRIANGLE_STRIP,
    GL_UNSIGNED_BYTE: GL_CONSTANTS.GL_UNSIGNED_BYTE,
    GL_UNSIGNED_SHORT: GL_CONSTANTS.GL_UNSIGNED_SHORT,
    GL_FLOAT: GL_CONSTANTS.GL_FLOAT,
    GL_STATIC_DRAW: GL_CONSTANTS.GL_STATIC_DRAW,
    GL_DYNAMIC_DRAW: GL_CONSTANTS.GL_DYNAMIC_DRAW,
    GL_COLOR_BUFFER_BIT: GL_CONSTANTS.GL_COLOR_BUFFER_BIT,
    GL_DEPTH_BUFFER_BIT: GL_CONSTANTS.GL_DEPTH_BUFFER_BIT,
    
    // Add shader-specific constants
    GL_VERTEX_SHADER: 0x8B31,
    GL_FRAGMENT_SHADER: 0x8B30
};