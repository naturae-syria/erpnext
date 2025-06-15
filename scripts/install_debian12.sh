#!/usr/bin/env bash
# Simple installer for ERPNext on Debian 12
# This script installs bench, creates a site and starts the server
set -euo pipefail

# Update package lists and install basic dependencies
sudo apt update
sudo apt install -y git python3-dev python3-setuptools python3-pip python3-venv \
    build-essential redis-server mariadb-server mariadb-client default-libmysqlclient-dev \
    wkhtmltopdf curl nodejs npm

# Install bench
sudo pip3 install --break-system-packages frappe-bench

# Initialize a bench instance
bench init --frappe-path https://github.com/frappe/frappe --skip-assets frappe-bench
cd frappe-bench

# Create a new site with default credentials
bench new-site --admin-password admin --mariadb-root-password root erpnext.localhost

# Get ERPNext app from GitHub
bench get-app https://github.com/naturae-syria/erpnext

# Install the app on the new site
bench --site erpnext.localhost install-app erpnext

# Build assets and start the server
bench build
bench start
