#!/bin/bash

#============================================================
# P5 PROXY GENERATOR
# 
# This script generates proxy files for P5 Archive.
# It can create proxies for P5 browser preview and/or
# workflow proxies for editing systems.
#
# Usage in P5:
#   Preview Converter Script: scripts/p5_proxy_generator.sh
#
# Input:  $1 = Full path to source video file
# Output: Full path to generated proxy (stdout)
#
# Example configurations:
#
#   1. Only P5 preview (default behavior):
#      ENABLE_P5_PREVIEW=true, P5_PREVIEW_SOURCE="preview"
#      ENABLE_WORKFLOW_STORE=false
#      -> 1 encode (preview quality), returned to P5
#
#   2. Only workflow proxy (no P5 preview):
#      ENABLE_P5_PREVIEW=false
#      ENABLE_WORKFLOW_STORE=true, WORKFLOW_STORE_SOURCE="workflow"
#      -> 1 encode (workflow quality), stored in workflow path, dummy to P5
#
#   3. Same proxy for both (one encode):
#      ENABLE_P5_PREVIEW=true, P5_PREVIEW_SOURCE="workflow"
#      ENABLE_WORKFLOW_STORE=true, WORKFLOW_STORE_SOURCE="workflow"
#      -> 1 encode (workflow quality), stored + returned to P5
#
#   4. Different qualities (two encodes):
#      ENABLE_P5_PREVIEW=true, P5_PREVIEW_SOURCE="preview"
#      ENABLE_WORKFLOW_STORE=true, WORKFLOW_STORE_SOURCE="workflow"
#      -> 2 encodes, preview to P5, workflow stored
#
#============================================================

#============================================================
# CONFIGURATION - Adjust values here
#============================================================

# P5 Preview Settings
ENABLE_P5_PREVIEW=true              # Return a preview to P5 (false = dummy image)
P5_PREVIEW_SOURCE="preview"         # preview | workflow (which quality to use)

# Workflow Proxy Settings
ENABLE_WORKFLOW_STORE=true          # Store a proxy in workflow location
WORKFLOW_STORE_SOURCE="workflow"    # preview | workflow (which quality to use)

# Debug mode (set to true for troubleshooting)
DEBUG_MODE=false

#------------------------------------------------------------
# FFmpeg Configuration
#------------------------------------------------------------
#
# P5 built-in FFmpeg uses libopenh264:
#   - Limited options (bitrate only)
#   - Uses: PREVIEW_VBITRATE, WORKFLOW_VBITRATE
#
# Custom FFmpeg with libx264:
#   - Better quality, more control
#   - Uses: CRF, PRESET, TUNE options
#   - Required: FFmpeg compiled with --enable-libx264
#   - Recommended: FFmpeg 5.0 or newer
#
# Leave empty to use P5's built-in FFmpeg
#
FFMPEG_PATH=""                      # Example: /usr/local/bin/ffmpeg

#------------------------------------------------------------
# Workflow Path Configuration
#------------------------------------------------------------
#
# Three independent operations (applied in order):
#
# 1. BASE PATH REPLACEMENT (optional)
#    WORKFLOW_PROJECT_FOLDER = marker folder name
#    WORKFLOW_NEW_BASE = new base path (replaces everything BEFORE marker)
#
# 2. REMOVE LEVELS
#    WORKFLOW_REMOVE_LEVELS = number of directories to remove from end
#
# 3. APPEND PATH
#    WORKFLOW_REPLACE_WITH = path to append
#
# Example 1: Different storage for proxies
#   Source: /Volumes/RAW_Storage/Projects/2024/BMW_Commercial/Footage/A-Cam/A001C003.mov
#   
#   WORKFLOW_PROJECT_FOLDER="Projects"
#   WORKFLOW_NEW_BASE="/Volumes/Proxy_Storage"
#   WORKFLOW_REMOVE_LEVELS=1
#   WORKFLOW_REPLACE_WITH="Proxies"
#
#   Step 1 (replace base): /Volumes/Proxy_Storage/Projects/2024/BMW_Commercial/Footage/A-Cam/
#   Step 2 (remove 1 level): /Volumes/Proxy_Storage/Projects/2024/BMW_Commercial/Footage/
#   Step 3 (append): /Volumes/Proxy_Storage/Projects/2024/BMW_Commercial/Footage/Proxies/A001C003.mp4
#
# Example 2: Proxies next to source footage
#   Source: /Volumes/Production/2024/Documentary/Camera_Raw/Day01/B001.mov
#   
#   WORKFLOW_PROJECT_FOLDER=""
#   WORKFLOW_NEW_BASE=""
#   WORKFLOW_REMOVE_LEVELS=1
#   WORKFLOW_REPLACE_WITH="Proxies"
#
#   Result: /Volumes/Production/2024/Documentary/Camera_Raw/Proxies/B001.mp4
#
# Note: _proxy suffix is only added if target directory equals source directory
#
WORKFLOW_PROJECT_FOLDER=""            # Step 1: Marker folder (empty = skip step 1)
WORKFLOW_NEW_BASE=""                  # Step 1: New base path
WORKFLOW_REMOVE_LEVELS=1              # Step 2: Directories to remove (0 = skip)
WORKFLOW_REPLACE_WITH="proxies"       # Step 3: Path to append (empty = skip)

#------------------------------------------------------------
# Preview Proxy Settings (for P5 browser - speed optimized)
#------------------------------------------------------------
PREVIEW_SCALE="320"                 # Width in pixels (height proportional)
PREVIEW_ABITRATE="64k"              # Audio bitrate
PREVIEW_CODEC="h264"                # h264 | prores | dnxhd
PREVIEW_CODEC_PROFILE=""            # Profile (only for prores/dnxhd)
PREVIEW_CONTAINER=""                # Leave empty for auto-select

# P5 built-in FFmpeg (libopenh264):
PREVIEW_VBITRATE="256k"             # Video bitrate

# Custom FFmpeg (libx264):
PREVIEW_CRF="28"                    # Quality (higher = smaller, range 18-32)
PREVIEW_PRESET="veryfast"           # ultrafast|veryfast|fast|medium
PREVIEW_TUNE="fastdecode"           # fastdecode|zerolatency|film (empty = none)

#------------------------------------------------------------
# Workflow Proxy Settings (for editing - quality optimized)
#------------------------------------------------------------
WORKFLOW_SCALE="1920"               # Width in pixels (height proportional)
WORKFLOW_ABITRATE="128k"            # Audio bitrate
WORKFLOW_CODEC="h264"               # h264 | prores | dnxhd
WORKFLOW_CODEC_PROFILE=""           # Profile (only for prores/dnxhd)
WORKFLOW_CONTAINER=""               # Leave empty for auto-select

# P5 built-in FFmpeg (libopenh264):
WORKFLOW_VBITRATE="5000k"           # Video bitrate

# Custom FFmpeg (libx264):
WORKFLOW_CRF="18"                   # Quality (lower = better, range 16-23)
WORKFLOW_PRESET="medium"            # fast|medium|slow|veryslow
WORKFLOW_TUNE=""                    # film|animation (empty = none)

#============================================================
# DO NOT MODIFY BELOW THIS LINE
#============================================================

# Determine paths
if [ ! -z "$AWPST_SRV_HOME" ]; then
    AW_PATH="$AWPST_SRV_HOME"
else
    AW_PATH="/usr/local/aw"
fi

# Temp directory for preview proxies (cleaned on P5 restart)
AW_TEMP="$AW_PATH/temp"
if [ ! -d "$AW_TEMP" ]; then
    AW_TEMP="/tmp"
fi

# Log file in temp (auto-cleanup), symlinked to log directory
LOGFILE_ACTUAL="$AW_TEMP/proxy_generator.log"
LOGFILE_LINK="$AW_PATH/log/proxy_generator.log"

# Create symlink if it doesn't exist or points elsewhere
if [ ! -L "$LOGFILE_LINK" ] || [ "$(readlink "$LOGFILE_LINK")" != "$LOGFILE_ACTUAL" ]; then
    rm -f "$LOGFILE_LINK" 2>/dev/null
    ln -s "$LOGFILE_ACTUAL" "$LOGFILE_LINK" 2>/dev/null
fi

LOGFILE="$LOGFILE_ACTUAL"

# Input file
INPUT_FILE="$1"

# Logging function
log() {
    local TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$TIMESTAMP] $1" >> "$LOGFILE"
}

# Debug logging function (only logs if DEBUG_MODE=true)
debug_log() {
    if [ "$DEBUG_MODE" = "true" ]; then
        log "DEBUG: $1"
    fi
}

# Error exit function
error_exit() {
    log "ERROR: $1"
    exit 1
}

#------------------------------------------------------------
# Determine FFmpeg and check for libx264 support
#------------------------------------------------------------
USE_LIBX264=false

if [ ! -z "$FFMPEG_PATH" ] && [ -x "$FFMPEG_PATH" ]; then
    # Custom FFmpeg specified, check for libx264
    if "$FFMPEG_PATH" -encoders 2>/dev/null | grep -q "libx264"; then
        FFMPEG="$FFMPEG_PATH"
        USE_LIBX264=true
        log "Using custom FFmpeg with libx264: $FFMPEG"
    else
        log "WARNING: Custom FFmpeg does not support libx264, falling back to P5 built-in"
        FFMPEG="$AW_PATH/bin/ffmpeg"
        USE_LIBX264=false
    fi
elif [ ! -z "$FFMPEG_PATH" ]; then
    log "WARNING: Custom FFmpeg not found or not executable: $FFMPEG_PATH"
    log "Falling back to P5 built-in FFmpeg"
    FFMPEG="$AW_PATH/bin/ffmpeg"
    USE_LIBX264=false
else
    FFMPEG="$AW_PATH/bin/ffmpeg"
    USE_LIBX264=false
    debug_log "Using P5 built-in FFmpeg"
fi

debug_log "FFMPEG=$FFMPEG"
debug_log "USE_LIBX264=$USE_LIBX264"

#------------------------------------------------------------
# Build workflow destination path
#------------------------------------------------------------
build_workflow_path() {
    local src_file="$1"
    local container="$2"
    local src_dir=$(dirname "$src_file")
    local src_filename=$(basename "$src_file")
    local src_basename="${src_filename%.*}"
    local original_dir="$src_dir"
    
    debug_log "build_workflow_path: src_dir=$src_dir"
    
    # Step 1: Replace base path if configured
    if [ ! -z "$WORKFLOW_PROJECT_FOLDER" ] && [ ! -z "$WORKFLOW_NEW_BASE" ]; then
        # Check if marker folder exists in path
        if [[ "$src_dir" == *"/$WORKFLOW_PROJECT_FOLDER/"* ]]; then
            # Marker is in the middle: /path/to/marker/subdir
            local after_marker="${src_dir##*/$WORKFLOW_PROJECT_FOLDER/}"
            src_dir="$WORKFLOW_NEW_BASE/$WORKFLOW_PROJECT_FOLDER/$after_marker"
            debug_log "build_workflow_path: marker in middle, new src_dir=$src_dir"
        elif [[ "$src_dir" == *"/$WORKFLOW_PROJECT_FOLDER" ]]; then
            # Marker is at the end: /path/to/marker
            src_dir="$WORKFLOW_NEW_BASE/$WORKFLOW_PROJECT_FOLDER"
            debug_log "build_workflow_path: marker at end, new src_dir=$src_dir"
        else
            log "WARNING: Project folder '$WORKFLOW_PROJECT_FOLDER' not found in path: $src_dir"
        fi
    fi
    
    # Step 2: Remove specified number of directory levels
    local target_dir="$src_dir"
    for ((i=0; i<WORKFLOW_REMOVE_LEVELS; i++)); do
        target_dir=$(dirname "$target_dir")
    done
    debug_log "build_workflow_path: after remove levels=$target_dir"
    
    # Step 3: Append replacement path
    if [ ! -z "$WORKFLOW_REPLACE_WITH" ]; then
        target_dir="$target_dir/$WORKFLOW_REPLACE_WITH"
    fi
    debug_log "build_workflow_path: after append=$target_dir"
    
    # Add _proxy suffix only if target directory equals source directory
    local output_basename="$src_basename"
    if [ "$target_dir" = "$original_dir" ]; then
        output_basename="${src_basename}_proxy"
        debug_log "build_workflow_path: same directory, adding _proxy suffix"
    fi
    
    # Build full output path with new extension
    echo "$target_dir/${output_basename}.${container}"
}

#------------------------------------------------------------
# Get container based on codec
#------------------------------------------------------------
get_container() {
    local codec="$1"
    local custom_container="$2"
    
    if [ ! -z "$custom_container" ]; then
        echo "$custom_container"
        return
    fi
    
    case "$codec" in
        h264)   echo "mp4" ;;
        prores) echo "mov" ;;
        dnxhd)  echo "mxf" ;;
        *)      echo "mp4" ;;
    esac
}

#------------------------------------------------------------
# Generate proxy file
#------------------------------------------------------------
generate_proxy() {
    local input="$1"
    local output="$2"
    local scale="$3"
    local vbitrate="$4"
    local abitrate="$5"
    local proxy_type="$6"
    local codec="$7"
    local codec_profile="$8"
    local crf="$9"
    local preset="${10}"
    local tune="${11}"
    
    # Create output directory if needed
    local output_dir=$(dirname "$output")
    if [ ! -d "$output_dir" ]; then
        mkdir -p "$output_dir" || error_exit "Cannot create directory: $output_dir"
    fi
    
    log "Generating $proxy_type ($codec): $output"
    
    # Get container
    local container=$(get_container "$codec" "")
    
    # Debug logging
    debug_log "input=$input"
    debug_log "output=$output"
    debug_log "scale=$scale"
    debug_log "codec=$codec"
    debug_log "container=$container"
    debug_log "USE_LIBX264=$USE_LIBX264"
    
    # Build FFmpeg command based on codec
    case "$codec" in
        h264)
            if [ "$USE_LIBX264" = true ]; then
                # libx264 with advanced options
                debug_log "Running H.264 encode (libx264) - CRF=$crf PRESET=$preset TUNE=$tune"
                
                # Build tune option
                local tune_opt=""
                if [ ! -z "$tune" ]; then
                    tune_opt="-tune $tune"
                fi
                
                "$FFMPEG" \
                    -i "$input" \
                    -vf "scale=${scale}:-2" \
                    -pix_fmt yuv420p \
                    -c:v libx264 \
                    -crf "$crf" \
                    -preset "$preset" \
                    $tune_opt \
                    -c:a aac \
                    -b:a "$abitrate" \
                    -movflags +faststart \
                    -f "$container" \
                    -loglevel error \
                    -y \
                    "$output" 2>> "$LOGFILE"
            else
                # libopenh264 with basic options
                debug_log "Running H.264 encode (libopenh264) - VBITRATE=$vbitrate"
                "$FFMPEG" \
                    -i "$input" \
                    -vf "scale=${scale}:-2" \
                    -pix_fmt yuv420p \
                    -c:v libopenh264 \
                    -b:v "$vbitrate" \
                    -c:a aac \
                    -b:a "$abitrate" \
                    -movflags +faststart \
                    -f "$container" \
                    -loglevel error \
                    -y \
                    "$output" 2>> "$LOGFILE"
            fi
            ;;
        prores)
            local prores_profile="1"
            case "$codec_profile" in
                proxy)    prores_profile="0" ;;
                lt)       prores_profile="1" ;;
                standard) prores_profile="2" ;;
                hq)       prores_profile="3" ;;
            esac
            debug_log "Running ProRes encode with profile $prores_profile"
            "$FFMPEG" \
                -i "$input" \
                -vf "scale=${scale}:-2" \
                -c:v prores_ks \
                -profile:v "$prores_profile" \
                -c:a pcm_s16le \
                -ar 48000 \
                -f "$container" \
                -loglevel error \
                -y \
                "$output" 2>> "$LOGFILE"
            ;;
        dnxhd)
            local dnx_profile="dnxhr_sq"
            if [ ! -z "$codec_profile" ]; then
                dnx_profile="$codec_profile"
            fi
            debug_log "Running DNxHD encode with profile $dnx_profile"
            "$FFMPEG" \
                -i "$input" \
                -vf "scale=${scale}:-2" \
                -pix_fmt yuv422p \
                -c:v dnxhd \
                -profile:v "$dnx_profile" \
                -c:a pcm_s16le \
                -ar 48000 \
                -f "$container" \
                -loglevel error \
                -y \
                "$output" 2>> "$LOGFILE"
            ;;
        *)
            # Fallback to H.264
            debug_log "Running fallback H.264 encode (libopenh264)"
            "$FFMPEG" \
                -i "$input" \
                -vf "scale=${scale}:-2" \
                -pix_fmt yuv420p \
                -c:v libopenh264 \
                -b:v "$vbitrate" \
                -c:a aac \
                -b:a "$abitrate" \
                -movflags +faststart \
                -f "$container" \
                -loglevel error \
                -y \
                "$output" 2>> "$LOGFILE"
            ;;
    esac
    
    local result=$?
    if [ $result -ne 0 ]; then
        log "ERROR: FFmpeg failed with exit code $result"
        return 1
    fi
    
    log "Successfully created: $output"
    return 0
}

#------------------------------------------------------------
# Main
#------------------------------------------------------------

log "========================================"
log "Processing: $INPUT_FILE"

# Validate input
if [ -z "$INPUT_FILE" ]; then
    error_exit "No input file specified"
fi

if [ ! -f "$INPUT_FILE" ]; then
    error_exit "Input file not found: $INPUT_FILE"
fi

# Determine which qualities are needed
NEED_PREVIEW_QUALITY=false
NEED_WORKFLOW_QUALITY=false

if [ "$ENABLE_P5_PREVIEW" = "true" ] && [ "$P5_PREVIEW_SOURCE" = "preview" ]; then
    NEED_PREVIEW_QUALITY=true
fi
if [ "$ENABLE_WORKFLOW_STORE" = "true" ] && [ "$WORKFLOW_STORE_SOURCE" = "preview" ]; then
    NEED_PREVIEW_QUALITY=true
fi
if [ "$ENABLE_P5_PREVIEW" = "true" ] && [ "$P5_PREVIEW_SOURCE" = "workflow" ]; then
    NEED_WORKFLOW_QUALITY=true
fi
if [ "$ENABLE_WORKFLOW_STORE" = "true" ] && [ "$WORKFLOW_STORE_SOURCE" = "workflow" ]; then
    NEED_WORKFLOW_QUALITY=true
fi

debug_log "NEED_PREVIEW_QUALITY=$NEED_PREVIEW_QUALITY"
debug_log "NEED_WORKFLOW_QUALITY=$NEED_WORKFLOW_QUALITY"

# Variables for generated proxies
PREVIEW_PROXY_PATH=""
WORKFLOW_PROXY_PATH=""

# Generate preview quality proxy
if [ "$NEED_PREVIEW_QUALITY" = "true" ]; then
    FILENAME=$(basename "$INPUT_FILE")
    BASENAME="${FILENAME%.*}"
    PREVIEW_CONTAINER_EXT=$(get_container "$PREVIEW_CODEC" "$PREVIEW_CONTAINER")
    PREVIEW_PROXY_PATH="$AW_TEMP/${BASENAME}_preview.${PREVIEW_CONTAINER_EXT}"
    
    generate_proxy "$INPUT_FILE" "$PREVIEW_PROXY_PATH" \
        "$PREVIEW_SCALE" "$PREVIEW_VBITRATE" "$PREVIEW_ABITRATE" \
        "preview_quality" "$PREVIEW_CODEC" "$PREVIEW_CODEC_PROFILE" \
        "$PREVIEW_CRF" "$PREVIEW_PRESET" "$PREVIEW_TUNE"
    
    if [ $? -ne 0 ]; then
        error_exit "Failed to generate preview quality proxy"
    fi
fi

# Generate workflow quality proxy
if [ "$NEED_WORKFLOW_QUALITY" = "true" ]; then
    FILENAME=$(basename "$INPUT_FILE")
    BASENAME="${FILENAME%.*}"
    WORKFLOW_CONTAINER_EXT=$(get_container "$WORKFLOW_CODEC" "$WORKFLOW_CONTAINER")
    WORKFLOW_PROXY_PATH="$AW_TEMP/${BASENAME}_workflow.${WORKFLOW_CONTAINER_EXT}"
    
    generate_proxy "$INPUT_FILE" "$WORKFLOW_PROXY_PATH" \
        "$WORKFLOW_SCALE" "$WORKFLOW_VBITRATE" "$WORKFLOW_ABITRATE" \
        "workflow_quality" "$WORKFLOW_CODEC" "$WORKFLOW_CODEC_PROFILE" \
        "$WORKFLOW_CRF" "$WORKFLOW_PRESET" "$WORKFLOW_TUNE"
    
    if [ $? -ne 0 ]; then
        error_exit "Failed to generate workflow quality proxy"
    fi
fi

# Store proxy in workflow location
if [ "$ENABLE_WORKFLOW_STORE" = "true" ]; then
    if [ "$WORKFLOW_STORE_SOURCE" = "preview" ]; then
        SOURCE_PATH="$PREVIEW_PROXY_PATH"
        CONTAINER_EXT=$(get_container "$PREVIEW_CODEC" "$PREVIEW_CONTAINER")
    else
        SOURCE_PATH="$WORKFLOW_PROXY_PATH"
        CONTAINER_EXT=$(get_container "$WORKFLOW_CODEC" "$WORKFLOW_CONTAINER")
    fi
    
    WORKFLOW_DEST=$(build_workflow_path "$INPUT_FILE" "$CONTAINER_EXT")
    WORKFLOW_DIR=$(dirname "$WORKFLOW_DEST")
    mkdir -p "$WORKFLOW_DIR"
    cp "$SOURCE_PATH" "$WORKFLOW_DEST"
    log "Stored proxy in workflow location: $WORKFLOW_DEST"
fi

# Determine return value for P5
RETURN_PATH=""
if [ "$ENABLE_P5_PREVIEW" = "true" ]; then
    if [ "$P5_PREVIEW_SOURCE" = "preview" ]; then
        RETURN_PATH="$PREVIEW_PROXY_PATH"
    else
        RETURN_PATH="$WORKFLOW_PROXY_PATH"
    fi
else
    # Generate dummy image for P5
    DUMMY_FILE="$AW_TEMP/proxy_dummy_$$.jpg"
    "$FFMPEG" -hide_banner -loglevel error \
        -f lavfi -i "color=c=gray:s=64x64:d=1" \
        -frames:v 1 \
        -y "$DUMMY_FILE" 2>/dev/null
    RETURN_PATH="$DUMMY_FILE"
    log "P5 preview disabled, returning dummy image"
fi

# Validate return path exists
if [ -z "$RETURN_PATH" ] || [ ! -f "$RETURN_PATH" ]; then
    error_exit "Return path invalid or file missing: $RETURN_PATH"
fi

# Cleanup: Remove temp files not returned to P5 (P5 moves the returned file)
if [ -f "$PREVIEW_PROXY_PATH" ] && [ "$RETURN_PATH" != "$PREVIEW_PROXY_PATH" ]; then
    rm -f "$PREVIEW_PROXY_PATH"
    debug_log "Cleaned up temp file: $PREVIEW_PROXY_PATH"
fi

if [ -f "$WORKFLOW_PROXY_PATH" ] && [ "$RETURN_PATH" != "$WORKFLOW_PROXY_PATH" ]; then
    rm -f "$WORKFLOW_PROXY_PATH"
    debug_log "Cleaned up temp file: $WORKFLOW_PROXY_PATH"
fi

log "Returning to P5: $RETURN_PATH"
log "========================================"

# Output path to P5
echo "$RETURN_PATH"
