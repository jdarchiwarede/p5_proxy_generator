#!/usr/bin/env python3
"""
Archiware Platform Module

Shared module for P5 scripts providing platform-independent paths and logging.

This module handles the differences between platforms:
- Windows: C:\\Program Files\\ARCHIWARE\\Data_Lifecycle_Management_Suite
- macOS/Linux: /usr/local/aw

It also handles P5's Unix-style path format in AWPST_SRV_HOME environment variable
(e.g., /C/Program Files/... on Windows).

Usage:
    import aw_platform as aw
    
    aw.set_logfile("my_script.log")
    aw.log("Processing started")
    aw.debug_log("Verbose info")  # Only logs if DEBUG_MODE = True
    
    # Access paths
    print(aw.AW_PATH)   # P5 installation directory
    print(aw.AW_TEMP)   # Temp directory for working files
    print(aw.AW_BIN)    # Directory containing FFmpeg and other binaries

Requirements:
    Python 3.7+

Author: Archiware GmbH
License: MIT
"""

import os
import sys
import tempfile
from datetime import datetime

#------------------------------------------------------------
# Path Normalization
#------------------------------------------------------------

def _normalize_path(path):
    """
    Convert P5 Unix-style paths to native OS format.
    
    P5 sets AWPST_SRV_HOME with Unix-style paths even on Windows,
    and wraps them in Tcl-style braces:
        {/C/Program Files/ARCHIWARE/...}
    
    This function converts to native format:
        C:\\Program Files\\ARCHIWARE\\...
    
    Args:
        path: Path string, possibly in P5/Tcl format
        
    Returns:
        Normalized path in native OS format
    """
    # Remove Tcl-style braces if present
    if path.startswith('{') and path.endswith('}'):
        path = path[1:-1]
    
    # Convert Unix-style Windows paths: /C/... -> C:\...
    if sys.platform == 'win32' and path.startswith('/') and len(path) > 2 and path[2] == '/':
        return path[1] + ':' + path[2:].replace('/', '\\')
    
    return os.path.normpath(path)

#------------------------------------------------------------
# P5 Installation Paths
#------------------------------------------------------------

# Determine P5 installation path
if os.environ.get('AWPST_SRV_HOME'):
    # Use environment variable set by P5 (normalize for Windows compatibility)
    AW_PATH = _normalize_path(os.environ['AWPST_SRV_HOME'])
elif sys.platform == 'win32':
    AW_PATH = r'C:\Program Files\ARCHIWARE\Data_Lifecycle_Management_Suite'
else:
    # macOS and Linux
    AW_PATH = '/usr/local/aw'

# Temp directory (P5 cleans this on restart)
AW_TEMP = os.path.join(AW_PATH, 'temp')
if not os.path.isdir(AW_TEMP):
    AW_TEMP = tempfile.gettempdir()

# Binary directory (contains FFmpeg)
# Windows has binaries in bin/prevgen, Unix uses bin symlink
if sys.platform == 'win32':
    AW_BIN = os.path.join(AW_PATH, 'bin', 'prevgen')
else:
    AW_BIN = os.path.join(AW_PATH, 'bin')

#------------------------------------------------------------
# Logging
#------------------------------------------------------------

_logfile = None
DEBUG_MODE = False


def set_logfile(name):
    """
    Set the logfile name. File will be created in AW_TEMP.
    
    Args:
        name: Filename for the log (e.g., "proxy_generator.log")
    """
    global _logfile
    _logfile = os.path.join(AW_TEMP, name)


def log(message):
    """
    Write a timestamped message to the logfile.
    
    Args:
        message: Text to log
    """
    if not _logfile:
        return
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    try:
        with open(_logfile, 'a', encoding='utf-8') as f:
            f.write(f"[{timestamp}] {message}\n")
    except:
        pass


def debug_log(message):
    """
    Write a debug message to the logfile (only if DEBUG_MODE is True).
    
    Enable debug logging by setting:
        aw.DEBUG_MODE = True
    
    Args:
        message: Debug text to log
    """
    if DEBUG_MODE:
        log(f"DEBUG: {message}")


def error_exit(message):
    """
    Log an error message and exit with error code 1.
    
    Args:
        message: Error description
    """
    log(f"ERROR: {message}")
    sys.exit(1)
