#!/bin/bash

set -e

# Get the directory of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source the configuration
source "$SCRIPT_DIR/config.sh"

# Function to display usage
usage() {
    echo "Usage: $0 <project_name> <odoo_version>"
    echo "  project_name: Name of the project/customer environment (e.g. houtland-18)"
    echo "  odoo_version: Odoo version to use (e.g. 18.0)"
    exit 1
}

# Check if both parameters were provided
if [ -z "$2" ]; then
    usage
fi

# Set project-specific variables
PROJECT_NAME="$1"
ODOO_VERSION="$2"
PROJECT_PATH="$BASE_PATH/$PROJECT_NAME"
VENV_PATH="$PROJECT_PATH/venv"
CUSTOM_ADDONS_PATH="$PROJECT_PATH/custom_addons"
ODOO_BASE_PATH="/opt/odoos/$ODOO_VERSION"
ODOO_PATH="$ODOO_BASE_PATH/odoo"
ENTERPRISE_PATH="$ODOO_BASE_PATH/enterprise"
DESIGN_THEMES_PATH="$ODOO_BASE_PATH/design-themes"
PYTHON_VERSION="3.12"

# Install system dependencies
sudo apt update
sudo apt install -y "${SYSTEM_DEPENDENCIES[@]}"

# Install Python if not already installed
if ! command -v "python$PYTHON_VERSION" &> /dev/null; then
    sudo add-apt-repository ppa:deadsnakes/ppa -y
    sudo apt update
    sudo apt install -y "python$PYTHON_VERSION" "python$PYTHON_VERSION-venv" "python$PYTHON_VERSION-dev"
fi

# Install UV
if ! command -v uv &> /dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# Create project directory
mkdir -p "$PROJECT_PATH"

# Create and activate virtual environment
"python$PYTHON_VERSION" -m venv "$VENV_PATH"
source "$VENV_PATH/bin/activate"

# Set Git protocol (ssh or https)
GIT_PROTOCOL="${GIT_PROTOCOL:-ssh}"

# Define repository URLs based on protocol
if [ "$GIT_PROTOCOL" = "ssh" ]; then
    ODOO_REPO="git@github.com:odoo/odoo.git"
    ENTERPRISE_REPO="git@github.com:odoo/enterprise.git"
    DESIGN_THEMES_REPO="git@github.com:odoo/design-themes.git"
else
    ODOO_REPO="https://github.com/odoo/odoo.git"
    ENTERPRISE_REPO="https://github.com/odoo/enterprise.git"
    DESIGN_THEMES_REPO="https://github.com/odoo/design-themes.git"
fi

# Clone or update Odoo repositories
sudo mkdir -p "$ODOO_BASE_PATH"
sudo chown "$USER:$USER" "$ODOO_BASE_PATH"

echo "Cloning/updating Odoo repositories..."
if ! clone_or_pull "$ODOO_REPO" "$ODOO_PATH" "$ODOO_VERSION"; then
    echo "Failed to clone/update Odoo repository. Please check your credentials and connectivity."
    exit 1
fi

if ! clone_or_pull "$ENTERPRISE_REPO" "$ENTERPRISE_PATH" "$ODOO_VERSION"; then
    echo "Failed to clone/update Enterprise repository. Please check your credentials and connectivity."
    exit 1
fi

if ! clone_or_pull "$DESIGN_THEMES_REPO" "$DESIGN_THEMES_PATH" "$ODOO_VERSION"; then
    echo "Failed to clone/update Design Themes repository. Please check your credentials and connectivity."
    exit 1
fi

# Install Odoo requirements using UV
uv pip install -r "$ODOO_PATH/requirements.txt"

# Install additional development tools
uv pip install debugpy pylint-odoo

# Create custom addons directory
mkdir -p "$CUSTOM_ADDONS_PATH"

# Function to replace placeholders in templates
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
        -e "s|\$DEFAULT_MODULE||g"
}

# Create run_odoo_debug.sh script
cat "$SCRIPT_DIR/templates/run_odoo_debug.sh.template" | replace_placeholders > "$PROJECT_PATH/run_odoo_debug.sh"
chmod +x "$PROJECT_PATH/run_odoo_debug.sh"

# Create Odoo configuration file
cat "$SCRIPT_DIR/templates/odoo.conf.template" | replace_placeholders > "$PROJECT_PATH/odoo.conf"

# Create VSCode workspace file
cat "$SCRIPT_DIR/templates/code_workspace.json.template" | replace_placeholders > "$PROJECT_PATH/$PROJECT_NAME.code-workspace"

# Create VSCode launch configuration
mkdir -p "$PROJECT_PATH/.vscode"
cat "$SCRIPT_DIR/templates/launch.json.template" | replace_placeholders > "$PROJECT_PATH/.vscode/launch.json"
cat "$SCRIPT_DIR/templates/tasks.json.template" | replace_placeholders > "$PROJECT_PATH/.vscode/tasks.json"
cat "$SCRIPT_DIR/templates/shortcuts.json.template" | replace_placeholders > "$PROJECT_PATH/.vscode/shortcuts.json"

# Create .pylintrc
if [ -f "$SCRIPT_DIR/templates/.pylintrc.$ODOO_VERSION.template" ]; then
    cat "$SCRIPT_DIR/templates/.pylintrc.$ODOO_VERSION.template"| replace_placeholders > "$PROJECT_PATH/.vscode/.pylintrc"
else
    echo -e "\033[0;31mWarning: No specific .pylintrc template found for Odoo version $ODOO_VERSION.\033[0m"
fi

# Create utility scripts
cat "$SCRIPT_DIR/templates/update_addons_path.sh.template" | replace_placeholders > "$PROJECT_PATH/update_addons_path.sh"
cat "$SCRIPT_DIR/templates/list_modules.sh.template" | replace_placeholders > "$PROJECT_PATH/list_modules.sh"
chmod +x "$PROJECT_PATH/update_addons_path.sh"
chmod +x "$PROJECT_PATH/list_modules.sh"

# Report completion
echo ""
echo -e "\033[0;32mOdoo development environment for \033[1;33m$PROJECT_NAME\033[0;32m setup complete!\033[0m"
echo -e "Your custom addons should be placed in: \033[0;36m$CUSTOM_ADDONS_PATH\033[0m"
echo -e "To open the project in VSCode, use: \033[0;36mcode $PROJECT_PATH/$PROJECT_NAME.code-workspace\033[0m"
echo "To run Odoo with debugging enabled, use the 'Python: Odoo' launch configuration in VSCode."
echo "NOTE: Ensure your SSH key is added to your GitHub account for Odoo, Enterprise, and design-themes repositories."
echo ""
