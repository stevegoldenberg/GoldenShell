# GoldenShell Interactive Mode

## Overview

GoldenShell now supports both **CLI mode** (command-line arguments) and **Interactive mode** (menu-driven interface).

## Usage

### Interactive Mode (New!)

Simply run the script without any arguments:

```bash
./goldenshell.py
# or
python3 goldenshell.py
```

This will display an interactive menu:

```
=====================================================
  GoldenShell - AWS Development Environment
=====================================================

  0. Exit
  1. Initialize configuration
  2. View configuration
  3. Deploy new instance
  4. Check instance status
  5. Start instance
  6. Stop instance
  7. Resize instance
  8. SSH to instance
  9. Destroy environment

Select an option: _
```

### CLI Mode (Existing Functionality)

All existing command-line functionality remains unchanged:

```bash
# Initialize configuration
./goldenshell.py init

# Check instance status
./goldenshell.py status

# Start instance
./goldenshell.py start

# Stop instance
./goldenshell.py stop

# Deploy new instance
./goldenshell.py deploy --instance-type t3.medium

# Resize instance
./goldenshell.py resize

# SSH to instance
./goldenshell.py ssh --tailscale-hostname <hostname>

# Destroy environment
./goldenshell.py destroy

# View configuration
./goldenshell.py config

# View help
./goldenshell.py --help
```

## Features of Interactive Mode

1. **User-Friendly Menu**: Clear, numbered options with color-coded prompts
2. **Screen Clearing**: Automatically clears the screen between operations for a clean interface
3. **Error Handling**: Gracefully handles errors and displays them in red
4. **Continuous Operation**: After completing an action, asks if you want to perform another
5. **Easy Exit**: Press '0' to exit at any time
6. **Contextual Prompts**: Some commands (like deploy) will prompt for additional parameters

## Implementation Details

### Changes Made

1. **Modified CLI Group Decorator** (line 160-166):
   - Added `invoke_without_command=True` to allow running without a subcommand
   - Added `@click.pass_context` to access Click context
   - Added check for `ctx.invoked_subcommand is None` to trigger interactive mode

2. **Added interactive_menu() Function** (line 63-157):
   - Displays formatted menu with all available commands
   - Handles user input and validates choices
   - Executes selected commands using Click's context.invoke()
   - Handles errors and provides user feedback
   - Loops until user chooses to exit

3. **Menu Options** (line 76-87):
   - All commands mapped to numbered options
   - Exit option (0) for clean termination
   - Organized in logical workflow order

4. **Command Execution** (line 115-150):
   - Maps menu selections to actual Click command functions
   - Special handling for commands requiring parameters (e.g., deploy)
   - Error handling for sys.exit() calls from commands
   - Exception handling with user-friendly error messages

## Backward Compatibility

All existing CLI functionality is **100% backward compatible**. Scripts, automation, and existing workflows will continue to work exactly as before. The interactive mode only activates when the script is run without any arguments.

## Color Scheme

- **Cyan**: Headers, separators, command execution indicators
- **Yellow**: Prompts and warnings
- **Green**: Success messages
- **Red**: Error messages
- **Bold**: Important headers and titles
