#!/usr/bin/env bash
# ==============================================================================
# wan2gp.sh - WAN2GP Launcher and Management Script
# Usage:
#   ./wan2gp.sh [2|4.5]        Launch WAN2GP in Profile 2 (fast) or 4.5 (low VRAM)
#   ./wan2gp.sh stop           Stop running WAN2GP instance
#   ./wan2gp.sh status         Check running status
#   ./wan2gp.sh restart [prof] Restart in chosen profile
# ==============================================================================

ACTION="${1:-2}"

stop_wan2gp() {
    local pids
    pids=$(pgrep -f "python.*wgp\.py")
    if [ -n "$pids" ]; then
        echo -e "\033[0;33mStopping WAN2GP (PID: $pids)...\033[0m"
        kill -TERM $pids 2>/dev/null || true
        sleep 2
        if pgrep -f "python.*wgp\.py" >/dev/null 2>&1; then
            pkill -9 -f "python.*wgp\.py" 2>/dev/null || true
        fi
        echo -e "\033[0;32m✓ WAN2GP stopped.\033[0m"
    else
        echo -e "\033[0;33mWAN2GP is not currently running.\033[0m"
    fi
}

status_wan2gp() {
    local pids
    pids=$(pgrep -f "python.*wgp\.py")
    if [ -n "$pids" ]; then
        echo -e "\033[0;32m[RUNNING] WAN2GP is active with PID: $pids\033[0m"
        ps -o pid,user,%cpu,%mem,etime,args -p $pids
    else
        echo -e "\033[0;31m[STOPPED] WAN2GP is not running.\033[0m"
    fi
}

if [ "$ACTION" = "stop" ]; then
    stop_wan2gp
    exit 0
elif [ "$ACTION" = "status" ]; then
    status_wan2gp
    exit 0
elif [ "$ACTION" = "restart" ]; then
    stop_wan2gp
    shift
    ACTION="${1:-2}"
    echo "Restarting with profile $ACTION..."
    sleep 1
fi

PROFILE="$ACTION"
if [ "$PROFILE" != "2" ] && [ "$PROFILE" != "4.5" ] && [ "$PROFILE" != "1" ] && [ "$PROFILE" != "3" ] && [ "$PROFILE" != "4" ]; then
    PROFILE="2"
fi

# Disable systemd-oomd if active to prevent premature OOM kills
if systemctl is-active --quiet systemd-oomd 2>/dev/null; then
    sudo systemctl stop systemd-oomd 2>/dev/null || true
    sudo systemctl mask systemd-oomd 2>/dev/null || true
fi

APP_DIR="/var/home/mplanetarian/pinokio/api/wan.git/app"
cd "$APP_DIR" || exit 1

# Ensure virtual environment is active
source "$APP_DIR/venv/bin/activate"

# Locate site-packages directory
SITE_PKGS=$(python -c "import site; print(site.getsitepackages()[0])")

# Export NVIDIA library paths
export LD_LIBRARY_PATH=$SITE_PKGS/nvidia/cudnn/lib:$SITE_PKGS/nvidia/cublas/lib:$SITE_PKGS/nvidia/cuda_runtime/lib:$LD_LIBRARY_PATH

echo -e "\033[1;36m==================================================\033[0m"
echo -e "\033[1;36m       STARTING WAN2GP (Profile: $PROFILE)        \033[0m"
echo -e "\033[1;36m==================================================\033[0m"
if [ "$PROFILE" = "2" ]; then
    echo -e "\033[0;32mMode: Profile 2 (HighRAM_LowVRAM) - High Speed VRAM-resident for 2B models\033[0m"
elif [ "$PROFILE" = "4.5" ]; then
    echo -e "\033[0;33mMode: Profile 4.5 (LowRAM_LowVRAM) - Aggressive PCIe offload for 14B models\033[0m"
fi
echo ""

# Run WAN2GP with selected profile (listening on 0.0.0.0 for LAN + localhost access)
PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True CUDA_VISIBLE_DEVICES=0 python wgp.py --multiple-images --advanced --listen --profile "$PROFILE" --attention sage --output-dir "/home/mplanetarian/Documents/WAN2GP_OUTPUTS"
