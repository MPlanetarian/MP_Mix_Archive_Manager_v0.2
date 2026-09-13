#!/usr/bin/env bash

# Setup colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

clear
echo -e "${BOLD}${BLUE}==================================================${NC}"
echo -e "${BOLD}${BLUE}         GENERATE MASTER TRACKLIST HTML INDEX     ${NC}"
echo -e "${BOLD}${BLUE}==================================================${NC}"
echo -e "${YELLOW}Parsing tracklist files and building HTML...${NC}\n"

python3 generate_master_tracklist.py
STATUS=$?

echo -e "${BLUE}--------------------------------------------------${NC}"
if [ $STATUS -eq 0 ]; then
    echo -e "${BOLD}${GREEN}Master Tracklist HTML generated successfully!${NC}"
    echo -e "You can open ${CYAN}master_tracklists.html${NC} in any browser."
else
    echo -e "${BOLD}${RED}Failed to generate Master Tracklist HTML.${NC}"
fi
echo -e "${BLUE}==================================================${NC}"
