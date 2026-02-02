# P5 Proxy Generator

A flexible proxy generation script for [P5 Archive](https://www.archiware.com/) that creates video proxies for both P5 browser previews and editing workflows during the archiving process.

## Features

- **Dual-output generation:** Create P5 browser previews and high-quality workflow proxies simultaneously
- **Flexible path mapping:** Automatically organize proxy files in your existing project structure
- **Single-encode optimization:** When the same quality works for both purposes, only one encoding pass is needed
- **Custom FFmpeg support:** Use your own FFmpeg installation for advanced encoding options (libx264 with CRF, presets, tune)
- **Automatic cleanup:** Temp files are removed after processing to prevent disk space issues

## Requirements

- P5 Archive (tested with P5 version 7.x)
- P5's built-in FFmpeg (included with P5) or custom FFmpeg installation
- macOS or Linux

### Optional: Custom FFmpeg

For advanced encoding options (CRF, presets, tune), install FFmpeg with libx264 support:

```bash
# macOS with Homebrew
brew install ffmpeg

# Linux (Ubuntu/Debian)
sudo apt install ffmpeg
```

## Installation

### Step 1: Create scripts directory

```bash
sudo mkdir -p /usr/local/aw/scripts
```

### Step 2: Copy the script

```bash
sudo cp p5_proxy_generator.sh /usr/local/aw/scripts/
```

### Step 3: Make executable

```bash
sudo chmod +x /usr/local/aw/scripts/p5_proxy_generator.sh
```

### Step 4: Configure P5 Archive Plan

1. Open your Archive Plan in the P5 Browser
2. Navigate to the **Previews** section
3. Set the preview converter script to: `scripts/p5_proxy_generator.sh`
4. Add file extensions (e.g., `.mov`, `.mp4`, `.mxf`, `.avi`)

### Step 5: Configure the script

Edit the script header to match your requirements:

```bash
sudo nano /usr/local/aw/scripts/p5_proxy_generator.sh
```

## Configuration

### Basic Settings

```bash
# P5 Preview Settings
ENABLE_P5_PREVIEW=true              # Return a preview to P5 (false = dummy image)
P5_PREVIEW_SOURCE="preview"         # preview | workflow (which quality to use)

# Workflow Proxy Settings
ENABLE_WORKFLOW_STORE=true          # Store a proxy in workflow location
WORKFLOW_STORE_SOURCE="workflow"    # preview | workflow (which quality to use)

# Debug mode
DEBUG_MODE=false                    # Set to true for troubleshooting
```

### FFmpeg Configuration

```bash
# Leave empty for P5's built-in FFmpeg, or specify path to custom FFmpeg
FFMPEG_PATH=""                      # Example: /usr/local/bin/ffmpeg
```

### Quality Settings

**Preview (speed optimized for P5 browser):**

```bash
PREVIEW_SCALE="320"                 # Width in pixels
PREVIEW_CODEC="h264"                # h264 | prores | dnxhd

# P5 built-in FFmpeg:
PREVIEW_VBITRATE="256k"

# Custom FFmpeg (libx264):
PREVIEW_CRF="28"                    # Higher = smaller (18-32)
PREVIEW_PRESET="veryfast"           # ultrafast|veryfast|fast|medium
PREVIEW_TUNE="fastdecode"           # fastdecode|zerolatency|film
```

**Workflow (quality optimized for editing):**

```bash
WORKFLOW_SCALE="1920"               # Width in pixels
WORKFLOW_CODEC="h264"               # h264 | prores | dnxhd

# P5 built-in FFmpeg:
WORKFLOW_VBITRATE="5000k"

# Custom FFmpeg (libx264):
WORKFLOW_CRF="18"                   # Lower = better (16-23)
WORKFLOW_PRESET="medium"            # fast|medium|slow|veryslow
WORKFLOW_TUNE=""                    # film|animation
```

### Path Mapping

Configure where workflow proxies are stored using three independent operations:

```bash
WORKFLOW_PROJECT_FOLDER=""          # Step 1: Marker folder (empty = skip)
WORKFLOW_NEW_BASE=""                # Step 1: New base path
WORKFLOW_REMOVE_LEVELS=1            # Step 2: Directories to remove (0 = skip)
WORKFLOW_REPLACE_WITH="proxies"     # Step 3: Path to append (empty = skip)
```

**Example 1: Different storage for proxies**

Source: `/Volumes/RAW_Storage/Projects/2024/BMW_Commercial/Footage/A-Cam/A001C003.mov`

```bash
WORKFLOW_PROJECT_FOLDER="Projects"
WORKFLOW_NEW_BASE="/Volumes/Proxy_Storage"
WORKFLOW_REMOVE_LEVELS=1
WORKFLOW_REPLACE_WITH="Proxies"
```

Result: `/Volumes/Proxy_Storage/Projects/2024/BMW_Commercial/Footage/Proxies/A001C003.mp4`

**Example 2: Proxies next to source footage**

Source: `/Volumes/Production/2024/Documentary/Camera_Raw/Day01/B001.mov`

```bash
WORKFLOW_PROJECT_FOLDER=""
WORKFLOW_NEW_BASE=""
WORKFLOW_REMOVE_LEVELS=1
WORKFLOW_REPLACE_WITH="Proxies"
```

Result: `/Volumes/Production/2024/Documentary/Camera_Raw/Proxies/B001.mp4`

## Use Cases

### 1. P5 Preview Only (Default)

```bash
ENABLE_P5_PREVIEW=true
P5_PREVIEW_SOURCE="preview"
ENABLE_WORKFLOW_STORE=false
```

### 2. Workflow Proxies Only

```bash
ENABLE_P5_PREVIEW=false
ENABLE_WORKFLOW_STORE=true
WORKFLOW_STORE_SOURCE="workflow"
```

### 3. Single Proxy for Both

```bash
ENABLE_P5_PREVIEW=true
P5_PREVIEW_SOURCE="workflow"
ENABLE_WORKFLOW_STORE=true
WORKFLOW_STORE_SOURCE="workflow"
```

### 4. Separate Qualities

```bash
ENABLE_P5_PREVIEW=true
P5_PREVIEW_SOURCE="preview"
ENABLE_WORKFLOW_STORE=true
WORKFLOW_STORE_SOURCE="workflow"
```

## Troubleshooting

### Enable Debug Mode

```bash
DEBUG_MODE=true
```

### Check Log File

```bash
cat /usr/local/aw/log/proxy_generator.log
```

### Common Issues

| Issue | Solution |
|-------|----------|
| "FFmpeg not found" | Check P5 installation or FFMPEG_PATH |
| "libx264 not available" | Install FFmpeg with libx264 support or leave FFMPEG_PATH empty |
| "Cannot create directory" | Check write permissions on target path |
| Proxies not appearing | Check file extensions in P5 Archive Plan |

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This script is provided "as is" without warranty of any kind, express or implied. Archiware makes no guarantees regarding functionality, completeness, or fitness for a particular purpose. Use at your own risk.

As this script relies on external components such as FFmpeg and its scope falls outside our software and responsibility, we are unable to provide technical support for its use.

We recommend thoroughly testing the script in a test environment before production use.

## Contributing

We welcome feedback and suggestions for improvement! Please open an issue or submit a pull request.

## Links

- [Archiware Website](https://www.archiware.com/)
- [P5 Archive Documentation](https://www.archiware.com/support)
- [Blog Post: Automating Proxy Generation](https://blog.archiware.com/)
