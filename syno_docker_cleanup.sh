#!/usr/bin/env bash
# shellcheck disable=SC2076
#----------------------------------------------------------
# Remove orphan docker btrfs subvolumes in Synology DSM 7
#
# Github: https://github.com/007revad/Synology_docker_cleanup
# Script verified at https://www.shellcheck.net/
#
# To run in a shell (replace /volume1/scripts/ with path to script):
# sudo -s /volume1/scripts/syno_docker_cleanup.sh
#----------------------------------------------------------

scriptver="v1.0.1"
script=Synology_docker_cleanup
repo="007revad/Synology_docker_cleanup"
scriptname=syno_docker_cleanup

# Shell Colors
#Black='\e[0;30m'   # ${Black}
Red='\e[0;31m'      # ${Red}
#Green='\e[0;32m'   # ${Green}
Yellow='\e[0;33m'   # ${Yellow}
#Blue='\e[0;34m'    # ${Blue}
#Purple='\e[0;35m'  # ${Purple}
Cyan='\e[0;36m'     # ${Cyan}
#White='\e[0;37m'   # ${White}
Error='\e[41m'      # ${Error}
#Warn='\e[47;31m'   # ${Warn}
Off='\e[0m'         # ${Off}

# Show script version
echo -e "$script $scriptver\n"

# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    echo -e "${Error}ERROR${Off} This script must be run as sudo or root!"
    exit 1
fi

# Check script is running on a Synology NAS
if ! /usr/bin/uname -a | grep -i synology >/dev/null; then
    echo -e "${Error}ERROR${Off} This script is NOT running on a Synology NAS!"
    echo "Copy the script to a folder on the Synology and run it from there."
    exit 1
fi

# Check Container Manager is running
if ! /usr/syno/bin/synopkg status ContainerManager >/dev/null; then
    echo -e "${Error}ERROR${Off} Container Manager is not running!"
    exit 1
fi


# Get volume @docker is on
source=$(readlink /var/packages/ContainerManager/var/docker)
volume=$(echo "$source" | cut -d"/" -f2)

#volume="volume2"  # debug


# Get list of @docker/btrfs/subvolumes
#echo -e "\n${Cyan}@docker/btrfs/subvolumes list:${Off}"  # debug
count="0"
for subvol in /"$volume"/@docker/btrfs/subvolumes/*; do    
    #echo "$subvol"  # debug
    allsubvolumes+=("$subvol")
    count=$((count+1))
done
echo -e "$count ${Yellow}total${Off} docker btrfs subvolumes found."


# Get list of current @docker/btrfs/subvolumes
#echo -e "\n${Cyan}btrfs subvolume list:${Off}"  # debug
readarray -t temp < <(btrfs subvolume list -p /"$volume"/@docker/btrfs/subvolumes)
count="0"
for v in "${temp[@]}"; do
    #echo "1 $v"  # debug
    sub=$(echo "$v" | grep '@docker/btrfs/subvolumes' | awk '{print $NF}')

    if [[ $sub =~ ^@docker/btrfs/subvolumes/* ]]; then
        #echo "/$volume/$sub"  # debug
        currentsubvolumes+=("/$volume/$sub")
        count=$((count+1))
    fi
done
echo -e "$count ${Yellow}active${Off} docker btrfs subvolumes found."


# Create list of orphan subvolumes
#echo -e "\n${Cyan}Orphan subvolume list:${Off}"  # debug
count="0"
for v in "${allsubvolumes[@]}"; do
    if [[ ! "${currentsubvolumes[*]}" =~ "$v" ]]; then
        #echo "$v"  # debug
        orphansubvolumes+=("$v")
        count=$((count+1))
    fi
done
echo -e "$count ${Yellow}orphan${Off} docker btrfs subvolumes found."


# Stop Container Manager
#echo -e "\nStopping Container Manager..."
#/usr/syno/bin/synopkg stop ContainerManager >/dev/null


# Delete orphan subvolumes
if [[ ${#orphansubvolumes[@]} -gt "0" ]]; then
    echo -e "\n${Cyan}Deleting $count orphan subvolumes...${Off}"
    for o in "${orphansubvolumes[@]}"; do
        #echo "$o"  # debug
        if [[ -d "$o" ]]; then
            if rm -rf "$o"; then
                deleted=$((deleted+1))
            else
                echo -e "${Red}Failed to delete${Off} $o"
                failed=$((failed+1))
            fi
        else
            echo -e "${Red}Failed to delete${Off} $o"
            failed=$((failed+1))
        fi
    done
else
    echo -e "\n${Yellow}No orphan subvolumes to delete.${Off}"
fi


# Start Container Manager
#echo -e "\nStarting Container Manager..."
#/usr/syno/bin/synopkg start ContainerManager >/dev/null


# Shows results
echo ""
if [[ $deleted -gt "0" ]]; then
    echo -e "\n${Yellow}Deleted $deleted orphan subvolumes.${Off}"
    echo -e "\nYou can now delete the .syno.bak containers:"
    echo "  1. Open Container Manager."
    echo "  2. Click on Container."
    echo "  3. Click on the little dot to the left of a container that ends in .syno.bak"
    echo "  4. Click on Action and select Delete."
    echo "  5. Click on the Delete button."
    echo "  6. Repeat steps 3 to 5 for other .syno.bak containers"
fi
if [[ $failed -gt "0" ]]; then
    echo -e "\n${Error}ERROR${Off} Failed to delete ${Cyan}$failed${Off} orphan subvolumes!"
fi

