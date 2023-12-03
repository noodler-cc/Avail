#!/bin/bash

step=1
total_steps=5
validator=false
node_name="noodler-template-avail-Node"
da_chain=goldberg
image_tag="v1.8.0.2"

display_variables() {
    echo "Network: $da_chain"
    echo "Image Version: $image_tag"
    echo "Validator: $validator"
    echo "Node Name: $node_name"
    echo "-----------------------------------"
}

header() {
    clear

    cat << "EOF"
    ___              _ __   ______      ____   _   __          __   
   /   |_   ______ _(_) /  / ____/_  __/ / /  / | / /___  ____/ /__ 
  / /| | | / / __ `/ / /  / /_  / / / / / /  /  |/ / __ \/ __  / _ \
 / ___ | |/ / /_/ / / /  / __/ / /_/ / / /  / /|  / /_/ / /_/ /  __/
/_/  |_|___/\__,_/_/_/  /_/    \__,_/_/_/  /_/ |_/\____/\__,_/\___/ 
                        🍜 by Noodler 🍜
---------------------------------------------------------------------
EOF
    display_variables
}

spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\\'
    while ps a | awk '{print $1}' | grep -q $pid; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

execute_command() {
    local title=$1
    local cmd=$2
    local status
    SECONDS=0
    printf "\r🚀  Step [$step/$total_steps]: $title - In progress"

    eval "$cmd" &> /dev/null &
    spinner
    wait $! && status=0 || status=$?

    if [[ $status -ne 0 ]]; then
        printf "\r❌  Step [$step/$total_steps]: $title - Failed       \n"
        return $status
    else
        printf "\r✅  Step [$step/$total_steps]: $title - Ok ($SECONDS sec) \n"
    fi
    ((step++))
}

execute_step() {
    local description=$1
    local command=$2
    execute_command "$description" "$command"
}

while getopts "Vn:t:c:" opt; do
    case $opt in
        V)
            validator=true
            total_steps=7
            ;;
        n)
            node_name=$OPTARG
            ;;
        t)
            image_tag=$OPTARG
            ;;
        c)
            da_chain=$OPTARG
            ;;
        \?)
            echo "Error: Invalid option -$OPTARG" >&2
            exit 1
            ;;
    esac
done

header

if ! command -v docker &> /dev/null; then
    execute_step "Installing Docker" '
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
        "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    '
else
    execute_step "Docker is already installed." ""
fi

execute_step "System Update" "sudo apt update && sudo apt upgrade -y"

execute_step "Installing Dependencies" "sudo apt-get -y install ca-certificates curl gnupg"

execute_step "Downloading the Image" "sudo docker pull availj/avail:$image_tag"

execute_step "Starting the Node" "sudo docker run -v $(pwd)$HOME/avail/state:/da/state:rw -v $(pwd)$HOME/avail/keystore:/da/keystore:rw -e DA_CHAIN=$da_chain --name avail -e DA_NAME=$node_name --network host -d --restart unless-stopped availj/avail:$image_tag"
if [ "$validator" = true ]; then
    execute_step "Validator Configuration" "sudo docker exec -i avail sed -i '/--execution native-else-wasm/a \        --validator \\\\' /entrypoint.sh"
    execute_step "Restarting the Node" "sudo docker restart avail; sleep 2"
fi