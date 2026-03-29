
#!/bin/bash

# =============================================================================
# API Migration Script - WSO2 to APK Gateway
# =============================================================================
#
# PURPOSE:
#   Automates the migration of APIs from WSO2 API Manager to APK Gateway.
#   This script exports an API, modifies it for APK compatibility, and re-imports it.
#
# WHAT IT DOES:
#   1. Login to the environment
#   2. Export the API as JSON
#   3. Copy and unzip the exported API to current directory
#   4. Modify api.json to set:
#      - gatewayVendor: "wso2"
#      - gatewayType: "wso2/apk"  
#      - initiatedFromGateway: false
#   5. Copy deployment_environments.yaml (if provided)
#   6. Delete the existing API (optional, with confirmation)
#   7. Import the modified API folder
#
# APICTL COMMANDS EXECUTED:
#   apictl login <environment> -u <user> -k
#   apictl export api -n <name> -v <version> -r <user> -e <environment> --format JSON -k
#   apictl delete api -n <name> -v <version> -r <admin> -e <environment> -k
#   apictl import api -f <folder> -e <environment> --update -k --preserve-provider=false
#
# USAGE:
#   ./migrate-api.sh -n <API_NAME> -v <VERSION> -u <USER> [-a <ADMIN>] [-d <DEPLOYMENT_FILE>]
#
# EXAMPLES:
#   ./migrate-api.sh -n TPP_Utils_API_OpenAPI_301 -v 1.0.0 -u Pereira
#   ./migrate-api.sh -n MyAPI -v 2.0.0 -u Pereira -d ./deployment_environments.yaml
#   ./migrate-api.sh -n MyAPI -v 1.0.0 -u Pereira --skip-delete
#   ./migrate-api.sh -n MyAPI -v 1.0.0 -u Pereira --dry-run
#
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# apictl path - adjust this if apictl is in a different location
APICTL="/Users/minura/SA-Team/POCs/MBCP/apictl/apictl"

# Verify apictl exists
if [[ ! -x "$APICTL" ]]; then
    echo "Error: apictl not found at $APICTL"
    echo "Please update the APICTL variable in this script"
    exit 1
fi

# Default values
ENVIRONMENT="Production"
FORMAT="JSON"
SKIP_SSL="-k"
PRESERVE_PROVIDER="false"

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n, --name              API name (required)"
    echo "  -v, --version           API version (required)"
    echo "  -e, --environment       Environment name (default: Production)"
    echo "  -u, --user              DevOps user for export (required)"
    echo "  -a, --admin             Admin user for delete (default: admin)"
    echo "  -d, --deployment-file   Path to deployment_environments.yaml (optional)"
    echo "  --skip-delete           Skip the delete step (useful for new imports)"
    echo "  --dry-run               Show what would be done without executing"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -n TPP_Utils_API_OpenAPI_301 -v 1.0.0 -u Pereira -a admin"
}

# Function to log messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse command line arguments
SKIP_DELETE=false
DRY_RUN=false
ADMIN_USER="admin"

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            API_NAME="$2"
            shift 2
            ;;
        -v|--version)
            API_VERSION="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -u|--user)
            DEVOPS_USER="$2"
            shift 2
            ;;
        -a|--admin)
            ADMIN_USER="$2"
            shift 2
            ;;
        -d|--deployment-file)
            DEPLOYMENT_FILE="$2"
            shift 2
            ;;
        --skip-delete)
            SKIP_DELETE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$API_NAME" ]]; then
    log_error "API name is required"
    usage
    exit 1
fi

if [[ -z "$API_VERSION" ]]; then
    log_error "API version is required"
    usage
    exit 1
fi

if [[ -z "$DEVOPS_USER" ]]; then
    log_error "DevOps user is required"
    usage
    exit 1
fi

# Set working directory to script's directory (not temp)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR"
API_FOLDER="${API_NAME}-${API_VERSION}"
EXPORT_FILE="${API_NAME}_${API_VERSION}.zip"

log_info "Working directory: $WORK_DIR"

# Function to execute or print command
run_cmd() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Would execute: $*"
    else
        "$@"
    fi
}

# =============================================================================
# Step 1: Login to the environment
# =============================================================================
# APICTL COMMAND: apictl login <environment> -u <user> -k
# This authenticates with the WSO2 API Manager and stores credentials for
# subsequent apictl operations. The -k flag skips SSL certificate validation.
# =============================================================================
log_info "Step 1: Logging in to $ENVIRONMENT as $DEVOPS_USER..."
if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY-RUN] Would execute: $APICTL login $ENVIRONMENT -u $DEVOPS_USER $SKIP_SSL"
else
    # Execute apictl login command
    "$APICTL" login "$ENVIRONMENT" -u "$DEVOPS_USER" $SKIP_SSL
fi

# =============================================================================
# Step 2: Export the current API
# =============================================================================
# APICTL COMMAND: apictl export api -n <name> -v <version> -r <user> -e <env> --format JSON -k
# This exports the API definition from WSO2 API Manager as a ZIP archive.
# The export includes: api.json, swagger/openapi definitions, policies, etc.
# Export location: ~/.wso2apictl/exported/apis/<environment>/
# =============================================================================
log_info "Step 2: Exporting API $API_NAME v$API_VERSION..."
cd "$WORK_DIR"
# Execute apictl export command - exports API as ZIP to ~/.wso2apictl/exported/apis/
run_cmd "$APICTL" export api -n "$API_NAME" -v "$API_VERSION" -r "$DEVOPS_USER" -e "$ENVIRONMENT" --format "$FORMAT" $SKIP_SSL

# =============================================================================
# Step 3: Extract and prepare the exported API
# =============================================================================
# This step processes the ZIP file exported by apictl in Step 2.
# The apictl tool exports APIs to: ~/.wso2apictl/exported/apis/<environment>/
# We extract the ZIP, then modify api.json to configure APK gateway settings:
#   - gatewayVendor: "wso2"        (identifies the gateway vendor)
#   - gatewayType: "wso2/apk"      (specifies APK as the target gateway)
#   - initiatedFromGateway: false  (indicates API originated from API Manager)
# =============================================================================
log_info "Step 3: Extracting and preparing the exported API..."
if [[ "$DRY_RUN" != true ]]; then
    # apictl exports to ~/.wso2apictl/exported/apis/<environment>/
    APICTL_EXPORT_DIR="$HOME/.wso2apictl/exported/apis/$ENVIRONMENT"
    EXPORT_FILE_PATH="$APICTL_EXPORT_DIR/${API_NAME}_${API_VERSION}.zip"
    ALT_EXPORT_FILE_PATH="$APICTL_EXPORT_DIR/${API_NAME}-${API_VERSION}.zip"
    
    # Find the export file and copy it to working directory
    if [[ -f "$EXPORT_FILE_PATH" ]]; then
        log_info "Found export at: $EXPORT_FILE_PATH"
        log_info "Copying to working directory..."
        cp "$EXPORT_FILE_PATH" "$WORK_DIR/"
        ACTUAL_EXPORT_FILE="$WORK_DIR/${API_NAME}_${API_VERSION}.zip"
    elif [[ -f "$ALT_EXPORT_FILE_PATH" ]]; then
        log_info "Found export at: $ALT_EXPORT_FILE_PATH"
        log_info "Copying to working directory..."
        cp "$ALT_EXPORT_FILE_PATH" "$WORK_DIR/"
        ACTUAL_EXPORT_FILE="$WORK_DIR/${API_NAME}-${API_VERSION}.zip"
    else
        log_error "Export file not found. Looked for:"
        log_error "  - $EXPORT_FILE_PATH"
        log_error "  - $ALT_EXPORT_FILE_PATH"
        exit 1
    fi
    
    # Remove existing folder if present
    if [[ -d "$WORK_DIR/$API_FOLDER" ]]; then
        log_info "Removing existing folder: $API_FOLDER"
        rm -rf "$WORK_DIR/$API_FOLDER"
    fi
    
    # Unzip in working directory
    log_info "Unzipping to: $WORK_DIR"
    unzip -o -q "$ACTUAL_EXPORT_FILE" -d "$WORK_DIR"

    # Find the extracted folder
    if [[ -d "$WORK_DIR/$API_FOLDER" ]]; then
        API_DIR="$WORK_DIR/$API_FOLDER"
    elif [[ -d "$WORK_DIR/${API_NAME}_${API_VERSION}" ]]; then
        API_DIR="$WORK_DIR/${API_NAME}_${API_VERSION}"
    elif [[ -d "$WORK_DIR/$API_NAME" ]]; then
        API_DIR="$WORK_DIR/$API_NAME"
    else
        # Find any directory that was created
        API_DIR=$(find "$WORK_DIR" -maxdepth 1 -type d -name "${API_NAME}*" | head -1)
        if [[ -z "$API_DIR" ]]; then
            log_error "Could not find extracted API directory"
            exit 1
        fi
    fi

    log_info "Extracted to: $API_DIR"

    # Update api.json for APK gateway
    API_JSON="$API_DIR/api.json"
    if [[ -f "$API_JSON" ]]; then
        log_info "Updating api.json for APK gateway..."
        log_info "Setting: gatewayVendor=wso2, gatewayType=wso2/apk, initiatedFromGateway=false"
        
        # Use jq if available, otherwise use sed
        # Note: Fields are nested inside .data object
        if command -v jq &> /dev/null; then
            jq '.data.gatewayVendor = "wso2" | .data.gatewayType = "wso2/apk" | .data.initiatedFromGateway = false' "$API_JSON" > "${API_JSON}.tmp"
            mv "${API_JSON}.tmp" "$API_JSON"
        else
            # Fallback to sed for systems without jq
            sed -i.bak 's/"gatewayVendor"[[:space:]]*:[[:space:]]*"[^"]*"/"gatewayVendor": "wso2"/g' "$API_JSON"
            sed -i.bak 's/"gatewayType"[[:space:]]*:[[:space:]]*"[^"]*"/"gatewayType": "wso2\/apk"/g' "$API_JSON"
            sed -i.bak 's/"initiatedFromGateway"[[:space:]]*:[[:space:]]*[^,}]*/"initiatedFromGateway": false/g' "$API_JSON"
            rm -f "${API_JSON}.bak"
        fi
        
        # Verify changes
        if command -v jq &> /dev/null; then
            log_info "Verifying changes..."
            VENDOR=$(jq -r '.data.gatewayVendor' "$API_JSON")
            TYPE=$(jq -r '.data.gatewayType' "$API_JSON")
            INITIATED=$(jq -r '.data.initiatedFromGateway' "$API_JSON")
            log_info "  gatewayVendor: $VENDOR"
            log_info "  gatewayType: $TYPE"
            log_info "  initiatedFromGateway: $INITIATED"
        fi
        
        log_info "api.json updated successfully"
    else
        log_warn "api.json not found at $API_JSON"
    fi

    # =========================================================================
    # Step 4: Copy deployment configuration if provided
    # =========================================================================
    # The deployment_environments.yaml file specifies which gateway environments
    # the API should be deployed to. This is used by apictl during import to
    # configure the API's deployment targets (e.g., APK gateway clusters).
    # =========================================================================
    if [[ -n "$DEPLOYMENT_FILE" && -f "$DEPLOYMENT_FILE" ]]; then
        log_info "Step 4: Copying deployment_environments.yaml..."
        cp "$DEPLOYMENT_FILE" "$API_DIR/"
    elif [[ -f "$SCRIPT_DIR/deployment_environments.yaml" ]]; then
        log_info "Step 4: Copying deployment_environments.yaml from script directory..."
        cp "$SCRIPT_DIR/deployment_environments.yaml" "$API_DIR/"
    else
        log_warn "Step 4: No deployment_environments.yaml provided, skipping..."
    fi
fi

# =============================================================================
# Step 5: Delete the existing API (if not skipped)
# =============================================================================
# APICTL COMMAND: apictl delete api -n <name> -v <version> -r <admin> -e <env> -k
# This removes the existing API from WSO2 API Manager before re-importing.
# Deletion is required because the import with --update may not properly
# update gateway configuration. Requires admin privileges.
# Use --skip-delete flag to skip this step for new API imports.
# =============================================================================
if [[ "$SKIP_DELETE" != true ]]; then
    log_info "Step 5: Deleting existing API $API_NAME v$API_VERSION..."
    log_warn "This requires admin rights. Using user: $ADMIN_USER"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Would execute: $APICTL delete api -n $API_NAME -v $API_VERSION -r $ADMIN_USER -e $ENVIRONMENT $SKIP_SSL"
    else
        # Prompt for confirmation before executing apictl delete
        read -p "Are you sure you want to delete the existing API? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Execute apictl delete command - removes API from API Manager
            "$APICTL" delete api -n "$API_NAME" -v "$API_VERSION" -r "$ADMIN_USER" -e "$ENVIRONMENT" $SKIP_SSL || {
                log_warn "Delete failed or API does not exist. Continuing with import..."
            }
        else
            log_info "Skipping delete step..."
        fi
    fi
else
    log_info "Step 5: Skipping delete step (--skip-delete flag set)"
fi

# =============================================================================
# Step 6: Import the updated API
# =============================================================================
# APICTL COMMAND: apictl import api -f <folder> -e <env> --update -k --preserve-provider=false --verbose
# This imports the modified API folder back into WSO2 API Manager.
# Key flags:
#   -f <folder>           : Path to the extracted and modified API folder
#   --update              : Update existing API if it exists
#   --preserve-provider   : Set to false to use current user as provider
#   --verbose             : Show detailed import progress
#   -k                    : Skip SSL certificate validation
# =============================================================================
log_info "Step 6: Importing the updated API..."
if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY-RUN] Would execute: $APICTL import api -f $API_DIR -e $ENVIRONMENT --update $SKIP_SSL --preserve-provider=$PRESERVE_PROVIDER --verbose"
else
    # Execute apictl import command - imports modified API back to API Manager
    "$APICTL" import api -f "$API_DIR" -e "$ENVIRONMENT" --update $SKIP_SSL --preserve-provider="$PRESERVE_PROVIDER" --verbose
fi

log_info "=========================================="
log_info "API Migration completed successfully!"
log_info "API: $API_NAME v$API_VERSION"
log_info "Environment: $ENVIRONMENT"
log_info "Edited API folder: $API_DIR"
log_info "=========================================="
