#!/usr/bin/env bash
# End-to-end installer for ERPNext on Debian 12
set -euo pipefail

BENCH_DIR=${BENCH_DIR:-frappe-bench}
SITE_NAME=${SITE_NAME:-erpnext.localhost}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-admin}
DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD:-root}

log() {
printf "[info] %s\n" "$1"
}

install_dependencies() {
log "Updating package lists"
sudo apt-get update
log "Installing dependencies"
sudo apt-get install -y git python3-dev python3-setuptools python3-pip python3-venv \
build-essential redis-server mariadb-server mariadb-client default-libmysqlclient-dev \
wkhtmltopdf curl nodejs npm
}

configure_mariadb() {
    log "Configuring MariaDB root password"
    if sudo mysql -u root -e "SELECT 1" >/dev/null 2>&1; then
        sudo mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}'"
    else
        sudo mysql -u root -p"${DB_ROOT_PASSWORD}" -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}'"
    fi
    sudo mysql -u root -p"${DB_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES"
}

setup_node() {
if ! command -v node >/dev/null; then
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
fi
sudo npm install -g yarn
}

install_bench() {
log "Installing bench"
sudo pip3 install --break-system-packages frappe-bench
}

init_bench() {
log "Initializing bench at ${BENCH_DIR}"
bench init --frappe-path https://github.com/frappe/frappe --skip-assets "$BENCH_DIR"
cd "$BENCH_DIR"
}

create_site() {
log "Creating site ${SITE_NAME}"
bench new-site --admin-password "$ADMIN_PASSWORD" --mariadb-root-password "$DB_ROOT_PASSWORD" "$SITE_NAME"
}

install_erpnext() {
log "Getting ERPNext app"
bench get-app https://github.com/naturae-syria/erpnext
log "Installing ERPNext"
bench --site "$SITE_NAME" install-app erpnext
}

build_and_start() {
log "Building assets"
bench build
log "Starting bench"
bench start
}

main() {
    install_dependencies
    configure_mariadb
    setup_node
    install_bench
    init_bench
    create_site
    install_erpnext
    build_and_start
}

main "$@"
