#!/bin/bash
set -e

echo "╔════════════════════════════════════════╗"
echo "║   GTA SA SSAO Niat - Setup            ║"
echo "╚════════════════════════════════════════╝"

# Create AML headers (embedded)
mkdir -p include/mod

cat > include/mod/amlmod.h << 'AMLMOD_H'
#pragma once
#define MYMOD(id, name, ver, author) \
    const char* g_pModGUID = id; \
    const char* g_pModName = name; \
    const char* g_pModVer = ver; \
    const char* g_pModAuthor = author;
AMLMOD_H

cat > include/mod/logger.h << 'LOGGER_H'
#pragma once
#include <android/log.h>
#define LOGD(tag, ...) __android_log_print(ANDROID_LOG_DEBUG, tag, __VA_ARGS__)
#define LOGI(tag, ...) __android_log_print(ANDROID_LOG_INFO, tag, __VA_ARGS__)
#define LOGE(tag, ...) __android_log_print(ANDROID_LOG_ERROR, tag, __VA_ARGS__)

struct Logger {
    const char* tag = "AML";
    void SetTag(const char* t) { tag = t; }
    void Info(const char* fmt, ...) {
        va_list args; va_start(args, fmt);
        __android_log_vprint(ANDROID_LOG_INFO, tag, fmt, args);
        va_end(args);
    }
    void Error(const char* fmt, ...) {
        va_list args; va_start(args, fmt);
        __android_log_vprint(ANDROID_LOG_ERROR, tag, fmt, args);
        va_end(args);
    }
};
static Logger* logger = new Logger();
LOGGER_H

cat > include/mod/config.h << 'CONFIG_H'
#pragma once
struct ConfigEntry {
    template<typename T> ConfigEntry* SetString(T) { return this; }
    template<typename T> ConfigEntry* SetInt(T) { return this; }
    const char* GetString() { return ""; }
    int GetInt() { return 0; }
};
struct Config {
    ConfigEntry* Bind(const char*, const char*) { return new ConfigEntry(); }
    ConfigEntry* Bind(const char*, bool, const char* = "") { return new ConfigEntry(); }
    ConfigEntry* Bind(const char*, float, const char* = "") { return new ConfigEntry(); }
    void Save() {}
};
static Config* config = new Config();
CONFIG_H

cat > include/aml.h << 'AML_H'
#pragma once
#include <dlfcn.h>
#include <cstdint>

struct AML {
    void* GetLibHandle(const char* name) { return dlopen(name, RTLD_NOW); }
    uintptr_t GetSym(void* h, const char* sym) {
        return (uintptr_t)dlsym(h, sym);
    }
    void Redirect(uintptr_t addr, uintptr_t dst, uintptr_t* orig) {
        *orig = addr;
        // Simplified redirect (Phase 1 mock)
    }
};
static AML* aml = new AML();
AML_H

echo "✓ Headers created"

# Generate project
mkdir -p jni

cat > jni/main.cpp << 'MAIN_CPP'
#include <mod/amlmod.h>
#include <mod/logger.h>
#include <mod/config.h>
#include <GLES3/gl3.h>
#include <aml.h>

MYMOD(net.gtasa.ssao, SSAO Niat, 1.0, Author)

typedef void (*RenderScene_t)(bool);
RenderScene_t g_orig = nullptr;

bool g_first = true;
int g_frame = 0;

void HookedRender(bool p) {
    if(g_first) {
        g_first = false;
        logger->Info("════════════════════════════════");
        logger->Info("  SSAO Niat - Phase 1 Active!");
        logger->Info("════════════════════════════════");
        
        GLint maxRT = 0;
        glGetIntegerv(GL_MAX_DRAW_BUFFERS, &maxRT);
        logger->Info("Max Render Targets: %d", maxRT);
        
        if(maxRT >= 3) logger->Info("✓ MRT (3 targets) supported!");
        else logger->Error("✗ MRT not supported!");
    }
    
    if(++g_frame % 120 == 0)
        logger->Info("Frame: %d | Running OK", g_frame);
    
    if(g_orig) g_orig(p);
}

extern "C" void OnModLoad() {
    logger->SetTag("SSAO_Niat");
    logger->Info("Loading SSAO Niat...");
    
    void* h = aml->GetLibHandle("libGTASA.so");
    if(!h) {
        logger->Error("Failed to get libGTASA.so!");
        return;
    }
    
    uintptr_t addr = aml->GetSym(h, "_Z11RenderSceneb");
    if(!addr) {
        logger->Error("Failed to find RenderScene!");
        return;
    }
    
    logger->Info("RenderScene: 0x%08X", addr);
    aml->Redirect(addr, (uintptr_t)HookedRender, (uintptr_t*)&g_orig);
    
    logger->Info("✓ Hooked successfully!");
    logger->Info("Waiting for first frame...");
}
MAIN_CPP

cat > jni/Android.mk << 'ANDROID_MK'
LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)
LOCAL_MODULE := SSAO_Niat
LOCAL_SRC_FILES := main.cpp
LOCAL_C_INCLUDES := $(LOCAL_PATH)/../include
LOCAL_CXXFLAGS := -O2 -std=c++17 -fexceptions
LOCAL_LDLIBS := -llog -ldl -lGLESv3
include $(BUILD_SHARED_LIBRARY)
ANDROID_MK

cat > jni/Application.mk << 'APP_MK'
APP_STL := c++_static
APP_ABI := armeabi-v7a
APP_PLATFORM := android-21
APP_OPTIM := release
APP_MK

echo "✓ Project generated"
echo ""
echo "════════════════════════════════════════"
echo "  Setup Complete!"
echo "════════════════════════════════════════"
