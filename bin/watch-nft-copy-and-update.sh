#!/usr/bin/env bash
# Watch for copying to /run/media/mplanetarian/DATA/NFT_VIDEOS and update playlist when complete
TARGET_DIR="/run/media/mplanetarian/DATA/NFT_VIDEOS"

while true; do
    sleep 5
    part_count=$(find "$TARGET_DIR" -name "*.part" 2>/dev/null | wc -l)
    if [ "$part_count" -eq 0 ]; then
        open_writers=$(lsof +D "$TARGET_DIR" 2>/dev/null | grep -E "REG.*w" | wc -l)
        if [ "$open_writers" -eq 0 ]; then
            # Double check after a short buffer
            sleep 6
            part_count=$(find "$TARGET_DIR" -name "*.part" 2>/dev/null | wc -l)
            open_writers=$(lsof +D "$TARGET_DIR" 2>/dev/null | grep -E "REG.*w" | wc -l)
            if [ "$part_count" -eq 0 ] && [ "$open_writers" -eq 0 ]; then
                "$HOME/.local/bin/update-nft-playlist"
                notify-send -u normal -a "Mix Archive Manager" "NFT Videos Transfer Complete" "Finished copying NFT_VIDEOS to DATA. Desktop playlist is fully updated." 2>/dev/null
                break
            fi
        fi
    fi
done
