#!/bin/bash
set -e

# Configuration
ODOO_VERSION="17.0"
ODOO_PATH="/opt/odoos/${ODOO_VERSION}"
CONFIG_PATH="/home/vincent/odoo_projects/bzbfedafin/odoo.conf"

# Function to find valid addon directories
find_addon_paths() {
    local search_dirs=("$@")
    local addons_path=""
    for dir in "${search_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local paths=$(find "$dir" -type f \( -name "__manifest__.py" -o -name "__openerp__.py" \) 2>/dev/null |
                           xargs -I {} dirname {} |
                           xargs -I {} dirname {} |
                           grep -v '/tools/posbox' |
                           sort -u |
                           tr '\n' ',' |
                           sed 's/,$//')
            if [ -n "$paths" ]; then
                addons_path="${addons_path}${paths},"
            fi
        fi
    done
    echo "${addons_path%,}"
}

# Define addon paths
ADDON_DIRS=(
    "${ODOO_PATH}/odoo/addons"
    "${ODOO_PATH}/enterprise"
    "${ODOO_PATH}/design-themes"
    "/home/vincent/odoo_projects/bzbfedafin/custom_addons"
)

ADDONS_PATH=$(find_addon_paths "${ADDON_DIRS[@]}")

if [ -z "$ADDONS_PATH" ]; then
    echo "Error: No valid addon paths found"
    exit 1
fi

# Update addons_path in odoo.conf
if [ -f "${CONFIG_PATH}" ]; then
    if grep -q "^addons_path" "${CONFIG_PATH}"; then
        # Replace existing addons_path line
        sed -i "/^addons_path/c\addons_path = ${ADDONS_PATH}" "${CONFIG_PATH}"
    else
        # Add addons_path if it doesn't exist
        echo "addons_path = ${ADDONS_PATH}" >> "${CONFIG_PATH}"
    fi
    echo "Updated addons_path in ${CONFIG_PATH}"
    echo "New addons_path: ${ADDONS_PATH}"
else
    echo "Error: Config file not found at ${CONFIG_PATH}"
    exit 1
fi
