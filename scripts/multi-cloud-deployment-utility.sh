```bash
#!/usr/bin/env bash
# cloud-deploy.sh - Comprehensive multi-cloud deployment utility
# Version: 1.1 - Enhanced with additional error handling and syntax fixes
# Supports major cloud providers and specialty platforms

# Enable strict error handling
set -e          # Exit on error
set -u          # Exit on undefined variables
set -o pipefail # Exit if any command in a pipeline fails

# Colors for terminal output (ANSI escape codes)
RESET="\033[0m"
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"

# Default configuration
CONFIG_FILE=".cloud-deploy.conf"
TOFU_VERSION="1.7.0"
PROJECT_DIR_BASE="." # Base directory for projects
PROVIDERS_DIR="./providers"
DEFAULT_PROVIDER="aws"
CADDY_ENABLED=false
STATE_BACKEND="local"
REPO_TRANSFER_ENABLED=false
BILLING_ENABLED=false

# --- Global Variables (will be set later) ---
PROJECT_NAME=""
PROJECT_DIR=""
SELECTED_PROVIDER=""
PROVIDER_CONFIG=""
PROVIDER_VARS=""
VARS_JSON=""
DOMAIN_NAME=""
EMAIL=""
GITHUB_USERNAME=""
PRIVATE_REPO=""
CLIENT_GITHUB_USERNAME=""
CLIENT_REPO=""
CLIENT_ROLE=""
REPO_TRANSFER_INFO=""
BILLING_TYPE=""
MONTHLY_FEE=""
COST_PERCENTAGE=""
BILLING_INFO=""
BACKEND_CONFIG=""
BACKEND_TYPE=""
BACKEND_SETTINGS=""
HOSTING_TYPE="self" # Default hosting type
declare -A PROVIDERS # Associative array for providers
declare -A PROVIDER_CATEGORIES # Associative array for provider categories
declare -A PROVIDER_INDEX_MAP # Map selection index to provider key

# --- Error Handling ---

# Error handler function
handle_error() {
  local line=$1
  local command=$2
  local code=$3
  echo -e "${RED}Error occurred in command '$command' on line $line with exit code $code${RESET}" >&2
  exit $code
}

# Set up error handling trap
trap 'handle_error ${LINENO} "$BASH_COMMAND" $?' ERR

# --- Helper Functions ---

# Check if a required command exists
check_command() {
  local cmd=$1
  local install_hint=$2

  if ! command -v "$cmd" &> /dev/null; then
    echo -e "${YELLOW}Command '$cmd' not found.${RESET}" >&2
    if [ -n "$install_hint" ]; then
      echo -e "Hint: $install_hint" >&2
    fi
    return 1
  fi
  return 0
}

# Safely create a directory
safe_mkdir() {
  local dir=$1

  if [ ! -d "$dir" ]; then
    if ! mkdir -p "$dir"; then
      echo -e "${RED}Failed to create directory: $dir${RESET}" >&2
      return 1
    fi
    echo -e "${GREEN}Created directory: $dir${RESET}"
  fi
  return 0
}

# --- Core Functions ---

# Print banner
print_banner() {
  echo -e "${BOLD}${BLUE}=================================================${RESET}"
  echo -e "${BOLD}${BLUE}     Comprehensive Multi-Cloud Deploy Utility     ${RESET}"
  echo -e "${BOLD}${BLUE}=================================================${RESET}"
  echo
}

# Check dependencies
check_dependencies() {
  echo -e "${BOLD}Checking dependencies...${RESET}"

  local missing_tools=()

  # Check if OpenTofu is installed
  if ! check_command "tofu" ""; then
    echo -e "${YELLOW}OpenTofu not found. Would you like to install it? [Y/n]${RESET}"
    read -r install_tofu
    if [[ "$install_tofu" =~ ^[Yy]$ ]] || [[ -z "$install_tofu" ]]; then
      install_opentofu || {
        echo -e "${RED}Failed to install OpenTofu.${RESET}" >&2
        exit 1
      }
    else
      echo -e "${RED}OpenTofu is required for this utility.${RESET}" >&2
      exit 1
    fi
  else
    echo -e "${GREEN}✓ OpenTofu found${RESET}"
  fi

  # Check for other required tools
  check_command "unzip" "Install with: apt-get install unzip / brew install unzip" || missing_tools+=("unzip")
  check_command "git" "Install with: apt-get install git / brew install git" || missing_tools+=("git")
  check_command "jq" "Install with: apt-get install jq / brew install jq" || missing_tools+=("jq")
  check_command "curl" "Install with: apt-get install curl / brew install curl" || missing_tools+=("curl")

  if [ ${#missing_tools[@]} -ne 0 ]; then
    echo -e "${RED}The following dependencies are missing:${RESET}" >&2
    for tool in "${missing_tools[@]}"; do
      echo "  - $tool" >&2
    done
    echo -e "${YELLOW}Please install these dependencies and try again.${RESET}" >&2
    exit 1
  else
    echo -e "${GREEN}✓ All core dependencies found${RESET}"
  fi
}

# Install OpenTofu
install_opentofu() {
  echo -e "${BOLD}Installing OpenTofu ${TOFU_VERSION}...${RESET}"

  # Ensure temp directory exists
  local tmp_dir="/tmp/opentofu_install"
  safe_mkdir "$tmp_dir" || return 1

  # Determine OS and architecture
  local os
  local arch

  case "$(uname -s)" in
    Linux*)  os="linux";;
    Darwin*) os="darwin";;
    MINGW*|MSYS*|CYGWIN*) os="windows";;
    *)
      echo -e "${RED}Unsupported operating system: $(uname -s)${RESET}" >&2
      rm -rf "$tmp_dir" # Clean up temp dir on failure
      return 1
      ;;
  esac

  case "$(uname -m)" in
    x86_64|amd64) arch="amd64";;
    arm64|aarch64) arch="arm64";;
    *)
      echo -e "${RED}Unsupported architecture: $(uname -m)${RESET}" >&2
      rm -rf "$tmp_dir" # Clean up temp dir on failure
      return 1
      ;;
  esac

  # Create bin directory if it doesn't exist
  safe_mkdir "$HOME/.local/bin" || return 1

  # Download OpenTofu
  local download_url="https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_${os}_${arch}.zip"
  echo "Downloading from: $download_url"

  if ! curl --fail -L "$download_url" -o "$tmp_dir/opentofu.zip"; then
    echo -e "${RED}Failed to download OpenTofu.${RESET}" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  # Extract OpenTofu
  if ! unzip -o "$tmp_dir/opentofu.zip" -d "$tmp_dir"; then
    echo -e "${RED}Failed to extract OpenTofu.${RESET}" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

  # Move to bin directory and make executable
  if ! mv "$tmp_dir/tofu" "$HOME/.local/bin/"; then
    echo -e "${RED}Failed to move OpenTofu to ~/.local/bin/${RESET}" >&2
    # Try sudo if mv fails without it (might need permissions)
    if ! sudo mv "$tmp_dir/tofu" /usr/local/bin/; then
       echo -e "${RED}Failed to move OpenTofu to system bin either. Check permissions.${RESET}" >&2
       rm -rf "$tmp_dir"
       return 1
    fi
     echo -e "${YELLOW}Installed OpenTofu to /usr/local/bin/ using sudo.${RESET}"
  fi

  # Check if tofu is now executable and in PATH
  local tofu_path
  if tofu_path=$(command -v tofu); then
      if [ -x "$tofu_path" ]; then
           echo -e "${GREEN}✓ OpenTofu found in PATH and is executable.${RESET}"
      else
          echo -e "${YELLOW}Making OpenTofu executable at $tofu_path...${RESET}"
          if ! chmod +x "$tofu_path"; then
              if ! sudo chmod +x "$tofu_path"; then
                  echo -e "${RED}Failed to make OpenTofu executable. Check permissions.${RESET}" >&2
                  rm -rf "$tmp_dir"
                  return 1
              fi
              echo -e "${YELLOW}Made OpenTofu executable using sudo.${RESET}"
          fi
      fi
  elif [ -x "$HOME/.local/bin/tofu" ]; then
       # Add ~/.local/bin to PATH if necessary
       if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
         echo -e "${YELLOW}Adding ~/.local/bin to PATH for current session and .bashrc${RESET}"
         # Use double quotes for variable expansion with >> redirection
         echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$HOME/.bashrc"
         # Export for current session
         export PATH="$HOME/.local/bin:$PATH"
       fi
  else
       echo -e "${RED}OpenTofu installed but not found in PATH. Please add it manually.${RESET}" >&2
       rm -rf "$tmp_dir"
       return 1
  fi


  # Clean up
  rm -rf "$tmp_dir"

  # Verify installation again
  if command -v tofu &> /dev/null; then
    echo -e "${GREEN}✓ OpenTofu installation verified successfully${RESET}"
    tofu version
    return 0
  else
    echo -e "${RED}Failed to verify OpenTofu installation. It's not available in the PATH.${RESET}" >&2
    return 1
  fi
}

# Load available cloud providers
load_providers() {
  echo -e "${BOLD}Loading available cloud providers...${RESET}"

  # Create providers directory if it doesn't exist
  safe_mkdir "$PROVIDERS_DIR" || {
    echo -e "${RED}Failed to create providers directory.${RESET}" >&2
    exit 1
  }

  # If providers directory is empty, create default providers
  if [ -z "$(ls -A "$PROVIDERS_DIR" 2>/dev/null)" ]; then
    echo -e "${YELLOW}No provider templates found. Creating defaults...${RESET}"
    create_default_providers || {
      echo -e "${RED}Failed to create default providers.${RESET}" >&2
      exit 1
    }
  fi

  # Load providers
  # Clear previous entries
  PROVIDERS=()
  PROVIDER_CATEGORIES=()
  PROVIDER_INDEX_MAP=()

  local provider_count=0
  local provider_files
  # Use process substitution and handle potential errors finding files
  mapfile -t provider_files < <(find "$PROVIDERS_DIR" -maxdepth 1 -name "*.json" -type f 2>/dev/null || echo "")

  if [ ${#provider_files[@]} -eq 0 ] || [ -z "${provider_files[0]}" ]; then
     echo -e "${YELLOW}No provider JSON files found in $PROVIDERS_DIR.${RESET}" >&2
     # Optionally create defaults again or exit
     echo -e "${YELLOW}Attempting to create default provider files...${RESET}"
     create_default_providers || {
       echo -e "${RED}Failed to create default providers. Exiting.${RESET}" >&2
       exit 1
     }
     # Reload after creating defaults
     mapfile -t provider_files < <(find "$PROVIDERS_DIR" -maxdepth 1 -name "*.json" -type f 2>/dev/null || echo "")
     if [ ${#provider_files[@]} -eq 0 ] || [ -z "${provider_files[0]}" ]; then
        echo -e "${RED}Still no provider files found after creating defaults. Exiting.${RESET}" >&2
        exit 1
     fi
  fi


  for provider_file in "${provider_files[@]}"; do
    # Skip if not a file (belt-and-suspenders)
    if [ ! -f "$provider_file" ]; then
      continue
    fi

    provider_key=$(basename "$provider_file" .json)

    # Try to read the provider file safely
    local provider_data
    if ! provider_data=$(cat "$provider_file"); then
      echo -e "${YELLOW}Warning: Failed to read provider file: $provider_file. Skipping.${RESET}" >&2
      continue
    fi

    # Try to parse the category using jq
    local category
    if ! category=$(echo "$provider_data" | jq -r '.category // "Major Cloud"' 2>/dev/null); then
      echo -e "${YELLOW}Warning: Failed to parse provider file '$provider_file' with jq or category missing. Using 'Other'. Skipping.${RESET}" >&2
      # Decide whether to skip or use default category
      # category="Other" # Use default if skipping is not desired
      continue
    fi

    PROVIDERS+=("$provider_key")
    PROVIDER_CATEGORIES["$provider_key"]="$category"
    ((provider_count++))
  done

  if [ ${#PROVIDERS[@]} -eq 0 ]; then
    echo -e "${RED}No valid cloud providers loaded. Please check the '$PROVIDERS_DIR' directory.${RESET}" >&2
    exit 1
  fi

  echo -e "${GREEN}✓ Found ${#PROVIDERS[@]} valid cloud providers${RESET}"
}

# Create default provider templates
create_default_providers() {
  echo -e "${YELLOW}Creating default provider templates...${RESET}"
  local success=true

  # Use single quotes for all JSON definitions to avoid unintended variable expansion
  # MAJOR CLOUD PROVIDERS
  if ! cat > "$PROVIDERS_DIR/aws.json" << 'EOF'
{
  "name": "AWS",
  "key": "aws",
  "description": "Amazon Web Services",
  "category": "Major Cloud",
  "variables": {
    "region": {
      "default": "us-west-2",
      "description": "AWS Region"
    },
    "profile": {
      "default": "default",
      "description": "AWS Profile"
    },
    "instance_type": {
      "default": "t3.micro",
      "description": "EC2 Instance Type"
    }
  },
  "backend": {
    "s3": {
      "bucket": "${project_name}-state",
      "key": "terraform.tfstate",
      "region": "${region}",
      "profile": "${profile}"
    }
  },
  "features": {
    "vpc": true,
    "rds": true,
    "lambda": true,
    "s3": true,
    "cloudfront": true,
    "route53": true,
    "ecs": true
  }
}
EOF
  then success=false; echo -e "${RED}Failed to create aws.json${RESET}" >&2; fi

  if ! cat > "$PROVIDERS_DIR/azure.json" << 'EOF'
{
  "name": "Azure",
  "key": "azure",
  "description": "Microsoft Azure",
  "category": "Major Cloud",
  "variables": {
    "location": {
      "default": "eastus",
      "description": "Azure Location"
    },
    "subscription_id": {
      "default": "",
      "description": "Azure Subscription ID (Required)"
    },
    "resource_group_name": {
      "default": "${project_name}-rg",
      "description": "Resource Group Name"
    }
  },
  "backend": {
    "azurerm": {
      "resource_group_name": "${resource_group_name}",
      "storage_account_name": "${project_name}state",
      "container_name": "tfstate",
      "key": "terraform.tfstate"
    }
  },
  "features": {
    "vnet": true,
    "vm": true,
    "app_service": true,
    "database": true,
    "storage": true,
    "cdn": true,
    "dns": true
  }
}
EOF
  then success=false; echo -e "${RED}Failed to create azure.json${RESET}" >&2; fi

  if ! cat > "$PROVIDERS_DIR/gcp.json" << 'EOF'
{
  "name": "GCP",
  "key": "gcp",
  "description": "Google Cloud Platform",
  "category": "Major Cloud",
  "variables": {
    "project_id": {
      "default": "",
      "description": "GCP Project ID (Required)"
    },
    "region": {
      "default": "us-central1",
      "description": "GCP Region"
    },
    "zone": {
      "default": "us-central1-a",
      "description": "GCP Zone"
    }
  },
  "backend": {
    "gcs": {
      "bucket": "${project_name}-state",
      "prefix": "terraform/state"
    }
  },
  "features": {
    "vpc": true,
    "compute": true,
    "cloud_run": true,
    "cloud_sql": true,
    "storage": true,
    "cloud_cdn": true,
    "dns": true
  }
}
EOF
  then success=false; echo -e "${RED}Failed to create gcp.json${RESET}" >&2; fi

  # SPECIALIZED CLOUD PROVIDERS
  if ! cat > "$PROVIDERS_DIR/digitalocean.json" << 'EOF'
{
  "name": "DigitalOcean",
  "key": "digitalocean",
  "description": "DigitalOcean Cloud",
  "category": "Specialized Cloud",
  "variables": {
    "region": {
      "default": "nyc3",
      "description": "DigitalOcean Region"
    },
    "droplet_size": {
      "default": "s-1vcpu-1gb",
      "description": "Droplet Size"
    },
    "github_username": {
        "default": "",
        "description": "GitHub Username (for App Platform)"
    },
    "github_repo": {
        "default": "",
        "description": "GitHub Repo Name (for App Platform)"
    }
  },
  "backend": {
    "s3": {
      "endpoint": "nyc3.digitaloceanspaces.com",
      "bucket": "${project_name}-state",
      "key": "terraform.tfstate",
      "region": "us-east-1",
      "skip_credentials_validation": true,
      "skip_metadata_api_check": true
    }
  },
  "features": {
    "vpc": true,
    "droplet": true,
    "kubernetes": true,
    "database": true,
    "spaces": true,
    "cdn": true,
    "domains": true,
    "app_platform": true
  }
}
EOF
  then success=false; echo -e "${RED}Failed to create digitalocean.json${RESET}" >&2; fi

  if ! cat > "$PROVIDERS_DIR/linode.json" << 'EOF'
{
  "name": "Linode",
  "key": "linode",
  "description": "Linode by Akamai",
  "category": "Specialized Cloud",
  "variables": {
    "region": {
      "default": "us-east",
      "description": "Linode Region"
    },
    "instance_type": {
      "default": "g6-nanode-1",
      "description": "Linode Instance Type"
    }
  },
  "backend": {
    "s3": {
      "endpoint": "us-east-1.linodeobjects.com",
      "bucket": "${project_name}-state",
      "key": "terraform.tfstate",
      "region": "us-east-1",
      "skip_credentials_validation": true,
      "skip_metadata_api_check": true
    }
  },
  "features": {
    "vpc": true,
    "instances": true,
    "kubernetes": true,
    "database": true,
    "object_storage": true
  }
}
EOF
  then success=false; echo -e "${RED}Failed to create linode.json${RESET}" >&2; fi

  if ! cat > "$PROVIDERS_DIR/ovh.json" << 'EOF'
{
  "name": "OVHcloud",
  "key": "ovh",
  "description": "OVHcloud - European Cloud Provider (Uses OpenStack Provider)",
  "category": "Specialized Cloud",
  "variables": {
    "region": {
      "default": "GRA7",
      "description": "OVH Region (e.g., GRA7, UK1, DE1)"
    },
    "flavor": {
      "default": "s1-2",
      "description": "OVH Instance Flavor (e.g., s1-2, b2-7)"
    },
    "image": {
        "default": "Ubuntu 22.04",
        "description": "OS Image Name"
    }
  },
  "backend": {
    "s3": {
      "endpoint": "s3.gra.io.cloud.ovh.net",
      "bucket": "${project_name}-state",
      "key": "terraform.tfstate",
      "region": "gra",
      "skip_credentials_validation": true,
      "skip_metadata_api_check": true
    }
  },
  "features": {
    "network": true,
    "compute": true,
    "storage": true,
    "database": true
  }
}
EOF
  then success=false; echo -e "${RED}Failed to create ovh.json${RESET}" >&2; fi

  # Hetzner Cloud - Note: `hcloud` is the correct key for the provider
  if ! cat > "$PROVIDERS_DIR/hcloud.json" << 'EOF'
{
  "name": "Hetzner",
  "key": "hcloud",
  "description": "Hetzner Cloud - German Cloud Provider",
  "category": "Specialized Cloud",
  "variables": {
    "location": {
      "default": "nbg1",
      "description": "Hetzner Location (e.g., nbg1, fsn1, hel1)"
    },
    "server_type": {
      "default": "cx11",
      "description": "Hetzner Server Type (e.g., cx11, cpx11)"
    }
  },
  "backend": {
    "local": {
      "path": "terraform.tfstate"
    }
  },
  "features": {
    "network": true,
    "servers": true,
    "volumes": true,
    "load_balancers": true,
    "firewalls": true
  }
}
EOF
  then success=false; echo -e "${RED}Failed to create hcloud.json${RESET}" >&2; fi

  # MANAGED APPLICATION PLATFORMS
  if ! cat > "$PROVIDERS_DIR/vercel.json" << 'EOF'
{
  "name": "Vercel",
  "key": "vercel",
  "description": "Vercel - Frontend Cloud Platform",
  "category": "Application Platform",
  "variables": {
    "project_name": {
      "default": "${project_name}",
      "description": "Vercel Project Name"
    },
    "framework": {
      "default": "nextjs",
      "description": "Framework (nextjs, react, vue, etc.)"
    },
    "domain_name": {
       "default": "",
       "description": "Custom Domain Name (Optional)"
    }
  },
  "backend": {
    "local": {
      "path": "terraform.tfstate"
    }
  },
  "features": {
    "project": true,
    "domains": true,
    "environment_variables": true,
    "preview": true
  }
}
EOF
  then success=false; echo -e "${RED}Failed to create vercel.json${RESET}" >&2; fi

  # Fly.io - Note: `fly` is the correct key for the provider
  if ! cat > "$PROVIDERS_DIR/fly.json" << 'EOF'
{
  "name": "Fly.io",
  "key": "fly",
  "description": "Fly.io - Edge Application Platform",
  "category": "Application Platform",
  "variables": {
    "app_name": {
      "default": "${project_name}",
      "description": "Fly.io App Name"
    },
    "region": {
      "default": "sjc",
      "description": "Primary Fly.io Region"
    },
    "vm_size": {
      "default": "shared-cpu-1x",
      "description": "VM Size (e.g., shared-cpu-1x, performance-1x)"
    },
    "image": {
      "default": "flyio/${project_name}:latest",
      "description": "Docker Image (e.g., user/repo:tag)"
    }
  },
  "backend": {
    "local": {
      "path": "terraform.tfstate"
    }
  },
  "features": {
    "app": true,
    "volumes": true,
    "ips": true,
    "certificates": true
  }
}
EOF
  then success=false; echo -e "${RED}Failed to create fly.json${RESET}" >&2; fi

  if ! cat > "$PROVIDERS_DIR/render.json" << 'EOF'
{
  "name": "Render",
  "key": "render",
  "description": "Render - Cloud Application Platform",
  "category": "Application Platform",
  "variables": {
    "service_name": {
      "default": "${project_name}",
      "description": "Render Service Name"
    },
    "service_type": {
      "default": "web",
      "description": "Service Type (web, static, background)"
    },
    "plan": {
      "default": "starter",
      "description": "Service Plan (e.g., starter, standard)"
    },
    "region": {
      "default": "oregon",
      "description": "Render Region (e.g., oregon, frankfurt)"
    }
  },
  "backend": {
    "local": {
      "path": "terraform.tfstate"
    }
  },
  "features": {
    "services": true,
    "static_sites": true,
    "databases": true,
    "env_groups": true
  }
}
EOF
  then success=false; echo -e "${RED}Failed to create render.json${RESET}" >&2; fi

  if ! cat > "$PROVIDERS_DIR/netlify.json" << 'EOF'
{
  "name": "Netlify",
  "key": "netlify",
  "description": "Netlify - Web Application Platform",
  "category": "Application Platform",
  "variables": {
    "site_name": {
      "default": "${project_name}",
      "description": "Netlify Site Name"
    },
    "build_command": {
      "default": "npm run build",
      "description": "Build Command"
    },
    "publish_directory": {
      "default": "dist",
      "description": "Publish Directory"
    },
     "domain_name": {
       "default": "",
       "description": "Custom Domain Name (Optional)"
    }
  },
  "backend": {
    "local": {
      "path": "terraform.tfstate"
    }
  },
  "features": {
    "site": true,
    "domain": true,
    "functions": true,
    "env": true
  }
}
EOF
  then success=false; echo -e "${RED}Failed to create netlify.json${RESET}" >&2; fi

  # PRIVACY-FOCUSED PROVIDERS
  # Infomaniak - Uses OpenStack provider
  if ! cat > "$PROVIDERS_DIR/infomaniak.json" << 'EOF'
{
  "name": "Infomaniak",
  "key": "openstack",
  "description": "Infomaniak Swiss Cloud - Privacy-Focused (Uses OpenStack Provider)",
  "category": "Privacy-Focused",
  "variables": {
    "region": {
      "default": "dc3-a",
      "description": "Infomaniak Region (e.g., dc3-a)"
    },
    "flavor": {
      "default": "a2-ram2-disk20-perf1",
      "description": "Instance Flavor"
    },
    "image": {
      "default": "Ubuntu 22.04",
      "description": "OS Image Name"
    }
  },
  "backend": {
    "local": {
      "path": "terraform.tfstate"
    }
  },
  "features": {
    "network": true,
    "instance": true,
    "volume": true,
    "security_group": true
  }
}
EOF
  then success=false; echo -e "${RED}Failed to create infomaniak.json${RESET}" >&2; fi

  if ! cat > "$PROVIDERS_DIR/exoscale.json" << 'EOF'
{
  "name": "Exoscale",
  "key": "exoscale",
  "description": "Exoscale - Swiss Privacy-Focused Cloud",
  "category": "Privacy-Focused",
  "variables": {
    "zone": {
      "default": "ch-gva-2",
      "description": "Exoscale Zone (e.g., ch-gva-2, de-fra-1)"
    },
    "instance_type": {
      "default": "standard.tiny",
      "description": "Instance Type (e.g., standard.tiny, standard.medium)"
    }
  },
  "backend": {
    "local": {
      "path": "terraform.tfstate"
    }
  },
  "features": {
    "compute": true,
    "database": true,
    "storage": true,
    "kubernetes": true
  }
}
EOF
  then success=false; echo -e "${RED}Failed to create exoscale.json${RESET}" >&2; fi

  # EDGE NETWORK
  if ! cat > "$PROVIDERS_DIR/cloudflare.json" << 'EOF'
{
  "name": "Cloudflare",
  "key": "cloudflare",
  "description": "Cloudflare - Edge Network",
  "category": "Edge Network",
  "variables": {
    "account_id": {
      "default": "",
      "description": "Cloudflare Account ID (Required)"
    },
    "zone_id": {
      "default": "",
      "description": "Cloudflare Zone ID (Required for DNS)"
    }
  },
  "backend": {
    "local": {
      "path": "terraform.tfstate"
    }
  },
  "features": {
    "dns": true,
    "workers": true,
    "pages": true,
    "r2": true,
    "d1": true,
    "kv": true
  }
}
EOF
  then success=false; echo -e "${RED}Failed to create cloudflare.json${RESET}" >&2; fi

  # Add OpenStack separately as it's used by OVH/Infomaniak but can be standalone
  if ! cat > "$PROVIDERS_DIR/openstack.json" << 'EOF'
{
  "name": "Generic OpenStack",
  "key": "openstack",
  "description": "Generic OpenStack Cloud",
  "category": "Specialized Cloud",
  "variables": {
    "region": {
      "default": "RegionOne",
      "description": "OpenStack Region"
    },
    "flavor": {
      "default": "m1.small",
      "description": "Instance Flavor Name"
    },
    "image": {
      "default": "Ubuntu 22.04",
      "description": "OS Image Name"
    }
  },
  "backend": {
    "local": {
      "path": "terraform.tfstate"
    }
  },
  "features": {
    "network": true,
    "compute": true,
    "storage": true
  }
}
EOF
   then success=false; echo -e "${RED}Failed to create openstack.json${RESET}" >&2; fi


  if $success; then
    echo -e "${GREEN}✓ Default provider templates created successfully${RESET}"
    return 0
  else
    echo -e "${RED}Errors occurred while creating default provider templates.${RESET}" >&2
    return 1
  fi
}

# Select cloud provider
select_provider() {
  echo -e "${BOLD}Available cloud providers:${RESET}"

  # Check if PROVIDERS is initialized
  if [ ${#PROVIDERS[@]} -eq 0 ]; then
    echo -e "${RED}No providers loaded. Ensure the providers directory exists and contains valid templates.${RESET}" >&2
    exit 1
  fi

  # Get all unique categories sorted alphabetically
  local sorted_categories
  mapfile -t sorted_categories < <(printf "%s\n" "${!PROVIDER_CATEGORIES[@]}" | sort -u)


  # Create an index map for selection
  PROVIDER_INDEX_MAP=() # Clear map

  # Display providers by category
  local counter=1
  for category in "${sorted_categories[@]}"; do
    echo -e "\n${BOLD}${BLUE}$category:${RESET}"

    for provider_key in "${PROVIDERS[@]}"; do
      # Check if the provider belongs to the current category
      if [[ "${PROVIDER_CATEGORIES[$provider_key]}" == "$category" ]]; then
        # Safely read the provider file
        local provider_file="$PROVIDERS_DIR/$provider_key.json"
        if [ -f "$provider_file" ]; then
          local provider_data
          local provider_name
          local provider_desc
          if ! provider_data=$(cat "$provider_file"); then
             echo -e "${YELLOW}Warning: Could not read $provider_file. Skipping.${RESET}" >&2
             continue
          fi
          if ! provider_name=$(echo "$provider_data" | jq -r '.name // "'$provider_key'"' 2>/dev/null); then
             provider_name="$provider_key" # Fallback name
          fi
           if ! provider_desc=$(echo "$provider_data" | jq -r '.description // "No description"' 2>/dev/null); then
             provider_desc="No description" # Fallback description
          fi

          echo -e "  ${BOLD}$counter.${RESET} $provider_name - $provider_desc"
          PROVIDER_INDEX_MAP[$counter]=$provider_key
          ((counter++))
        else
          echo -e "${YELLOW}Warning: Provider file $provider_file not found. Skipping.${RESET}" >&2
        fi
      fi
    done
  done

  echo
  # Prompt until valid input is received
  while true; do
      read -p "Select a cloud provider [1-$((counter-1))]: " provider_choice
      if [[ "$provider_choice" =~ ^[0-9]+$ ]] && [ "$provider_choice" -ge 1 ] && [ "$provider_choice" -lt "$counter" ]; then
          if [[ -v "PROVIDER_INDEX_MAP[$provider_choice]" ]]; then
              SELECTED_PROVIDER="${PROVIDER_INDEX_MAP[$provider_choice]}"
              echo -e "${GREEN}Selected provider: ${BOLD}$SELECTED_PROVIDER${RESET}"
              break # Exit loop on valid selection
          else
              echo -e "${RED}Internal error: Invalid index mapping. Please try again.${RESET}" >&2
          fi
      else
          echo -e "${RED}Invalid choice. Please enter a number between 1 and $((counter-1)).${RESET}" >&2
      fi
  done


  # Load provider configuration
  local selected_provider_file="$PROVIDERS_DIR/$SELECTED_PROVIDER.json"
  if [ -f "$selected_provider_file" ]; then
    if ! PROVIDER_CONFIG=$(cat "$selected_provider_file"); then
        echo -e "${RED}Failed to read provider config file: $selected_provider_file${RESET}" >&2
        exit 1
    fi
  else
    echo -e "${RED}Provider config file not found: $selected_provider_file${RESET}" >&2
    exit 1
  fi
}

# Configure project
configure_project() {
  echo -e "${BOLD}Configuring project...${RESET}"

  # Prompt for project name
  read -p "Enter project name [default: myproject]: " PROJECT_NAME_INPUT
  PROJECT_NAME_INPUT=${PROJECT_NAME_INPUT:-myproject}

  # Sanitize project name (allow alphanumeric, hyphen, underscore; start/end alphanumeric)
  PROJECT_NAME=$(echo "$PROJECT_NAME_INPUT" | sed -e 's/[^[:alnum:]_-]//g' -e 's/^[^[:alnum:]]*//' -e 's/[^[:alnum:]]*$//')
  # Replace consecutive hyphens/underscores with a single one
  PROJECT_NAME=$(echo "$PROJECT_NAME" | sed -e 's/[-_][-_]*/-/g')
  # Ensure it's not empty
  if [ -z "$PROJECT_NAME" ]; then
    echo -e "${YELLOW}Project name was invalid after sanitization. Using 'my-project' instead.${RESET}"
    PROJECT_NAME="my-project"
  fi
  echo -e "Using sanitized project name: ${CYAN}$PROJECT_NAME${RESET}"


  # Define and create project directory
  PROJECT_DIR="${PROJECT_DIR_BASE}/${PROJECT_NAME}"
  safe_mkdir "$PROJECT_DIR" || {
    echo -e "${RED}Failed to create project directory: $PROJECT_DIR${RESET}" >&2
    exit 1
  }

  # Configure provider variables
  echo -e "${BOLD}Configuring ${SELECTED_PROVIDER}...${RESET}"

  # Get provider variables safely
  if ! PROVIDER_VARS=$(echo "$PROVIDER_CONFIG" | jq -r '.variables // {}'); then
    echo -e "${RED}Failed to parse variables from provider configuration.${RESET}" >&2
    # Exit or continue with empty variables? Exiting is safer.
    exit 1
  fi

  # Prompt for each variable
  VARS_JSON="{}"

  # Get variable names safely
  local var_names
  mapfile -t var_names < <(echo "$PROVIDER_VARS" | jq -r 'keys[]' 2>/dev/null || echo "")

  # Process each variable
  if [ ${#var_names[@]} -gt 0 ] && [ -n "${var_names[0]}" ]; then
      for var_name in "${var_names[@]}"; do
        # Extract variable properties safely
        local var_default
        local var_desc
        # Use jq's --arg for safety against injection in variable names
        if ! var_default=$(echo "$PROVIDER_VARS" | jq -r --arg name "$var_name" '.[$name].default // ""' 2>/dev/null); then
          var_default=""
        fi
        if ! var_desc=$(echo "$PROVIDER_VARS" | jq -r --arg name "$var_name" '.[$name].description // "No description"' 2>/dev/null); then
          var_desc="No description"
        fi

        # Replace ${project_name} in default value - Use Bash substitution
        var_default="${var_default//\$\{project_name\}/$PROJECT_NAME}"
        # Replace ${region} etc. if needed (though better done during TF apply)
        # Example: var_default="${var_default//\$\{region\}/${SOME_OTHER_VAR:-}}"

        read -p "$var_desc [$var_default]: " var_value
        # Use provided value or the processed default
        var_value=${var_value:-$var_default}

        # Update variables JSON using jq safely
        if ! VARS_JSON=$(echo "$VARS_JSON" | jq --arg name "$var_name" --arg value "$var_value" '. + {($name): $value}'); then
            echo -e "${RED}Failed to update variables JSON for '$var_name'.${RESET}" >&2
            # Decide whether to exit or continue
            exit 1
        fi
      done
  else
      echo -e "${YELLOW}No variables defined for this provider in its JSON config.${RESET}"
  fi

  # Ask about Caddy integration
  read -p "Enable Caddy server for web hosting (requires self-hosted VM)? [y/N]: " enable_caddy
  if [[ "$enable_caddy" =~ ^[Yy]$ ]]; then
    CADDY_ENABLED=true

    # Prompt for domain
    read -p "Enter domain name for Caddy (e.g., example.com): " DOMAIN_NAME_INPUT
    if [ -z "$DOMAIN_NAME_INPUT" ]; then
      echo -e "${YELLOW}Warning: No domain name provided. Using 'example.com' for Caddyfile. Please update later.${RESET}"
      DOMAIN_NAME="example.com"
    else
       DOMAIN_NAME="$DOMAIN_NAME_INPUT" # Basic validation could be added here
    fi
    # Add to TF variables only if not already present (some providers might have it)
    if ! echo "$VARS_JSON" | jq -e '.domain_name' > /dev/null; then
       VARS_JSON=$(echo "$VARS_JSON" | jq --arg domain "$DOMAIN_NAME" '. + {"domain_name": $domain}')
    fi


    # Ask about email for Let's Encrypt
    read -p "Email address for Let's Encrypt SSL certificates: " EMAIL_INPUT
    if [ -z "$EMAIL_INPUT" ]; then
      echo -e "${YELLOW}Warning: No email provided for Let's Encrypt. Using 'admin@$DOMAIN_NAME'. Please update later.${RESET}"
      EMAIL="admin@$DOMAIN_NAME"
    else
      EMAIL="$EMAIL_INPUT" # Basic email validation could be added here
    fi
     # Add to TF variables only if not already present
    if ! echo "$VARS_JSON" | jq -e '.email' > /dev/null; then
        VARS_JSON=$(echo "$VARS_JSON" | jq --arg email "$EMAIL" '. + {"email": $email}')
    fi
  else
    CADDY_ENABLED=false
  fi

  # Configure repository transfer (for client handover)
  read -p "Configure repository transfer for client handover? [y/N]: " enable_repo_transfer
  if [[ "$enable_repo_transfer" =~ ^[Yy]$ ]]; then
    REPO_TRANSFER_ENABLED=true

    # Check for gh CLI specifically for this feature
    check_command "gh" "Install GitHub CLI from https://cli.github.com/" || {
        echo -e "${YELLOW}GitHub CLI 'gh' not found. Skipping repository transfer setup.${RESET}" >&2
        REPO_TRANSFER_ENABLED=false
    }

    if $REPO_TRANSFER_ENABLED; then
        # Current repo info
        read -p "Your GitHub username or organization: " GITHUB_USERNAME_INPUT
        GITHUB_USERNAME=${GITHUB_USERNAME_INPUT:-"developer"}
        if [ "$GITHUB_USERNAME" == "developer" ]; then echo -e "${YELLOW}Using default source username 'developer'.${RESET}"; fi

        read -p "Current private repository name: " PRIVATE_REPO_INPUT
        PRIVATE_REPO=${PRIVATE_REPO_INPUT:-"$PROJECT_NAME-repo"}
         if [ "$PRIVATE_REPO" == "$PROJECT_NAME-repo" ]; then echo -e "${YELLOW}Using default source repo name '$PRIVATE_REPO'.${RESET}"; fi

        # Client repo info
        read -p "Client's GitHub username or organization: " CLIENT_GITHUB_USERNAME_INPUT
        CLIENT_GITHUB_USERNAME=${CLIENT_GITHUB_USERNAME_INPUT:-"client"}
         if [ "$CLIENT_GITHUB_USERNAME" == "client" ]; then echo -e "${YELLOW}Using default destination username 'client'.${RESET}"; fi


        read -p "Repository name for client: " CLIENT_REPO_INPUT
        CLIENT_REPO=${CLIENT_REPO_INPUT:-"$PROJECT_NAME"}
        if [ "$CLIENT_REPO" == "$PROJECT_NAME" ]; then echo -e "${YELLOW}Using default destination repo name '$CLIENT_REPO'.${RESET}"; fi

        # Permissions management
        read -p "Give client admin access to the project? [y/N]: " ADMIN_ACCESS
        if [[ "$ADMIN_ACCESS" =~ ^[Yy]$ ]]; then
          CLIENT_ROLE="admin"
        else
          CLIENT_ROLE="maintain"
        fi

        # Save repo transfer info - Using heredoc with quoted EOF to prevent variable expansion
        # Need to escape potential special characters in variables for JSON validity
        # Using jq is safer here
        if ! REPO_TRANSFER_INFO=$(jq -n \
              --arg su "$GITHUB_USERNAME" --arg sr "$PRIVATE_REPO" \
              --arg du "$CLIENT_GITHUB_USERNAME" --arg dr "$CLIENT_REPO" \
              --arg cr "$CLIENT_ROLE" \
              '{source: {username: $su, repo: $sr}, destination: {username: $du, repo: $dr}, permissions: {role: $cr}}'); then
           echo -e "${RED}Failed to create repo transfer JSON.${RESET}" >&2
           REPO_TRANSFER_ENABLED=false # Disable if JSON creation fails
        fi
    fi
  else
     REPO_TRANSFER_ENABLED=false
  fi

  # Ask about billing model (for client projects)
  read -p "Configure recurring billing for client? [y/N]: " enable_billing
  if [[ "$enable_billing" =~ ^[Yy]$ ]]; then
    BILLING_ENABLED=true

    # Check for bc CLI specifically for this feature
    check_command "bc" "Install 'bc' for calculations (e.g., apt-get install bc)" || {
        echo -e "${YELLOW}'bc' command not found. Billing calculations in generated scripts might fail.${RESET}" >&2
        # Don't disable billing, just warn
    }
     # Check for pandoc CLI for PDF generation
     if ! check_command "pandoc" "Install 'pandoc' for optional PDF invoice generation"; then
        echo -e "${YELLOW}'pandoc' command not found. Optional PDF invoice generation will be unavailable.${RESET}" >&2
     fi


    # Billing model
    echo -e "${BOLD}Select billing model:${RESET}"
    echo "1. Fixed monthly fee (you handle all infrastructure costs)"
    echo "2. Pass-through (client pays infrastructure costs directly)"
    echo "3. Hybrid (fixed fee + percentage of infrastructure costs)"
    read -p "Select billing model [1-3]: " billing_model

    case $billing_model in
      1) BILLING_TYPE="fixed" ;;
      2) BILLING_TYPE="passthrough" ;;
      3) BILLING_TYPE="hybrid" ;;
      *)
         echo -e "${YELLOW}Invalid choice. Using fixed billing model.${RESET}"
         BILLING_TYPE="fixed"
         ;;
    esac

    # Initialize fee/percentage variables
    MONTHLY_FEE="0"
    COST_PERCENTAGE="0"

    if [[ "$BILLING_TYPE" == "fixed" || "$BILLING_TYPE" == "hybrid" ]]; then
      read -p "Monthly fee amount (e.g., 100.00): " MONTHLY_FEE_INPUT
      # Validate input is a non-negative number
      if [[ "$MONTHLY_FEE_INPUT" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
         MONTHLY_FEE="$MONTHLY_FEE_INPUT"
      else
         echo -e "${YELLOW}Invalid amount. Using 0 as default monthly fee.${RESET}"
         MONTHLY_FEE="0"
      fi
    fi

    if [[ "$BILLING_TYPE" == "hybrid" ]]; then
      read -p "Percentage markup on infrastructure costs (e.g., 10): " COST_PERCENTAGE_INPUT
      # Validate input is a non-negative number
       if [[ "$COST_PERCENTAGE_INPUT" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
         COST_PERCENTAGE="$COST_PERCENTAGE_INPUT"
      else
         echo -e "${YELLOW}Invalid percentage. Using 0% as default markup.${RESET}"
         COST_PERCENTAGE="0"
      fi
    fi

    # Save billing info using jq for safety
     if ! BILLING_INFO=$(jq -n \
           --arg bt "$BILLING_TYPE" \
           --arg mf "$MONTHLY_FEE" \
           --arg cp "$COST_PERCENTAGE" \
           '{model: $bt, monthly_fee: $mf, cost_percentage: $cp, billing_day: "1", currency: "USD"}'); then
        echo -e "${RED}Failed to create billing info JSON.${RESET}" >&2
        BILLING_ENABLED=false # Disable if JSON creation fails
     fi
  else
      BILLING_ENABLED=false
  fi

  # Configure state backend
  echo -e "${BOLD}Configuring state backend...${RESET}"
  echo "1. Local (not recommended for team/production use)"
  echo "2. Remote (recommended)"
  read -p "Select state backend [1-2]: " backend_choice

  if [ "$backend_choice" == "2" ]; then
    STATE_BACKEND="remote"

    # Get backend configuration from provider safely
    if ! BACKEND_CONFIG=$(echo "$PROVIDER_CONFIG" | jq -r '.backend // {}'); then
      echo -e "${RED}Failed to parse backend configuration. Falling back to local state.${RESET}" >&2
      STATE_BACKEND="local"
    else
      # Get backend type safely
      if ! BACKEND_TYPE=$(echo "$BACKEND_CONFIG" | jq -r 'keys[0] // ""' 2>/dev/null) || [ -z "$BACKEND_TYPE" ]; then
        echo -e "${YELLOW}No remote backend type defined for $SELECTED_PROVIDER. Falling back to local state.${RESET}" >&2
        STATE_BACKEND="local"
      else
        # Get backend settings safely
        if ! BACKEND_SETTINGS=$(echo "$BACKEND_CONFIG" | jq -r ".[\"$BACKEND_TYPE\"] // {}"); then
          echo -e "${RED}Failed to parse backend settings for type '$BACKEND_TYPE'. Falling back to local state.${RESET}" >&2
          STATE_BACKEND="local"
        else
          # Check if backend settings are empty
          if [ "$(echo "$BACKEND_SETTINGS" | jq 'length')" -eq 0 ]; then
             echo -e "${YELLOW}Remote backend settings for '$BACKEND_TYPE' are empty. Falling back to local state.${RESET}" >&2
             STATE_BACKEND="local"
          else
            # Replace variables in backend settings - This part is tricky, needs careful expansion
            # Create a temporary string for modification
            temp_backend_settings_str=$(echo "$BACKEND_SETTINGS" | jq -c .)

            # Loop through TF variables and project name for substitution
            # Use a robust method like sed or perl if simple substitution fails
             temp_backend_settings_str="${temp_backend_settings_str//\$\{project_name\}/$PROJECT_NAME}"

             local var_names_for_backend
             mapfile -t var_names_for_backend < <(echo "$VARS_JSON" | jq -r 'keys[]' 2>/dev/null || echo "")

             if [ ${#var_names_for_backend[@]} -gt 0 ] && [ -n "${var_names_for_backend[0]}" ]; then
                 for var_name_bk in "${var_names_for_backend[@]}"; do
                    local var_value_bk
                    var_value_bk=$(echo "$VARS_JSON" | jq -r --arg name "$var_name_bk" '.[$name]')
                    # Use delimiter that's unlikely to appear in values/keys
                    # Using sed might be more robust than bash substitution here
                    # Note: This assumes simple string replacement is sufficient. Complex cases might break.
                    temp_backend_settings_str=$(echo "$temp_backend_settings_str" | sed "s|\${${var_name_bk}}|${var_value_bk}|g")
                 done
             fi

             # Convert back to pretty JSON for storage (optional, but cleaner)
             BACKEND_SETTINGS=$(echo "$temp_backend_settings_str" | jq .)
             echo -e "${GREEN}Configured remote backend: ${BOLD}$BACKEND_TYPE${RESET}"
          fi
        fi
      fi
    fi
  else
    STATE_BACKEND="local"
    echo -e "${GREEN}Configured local state backend.${RESET}"
  fi

  # Configure hosting options
  # Define lists of providers for easier management
  local self_host_providers=("aws" "gcp" "azure" "digitalocean" "linode" "hcloud" "ovh" "exoscale" "infomaniak" "openstack")
  local managed_platform_providers=("vercel" "netlify" "render" "fly" "cloudflare")

  # Check if the selected provider is in the self-host list
  local is_self_host_provider=false
  for p in "${self_host_providers[@]}"; do
    if [[ "$SELECTED_PROVIDER" == "$p" ]]; then
      is_self_host_provider=true
      break
    fi
  done

  # Check if the selected provider is primarily a managed platform
  local is_managed_platform=false
   for p in "${managed_platform_providers[@]}"; do
    if [[ "$SELECTED_PROVIDER" == "$p" ]]; then
      is_managed_platform=true
      break
    fi
  done

  # Determine hosting type based on provider type
  if $is_managed_platform; then
      HOSTING_TYPE="managed"
      echo -e "${CYAN}Provider '$SELECTED_PROVIDER' primarily uses managed services. Setting hosting type to 'managed'.${RESET}"
  elif $is_self_host_provider; then
      echo -e "${BOLD}Configuring hosting options for $SELECTED_PROVIDER...${RESET}"
      echo "1. Self-hosted (VMs, basic instances)"
      echo "2. Managed services (e.g., S3/CloudFront, App Service, Cloud Run, App Platform - if available)"
      read -p "Select hosting type [1-2, default 1]: " hosting_choice

      if [ "$hosting_choice" == "2" ]; then
        # Check if the provider actually supports a managed option in our templates
        # This check is rudimentary; ideally, the provider JSON would declare this capability
        case $SELECTED_PROVIDER in
           aws|azure|gcp|digitalocean|cloudflare) # Added Cloudflare here as it has Pages
             HOSTING_TYPE="managed"
             echo -e "${GREEN}Selected managed service hosting.${RESET}"
             ;;
           *)
             echo -e "${YELLOW}Managed service option not explicitly defined for '$SELECTED_PROVIDER' in this script. Defaulting to self-hosted.${RESET}" >&2
             HOSTING_TYPE="self"
             ;;
        esac
      else
        HOSTING_TYPE="self"
        echo -e "${GREEN}Selected self-hosted infrastructure.${RESET}"
      fi
  else
       # Fallback for providers not explicitly listed
       echo -e "${YELLOW}Hosting type decision unclear for provider '$SELECTED_PROVIDER'. Defaulting to self-hosted.${RESET}" >&2
       HOSTING_TYPE="self"
  fi

  # Final check for Caddy with managed hosting (doesn't make sense)
  if $CADDY_ENABLED && [ "$HOSTING_TYPE" == "managed" ]; then
     echo -e "${YELLOW}Warning: Caddy integration is enabled but hosting type is 'managed'. Caddy usually requires a self-hosted VM. Disabling Caddy.${RESET}" >&2
     CADDY_ENABLED=false
     # Remove Caddy variables if they were added
     VARS_JSON=$(echo "$VARS_JSON" | jq 'del(.domain_name) | del(.email)')
  fi

  # --- Generate Project Files ---

  # Save configuration first
  if ! save_configuration; then
    echo -e "${RED}Failed to save configuration. Aborting file generation.${RESET}" >&2
    exit 1
  fi

  # Generate OpenTofu files
  if ! generate_tofu_files; then
    echo -e "${RED}Failed to generate OpenTofu files.${RESET}" >&2
    # Exit or allow continuation? Exiting is safer if core TF files fail.
    exit 1
  fi

  # Generate repository transfer scripts if enabled
  if $REPO_TRANSFER_ENABLED; then
    if ! generate_repo_transfer_scripts; then
      # Don't exit on non-critical script generation failure, just warn
      echo -e "${YELLOW}Warning: Failed to generate repository transfer scripts.${RESET}" >&2
    fi
  fi

  # Generate billing documentation if enabled
  if $BILLING_ENABLED; then
    if ! generate_billing_docs; then
      # Don't exit on non-critical script generation failure, just warn
      echo -e "${YELLOW}Warning: Failed to generate billing documentation.${RESET}" >&2
    fi
  fi

  echo -e "${GREEN}✓ Project configuration and file generation complete.${RESET}"
}


# Save configuration - with error handling
save_configuration() {
  echo -e "${BOLD}Saving configuration...${RESET}"
  local success=true

  # Create configuration file (.cloud-deploy.conf)
  # Ensure variables are correctly expanded here
  if ! cat > "$PROJECT_DIR/$CONFIG_FILE" << EOF
PROJECT_NAME="${PROJECT_NAME}"
SELECTED_PROVIDER="${SELECTED_PROVIDER}"
CADDY_ENABLED=${CADDY_ENABLED}
STATE_BACKEND="${STATE_BACKEND}"
HOSTING_TYPE="${HOSTING_TYPE:-self}"
DOMAIN_NAME="${DOMAIN_NAME:-}"
REPO_TRANSFER_ENABLED=${REPO_TRANSFER_ENABLED}
BILLING_ENABLED=${BILLING_ENABLED:-false}
EOF
  then
    echo -e "${RED}Failed to create configuration file: $PROJECT_DIR/$CONFIG_FILE${RESET}" >&2
    success=false
  fi

  # Save variables (terraform.tfvars.json) - jq ensures valid JSON
  if ! echo "$VARS_JSON" | jq '.' > "$PROJECT_DIR/terraform.tfvars.json"; then
    echo -e "${RED}Failed to save variables file: $PROJECT_DIR/terraform.tfvars.json${RESET}" >&2
    success=false
  fi

  # Save repository transfer info if enabled (.repo-transfer.json)
  if $REPO_TRANSFER_ENABLED; then
     # Check if REPO_TRANSFER_INFO is valid JSON before writing
     if echo "$REPO_TRANSFER_INFO" | jq -e . > /dev/null 2>&1; then
        if ! echo "$REPO_TRANSFER_INFO" | jq '.' > "$PROJECT_DIR/.repo-transfer.json"; then
          echo -e "${YELLOW}Warning: Failed to save repository transfer info: $PROJECT_DIR/.repo-transfer.json${RESET}" >&2
          # Don't mark as failure, it's optional data
        fi
     else
         echo -e "${YELLOW}Warning: Repository transfer info was not valid JSON. Skipping save.${RESET}" >&2
     fi
  fi

  # Save billing info if enabled (.billing.json)
  if $BILLING_ENABLED; then
     # Check if BILLING_INFO is valid JSON before writing
      if echo "$BILLING_INFO" | jq -e . > /dev/null 2>&1; then
        if ! echo "$BILLING_INFO" | jq '.' > "$PROJECT_DIR/.billing.json"; then
          echo -e "${YELLOW}Warning: Failed to save billing info: $PROJECT_DIR/.billing.json${RESET}" >&2
           # Don't mark as failure, it's optional data
        fi
     else
          echo -e "${YELLOW}Warning: Billing info was not valid JSON. Skipping save.${RESET}" >&2
     fi
  fi

  if $success; then
     echo -e "${GREEN}✓ Configuration saved successfully${RESET}"
     return 0
  else
     echo -e "${RED}Errors occurred while saving configuration.${RESET}" >&2
     return 1
  fi
}

# Generate OpenTofu files - with enhanced error handling
generate_tofu_files() {
  echo -e "${BOLD}Generating OpenTofu files...${RESET}"
  local success=true

  # --- versions.tf ---
  if ! cat > "$PROJECT_DIR/versions.tf" << 'EOF'
terraform {
  required_version = ">= 1.0.0"
  required_providers {
EOF
  then
    echo -e "${RED}Failed to create versions.tf file.${RESET}" >&2; success=false
  fi

  # Add provider requirement based on selected provider key
  # Use single quotes for heredoc as no expansion needed here
  case $SELECTED_PROVIDER in
    aws) provider_block='
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }' ;;
    azure) provider_block='
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }' ;;
    gcp) provider_block='
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }' ;;
    digitalocean) provider_block='
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }' ;;
    linode) provider_block='
    linode = {
      source  = "linode/linode"
      version = "~> 2.0"
    }' ;;
    hcloud) provider_block='
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.0"
    }' ;;
    ovh | openstack | infomaniak) provider_block='
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.0" # Check for latest compatible version
    }' ;;
    exoscale) provider_block='
    exoscale = {
      source  = "exoscale/exoscale"
      version = "~> 0.48" # Check for latest
    }' ;;
    vercel) provider_block='
    vercel = {
      source  = "vercel/vercel"
      version = "~> 0.15" # Check for latest
    }' ;;
    fly) provider_block='
    fly = {
      source  = "fly-apps/fly"
      version = "~> 0.0.23" # Check for latest
    }' ;;
    render) provider_block='
    render = {
      source  = "render-oss/render"
      version = "~> 0.0.1" # Check for latest
    }' ;;
    netlify) provider_block='
    netlify = {
      source  = "netlify/netlify"
      version = "~> 0.7" # Check for latest
    }' ;;
    cloudflare) provider_block='
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }' ;;
    *)
      echo -e "${YELLOW}Warning: Unknown provider '$SELECTED_PROVIDER' for versions.tf. No provider block added.${RESET}" >&2
      provider_block=""
      ;;
  esac

  if [ -n "$provider_block" ]; then
      if ! echo "$provider_block" >> "$PROJECT_DIR/versions.tf"; then
           echo -e "${RED}Failed to add provider block to versions.tf.${RESET}" >&2; success=false
      fi
  fi

  # Add Caddy provider if enabled
  if $CADDY_ENABLED; then
    if ! cat >> "$PROJECT_DIR/versions.tf" << 'EOF'
    caddy = {
      source  = "greenpau/caddy"
      version = "~> 0.1" # Check for latest
    }
EOF
    then
      echo -e "${RED}Failed to add Caddy provider to versions.tf.${RESET}" >&2; success=false
    fi
  fi

  # Close versions.tf providers block
  if ! echo "  }" >> "$PROJECT_DIR/versions.tf"; then
     echo -e "${RED}Failed to close providers block in versions.tf.${RESET}" >&2; success=false
  fi
  # Close versions.tf main block
   if ! echo "}" >> "$PROJECT_DIR/versions.tf"; then
     echo -e "${RED}Failed to close main block in versions.tf.${RESET}" >&2; success=false
  fi


  # --- providers.tf ---
  if ! cat > "$PROJECT_DIR/providers.tf" << EOF
# Provider configuration for $SELECTED_PROVIDER
# Credentials typically loaded from environment variables or config files
EOF
  then
    echo -e "${RED}Failed to create providers.tf file.${RESET}" >&2; success=false
  fi

  # Add provider-specific configuration block
  # Use single quotes for heredocs as expansion is mostly based on `var.*` which happens at runtime
  case $SELECTED_PROVIDER in
    aws) provider_conf='
provider "aws" {
  region  = var.region
  # profile = var.profile # Uncomment if using profiles, ensure var.profile exists
}' ;;
    azure) provider_conf='
provider "azurerm" {
  features {}
  # subscription_id = var.subscription_id # Uncomment if needed, ensure var.subscription_id exists
}' ;;
    gcp) provider_conf='
provider "google" {
  project = var.project_id
  region  = var.region
  # zone    = var.zone # Zone might be resource-specific
}' ;;
    digitalocean) provider_conf='
provider "digitalocean" {
  # Token loaded from DO_TOKEN env var
}' ;;
    linode) provider_conf='
provider "linode" {
  # Token loaded from LINODE_TOKEN env var
}' ;;
    hcloud) provider_conf='
provider "hcloud" {
  # Token loaded from HCLOUD_TOKEN env var
}' ;;
    ovh | openstack | infomaniak ) provider_conf='
provider "openstack" {
  # Credentials loaded from OS_* env vars or clouds.yaml
  # region = var.region # Optional: ensure var.region exists if needed
}' ;;
    exoscale) provider_conf='
provider "exoscale" {
  # API keys loaded from EXOSCALE_API_KEY/SECRET env vars
  # Or use config file
}' ;;
    vercel) provider_conf='
provider "vercel" {
  # Token loaded from VERCEL_API_TOKEN env var
}' ;;
    fly) provider_conf='
provider "fly" {
  # Token loaded from FLY_API_TOKEN env var
  # useinternaltunnel = true # May be needed in some environments
}' ;;
    render) provider_conf='
provider "render" {
  # API key loaded from RENDER_API_KEY env var
}' ;;
    netlify) provider_conf='
provider "netlify" {
  # Token loaded from NETLIFY_AUTH_TOKEN env var
}' ;;
    cloudflare) provider_conf='
provider "cloudflare" {
  # API token loaded from CLOUDFLARE_API_TOKEN env var
  # Or email/api_key
  # account_id = var.account_id # Required for many resources
}' ;;
     *)
      echo -e "${YELLOW}Warning: Unknown provider '$SELECTED_PROVIDER' for providers.tf.${RESET}" >&2
      provider_conf=""
      ;;
  esac

   if [ -n "$provider_conf" ]; then
      if ! echo "$provider_conf" >> "$PROJECT_DIR/providers.tf"; then
           echo -e "${RED}Failed to add provider config block to providers.tf.${RESET}" >&2; success=false
      fi
  fi


  # Add Caddy provider configuration if enabled
  if $CADDY_ENABLED; then
    if ! cat >> "$PROJECT_DIR/providers.tf" << 'EOF'

provider "caddy" {
  address = "localhost:2019" # Assumes Caddy admin API runs locally
}
EOF
    then
      echo -e "${RED}Failed to add Caddy provider config to providers.tf.${RESET}" >&2; success=false
    fi
  fi

  # --- backend.tf ---
  if [ "$STATE_BACKEND" == "remote" ] && [ -n "$BACKEND_TYPE" ] && [ "$BACKEND_SETTINGS" != "{}" ]; then
      # Start backend.tf
      if ! cat > "$PROJECT_DIR/backend.tf" << EOF
# State backend configuration for $SELECTED_PROVIDER ($BACKEND_TYPE)
terraform {
  backend "$BACKEND_TYPE" {
EOF
      then
        echo -e "${RED}Failed to create remote backend.tf file.${RESET}" >&2; success=false
      fi

      # Add backend settings from the processed JSON
      local backend_keys
      mapfile -t backend_keys < <(echo "$BACKEND_SETTINGS" | jq -r 'keys[]' 2>/dev/null || echo "")

      if [ ${#backend_keys[@]} -gt 0 ] && [ -n "${backend_keys[0]}" ]; then
          for key in "${backend_keys[@]}"; do
            local value
            # Extract value safely
            if ! value=$(echo "$BACKEND_SETTINGS" | jq -r --arg k "$key" '.[$k]' 2>/dev/null); then
               echo -e "${YELLOW}Warning: Could not get value for backend key '$key'. Skipping.${RESET}" >&2
               continue
            fi

            # Format value: booleans without quotes, strings with quotes
            local formatted_value
            if [[ "$value" == "true" || "$value" == "false" ]]; then
              formatted_value="$value"
            else
              # Escape double quotes within the value for HCL string literal
              value_escaped=${value//\"/\\\"}
              formatted_value="\"$value_escaped\""
            fi

            # Append setting to backend.tf
            if ! echo "    $key = $formatted_value" >> "$PROJECT_DIR/backend.tf"; then
              echo -e "${RED}Failed to write backend setting '$key' to backend.tf.${RESET}" >&2; success=false
            fi
          done
      else
           echo -e "${YELLOW}Warning: No keys found in backend settings JSON. Backend block might be incomplete.${RESET}" >&2
      fi

       # Close backend block and file
      if ! echo "  }" >> "$PROJECT_DIR/backend.tf"; then
         echo -e "${RED}Failed to close backend block in backend.tf.${RESET}" >&2; success=false
      fi
       if ! echo "}" >> "$PROJECT_DIR/backend.tf"; then
         echo -e "${RED}Failed to close terraform block in backend.tf.${RESET}" >&2; success=false
      fi

  else # Local state backend
    if ! cat > "$PROJECT_DIR/backend.tf" << 'EOF'
# Using local state (not recommended for team/production use)
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
EOF
    then
      echo -e "${RED}Failed to create local backend.tf file.${RESET}" >&2; success=false
    fi
  fi

  # --- variables.tf ---
  if ! cat > "$PROJECT_DIR/variables.tf" << EOF
# Variables for $PROJECT_NAME on $SELECTED_PROVIDER
EOF
  then
    echo -e "${RED}Failed to create variables.tf file.${RESET}" >&2; success=false
  fi

  # Add variables based on provider JSON config
  local var_tf_names
  mapfile -t var_tf_names < <(echo "$PROVIDER_VARS" | jq -r 'keys[]' 2>/dev/null || echo "")

  if [ ${#var_tf_names[@]} -gt 0 ] && [ -n "${var_tf_names[0]}" ]; then
      for var_name in "${var_tf_names[@]}"; do
        local var_desc
        # Extract description safely
        if ! var_desc=$(echo "$PROVIDER_VARS" | jq -r --arg name "$var_name" '.[$name].description // "No description"' 2>/dev/null); then
          var_desc="No description"
        fi
        # Escape double quotes in description for HCL string literal
        var_desc_escaped=${var_desc//\"/\\\"}

        # Append variable block
        # Use single quotes for heredoc
        if ! cat >> "$PROJECT_DIR/variables.tf" << EOF

variable "$var_name" {
  description = "$var_desc_escaped"
  type        = string # Assuming string type for simplicity, could enhance later
  # default = "" # Defaults are usually set in terraform.tfvars.json
}
EOF
        then
          echo -e "${RED}Failed to add variable '$var_name' to variables.tf.${RESET}" >&2; success=false
        fi
      done
  fi

  # Add Caddy variables if enabled
  if $CADDY_ENABLED; then
    # Only add if not already defined by the provider config
    if ! grep -q 'variable "domain_name"' "$PROJECT_DIR/variables.tf"; then
        if ! cat >> "$PROJECT_DIR/variables.tf" << 'EOF'

variable "domain_name" {
  description = "Domain name for the website (used by Caddy)"
  type        = string
}
EOF
        then echo -e "${RED}Failed to add Caddy domain_name variable.${RESET}" >&2; success=false; fi
    fi
    if ! grep -q 'variable "email"' "$PROJECT_DIR/variables.tf"; then
       if ! cat >> "$PROJECT_DIR/variables.tf" << 'EOF'

variable "email" {
  description = "Email address for Let's Encrypt (used by Caddy)"
  type        = string
}
EOF
       then echo -e "${RED}Failed to add Caddy email variable.${RESET}" >&2; success=false; fi
    fi
  fi

 # --- main.tf ---
  if ! cat > "$PROJECT_DIR/main.tf" << EOF
# Main infrastructure for $PROJECT_NAME on $SELECTED_PROVIDER

locals {
  project_name = "$PROJECT_NAME" # Use the sanitized project name
  environment  = "dev"          # Change to "prod" for production
  tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "OpenTofu"
  }
}
EOF
  then
    echo -e "${RED}Failed to create main.tf file.${RESET}" >&2; success=false
  fi

  # Add provider-specific resources based on hosting type
  # Using single quotes 'EOF' for most blocks to prevent unwanted expansion
  # Use double quotes EOF only when ${local.project_name} or other intended vars are needed
  if [ "$HOSTING_TYPE" == "self" ]; then
    # Self-hosted resources
    case $SELECTED_PROVIDER in
      aws)
        if ! cat >> "$PROJECT_DIR/main.tf" << 'EOF'

# --- AWS Self-Hosted ---

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, {
    Name = "${local.project_name}-vpc"
  })
}

resource "aws_subnet" "public" {
  count             = 2 # Example: 2 subnets in different AZs
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index) # e.g., 10.0.0.0/24, 10.0.1.0/24
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name = "${local.project_name}-public-${count.index}"
  })
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.tags, {
    Name = "${local.project_name}-igw"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.tags, {
    Name = "${local.project_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "web" {
  name        = "${local.project_name}-web-sg"
  description = "Allow HTTP/HTTPS/SSH inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

   ingress {
    description = "SSH from anywhere (Restrict in production!)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: Restrict this to your IP in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allow all outbound
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

# Find latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "${local.project_name}-keypair"
  public_key = file("~/.ssh/id_rsa.pub") # Ensure this file exists
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id # Deploy in the first public subnet
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.deployer.key_name
  # associate_public_ip_address = true # Handled by map_public_ip_on_launch in subnet

  # user_data = <<-EOF # Use if you need startup script
  #   #!/bin/bash
  #   yum update -y
  #   yum install -y httpd
  #   systemctl start httpd
  #   systemctl enable httpd
  #   echo "<h1>Hello from ${local.project_name} on AWS!</h1>" > /var/www/html/index.html
  # EOF

  tags = merge(local.tags, {
    Name = "${local.project_name}-web"
  })

  # Avoid immediate replacement on key change if using lifecycle ignore_changes
  # lifecycle {
  #   ignore_changes = [key_name]
  # }
}
EOF
        then echo -e "${RED}Failed to add AWS self-hosted resources.${RESET}" >&2; success=false; fi ;;

      azure)
        if ! cat >> "$PROJECT_DIR/main.tf" << 'EOF'

# --- Azure Self-Hosted ---

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = local.tags
}

resource "azurerm_virtual_network" "main" {
  name                = "${local.project_name}-vnet"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.0.0.0/16"]

  tags = local.tags
}

resource "azurerm_subnet" "main" {
  name                 = "${local.project_name}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "main" {
  name                = "${local.project_name}-ip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static" # Static IP is often preferred for servers
  sku                 = "Standard" # Use Standard SKU for availability zones, etc.

  tags = local.tags
}

resource "azurerm_network_security_group" "main" {
  name                = "${local.project_name}-nsg"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

   security_rule {
    name                       = "AllowSSH"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "Internet" # WARNING: Restrict this to your IP in production
    destination_address_prefix = "*"
  }

  tags = local.tags
}

resource "azurerm_network_interface" "main" {
  name                = "${local.project_name}-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }

  tags = local.tags
}

resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_linux_virtual_machine" "main" {
  name                            = "${local.project_name}-vm"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = "Standard_B1s" # Example size
  admin_username                  = "adminuser"
  network_interface_ids           = [azurerm_network_interface.main.id]
  disable_password_authentication = true # Recommended for security

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub") # Ensure this file exists
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS" # Or Premium_LRS for SSD
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy" # Ubuntu 22.04 LTS
    sku       = "22_04-lts-gen2"              # Use Gen2 where possible
    version   = "latest"
  }

  # user_data = base64encode(<<-EOF # Use if you need startup script (cloud-init)
  #   #!/bin/bash
  #   apt-get update
  #   apt-get install -y nginx
  #   echo "<h1>Hello from ${local.project_name} on Azure!</h1>" > /var/www/html/index.html
  # EOF
  # )

  tags = local.tags
}
EOF
        then echo -e "${RED}Failed to add Azure self-hosted resources.${RESET}" >&2; success=false; fi ;;

      gcp)
        # Use double quotes for EOF here because of ${local.project_name}
        if ! cat >> "$PROJECT_DIR/main.tf" << EOF

# --- GCP Self-Hosted ---

resource "google_compute_network" "main" {
  name                    = "\${local.project_name}-vpc"
  auto_create_subnetworks = false # Recommended practice
  project                 = var.project_id
}

resource "google_compute_subnetwork" "main" {
  name          = "\${local.project_name}-subnet"
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.main.id # Use id instead of self_link
  region        = var.region
  project       = var.project_id
}

resource "google_compute_firewall" "allow_http_https_ssh" {
  name    = "\${local.project_name}-allow-web-ssh"
  network = google_compute_network.main.id
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "22"]
  }

  # Allow from anywhere (restrict SSH in production)
  source_ranges = ["0.0.0.0/0"]
  # Use target_tags for more granular control if needed
  # target_tags = ["web-server"]
}

resource "google_compute_instance" "main" {
  name         = "\${local.project_name}-vm"
  machine_type = "e2-micro" # Example type
  zone         = var.zone
  project      = var.project_id

  tags = ["web-server"] # Optional tag for firewall rules

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11" # Example image
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.main.id
    # Access config for public IP (ephemeral by default)
    access_config {
    }
  }

  # Add SSH key to metadata for login
  metadata = {
    ssh-keys = "adminuser:\${file("~/.ssh/id_rsa.pub")}" # Ensure key file exists, replace adminuser if needed
  }

  # Startup script example
  metadata_startup_script = <<-EOT # Using EOT here, but EOF is fine too
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    echo "<h1>Hello from \${local.project_name} on GCP!</h1>" > /var/www/html/index.html
  EOT

  labels = local.tags # Use labels for GCP-specific tagging
}
EOF
        then echo -e "${RED}Failed to add GCP self-hosted resources.${RESET}" >&2; success=false; fi ;;

      digitalocean)
         # Use single quotes 'EOF' as expansion is not needed here
        if ! cat >> "$PROJECT_DIR/main.tf" << 'EOF'

# --- DigitalOcean Self-Hosted ---

resource "digitalocean_vpc" "main" {
  name     = "${local.project_name}-vpc"
  region   = var.region
  ip_range = "10.0.0.0/16" # Example range
}

# Get SSH key data source (more robust than embedding file path)
data "digitalocean_ssh_key" "main" {
  name = "My Default SSH Key" # Replace with the name of your key in DO account
  # Alternatively, create a new key resource:
  # resource "digitalocean_ssh_key" "main" {
  #   name       = "${local.project_name}-key"
  #   public_key = file("~/.ssh/id_rsa.pub")
  # }
}

resource "digitalocean_droplet" "main" {
  name     = "${local.project_name}-droplet"
  size     = var.droplet_size
  image    = "ubuntu-22-04-x64" # Use Ubuntu 22.04 LTS
  region   = var.region
  vpc_uuid = digitalocean_vpc.main.id
  ssh_keys = [data.digitalocean_ssh_key.main.id] # Reference SSH key ID

  # user_data = <<-EOF # Use for startup script
  #   #!/bin/bash
  #   apt-get update
  #   apt-get install -y nginx
  #   echo "<h1>Hello from ${local.project_name} on DO!</h1>" > /var/www/html/index.html
  # EOF

  tags = [local.project_name, local.environment]
}

resource "digitalocean_firewall" "main" {
  name = "${local.project_name}-firewall"

  # Apply firewall to the specific droplet
  droplet_ids = [digitalocean_droplet.main.id]

  # Allow standard web traffic and SSH inbound
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"] # WARNING: Restrict this in production
  }
  # Allow ICMP (ping) inbound
   inbound_rule {
    protocol         = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Allow all outbound traffic
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
   outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
EOF
        then echo -e "${RED}Failed to add DigitalOcean self-hosted resources.${RESET}" >&2; success=false; fi ;;

      linode)
        # Use single quotes 'EOF'
        if ! cat >> "$PROJECT_DIR/main.tf" << 'EOF'

# --- Linode Self-Hosted ---

# Generate a random password for root (less secure than SSH keys)
resource "random_password" "root_password" {
  length           = 24
  special          = true
  override_special = "_%@"
}

# Create a Linode instance
resource "linode_instance" "main" {
  label      = "${local.project_name}-instance"
  region     = var.region
  type       = var.instance_type
  image      = "linode/ubuntu22.04" # Use Ubuntu 22.04 LTS
  root_pass  = random_password.root_password.result # Use random password
  authorized_keys = [ file("~/.ssh/id_rsa.pub") ] # Strongly recommend using SSH keys

  # user_data = base64encode(<<-EOF # Use for startup script (StackScript is another option)
  #   #!/bin/bash
  #   apt-get update
  #   apt-get install -y nginx
  #   echo "<h1>Hello from ${local.project_name} on Linode!</h1>" > /var/www/html/index.html
  # EOF
  # )

  tags = [local.project_name, local.environment]
}

# Create a firewall for the instance
resource "linode_firewall" "main" {
  label = "${local.project_name}-firewall"
  tags  = [local.project_name, local.environment]

  # Inbound rules
  inbound {
    label    = "allow-http"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "80"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }
  inbound {
    label    = "allow-https"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "443"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }
  inbound {
    label    = "allow-ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = ["0.0.0.0/0"] # WARNING: Restrict this in production
    ipv6     = ["::/0"]
  }

  # Outbound policy (ALLOW by default if no rules specified, explicitly allowing is safer)
   outbound_policy = "ACCEPT"
  # outbound {
  #   label    = "allow-all-outbound"
  #   action   = "ACCEPT"
  #   protocol = "ALL"
  #   ipv4     = ["0.0.0.0/0"]
  #   ipv6     = ["::/0"]
  # }

  # Apply firewall to the instance
  linodes = [linode_instance.main.id]
}
EOF
        then echo -e "${RED}Failed to add Linode self-hosted resources.${RESET}" >&2; success=false; fi ;;

      hcloud)
         # Use single quotes 'EOF'
        if ! cat >> "$PROJECT_DIR/main.tf" << 'EOF'

# --- Hetzner Cloud Self-Hosted ---

# Add SSH key to Hetzner Cloud project
resource "hcloud_ssh_key" "default" {
  name       = "${local.project_name}-ssh-key"
  public_key = file("~/.ssh/id_rsa.pub") # Ensure this file exists
}

# Create a Hetzner server
resource "hcloud_server" "main" {
  name        = "${local.project_name}-server"
  server_type = var.server_type
  image       = "ubuntu-22.04" # Ubuntu 22.04 LTS
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.default.id] # Use the SSH key resource ID

  # user_data = <<-EOF # Use for startup script (cloud-init)
  #   #!/bin/bash
  #   apt-get update
  #   apt-get install -y nginx
  #   echo "<h1>Hello from ${local.project_name} on Hetzner!</h1>" > /var/www/html/index.html
  # EOF

  labels = local.tags # Use labels for tagging
}

# Create a firewall
resource "hcloud_firewall" "main" {
  name = "${local.project_name}-firewall"

  # Inbound rules
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
    description = "Allow HTTP"
  }
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
    description = "Allow HTTPS"
  }
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"] # WARNING: Restrict this in production
    description = "Allow SSH"
  }
   rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
    description = "Allow Ping"
  }

  # Outbound rules (Allow all by default if no outbound rules are specified)

  # Apply firewall to server
  # Using firewall attachment resource is now preferred
}

resource "hcloud_firewall_attachment" "fw_attachment" {
  firewall_id = hcloud_firewall.main.id
  server_ids  = [hcloud_server.main.id]
}
EOF
        then echo -e "${RED}Failed to add Hetzner self-hosted resources.${RESET}" >&2; success=false; fi ;;

      exoscale)
         # Use double quotes EOF because of ${local.project_name}
        if ! cat >> "$PROJECT_DIR/main.tf" << EOF

# --- Exoscale Self-Hosted ---

# Create a security group
resource "exoscale_security_group" "main" {
  name = "\${local.project_name}-sg"
}

# Add security group rules (using separate resources)
resource "exoscale_security_group_rule" "allow_http" {
  security_group_id = exoscale_security_group.main.id
  type              = "INGRESS"
  protocol          = "tcp"
  cidr              = "0.0.0.0/0"
  start_port        = 80
  end_port          = 80
  description       = "Allow HTTP"
}

resource "exoscale_security_group_rule" "allow_https" {
  security_group_id = exoscale_security_group.main.id
  type              = "INGRESS"
  protocol          = "tcp"
  cidr              = "0.0.0.0/0"
  start_port        = 443
  end_port          = 443
  description       = "Allow HTTPS"
}

resource "exoscale_security_group_rule" "allow_ssh" {
  security_group_id = exoscale_security_group.main.id
  type              = "INGRESS"
  protocol          = "tcp"
  cidr              = "0.0.0.0/0" # WARNING: Restrict this in production
  start_port        = 22
  end_port          = 22
  description       = "Allow SSH"
}

resource "exoscale_security_group_rule" "allow_ping" {
  security_group_id = exoscale_security_group.main.id
  type              = "INGRESS"
  protocol          = "icmp"
  icmp_type         = 8 # Echo request
  icmp_code         = 0
  cidr              = "0.0.0.0/0"
  description       = "Allow Ping"
}

# Get SSH key data source (more robust)
resource "exoscale_ssh_keypair" "main" {
   name = "\${local.project_name}-key"
   public_key = file("~/.ssh/id_rsa.pub") # Ensure this exists
}

# Get the latest Ubuntu 22.04 template ID
data "exoscale_compute_template" "ubuntu_lts" {
  zone = var.zone
  filter = "Ubuntu 22.04 LTS" # Adjust filter as needed
}

# Create a compute instance
resource "exoscale_compute_instance" "main" {
  name               = "\${local.project_name}-instance"
  zone               = var.zone
  type               = var.instance_type
  disk_size          = 10 # Default size, adjust as needed
  template_id        = data.exoscale_compute_template.ubuntu_lts.id
  security_group_ids = [exoscale_security_group.main.id]
  key_pair           = exoscale_ssh_keypair.main.name

  # user_data example (cloud-init)
  user_data = <<-EOT
    #cloud-config
    package_update: true
    package_upgrade: true
    packages:
      - nginx
    runcmd:
      - echo "<h1>Hello from \${local.project_name} on Exoscale!</h1>" > /var/www/html/index.html
      - systemctl enable --now nginx
  EOT

  tags = local.tags # Exoscale uses 'labels' but TF maps 'tags' to it
}
EOF
        then echo -e "${RED}Failed to add Exoscale self-hosted resources.${RESET}" >&2; success=false; fi ;;

      ovh | openstack | infomaniak)
         # Use single quotes 'EOF'
        if ! cat >> "$PROJECT_DIR/main.tf" << 'EOF'

# --- OpenStack Self-Hosted (Generic / OVH / Infomaniak) ---

# Data source for external network (adjust name if needed)
data "openstack_networking_network_v2" "external" {
  name = "Ext-Net" # Common name on OVH, adjust for your OpenStack
}

# Create a network
resource "openstack_networking_network_v2" "main" {
  name           = "${local.project_name}-network"
  admin_state_up = "true"
}

# Create a subnet
resource "openstack_networking_subnet_v2" "main" {
  name            = "${local.project_name}-subnet"
  network_id      = openstack_networking_network_v2.main.id
  cidr            = "10.0.0.0/24" # Example CIDR
  ip_version      = 4
  dns_nameservers = ["1.1.1.1", "8.8.8.8"] # Example DNS
}

# Create a router for external access
resource "openstack_networking_router_v2" "main" {
  name                = "${local.project_name}-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id
}

# Connect router to our subnet
resource "openstack_networking_router_interface_v2" "main" {
  router_id = openstack_networking_router_v2.main.id
  subnet_id = openstack_networking_subnet_v2.main.id
}

# Create security group
resource "openstack_networking_secgroup_v2" "main" {
  name        = "${local.project_name}-secgroup"
  description = "Allow HTTP/HTTPS/SSH for ${local.project_name}"
}

# Allow HTTP
resource "openstack_networking_secgroup_rule_v2" "allow_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.main.id
}

# Allow HTTPS
resource "openstack_networking_secgroup_rule_v2" "allow_https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.main.id
}

# Allow SSH
resource "openstack_networking_secgroup_rule_v2" "allow_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0" # WARNING: Restrict this in production
  security_group_id = openstack_networking_secgroup_v2.main.id
}

# Allow ICMP (Ping)
resource "openstack_networking_secgroup_rule_v2" "allow_icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.main.id
}

# Allow all Egress
resource "openstack_networking_secgroup_rule_v2" "allow_egress" {
  direction         = "egress"
  ethertype         = "IPv4"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.main.id
}

# Create keypair
resource "openstack_compute_keypair_v2" "main" {
  name       = "${local.project_name}-keypair"
  public_key = file("~/.ssh/id_rsa.pub") # Ensure this file exists
}

# Data source for image
data "openstack_images_image_v2" "os_image" {
  name        = var.image # Use image name from variables
  most_recent = true
}

# Create an instance
resource "openstack_compute_instance_v2" "main" {
  name            = "${local.project_name}-instance"
  image_id        = data.openstack_images_image_v2.os_image.id
  flavor_name     = var.flavor
  key_pair        = openstack_compute_keypair_v2.main.name
  security_groups = [openstack_networking_secgroup_v2.main.name]

  network {
    uuid = openstack_networking_network_v2.main.id
  }

  # user_data = <<-EOF # cloud-init script
  #   #!/bin/bash
  #   apt-get update
  #   apt-get install -y nginx
  #   echo "<h1>Hello from ${local.project_name} on OpenStack!</h1>" > /var/www/html/index.html
  # EOF

  # Optional: metadata for tags if compute API supports it
  # metadata = local.tags
}

# Create a floating IP
resource "openstack_compute_floatingip_v2" "fip" {
  pool = data.openstack_networking_network_v2.external.name # Pool name usually same as external network name
}

# Associate floating IP
resource "openstack_compute_floatingip_associate_v2" "fip_assoc" {
  floating_ip = openstack_compute_floatingip_v2.fip.address
  instance_id = openstack_compute_instance_v2.main.id
}
EOF
        then echo -e "${RED}Failed to add OpenStack self-hosted resources.${RESET}" >&2; success=false; fi ;;
       *)
         echo -e "${YELLOW}Self-hosted template not available for provider '$SELECTED_PROVIDER'. Skipping resource generation.${RESET}" >&2
         # Consider adding a placeholder or default message in main.tf
         if ! echo "# No self-hosted resources defined for $SELECTED_PROVIDER" >> "$PROJECT_DIR/main.tf"; then success=false; fi
         ;;
    esac
  else # Managed services
     case $SELECTED_PROVIDER in
      aws)
         # Use single quotes 'EOF'
        if ! cat >> "$PROJECT_DIR/main.tf" << 'EOF'

# --- AWS Managed (S3/CloudFront Static Site) ---

resource "aws_s3_bucket" "website" {
  bucket = "${local.project_name}-website" # Bucket names must be globally unique

  tags = local.tags
}

# Enable static website hosting
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.bucket # Reference bucket name

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html" # Optional error page
  }
}

# Bucket policy to allow public read access
resource "aws_s3_bucket_policy" "website_public_read" {
  bucket = aws_s3_bucket.website.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::${aws_s3_bucket.website.bucket}/*"
      },
    ]
  })
}

# Block public ACLs - Recommended for security
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = false # Policy above needs to be public
  ignore_public_acls      = true
  restrict_public_buckets = false # Allows public access via policy
}


# CloudFront distribution
resource "aws_cloudfront_distribution" "website" {
  origin {
    domain_name = aws_s3_bucket_website_configuration.website.website_endpoint # Use website endpoint
    origin_id   = "S3-${aws_s3_bucket.website.bucket}"
    # custom_origin_config is not needed for S3 website endpoint origin
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  # Logging configuration (optional but recommended)
  # logging_config {
  #   include_cookies = false
  #   bucket          = "my-cloudfront-logs-bucket.s3.amazonaws.com" # Create this bucket separately
  #   prefix          = "${local.project_name}/"
  # }

  # Default cache behavior
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"] # Allow OPTIONS for CORS if needed
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website.bucket}"

    # Cache based on query strings, cookies, headers (adjust as needed)
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
      # headers = ["Origin"] # Include Origin header if CORS is needed
    }

    viewer_protocol_policy = "redirect-to-https" # Enforce HTTPS
    min_ttl                = 0
    default_ttl            = 3600 # 1 hour
    max_ttl                = 86400 # 24 hours
    compress               = true # Enable compression
  }

  # Price class (All=best performance, 200=US/EU, 100=US/EU/limited Asia)
  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none" # Or whitelist/blacklist countries
    }
  }

  # Viewer certificate for HTTPS
  viewer_certificate {
    cloudfront_default_certificate = true
    # Or use ACM certificate:
    # acm_certificate_arn = var.acm_certificate_arn # Requires ACM cert in us-east-1
    # ssl_support_method = "sni-only"
    # minimum_protocol_version = "TLSv1.2_2021"
  }

  # Aliases for custom domain (requires viewer_certificate with ACM cert)
  # aliases = [var.domain_name] # Ensure var.domain_name exists

  tags = local.tags
}
EOF
        then echo -e "${RED}Failed to add AWS managed resources.${RESET}" >&2; success=false; fi ;;

      azure)
        # Use single quotes 'EOF'
        if ! cat >> "$PROJECT_DIR/main.tf" << 'EOF'

# --- Azure Managed (App Service Web App) ---

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = local.tags
}

# Create an App Service Plan (determines pricing tier, OS, scale)
resource "azurerm_app_service_plan" "main" {
  name                = "${local.project_name}-asp"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Pricing tier (e.g., F1=Free, B1=Basic, S1=Standard, P1V2=Premium)
  sku {
    tier = "Basic"
    size = "B1"
  }
  kind = "Linux" # Specify Linux for Linux Web App
  reserved = true # Required for Linux plans

  tags = local.tags
}

# Create a Linux Web App
resource "azurerm_linux_web_app" "main" {
  name                = "${local.project_name}-webapp"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_app_service_plan.main.id

  # Site configuration (example for Node.js)
  site_config {
    application_stack {
       node_version = "18-lts" # Specify runtime version
    }
    always_on = false # Set to true for Basic tier and above to keep app warm
    # http2_enabled = true # Enable HTTP/2
    # Use 32 bit worker process for lower memory usage on basic tiers
    use_32_bit_worker_process = (lower(azurerm_app_service_plan.main.sku[0].tier) == "basic" || lower(azurerm_app_service_plan.main.sku[0].tier) == "free") ? true : false
  }

  # App settings (environment variables)
  app_settings = {
    "NODE_ENV" = "production"
    # Add other settings like database connection strings here
    # "DATABASE_URL" = "..."
  }

  # Optional: HTTPS only
  https_only = true

  tags = local.tags
}
EOF
        then echo -e "${RED}Failed to add Azure managed resources.${RESET}" >&2; success=false; fi ;;

      gcp)
        # Use single quotes 'EOF'
        if ! cat >> "$PROJECT_DIR/main.tf" << 'EOF'

# --- GCP Managed (Cloud Run) ---

# Enable necessary APIs (Cloud Run, IAM) - Can be done via gcloud or console beforehand
resource "google_project_service" "run_api" {
  project = var.project_id
  service = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iam_api" {
  project = var.project_id
  service = "iam.googleapis.com"
  disable_on_destroy = false
}


# Create a Cloud Run service
resource "google_cloud_run_v2_service" "main" {
  name     = "${local.project_name}-service"
  location = var.region
  project  = var.project_id

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello" # Default hello image
      # Replace with your image:
      # image = "gcr.io/${var.project_id}/${local.project_name}:latest"

      # Optional: resources, ports, env vars
      # ports {
      #   container_port = 8080 # Port your container listens on
      # }
      # resources {
      #   limits = {
      #     cpu    = "1000m"
      #     memory = "512Mi"
      #   }
      # }
      # env {
      #   name = "NODE_ENV"
      #   value = "production"
      # }
    }
    # Optional: scaling, timeout, etc.
    # scaling {
    #   min_instance_count = 0
    #   max_instance_count = 3
    # }
    # timeout = "300s"
  }

  # Traffic splitting (100% to latest revision)
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  # Allow unauthenticated access (public)
  # depends_on is important to ensure IAM API is enabled first
  depends_on = [google_project_service.run_api, google_project_service.iam_api]
}

# Grant public access using IAM policy binding
resource "google_cloud_run_v2_service_iam_binding" "allow_public" {
  project  = google_cloud_run_v2_service.main.project
  location = google_cloud_run_v2_service.main.location
  name     = google_cloud_run_v2_service.main.name

  role    = "roles/run.invoker"
  members = ["allUsers"]

  # depends_on is implicitly handled by referencing the service
}
EOF
        then echo -e "${RED}Failed to add GCP managed resources.${RESET}" >&2; success=false; fi ;;

      digitalocean)
        # Use double quotes EOF for ${var.*} and ${local.*} expansion
        if ! cat >> "$PROJECT_DIR/main.tf" << EOF

# --- DigitalOcean Managed (App Platform) ---

resource "digitalocean_app" "main" {
  spec {
    name   = local.project_name # App name
    region = var.region         # Region for the app

    # Define services (e.g., web service, worker, static site)
    services = [{
      name               = "\${local.project_name}-web" # Service name
      instance_size_slug = "basic-xxs"       # Instance size (check available slugs)
      instance_count     = 1                 # Number of instances

      # Source: Connect to GitHub repo
      github {
        repo           = "\${var.github_username}/\${var.github_repo}" # Ensure these vars exist
        branch         = "main"              # Branch to deploy
        deploy_on_push = true                # Auto-deploy on push
      }

      # Or use Docker Hub:
      # image {
      #   registry_type = "DOCKER_HUB"
      #   repository    = "user/imagename"
      #   tag           = "latest"
      # }

      # Define HTTP routes
      routes = [{
        path = "/" # Route all traffic from root path
      }]

      # Environment variables (example)
      # envs = [{
      #   key   = "NODE_ENV"
      #   value = "production"
      #   scope = "RUN_AND_BUILD_TIME"
      #   type  = "GENERAL"
      # }]

      # Build and run commands (if using buildpack, often auto-detected)
      # build_command = "npm run build"
      # run_command   = "npm start"

      # Port container listens on
      http_port = 8080 # Adjust if your app uses a different port
    }]

    # Optional: Static site component
    # static_sites = [{
    #   name = "\${local.project_name}-static"
    #   github {
    #     repo   = "\${var.github_username}/\${var.github_repo}"
    #     branch = "main"
    #     deploy_on_push = true
    #   }
    #   source_dir = "/public" # Directory containing static assets
    #   build_command = "npm run build:static" # If build step is needed
    #   output_dir = "/dist" # Directory with built assets
    #   routes = [{ path = "/static" }] # Route for static assets
    # }]

    # Optional: Database component
    # databases = [{
    #   name           = "\${local.project_name}-db"
    #   engine         = "PG" # PostgreSQL (PG), MySQL (MYSQL), Redis (REDIS)
    #   production     = true # Use production-grade cluster
    #   version        = "14" # Specify engine version
    #   # size = "db-s-1vcpu-1gb" # Specify cluster size
    #   # num_nodes = 1 # Number of nodes
    # }]
  }
}
EOF
        then echo -e "${RED}Failed to add DigitalOcean managed resources.${RESET}" >&2; success=false; fi ;;

      vercel)
        # Use single quotes 'EOF'
        if ! cat >> "$PROJECT_DIR/main.tf" << 'EOF'

# --- Vercel Managed ---

# Create a Vercel project
resource "vercel_project" "main" {
  name      = var.project_name # Name of the project in Vercel
  framework = var.framework    # Framework preset (e.g., nextjs, nuxt, gatsby, react, vue)
  # Optional: Link to Git repository
  # git_repository = {
  #   type = "github"
  #   repo = "user/repo" # e.g., your-github-username/your-repo-name
  # }
  # Optional: Root directory if monorepo
  # root_directory = "packages/web"
}

# Create a custom domain configuration (Optional)
# Requires var.domain_name to be set
resource "vercel_project_domain" "main_domain" {
  # count = var.domain_name != "" ? 1 : 0 # Only create if domain_name is provided

  project_id = vercel_project.main.id
  domain     = var.domain_name # Your custom domain
}

# Add production environment variable (Example)
resource "vercel_project_environment_variable" "node_env" {
  project_id = vercel_project.main.id
  key        = "NODE_ENV"
  value      = "production"
  target     = ["production"] # Apply only to production deployments
}

# Example: Add another variable for preview/development
# resource "vercel_project_environment_variable" "api_url_dev" {
#   project_id = vercel_project.main.id
#   key        = "API_URL"
#   value      = "https://dev-api.example.com"
#   target     = ["development", "preview"]
# }

# Example: Add a secret
# resource "vercel_secret" "api_key" {
#   name = "${var.project_name}-api-key"
#   value = "your-sensitive-api-key" # Consider using input variables marked sensitive
# }

# resource "vercel_project_environment_variable" "api_key_secret" {
#   project_id = vercel_project.main.id
#   key        = "API_KEY"
#   value      = vercel_secret.api_key.value # Reference the secret
#   target     = ["production", "development", "preview"]
# }
EOF
        then echo -e "${RED}Failed to add Vercel managed resources.${RESET}" >&2; success=false; fi ;;

      fly)
        # Use double quotes EOF for ${var.*} and ${local.*} expansion
        if ! cat >> "$PROJECT_DIR/main.tf" << EOF

# --- Fly.io Managed ---

# Create a Fly application
resource "fly_app" "main" {
  name = var.app_name # Must be globally unique on Fly.io
  org  = "personal"   # Replace with your organization slug if applicable
}

# Allocate an IP address (v4 or v6)
resource "fly_ip" "shared_v4" {
  app  = fly_app.main.name
  type = "v4"       # Request an IPv4 address
  # type = "shared_v4" # Use if you don't need a dedicated IP
}
# resource "fly_ip" "v6" {
#   app  = fly_app.main.name
#   type = "v6"
# }

# Define a Fly machine (instance running your app)
resource "fly_machine" "web" {
  app    = fly_app.main.name
  name   = "\${var.app_name}-web-01" # Optional: specific machine name
  region = var.region               # Primary region to deploy

  # VM configuration
  guest {
    # Specify size based on var.vm_size (e.g., "shared-cpu-1x")
    cpu_kind = split("-", var.vm_size)[0] # e.g., "shared" or "performance"
    cpus     = tonumber(regex("cpu-([0-9]+)x", var.vm_size)[0]) # e.g., 1
    # Memory based on size (adjust mapping as needed)
    memory_mb = (var.vm_size == "shared-cpu-1x" ? 256 :
                (var.vm_size == "performance-1x" ? 2048 : 512)) # Example mapping
  }

  # Image configuration
  image = var.image # Docker image reference

  # Environment variables
  # env = {
  #   NODE_ENV = "production"
  #   PORT     = "8080" # Fly proxies to this internal port by default
  # }

  # Services (how Fly exposes your app)
  services = [
    {
      protocol      = "tcp"
      internal_port = 8080 # Port your application listens on inside the container
      ports = [
        # Expose standard HTTP/HTTPS ports externally
        { port = 80, handlers = ["http"] },
        { port = 443, handlers = ["tls", "http"] } # TLS termination handled by Fly proxy
      ]
      # Optional: Health checks
      # checks = [{
      #   type     = "http"
      #   port     = 8080
      #   path     = "/healthz" # Path for health check endpoint
      #   interval = "15s"
      #   timeout  = "2s"
      # }]
      # Optional: Concurrency limits
      # concurrency = {
      #   type = "connections"
      #   hard_limit = 200
      #   soft_limit = 150
      # }
    }
  ]

  # Optional: Mounts for persistent volumes
  # mounts = [{
  #   volume = fly_volume.data.id
  #   path   = "/data" # Mount path inside the container
  # }]

  # depends_on = [fly_ip.shared_v4] # Ensure IP is allocated first
}

# Optional: Persistent volume
# resource "fly_volume" "data" {
#   app    = fly_app.main.name
#   name   = "\${var.app_name}-data"
#   region = var.region
#   size_gb = 10 # Size in GB
# }

# Optional: Certificate for custom domain
# resource "fly_cert" "custom_domain" {
#   app = fly_app.main.name
#   hostname = "your.custom-domain.com" # Replace with your domain
# }
EOF
        then echo -e "${RED}Failed to add Fly.io managed resources.${RESET}" >&2; success=false; fi ;;

      render)
         # Use single quotes 'EOF'
        if ! cat >> "$PROJECT_DIR/main.tf" << 'EOF'

# --- Render Managed ---

# Create a Render web service
resource "render_service" "web" {
  name = var.service_name # Name of the service on Render

  # Basic service configuration
  owner_id      = "" # Find your Owner ID (User or Team ID) in Render settings
  type          = var.service_type # e.g., "web_service", "static_site", "background_worker"
  region        = var.region       # e.g., "oregon", "frankfurt"
  branch        = "main"           # Default branch to deploy

  # Build and deploy configuration
  auto_deploy    = "yes" # Or "no"
  build_filter {          # Optional: Only build if specific paths change
    paths = ["src/**", "package.json"]
  }

  # Source repository (example: GitHub)
  repo = "https://github.com/user/repo" # Replace with your actual repo URL

  # Service details based on type
  service_details {
    # Common settings
    # plan = var.plan # e.g., "starter", "standard", "pro" (defaults usually ok for starter)

    # Settings for web_service or background_worker
    # build_command = "npm install && npm run build" # If needed
    # start_command = "npm start"                  # Command to run the app

    # Settings for static_site
    # publish_path = "public" # Directory with static assets after build

    # Environment specific details
    env = "docker" # Or "node", "python", "ruby", etc.

    # For Docker environment
    docker_details {
       dockerfile_path = "./Dockerfile"
       docker_context_path = "."
    }

    # For buildpack environments (e.g., Node)
    # native_environment_details {
    #    build_command = "npm install && npm run build"
    #    start_command = "node dist/server.js"
    # }

    # Optional: Health check path for web services
    health_check_path = "/healthz"

    # Optional: Disk persistence (requires paid plan)
    # disk {
    #   name = "data"
    #   mount_path = "/data"
    #   size_gb = 10
    # }
  }

  # Environment variables
  env_vars = {
    NODE_ENV = "production"
    # GENERATED_PASSWORD = random_password.db_password.result # Example using a secret
  }
}

# Example: Generate a random password for a database
# resource "random_password" "db_password" {
#   length  = 16
#   special = false
# }

# Optional: Create a Render database
# resource "render_database" "db" {
#   name      = "${var.service_name}-db"
#   owner_id  = render_service.web.owner_id # Use same owner
#   engine    = "POSTGRES" # Or "MYSQL", "REDIS"
#   region    = var.region
#   # plan = "starter" # Or higher plans
#   # version = "14" # Specify engine version
# }

# Optional: Environment group for shared variables
# resource "render_env_group" "shared" {
#   name     = "${var.service_name}-shared-env"
#   owner_id = render_service.web.owner_id
#   env_vars = {
#     API_KEY = "shared-secret-value"
#   }
# }
# Link env group to service
# resource "render_service_env_group_link" "web_link" {
#   service_id  = render_service.web.id
#   env_group_id = render_env_group.shared.id
# }
EOF
        then echo -e "${RED}Failed to add Render managed resources.${RESET}" >&2; success=false; fi ;;

      netlify)
         # Use single quotes 'EOF'
        if ! cat >> "$PROJECT_DIR/main.tf" << 'EOF'

# --- Netlify Managed ---

# Create a Netlify site
resource "netlify_site" "main" {
  name = var.site_name # Optional: Custom site name (must be unique)

  # Repository configuration
  repo {
    provider = "github"       # Or "gitlab", "bitbucket"
    repo     = "user/repo"    # Replace with your repository path
    branch   = "main"         # Production branch
    # Optional: Base directory if monorepo
    # base = "packages/web"
    # Optional: Deploy previews from pull requests
    deploy_previews_enabled = true
    # Optional: Deploy branch deploys
    branch_deploys_enabled = true
  }

  # Build settings
  build_settings {
    command        = var.build_command      # e.g., "npm run build"
    publish        = var.publish_directory  # e.g., "dist", "public", "build"
    # Optional: Functions directory
    # functions_dir  = "netlify/functions"
    # Optional: Base directory (alternative to repo.base)
    # base           = "site"
  }

  # Environment variables
  environment = {
    NODE_ENV = "production"
    # Add other production variables here
    # API_URL = "https://api.example.com"
  }

  # Optional: Custom domain (requires var.domain_name)
  # custom_domain = var.domain_name != "" ? var.domain_name : null

  # Optional: Force HTTPS
  force_ssl = true

  # Optional: Processing settings for assets (defaults usually fine)
  # processing_settings {
  #   html = { pretty_urls = true }
  # }
}

# Optional: Configure DNS if using Netlify DNS
# resource "netlify_dns_zone" "main" {
#   account_slug = "your-account-slug" # Find in Netlify settings
#   name         = var.domain_name     # Your domain name
# }
# resource "netlify_dns_record" "apex" {
#   zone_id = netlify_dns_zone.main.id
#   type    = "NETLIFY"
#   name    = "@" # Apex record
#   value   = netlify_site.main.name # Points to the Netlify site
# }
# resource "netlify_dns_record" "www" {
#   zone_id = netlify_dns_zone.main.id
#   type    = "NETLIFY"
#   name    = "www" # www subdomain
#   value   = netlify_site.main.name
# }

# Optional: Deploy key (if needed for private repos)
# resource "netlify_deploy_key" "main" {}
# output "deploy_key_public_key" {
#   value = netlify_deploy_key.main.public_key
#   description = "Add this public key as a deploy key in your Git repository."
# }
EOF
        then echo -e "${RED}Failed to add Netlify managed resources.${RESET}" >&2; success=false; fi ;;

      cloudflare)
         # Use single quotes 'EOF'
        if ! cat >> "$PROJECT_DIR/main.tf" << 'EOF'

# --- Cloudflare Managed (Pages) ---

# Create Cloudflare Pages project
resource "cloudflare_pages_project" "main" {
  account_id        = var.account_id       # Your Cloudflare account ID
  name              = local.project_name   # Name of the Pages project
  production_branch = "main"             # Git branch for production deploys

  # Source configuration (e.g., GitHub)
  source {
    type = "github"
    config {
      owner             = "github_user_or_org" # Replace with GitHub owner
      repo_name         = "your_repo_name"     # Replace with GitHub repo name
      production_branch = "main"
      pr_comments_enabled = true
      deployments_enabled = true
      # Optional: Root directory in monorepo
      # root_dir = "/apps/web"
    }
  }

  # Build configuration
  build_config {
    build_command   = "npm run build" # Your build command
    destination_dir = "dist"        # Directory with build output
    # Optional: Root directory (alternative to source.config.root_dir)
    # root_dir        = ""
  }

  # Deployment configurations (for preview/production env vars)
  deployment_configs {
    preview {
      # environment_variables = {
      #   NODE_ENV = "development"
      #   API_URL = "https://preview-api.example.com"
      # }
      # secrets = { # For sensitive variables
      #   API_KEY = var.preview_api_key # Use sensitive TF variables
      # }
    }
    production {
      environment_variables = {
        NODE_ENV = "production"
        # API_URL = "https://api.example.com"
      }
      # secrets = {
      #   API_KEY = var.production_api_key
      # }
    }
  }
}

# Optional: Create Cloudflare DNS CNAME record for custom domain
# Assumes you have a var.zone_id and var.domain_name defined
# resource "cloudflare_record" "pages_cname" {
#   count = var.domain_name != "" ? 1 : 0

#   zone_id = var.zone_id
#   name    = "@" # Use "@" for apex domain, or subdomain name like "www"
#   value   = cloudflare_pages_project.main.subdomain # Default is project-name.pages.dev
#   type    = "CNAME"
#   proxied = true # Enable Cloudflare proxy benefits (recommended)
#   ttl     = 1 # Auto TTL
# }

# Optional: Add custom domain to Pages project
# resource "cloudflare_pages_domain" "custom_domain" {
#   count = var.domain_name != "" ? 1 : 0

#   account_id  = var.account_id
#   project_name = cloudflare_pages_project.main.name
#   domain      = var.domain_name
# }
EOF
        then echo -e "${RED}Failed to add Cloudflare managed resources.${RESET}" >&2; success=false; fi ;;

       *)
         echo -e "${YELLOW}Managed service template not available for provider '$SELECTED_PROVIDER'. Skipping resource generation.${RESET}" >&2
          if ! echo "# No managed resources defined for $SELECTED_PROVIDER" >> "$PROJECT_DIR/main.tf"; then success=false; fi
         ;;
     esac
  fi

  # Add Caddy configuration resource if enabled (only makes sense for self-hosted)
  if $CADDY_ENABLED && [ "$HOSTING_TYPE" == "self" ]; then
     # Find the compute resource name based on provider to create dependency
     local compute_resource_ref=""
     case $SELECTED_PROVIDER in
        aws) compute_resource_ref="aws_instance.web" ;;
        azure) compute_resource_ref="azurerm_linux_virtual_machine.main" ;;
        gcp) compute_resource_ref="google_compute_instance.main" ;;
        digitalocean) compute_resource_ref="digitalocean_droplet.main" ;;
        linode) compute_resource_ref="linode_instance.main" ;;
        hcloud) compute_resource_ref="hcloud_server.main" ;;
        exoscale) compute_resource_ref="exoscale_compute_instance.main" ;;
        ovh | openstack | infomaniak) compute_resource_ref="openstack_compute_instance_v2.main" ;;
     esac

     if [ -n "$compute_resource_ref" ]; then
       # Use single quotes 'EOF'
       if ! cat >> "$PROJECT_DIR/main.tf" << EOF

# --- Caddy Configuration Resource ---
# Note: Assumes Caddy admin API is accessible from where Terraform runs
# This resource definition might need adjustment based on how Caddy is run

# resource "caddy_config" "main" {
#   depends_on = [$compute_resource_ref] # Ensure VM is created first

#   config = templatefile("\${path.module}/caddy/Caddyfile", {
#     # Pass variables if Caddyfile uses them, e.g.
#     # domain = var.domain_name
#     # email = var.email
#   })

#   # Requires provider "caddy" block in providers.tf
#   # Requires Caddy running with admin API enabled at localhost:2019
# }

# --- Alternative: Use provisioner to copy Caddyfile ---
# Consider using a provisioner as an alternative if direct API access is complex

resource "null_resource" "configure_caddy" {
  depends_on = [$compute_resource_ref]

  # Connection details depend on the provider's output for IP/host
  # Example for AWS:
  # connection {
  #   type        = "ssh"
  #   user        = "ec2-user" # Or appropriate user for the AMI
  #   private_key = file("~/.ssh/id_rsa") # Your private key
  #   host        = $compute_resource_ref.public_ip
  # }

  # Example for generic OpenStack with Floating IP:
  # connection {
  #   type        = "ssh"
  #   user        = "ubuntu" # Or appropriate user
  #   private_key = file("~/.ssh/id_rsa")
  #   host        = openstack_compute_floatingip_v2.fip.address
  # }


  # Provisioner to copy Caddyfile and reload Caddy
  # This requires SSH access and Caddy already installed on the VM
  # provisioner "file" {
  #   source      = "\${path.module}/caddy/Caddyfile"
  #   destination = "/tmp/Caddyfile"
  # }

  # provisioner "remote-exec" {
  #   inline = [
  #     "sudo mv /tmp/Caddyfile /etc/caddy/Caddyfile",
  #     "sudo systemctl reload caddy" # Or restart if needed
  #   ]
  # }

  # Trigger recreation if Caddyfile content changes
  triggers = {
    caddyfile_hash = filemd5("\${path.module}/caddy/Caddyfile")
  }
}
EOF
       then echo -e "${RED}Failed to add Caddy configuration/provisioner block.${RESET}" >&2; success=false; fi
     else
        echo -e "${YELLOW}Warning: Caddy enabled, but compute resource reference for '$SELECTED_PROVIDER' unknown. Cannot set dependency or configure provisioner correctly.${RESET}" >&2
     fi
  elif $CADDY_ENABLED && [ "$HOSTING_TYPE" == "managed" ]; then
       # Already warned about this combination, do nothing here
       :
  fi


  # --- outputs.tf ---
  if ! cat > "$PROJECT_DIR/outputs.tf" << EOF
# Outputs for $PROJECT_NAME on $SELECTED_PROVIDER ($HOSTING_TYPE)
EOF
  then
    echo -e "${RED}Failed to create outputs.tf file.${RESET}" >&2; success=false
  fi

  # Add outputs based on provider and hosting type
  # Use single quotes 'EOF' for heredocs
  if [ "$HOSTING_TYPE" == "self" ]; then
    case $SELECTED_PROVIDER in
      aws)
        if ! cat >> "$PROJECT_DIR/outputs.tf" << 'EOF'

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.web.public_ip
}
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.web.id
}
output "ssh_command" {
   description = "Command to SSH into the instance"
   value       = "ssh -i ~/.ssh/id_rsa ${aws_instance.web.public_dns != "" ? "ec2-user@${aws_instance.web.public_dns}" : "(Instance starting...)"}"
   # User might be different depending on AMI (e.g., ubuntu)
}
EOF
        then echo -e "${RED}Failed to add AWS self-hosted outputs.${RESET}" >&2; success=false; fi ;;
      azure)
        if ! cat >> "$PROJECT_DIR/outputs.tf" << 'EOF'

output "public_ip_address" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.main.ip_address
}
output "vm_id" {
  description = "ID of the Azure VM"
  value       = azurerm_linux_virtual_machine.main.id
}
output "ssh_command" {
   description = "Command to SSH into the VM"
   value       = "ssh -i ~/.ssh/id_rsa adminuser@${azurerm_public_ip.main.ip_address}"
}
EOF
        then echo -e "${RED}Failed to add Azure self-hosted outputs.${RESET}" >&2; success=false; fi ;;
      gcp)
        if ! cat >> "$PROJECT_DIR/outputs.tf" << 'EOF'

output "instance_external_ip" {
  description = "External IP address of the VM instance"
  value       = google_compute_instance.main.network_interface[0].access_config[0].nat_ip
}
output "instance_name" {
  description = "Name of the VM instance"
  value       = google_compute_instance.main.name
}
output "ssh_command" {
   description = "Command to SSH into the VM using gcloud"
   value       = "gcloud compute ssh --project ${var.project_id} --zone ${var.zone} ${google_compute_instance.main.name}"
}
EOF
        then echo -e "${RED}Failed to add GCP self-hosted outputs.${RESET}" >&2; success=false; fi ;;
      digitalocean)
        if ! cat >> "$PROJECT_DIR/outputs.tf" << 'EOF'

output "droplet_ipv4_address" {
  description = "IPv4 address of the Droplet"
  value       = digitalocean_droplet.main.ipv4_address
}
output "droplet_id" {
  description = "ID of the Droplet"
  value       = digitalocean_droplet.main.id
}
output "ssh_command" {
   description = "Command to SSH into the Droplet"
   value       = "ssh -i ~/.ssh/id_rsa root@${digitalocean_droplet.main.ipv4_address}" # DO uses root by default
}
EOF
        then echo -e "${RED}Failed to add DigitalOcean self-hosted outputs.${RESET}" >&2; success=false; fi ;;
      linode)
        if ! cat >> "$PROJECT_DIR/outputs.tf" << 'EOF'

output "instance_ip_address" {
  description = "IPv4 address of the Linode instance"
  value       = linode_instance.main.ip_address
}
output "instance_id" {
  description = "ID of the Linode instance"
  value       = linode_instance.main.id
}
output "root_password" {
  description = "Root password for the instance (if not using SSH keys)"
  value       = random_password.root_password.result
  sensitive   = true
}
output "ssh_command" {
   description = "Command to SSH into the Linode"
   value       = "ssh -i ~/.ssh/id_rsa root@${linode_instance.main.ip_address}"
}
EOF
        then echo -e "${RED}Failed to add Linode self-hosted outputs.${RESET}" >&2; success=false; fi ;;
      hcloud)
        if ! cat >> "$PROJECT_DIR/outputs.tf" << 'EOF'

output "server_ipv4_address" {
  description = "IPv4 address of the Hetzner server"
  value       = hcloud_server.main.ipv4_address
}
output "server_id" {
  description = "ID of the Hetzner server"
  value       = hcloud_server.main.id
}
output "ssh_command" {
   description = "Command to SSH into the Hetzner server"
   value       = "ssh -i ~/.ssh/id_rsa root@${hcloud_server.main.ipv4_address}"
}
EOF
        then echo -e "${RED}Failed to add Hetzner self-hosted outputs.${RESET}" >&2; success=false; fi ;;
      exoscale)
        if ! cat >> "$PROJECT_DIR/outputs.tf" << 'EOF'

output "instance_ip_address" {
  description = "IPv4 address of the Exoscale instance"
  value       = exoscale_compute_instance.main.ip_address
}
output "instance_id" {
  description = "ID of the Exoscale instance"
  value       = exoscale_compute_instance.main.id
}
output "ssh_command" {
   description = "Command to SSH into the Exoscale instance"
   # User depends on template, often 'ubuntu' for Ubuntu templates
   value       = "ssh -i ~/.ssh/id_rsa ubuntu@${exoscale_compute_instance.main.ip_address}"
}
EOF
        then echo -e "${RED}Failed to add Exoscale self-hosted outputs.${RESET}" >&2; success=false; fi ;;
      ovh | openstack | infomaniak)
        if ! cat >> "$PROJECT_DIR/outputs.tf" << 'EOF'

output "instance_floating_ip" {
  description = "Floating IP address of the OpenStack instance"
  value       = openstack_compute_floatingip_v2.fip.address
}
output "instance_id" {
  description = "ID of the OpenStack instance"
  value       = openstack_compute_instance_v2.main.id
}
output "ssh_command" {
   description = "Command to SSH into the OpenStack instance"
   # User depends on image, often 'ubuntu' or 'centos'
   value       = "ssh -i ~/.ssh/id_rsa ubuntu@${openstack_compute_floatingip_v2.fip.address}"
}
EOF
        then echo -e "${RED}Failed to add OpenStack self-hosted outputs.${RESET}" >&2; success=false; fi ;;
       *)
         if ! echo "# No self-hosted outputs defined for $SELECTED_PROVIDER" >> "$PROJECT_DIR/outputs.tf"; then success=false; fi ;;
    esac
  else # Managed service outputs
    case $SELECTED_PROVIDER in
      aws)
        if ! cat >> "$PROJECT_DIR/outputs.tf" << 'EOF'

output "s3_bucket_name" {
  description = "Name of the S3 bucket for static website"
  value       = aws_s3_bucket.website.bucket
}
output "s3_website_endpoint" {
  description = "S3 static website endpoint URL"
  value       = "http://${aws_s3_bucket_website_configuration.website.website_endpoint}"
}
output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.website.id
}
output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution (use this for access)"
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
}
EOF
        then echo -e "${RED}Failed to add AWS managed outputs.${RESET}" >&2; success=false; fi ;;
      azure)
        if ! cat >> "$PROJECT_DIR/outputs.tf" << 'EOF'

output "webapp_default_hostname" {
  description = "Default hostname of the Linux Web App"
  value       = azurerm_linux_web_app.main.default_hostname
}
output "webapp_url" {
   description = "URL to access the Web App"
   value       = "https://${azurerm_linux_web_app.main.default_hostname}"
}
output "webapp_name" {
  description = "Name of the Linux Web App"
  value       = azurerm_linux_web_app.main.name
}
EOF
        then echo -e "${RED}Failed to add Azure managed outputs.${RESET}" >&2; success=false; fi ;;
      gcp)
        if ! cat >> "$PROJECT_DIR/outputs.tf" << 'EOF'

output "cloud_run_service_name" {
  description = "Name of the Cloud Run service"
  value       = google_cloud_run_v2_service.main.name
}
output "cloud_run_service_url" {
  description = "URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.main.uri
}
EOF
        then echo -e "${RED}Failed to add GCP managed outputs.${RESET}" >&2; success=false; fi ;;
      digitalocean)
        if ! cat >> "$PROJECT_DIR/outputs.tf" << 'EOF'

output "app_id" {
  description = "ID of the App Platform app"
  value       = digitalocean_app.main.id
}
output "app_live_url" {
  description = "Live URL of the App Platform app"
  value       = digitalocean_app.main.live_url
}
output "app_default_ingress" {
   description = "Default ingress hostname for the app"
   value       = digitalocean_app.main.default_ingress # May need https:// prefix
}
EOF
        then echo -e "${RED}Failed to add DigitalOcean managed outputs.${RESET}" >&2; success=false; fi ;;
      vercel)
        if ! cat >> "$PROJECT_DIR/outputs.tf" << 'EOF'

output "project_id" {
  description = "ID of the Vercel project"
  value       = vercel_project.main.id
}
output "project_url" {
  description = "Primary URL of the Vercel deployment"
  # The actual URL depends on custom domains or the default Vercel URL
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "https://${vercel_project.main.name}.vercel.app"
}
EOF
        then echo -e "${RED}Failed to add Vercel managed outputs.${RESET}" >&2; success=false; fi ;;
      fly)
        if ! cat >> "$PROJECT_DIR/outputs.tf" << 'EOF'

output "app_name" {
  description = "Name of the Fly app"
  value       = fly_app.main.name
}
output "app_hostname" {
  description = "Default hostname for the Fly app"
  value       = fly_app.main.hostname
}
output "app_url" {
   description = "URL to access the Fly app"
   value       = "https://${fly_app.main.hostname}"
}
output "ipv4_address" {
  description = "Allocated IPv4 address"
  value       = fly_ip.shared_v4.address
}
EOF
        then echo -e "${RED}Failed to add Fly.io managed outputs.${RESET}" >&2; success=false; fi ;;
      render)
        if ! cat >> "$PROJECT_DIR/outputs.tf" << 'EOF'

output "service_id" {
  description = "ID of the Render service"
  value       = render_service.web.id
}
output "service_url" {
  description = "URL of the Render service"
  # The URL might be in service_details, but this attribute access might change
  # Refer to the specific provider version documentation
  value       = render_service.web.service_url # Check attribute name
}
EOF
        then echo -e "${RED}Failed to add Render managed outputs.${RESET}" >&2; success=false; fi ;;
      netlify)
        if ! cat >> "$PROJECT_DIR/outputs.tf" << 'EOF'

output "site_id" {
  description = "ID of the Netlify site"
  value       = netlify_site.main.id
}
output "site_url" {
  description = "Primary URL of the Netlify site"
  value       = netlify_site.main.ssl_url # Use SSL URL
}
output "site_name" {
   description = "Name of the Netlify site"
   value       = netlify_site.main.name
}
EOF
        then echo -e "${RED}Failed to add Netlify managed outputs.${RESET}" >&2; success=false; fi ;;
      cloudflare)
        if ! cat >> "$PROJECT_DIR/outputs.tf" << 'EOF'

output "pages_project_name" {
  description = "Name of the Cloudflare Pages project"
  value       = cloudflare_pages_project.main.name
}
output "pages_project_subdomain" {
  description = "Default subdomain for the Pages project"
  value       = cloudflare_pages_project.main.subdomain # e.g., project-name.pages.dev
}
output "pages_url" {
  description = "Default URL of the Cloudflare Pages site"
  value       = "https://${cloudflare_pages_project.main.subdomain}"
}
EOF
        then echo -e "${RED}Failed to add Cloudflare managed outputs.${RESET}" >&2; success=false; fi ;;
       *)
         if ! echo "# No managed outputs defined for $SELECTED_PROVIDER" >> "$PROJECT_DIR/outputs.tf"; then success=false; fi ;;
    esac
  fi


  # --- README.md ---
  # Start README using heredoc with expansion for PROJECT_NAME etc.
  if ! cat > "$PROJECT_DIR/README.md" << EOF
# $PROJECT_NAME

Infrastructure as Code project for $PROJECT_NAME using OpenTofu on $SELECTED_PROVIDER.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Infrastructure Components](#infrastructure-components)
- [Deployment](#deployment)
- [Configuration](#configuration)
- [Maintenance](#maintenance)

## Overview

This project uses OpenTofu to manage infrastructure for deploying '$PROJECT_NAME' on $SELECTED_PROVIDER ($HOSTING_TYPE hosting).

## Prerequisites

- OpenTofu ${TOFU_VERSION} or later ([Installation Guide](https://opentofu.org/docs/intro/install/))
- $SELECTED_PROVIDER credentials configured (e.g., via environment variables, config files)
- Git
- jq
- SSH Key Pair (`~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub` - required for VM access)
$( $CADDY_ENABLED && [ "$HOSTING_TYPE" == "self" ] && echo "- Access to configure DNS for '$DOMAIN_NAME' (for Caddy SSL)")
$( $REPO_TRANSFER_ENABLED && echo "- GitHub CLI ('gh') installed and authenticated (for repository transfer)")
$( $BILLING_ENABLED && echo "- 'bc' command-line calculator (for invoice generation script)")
$( $BILLING_ENABLED && echo "- 'pandoc' (optional, for PDF invoice generation)")

## Getting Started

1.  **Clone this repository** (if not already done).
2.  **Navigate to Project Directory**:
    \`\`\`bash
    cd "$PROJECT_NAME"
    \`\`\`
3.  **Review Configuration**: Check and update values in \`terraform.tfvars.json\` if needed. Ensure your provider credentials are set up correctly.
4.  **Initialize OpenTofu**: This downloads necessary providers.
    \`\`\`bash
    tofu init
    \`\`\`
5.  **Plan Deployment**: See what changes OpenTofu will make.
    \`\`\`bash
    tofu plan
    \`\`\`
6.  **Apply Changes**: Provision the infrastructure.
    \`\`\`bash
    tofu apply
    \`\`\`
    Or use the deployment script:
    \`\`\`bash
    ./deploy.sh
    \`\`\`

## Infrastructure Components

This project provisions the following main resources on $SELECTED_PROVIDER:

EOF
  then
    echo -e "${RED}Failed to create README.md.${RESET}" >&2; success=false
  fi

  # Add provider-specific components to README conditionally
  readme_components=""
  if [ "$HOSTING_TYPE" == "self" ]; then
     case $SELECTED_PROVIDER in
       aws) readme_components="- VPC, Subnets, Internet Gateway, Route Table\n- Security Group (Web/SSH)\n- EC2 Instance\n- Key Pair" ;;
       azure) readme_components="- Resource Group\n- Virtual Network & Subnet\n- Network Security Group\n- Public IP\n- Network Interface\n- Linux Virtual Machine" ;;
       gcp) readme_components="- VPC Network & Subnet\n- Firewall Rule (Web/SSH)\n- Compute Engine VM Instance" ;;
       digitalocean) readme_components="- VPC\n- Droplet\n- Firewall\n- SSH Key (Data Source or Resource)" ;;
       linode) readme_components="- Linode Instance\n- Firewall" ;;
       hcloud) readme_components="- Hetzner Server\n- SSH Key\n- Firewall & Attachment" ;;
       exoscale) readme_components="- Security Group & Rules\n- SSH Keypair\n- Compute Instance" ;;
       ovh | openstack | infomaniak) readme_components="- Network & Subnet\n- Router & Interface\n- Security Group & Rules\n- Key Pair\n- Compute Instance\n- Floating IP" ;;
       *) readme_components="- Basic Compute Instance\n- Networking components (VPC/Subnet/Firewall as applicable)" ;;
     esac
  else # Managed
      case $SELECTED_PROVIDER in
       aws) readme_components="- S3 Bucket (configured for static website hosting)\n- S3 Bucket Policy (public read)\n- CloudFront Distribution" ;;
       azure) readme_components="- Resource Group\n- App Service Plan\n- Linux Web App" ;;
       gcp) readme_components="- Cloud Run v2 Service\n- IAM Binding (for public access)" ;;
       digitalocean) readme_components="- App Platform App (with Service definition)" ;;
       vercel) readme_components="- Vercel Project\n- Optional: Custom Domain, Environment Variables" ;;
       fly) readme_components="- Fly App\n- Fly Machine\n- Fly IP Address" ;;
       render) readme_components="- Render Service (Web/Static/Worker)" ;;
       netlify) readme_components="- Netlify Site (linked to Git repo)\n- Build Settings" ;;
       cloudflare) readme_components="- Cloudflare Pages Project (linked to Git repo)\n- Build Configuration" ;;
        *) readme_components="- Managed Platform Service (details depend on provider)" ;;
     esac
  fi

  if [ -n "$readme_components" ]; then
      if ! echo -e "$readme_components" >> "$PROJECT_DIR/README.md"; then
          echo -e "${RED}Failed to add infrastructure components to README.${RESET}" >&2; success=false
      fi
  fi

  # Add Caddy component if enabled
  if $CADDY_ENABLED && [ "$HOSTING_TYPE" == "self" ]; then
    if ! echo -e "- Caddy server configuration (via provisioner or manual script)" >> "$PROJECT_DIR/README.md"; then
      echo -e "${RED}Failed to add Caddy component to README.md.${RESET}" >&2; success=false
    fi
  fi

  # Finish README.md
  # Use single quotes for heredoc 'EOF' to prevent issues with backticks
  if ! cat >> "$PROJECT_DIR/README.md" << 'EOF'

## Deployment Script (`deploy.sh`)

A helper script `deploy.sh` is included in the project directory to automate the `init`, `plan`, and `apply` steps with confirmation.

```bash
./deploy.sh
```

## Configuration

- **Main Variables**: Edit `terraform.tfvars.json` to set required provider variables (region, instance types, etc.).
- **Provider Credentials**: Ensure your cloud provider credentials are configured securely (e.g., environment variables `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `GOOGLE_CREDENTIALS`, `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`, `DO_TOKEN`, `LINODE_TOKEN`, `HCLOUD_TOKEN`, etc., or provider-specific config files).
- **SSH Key**: Ensure `~/.ssh/id_rsa.pub` exists and corresponds to the private key `~/.ssh/id_rsa` used for SSH access.

## Maintenance

- **Update Infrastructure**: Modify the `.tf` files as needed, then run `./deploy.sh` or `tofu plan` followed by `tofu apply`.
- **Destroy Infrastructure**: To remove all resources managed by this configuration, run:
  ```bash
  tofu destroy
  ```
  **Warning**: This action is irreversible.

EOF
  then
    echo -e "${RED}Failed to finalize README.md.${RESET}" >&2; success=false
  fi

  # --- deploy.sh ---
  # Create deploy.sh script (using single quotes 'EOF')
  if ! cat > "$PROJECT_DIR/deploy.sh" << 'EOF'
#!/bin/bash
# Deploy script for OpenTofu infrastructure

# Strict mode
set -e
set -u
set -o pipefail

# Colors for terminal output
RESET="\033[0m"
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"

# Error handling function
handle_error() {
  local line=$1
  local command=$2
  local code=$3
  echo -e "${RED}Error occurred in command '$command' on line $line with exit code $code${RESET}" >&2
  # Clean up plan file if it exists on error
  rm -f tfplan
  exit $code
}

# Set up error handling trap
trap 'handle_error ${LINENO} "$BASH_COMMAND" $?' ERR

# --- Main Deployment Logic ---

# Print banner
echo -e "${BOLD}${BLUE}=====================================${RESET}"
echo -e "${BOLD}${BLUE}  Deploying Infrastructure with OpenTofu  ${RESET}"
echo -e "${BOLD}${BLUE}=====================================${RESET}"
echo

# Check if OpenTofu is installed
if ! command -v tofu &> /dev/null; then
    echo -e "${RED}Error: OpenTofu ('tofu') command not found. Please install it first.${RESET}" >&2
    exit 1
fi
echo -e "${GREEN}✓ OpenTofu found: $(command -v tofu)${RESET}"
tofu version

# Initialize OpenTofu (downloads providers)
echo
echo -e "${BOLD}Initializing OpenTofu...${RESET}"
# The -upgrade flag can be useful if provider versions changed
if ! tofu init -upgrade; then
    echo -e "${RED}Failed to initialize OpenTofu.${RESET}" >&2
    exit 1
fi
echo -e "${GREEN}✓ OpenTofu initialized successfully.${RESET}"

# Validate configuration
echo
echo -e "${BOLD}Validating configuration...${RESET}"
if ! tofu validate; then
    echo -e "${RED}Terraform configuration validation failed.${RESET}" >&2
    exit 1
fi
echo -e "${GREEN}✓ Configuration validation successful.${RESET}"


# Plan the deployment (saves plan to tfplan)
echo
echo -e "${BOLD}Planning deployment...${RESET}"
if ! tofu plan -out=tfplan; then
    echo -e "${RED}Failed to create deployment plan.${RESET}" >&2
    exit 1
fi
echo -e "${GREEN}✓ Deployment plan created successfully (tfplan).${RESET}"

# Ask for confirmation
echo
echo -e "${YELLOW}Review the plan generated above.${RESET}"
read -p "Do you want to apply these changes? [y/N]: " apply_confirm

if [[ "$apply_confirm" =~ ^[Yy]$ ]]; then
    # Apply the plan
    echo
    echo -e "${BOLD}Applying deployment plan...${RESET}"
    if ! tofu apply -auto-approve tfplan; then # Use auto-approve as we already confirmed
        echo -e "${RED}Failed to apply deployment plan.${RESET}" >&2
        # Keep tfplan file for debugging if apply fails
        exit 1
    fi

    # Clean up plan file on success
    rm -f tfplan

    # Show outputs
    echo
    echo -e "${BOLD}Deployment completed successfully. Outputs:${RESET}"
    if ! tofu output; then
       echo -e "${YELLOW}Warning: Failed to retrieve outputs after apply.${RESET}" >&2
    fi

    echo
    echo -e "${GREEN}✓ Infrastructure deployment successful!${RESET}"
else
    echo -e "${YELLOW}Deployment aborted by user.${RESET}"
    # Clean up plan file if aborted
    rm -f tfplan
    exit 0 # Exit cleanly if user aborts
fi
EOF
  then
    echo -e "${RED}Failed to create deploy.sh script.${RESET}" >&2; success=false
  fi

  # Make deploy.sh executable
  if ! chmod +x "$PROJECT_DIR/deploy.sh"; then
    echo -e "${RED}Failed to make deploy.sh executable.${RESET}" >&2; success=false
  fi

  # --- Final Check ---
  if $success; then
    echo -e "${GREEN}✓ OpenTofu files generated successfully${RESET}"
    return 0
  else
    echo -e "${RED}Errors occurred during OpenTofu file generation.${RESET}" >&2
    return 1
  fi
}


# Generate Caddy configuration - Enhanced
generate_caddy_config() {
  # Only proceed if Caddy is enabled AND hosting is self-hosted
  if ! $CADDY_ENABLED || [ "$HOSTING_TYPE" != "self" ]; then
      # This case should ideally be caught earlier, but double-check
       echo -e "${CYAN}Skipping Caddy config generation (not enabled or not self-hosted).${RESET}"
       return 0
  fi

  echo -e "${BOLD}Generating Caddy configuration...${RESET}"
  local caddy_dir="$PROJECT_DIR/caddy"
  local success=true

  # Create Caddy directory
  if ! safe_mkdir "$caddy_dir"; then
    echo -e "${RED}Failed to create Caddy directory: $caddy_dir${RESET}" >&2
    return 1 # Fail if directory cannot be created
  fi

  # Generate Caddyfile - Use variable expansion carefully
  # Ensure DOMAIN_NAME and EMAIL are set (should be done in configure_project)
  local caddyfile_content
  # Use printf for better control over formatting and quoting issues
  if ! caddyfile_content=$(printf '%s\n' \
      "{" \
      "  email ${EMAIL}" \
      "}" \
      "" \
      "${DOMAIN_NAME} {" \
      "  root * /var/www/html" \
      "  file_server" \
      "  encode gzip zstd" \
      "" \
      "  log {" \
      "    output file /var/log/caddy/${DOMAIN_NAME}.log {" \
      "        roll_keep_for 7d # Keep logs for 7 days" \
      "    }" \
      "  }" \
      "" \
      "  # Example reverse proxy (uncomment and adjust if needed)" \
      "  # reverse_proxy localhost:8080" \
      "}"); then
     echo -e "${RED}Failed to format Caddyfile content.${RESET}" >&2
     return 1
  fi

   if ! echo "$caddyfile_content" > "$caddy_dir/Caddyfile"; then
      echo -e "${RED}Failed to create Caddyfile: $caddy_dir/Caddyfile${RESET}" >&2
      success=false
   fi


  # Create caddy deployment script (deploy-caddy.sh)
  # Use single quotes 'EOF' to prevent premature expansion
  if ! cat > "$caddy_dir/deploy-caddy.sh" << 'EOF'
#!/bin/bash
# Installs/Configures Caddy on a remote Ubuntu/Debian server via SSH

# Strict mode
set -e
set -u
set -o pipefail

# Colors
RESET="\033[0m"
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"

# Error handling function for this script
handle_script_error() {
  local line=$1
  local command=$2
  local code=$3
  echo -e "${RED}Error in deploy-caddy.sh: Command '$command' on line $line failed with exit code $code${RESET}" >&2
  exit $code
}
trap 'handle_script_error ${LINENO} "$BASH_COMMAND" $?' ERR

# --- Configuration ---
SSH_USER="ubuntu" # Default user for cloud VMs, change if needed (e.g., ec2-user, adminuser, root)
SSH_KEY="~/.ssh/id_rsa" # Path to your private SSH key
CADDYFILE_LOCAL_PATH="./Caddyfile" # Path to the Caddyfile in the current directory
CADDYFILE_REMOTE_PATH="/etc/caddy/Caddyfile"
WEB_ROOT="/var/www/html"
TEST_PAGE_CONTENT="<h1>Hello from Caddy!</h1> Managed by cloud-deploy."

# --- Script Logic ---

# Check usage
if [ $# -lt 1 ]; then
  echo -e "${YELLOW}Usage: $0 <server_ip_or_hostname>${RESET}" >&2
  echo "Example: $0 192.0.2.10" >&2
  exit 1
fi
SERVER_ADDR="$1"

# Check if local Caddyfile exists
if [ ! -f "$CADDYFILE_LOCAL_PATH" ]; then
   echo -e "${RED}Error: Local Caddyfile not found at '$CADDYFILE_LOCAL_PATH'${RESET}" >&2
   exit 1
fi

# Check if SSH key exists
if [ ! -f "$SSH_KEY" ]; then
  echo -e "${RED}Error: SSH private key not found at '$SSH_KEY'. Use -i option or place key correctly.${RESET}" >&2
  # Could enhance to allow passing key via -i argument
  exit 1
fi

# Test SSH connection
echo -e "${BOLD}Testing SSH connection to $SSH_USER@$SERVER_ADDR...${RESET}"
if ! ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=10 "$SSH_USER@$SERVER_ADDR" echo "SSH connection successful." 2>/dev/null; then
  echo -e "${RED}Error: Cannot connect to server $SERVER_ADDR as user $SSH_USER.${RESET}" >&2
  echo "Troubleshooting tips:" >&2
  echo "- Ensure the server IP/hostname is correct." >&2
  echo "- Verify the SSH user '$SSH_USER' is correct for the server's OS." >&2
  echo "- Check if your public key (${SSH_KEY}.pub) is in ~/.ssh/authorized_keys on the server." >&2
  echo "- Ensure the server's firewall (Security Group, NSG, ufw) allows SSH (port 22) from your IP." >&2
  exit 1
fi
echo -e "${GREEN}✓ SSH connection successful.${RESET}"


# SSH into the server and perform setup/installation
echo -e "${BOLD}Running remote setup via SSH...${RESET}"
# Use heredoc for remote commands. Escape remote variables ($) if needed.
if ! ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_ADDR" "bash -s" << 'ENDSSH'
set -e # Use strict mode on remote server too
set -u
echo "--- Starting remote execution ---"

# Check if Caddy is already installed
if command -v caddy &> /dev/null; then
    echo "Caddy already installed. Version: $(caddy version)"
    echo "Ensuring Caddy service is enabled..."
    sudo systemctl enable caddy || { echo "Failed to enable Caddy service"; exit 1; }
else
    # Install Caddy (Debian/Ubuntu)
    echo "Installing Caddy..."
    sudo apt-get update -qq || { echo "Failed to update apt cache"; exit 1; }
    # Install prerequisites quietly
    sudo apt-get install -y -qq debian-keyring debian-archive-keyring apt-transport-https curl || { echo "Failed to install prerequisites"; exit 1; }
    # Add Caddy repository GPG key
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg || { echo "Failed to download Caddy GPG key"; exit 1; }
    # Add Caddy repository source list
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null || { echo "Failed to add Caddy repository source"; exit 1; }
    # Update cache again and install Caddy quietly
    sudo apt-get update -qq || { echo "Failed to update apt cache after adding repo"; exit 1; }
    sudo apt-get install -y -qq caddy || { echo "Failed to install Caddy package"; exit 1; }
    echo "Caddy installed successfully."
    sudo systemctl enable caddy || { echo "Failed to enable Caddy service"; exit 1; }
fi

# Create web root directory
echo "Ensuring web root directory exists: ${WEB_ROOT}"
sudo mkdir -p "${WEB_ROOT}" || { echo "Failed to create web root directory"; exit 1; }
# Set appropriate permissions (example: readable by Caddy user, often 'caddy' or 'www-data')
sudo chown -R caddy:caddy "${WEB_ROOT}" || sudo chown -R www-data:www-data "${WEB_ROOT}" || echo "Warning: Could not set ownership of ${WEB_ROOT}"
sudo chmod -R 755 "${WEB_ROOT}" || echo "Warning: Could not set permissions for ${WEB_ROOT}"


# Create a test page
echo "Creating/updating test page: ${WEB_ROOT}/index.html"
echo "${TEST_PAGE_CONTENT}" | sudo tee "${WEB_ROOT}/index.html" > /dev/null || { echo "Failed to create test page"; exit 1; }

# Ensure Caddy config directory exists
echo "Ensuring Caddy config directory exists: /etc/caddy"
sudo mkdir -p /etc/caddy || { echo "Failed to create Caddy config directory"; exit 1; }

echo "--- Remote execution finished ---"
ENDSSH
then
   echo -e "${RED}Error during remote setup via SSH.${RESET}" >&2
   exit 1
fi
echo -e "${GREEN}✓ Remote setup completed.${RESET}"

# Copy Caddyfile to the server using scp
echo -e "${BOLD}Copying Caddyfile to server...${RESET}"
if ! scp -i "$SSH_KEY" "$CADDYFILE_LOCAL_PATH" "$SSH_USER@$SERVER_ADDR:/tmp/Caddyfile.tmp"; then
  echo -e "${RED}Error: Failed to copy Caddyfile to server.${RESET}" >&2
  exit 1
fi
echo -e "${GREEN}✓ Caddyfile copied to /tmp/Caddyfile.tmp on server.${RESET}"

# Move Caddyfile into place and reload Caddy service via SSH
echo -e "${BOLD}Moving Caddyfile and reloading Caddy service...${RESET}"
if ! ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_ADDR" "bash -s" << 'ENDSSH'
set -e # Use strict mode on remote server too
echo "--- Moving Caddyfile and reloading service ---"

# Validate Caddyfile syntax before moving (optional but recommended)
echo "Validating Caddyfile syntax..."
if ! sudo caddy fmt --overwrite /tmp/Caddyfile.tmp; then
    echo "Warning: Caddyfile formatting failed, continuing anyway..."
    # Optionally exit here if formatting is critical: exit 1;
fi
if ! sudo caddy validate --config /tmp/Caddyfile.tmp --adapter caddyfile; then
    echo "Error: Caddyfile validation failed. Please check '$CADDYFILE_LOCAL_PATH' syntax." >&2
    # Remove temporary file on failure
    sudo rm -f /tmp/Caddyfile.tmp
    exit 1
fi
echo "Caddyfile validation successful."

# Move the validated Caddyfile into place
echo "Moving temporary Caddyfile to ${CADDYFILE_REMOTE_PATH}"
sudo mv /tmp/Caddyfile.tmp "${CADDYFILE_REMOTE_PATH}" || { echo "Failed to move Caddyfile"; exit 1; }

# Set correct ownership/permissions for Caddyfile
sudo chown root:root "${CADDYFILE_REMOTE_PATH}" || echo "Warning: Could not set Caddyfile owner to root:root"
sudo chmod 644 "${CADDYFILE_REMOTE_PATH}" || echo "Warning: Could not set Caddyfile permissions to 644"

# Reload Caddy service (graceful reload)
echo "Reloading Caddy service..."
sudo systemctl reload caddy || { echo "Failed to reload Caddy. Trying restart..."; sudo systemctl restart caddy || { echo "Failed to restart Caddy either."; exit 1; } }

# Check Caddy status
echo "Checking Caddy service status..."
if sudo systemctl is-active --quiet caddy; then
  echo "Caddy service is active."
else
  echo "Error: Caddy service is not active after reload/restart." >&2
  sudo systemctl status caddy --no-pager # Show status details
  exit 1
fi

echo "--- Caddy reload finished ---"
ENDSSH
then
    echo -e "${RED}Error during Caddyfile deployment and service reload.${RESET}" >&2
    exit 1
fi

echo
echo -e "${GREEN}✓ Caddy deployment and configuration completed successfully!${RESET}"
echo -e "You should now be able to access your site."
echo -e "Check Caddy logs on the server: ${YELLOW}sudo journalctl -u caddy -f${RESET}"

EOF
  then
    echo -e "${RED}Failed to create Caddy deployment script.${RESET}" >&2
    success=false
  fi

  # Make caddy deployment script executable
  if ! chmod +x "$caddy_dir/deploy-caddy.sh"; then
    echo -e "${RED}Failed to make Caddy deployment script executable.${RESET}" >&2
    success=false
  fi

  if $success; then
    echo -e "${GREEN}✓ Caddy configuration and deployment script generated${RESET}"
    return 0
  else
     echo -e "${RED}Errors occurred during Caddy configuration generation.${RESET}" >&2
     return 1
  fi
}


# Generate repository transfer scripts - Enhanced
generate_repo_transfer_scripts() {
  # Only proceed if enabled
  if ! $REPO_TRANSFER_ENABLED; then
     echo -e "${CYAN}Skipping repository transfer script generation (not enabled).${RESET}"
     return 0
  fi
   # Check gh was confirmed earlier
  if ! command -v gh &> /dev/null; then
     echo -e "${YELLOW}Warning: gh command not found, cannot generate functional repo transfer script.${RESET}" >&2
     return 0 # Don't fail the whole script, just skip this part
  fi


  echo -e "${BOLD}Generating repository transfer scripts...${RESET}"
  local scripts_dir="$PROJECT_DIR/scripts"
  local success=true

  # Create scripts directory
  if ! safe_mkdir "$scripts_dir"; then
    echo -e "${RED}Failed to create scripts directory: $scripts_dir${RESET}" >&2
    return 1 # Fail if directory cannot be created
  fi

  # --- repo-transfer.sh ---
  # Generate script with embedded config loading and error handling
  # Use single quotes 'EOF' for the main script template
  if ! cat > "$scripts_dir/repo-transfer.sh" << 'EOF'
#!/bin/bash
# Transfers repository ownership or adds collaborator based on .repo-transfer.json

# Strict mode
set -e
set -u
set -o pipefail

# Colors
RESET="\033[0m"
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"

# Config file location relative to this script's execution directory
# Assumes script is run from within the 'scripts' directory
CONFIG_FILE="../.repo-transfer.json"

# Error handling function for this script
handle_script_error() {
  local line=$1
  local command=$2
  local code=$3
  echo -e "${RED}Error in repo-transfer.sh: Command '$command' on line $line failed with exit code $code${RESET}" >&2
  exit $code
}
trap 'handle_script_error ${LINENO} "$BASH_COMMAND" $?' ERR

# --- Helper: Check command ---
check_cmd_gh() {
  if ! command -v "$1" &> /dev/null; then
    echo -e "${RED}Error: Command '$1' not found.${RESET}" >&2
    if [ -n "$2" ]; then echo -e "Hint: $2" >&2; fi
    exit 1
  fi
}

# --- Main Logic ---

# Check dependencies
check_cmd_gh "gh" "Install GitHub CLI from https://cli.github.com/"
check_cmd_gh "jq" "Install jq (e.g., apt install jq, brew install jq)"

# Load configuration from JSON file
if [ ! -f "$CONFIG_FILE" ]; then
  echo -e "${RED}Error: Repository transfer configuration file not found at '$CONFIG_FILE'.${RESET}" >&2
  echo "Expected file format in ../.repo-transfer.json:" >&2
  echo '{ "source": {"username": "...", "repo": "..."}, "destination": {"username": "...", "repo": "..."}, "permissions": {"role": "admin|maintain"} }' >&2
  exit 1
fi

echo -e "${BOLD}Loading transfer configuration from $CONFIG_FILE...${RESET}"
# Extract variables safely using jq
SOURCE_USER=$(jq -r '.source.username // ""' "$CONFIG_FILE")
SOURCE_REPO=$(jq -r '.source.repo // ""' "$CONFIG_FILE")
DEST_USER=$(jq -r '.destination.username // ""' "$CONFIG_FILE")
DEST_REPO=$(jq -r '.destination.repo // ""' "$CONFIG_FILE")
PERMISSIONS=$(jq -r '.permissions.role // "maintain"' "$CONFIG_FILE") # Default to 'maintain'

# Validate required variables
if [ -z "$SOURCE_USER" ] || [ -z "$SOURCE_REPO" ] || [ -z "$DEST_USER" ] || [ -z "$DEST_REPO" ]; then
  echo -e "${RED}Error: Missing required configuration values in '$CONFIG_FILE'.${RESET}" >&2
  echo "Ensure source.username, source.repo, destination.username, and destination.repo are set." >&2
  exit 1
fi
echo -e "${GREEN}✓ Configuration loaded.${RESET}"
echo "Source: $SOURCE_USER/$SOURCE_REPO"
echo "Destination: $DEST_USER/$DEST_REPO"
echo "Permissions/Role: $PERMISSIONS"

# Print banner
echo
echo -e "${BOLD}${BLUE}=====================================${RESET}"
echo -e "${BOLD}${BLUE}    GitHub Repository Transfer Utility    ${RESET}"
echo -e "${BOLD}${BLUE}=====================================${RESET}"
echo

# Check if logged in to GitHub
echo -e "${BOLD}Checking GitHub authentication...${RESET}"
if ! gh auth status; then
    echo -e "${YELLOW}You are not logged in to GitHub CLI.${RESET}" >&2
    read -p "Would you like to log in now? [y/N]: " login_now
    if [[ "$login_now" =~ ^[Yy]$ ]]; then
        if ! gh auth login; then
          echo -e "${RED}Failed to log in to GitHub CLI.${RESET}" >&2
          exit 1
        fi
    else
        echo -e "${RED}GitHub CLI authentication required to proceed.${RESET}" >&2
        exit 1
    fi
fi
echo -e "${GREEN}✓ Authenticated with GitHub CLI.${RESET}"


# Transfer options
echo
echo -e "${BOLD}Select Repository Transfer Option:${RESET}"
echo "1. ${BOLD}Create New Repo & Push:${RESET} Create a new private repository '$DEST_USER/$DEST_REPO' and push the current project code to it."
echo "2. ${BOLD}Add Collaborator:${RESET} Add '$DEST_USER' as a collaborator with '$PERMISSIONS' permissions to the existing '$SOURCE_USER/$SOURCE_REPO' repository."
echo "3. ${BOLD}Transfer Ownership:${RESET} Initiate transfer of ownership of '$SOURCE_USER/$SOURCE_REPO' to '$DEST_USER'. (Requires acceptance by '$DEST_USER')."
echo "4. ${BOLD}Cancel${RESET}"

local transfer_option
while true; do
    read -p "Enter your choice [1-4]: " transfer_option
    case $transfer_option in
        1|2|3|4) break ;;
        *) echo -e "${YELLOW}Invalid choice. Please enter 1, 2, 3, or 4.${RESET}" >&2 ;;
    esac
done


case $transfer_option in
  1) # Create New Repo & Push
    echo
    echo -e "${BOLD}Option 1: Creating new repository and pushing code...${RESET}"

    # Check if destination repo already exists
    echo "Checking if '$DEST_USER/$DEST_REPO' already exists..."
    if gh repo view "$DEST_USER/$DEST_REPO" > /dev/null 2>&1; then
       echo -e "${YELLOW}Warning: Repository '$DEST_USER/$DEST_REPO' already exists.${RESET}" >&2
       read -p "Do you want to proceed and push to the existing repository? [y/N]: " push_existing
       if [[ ! "$push_existing" =~ ^[Yy]$ ]]; then
          echo "Operation cancelled."
          exit 0
       fi
    else
       # Create new private repository in client's account/org
       echo -e "Creating new private repository: $DEST_USER/$DEST_REPO"
       # Use --private flag, add --org if DEST_USER is an org? GH CLI handles this.
       if ! gh repo create "$DEST_USER/$DEST_REPO" --private; then
         echo -e "${RED}Failed to create repository. Check permissions and ensure '$DEST_USER' is a valid user/org.${RESET}" >&2
         exit 1
       fi
       echo -e "${GREEN}✓ Repository created successfully.${RESET}"
    fi

    # Assume current directory or parent directory contains the project code
    # Determine project root (assuming script is in project_dir/scripts)
    PROJECT_ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
    if [ ! -d "$PROJECT_ROOT_DIR/.git" ]; then
        echo -e "${RED}Error: Cannot find '.git' directory in '$PROJECT_ROOT_DIR'. Is this a Git repository?${RESET}" >&2
        exit 1
    fi
    echo "Using project root: $PROJECT_ROOT_DIR"

    # Add remote and push
    cd "$PROJECT_ROOT_DIR"
    local client_remote_name="client_transfer"
    echo "Adding temporary remote '$client_remote_name'..."
    # Remove remote first if it exists from a previous failed run
    git remote remove "$client_remote_name" 2>/dev/null || true
    if ! git remote add "$client_remote_name" "https://github.com/$DEST_USER/$DEST_REPO.git"; then
      echo -e "${RED}Failed to add git remote '$client_remote_name'.${RESET}" >&2
      exit 1
    fi

    echo "Pushing all branches and tags to '$client_remote_name'..."
    # Use --all to push all branches, --tags for tags
    # Use -u to set upstream for the main/master branch if desired
    # Determine default branch name
    local default_branch
    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
    if [ -z "$default_branch" ]; then default_branch="main"; fi # Fallback

    # Push default branch with upstream tracking
    if ! git push -u "$client_remote_name" "$default_branch"; then
        echo -e "${RED}Failed to push default branch '$default_branch' to '$client_remote_name'.${RESET}" >&2
        git remote remove "$client_remote_name" # Clean up remote on failure
        exit 1
    fi
    # Push remaining branches and tags without setting upstream
    if ! git push "$client_remote_name" --all; then
        echo -e "${YELLOW}Warning: Failed to push all branches (default branch pushed successfully).${RESET}" >&2
    fi
     if ! git push "$client_remote_name" --tags; then
         echo -e "${YELLOW}Warning: Failed to push tags.${RESET}" >&2
     fi


    echo -e "${GREEN}✓ Code pushed successfully to $DEST_USER/$DEST_REPO${RESET}"

    # Optionally remove the temporary remote
    read -p "Remove temporary remote '$client_remote_name'? [Y/n]: " remove_remote
    if [[ "$remove_remote" =~ ^[Yy]$ ]] || [[ -z "$remove_remote" ]]; then
       git remote remove "$client_remote_name"
       echo "Remote '$client_remote_name' removed."
    fi
    cd - > /dev/null # Return to original directory
    ;;

  2) # Add Collaborator
    echo
    echo -e "${BOLD}Option 2: Adding '$DEST_USER' as collaborator to '$SOURCE_USER/$SOURCE_REPO'...${RESET}"
    echo -e "Permission level: ${YELLOW}$PERMISSIONS${RESET}"

    # Use gh api to add collaborator
    # Note: The user needs admin rights on the source repo
    # PUT /repos/{owner}/{repo}/collaborators/{username}
    echo "Sending invitation..."
    if ! gh api "repos/$SOURCE_USER/$SOURCE_REPO/collaborators/$DEST_USER" -X PUT -f permission="$PERMISSIONS" --silent; then
      echo -e "${RED}Failed to add collaborator.${RESET}" >&2
      echo "Ensure '$SOURCE_USER/$SOURCE_REPO' exists and you have admin rights." >&2
      echo "Ensure '$DEST_USER' is a valid GitHub username." >&2
      exit 1
    fi

    echo -e "${GREEN}✓ Invitation sent to $DEST_USER to collaborate on $SOURCE_USER/$SOURCE_REPO with $PERMISSIONS permissions.${RESET}"
    echo -e "${YELLOW}$DEST_USER needs to accept the invitation.${RESET}"
    ;;

  3) # Transfer Ownership
    echo
    echo -e "${BOLD}Option 3: Initiating ownership transfer of '$SOURCE_USER/$SOURCE_REPO' to '$DEST_USER'...${RESET}"
    echo -e "${YELLOW}WARNING: This action cannot be undone easily once accepted by the new owner.${RESET}"
    read -p "Are you absolutely sure you want to initiate this transfer? [y/N]: " confirm_transfer
    if [[ ! "$confirm_transfer" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 0
    fi

    # Use gh api to initiate transfer
    # POST /repos/{owner}/{repo}/transfer
    # Note: The user needs admin rights on the source repo
    echo "Initiating transfer..."
     if ! gh api "repos/$SOURCE_USER/$SOURCE_REPO/transfer" -X POST -f new_owner="$DEST_USER" --silent; then
      echo -e "${RED}Failed to initiate repository transfer.${RESET}" >&2
      echo "Ensure '$SOURCE_USER/$SOURCE_REPO' exists and you have admin rights." >&2
      echo "Ensure '$DEST_USER' is a valid GitHub username or organization where you have create repo rights." >&2
      exit 1
    fi

    echo -e "${GREEN}✓ Repository transfer initiated.${RESET}"
    echo -e "${YELLOW}$DEST_USER needs to accept the transfer invitation within 7 days.${RESET}"
    echo -e "You can manage pending transfers at: https://github.com/account/repositories"
    ;;
  4) # Cancel
    echo "Operation cancelled."
    exit 0
    ;;
esac

echo
echo -e "${BOLD}Next steps:${RESET}"
echo "1. Inform the client about the repository setup/transfer."
echo "2. Share project documentation (e.g., ../CLIENT_README.md) with the client."
echo "3. Configure billing access/setup if applicable."
echo "4. Schedule a handover meeting if needed."

exit 0
EOF
  then
    echo -e "${RED}Failed to create repository transfer script.${RESET}" >&2
    success=false
  fi

  # Make repository transfer script executable
  if $success && ! chmod +x "$scripts_dir/repo-transfer.sh"; then
    echo -e "${RED}Failed to make repository transfer script executable.${RESET}" >&2
    success=false
  fi

  # --- CLIENT_README.md ---
  # Generate client documentation template using variable expansion
  local client_readme_file="$PROJECT_DIR/CLIENT_README.md"
  echo -e "${BOLD}Generating client documentation template ($client_readme_file)...${RESET}"

  # Determine access instructions based on provider
  local access_instructions=""
   case $SELECTED_PROVIDER in
     aws) access_instructions="- **AWS Console**: Log in to the AWS Management Console.\n- **Region**: Resources are primarily in \`${VARS_JSON=$(echo "$PROVIDER_VARS" | jq -r '.region.default // "us-west-2"')}\`.\n- Look for resources tagged with Project: \`$PROJECT_NAME\`." ;;
     azure) access_instructions="- **Azure Portal**: Log in to the Azure Portal.\n- **Resource Group**: Resources are under \`${VARS_JSON=$(echo "$PROVIDER_VARS" | jq -r '.resource_group_name.default // "$PROJECT_NAME-rg"')}\` in location \`${VARS_JSON=$(echo "$PROVIDER_VARS" | jq -r '.location.default // "eastus"')}\`." ;;
     gcp) access_instructions="- **Google Cloud Console**: Log in to the GCP Console.\n- **Project**: Resources are under project ID \`${VARS_JSON=$(echo "$PROVIDER_VARS" | jq -r '.project_id.default // "your-gcp-project-id"')}\` in region \`${VARS_JSON=$(echo "$PROVIDER_VARS" | jq -r '.region.default // "us-central1"')}\`." ;;
     digitalocean) access_instructions="- **DigitalOcean Dashboard**: Log in to the DigitalOcean Dashboard.\n- Look for resources (Droplets, Apps, etc.) tagged with \`$PROJECT_NAME\` in region \`${VARS_JSON=$(echo "$PROVIDER_VARS" | jq -r '.region.default // "nyc3"')}\`." ;;
     vercel) access_instructions="- **Vercel Dashboard**: Log in to Vercel.\n- **Project**: Manage your project named \`${VARS_JSON=$(echo "$PROVIDER_VARS" | jq -r '.project_name.default // "$PROJECT_NAME"')}\`." ;;
     fly) access_instructions="- **Fly.io Dashboard**: Log in to Fly.io.\n- **App**: Manage your application named \`${VARS_JSON=$(echo "$PROVIDER_VARS" | jq -r '.app_name.default // "$PROJECT_NAME"')}\`." ;;
     render) access_instructions="- **Render Dashboard**: Log in to Render.\n- **Service**: Manage your service named \`${VARS_JSON=$(echo "$PROVIDER_VARS" | jq -r '.service_name.default // "$PROJECT_NAME"')}\`." ;;
     netlify) access_instructions="- **Netlify Dashboard**: Log in to Netlify.\n- **Site**: Manage your site (likely named \`${VARS_JSON=$(echo "$PROVIDER_VARS" | jq -r '.site_name.default // "$PROJECT_NAME"')}\` or similar)." ;;
     cloudflare) access_instructions="- **Cloudflare Dashboard**: Log in to Cloudflare.\n- **Account**: \`${VARS_JSON=$(echo "$PROVIDER_VARS" | jq -r '.account_id.default // "your-account-id"')}\`.\n- **Pages Project**: Look for \`$PROJECT_NAME\` under Pages." ;;
     *) access_instructions="- **Provider Dashboard**: Log in to your $SELECTED_PROVIDER dashboard.\n- Look for resources related to project \`$PROJECT_NAME\`." ;;
   esac

  # Determine website access URL - Use outputs if possible, otherwise construct likely URL
  local website_url_info=""
  if [ -n "$DOMAIN_NAME" ]; then
      website_url_info="Your primary website URL is expected to be: **https://\${DOMAIN_NAME}** (DNS configuration might be required)."
  elif [ "$HOSTING_TYPE" == "managed" ]; then
       case $SELECTED_PROVIDER in
         aws) website_url_info="Your website URL is the CloudFront Domain Name provided in the deployment outputs." ;;
         azure) website_url_info="Your website URL is the Web App Default Hostname provided in the deployment outputs." ;;
         gcp) website_url_info="Your website URL is the Cloud Run Service URL provided in the deployment outputs." ;;
         digitalocean) website_url_info="Your website URL is the App Live URL provided in the deployment outputs." ;;
         vercel) website_url_info="Your website URL is the Project URL provided in the deployment outputs." ;;
         fly) website_url_info="Your website URL is the App URL provided in the deployment outputs." ;;
         render) website_url_info="Your website URL is the Service URL provided in the deployment outputs." ;;
         netlify) website_url_info="Your website URL is the Site URL provided in the deployment outputs." ;;
         cloudflare) website_url_info="Your website URL is the Pages URL provided in the deployment outputs." ;;
         *) website_url_info="Your website URL will be provided in the deployment outputs." ;;
       esac
  elif [ "$HOSTING_TYPE" == "self" ]; then
        website_url_info="Your website URL will likely be based on the Public IP Address provided in the deployment outputs (e.g., http://<public_ip>). If using Caddy and a domain, it will be https://<your_domain> once DNS is configured."
  else
       website_url_info="Your website's URL will be provided in the deployment outputs."
  fi

  # Generate billing section conditionally
  local billing_section=""
  if $BILLING_ENABLED; then
      billing_section+="\n## Billing Information\n\n"
      case $BILLING_TYPE in
         fixed) billing_section+="Your project is billed on a fixed fee model. You will be invoiced **\$${MONTHLY_FEE:-0} ${BILLING_INFO=$(echo "$BILLING_INFO" | jq -r '.currency // "USD"')}** per month.\n" ;;
         passthrough) billing_section+="Your project uses a pass-through billing model. You are responsible for paying the infrastructure costs directly to **$SELECTED_PROVIDER**. We recommend setting up billing alerts in your $SELECTED_PROVIDER account.\n" ;;
         hybrid) billing_section+="Your project uses a hybrid billing model. You will be charged a fixed fee of **\$${MONTHLY_FEE:-0} ${BILLING_INFO=$(echo "$BILLING_INFO" | jq -r '.currency // "USD"')}** per month, plus **${COST_PERCENTAGE:-0}%** of the actual infrastructure costs incurred from $SELECTED_PROVIDER.\n" ;;
      esac
      billing_section+="\nBilling cycle: Monthly, typically invoiced around the ${BILLING_INFO=$(echo "$BILLING_INFO" | jq -r '.billing_day // "1")}st of each month for the previous month's service/costs.\n"
      billing_section+="Payment Terms: Net 15 days (unless otherwise specified).\n"
  fi


  # Use cat with EOF (allowing expansion)
  # Escape backticks and dollar signs intended literally
 if ! cat > "$client_readme_file" << EOF
# $PROJECT_NAME - Client Documentation

## Overview

Welcome! This document provides essential information about your **$PROJECT_NAME** project, deployed and managed using modern Infrastructure as Code practices on the **$SELECTED_PROVIDER** cloud platform.

## Accessing Your Project

### Infrastructure Access ($SELECTED_PROVIDER)

Your project's infrastructure components reside on $SELECTED_PROVIDER.

$access_instructions

Please use the credentials provided to you separately for logging into the provider's console/dashboard.

### Website / Application Access

$website_url_info

Deployment outputs (available after running \`tofu output\` or \`./deploy.sh\`) will contain specific URLs and IP addresses.

## Maintenance and Updates

### Infrastructure Management
The infrastructure for this project is managed using OpenTofu. Changes should ideally be made through updates to the configuration files in the Git repository and applied using \`tofu apply\`. Direct changes via the cloud console are discouraged as they may be overwritten.

### Regular Maintenance
- **Security Updates**: Underlying infrastructure (VMs, containers, managed services) are typically updated automatically by the provider or managed via the IaC configuration. Application-level updates are handled separately.
- **Backups**: Backup strategies depend on the services used. Please consult the specific service documentation or inquire for details. (e.g., RDS automatic backups, Volume snapshots).
- **Monitoring**: Basic monitoring is often provided by the cloud platform. Custom monitoring/alerting can be set up upon request.

### Requesting Changes
To request changes, updates, or report issues:
1.  **Preferred Method**: [Your preferred contact method - e.g., Email support@yourcompany.com, Open issue in GitHub repo, Use project management tool]
2.  Provide detailed information about the request or issue.
3.  Standard turnaround time is typically [Your standard timeframe, e.g., 1-3 business days], but may vary based on complexity. Urgent issues will be prioritized.
$billing_section
## Support

For assistance with your project, please contact us:

- **Email**: [Your Support Email Address]
- **Phone**: [Your Support Phone Number (Optional)]
- **Support Hours**: [Your Support Hours, e.g., Monday-Friday, 9 AM - 5 PM Your Timezone]

## Technical Foundation

- **Infrastructure as Code**: OpenTofu (\`main.tf\`, \`variables.tf\`, etc.)
- **Cloud Provider**: $SELECTED_PROVIDER
- **Hosting Model**: $HOSTING_TYPE
- **Source Code Repository**: $(if $REPO_TRANSFER_ENABLED; then echo "https://github.com/$DEST_USER/$DEST_REPO"; else echo "[Link to Client's Repository]"; fi)

---

Thank you for your partnership! We look forward to supporting your project's success.

[Your Company Name]
[Your Website (Optional)]
EOF
  then
      echo -e "${RED}Failed to create client README file.${RESET}" >&2
      success=false
  fi


  if $success; then
    echo -e "${GREEN}✓ Repository transfer scripts and client documentation generated${RESET}"
    return 0
  else
     echo -e "${RED}Errors occurred during repository transfer script/doc generation.${RESET}" >&2
     return 1
  fi
}

# Generate billing documentation - Enhanced
generate_billing_docs() {
   # Only proceed if enabled
   if ! $BILLING_ENABLED; then
      echo -e "${CYAN}Skipping billing documentation generation (not enabled).${RESET}"
      return 0
   fi
   # Check required commands confirmed earlier
   if ! command -v bc &> /dev/null; then
      echo -e "${YELLOW}Warning: 'bc' not found. Calculations in invoice generator script might fail.${RESET}" >&2
   fi
    if ! command -v pandoc &> /dev/null; then
      echo -e "${YELLOW}Warning: 'pandoc' not found. Optional PDF invoice generation will fail.${RESET}" >&2
   fi


  echo -e "${BOLD}Generating billing documentation and scripts...${RESET}"
  local billing_dir="$PROJECT_DIR/billing"
  local success=true

  # Create billing directory
  if ! safe_mkdir "$billing_dir"; then
    echo -e "${RED}Failed to create billing directory: $billing_dir${RESET}" >&2
    return 1 # Fail if directory cannot be created
  fi

  # --- billing-setup.md ---
  echo -e "${BOLD}Generating billing setup guide...${RESET}"

  # Determine billing model description
  local billing_model_desc=""
  local monthly_invoice_estimate=""
  local currency
  currency=$(echo "$BILLING_INFO" | jq -r '.currency // "USD"')

  case $BILLING_TYPE in
    fixed)
      billing_model_desc="**Fixed Fee Model**\n\n- Monthly Fee: **${currency} ${MONTHLY_FEE:-0}**\n- Billing Cycle: Monthly (around the ${BILLING_INFO=$(echo "$BILLING_INFO" | jq -r '.billing_day // "1")}st of each month for previous month)\n- Payment Terms: Net 15 days"
      monthly_invoice_estimate="**Fixed Monthly Invoice Amount: ${currency} ${MONTHLY_FEE:-0}**"
      ;;
    passthrough)
      billing_model_desc="**Pass-through Model**\n\n- Infrastructure costs are billed directly by **$SELECTED_PROVIDER** to the client.\n- Client is responsible for setting up payment with $SELECTED_PROVIDER.\n- Strongly recommend setting up **billing alerts and budgets** in the $SELECTED_PROVIDER console.\n- Our role is limited to infrastructure management, not cost payment."
      monthly_invoice_estimate="**Monthly Invoice Amount: Direct from $SELECTED_PROVIDER** (Monitor your provider bills)"
       ;;
    hybrid)
      billing_model_desc="**Hybrid Model**\n\n- Monthly Fixed Fee: **${currency} ${MONTHLY_FEE:-0}**\n- Markup on Infrastructure Costs: **${COST_PERCENTAGE:-0}%**\n- Billing Cycle: Monthly (around the ${BILLING_INFO=$(echo "$BILLING_INFO" | jq -r '.billing_day // "1")}st of each month for previous month)\n- Payment Terms: Net 15 days\n- Invoice includes fixed fee plus the percentage markup on the actual $SELECTED_PROVIDER costs for the previous month."
       monthly_invoice_estimate="**Estimated Monthly Invoice Amount: ${currency} ${MONTHLY_FEE:-0} + (${COST_PERCENTAGE:-0}% of Infrastructure Cost)**"
      ;;
    *) billing_model_desc="**Unknown Billing Model**" ;;
  esac

  # Determine infrastructure cost estimate placeholders
  # These are VERY rough estimates and should be replaced with provider calculator results
  local infra_cost_estimate=""
   case $SELECTED_PROVIDER in
     aws)
       if [ "$HOSTING_TYPE" == "self" ]; then infra_cost_estimate="- EC2 Instance (${VARS_JSON=$(echo "$VARS_JSON" | jq -r '.instance_type // "t3.micro"')}) : \$XX.XX/month\n- Data Transfer: \$XX.XX/month (variable)\n- EBS Volume: \$XX.XX/month\n- Other (IP, etc.): \$XX.XX/month"
       else infra_cost_estimate="- S3 Storage & Requests: \$XX.XX/month (variable)\n- CloudFront Data Transfer: \$XX.XX/month (variable)\n- Other (Route 53, ACM): \$XX.XX/month"; fi ;;
     azure)
       if [ "$HOSTING_TYPE" == "self" ]; then infra_cost_estimate="- Virtual Machine (\`Standard_B1s\`): \$XX.XX/month\n- Managed Disk: \$XX.XX/month\n- Public IP: \$XX.XX/month\n- Bandwidth: \$XX.XX/month (variable)"
       else infra_cost_estimate="- App Service Plan (\`B1\`) : \$XX.XX/month\n- Web App (Included in Plan usually)\n- Bandwidth: \$XX.XX/month (variable)"; fi ;;
     gcp)
       if [ "$HOSTING_TYPE" == "self" ]; then infra_cost_estimate="- Compute Engine (\`e2-micro\`) : \$XX.XX/month\n- Persistent Disk: \$XX.XX/month\n- Networking (IP, Egress): \$XX.XX/month (variable)"
       else infra_cost_estimate="- Cloud Run Requests/CPU: \$XX.XX/month (variable)\n- Networking (Egress): \$XX.XX/month (variable)"; fi ;;
     digitalocean)
        if [ "$HOSTING_TYPE" == "self" ]; then infra_cost_estimate="- Droplet (\`${VARS_JSON=$(echo "$VARS_JSON" | jq -r '.droplet_size // "s-1vcpu-1gb"')}\`) : \$XX.XX/month\n- Bandwidth: (Included up to limit, then \$XX.XX/month)"
        else infra_cost_estimate="- App Platform (\`basic-xxs\`): \$XX.XX/month\n- Bandwidth: (Included up to limit)"; fi ;;
     vercel | netlify | fly | render | cloudflare) infra_cost_estimate="- Platform Plan: \$XX.XX/month (Free tiers often available)\n- Usage-based costs (Builds, Bandwidth, Functions): \$XX.XX/month (variable)" ;;
     *) infra_cost_estimate="- Base compute/service: \$XX.XX/month\n- Storage: \$XX.XX/month\n- Data Transfer: \$XX.XX/month (variable)" ;;
   esac

   # Define invoice template lines conditionally
   local invoice_line_items="[$PROJECT_NAME Monthly Service Fee]"
   local invoice_total_line="[TOTAL]"
   if [ "$BILLING_TYPE" == "hybrid" ]; then
      invoice_line_items+="\n| Infrastructure Cost Markup (${COST_PERCENTAGE:-0}%)"
      invoice_total_line="| **TOTAL**"
   elif [ "$BILLING_TYPE" == "passthrough" ]; then
      # No service fee line item typically needed unless there's a separate management fee
      invoice_line_items="[Infrastructure Costs (Informational Only)]"
      invoice_total_line="| **TOTAL (Direct Bill from Provider)**"
   else # Fixed
      invoice_total_line="| **TOTAL**"
   fi


   # Use cat with EOF allowing expansion
   if ! cat > "$billing_dir/billing-setup.md" << EOF
# Billing Setup Guide for Project: $PROJECT_NAME

This document outlines the billing model and setup steps for the '$PROJECT_NAME' project hosted on $SELECTED_PROVIDER.

## Billing Model Overview

$billing_model_desc

## Estimated Monthly Infrastructure Costs ($SELECTED_PROVIDER)

**Disclaimer**: These are *rough estimates* based on the initial setup. Actual costs depend heavily on usage, traffic, data storage, and specific configurations. Please use the $SELECTED_PROVIDER pricing calculator for more accurate projections and monitor your actual usage.

$infra_cost_estimate

**Total Estimated Monthly Infrastructure Cost: \$XX.XX - \$YY.YY** (Replace with calculator estimate)

$monthly_invoice_estimate

## Setup Checklist (Internal Use)

- [ ] **Client Agreement**: Confirm billing model and terms are agreed upon with the client.
- [ ] **Provider Account Access**:
    - If **Pass-through**: Ensure client has set up their $SELECTED_PROVIDER account and payment method. Obtain necessary access/permissions for infrastructure management if needed.
    - If **Fixed/Hybrid**: Ensure your $SELECTED_PROVIDER account is used and billing is configured.
- [ ] **Internal Tracking**: Set up internal project tracking for time/costs associated with $PROJECT_NAME.
- [ ] **Invoicing Setup**: Configure your invoicing system (e.g., Stripe, Wave, QuickBooks) for recurring invoices based on the model.
    - If **Hybrid**: Establish a process to obtain actual $SELECTED_PROVIDER costs for the previous month around the end of the month to calculate markup.
- [ ] **Cost Monitoring**: Set up billing alerts in the $SELECTED_PROVIDER account (either yours or the client's) to monitor spending against estimates.
- [ ] **Documentation**: Share relevant sections of this guide and the CLIENT_README.md with the client.

## Sample Invoice Structure (For Fixed/Hybrid)

\`\`\`
--------------------------------------------------
INVOICE TO: [Client Company Name]
[Client Address]

FROM: [Your Company Name]
[Your Address]

Invoice #: INV-YYYYMM-XXX
Date: [Date Generated]
Due Date: [Date Generated + 15 Days]
Period: [Month Year] (e.g., July 2024)
--------------------------------------------------
| Description                             | Amount (${currency}) |
|-----------------------------------------|---------:|
$invoice_line_items | \$ XXX.XX |
$( [ "$BILLING_TYPE" == "hybrid" ] && echo "| Infrastructure Cost Markup (${COST_PERCENTAGE:-0}%)           | \$ XX.XX |")
|-----------------------------------------|---------:|
$invoice_total_line | \$ XXX.XX |
--------------------------------------------------
Payment Terms: Net 15 days
Payment Methods Accepted: [e.g., Bank Transfer, Credit Card via Link]

Notes: Infrastructure costs for hybrid model are based on actual $SELECTED_PROVIDER charges for the billing period.

Thank you for your business!
\`\`\`

## Notes & Recommendations

- Regularly review $SELECTED_PROVIDER costs and compare them against estimates.
- Communicate significant cost variations or potential overruns to the client proactively (especially for Hybrid/Pass-through).
- Ensure clients understand the factors influencing variable costs (traffic, storage, etc.).
- Billing questions should be directed to: [Your Billing Contact Email/Department]
EOF
    then
        echo -e "${RED}Failed to create billing-setup.md.${RESET}" >&2
        success=false
    fi


  # --- generate-invoice.sh ---
  echo -e "${BOLD}Generating invoice generator script...${RESET}"
  # Use single quotes 'EOF' for the script template
  if ! cat > "$billing_dir/generate-invoice.sh" << 'EOF'
#!/bin/bash
# Generates a draft markdown invoice based on project billing settings.

# Strict mode
set -e
set -u
set -o pipefail

# Colors
RESET="\033[0m"
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"

# Config file locations relative to script execution (assuming run from ./billing)
PROJECT_CONF_FILE="../.cloud-deploy.conf"
BILLING_CONF_FILE="../.billing.json"
OUTPUT_DIR="./invoices" # Output directory within billing folder

# Error handling
handle_script_error() {
  local line=$1
  local command=$2
  local code=$3
  echo -e "${RED}Error in generate-invoice.sh: Command '$command' on line $line failed with exit code $code${RESET}" >&2
  exit $code
}
trap 'handle_script_error ${LINENO} "$BASH_COMMAND" $?' ERR

# --- Helper: Check command ---
check_cmd_invoice() {
  if ! command -v "$1" &> /dev/null; then
    echo -e "${YELLOW}Warning: Command '$1' not found.${RESET}" >&2
    if [ -n "$2" ]; then echo -e "Hint: $2" >&2; fi
    return 1 # Return 1 indicates command not found
  fi
  return 0 # Return 0 indicates command found
}


# --- Main Logic ---

echo -e "${BOLD}Invoice Generator for Cloud Deploy Project${RESET}"

# Check dependencies
check_cmd_invoice "jq" "Install jq (e.g., apt install jq, brew install jq)" || exit 1
BC_FOUND=true
check_cmd_invoice "bc" "Install bc for calculations (e.g., apt install bc)" || BC_FOUND=false
PANDOC_FOUND=true
check_cmd_invoice "pandoc" "Install pandoc for optional PDF generation" || PANDOC_FOUND=false

# Load project configuration
if [ ! -f "$PROJECT_CONF_FILE" ]; then
  echo -e "${RED}Error: Project configuration file not found at '$PROJECT_CONF_FILE'.${RESET}" >&2
  exit 1
fi
# Source carefully, handle potential errors if file is malformed
# Using grep/sed is safer than source if format is simple key=value
PROJECT_NAME=$(grep '^PROJECT_NAME=' "$PROJECT_CONF_FILE" | cut -d'=' -f2 | tr -d '"')
if [ -z "$PROJECT_NAME" ]; then
   echo -e "${RED}Error: Could not read PROJECT_NAME from '$PROJECT_CONF_FILE'.${RESET}" >&2
   exit 1
fi
echo "Project: $PROJECT_NAME"

# Load billing configuration
if [ ! -f "$BILLING_CONF_FILE" ]; then
  echo -e "${RED}Error: Billing configuration file not found at '$BILLING_CONF_FILE'.${RESET}" >&2
  echo "Ensure billing was enabled during project setup." >&2
  exit 1
fi

echo "Loading billing info from $BILLING_CONF_FILE..."
BILLING_TYPE=$(jq -r '.model // ""' "$BILLING_CONF_FILE")
MONTHLY_FEE=$(jq -r '.monthly_fee // "0"' "$BILLING_CONF_FILE")
COST_PERCENTAGE=$(jq -r '.cost_percentage // "0"' "$BILLING_CONF_FILE")
CURRENCY=$(jq -r '.currency // "USD"' "$BILLING_CONF_FILE")

# Validate loaded billing info
if [ -z "$BILLING_TYPE" ]; then
    echo -e "${RED}Error: Billing model ('model') not found in '$BILLING_CONF_FILE'.${RESET}" >&2
    exit 1
fi
echo "Billing Model: $BILLING_TYPE"
echo "Monthly Fee: $MONTHLY_FEE $CURRENCY"
if [ "$BILLING_TYPE" == "hybrid" ]; then
    echo "Cost Markup: $COST_PERCENTAGE %"
fi

# Get invoice period (previous month by default)
DEFAULT_YEAR=$(date -d "last month" +"%Y")
DEFAULT_MONTH=$(date -d "last month" +"%m")
DEFAULT_MONTH_NAME=$(date -d "last month" +"%B")

read -p "Enter Invoice Year [$DEFAULT_YEAR]: " YEAR
YEAR=${YEAR:-$DEFAULT_YEAR}
read -p "Enter Invoice Month (numeric, e.g., 07 for July) [$DEFAULT_MONTH]: " MONTH
MONTH=${MONTH:-$DEFAULT_MONTH}
# Validate month format
if ! [[ "$MONTH" =~ ^(0[1-9]|1[0-2])$ ]]; then
   echo -e "${RED}Invalid month format. Please use MM (e.g., 07).${RESET}" >&2
   exit 1
fi
MONTH_NAME=$(date -d "${YEAR}-${MONTH}-01" +"%B") # Get month name from YYYY-MM-01
echo "Generating invoice for period: ${MONTH_NAME} ${YEAR}"


# Get dates for invoice
INVOICE_DATE=$(date +"%Y-%m-%d")
DUE_DATE=$(date -d "+15 days" +"%Y-%m-%d") # Adjust '15 days' as needed

# Initialize calculated values
INFRA_COST="0"
INFRA_FEE="0"
TOTAL="0"

# Ask for infrastructure costs if needed (Hybrid or Passthrough)
if [ "$BILLING_TYPE" == "hybrid" ] || [ "$BILLING_TYPE" == "passthrough" ]; then
  read -p "Enter the total infrastructure costs from provider for ${MONTH_NAME} ${YEAR} (numeric, e.g., 123.45): " INFRA_COST_INPUT
   if [[ "$INFRA_COST_INPUT" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
     INFRA_COST="$INFRA_COST_INPUT"
   else
     echo -e "${YELLOW}Invalid infrastructure cost format. Using 0.${RESET}"
     INFRA_COST="0"
   fi
fi

# Calculate totals based on billing model
if [ "$BILLING_TYPE" == "fixed" ]; then
  TOTAL="$MONTHLY_FEE"

elif [ "$BILLING_TYPE" == "hybrid" ]; then
  if $BC_FOUND; then
    # Calculate percentage using bc for floating point math
    INFRA_FEE=$(echo "scale=2; $INFRA_COST * $COST_PERCENTAGE / 100" | bc)
    TOTAL=$(echo "scale=2; $MONTHLY_FEE + $INFRA_FEE" | bc)
    # Ensure TOTAL is not negative, though unlikely here
    if (( $(echo "$TOTAL < 0" | bc -l) )); then TOTAL="0.00"; fi
  else
    echo -e "${YELLOW}Warning: 'bc' not found. Cannot calculate hybrid total accurately. Set manually.${RESET}" >&2
    INFRA_FEE="CALC_ERROR"
    TOTAL="MANUAL_ENTRY"
  fi

elif [ "$BILLING_TYPE" == "passthrough" ]; then
  # Total is handled by provider, maybe invoice is just for management fee if any?
  # For this script, let's assume no separate fee, total is informational.
  TOTAL="0.00" # Or set to a management fee if applicable
  MONTHLY_FEE="0.00" # Assuming no fixed fee in pure passthrough
else
   echo -e "${RED}Error: Unknown billing type '$BILLING_TYPE'. Cannot calculate total.${RESET}" >&2
   exit 1
fi

# Format numbers to 2 decimal places (using printf)
MONTHLY_FEE=$(printf "%.2f" "$MONTHLY_FEE")
INFRA_COST=$(printf "%.2f" "$INFRA_COST")
INFRA_FEE=$(printf "%.2f" "$INFRA_FEE")
TOTAL=$(printf "%.2f" "$TOTAL")


# Create invoice number (example format)
INVOICE_NUM="INV-${YEAR}${MONTH}-$(echo "$PROJECT_NAME" | tr '[:lower:]' '[:upper:]' | cut -c1-5)"

# Create output directory if it doesn't exist
if ! mkdir -p "$OUTPUT_DIR"; then
    echo -e "${RED}Error: Failed to create output directory '$OUTPUT_DIR'.${RESET}" >&2
    exit 1
fi

# Define invoice filenames
INVOICE_MD_FILE="${OUTPUT_DIR}/invoice-${YEAR}-${MONTH}-${PROJECT_NAME}.md"
INVOICE_PDF_FILE="${OUTPUT_DIR}/invoice-${YEAR}-${MONTH}-${PROJECT_NAME}.pdf"


# --- Generate Markdown Invoice ---
echo -e "${BOLD}Generating Markdown invoice: $INVOICE_MD_FILE...${RESET}"
# Use cat with EOF, allowing variable expansion
# Replace placeholders with your actual company/client info
if ! cat > "$INVOICE_MD_FILE" << EOF
# INVOICE

**From:**
[Your Company Name]
[Your Address Line 1]
[Your City, State, Zip]
[Your Email]
[Your Phone (Optional)]
[Your VAT/Tax ID (If applicable)]

---

**Bill To:**
[Client Company Name]
[Client Address Line 1]
[Client City, State, Zip]
[Client Contact Email]

---

**Invoice Number:** ${INVOICE_NUM}
**Invoice Date:** ${INVOICE_DATE}
**Due Date:** ${DUE_DATE}
**Period:** ${MONTH_NAME} ${YEAR}

---

| Description                             | Amount (${CURRENCY}) |
|:----------------------------------------|-------------:|
$( [ "$BILLING_TYPE" != "passthrough" ] && printf "| %-39s | %12.2f |\n" "$PROJECT_NAME Monthly Service Fee" "$MONTHLY_FEE" )
$( [ "$BILLING_TYPE" == "hybrid" ] && printf "| %-39s | %12.2f |\n" "Infrastructure Cost Markup (${COST_PERCENTAGE}%)" "$INFRA_FEE" )
$( [ "$BILLING_TYPE" == "passthrough" ] && printf "| %-39s | %12.2f |\n" "Infrastructure Costs (Direct Bill)" "$INFRA_COST" )
|:----------------------------------------|-------------:|
| **TOTAL DUE**                           | **${TOTAL}** |

---

**Payment Terms:** Net 15 days

**Payment Methods:**
- [e.g., Bank Transfer: Account # XXX, Sort Code YYY]
- [e.g., Stripe/PayPal Link: https://...]

**Notes:**
$( [ "$BILLING_TYPE" == "hybrid" ] && echo "- Infrastructure costs for markup calculation based on actual $SELECTED_PROVIDER charges for the period." )

Thank you for your business!
EOF
then
   echo -e "${RED}Error: Failed to write Markdown invoice file.${RESET}" >&2
   exit 1
fi

echo -e "${GREEN}✓ Markdown invoice generated: ${INVOICE_MD_FILE}${RESET}"

# --- Optional: Convert to PDF ---
if $PANDOC_FOUND; then
    read -p "Convert the invoice to PDF using pandoc? [y/N]: " convert_pdf
    if [[ "$convert_pdf" =~ ^[Yy]$ ]]; then
        echo -e "${BOLD}Converting to PDF: $INVOICE_PDF_FILE...${RESET}"
        # Basic pandoc conversion, might need latex installed (texlive-latex-base, etc.)
        # Add --pdf-engine=xelatex for better unicode support if needed
        if pandoc "$INVOICE_MD_FILE" -o "$INVOICE_PDF_FILE"; then
            echo -e "${GREEN}✓ PDF invoice generated: ${INVOICE_PDF_FILE}${RESET}"
        else
            echo -e "${RED}Error: Pandoc conversion failed.${RESET}" >&2
            echo "Ensure LaTeX (e.g., texlive-latex-base, texlive-fonts-recommended) is installed for PDF generation." >&2
            # Don't exit, markdown file is still useful
        fi
    fi
else
    echo -e "${YELLOW}Skipping PDF conversion ('pandoc' not found).${RESET}"
fi

echo
echo -e "${GREEN}Invoice generation process finished.${RESET}"

exit 0

EOF
  then
    echo -e "${RED}Failed to create invoice generator script.${RESET}" >&2
    success=false
  fi

  # Make invoice generator script executable
  if $success && ! chmod +x "$billing_dir/generate-invoice.sh"; then
    echo -e "${RED}Failed to make invoice generator script executable.${RESET}" >&2
    success=false
  fi

  if $success; then
    echo -e "${GREEN}✓ Billing documentation and scripts generated${RESET}"
    return 0
  else
     echo -e "${RED}Errors occurred during billing documentation generation.${RESET}" >&2
     return 1
  fi
}


# --- Main Execution ---
main() {
  print_banner
  check_dependencies # Exits if critical deps missing

  # Load provider definitions
  load_providers || { echo -e "${RED}Failed to load providers. Exiting.${RESET}" >&2; exit 1; }

  # Select provider
  select_provider # Exits internally if selection fails

  # Configure project settings and generate files
  configure_project || { echo -e "${RED}Project configuration failed. Exiting.${RESET}" >&2; exit 1; }


  # --- Final Instructions ---
  echo
  echo -e "${BOLD}${GREEN}🚀 Project setup complete! 🚀${RESET}"
  echo -e "Project directory: ${BOLD}${PROJECT_DIR}${RESET}"
  echo
  echo -e "${BOLD}Next steps:${RESET}"
  echo -e "1. ${YELLOW}Review generated files:${RESET} Check \`${PROJECT_DIR}/terraform.tfvars.json\`, \`${PROJECT_DIR}/main.tf\`, and other generated files for correctness."
  echo -e "2. ${YELLOW}Configure Credentials:${RESET} Ensure your cloud provider credentials for '$SELECTED_PROVIDER' are set up (environment variables, config files)."
  echo -e "3. ${YELLOW}Initialize & Deploy:${RESET} Navigate to the project directory and run the deployment script:"
  echo -e "   \`cd \"$PROJECT_DIR\" && ./deploy.sh\`"

  if $CADDY_ENABLED && [ "$HOSTING_TYPE" == "self" ]; then
    echo -e "4. ${YELLOW}Configure Caddy:${RESET} After deployment, get the server IP from \`tofu output\` and run:"
    echo -e "   \`cd \"$PROJECT_DIR/caddy\" && ./deploy-caddy.sh <server_ip>\`"
    echo -e "   ${YELLOW}(Ensure your DNS A record for '$DOMAIN_NAME' points to the server IP)${RESET}"
  fi

  if $REPO_TRANSFER_ENABLED; then
     # Adjust step number based on Caddy presence
     local step_num=$([ "$CADDY_ENABLED" == "true" ] && [ "$HOSTING_TYPE" == "self" ] && echo "5" || echo "4")
     echo -e "${step_num}. ${YELLOW}Repository Transfer:${RESET} When ready for client handover, run:"
     echo -e "   \`cd \"$PROJECT_DIR/scripts\" && ./repo-transfer.sh\`"
  fi

  if $BILLING_ENABLED; then
     # Adjust step number
      local step_num_billing=$([ "$REPO_TRANSFER_ENABLED" == "true" ] && echo "$((step_num+1))" || echo "$step_num")
      echo -e "${step_num_billing}. ${YELLOW}Billing Setup:${RESET} Refer to the internal guide:"
      echo -e "   \`${PROJECT_DIR}/billing/billing-setup.md\`"
      echo -e "   Use the invoice generator script monthly (after getting provider costs if hybrid/passthrough):"
      echo -e "   \`cd \"$PROJECT_DIR/billing\" && ./generate-invoice.sh\`"
  fi

  echo
  echo -e "${BOLD}Happy deploying!${RESET}"
}

# Run the main function, passing all script arguments (if any needed later)
main "$@"
```