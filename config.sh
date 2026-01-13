#!/bin/bash

# Base configuration
PYTHON_VERSION="3.12"
BASE_PATH="${BASE_PATH:-$HOME/odoo_projects}"

# System dependencies
SYSTEM_DEPENDENCIES=(
    git
    build-essential
    wget
    libxslt-dev
    libzip-dev
    libldap2-dev
    libsasl2-dev
    node-less
    libjpeg-dev
    zlib1g-dev
    libpq-dev
    libxml2-dev
    libxslt1-dev
    libldap2-dev
    libsasl2-dev
    libxml2-dev
)

# Function to clone or pull a git repository
clone_or_pull() {
    local repo_url="$1"
    local repo_path="$2"
    local branch="$3"

    if [ ! -d "$repo_path" ]; then
        git clone --depth 1 -b "$branch" "$repo_url" "$repo_path"
    else
        (cd "$repo_path" && git pull)
    fi
}
