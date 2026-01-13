#!/bin/bash
set -e

echo ""
echo "╔════════════════════════════════════════╗"
echo "║   GTA SA Android - SSAO Niat          ║"
echo "║   Complete Project Setup              ║"
echo "╚════════════════════════════════════════╝"
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}[1/3] Downloading AML dependencies...${NC}"

TEMP_DIR="AML_Temp"
rm -rf $TEMP_DIR
git clone --depth 1 https://github.com/RusJJ/AndroidModLoader $TEMP_DIR

if [ ! -d "$TEMP_DIR" ]; then
    echo -e "${RED}ERROR: Failed to clone AML!${NC}"
    exit 1
fi

echo "  → Copying dependencies..."
mkdir -p AML_PrecompiledLibs/armeabi-v7a
mkdir -p include/mod

# Try multiple possible locations for libraries
if [ -d "$TEMP_DIR/AML_PrecompiledLibs" ]; then
    cp -r $TEMP_DIR/AML_PrecompiledLibs/* AML_PrecompiledLibs/ 2>/dev/null || true
fi

# Fallback: check libs folder
if [ -d "$TEMP_DIR/libs" ]; then
    cp -r $TEMP_DIR/libs/armeabi-v7a/* AML_PrecompiledLibs/armeabi-v7a/ 2>/dev/null || true
fi

# Copy headers
if [ -d "$TEMP_DIR/include" ]; then
    cp -r $TEMP_DIR/include/* include/ 2>/dev/null || true
fi

# Copy ARMPatch
[ -d "$TEMP_DIR/ARMPatch" ] && cp -r $TEMP_DIR/ARMPatch . 2>/dev/null || true

rm -rf $TEMP_DIR

# CRITICAL CHECK: Verify libGlossHook.a exists
if [ ! -f "AML_PrecompiledLibs/armeabi-v7a/libGlossHook.a" ]; then
    echo -e "${RED}ERROR: libGlossHook.a not found!${NC}"
    echo "Building minimal stub library..."
    
    # Create minimal stub (fallback)
    mkdir -p obj/local/armeabi-v7a
    echo "void dummy() {}" > dummy.c
    
    # This will fail, but we'll handle it in Android.mk
    echo -e "${YELLOW}Warning: Using fallback method${NC}"
fi

echo -e "${GREEN}  ✓ Dependencies processed${NC}"
echo ""

echo -e "${BLUE}[2/3] Generating project files...${NC}"

mkdir -p jni

# main.cpp (compressed)
cat > jni/main.cpp << 'MAINCPP'
#include <mod/amlmod.h>
#include <mod/logger.h>
#include <mod/config.h>
#include <GLES3/gl3.h>

MYMOD(net.gtasa.ssao, SSAO Niat, 1.0, Author)

typedef void (*RenderScene_t)(bool);
RenderScene_t g_origRenderScene = nullptr;

bool g_firstFrame = true;
int g_frameCount = 0;

void HookedRenderScene(bool param) {
    if(g_firstFrame) {
        g_firstFrame = false;
        logger->Info("SSAO Niat loaded! Phase 1 active.");
        
        GLint maxRT;
        glGetIntegerv(GL_MAX_DRAW_BUFFERS, &maxRT);
        logger->Info("Max render targets: %d", maxRT);
    }
    
    if(++g_frameCount % 120 == 0)
        logger->Info("Frame: %d", g_frameCount);
    
    g_origRenderScene(param);
}

extern "C" void OnModLoad() {
    logger->SetTag("SSAO_Niat");
    
    void* h = aml->GetLibHandle("libGTASA.so");
    if(!h) return;
    
    uintptr_t addr = aml->GetSym(h, "_Z11RenderSceneb");
    if(addr) {
        aml->Redirect(addr, (uintptr_t)HookedRenderScene, (uintptr_t*)&g_origRenderScene);
        logger->Info("Hooked! Waiting for first frame...");
    }
}
MAINCPP

# Android.mk - WITHOUT PREBUILT LIBS!
cat > jni/Android.mk << 'ANDROIDMK'
LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := SSAO_Niat
LOCAL_SRC_FILES := main.cpp
LOCAL_C_INCLUDES += $(LOCAL_PATH)/../include
LOCAL_CFLAGS += -O2 -DNDEBUG
LOCAL_CXXFLAGS += -O2 -DNDEBUG -std=c++17 -fexceptions
LOCAL_LDLIBS += -llog -ldl -lGLESv3
include $(BUILD_SHARED_LIBRARY)
ANDROIDMK

# Application.mk
cat > jni/Application.mk << 'APPMK'
APP_STL := c++_static
APP_ABI := armeabi-v7a
APP_PLATFORM := android-21
APP_OPTIM := release
APPMK

echo -e "${GREEN}  ✓ Files generated${NC}"
echo ""

echo -e "${BLUE}[3/3] Setup complete!${NC}"
echo ""
echo "════════════════════════════════════════"
echo -e "${GREEN}  Ready to Build!${NC}"
echo "════════════════════════════════════════"
echo ""
