#!/bin/bash
set -eo pipefail 
# --- Configuration Variables ---
APP_NAME="data-collection-service"
APP_DIR="/opt/${APP_NAME}"
CONFIG_DIR="${APP_DIR}/config"
LOG_DIR="/var/log/${APP_NAME}"
COMPOSE_FILE="${APP_DIR}/docker-compose.yml"

DOCKER_IMAGE_TAG="${DOCKER_IMAGE_TAG:-latest}"
DOCKER_IMAGE_REPO="${DOCKER_IMAGE_REPO:-your_dockerhub_username/${APP_NAME}}"

ENVIRONMENT="staging" 
DEPLOYMENT_STRATEGY="" 

log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >&2
}
log_warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $1" >&2
}
log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >&2
    exit 1
}

parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --deploy) DEPLOY_SERVICE=true ;;
            --environment) ENVIRONMENT="$2"; shift ;;
            --strategy) DEPLOYMENT_STRATEGY="$2"; shift ;;
            --help)
                echo "Usage: $0 [--deploy] [--environment <staging|production>] [--strategy <blue|green>]"
                echo "  --deploy: Perform the deployment actions."
                echo "  --environment: Specify the target environment (e.g., staging, production)."
                echo "  --strategy: Specify deployment strategy for prod (e.g., blue, green)."
                exit 0
                ;;
            *) log_warning "Unknown parameter passed: $1"; exit 1 ;;
        esac
        shift
    done
}

# --- Pre-flight Checks ---
pre_flight_checks() {
    log_info "Running pre-flight checks..."

    command -v docker >/dev/null 2>&1 || log_error "Docker is not installed. Please install Docker Engine."
    command -v docker-compose >/dev/null 2>&1 || log_error "Docker Compose is not installed. Please install Docker Compose (v2 recommended)."
    command -v curl >/dev/null 2>&1 || log_error "Curl is not installed. Please install curl."
    command -v jq >/dev/null 2>&1 || log_warning "JQ is not installed. May affect JSON parsing for logging/monitoring."

    # Check system resources
    local min_disk_gb=10 # Minimum 10GB free disk space
    local min_mem_mb=1024 # Minimum 1GB free RAM

    local free_disk_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ "$free_disk_gb" -lt "$min_disk_gb" ]]; then
        log_error "Insufficient disk space. Requires at least ${min_disk_gb}GB, found ${free_disk_gb}GB."
    fi
    log_info "Disk space check passed. ${free_disk_gb}GB free."

    local free_mem_mb=$(free -m | awk 'NR==2 {print $4}')
    if [[ "$free_mem_mb" -lt "$min_mem_mb" ]]; then
        log_error "Insufficient memory. Requires at least ${min_mem_mb}MB, found ${free_mem_mb}MB."
    fi
    log_info "Memory check passed. ${free_mem_mb}MB free."
    log_info "Pre-flight checks completed successfully."
}

# --- Environment Configuration ---
configure_environment() {
    log_info "Configuring environment for ${ENVIRONMENT}..."

    mkdir -p "${APP_DIR}" "${CONFIG_DIR}" "${LOG_DIR}" || log_error "Failed to create application directories."
    log_info "Created application directories: ${APP_DIR}, ${CONFIG_DIR}, ${LOG_DIR}"

    chown -R root:root "${LOG_DIR}" # Or a specific user if container logs write directly
    chmod 755 "${LOG_DIR}"
    log_info "Set permissions for log directory."
    
    cp docker-compose.yml "${APP_DIR}/docker-compose.yml" || log_error "Failed to copy docker-compose.yml."
    mkdir -p "${APP_DIR}/nginx/conf.d" || log_error "Failed to create nginx config directory."
    cp nginx/nginx.conf "${APP_DIR}/nginx/nginx.conf" || log_error "Failed to copy nginx.conf."
    cp nginx/conf.d/default.conf "${APP_DIR}/nginx/conf.d/default.conf" || log_error "Failed to copy default.conf."

    # Example for `db_init` scripts (for first-time setup or schema changes)
    mkdir -p "${APP_DIR}/db_init"
    cp db_init/init.sql "${APP_DIR}/db_init/init.sql" || log_error "Failed to copy init.sql."

    log_info "Environment configuration completed."
}

# --- Deployment ---
deploy_service() {
    log_info "Starting deployment for ${ENVIRONMENT} environment (Image tag: ${DOCKER_IMAGE_TAG})..."

    cd "${APP_DIR}" || log_error "Failed to change to application directory: ${APP_DIR}"

    export DOCKER_IMAGE_REPO=${DOCKER_IMAGE_REPO}
    export DOCKER_IMAGE_TAG=${DOCKER_IMAGE_TAG}

    log_info "Pulling latest Docker images..."
    docker compose -f "${COMPOSE_FILE}" pull || log_warning "Failed to pull latest images. Attempting to build or use local."

    log_info "Stopping existing services (if any)..."
    docker compose -f "${COMPOSE_FILE}" down --remove-orphans || log_warning "Failed to stop existing services (may not be running)."

    log_info "Starting services in correct order..."
    docker compose -f "${COMPOSE_FILE}" up -d || log_error "Failed to start Docker Compose services."

    log_info "Waiting for services to become healthy..."
    # This command waits for all services with a healthcheck to report 'healthy'
    local timeout_seconds=300 # 5 minutes timeout
    local start_time=$(date +%s)
    while true; do
        local unhealthy_services=$(docker compose -f "${COMPOSE_FILE}" ps --services --filter "status=unhealthy" --quiet)
        if [ -z "$unhealthy_services" ]; then
            log_info "All services are healthy."
            break
        fi
        current_time=$(date +%s)
        if (( current_time - start_time > timeout_seconds )); then
            log_error "Services did not become healthy within ${timeout_seconds} seconds. Unhealthy services: ${unhealthy_services}"
        fi
        log_info "Waiting for: ${unhealthy_services} to become healthy... (Current status: $(docker compose -f "${COMPOSE_FILE}" ps --format "{{.Name}} {{.Status}}"))"
        sleep 10
    done

    log_info "Database migrations assumed to be handled (e.g., via db_init scripts or external tool)."

    log_info "Deployment completed successfully for ${ENVIRONMENT}."
}


# --- Main Execution Flow ---
main() {
    parse_args "$@"

    pre_flight_checks
    configure_environment

    if [ "$DEPLOY_SERVICE" = true ]; then
        deploy_service
    else
        log_info "No --deploy flag provided. Only pre-flight and configuration steps executed."
    fi

    log_info "${APP_NAME} setup script finished."
}

main "$@"
