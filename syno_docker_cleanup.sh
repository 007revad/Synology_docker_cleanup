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

scriptver="v1.0.0"
script=Synology_docker_cleanup
repo="007revad/Synology_docker_cleanup"
scriptname=syno_docker_cleanup

# Show script version
echo -e "$script $scriptver\n"

# Check script is running as root
if [[ $( whoami ) != "root" ]]; then
    echo -e "ERROR This script must be run as sudo or root!"
    exit 1
fi

# Check script is running on a Synology NAS
if ! /usr/bin/uname -a | grep -i synology >/dev/null; then
    echo "This script is NOT running on a Synology NAS!"
    echo "Copy the script to a folder on the Synology and run it from there."
    exit 1
fi

# Check Container Manager is running
if ! /usr/syno/bin/synopkg status ContainerManager >/dev/null; then
    echo -e "ERROR Container Manager is not running!"
    exit 1
fi


# Get volume @docker is on
source=$(readlink /var/packages/ContainerManager/var/docker)
volume=$(echo "$source" | cut -d"/" -f2)

#volume="volume2"  # debug


# Get list of @docker/btrfs/subvolumes
echo "@docker/btrfs/subvolumes list:"  # debug
count="0"
for subvol in /"$volume"/@docker/btrfs/subvolumes/*; do    
    #echo "$subvol"  # debug
    allsubvolumes+=("$subvol")
    count=$((count+1))
done
echo "$count @docker/btrfs/subvolumes found."  # debug


# Get list of current @docker/btrfs/subvolumes
echo -e "\nbtrfs subvolume list:"  # debug
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
echo "$count btrfs subvolumes found."  # debug


# Create list of orphan subvolumes
echo -e "\nOrphan subvolume list:"  # debug
count="0"
for v in "${allsubvolumes[@]}"; do
    if [[ ! "${currentsubvolumes[*]}" =~ "$v" ]]; then
        #echo "$v"  # debug
        orphansubvolumes+=("$v")
        count=$((count+1))
    fi
done
echo "$count orphan subvolumes found."  # debug


# Stop Container Manager
#echo -e "\nStopping Container Manager"
#/usr/syno/bin/synopkg stop ContainerManager >/dev/null


# Delete orphan subvolumes
if [[ ${#orphansubvolumes[@]} -gt "0" ]]; then
    echo -e "\nDeleting orphan subvolumes..."
    for o in "${orphansubvolumes[@]}"; do
        #echo "$o"  # debug
        if [[ -d "$o" ]]; then
            if rm -rf "$o"; then
                deleted=$((deleted+1))
            else
                echo "Failed to delete $o"
                failed=$((failed+1))
            fi
        else
            echo "Failed to delete $o"
            failed=$((failed+1))
        fi
    done
else
    echo -e "\nNo orphan subvolumes to delete."
fi


# Start Container Manager
#echo "Starting Container Manager"
#/usr/syno/bin/synopkg start ContainerManager >/dev/null


# Shows results
echo ""
if [[ $deleted -gt "0" ]]; then
    echo "Deleted $deleted orphan subvolumes."
    echo -e "\nYou can now delete the .syno.bak containers:"
    echo "  1. Open Container Manager."
    echo "  2. Click on Container."
    echo "  3. Click on the little dot to the left of a container that ends in .syno.bak"
    echo "  4. Click on Action and select Delete."
    echo "  5. Click on the Delete button."
    echo "  6. Repeat steps 3 to 5 for other .syno.bak containers"
fi
if [[ $failed -gt "0" ]]; then
    echo "Failed to delete $failed orphan subvolumes!"
fi

