#!/usr/bin/env python3
"""
P5 Proxy Generator

Generates proxy files for P5 Archive during the archiving process.
Can create both P5 browser previews and high-quality workflow proxies.

Features:
    - Dual-output: P5 preview + workflow proxy simultaneously
    - Flexible path mapping for workflow proxies
    - Single-encode optimization when same quality serves both purposes
    - Custom FFmpeg support with libx264 for better quality control

Usage in P5:
    Archive Plan -> Previews -> Script: scripts/p5_proxy_generator.py

Requirements:
    - Python 3.7+
    - P5 Archive 7.x or later
    - FFmpeg (included with P5, or custom installation)

Author: Archiware GmbH
License: MIT
"""

import os
import sys
import re
import shutil
import subprocess
from pathlib import Path

import aw_platform as aw

#============================================================
# CONFIGURATION
# Adjust these values to match your requirements
#============================================================

#------------------------------------------------------------
# Output Selection
#------------------------------------------------------------

# P5 Preview: Small proxy for browsing in P5 web interface
ENABLE_P5_PREVIEW = True            # Set False to skip P5 preview
P5_PREVIEW_SOURCE = "preview"       # "preview" = small, "workflow" = use workflow quality

# Workflow Proxy: Higher quality for editing in NLE systems
ENABLE_WORKFLOW_STORE = True        # Set False to skip workflow proxy
WORKFLOW_STORE_SOURCE = "workflow"  # "workflow" = high quality, "preview" = use preview quality

#------------------------------------------------------------
# FFmpeg Configuration
#------------------------------------------------------------

# Leave empty to use P5's built-in FFmpeg (libopenh264)
# Or specify path to custom FFmpeg with libx264 for better quality
# Windows example: r"C:\ffmpeg\bin\ffmpeg.exe"
# macOS example: "/usr/local/bin/ffmpeg"
FFMPEG_PATH = ""

#------------------------------------------------------------
# Workflow Path Mapping
#------------------------------------------------------------
# Defines where workflow proxies are stored.
# Three independent operations applied in order:
#
# Step 1: Replace base path (optional)
#   WORKFLOW_PROJECT_FOLDER = marker folder to find in path
#   WORKFLOW_NEW_BASE = new base path (replaces everything before marker)
#
# Step 2: Remove directory levels
#   WORKFLOW_REMOVE_LEVELS = number of directories to remove from end
#
# Step 3: Append path
#   WORKFLOW_REPLACE_WITH = folder name to append
#
# Example:
#   Source: /Volumes/RAW/Projects/2024/BMW/Footage/A-Cam/A001.mov
#   Settings: PROJECT_FOLDER="Projects", NEW_BASE="/Volumes/Proxies",
#             REMOVE_LEVELS=1, REPLACE_WITH="Proxies"
#   Result: /Volumes/Proxies/Projects/2024/BMW/Footage/Proxies/A001.mp4

WORKFLOW_PROJECT_FOLDER = ""        # Marker folder (empty = skip step 1)
WORKFLOW_NEW_BASE = ""              # New base path, use r"X:\path" on Windows
WORKFLOW_REMOVE_LEVELS = 1          # Directories to remove (0 = skip)
WORKFLOW_REPLACE_WITH = "proxies"   # Folder to append (empty = skip)

#------------------------------------------------------------
# Preview Quality (P5 Browser - Speed Optimized)
#------------------------------------------------------------

PREVIEW_SCALE = "320"               # Width in pixels (height auto)
PREVIEW_ABITRATE = "64k"            # Audio bitrate
PREVIEW_CODEC = "h264"              # h264 | prores | dnxhd
PREVIEW_CODEC_PROFILE = ""          # Codec profile (for prores/dnxhd)
PREVIEW_CONTAINER = ""              # Container format (empty = auto)

# P5 built-in FFmpeg (libopenh264):
PREVIEW_VBITRATE = "256k"           # Video bitrate

# Custom FFmpeg (libx264) - used when FFMPEG_PATH is set:
PREVIEW_CRF = "28"                  # Quality: higher = smaller (18-32)
PREVIEW_PRESET = "veryfast"         # Speed: ultrafast|veryfast|fast|medium
PREVIEW_TUNE = "fastdecode"         # Optimization: fastdecode|zerolatency|film

#------------------------------------------------------------
# Workflow Quality (Editing - Quality Optimized)
#------------------------------------------------------------

WORKFLOW_SCALE = "1920"             # Width in pixels (height auto)
WORKFLOW_ABITRATE = "128k"          # Audio bitrate
WORKFLOW_CODEC = "h264"             # h264 | prores | dnxhd
WORKFLOW_CODEC_PROFILE = ""         # Codec profile (for prores/dnxhd)
WORKFLOW_CONTAINER = ""             # Container format (empty = auto)

# P5 built-in FFmpeg (libopenh264):
WORKFLOW_VBITRATE = "5000k"         # Video bitrate

# Custom FFmpeg (libx264) - used when FFMPEG_PATH is set:
WORKFLOW_CRF = "18"                 # Quality: lower = better (16-23)
WORKFLOW_PRESET = "medium"          # Speed: fast|medium|slow|veryslow
WORKFLOW_TUNE = ""                  # Optimization: film|animation (empty = none)

#============================================================
# IMPLEMENTATION
# Do not modify below unless you know what you're doing
#============================================================

# Initialize logging
aw.set_logfile("proxy_generator.log")

# FFmpeg globals (set by init_ffmpeg)
FFMPEG = None
USE_LIBX264 = False


def init_ffmpeg():
    """
    Initialize FFmpeg path and detect libx264 support.
    
    If FFMPEG_PATH is set and valid, checks for libx264 encoder.
    Falls back to P5 built-in FFmpeg if custom path is invalid.
    """
    global FFMPEG, USE_LIBX264
    
    ffmpeg_exe = 'ffmpeg.exe' if sys.platform == 'win32' else 'ffmpeg'
    builtin = os.path.join(aw.AW_BIN, ffmpeg_exe)
    
    # Try custom FFmpeg if specified
    if FFMPEG_PATH and os.path.isfile(FFMPEG_PATH):
        try:
            result = subprocess.run([FFMPEG_PATH, '-encoders'], 
                                    capture_output=True, text=True)
            if 'libx264' in result.stdout:
                FFMPEG = FFMPEG_PATH
                USE_LIBX264 = True
                aw.log(f"Using custom FFmpeg with libx264: {FFMPEG}")
                return
        except:
            pass
        aw.log("WARNING: Custom FFmpeg invalid, using P5 built-in")
    
    # Use P5 built-in FFmpeg
    FFMPEG = builtin
    USE_LIBX264 = False


def get_container(codec, custom=""):
    """
    Get container format for codec.
    
    Args:
        codec: Video codec (h264, prores, dnxhd)
        custom: Custom container override
        
    Returns:
        Container format string (mp4, mov, mxf)
    """
    if custom:
        return custom
    return {"h264": "mp4", "prores": "mov", "dnxhd": "mxf"}.get(codec, "mp4")


def build_workflow_path(src_file, container):
    """
    Build destination path for workflow proxy using path mapping rules.
    
    Applies three operations:
    1. Replace base path if WORKFLOW_PROJECT_FOLDER is found
    2. Remove WORKFLOW_REMOVE_LEVELS directories from end
    3. Append WORKFLOW_REPLACE_WITH folder
    
    Args:
        src_file: Source video file path
        container: Output container format
        
    Returns:
        Full path for workflow proxy file
    """
    src_dir = os.path.dirname(src_file)
    src_basename = Path(src_file).stem
    original_dir = src_dir
    
    # Step 1: Replace base path if configured
    if WORKFLOW_PROJECT_FOLDER and WORKFLOW_NEW_BASE:
        # Match marker folder with path separator on both sides
        pattern = re.compile(rf"[/\\]{re.escape(WORKFLOW_PROJECT_FOLDER)}[/\\]")
        match = pattern.search(src_dir)
        
        if match:
            # Marker found in middle of path
            after_marker = src_dir[match.end():]
            src_dir = os.path.join(WORKFLOW_NEW_BASE, WORKFLOW_PROJECT_FOLDER, after_marker)
        elif src_dir.endswith(os.sep + WORKFLOW_PROJECT_FOLDER):
            # Marker is at end of path
            src_dir = os.path.join(WORKFLOW_NEW_BASE, WORKFLOW_PROJECT_FOLDER)
        else:
            aw.log(f"WARNING: Project folder '{WORKFLOW_PROJECT_FOLDER}' not found")
    
    # Step 2: Remove directory levels from end
    target_dir = src_dir
    for _ in range(WORKFLOW_REMOVE_LEVELS):
        target_dir = os.path.dirname(target_dir)
    
    # Step 3: Append replacement folder
    if WORKFLOW_REPLACE_WITH:
        target_dir = os.path.join(target_dir, WORKFLOW_REPLACE_WITH)
    
    # Add _proxy suffix only if output is in same directory as source
    output_basename = src_basename
    if os.path.normpath(target_dir) == os.path.normpath(original_dir):
        output_basename = f"{src_basename}_proxy"
    
    return os.path.join(target_dir, f"{output_basename}.{container}")


def generate_proxy(input_file, output_file, scale, vbitrate, abitrate, 
                   proxy_type, codec, codec_profile, container, crf, preset, tune):
    """
    Generate a proxy video file using FFmpeg.
    
    Args:
        input_file: Source video path
        output_file: Destination proxy path
        scale: Output width in pixels
        vbitrate: Video bitrate (for libopenh264)
        abitrate: Audio bitrate
        proxy_type: Description for logging
        codec: Video codec (h264, prores, dnxhd)
        codec_profile: Codec-specific profile
        container: Output container format
        crf: Constant Rate Factor (for libx264)
        preset: Encoding preset (for libx264)
        tune: Encoding tune option (for libx264)
        
    Returns:
        True on success, False on failure
    """
    # Create output directory
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    aw.log(f"Generating {proxy_type} ({codec}): {output_file}")
    
    # Build FFmpeg command
    cmd = [FFMPEG, "-i", input_file]
    
    if codec == "h264":
        cmd += ["-vf", f"scale={scale}:-2", "-pix_fmt", "yuv420p"]
        if USE_LIBX264:
            # libx264 with quality settings
            cmd += ["-c:v", "libx264", "-crf", crf, "-preset", preset]
            if tune:
                cmd += ["-tune", tune]
        else:
            # libopenh264 with bitrate
            cmd += ["-c:v", "libopenh264", "-b:v", vbitrate]
        cmd += ["-c:a", "aac", "-b:a", abitrate, "-movflags", "+faststart"]
    
    elif codec == "prores":
        # ProRes profiles: 0=proxy, 1=lt, 2=standard, 3=hq
        profile = {"proxy": "0", "lt": "1", "standard": "2", "hq": "3"}.get(codec_profile, "1")
        cmd += ["-vf", f"scale={scale}:-2", "-c:v", "prores_ks", "-profile:v", profile,
                "-c:a", "pcm_s16le", "-ar", "48000"]
    
    elif codec == "dnxhd":
        # DNxHR profiles: dnxhr_lb, dnxhr_sq, dnxhr_hq, dnxhr_hqx, dnxhr_444
        profile = codec_profile or "dnxhr_sq"
        cmd += ["-vf", f"scale={scale}:-2", "-pix_fmt", "yuv422p",
                "-c:v", "dnxhd", "-profile:v", profile,
                "-c:a", "pcm_s16le", "-ar", "48000"]
    
    else:
        # Fallback to H.264 with libopenh264
        cmd += ["-vf", f"scale={scale}:-2", "-pix_fmt", "yuv420p",
                "-c:v", "libopenh264", "-b:v", vbitrate,
                "-c:a", "aac", "-b:a", abitrate, "-movflags", "+faststart"]
    
    cmd += ["-f", container, "-loglevel", "error", "-y", output_file]
    
    # Execute FFmpeg
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stderr:
        aw.log(result.stderr)
    
    if result.returncode != 0:
        aw.log(f"ERROR: FFmpeg failed with exit code {result.returncode}")
        return False
    
    aw.log(f"Successfully created: {output_file}")
    return True


def main():
    """Main entry point."""
    
    # Validate input
    if len(sys.argv) < 2:
        aw.error_exit("No input file specified")
    
    input_file = sys.argv[1]
    init_ffmpeg()
    
    aw.log("========================================")
    aw.log(f"Processing: {input_file}")
    
    if not os.path.isfile(input_file):
        aw.error_exit(f"Input file not found: {input_file}")
    
    # Determine which qualities are needed
    need_preview = (ENABLE_P5_PREVIEW and P5_PREVIEW_SOURCE == "preview") or \
                   (ENABLE_WORKFLOW_STORE and WORKFLOW_STORE_SOURCE == "preview")
    need_workflow = (ENABLE_P5_PREVIEW and P5_PREVIEW_SOURCE == "workflow") or \
                    (ENABLE_WORKFLOW_STORE and WORKFLOW_STORE_SOURCE == "workflow")
    
    basename = Path(input_file).stem
    preview_proxy_path = ""
    workflow_proxy_path = ""
    
    # Generate preview quality proxy
    if need_preview:
        ext = get_container(PREVIEW_CODEC, PREVIEW_CONTAINER)
        preview_proxy_path = os.path.join(aw.AW_TEMP, f"{basename}_preview.{ext}")
        if not generate_proxy(input_file, preview_proxy_path, 
                              PREVIEW_SCALE, PREVIEW_VBITRATE, PREVIEW_ABITRATE,
                              "preview_quality", PREVIEW_CODEC, PREVIEW_CODEC_PROFILE, 
                              ext, PREVIEW_CRF, PREVIEW_PRESET, PREVIEW_TUNE):
            aw.error_exit("Failed to generate preview quality proxy")
    
    # Generate workflow quality proxy
    if need_workflow:
        ext = get_container(WORKFLOW_CODEC, WORKFLOW_CONTAINER)
        workflow_proxy_path = os.path.join(aw.AW_TEMP, f"{basename}_workflow.{ext}")
        if not generate_proxy(input_file, workflow_proxy_path,
                              WORKFLOW_SCALE, WORKFLOW_VBITRATE, WORKFLOW_ABITRATE,
                              "workflow_quality", WORKFLOW_CODEC, WORKFLOW_CODEC_PROFILE,
                              ext, WORKFLOW_CRF, WORKFLOW_PRESET, WORKFLOW_TUNE):
            aw.error_exit("Failed to generate workflow quality proxy")
    
    # Copy workflow proxy to destination
    if ENABLE_WORKFLOW_STORE:
        source_path = preview_proxy_path if WORKFLOW_STORE_SOURCE == "preview" else workflow_proxy_path
        ext = get_container(PREVIEW_CODEC if WORKFLOW_STORE_SOURCE == "preview" else WORKFLOW_CODEC,
                           PREVIEW_CONTAINER if WORKFLOW_STORE_SOURCE == "preview" else WORKFLOW_CONTAINER)
        workflow_dest = build_workflow_path(input_file, ext)
        os.makedirs(os.path.dirname(workflow_dest), exist_ok=True)
        shutil.copy2(source_path, workflow_dest)
        aw.log(f"Stored workflow proxy: {workflow_dest}")
    
    # Determine which file to return to P5
    if ENABLE_P5_PREVIEW:
        return_path = preview_proxy_path if P5_PREVIEW_SOURCE == "preview" else workflow_proxy_path
    else:
        # Generate dummy image when P5 preview is disabled
        return_path = os.path.join(aw.AW_TEMP, f"proxy_dummy_{os.getpid()}.jpg")
        subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "error", "-f", "lavfi", 
                       "-i", "color=c=gray:s=64x64:d=1", "-frames:v", "1", "-y", return_path], 
                       capture_output=True)
        aw.log("P5 preview disabled, returning dummy image")
    
    # Verify return file exists
    if not return_path or not os.path.isfile(return_path):
        aw.error_exit(f"Return path invalid: {return_path}")
    
    # Cleanup temp files not returned to P5
    for path in [preview_proxy_path, workflow_proxy_path]:
        if path and os.path.isfile(path) and path != return_path:
            os.remove(path)
    
    aw.log(f"Returning to P5: {return_path}")
    aw.log("========================================")
    
    # Output path to P5 (this is how P5 receives the result)
    print(return_path)


if __name__ == "__main__":
    main()
