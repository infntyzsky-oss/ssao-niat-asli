LOCAL_PATH := $(call my-dir)

# ============================================================================
# Prebuilt Libraries (AML Dependencies)
# ============================================================================

include $(CLEAR_VARS)
LOCAL_MODULE := substrate
LOCAL_SRC_FILES := ../AML_PrecompiledLibs/$(TARGET_ARCH_ABI)/libsubstrate.a
include $(PREBUILT_STATIC_LIBRARY)

include $(CLEAR_VARS)
LOCAL_MODULE := gloss
LOCAL_SRC_FILES := ../AML_PrecompiledLibs/$(TARGET_ARCH_ABI)/libGlossHook.a
include $(PREBUILT_STATIC_LIBRARY)

# ============================================================================
# Main Module - GTA SA AO
# ============================================================================

include $(CLEAR_VARS)

LOCAL_MODULE := GTASA_AO
LOCAL_CPP_EXTENSION := .cpp .cc

# Source files
LOCAL_SRC_FILES := main.cpp

# Shared libraries
LOCAL_SHARED_LIBRARIES := substrate gloss

# Include paths
LOCAL_C_INCLUDES += $(LOCAL_PATH)/../AML_PrecompiledLibs/include

# Compiler flags
LOCAL_CFLAGS += -O2 -mfloat-abi=softfp -DNDEBUG -std=c17 -mthumb
LOCAL_CXXFLAGS += -O2 -mfloat-abi=softfp -DNDEBUG -std=c++17 -mthumb -fexceptions

# Linker flags
LOCAL_LDLIBS += -llog -ldl -lGLESv3 -lEGL -landroid

# Build
include $(BUILD_SHARED_LIBRARY)
