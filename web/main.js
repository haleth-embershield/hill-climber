// DOM elements
const gameCanvas = document.getElementById('game-canvas');
const statusMessage = document.getElementById('status-message');
const logContainer = document.getElementById('log-container');
const startButton = document.getElementById('start-button');
const pauseButton = document.getElementById('pause-button');
const primaryActionButton = document.getElementById('primary-action-button');
const scoreElement = document.getElementById('score');
const highScoreElement = document.getElementById('high-score');
const gameStateMessage = document.getElementById('game-state-message');
const webglErrorElement = document.getElementById('webgl-error');
const volumeSlider = document.getElementById('volume-slider');
const volumeValue = document.getElementById('volume-value');
const fpsCounter = document.getElementById('fps-counter');

// Game state
let score = 0;
let highScore = 0;
let masterVolume = 0.7; // Default volume (70%)

// FPS tracking
let frameCount = 0;
let lastFpsUpdate = 0;
let currentFps = 0;

// Update volume display and set master volume
volumeSlider.addEventListener('input', function() {
    const volume = this.value;
    volumeValue.textContent = volume + '%';
    masterVolume = volume / 100;
    
    // Update audio context gain if available
    if (gainNode) {
        gainNode.gain.value = masterVolume;
    }
});

// Audio system with volume control
const audioContext = new (window.AudioContext || window.webkitAudioContext)();
const audioBuffers = {};
let gainNode = null;

// Create gain node for volume control
try {
    gainNode = audioContext.createGain();
    gainNode.gain.value = masterVolume;
    gainNode.connect(audioContext.destination);
} catch (e) {
    console.error('Error creating gain node:', e);
}

// Sound names mapping
const soundNames = ['sound1', 'sound2', 'sound3'];

// Function to play sound from buffer with volume control
function playSound(soundName) {
    if (audioBuffers[soundName]) {
        const source = audioContext.createBufferSource();
        source.buffer = audioBuffers[soundName];
        
        // Connect through gain node for volume control if available
        if (gainNode) {
            source.connect(gainNode);
        } else {
            source.connect(audioContext.destination);
        }
        
        source.start(0);
    }
}

// Function to decode audio data from WASM
async function decodeAudioData(data) {
    try {
        return await audioContext.decodeAudioData(data);
    } catch (error) {
        console.error('Error decoding audio data:', error);
        return null;
    }
}

// WASM module reference
let wasmModule = null;
// Make wasmModule globally accessible for the callback system
window.wasmModule = null;

// Animation state
let animationFrameId = null;
let lastTimestamp = 0;
let isPaused = false;

// Check WebGL support and initialize if available
function checkWebGLSupport() {
    if (!window.WebGLInterface || !window.WebGLInterface.isSupported()) {
        // WebGL is not supported
        webglErrorElement.style.display = 'block';
        gameCanvas.style.display = 'none';
        startButton.disabled = true;
        pauseButton.disabled = true;
        primaryActionButton.disabled = true;
        statusMessage.textContent = "Error: WebGL is not supported by your browser";
        addLogEntry("WebGL is not supported by your browser");
        return false;
    }
    return true;
}

// Initialize WebGL
function initializeWebGL() {
    // Get the canvas element
    const canvas = document.getElementById('game-canvas');
    
    // Initialize WebGL
    if (!window.WebGLInterface.init(canvas)) {
        console.error('Failed to initialize WebGL');
        addLogEntry("WebGL initialization failed");
        statusMessage.textContent = "Error: WebGL initialization failed";
        webglErrorElement.style.display = 'block';
        gameCanvas.style.display = 'none';
        startButton.disabled = true;
        pauseButton.disabled = true;
        primaryActionButton.disabled = true;
        return false;
    }
    
    addLogEntry("WebGL initialized successfully");
    return true;
}

// Define imports globally so it can be accessed from all functions
const imports = {
    env: {
        consoleLog: (ptr, len) => {
            const buffer = new Uint8Array(wasmModule.memory.buffer);
            const message = new TextDecoder().decode(buffer.subarray(ptr, ptr + len));
            console.log(message);
            addLogEntry(message);
            
            // Update score display if the message contains score information
            if (message.startsWith('Score:')) {
                const scoreMatch = message.match(/Score: (\d+)/);
                if (scoreMatch && scoreMatch[1]) {
                    score = parseInt(scoreMatch[1]);
                    scoreElement.textContent = score;
                }
            }
            
            // Update game over message
            if (message === 'Game Over!') {
                gameStateMessage.classList.add('visible');
                if (score > highScore) {
                    highScore = score;
                    highScoreElement.textContent = highScore;
                }
                
                // For game over, we want to stop the animation loop completely
                // after rendering the final frame
                if (animationFrameId) {
                    cancelAnimationFrame(animationFrameId);
                    animationFrameId = null;
                    
                    // Render one final frame to ensure the game over state is displayed correctly
                    if (wasmModule && typeof wasmModule.update === 'function') {
                        wasmModule.update(0);
                    }
                }
            }
        },
        // New unified audio function that receives audio data from WASM
        playAudioFromWasm: async (dataPtr, dataLen, soundId) => {
            try {
                // Get the audio data from WASM memory
                const buffer = new Uint8Array(wasmModule.memory.buffer);
                const audioData = buffer.slice(dataPtr, dataPtr + dataLen);
                
                // Convert to ArrayBuffer for Web Audio API
                const arrayBuffer = audioData.buffer.slice(
                    audioData.byteOffset, 
                    audioData.byteOffset + audioData.byteLength
                );
                
                // Get the sound name based on ID
                const soundName = soundNames[soundId] || 'unknown';
                
                // Check if we've already decoded this audio
                if (!audioBuffers[soundName]) {
                    // Decode the audio data
                    const audioBuffer = await decodeAudioData(arrayBuffer);
                    if (audioBuffer) {
                        audioBuffers[soundName] = audioBuffer;
                        console.log(`Decoded audio: ${soundName}`);
                    }
                }
                
                // Play the sound
                playSound(soundName);
            } catch (error) {
                console.error('Error playing audio from WASM:', error);
            }
        },
        executeBatchedCommands: (cmdPtr, width, height) => {
            window.WebGLInterface.executeBatch(cmdPtr, width, height, wasmModule.memory);
        },
        
        // Add registerCallback function for the callback system
        registerCallback: (typePtr, callback) => {
            const buffer = new Uint8Array(wasmModule.memory.buffer);
            // Find the null terminator in the string
            let len = 0;
            while (buffer[typePtr + len] !== 0) len++;
            const type = new TextDecoder().decode(buffer.subarray(typePtr, typePtr + len));
            return window.WebGLInterface.registerCallback(type, callback);
        },
        
        // WebGL shader functions from shaders.zig
        createShader: (shader_type, source_ptr, source_len) => {
            const buffer = new Uint8Array(wasmModule.memory.buffer);
            const source = new TextDecoder().decode(buffer.subarray(source_ptr, source_ptr + source_len));
            return window.WebGLInterface.createShader(shader_type, source);
        },
        createProgram: (vertex_shader_id, fragment_shader_id) => {
            return window.WebGLInterface.createProgram(vertex_shader_id, fragment_shader_id);
        },
        deleteShader: (shader_id) => {
            window.WebGLInterface.deleteShader(shader_id);
        },
        deleteProgram: (program_id) => {
            window.WebGLInterface.deleteProgram(program_id);
        },
        useProgram: (program_id) => {
            window.WebGLInterface.useProgram(program_id);
        },
        getUniformLocation: (program_id, name_ptr, name_len) => {
            const buffer = new Uint8Array(wasmModule.memory.buffer);
            const name = new TextDecoder().decode(buffer.subarray(name_ptr, name_ptr + name_len));
            return window.WebGLInterface.getUniformLocation(program_id, name);
        },
        setUniformMatrix4fv: (location, value_ptr) => {
            const matrixData = new Float32Array(wasmModule.memory.buffer, value_ptr, 16);
            window.WebGLInterface.setUniformMatrix4fv(location, matrixData);
        },
        setUniform3f: (location, x, y, z) => {
            window.WebGLInterface.setUniform3f(location, x, y, z);
        },
        setUniform4f: (location, x, y, z, w) => {
            window.WebGLInterface.setUniform4f(location, x, y, z, w);
        }
    }
};

// Animation loop function
function animate(timestamp) {
    // If we're in game over state, don't continue the animation loop
    if (gameStateMessage.classList.contains('visible')) {
        animationFrameId = null;
        return;
    }
    
    // FPS calculation
    frameCount++;
    if (timestamp - lastFpsUpdate >= 1000) { // Update every second
        currentFps = Math.round((frameCount * 1000) / (timestamp - lastFpsUpdate));
        fpsCounter.textContent = currentFps;
        frameCount = 0;
        lastFpsUpdate = timestamp;
    }
    
    // If paused, don't update game logic but still render the current frame
    if (isPaused) {
        // Call update with 0 delta time to just render the current state
        if (wasmModule && typeof wasmModule.update === 'function') {
            wasmModule.update(0);
        }
        
        // Request next frame only if we're paused but not in game over
        if (!gameStateMessage.classList.contains('visible')) {
            animationFrameId = requestAnimationFrame(animate);
        } else {
            animationFrameId = null;
        }
        return;
    }
    
    // Calculate delta time in seconds
    if (!lastTimestamp) lastTimestamp = timestamp;
    const deltaTime = Math.min((timestamp - lastTimestamp) / 1000, 0.1); // Cap delta time to avoid large jumps
    lastTimestamp = timestamp;
    
    // Call WASM update function
    wasmModule.update(deltaTime);
    
    // Request next frame
    animationFrameId = requestAnimationFrame(animate);
}

// Start animation loop
function startAnimationLoop() {
    // Start the animation loop
    animationFrameId = requestAnimationFrame(animate);
}

// Add log entry to the log container
function addLogEntry(message) {
    const entry = document.createElement('div');
    entry.className = 'log-entry';
    entry.textContent = message;
    logContainer.appendChild(entry);
    
    // Auto-scroll to bottom
    logContainer.scrollTop = logContainer.scrollHeight;
    
    // Limit number of entries
    while (logContainer.children.length > 100) {
        logContainer.removeChild(logContainer.firstChild);
    }
}

// Handle primary action
function handlePrimaryAction() {
    if (!wasmModule) return;
    
    // Call WASM function to handle action
    // First try the new function name, fall back to the old one for backward compatibility
    if (typeof wasmModule.handlePrimaryAction === 'function') {
        wasmModule.handlePrimaryAction();
        
        // Hide game over message when starting a new game
        gameStateMessage.classList.remove('visible');
    } else if (typeof wasmModule.handleJump === 'function') { 
        // Backward compatibility with existing code
        wasmModule.handleJump();
        
        // Hide game over message when starting a new game
        gameStateMessage.classList.remove('visible');
    }
}

// Handle canvas click
function handleCanvasClick(event) {
    if (!wasmModule || isPaused) return;
    
    // Call WASM function to handle click
    if (typeof wasmModule.handleClick === 'function') {
        const rect = gameCanvas.getBoundingClientRect();
        const x = event.clientX - rect.left;
        const y = event.clientY - rect.top;
        wasmModule.handleClick(x, y);
        
        // Hide game over message when starting a new game
        gameStateMessage.classList.remove('visible');
    }
}

// Start the game
function startGame() {
    if (!wasmModule) return;
    
    // Reset game state if needed
    if (typeof wasmModule.resetGame === 'function') {
        wasmModule.resetGame();
        
        // Reset score display
        score = 0;
        scoreElement.textContent = '0';
        
        // Hide game over message
        gameStateMessage.classList.remove('visible');
    }
    
    isPaused = false;
    lastTimestamp = 0; // Reset timestamp to avoid large delta on first frame
    statusMessage.textContent = "Game started";
    
    // Start animation loop if not already running
    if (!animationFrameId) {
        startAnimationLoop();
    }
}

// Toggle pause state
function togglePause() {
    if (!wasmModule) return;
    
    isPaused = !isPaused;
    statusMessage.textContent = isPaused ? "Game paused" : "Game resumed";
    
    // Call WASM function to toggle pause
    if (typeof wasmModule.togglePause === 'function') {
        wasmModule.togglePause();
    }
    
    if (!isPaused && !animationFrameId) {
        startAnimationLoop();
    }
}

// Initialize WebAssembly module
async function initWasm() {
    try {
        statusMessage.textContent = "Loading WASM module...";
        
        // Initialize WebGL
        if (!initializeWebGL()) {
            return; // Stop initialization if WebGL initialization fails
        }
        
        // Add resize handler for responsive canvas
        function handleResize() {
            const container = document.querySelector('.container');
            const containerWidth = container.clientWidth - 40; // Account for padding
            const aspectRatio = 4/3; // Maintain 4:3 aspect ratio
            
            // Calculate new dimensions while maintaining aspect ratio
            let newWidth = Math.min(containerWidth, 800); // Max width of 800px
            let newHeight = newWidth / aspectRatio;
            
            // Update canvas size
            gameCanvas.style.width = `${newWidth}px`;
            gameCanvas.style.height = `${newHeight}px`;
            
            // Keep the internal resolution the same
            gameCanvas.width = 800;
            gameCanvas.height = 600;
        }
        
        // Call resize handler initially and add event listener
        handleResize();
        window.addEventListener('resize', handleResize);
        
        // Load the WASM file
        const wasmUrl = 'game.wasm';
        
        const response = await fetch(wasmUrl);
        if (!response.ok) {
            throw new Error(`Failed to fetch WASM: ${response.statusText}`);
        }
        
        const wasmBytes = await response.arrayBuffer();
        
        // Instantiate the WebAssembly module
        const { instance } = await WebAssembly.instantiate(wasmBytes, imports);
        wasmModule = instance.exports;
        // Make wasmModule globally accessible for the callback system
        window.wasmModule = wasmModule;
        
        // Initialize the WASM module
        wasmModule.init();
        
        // Update status
        statusMessage.textContent = "WASM module loaded successfully";
        
        // Add click event listener to canvas
        gameCanvas.addEventListener('click', handleCanvasClick);
        
        // Add button event listeners
        startButton.addEventListener('click', startGame);
        pauseButton.addEventListener('click', togglePause);
        primaryActionButton.addEventListener('click', handlePrimaryAction);

        // Mouse event listeners
        gameCanvas.addEventListener('mousemove', (event) => {
            if (!wasmModule) return;
            
            const rect = gameCanvas.getBoundingClientRect();
            const x = event.clientX - rect.left;
            const y = event.clientY - rect.top;
            wasmModule.handlePointerMove(x, y);
        });

        gameCanvas.addEventListener('mousedown', (event) => {
            if (!wasmModule) return;
            event.preventDefault();
            
            const rect = gameCanvas.getBoundingClientRect();
            const x = event.clientX - rect.left;
            const y = event.clientY - rect.top;
            
            // Map mouse button to our custom codes
            let buttonCode = null;
            switch(event.button) {
                case 0: // Left
                    buttonCode = 200; // MouseLeft
                    break;
                case 1: // Middle
                    buttonCode = 201; // MouseMiddle
                    break;
                case 2: // Right
                    buttonCode = 202; // MouseRight
                    break;
                case 3: // Back
                    buttonCode = 203; // MouseBack
                    break;
                case 4: // Forward
                    buttonCode = 204; // MouseForward
                    break;
            }
            
            if (buttonCode !== null) {
                wasmModule.handlePointerAction(buttonCode, true, x, y);
            }
        });

        gameCanvas.addEventListener('mouseup', (event) => {
            if (!wasmModule) return;
            event.preventDefault();
            
            const rect = gameCanvas.getBoundingClientRect();
            const x = event.clientX - rect.left;
            const y = event.clientY - rect.top;
            
            // Map mouse button to our custom codes
            let buttonCode = null;
            switch(event.button) {
                case 0: // Left
                    buttonCode = 200; // MouseLeft
                    break;
                case 1: // Middle
                    buttonCode = 201; // MouseMiddle
                    break;
                case 2: // Right
                    buttonCode = 202; // MouseRight
                    break;
                case 3: // Back
                    buttonCode = 203; // MouseBack
                    break;
                case 4: // Forward
                    buttonCode = 204; // MouseForward
                    break;
            }
            
            if (buttonCode !== null) {
                wasmModule.handlePointerAction(buttonCode, false, x, y);
            }
        });

        // Prevent context menu on right click
        gameCanvas.addEventListener('contextmenu', (event) => {
            event.preventDefault();
        });

        // Mouse wheel support
        gameCanvas.addEventListener('wheel', (event) => {
            if (!wasmModule) return;
            event.preventDefault();
            
            // Normalize scroll values
            const scrollX = event.deltaX / 100;
            const scrollY = event.deltaY / 100;
            wasmModule.handleScroll(scrollX, scrollY);
        });

        // Touch event support
        gameCanvas.addEventListener('touchstart', (event) => {
            if (!wasmModule) return;
            event.preventDefault();
            
            const rect = gameCanvas.getBoundingClientRect();
            const touch = event.touches[0];
            const x = touch.clientX - rect.left;
            const y = touch.clientY - rect.top;
            
            // Use 210 for primary touch (matches our TouchPrimary code)
            wasmModule.handlePointerAction(210, true, x, y);
            wasmModule.handlePointerMove(x, y);
        });

        gameCanvas.addEventListener('touchmove', (event) => {
            if (!wasmModule) return;
            event.preventDefault();
            
            const rect = gameCanvas.getBoundingClientRect();
            const touch = event.touches[0];
            const x = touch.clientX - rect.left;
            const y = touch.clientY - rect.top;
            
            wasmModule.handlePointerMove(x, y);
        });

        gameCanvas.addEventListener('touchend', (event) => {
            if (!wasmModule) return;
            event.preventDefault();
            
            const rect = gameCanvas.getBoundingClientRect();
            // Use last known position since touches array will be empty
            const x = event.changedTouches[0].clientX - rect.left;
            const y = event.changedTouches[0].clientY - rect.top;
            
            // Use 210 for primary touch (matches our TouchPrimary code)
            wasmModule.handlePointerAction(210, false, x, y);
        });

        // Add keyboard event listener
        window.addEventListener('keydown', (event) => {
            if (!wasmModule) return;
            
            // Map key to keycode
            let keyCode = null;
            switch(event.key) {
                case 'ArrowRight':
                    keyCode = 39; // ArrowRight
                    break;
                case 'ArrowLeft':
                    keyCode = 37; // ArrowLeft
                    break;
                case 'ArrowUp':
                    keyCode = 38; // ArrowUp
                    break;
                case 'ArrowDown':
                    keyCode = 40; // ArrowDown
                    break;
                case 'd':
                case 'D':
                    keyCode = 68; // KeyD
                    break;
                case 'a':
                case 'A':
                    keyCode = 65; // KeyA
                    break;
                case 'w':
                case 'W':
                    keyCode = 87; // KeyW
                    break;
                case 's':
                case 'S':
                    keyCode = 83; // KeyS
                    break;
                case 'r':
                case 'R':
                    keyCode = 82; // KeyR
                    break;
                case 'p':
                case 'P':
                    keyCode = 80; // KeyP
                    break;
                case 'm':
                case 'M':
                    keyCode = 77; // KeyM
                    break;
                case ' ':
                    keyCode = 32; // Space
                    break;
            }
            
            if (keyCode !== null) {
                event.preventDefault();
                wasmModule.handleInput(keyCode, true);
            }
        });
        
        // Add keyboard event listener for key up events
        window.addEventListener('keyup', (event) => {
            if (!wasmModule) return;
            
            // Map key to keycode
            let keyCode = null;
            switch(event.key) {
                case 'ArrowRight':
                    keyCode = 39; // ArrowRight
                    break;
                case 'ArrowLeft':
                    keyCode = 37; // ArrowLeft
                    break;
                case 'ArrowUp':
                    keyCode = 38; // ArrowUp
                    break;
                case 'ArrowDown':
                    keyCode = 40; // ArrowDown
                    break;
                case 'd':
                case 'D':
                    keyCode = 68; // KeyD
                    break;
                case 'a':
                case 'A':
                    keyCode = 65; // KeyA
                    break;
                case 'w':
                case 'W':
                    keyCode = 87; // KeyW
                    break;
                case 's':
                case 'S':
                    keyCode = 83; // KeyS
                    break;
                case 'r':
                case 'R':
                    keyCode = 82; // KeyR
                    break;
                case 'p':
                case 'P':
                    keyCode = 80; // KeyP
                    break;
                case 'm':
                case 'M':
                    keyCode = 77; // KeyM
                    break;
                case ' ':
                    keyCode = 32; // Space
                    break;
            }
            
            if (keyCode !== null) {
                event.preventDefault();
                wasmModule.handleInput(keyCode, false);
            }
        });
        
        // Start the game loop
        startAnimationLoop();
        
    } catch (error) {
        statusMessage.textContent = `Error: ${error.message}`;
        console.error("Initialization error:", error);
        
        // Add retry button
        const retryButton = document.createElement('button');
        retryButton.textContent = 'Retry Loading';
        retryButton.onclick = () => {
            statusMessage.textContent = '';
            retryButton.remove();
            initWasm();
        };
        statusMessage.appendChild(retryButton);
    }
}

// Initialize the application
window.addEventListener('load', () => {
    // Check WebGL support first
    if (!checkWebGLSupport()) {
        statusMessage.textContent = "Error: WebGL is not supported by your browser";
        return; // Stop initialization if WebGL is not supported
    }
    
    // Continue with WASM initialization
    initWasm();
});

// Add log toggle functionality
const logToggle = document.getElementById('log-toggle');

logToggle.addEventListener('click', () => {
    logContainer.classList.toggle('hidden');
    logToggle.classList.toggle('collapsed');
});

// Clean up resources when the page is unloaded
window.addEventListener('beforeunload', () => {
    if (wasmModule && typeof wasmModule.deinit === 'function') {
        wasmModule.deinit();
    }
});