#!/bin/bash

# ============================================================================
# GTA SA AO - Complete Automated Setup
# For repo: ssao-niat
# ============================================================================

set -e

echo ""
echo "╔════════════════════════════════════════╗"
echo "║   GTA SA Android - SSAO Niat          ║"
echo "║   Complete Project Setup              ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# Check if running in repo
# ============================================================================

if [ -f "jni/main.cpp" ]; then
    echo -e "${YELLOW}Project files already exist!${NC}"
    echo "This will overwrite existing files."
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# ============================================================================
# Download AML Dependencies
# ============================================================================

echo -e "${BLUE}[1/4] Downloading AML dependencies...${NC}"

TEMP_DIR="AML_Temp"
rm -rf $TEMP_DIR

git clone --depth 1 https://github.com/RusJJ/AndroidModLoader $TEMP_DIR

if [ ! -d "$TEMP_DIR" ]; then
    echo -e "${RED}ERROR: Failed to clone AML!${NC}"
    exit 1
fi

# Copy dependencies
echo "  → Copying AML_PrecompiledLibs..."
mkdir -p AML_PrecompiledLibs
cp -r $TEMP_DIR/AML_PrecompiledLibs/* AML_PrecompiledLibs/ 2>/dev/null || true

echo "  → Copying include files..."
mkdir -p include
cp -r $TEMP_DIR/include/* include/ 2>/dev/null || true

echo "  → Copying ARMPatch..."
if [ -d "$TEMP_DIR/ARMPatch" ]; then
    cp -r $TEMP_DIR/ARMPatch .
fi

rm -rf $TEMP_DIR

echo -e "${GREEN}  ✓ Dependencies downloaded${NC}"
echo ""

# ============================================================================
# Create Project Structure
# ============================================================================

echo -e "${BLUE}[2/4] Creating project structure...${NC}"

mkdir -p jni
mkdir -p libs/armeabi-v7a
mkdir -p obj/local/armeabi-v7a
mkdir -p .github/workflows

echo -e "${GREEN}  ✓ Directories created${NC}"
echo ""

# ============================================================================
# Generate Project Files
# ============================================================================

echo -e "${BLUE}[3/4] Generating project files...${NC}"

# ============================================================================
# jni/main.cpp
# ============================================================================

echo "  → Creating jni/main.cpp..."

cat > jni/main.cpp << 'EOF'
// ============================================================================
// GTA:SA Android - Ambient Occlusion (SSAO Niat)
// Phase 1: Foundation & Hooking
// ============================================================================

#include <mod/amlmod.h>
#include <mod/logger.h>
#include <mod/config.h>
#include <GLES3/gl3.h>
#include <GLES3/gl3ext.h>

MYMOD(net.gtasa.ssao, GTA:SA SSAO Niat, 1.0.0, YourName)

// ============================================================================
// Config
// ============================================================================

ConfigEntry* g_pCfgEnabled;
ConfigEntry* g_pCfgIntensity;
ConfigEntry* g_pCfgRadius;

// ============================================================================
// Function Pointers
// ============================================================================

typedef void (*RenderScene_t)(bool);
RenderScene_t g_pOriginalRenderScene = nullptr;

typedef void* (*GetCurrentViewMatrix_t)();
typedef void* (*GetCurrentProjectionMatrix_t)();
GetCurrentViewMatrix_t g_pGetViewMatrix = nullptr;
GetCurrentProjectionMatrix_t g_pGetProjectionMatrix = nullptr;

// ============================================================================
// State
// ============================================================================

bool g_bAOInitialized = false;
bool g_bFirstFrame = true;
int g_nFrameCount = 0;
int g_nScreenWidth = 0;
int g_nScreenHeight = 0;

// ============================================================================
// OpenGL Utilities
// ============================================================================

void CheckGLError(const char* op) {
    GLenum error;
    while((error = glGetError()) != GL_NO_ERROR) {
        logger->Error("GL error after %s: 0x%x", op, error);
    }
}

void PrintGLInfo() {
    logger->Info("OpenGL Vendor: %s", glGetString(GL_VENDOR));
    logger->Info("OpenGL Renderer: %s", glGetString(GL_RENDERER));
    logger->Info("OpenGL Version: %s", glGetString(GL_VERSION));
    logger->Info("GLSL Version: %s", glGetString(GL_SHADING_LANGUAGE_VERSION));
    
    GLint maxDrawBuffers, maxColorAttachments;
    glGetIntegerv(GL_MAX_DRAW_BUFFERS, &maxDrawBuffers);
    glGetIntegerv(GL_MAX_COLOR_ATTACHMENTS, &maxColorAttachments);
    
    logger->Info("Max Draw Buffers: %d", maxDrawBuffers);
    logger->Info("Max Color Attachments: %d", maxColorAttachments);
    
    if(maxDrawBuffers < 3) {
        logger->Error("Device does not support 3 render targets!");
    } else {
        logger->Info("MRT (3 targets) supported!");
    }
}

void GetScreenResolution() {
    GLint viewport[4];
    glGetIntegerv(GL_VIEWPORT, viewport);
    g_nScreenWidth = viewport[2];
    g_nScreenHeight = viewport[3];
    logger->Info("Screen Resolution: %dx%d", g_nScreenWidth, g_nScreenHeight);
}

// ============================================================================
// Initialization
// ============================================================================

bool InitializeAO() {
    logger->Info("Initializing SSAO system...");
    
    PrintGLInfo();
    GetScreenResolution();
    
    if(g_nScreenWidth == 0 || g_nScreenHeight == 0) {
        logger->Error("Invalid screen resolution!");
        return false;
    }
    
    // TODO Phase 2: Create G-Buffer FBO
    // TODO Phase 3: Create SSAO compute shader
    // TODO Phase 4: Create blur & composite
    
    g_bAOInitialized = true;
    logger->Info("SSAO system initialized!");
    return true;
}

// ============================================================================
// Render Hook
// ============================================================================

void HookedRenderScene(bool param) {
    // First frame initialization
    if(g_bFirstFrame) {
        g_bFirstFrame = false;
        logger->Info("First frame! Initializing...");
        
        if(!InitializeAO()) {
            logger->Error("Failed to initialize!");
        }
    }
    
    g_nFrameCount++;
    
    // Log every 60 frames
    if(g_nFrameCount % 60 == 0) {
        logger->Info("Frame: %d | Hook active!", g_nFrameCount);
        
        if(g_pGetViewMatrix && g_pGetProjectionMatrix) {
            void* viewMat = g_pGetViewMatrix();
            void* projMat = g_pGetProjectionMatrix();
            if(viewMat && projMat) {
                logger->Info("Matrices extracted OK!");
            }
        }
    }
    
    // TODO Phase 2: G-Buffer pass here
    
    // Original render
    g_pOriginalRenderScene(param);
    
    // TODO Phase 3: SSAO compute here
    // TODO Phase 4: Composite here
}

// ============================================================================
// Hooking
// ============================================================================

bool HookFunctions(void* handle) {
    logger->Info("Hooking rendering functions...");
    
    // Get RenderScene (offset 0x003f609c from your symbols)
    uintptr_t pRenderScene = aml->GetSym(handle, "_Z11RenderSceneb");
    if(!pRenderScene) {
        logger->Error("Failed to find RenderScene!");
        return false;
    }
    logger->Info("RenderScene: 0x%08X", pRenderScene);
    
    // Get matrix functions
    g_pGetViewMatrix = (GetCurrentViewMatrix_t)aml->GetSym(handle, 
        "_Z20GetCurrentViewMatrixv");
    g_pGetProjectionMatrix = (GetCurrentProjectionMatrix_t)aml->GetSym(handle, 
        "_Z26GetCurrentProjectionMatrixv");
    
    if(!g_pGetViewMatrix || !g_pGetProjectionMatrix) {
        logger->Error("Failed to find matrix functions!");
        return false;
    }
    logger->Info("Matrix functions found!");
    
    // Hook RenderScene
    aml->Redirect(pRenderScene, (uintptr_t)HookedRenderScene, 
                  (uintptr_t*)&g_pOriginalRenderScene);
    
    logger->Info("Functions hooked successfully!");
    return true;
}

// ============================================================================
// AML Callbacks
// ============================================================================

extern "C" void OnModPreLoad() {
    logger->SetTag("SSAO_Niat");
    logger->Info("╔════════════════════════════════════╗");
    logger->Info("║   GTA SA SSAO - Niat Edition      ║");
    logger->Info("║   Phase 1: Foundation             ║");
    logger->Info("╚════════════════════════════════════╝");
    
    // Config
    config->Bind("Author", "")->SetString("YourName");
    g_pCfgEnabled = config->Bind("Enabled", true, "SSAO");
    g_pCfgIntensity = config->Bind("Intensity", 1.5f, "SSAO");
    g_pCfgRadius = config->Bind("Radius", 0.5f, "SSAO");
    config->Save();
}

extern "C" void OnModLoad() {
    logger->Info("Loading mod...");
    
    void* hGTASA = aml->GetLibHandle("libGTASA.so");
    if(!hGTASA) {
        logger->Error("Failed to get libGTASA.so!");
        return;
    }
    
    if(!HookFunctions(hGTASA)) {
        logger->Error("Hooking failed!");
        return;
    }
    
    logger->Info("Mod loaded! Waiting for first frame...");
}
EOF

# ============================================================================
# jni/Android.mk
# ============================================================================

echo "  → Creating jni/Android.mk..."

cat > jni/Android.mk << 'EOF'
LOCAL_PATH := $(call my-dir)

# ============================================================================
# ARMPatch
# ============================================================================

include $(CLEAR_VARS)
LOCAL_MODULE := armpatch
LOCAL_SRC_FILES := ../obj/local/$(TARGET_ARCH_ABI)/libarmpatch.a
include $(PREBUILT_STATIC_LIBRARY)

# ============================================================================
# Substrate
# ============================================================================

include $(CLEAR_VARS)
LOCAL_MODULE := substrate
LOCAL_SRC_FILES := ../obj/local/$(TARGET_ARCH_ABI)/libsubstrate.a
include $(PREBUILT_STATIC_LIBRARY)

# ============================================================================
# GlossHook
# ============================================================================

include $(CLEAR_VARS)
LOCAL_MODULE := gloss
LOCAL_SRC_FILES := ../AML_PrecompiledLibs/$(TARGET_ARCH_ABI)/libGlossHook.a
include $(PREBUILT_STATIC_LIBRARY)

# ============================================================================
# SSAO Niat - Main Module
# ============================================================================

include $(CLEAR_VARS)

LOCAL_MODULE := SSAO_Niat
LOCAL_CPP_EXTENSION := .cpp .cc

LOCAL_SRC_FILES := main.cpp

LOCAL_SHARED_LIBRARIES := armpatch substrate gloss

LOCAL_C_INCLUDES += $(LOCAL_PATH)/../include \
                    $(LOCAL_PATH)/../AML_PrecompiledLibs/include

LOCAL_CFLAGS += -O2 -mfloat-abi=softfp -DNDEBUG -std=c17 -mthumb
LOCAL_CXXFLAGS += -O2 -mfloat-abi=softfp -DNDEBUG -std=c++17 -mthumb -fexceptions

LOCAL_LDLIBS += -llog -ldl -lGLESv3 -lEGL -landroid

include $(BUILD_SHARED_LIBRARY)
EOF

# ============================================================================
# jni/Application.mk
# ============================================================================

echo "  → Creating jni/Application.mk..."

cat > jni/Application.mk << 'EOF'
APP_STL := c++_static
APP_ABI := armeabi-v7a
APP_PLATFORM := android-21
APP_OPTIM := release
NDK_TOOLCHAIN_VERSION := clang
EOF

# ============================================================================
# .github/workflows/build.yml
# ============================================================================

echo "  → Creating .github/workflows/build.yml..."

cat > .github/workflows/build.yml << 'EOF'
name: Build SSAO Niat

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup NDK
      uses: nttld/setup-ndk@v1
      with:
        ndk-version: r24

    - name: Download Dependencies
      run: ./setup.sh || true

    - name: Build ARMPatch
      run: |
        if [ -d "ARMPatch/armpatch_src" ]; then
          ndk-build NDK_PROJECT_PATH=. \
                    APP_BUILD_SCRIPT=./ARMPatch/armpatch_src/Android.mk \
                    NDK_APPLICATION_MK=./ARMPatch/armpatch_src/Application.mk \
                    -j$(nproc) || true
        fi

    - name: Build Mod
      run: |
        ndk-build NDK_PROJECT_PATH=. \
                  APP_BUILD_SCRIPT=./jni/Android.mk \
                  NDK_APPLICATION_MK=./jni/Application.mk \
                  -j$(nproc)

    - name: Upload Artifact
      uses: actions/upload-artifact@v4
      with:
        name: SSAO_Niat_Mod
        path: libs/armeabi-v7a/*.so
EOF

# ============================================================================
# build.sh
# ============================================================================

echo "  → Creating build.sh..."

cat > build.sh << 'EOF'
#!/bin/bash

echo "════════════════════════════════════════"
echo "  Building SSAO Niat"
echo "════════════════════════════════════════"

# Build ARMPatch if exists
if [ -d "ARMPatch/armpatch_src" ]; then
    echo ""
    echo "[1/2] Building ARMPatch..."
    ndk-build NDK_PROJECT_PATH=. \
              APP_BUILD_SCRIPT=./ARMPatch/armpatch_src/Android.mk \
              NDK_APPLICATION_MK=./ARMPatch/armpatch_src/Application.mk \
              -j$(nproc)
fi

# Build mod
echo ""
echo "[2/2] Building SSAO Niat..."
ndk-build NDK_PROJECT_PATH=. \
          APP_BUILD_SCRIPT=./jni/Android.mk \
          NDK_APPLICATION_MK=./jni/Application.mk \
          -j$(nproc)

echo ""
echo "════════════════════════════════════════"
echo "  Build Complete!"
echo "════════════════════════════════════════"
echo ""
echo "Output: libs/armeabi-v7a/libSSAO_Niat.so"
echo ""
echo "Install:"
echo "  adb push libs/armeabi-v7a/libSSAO_Niat.so \\"
echo "    /sdcard/Android/data/com.rockstargames.gtasa/mods/"
echo ""
EOF

chmod +x build.sh

# ============================================================================
# README.md
# ============================================================================

echo "  → Creating README.md..."

cat > README.md << 'EOF'
# SSAO Niat - GTA SA Android

Screen Space Ambient Occlusion untuk GTA San Andreas Android.

## 🚀 Quick Start

```bash
# 1. Setup dependencies
./setup.sh

# 2. Build
./build.sh

# 3. Install
adb push libs/armeabi-v7a/libSSAO_Niat.so \
  /sdcard/Android/data/com.rockstargames.gtasa/mods/
```

## 📋 Requirements

- Android NDK r24+
- GTA SA v2.00 (ARM32)
- OpenGL ES 3.0+
- Device with 3+ render targets

## 📊 Status

- ✅ Phase 1: Foundation (DONE)
- ⏳ Phase 2: G-Buffer
- ⏳ Phase 3: SSAO Core  
- ⏳ Phase 4: Polish

## 🐛 Debug

```bash
adb logcat | grep SSAO_Niat
```

## 📝 Config

`/sdcard/Android/data/com.rockstargames.gtasa/configs/ModLoaderCore.cfg`

```ini
[SSAO]
Enabled = true
Intensity = 1.5
Radius = 0.5
```

## 🤝 Credits

- AML - RusJJ
- MTA:SA - Reference
- SAADOX - Inspiration
EOF

# ============================================================================
# .gitignore
# ============================================================================

echo "  → Creating .gitignore..."

cat > .gitignore << 'EOF'
# Build outputs
libs/
obj/
AML_Temp/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db
EOF

echo -e "${GREEN}  ✓ Project files created${NC}"
echo ""

# ============================================================================
# Final Summary
# ============================================================================

echo -e "${BLUE}[4/4] Setup complete!${NC}"
echo ""
echo "════════════════════════════════════════"
echo -e "${GREEN}  SSAO Niat - Ready to Build!${NC}"
echo "════════════════════════════════════════"
echo ""
echo "Project structure:"
echo "  ├── jni/"
echo "  │   ├── main.cpp         (Phase 1 code)"
echo "  │   ├── Android.mk"
echo "  │   └── Application.mk"
echo "  ├── .github/workflows/   (CI/CD)"
echo "  ├── build.sh             (Build script)"
echo "  ├── setup.sh             (This script)"
echo "  └── README.md"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "  1. Build the mod:"
echo "     ${GREEN}./build.sh${NC}"
echo ""
echo "  2. Install to device:"
echo "     ${GREEN}adb push libs/armeabi-v7a/libSSAO_Niat.so \\${NC}"
echo "     ${GREEN}  /sdcard/Android/data/com.rockstargames.gtasa/mods/${NC}"
echo ""
echo "  3. Test in-game and check logs:"
echo "     ${GREEN}adb logcat | grep SSAO_Niat${NC}"
echo ""
echo "════════════════════════════════════════"
echo ""

# Check dependencies
if [ -f "AML_PrecompiledLibs/armeabi-v7a/libGlossHook.a" ]; then
    echo -e "${GREEN}✓ Dependencies OK!${NC}"
else
    echo -e "${YELLOW}! Dependencies incomplete - run ./setup.sh again${NC}"
fi

echo ""
echo -e "${GREEN}Setup complete! Run ./build.sh to compile!${NC}"
echo ""

chmod +x setup.sh

echo -e "${GREEN}  ✓ setup.sh created${NC}"
echo ""

echo "════════════════════════════════════════"
echo -e "${GREEN}Complete setup file created!${NC}"
echo "════════════════════════════════════════"
echo ""
echo "This file includes EVERYTHING:"
echo "  • Auto-download dependencies"
echo "  • Generate all project files"
echo "  • Build scripts"
echo "  • CI/CD workflow"
echo "  • Documentation"
echo ""
echo "Save this as 'setup.sh' in your repo!"
echo ""
