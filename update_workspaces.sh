#!/bin/bash
# Update existing Odoo workspaces with latest configurations
#
# Usage: ./update_workspaces.sh [base_folder]
#        base_folder defaults to ~/odoo_projects
#
# This script:
# - Recursively scans for .code-workspace files
# - Detects project structure (odoo path, enterprise, custom_addons, venv)
# - Updates VSCode settings, odools.toml, and utility scripts

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_FOLDER="${1:-$HOME/odoo_projects}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}Scanning for workspaces in: $BASE_FOLDER${NC}"
echo ""

# Find all .code-workspace files
WORKSPACES=$(find "$BASE_FOLDER" -name "*.code-workspace" -type f 2>/dev/null)

if [ -z "$WORKSPACES" ]; then
    echo -e "${YELLOW}No workspaces found in $BASE_FOLDER${NC}"
    exit 0
fi

# Count workspaces
WORKSPACE_COUNT=$(echo "$WORKSPACES" | wc -l)
echo -e "Found ${GREEN}$WORKSPACE_COUNT${NC} workspace(s):"
echo "$WORKSPACES" | while read -r ws; do
    echo "  - $ws"
done
echo ""

# Ask for confirmation
read -p "Update all workspaces? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""

# Process each workspace
echo "$WORKSPACES" | while read -r WORKSPACE_FILE; do
    PROJECT_PATH=$(dirname "$WORKSPACE_FILE")
    PROJECT_NAME=$(basename "$PROJECT_PATH")

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "Updating: ${GREEN}$PROJECT_NAME${NC}"
    echo -e "Path: $PROJECT_PATH"

    # Detect project structure
    VENV_PATH=""
    ODOO_PATH=""
    ENTERPRISE_PATH=""
    DESIGN_THEMES_PATH=""
    CUSTOM_ADDONS_PATH=""
    ODOO_VERSION=""

    # Find venv
    if [ -d "$PROJECT_PATH/venv" ]; then
        VENV_PATH="$PROJECT_PATH/venv"
    elif [ -d "$PROJECT_PATH/.venv" ]; then
        VENV_PATH="$PROJECT_PATH/.venv"
    fi

    # Find custom_addons
    if [ -d "$PROJECT_PATH/custom_addons" ]; then
        CUSTOM_ADDONS_PATH="$PROJECT_PATH/custom_addons"
    elif [ -d "$PROJECT_PATH/addons" ]; then
        CUSTOM_ADDONS_PATH="$PROJECT_PATH/addons"
    fi

    # Try to detect Odoo paths from existing workspace or odoo.conf
    if [ -f "$PROJECT_PATH/odoo.conf" ]; then
        # Try to find addons_path in odoo.conf which might contain odoo path hints
        ADDONS_LINE=$(grep "^addons_path" "$PROJECT_PATH/odoo.conf" 2>/dev/null || true)
        if [ -n "$ADDONS_LINE" ]; then
            # Extract paths and find odoo/enterprise
            for path in $(echo "$ADDONS_LINE" | cut -d'=' -f2 | tr ',' '\n'); do
                path=$(echo "$path" | xargs)  # trim whitespace
                if [[ "$path" == */odoo/addons ]]; then
                    ODOO_PATH=$(dirname "$path")
                elif [[ "$path" == */enterprise ]]; then
                    ENTERPRISE_PATH="$path"
                elif [[ "$path" == */design-themes ]]; then
                    DESIGN_THEMES_PATH="$path"
                fi
            done
        fi
    fi

    # Try to detect from /opt/odoos structure
    if [ -z "$ODOO_PATH" ]; then
        # Check existing workspace file for paths
        if [ -f "$WORKSPACE_FILE" ]; then
            ODOO_PATH=$(grep -oP '"path":\s*"/opt/odoos/[^"]+/odoo"' "$WORKSPACE_FILE" 2>/dev/null | head -1 | grep -oP '/opt/odoos/[^"]+' || true)
            if [ -n "$ODOO_PATH" ]; then
                ODOO_VERSION=$(echo "$ODOO_PATH" | grep -oP '\d+\.\d+|master' || true)
                ENTERPRISE_PATH=$(dirname "$ODOO_PATH")/enterprise
                DESIGN_THEMES_PATH=$(dirname "$ODOO_PATH")/design-themes
            fi
        fi
    fi

    # Fallback: scan /opt/odoos for matching version
    if [ -z "$ODOO_PATH" ] && [ -d "/opt/odoos" ]; then
        # Try to guess version from project name (e.g., project-18 -> 18.0)
        VERSION_GUESS=$(echo "$PROJECT_NAME" | grep -oP '\d+' | tail -1 || true)
        if [ -n "$VERSION_GUESS" ]; then
            if [ -d "/opt/odoos/${VERSION_GUESS}.0/odoo" ]; then
                ODOO_VERSION="${VERSION_GUESS}.0"
                ODOO_PATH="/opt/odoos/${VERSION_GUESS}.0/odoo"
                ENTERPRISE_PATH="/opt/odoos/${VERSION_GUESS}.0/enterprise"
                DESIGN_THEMES_PATH="/opt/odoos/${VERSION_GUESS}.0/design-themes"
            fi
        fi
    fi

    # Validate detected paths
    MISSING=""
    [ -z "$VENV_PATH" ] || [ ! -d "$VENV_PATH" ] && MISSING="$MISSING venv"
    [ -z "$ODOO_PATH" ] || [ ! -d "$ODOO_PATH" ] && MISSING="$MISSING odoo"
    [ -z "$CUSTOM_ADDONS_PATH" ] && MISSING="$MISSING custom_addons"

    if [ -n "$MISSING" ]; then
        echo -e "${YELLOW}  Warning: Could not detect:$MISSING${NC}"
        echo -e "${YELLOW}  Skipping this workspace. Configure manually or check structure.${NC}"
        continue
    fi

    echo "  Detected:"
    echo "    Odoo: $ODOO_PATH"
    echo "    Enterprise: $ENTERPRISE_PATH"
    echo "    Custom Addons: $CUSTOM_ADDONS_PATH"
    echo "    Venv: $VENV_PATH"

    # Function to replace placeholders
    replace_placeholders() {
        sed -e "s|\$VENV_PATH|$VENV_PATH|g" \
            -e "s|\$PROJECT_PATH|$PROJECT_PATH|g" \
            -e "s|\$ODOO_PATH|$ODOO_PATH|g" \
            -e "s|\$ENTERPRISE_PATH|$ENTERPRISE_PATH|g" \
            -e "s|\$DESIGN_THEMES_PATH|$DESIGN_THEMES_PATH|g" \
            -e "s|\$CUSTOM_ADDONS_PATH|$CUSTOM_ADDONS_PATH|g" \
            -e "s|\$USER|$USER|g" \
            -e "s|\$PROJECT_NAME|$PROJECT_NAME|g" \
            -e "s|\$ODOO_VERSION|$ODOO_VERSION|g" \
            -e "s|\$DEFAULT_MODULE||g" \
            -e "s|\$DB_NAME||g"
    }

    # Update workspace file
    echo "  Updating workspace settings..."
    cat "$SCRIPT_DIR/templates/code_workspace.json.template" | replace_placeholders > "$WORKSPACE_FILE"

    # Update/create .vscode folder
    mkdir -p "$PROJECT_PATH/.vscode"
    cat "$SCRIPT_DIR/templates/launch.json.template" | replace_placeholders > "$PROJECT_PATH/.vscode/launch.json"
    cat "$SCRIPT_DIR/templates/tasks.json.template" | replace_placeholders > "$PROJECT_PATH/.vscode/tasks.json"
    cat "$SCRIPT_DIR/templates/shortcuts.json.template" | replace_placeholders > "$PROJECT_PATH/.vscode/shortcuts.json"
    cat "$SCRIPT_DIR/templates/.pylintrc.template" | replace_placeholders > "$PROJECT_PATH/.vscode/.pylintrc"

    # Update utility scripts
    echo "  Updating utility scripts..."
    cat "$SCRIPT_DIR/templates/update_addons_path.sh.template" | replace_placeholders > "$PROJECT_PATH/update_addons_path.sh"
    cat "$SCRIPT_DIR/templates/list_modules.sh.template" | replace_placeholders > "$PROJECT_PATH/list_modules.sh"
    cat "$SCRIPT_DIR/templates/update_odools_config.sh.template" | replace_placeholders > "$PROJECT_PATH/update_odools_config.sh"
    chmod +x "$PROJECT_PATH/update_addons_path.sh"
    chmod +x "$PROJECT_PATH/list_modules.sh"
    chmod +x "$PROJECT_PATH/update_odools_config.sh"

    # Generate odools.toml
    echo "  Generating odools.toml..."
    "$PROJECT_PATH/update_odools_config.sh" > /dev/null

    # Update odoo.conf if it exists
    if [ -f "$PROJECT_PATH/odoo.conf" ]; then
        echo "  Preserving existing odoo.conf (not overwriting)"
    fi

    echo -e "  ${GREEN}Done!${NC}"
    echo ""
done

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}All workspaces updated!${NC}"
echo ""
echo "Notes:"
echo "  - Restart VSCode to apply changes"
echo "  - Run ./update_odools_config.sh in each project after adding new addons"
