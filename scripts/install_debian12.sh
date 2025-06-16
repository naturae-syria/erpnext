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
build-essential pkg-config redis-server mariadb-server mariadb-client default-libmysqlclient-dev \
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

wait_for_redis() {
    local attempts=0
    local max_attempts=30
    until redis-cli -p 13000 ping >/dev/null 2>&1; do
        if [ "$attempts" -ge "$max_attempts" ]; then
            log "Redis failed to start"
            return 1
        fi
        attempts=$((attempts+1))
        sleep 1
    done
}

start_background_bench() {
    log "Starting temporary bench to launch Redis"
    bench start &> /tmp/bench_start.log &
    BENCH_BG_PID=$!
    wait_for_redis
}

stop_background_bench() {
    if [ -n "${BENCH_BG_PID:-}" ] && kill -0 "$BENCH_BG_PID" 2>/dev/null; then
        log "Stopping temporary bench"
        kill "$BENCH_BG_PID"
        wait "$BENCH_BG_PID" || true
    fi
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
    start_background_bench
    create_site
    install_erpnext
    stop_background_bench
    build_and_start
}

main "$@"
