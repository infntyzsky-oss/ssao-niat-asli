// ============================================================================
// GTA:SA Android - Ambient Occlusion Mod
// Phase 1: Foundation & Hooking
// Author: YourName
// ============================================================================

#include <mod/amlmod.h>
#include <mod/logger.h>
#include <mod/config.h>

// OpenGL ES 3.0
#include <GLES3/gl3.h>
#include <GLES3/gl3ext.h>

// Android
#include <jni.h>
#include <android/log.h>

// ============================================================================
// Module Info
// ============================================================================

MYMOD(net.gtasa.ao, GTA:SA Ambient Occlusion, 1.0, YourName)

// ============================================================================
// Config
// ============================================================================

ConfigEntry* g_pCfgEnabled;
ConfigEntry* g_pCfgIntensity;
ConfigEntry* g_pCfgRadius;

// ============================================================================
// Symbol Addresses (from your list)
// ============================================================================

// RenderScene
typedef void (*RenderScene_t)(bool);
RenderScene_t g_pOriginalRenderScene = nullptr;

// Matrix functions
typedef void* (*GetCurrentViewMatrix_t)();
typedef void* (*GetCurrentProjectionMatrix_t)();
GetCurrentViewMatrix_t g_pGetViewMatrix = nullptr;
GetCurrentProjectionMatrix_t g_pGetProjectionMatrix = nullptr;

// Camera
struct CCamera; // Forward declare
CCamera* TheCamera = nullptr;

// ============================================================================
// Hooked Functions
// ============================================================================

bool g_bAOInitialized = false;
int g_nFrameCount = 0;

void HookedRenderScene(bool param)
{
    g_nFrameCount++;
    
    // Log every 60 frames (every ~2 seconds at 30fps)
    if(g_nFrameCount % 60 == 0)
    {
        logger->Info("RenderScene hooked! Frame: %d", g_nFrameCount);
        
        // Test matrix extraction
        if(g_pGetViewMatrix && g_pGetProjectionMatrix)
        {
            void* viewMat = g_pGetViewMatrix();
            void* projMat = g_pGetProjectionMatrix();
            
            if(viewMat && projMat)
            {
                logger->Info("Matrices extracted successfully!");
            }
        }
    }
    
    // === TODO: G-Buffer Pass Here (Phase 2) ===
    
    // Call original render
    g_pOriginalRenderScene(param);
    
    // === TODO: SSAO Pass Here (Phase 3) ===
    
    // === TODO: Composite Here (Phase 4) ===
}

// ============================================================================
// OpenGL Utility Functions
// ============================================================================

void CheckGLError(const char* op)
{
    GLenum error;
    while((error = glGetError()) != GL_NO_ERROR)
    {
        logger->Error("OpenGL error after %s: 0x%x", op, error);
    }
}

void PrintGLInfo()
{
    const GLubyte* vendor = glGetString(GL_VENDOR);
    const GLubyte* renderer = glGetString(GL_RENDERER);
    const GLubyte* version = glGetString(GL_VERSION);
    const GLubyte* glsl = glGetString(GL_SHADING_LANGUAGE_VERSION);
    
    logger->Info("OpenGL Vendor: %s", vendor);
    logger->Info("OpenGL Renderer: %s", renderer);
    logger->Info("OpenGL Version: %s", version);
    logger->Info("GLSL Version: %s", glsl);
    
    // Check for important extensions
    GLint maxDrawBuffers, maxColorAttachments;
    glGetIntegerv(GL_MAX_DRAW_BUFFERS, &maxDrawBuffers);
    glGetIntegerv(GL_MAX_COLOR_ATTACHMENTS, &maxColorAttachments);
    
    logger->Info("Max Draw Buffers: %d", maxDrawBuffers);
    logger->Info("Max Color Attachments: %d", maxColorAttachments);
    
    if(maxDrawBuffers < 3)
    {
        logger->Error("Device does not support 3 render targets! AO will not work!");
    }
}

// ============================================================================
// Screen Info
// ============================================================================

int g_nScreenWidth = 0;
int g_nScreenHeight = 0;

void GetScreenResolution()
{
    GLint viewport[4];
    glGetIntegerv(GL_VIEWPORT, viewport);
    
    g_nScreenWidth = viewport[2];
    g_nScreenHeight = viewport[3];
    
    logger->Info("Screen Resolution: %dx%d", g_nScreenWidth, g_nScreenHeight);
}

// ============================================================================
// Initialization
// ============================================================================

bool InitializeAO()
{
    logger->Info("Initializing AO system...");
    
    // Print OpenGL info
    PrintGLInfo();
    
    // Get screen resolution
    GetScreenResolution();
    
    if(g_nScreenWidth == 0 || g_nScreenHeight == 0)
    {
        logger->Error("Invalid screen resolution!");
        return false;
    }
    
    // === TODO: Initialize G-Buffer (Phase 2) ===
    
    // === TODO: Initialize SSAO (Phase 3) ===
    
    g_bAOInitialized = true;
    logger->Info("AO system initialized successfully!");
    
    return true;
}

// ============================================================================
// Hooking
// ============================================================================

bool HookFunctions(void* handle)
{
    logger->Info("Hooking functions...");
    
    // Get RenderScene address
    uintptr_t pRenderScene = aml->GetSym(handle, "_Z11RenderSceneb");
    if(!pRenderScene)
    {
        logger->Error("Failed to find RenderScene!");
        return false;
    }
    logger->Info("RenderScene at: 0x%X", pRenderScene);
    
    // Get matrix functions
    g_pGetViewMatrix = (GetCurrentViewMatrix_t)aml->GetSym(handle, "_Z20GetCurrentViewMatrixv");
    g_pGetProjectionMatrix = (GetCurrentProjectionMatrix_t)aml->GetSym(handle, "_Z26GetCurrentProjectionMatrixv");
    
    if(!g_pGetViewMatrix || !g_pGetProjectionMatrix)
    {
        logger->Error("Failed to find matrix functions!");
        return false;
    }
    logger->Info("Matrix functions found!");
    
    // Get TheCamera global
    TheCamera = (CCamera*)aml->GetSym(handle, "TheCamera");
    if(!TheCamera)
    {
        logger->Warn("Failed to find TheCamera (optional)");
    }
    
    // Hook RenderScene
    aml->Redirect(pRenderScene, (uintptr_t)HookedRenderScene, (uintptr_t*)&g_pOriginalRenderScene);
    
    logger->Info("Functions hooked successfully!");
    return true;
}

// ============================================================================
// AML Callbacks
// ============================================================================

extern "C" void OnModPreLoad()
{
    logger->SetTag("GTASA_AO");
    logger->Info("===========================================");
    logger->Info("  GTA:SA Ambient Occlusion - Phase 1");
    logger->Info("  Testing: Mod Load + Hooking");
    logger->Info("===========================================");
    
    // Create config
    config->Bind("Author", "")->SetString("YourName");
    config->Bind("Discord", "")->SetString("Your Discord");
    
    // AO Settings
    g_pCfgEnabled = config->Bind("Enabled", true, "AO");
    g_pCfgIntensity = config->Bind("Intensity", 1.5f, "AO");
    g_pCfgRadius = config->Bind("Radius", 0.5f, "AO");
    
    config->Save();
}

extern "C" void OnModLoad()
{
    logger->Info("OnModLoad called!");
    
    // Get GTA SA handle
    void* hGTASA = aml->GetLibHandle("libGTASA.so");
    if(!hGTASA)
    {
        logger->Error("Failed to get libGTASA.so handle!");
        return;
    }
    logger->Info("Got GTA SA handle: 0x%p", hGTASA);
    
    // Hook functions
    if(!HookFunctions(hGTASA))
    {
        logger->Error("Failed to hook functions!");
        return;
    }
    
    logger->Info("Mod loaded successfully!");
    logger->Info("Waiting for first frame to initialize AO...");
}

// ============================================================================
// Lazy Initialization (on first frame)
// ============================================================================

// We initialize AO on first frame because OpenGL context must be active
bool g_bFirstFrame = true;

void OnFirstFrame()
{
    if(g_bFirstFrame)
    {
        g_bFirstFrame = false;
        
        logger->Info("First frame detected! Initializing AO...");
        
        // Initialize AO system
        if(!InitializeAO())
        {
            logger->Error("Failed to initialize AO!");
            return;
        }
        
        logger->Info("===========================================");
        logger->Info("  Phase 1 Complete!");
        logger->Info("  Check logcat for 'RenderScene hooked!'");
        logger->Info("===========================================");
    }
}

// Update HookedRenderScene to call OnFirstFrame
void HookedRenderScene(bool param)
{
    OnFirstFrame();
    
    g_nFrameCount++;
    
    if(g_nFrameCount % 60 == 0)
    {
        logger->Info("RenderScene hooked! Frame: %d", g_nFrameCount);
        
        if(g_pGetViewMatrix && g_pGetProjectionMatrix)
        {
            void* viewMat = g_pGetViewMatrix();
            void* projMat = g_pGetProjectionMatrix();
            
            if(viewMat && projMat)
            {
                logger->Info("Matrices OK!");
            }
        }
    }
    
    g_pOriginalRenderScene(param);
}
