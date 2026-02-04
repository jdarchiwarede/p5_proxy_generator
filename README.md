# P5 Proxy Generator

A cross-platform proxy generation script for [P5 Archive](https://www.archiware.com/) that creates video proxies for both P5 browser previews and editing workflows during the archiving process.

## Features

- **Cross-platform:** Works on Windows, macOS, and Linux
- **Dual-output generation:** Create P5 browser previews and high-quality workflow proxies simultaneously
- **Flexible path mapping:** Automatically organize proxy files in your existing project structure
- **Single-encode optimization:** When the same quality works for both purposes, only one encoding pass is needed
- **Custom FFmpeg support:** Use your own FFmpeg installation for advanced encoding options (libx264 with CRF, presets, tune)
- **Automatic cleanup:** Temp files are removed after processing to prevent disk space issues

## Requirements

- P5 Archive 7.x or later
- Python 3.7 or later
- P5's built-in FFmpeg (included with P5) or custom FFmpeg installation

### Python Installation

**Windows:**
Download from [python.org](https://www.python.org/downloads/) and install. Make sure to check "Add Python to PATH" during installation.

**macOS:**
```bash
brew install python
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt install python3
```

### Optional: Custom FFmpeg

For advanced encoding options (CRF, presets, tune), install FFmpeg with libx264 support:

```bash
# macOS with Homebrew
brew install ffmpeg

# Linux (Ubuntu/Debian)
sudo apt install ffmpeg

# Windows
# Download from https://ffmpeg.org/download.html
```

## Installation

### Step 1: Create scripts directory

**macOS/Linux:**
```bash
sudo mkdir -p /usr/local/aw/scripts
```

**Windows:**
The directory already exists at `C:\Program Files\ARCHIWARE\Data_Lifecycle_Management_Suite\scripts`

### Step 2: Copy the scripts

Copy both `aw_platform.py` and `p5_proxy_generator.py` to the scripts directory:

**macOS/Linux:**
```bash
sudo cp aw_platform.py p5_proxy_generator.py /usr/local/aw/scripts/
```

**Windows:**
Copy files to `C:\Program Files\ARCHIWARE\Data_Lifecycle_Management_Suite\scripts\`

### Step 3: Configure P5 Archive Plan

1. Open your Archive Plan in the P5 Browser
2. Navigate to the **Previews** section
3. Set the preview converter script to: `python scripts/p5_proxy_generator.py`
4. Add file extensions (e.g., `.mov`, `.mp4`, `.mxf`, `.avi`)

### Step 4: Configure the script

Edit `p5_proxy_generator.py` to match your requirements. On Windows, use a text editor like Notepad++ or VS Code.

## Configuration

### Basic Settings

```python
# P5 Preview Settings
ENABLE_P5_PREVIEW = True              # Return a preview to P5 (False = dummy image)
P5_PREVIEW_SOURCE = "preview"         # "preview" | "workflow" (which quality to use)

# Workflow Proxy Settings
ENABLE_WORKFLOW_STORE = True          # Store a proxy in workflow location
WORKFLOW_STORE_SOURCE = "workflow"    # "preview" | "workflow" (which quality to use)
```

### FFmpeg Configuration

```python
# Leave empty for P5's built-in FFmpeg, or specify path to custom FFmpeg
FFMPEG_PATH = ""

# Windows example (note the r prefix for raw string):
FFMPEG_PATH = r"C:\ffmpeg\bin\ffmpeg.exe"

# macOS/Linux example:
FFMPEG_PATH = "/usr/local/bin/ffmpeg"
```

### Quality Settings

**Preview (speed optimized for P5 browser):**

```python
PREVIEW_SCALE = "320"                 # Width in pixels
PREVIEW_CODEC = "h264"                # h264 | prores | dnxhd

# P5 built-in FFmpeg:
PREVIEW_VBITRATE = "256k"

# Custom FFmpeg (libx264):
PREVIEW_CRF = "28"                    # Higher = smaller (18-32)
PREVIEW_PRESET = "veryfast"           # ultrafast|veryfast|fast|medium
PREVIEW_TUNE = "fastdecode"           # fastdecode|zerolatency|film
```

**Workflow (quality optimized for editing):**

```python
WORKFLOW_SCALE = "1920"               # Width in pixels
WORKFLOW_CODEC = "h264"               # h264 | prores | dnxhd

# P5 built-in FFmpeg:
WORKFLOW_VBITRATE = "5000k"

# Custom FFmpeg (libx264):
WORKFLOW_CRF = "18"                   # Lower = better (16-23)
WORKFLOW_PRESET = "medium"            # fast|medium|slow|veryslow
WORKFLOW_TUNE = ""                    # film|animation
```

### Path Mapping

Configure where workflow proxies are stored using three independent operations:

```python
WORKFLOW_PROJECT_FOLDER = ""          # Step 1: Marker folder (empty = skip)
WORKFLOW_NEW_BASE = ""                # Step 1: New base path
WORKFLOW_REMOVE_LEVELS = 1            # Step 2: Directories to remove (0 = skip)
WORKFLOW_REPLACE_WITH = "proxies"     # Step 3: Path to append (empty = skip)
```

> **Windows Note:** Use raw strings (prefix with `r`) for paths with backslashes:
> ```python
> WORKFLOW_NEW_BASE = r"X:\projects"
> ```
> Or use forward slashes which also work on Windows:
> ```python
> WORKFLOW_NEW_BASE = "X:/projects"
> ```

**Example 1: Different storage for proxies**

Source: `/Volumes/RAW_Storage/Projects/2024/BMW_Commercial/Footage/A-Cam/A001C003.mov`

```python
WORKFLOW_PROJECT_FOLDER = "Projects"
WORKFLOW_NEW_BASE = "/Volumes/Proxy_Storage"  # Windows: r"X:\Proxy_Storage"
WORKFLOW_REMOVE_LEVELS = 1
WORKFLOW_REPLACE_WITH = "Proxies"
```

Result: `/Volumes/Proxy_Storage/Projects/2024/BMW_Commercial/Footage/Proxies/A001C003.mp4`

**Example 2: Proxies next to source footage**

Source: `/Volumes/Production/2024/Documentary/Camera_Raw/Day01/B001.mov`

```python
WORKFLOW_PROJECT_FOLDER = ""
WORKFLOW_NEW_BASE = ""
WORKFLOW_REMOVE_LEVELS = 1
WORKFLOW_REPLACE_WITH = "Proxies"
```

Result: `/Volumes/Production/2024/Documentary/Camera_Raw/Proxies/B001.mp4`

## Use Cases

### 1. P5 Preview Only (Default)

```python
ENABLE_P5_PREVIEW = True
P5_PREVIEW_SOURCE = "preview"
ENABLE_WORKFLOW_STORE = False
```

### 2. Workflow Proxies Only

```python
ENABLE_P5_PREVIEW = False
ENABLE_WORKFLOW_STORE = True
WORKFLOW_STORE_SOURCE = "workflow"
```

### 3. Single Proxy for Both

```python
ENABLE_P5_PREVIEW = True
P5_PREVIEW_SOURCE = "workflow"
ENABLE_WORKFLOW_STORE = True
WORKFLOW_STORE_SOURCE = "workflow"
```

### 4. Separate Qualities

```python
ENABLE_P5_PREVIEW = True
P5_PREVIEW_SOURCE = "preview"
ENABLE_WORKFLOW_STORE = True
WORKFLOW_STORE_SOURCE = "workflow"
```

## Troubleshooting

### Enable Debug Mode

Edit `aw_platform.py` and set:
```python
DEBUG_MODE = True
```

Or add at the top of `p5_proxy_generator.py` after the import:
```python
aw.DEBUG_MODE = True
```

### Check Log File

**macOS/Linux:**
```bash
cat /usr/local/aw/temp/proxy_generator.log
```

**Windows:**
```
C:\Program Files\ARCHIWARE\Data_Lifecycle_Management_Suite\temp\proxy_generator.log
```

### Common Issues

| Issue | Solution |
|-------|----------|
| "FFmpeg not found" | Check P5 installation or FFMPEG_PATH setting |
| "libx264 not available" | Install FFmpeg with libx264 support or leave FFMPEG_PATH empty |
| "Cannot create directory" | Check write permissions on target path |
| Proxies not appearing | Check file extensions in P5 Archive Plan |
| "invalid escape sequence" | Use `r"..."` for Windows paths with backslashes |
| Script works manually but not in P5 | Restart P5 server to clear Python cache |

### Manual Testing

Test the script from command line to verify it works:

**macOS/Linux:**
```bash
cd /usr/local/aw
python3 scripts/p5_proxy_generator.py "/path/to/test/video.mp4"
```

**Windows:**
```cmd
cd "C:\Program Files\ARCHIWARE\Data_Lifecycle_Management_Suite"
python scripts\p5_proxy_generator.py "X:\path\to\test\video.mp4"
```

## File Structure

```
scripts/
├── aw_platform.py         # Platform detection and logging (do not modify)
└── p5_proxy_generator.py  # Main script with configuration
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This script is provided "as is" without warranty of any kind, express or implied. Archiware makes no guarantees regarding functionality, completeness, or fitness for a particular purpose. Use at your own risk.

As this script relies on external components such as FFmpeg and Python, and its scope falls outside our software and responsibility, we are unable to provide technical support for its use.

We recommend thoroughly testing the script in a test environment before production use.

## Contributing

We welcome feedback and suggestions for improvement! Please open an issue or submit a pull request.

## Links

- [Archiware Website](https://www.archiware.com/)
- [P5 Archive Documentation](https://www.archiware.com/support)
- [Blog Post: Automating Proxy Generation](https://blog.archiware.com/)
