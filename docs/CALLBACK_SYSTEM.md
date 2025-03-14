# WebGL Callback System Implementation

## Overview

This document explains the implementation of a callback system to replace the previous hack used for returning WebGL resource IDs from JavaScript to Zig. The callback system provides a clean, maintainable, and extensible way to handle asynchronous communication between JavaScript and Zig in our WebAssembly-based game engine.

## Previous Implementation (The Hack)

In the previous implementation, when creating WebGL resources like buffers, we used a hack to return the resource ID back to Zig:

```javascript
// Store the buffer ID in the command data so Zig can read it
// This is a hack to return the buffer ID to Zig
commandData[cmdIndex + 1] = bufferId;
```

This approach had several issues:
1. It repurposed the command buffer's memory for bidirectional communication
2. It was fragile and could lead to data corruption if not handled carefully
3. It lacked proper error handling
4. It wasn't thread-safe
5. It violated the unidirectional command pattern

## New Callback System

The new implementation uses a proper callback system where Zig registers callback functions that JavaScript can invoke when events occur or when data needs to be returned.

### JavaScript Implementation

1. **Callback Registry**: A central registry to store and manage callbacks.
   ```javascript
   const callbackRegistry = {
       callbacks: {},
       register: function(type, callback) { ... },
       invoke: function(type, ...args) { ... }
   };
   ```

2. **Callback Types**: Predefined types for different callback scenarios.
   ```javascript
   const CallbackType = {
       BUFFER_CREATED: 'buffer_created',
       SHADER_CREATED: 'shader_created',
       PROGRAM_CREATED: 'program_created',
       ERROR: 'error'
   };
   ```

3. **Registration Function**: Allows Zig to register callbacks.
   ```javascript
   function registerCallbackForWasm(callbackType, callbackFn) {
       callbackRegistry.register(callbackType, callbackFn);
       return true;
   }
   ```

4. **Invocation**: JavaScript code invokes callbacks when events occur.
   ```javascript
   // Example: When a buffer is created
   callbackRegistry.invoke(CallbackType.BUFFER_CREATED, bufferId);
   
   // Example: When an error occurs
   callbackRegistry.invoke(CallbackType.ERROR, errorMessage);
   ```

### Zig Implementation

1. **Callback Function Types**: Define the types of callbacks.
   ```zig
   pub const BufferCreatedCallback = fn (bufferId: u32) callconv(.C) void;
   pub const ErrorCallback = fn (errorPtr: [*]const u8, errorLen: usize) callconv(.C) void;
   ```

2. **External JavaScript Functions**: Declare the JavaScript functions.
   ```zig
   extern fn registerCallback(callbackType: [*]const u8, callbackFn: ?*const anyopaque) bool;
   ```

3. **Callback Implementations**: Implement the callback functions.
   ```zig
   export fn handleBufferCreated(bufferId: u32) void {
       // Store or process the buffer ID
       lastBufferId = bufferId;
   }
   
   export fn handleError(errorPtr: [*]const u8, errorLen: usize) void {
       // Process the error message
       const errorMsg = errorPtr[0..errorLen];
       // Handle error...
   }
   ```

4. **Callback Registration**: Register the callbacks with JavaScript.
   ```zig
   pub fn initCallbacks() bool {
       _ = registerCallback(BUFFER_CREATED_CALLBACK.ptr, @ptrCast(&handleBufferCreated));
       _ = registerCallback(ERROR_CALLBACK.ptr, @ptrCast(&handleError));
       return true;
   }
   ```

## How to Use the Callback System

### Step 1: Initialize Callbacks

At the start of your application, initialize the callback system:

```zig
// In your initialization code
_ = initCallbacks();
```

### Step 2: Create Resources Using Command Buffer

When creating resources, use the command buffer as usual:

```zig
// Create a buffer
commandBuffer.addCreateBufferCommand();

// Execute the command buffer
executeBatchedCommands(commandBuffer.getBufferPtr(), width, height);

// The buffer ID will be available in lastBufferId after the callback is invoked
const bufferId = lastBufferId;
```

### Step 3: Handle Errors

The error callback will be invoked if any errors occur:

```zig
// Check if an error occurred
if (lastError.len > 0) {
    std.debug.print("Error: {s}\n", .{lastError});
    // Handle the error...
    lastError = "";  // Reset the error
}
```

## Benefits of the New System

1. **Clean Separation**: Clear separation between command sending and result handling
2. **Extensibility**: Easy to add new callback types for different events
3. **Error Handling**: Proper error propagation from JavaScript to Zig
4. **Thread Safety**: Better support for potential future multi-threading
5. **Maintainability**: More professional and maintainable code structure
6. **Reusability**: The callback system can be reused in other projects

## Future Enhancements

1. **Async/Promise Integration**: Better integration with JavaScript's async patterns
2. **Structured Error Handling**: More detailed error information and handling
3. **Resource Lifecycle Management**: Callbacks for resource destruction and cleanup
4. **Performance Optimization**: Batch callback processing for high-frequency events

## Example Code

See `docs/callback_example.zig` for a complete example of how to use the callback system. 