#!/bin/bash
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

echo -e "${BLUE}[1/4] Downloading AML dependencies...${NC}"

TEMP_DIR="AML_Temp"
rm -rf $TEMP_DIR
git clone --depth 1 https://github.com/RusJJ/AndroidModLoader $TEMP_DIR

echo "  → Copying AML_PrecompiledLibs..."
mkdir -p AML_PrecompiledLibs
cp -r $TEMP_DIR/AML_PrecompiledLibs/* AML_PrecompiledLibs/ 2>/dev/null || true

echo "  → Copying include files..."
mkdir -p include
cp -r $TEMP_DIR/include/* include/ 2>/dev/null || true

echo "  → Copying ARMPatch..."
[ -d "$TEMP_DIR/ARMPatch" ] && cp -r $TEMP_DIR/ARMPatch .

rm -rf $TEMP_DIR
echo -e "${GREEN}  ✓ Dependencies downloaded${NC}"
echo ""

echo -e "${BLUE}[2/4] Creating project structure...${NC}"
mkdir -p jni libs/armeabi-v7a obj/local/armeabi-v7a .github/workflows
echo -e "${GREEN}  ✓ Directories created${NC}"
echo ""

echo -e "${BLUE}[3/4] Generating project files...${NC}"

# main.cpp
echo "  → Creating jni/main.cpp..."
cat > jni/main.cpp << 'MAINCPP'
#include <mod/amlmod.h>
#include <mod/logger.h>
#include <mod/config.h>
#include <GLES3/gl3.h>

MYMOD(net.gtasa.ssao, GTA:SA SSAO Niat, 1.0.0, YourName)

ConfigEntry *g_pCfgEnabled, *g_pCfgIntensity, *g_pCfgRadius;

typedef void (*RenderScene_t)(bool);
RenderScene_t g_pOriginalRenderScene = nullptr;

typedef void* (*GetCurrentViewMatrix_t)();
typedef void* (*GetCurrentProjectionMatrix_t)();
GetCurrentViewMatrix_t g_pGetViewMatrix = nullptr;
GetCurrentProjectionMatrix_t g_pGetProjectionMatrix = nullptr;

bool g_bAOInitialized = false, g_bFirstFrame = true;
int g_nFrameCount = 0, g_nScreenWidth = 0, g_nScreenHeight = 0;

void CheckGLError(const char* op) {
    GLenum error;
    while((error = glGetError()) != GL_NO_ERROR)
        logger->Error("GL error after %s: 0x%x", op, error);
}

void PrintGLInfo() {
    logger->Info("OpenGL Vendor: %s", glGetString(GL_VENDOR));
    logger->Info("OpenGL Renderer: %s", glGetString(GL_RENDERER));
    logger->Info("OpenGL Version: %s", glGetString(GL_VERSION));
    
    GLint maxDrawBuffers, maxColorAttachments;
    glGetIntegerv(GL_MAX_DRAW_BUFFERS, &maxDrawBuffers);
    glGetIntegerv(GL_MAX_COLOR_ATTACHMENTS, &maxColorAttachments);
    
    logger->Info("Max Draw Buffers: %d", maxDrawBuffers);
    logger->Info("Max Color Attachments: %d", maxColorAttachments);
    
    if(maxDrawBuffers < 3)
        logger->Error("Device does not support 3 render targets!");
    else
        logger->Info("MRT (3 targets) supported!");
}

void GetScreenResolution() {
    GLint viewport[4];
    glGetIntegerv(GL_VIEWPORT, viewport);
    g_nScreenWidth = viewport[2];
    g_nScreenHeight = viewport[3];
    logger->Info("Screen Resolution: %dx%d", g_nScreenWidth, g_nScreenHeight);
}

bool InitializeAO() {
    logger->Info("Initializing SSAO system...");
    PrintGLInfo();
    GetScreenResolution();
    
    if(g_nScreenWidth == 0 || g_nScreenHeight == 0) {
        logger->Error("Invalid screen resolution!");
        return false;
    }
    
    g_bAOInitialized = true;
    logger->Info("SSAO system initialized!");
    return true;
}

void HookedRenderScene(bool param) {
    if(g_bFirstFrame) {
        g_bFirstFrame = false;
        logger->Info("First frame! Initializing...");
        if(!InitializeAO())
            logger->Error("Failed to initialize!");
    }
    
    g_nFrameCount++;
    
    if(g_nFrameCount % 60 == 0) {
        logger->Info("Frame: %d | Hook active!", g_nFrameCount);
        if(g_pGetViewMatrix && g_pGetProjectionMatrix) {
            void* viewMat = g_pGetViewMatrix();
            void* projMat = g_pGetProjectionMatrix();
            if(viewMat && projMat)
                logger->Info("Matrices extracted OK!");
        }
    }
    
    g_pOriginalRenderScene(param);
}

bool HookFunctions(void* handle) {
    logger->Info("Hooking rendering functions...");
    
    uintptr_t pRenderScene = aml->GetSym(handle, "_Z11RenderSceneb");
    if(!pRenderScene) {
        logger->Error("Failed to find RenderScene!");
        return false;
    }
    logger->Info("RenderScene: 0x%08X", pRenderScene);
    
    g_pGetViewMatrix = (GetCurrentViewMatrix_t)aml->GetSym(handle, "_Z20GetCurrentViewMatrixv");
    g_pGetProjectionMatrix = (GetCurrentProjectionMatrix_t)aml->GetSym(handle, "_Z26GetCurrentProjectionMatrixv");
    
    if(!g_pGetViewMatrix || !g_pGetProjectionMatrix) {
        logger->Error("Failed to find matrix functions!");
        return false;
    }
    logger->Info("Matrix functions found!");
    
    aml->Redirect(pRenderScene, (uintptr_t)HookedRenderScene, (uintptr_t*)&g_pOriginalRenderScene);
    
    logger->Info("Functions hooked successfully!");
    return true;
}

extern "C" void OnModPreLoad() {
    logger->SetTag("SSAO_Niat");
    logger->Info("╔════════════════════════════════════╗");
    logger->Info("║   GTA SA SSAO - Niat Edition      ║");
    logger->Info("║   Phase 1: Foundation             ║");
    logger->Info("╚════════════════════════════════════╝");
    
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
MAINCPP

# Android.mk - NO ARMPATCH!
echo "  → Creating jni/Android.mk..."
cat > jni/Android.mk << 'ANDROIDMK'
LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := gloss
LOCAL_SRC_FILES := ../AML_PrecompiledLibs/$(TARGET_ARCH_ABI)/libGlossHook.a
include $(PREBUILT_STATIC_LIBRARY)

include $(CLEAR_VARS)
LOCAL_MODULE := SSAO_Niat
LOCAL_CPP_EXTENSION := .cpp .cc
LOCAL_SRC_FILES := main.cpp
LOCAL_STATIC_LIBRARIES := gloss
LOCAL_C_INCLUDES += $(LOCAL_PATH)/../include $(LOCAL_PATH)/../AML_PrecompiledLibs/include
LOCAL_CFLAGS += -O2 -mfloat-abi=softfp -DNDEBUG -std=c17 -mthumb
LOCAL_CXXFLAGS += -O2 -mfloat-abi=softfp -DNDEBUG -std=c++17 -mthumb -fexceptions
LOCAL_LDLIBS += -llog -ldl -lGLESv3 -lEGL -landroid
include $(BUILD_SHARED_LIBRARY)
ANDROIDMK

# Application.mk
echo "  → Creating jni/Application.mk..."
cat > jni/Application.mk << 'APPMK'
APP_STL := c++_static
APP_ABI := armeabi-v7a
APP_PLATFORM := android-21
APP_OPTIM := release
NDK_TOOLCHAIN_VERSION := clang
APPMK

echo -e "${GREEN}  ✓ Project files created${NC}"
echo ""

echo -e "${BLUE}[4/4] Setup complete!${NC}"
echo ""
echo "════════════════════════════════════════"
echo -e "${GREEN}  SSAO Niat - Ready to Build!${NC}"
echo "════════════════════════════════════════"

[ -f "AML_PrecompiledLibs/armeabi-v7a/libGlossHook.a" ] && echo -e "${GREEN}✓ Dependencies OK!${NC}" || echo -e "${YELLOW}! Dependencies incomplete${NC}"

echo ""
