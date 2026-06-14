# Zig + zgui GUI Application Architecture Template

This repository implements a clean, production-ready project architecture for building GUI applications in Zig (0.16.0) using `zgui` (Dear ImGui bindings).

## 📁 Project Structure

```text
dhace/
├── build.zig          # Build script linking GLFW, OpenGL and zgui dependencies
├── build.zig.zon      # Package manager dependencies
├── .cursorrules       # Guidelines for AI development in this project
├── src/
│   ├── main.zig       # Entry point: initializes allocators, windowing, and the render loop
│   ├── app.zig        # Global application state (the "Model")
│   ├── core/          # Decoupled business logic (No GUI dependencies)
│   │   ├── database.zig # Simulated data store connection
│   │   └── math.zig   # Pure math functions and unit tests
│   ├── view/          # UI rendering logic (Views query the Model and call mutators)
│   │   ├── main_window.zig
│   │   ├── settings_panel.zig
│   │   └── components.zig # Custom, reusable UI elements
│   └── platform/      # Conditional compilation for OS-specific APIs
│       ├── win32.zig
│       └── linux.zig
├── skills/            # Automated helper scripts for developer agents
│   ├── format.ps1
│   ├── build.ps1
│   └── test.ps1
└── assets/            # Fonts, images, icons
```

---

## 🛠️ Prerequisites

This project is 100% self-contained and builds its C dependencies (GLFW and OpenGL loaders) from source via Zig's package manager (`zglfw` and `zopengl`).
Before building this project, you only need the following installed:
1. **Zig Compiler (0.16.0)**: Ensure you are using the nightly build.

---

## 🚀 Commands

### 1. Build and Run
Compiles and launches the graphical interface:
```bash
zig build run
```

### 2. Format Source Code
Cleans up whitespace and formatting across files:
```bash
zig fmt .
```
*(Or use `skills/format.ps1` in PowerShell)*

### 3. Run Unit Tests
Executes unit tests in `src/core/math.zig` and other test blocks:
```bash
zig build test
```
*(Or use `skills/test.ps1` in PowerShell)*

---

## 🧠 Architectural Design Principles

1. **Keep it Simple (KISS)**: Memory allocations are kept explicit. View code is transient and stateless, meaning we don't store widget handles or states; everything is driven by the state of the model (`App` struct).
2. **Decoupling**: The contents of `src/core/` are pure Zig and completely independent of GLFW/zgui. They can be tested in isolation.
3. **Platform Independence**: OS-specific tasks are isolated to `src/platform/` and conditionally imported dynamically during compile time.
