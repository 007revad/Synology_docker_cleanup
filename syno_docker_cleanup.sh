#!/usr/bin/env bash
# shellcheck disable=SC2076
#--------------------------------------------------------------------
# Remove orphan docker btrfs subvolumes in Synology DSM 7 and DSM 6
#
# Github: https://github.com/007revad/Synology_docker_cleanup
# Script verified at https://www.shellcheck.net/
#
# To run in a shell (replace /volume1/scripts/ with path to script):
# sudo -s /volume1/scripts/syno_docker_cleanup.sh
#--------------------------------------------------------------------

scriptver="v1.2.4"
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

# Check Container Manager or Docker is installed
if [[ -d /var/packages/ContainerManager ]]; then
    docker_pkg="ContainerManager"
    docker_pkg_name="Container Manager"
elif [[ -d /var/packages/Docker ]]; then
    docker_pkg="Docker"
    docker_pkg_name="Docker"
else
    echo -e "${Error}ERROR${Off} Container Manager or Docker is not installed!"
    exit 1
fi

# Check Container Manager or Docker is running
if ! /usr/syno/bin/synopkg status "$docker_pkg" >/dev/null; then
    echo -e "${Error}ERROR${Off} $docker_pkg_name is not running!"
    exit 1
fi

# Get volume @docker is on
if [[ $docker_pkg == "ContainerManager" ]]; then
    source=$(readlink /var/packages/ContainerManager/var/docker)
else
    source=$(readlink /var/packages/Docker/target/docker)
fi
if [[ -d $source ]]; then
    volume=$(echo "$source" | cut -d"/" -f2)
else
    echo -e "${Error}ERROR${Off} @docker folder not found!"
    echo "$source"
    exit 1
fi

#volume="volume2"  # debug


# Get list of @docker/btrfs/subvolumes
#echo -e "\n${Cyan}@docker/btrfs/subvolumes list:${Off}"  # debug
count="0"
for subvol in /"$volume"/@docker/btrfs/subvolumes/*; do    
    #echo "$subvol"  # debug
    allsubvolumes+=("$subvol")
    count=$((count+1))
done
s=""
if [[ $count -gt "0" ]]; then s="s"; fi
echo -e "$count ${Yellow}total${Off} docker btrfs subvolume$s found."


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
s=""
if [[ $count -gt "0" ]]; then s="s"; fi
echo -e "$count ${Yellow}active${Off} docker btrfs subvolume$s found."


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
s=""
if [[ $count -gt "0" ]]; then s="s"; fi
echo -e "$count ${Yellow}orphan${Off} docker btrfs subvolume$s found."


# Stop Container Manager or Docker
#echo -e "\nStopping $docker_pkg_name..."
#/usr/syno/bin/synopkg stop $docker_pkg >/dev/null


# Delete orphan subvolumes
if [[ ${#orphansubvolumes[@]} -gt "0" ]]; then
    s=""
    if [[ $count -gt "0" ]]; then s="s"; fi
    echo -e "\n${Cyan}Deleting $count orphan subvolume$s...${Off}"
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


# Start Container Manager or Docker
#echo -e "\nStarting $docker_pkg_name..."
#/usr/syno/bin/synopkg start $docker_pkg >/dev/null


# Delete dangling images
readarray -t temp < <(docker images --filter "dangling=true")
count=$((${#temp[@]}-1))
if [[ $count -gt "0" ]]; then
    s=""
    if [[ $count -gt "1" ]]; then s="s"; fi
    echo -e "\n${Cyan}Deleting $count orphan image$s...${Off}"
    docker rmi "$(docker images -f "dangling=true" -q)"
else
    echo -e "\n${Yellow}No dangling images to delete.${Off}"
fi


# Shows results
echo ""
if [[ $deleted -gt "0" ]]; then
    echo -e "\n${Yellow}Deleted $deleted orphan subvolumes.${Off}"

    # Delete .syno.bak containers
    if [[ ! $(docker ps -a --format "{{.Names}}" | grep -qE .*\.syno\.bak$) ]]; then
        echo -e "\nYou can now delete any containers with names ending in .syno.bak:"
        if [[ $docker_pkg == "ContainerManager" ]]; then
            echo "  1. Open Container Manager."
        else
            echo "  1. Open $docker_pkg."
        fi
        echo "  2. Click on Container."
        echo "  3. Select a container that ends in .syno.bak"
        echo "  4. Click on Action and select Delete."
        echo "  5. Click on the Delete button."
        echo "  6. Repeat steps 3 to 5 for other .syno.bak containers"
    fi
fi
if [[ $failed -gt "0" ]]; then
    echo -e "\n${Error}ERROR${Off} Failed to delete ${Cyan}$failed${Off} orphan subvolumes!"
fi

