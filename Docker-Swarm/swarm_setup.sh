#!/bin/bash

# ./swarm_setup.sh 3 5 - This would set up a Docker Swarm with 3 manager nodes and 5 worker nodes.
# ./swarm_setup.sh - for a single node





# Set the IP address of the admin node
admin=XXX.XXX.XXX.XXX

# User of remote machines
user=ubuntu

# Interface used on remotes
interface=eth0

# SSH certificate name variable
certName=id_rsa

# Default number of nodes
default_managers=1
default_workers=1

# Get the number of manager and worker nodes from command line arguments
num_managers=${1:-$default_managers}
num_workers=${2:-$default_workers}

# Function to generate IP addresses
generate_ips() {
    local prefix="XXX.XXX.XXX."
    local start_ip=1
    local type=$1
    local count=$2
    
    for i in $(seq 1 $count); do
        ip="${prefix}$((start_ip++))"
        eval "${type}[$((i-1))]=$ip"
    done
}

# Generate IP addresses for managers and workers
generate_ips managers $num_managers
generate_ips workers $num_workers

# Combine all nodes
all=(${managers[@]} ${workers[@]})

#############################################
#            DO NOT EDIT BELOW              #
#############################################

# Function to configure time settings
configure_time() {
  sudo timedatectl set-ntp off
  sudo timedatectl set-ntp on
}

# Function to move SSH certificates
move_ssh_certs() {
  cp /home/$user/{$certName,$certName.pub} /home/$user/.ssh
  chmod 600 /home/$user/.ssh/$certName
  chmod 644 /home/$user/.ssh/$certName.pub
}

# Function to create SSH config
create_ssh_config() {
  echo "StrictHostKeyChecking no" > ~/.ssh/config
}

# Function to add SSH keys to all nodes
add_ssh_keys() {
  for node in "${all[@]}"; do
    ssh-copy-id $user@$node
  done
}

# Function to copy SSH keys to the first manager
copy_ssh_keys_to_first_manager() {
  scp -i /home/$user/.ssh/$certName /home/$user/$certName $user@${managers[0]}:~/.ssh
  scp -i /home/$user/.ssh/$certName /home/$user/$certName.pub $user@${managers[0]}:~/.ssh
}

# Function to install dependencies on each node
install_dependencies() {
  for newnode in "${all[@]}"; do
    ssh $user@$newnode -i ~/.ssh/$certName sudo su <<'EOF'
    iptables -F
    iptables -P INPUT ACCEPT
    apt-get update
    NEEDRESTART_MODE=a apt install ca-certificates curl gnupg -y
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    NEEDRESTART_MODE=a apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
    NEEDRESTART_MODE=a apt install software-properties-common glusterfs-server -y
    systemctl start glusterd
    systemctl enable glusterd
    mkdir -p /gluster/volume1
    exit
EOF
    echo -e " \033[32;5m$newnode - Docker & GlusterFS installed!\033[0m"
  done
}

# Function to initialize Docker Swarm
initialize_swarm() {
  ssh -tt $user@${managers[0]} -i ~/.ssh/$certName sudo su <<EOF
  docker swarm init --advertise-addr ${managers[0]} --default-addr-pool 10.20.0.0/16 --default-addr-pool-mask-length 26
  docker swarm join-token manager | sed -n 3p | grep -Po 'docker swarm join --token \\K[^\\s]*' > manager.txt
  docker swarm join-token worker | sed -n 3p | grep -Po 'docker swarm join --token \\K[^\\s]*' > worker.txt
  echo "StrictHostKeyChecking no" > ~/.ssh/config
  ssh-copy-id -i /home/$user/.ssh/$certName $user@$admin
  scp -i /home/$user/.ssh/$certName /home/$user/manager.txt $user@$admin:~/manager
  scp -i /home/$user/.ssh/$certName /home/$user/worker.txt $user@$admin:~/worker
  exit
EOF
  echo -e " \033[32;5mFirst Manager Initialized\033[0m"
}

# Function to join additional manager nodes to the Swarm
join_manager_nodes() {
  managerToken=$(cat manager)
  for i in $(seq 1 $((num_managers-1))); do
    ssh -tt $user@${managers[$i]} -i ~/.ssh/$certName sudo su <<EOF
    docker swarm join \
    --token $managerToken \
    ${managers[0]}
    exit
EOF
    echo -e " \033[32;5m${managers[$i]} - Manager node joined successfully!\033[0m"
  done
}

# Function to join worker nodes to the Swarm
join_worker_nodes() {
  workerToken=$(cat worker)
  for newnode in "${workers[@]}"; do
    ssh -tt $user@$newnode -i ~/.ssh/$certName sudo su <<EOF
    docker swarm join \
    --token $workerToken \
    ${managers[0]}
    exit
EOF
    echo -e " \033[32;5m$newnode - Worker node joined successfully!\033[0m"
  done
}

# Function to create GlusterFS Cluster
create_glusterfs_cluster() {
  local gluster_nodes=("${managers[@]}" "${workers[@]}")
  ssh -tt $user@${managers[0]} -i ~/.ssh/$certName sudo su <<EOF
  $(for node in "${gluster_nodes[@]}"; do echo "gluster peer probe $node"; done)
  gluster volume create staging-gfs replica $((num_managers + num_workers)) $(for node in "${gluster_nodes[@]}"; do echo "$node:/gluster/volume1"; done) force
  gluster volume start staging-gfs
  chmod 666 /var/run/docker.sock
  $(for i in $(seq 0 $((num_workers-1))); do echo "docker node update --label-add worker=true worker$((i+1))"; done)
  exit
EOF
  echo -e " \033[32;5mGlusterFS created\033[0m"
}

# Function to ensure GlusterFS mount restarts after boot
configure_glusterfs_mount() {
  for newnode in "${all[@]}"; do
    ssh $user@$newnode -i ~/.ssh/$certName sudo su <<'EOF'
    echo 'localhost:/staging-gfs /mnt glusterfs defaults,_netdev,backupvolfile-server=localhost 0 0' >> /etc/fstab
    mount.glusterfs localhost:/staging-gfs /mnt
    chown -R root:docker /mnt
    exit
EOF
    echo -e " \033[32;5m$newnode - GlusterFS mounted on reboot\033[0m"
  done
}

# Function to deploy Portainer
deploy_portainer() {
  ssh -tt $user@${managers[0]} -i ~/.ssh/$certName sudo su <<'EOF'
  mkdir /mnt/Portainer
  curl -L https://raw.githubusercontent.com/JamesTurland/JimsGarage/main/Docker-Swarm/portainer-agent-stack.yml -o portainer-agent-stack.yml
  docker stack deploy -c portainer-agent-stack.yml portainer
  docker node ls
  docker service ls
  gluster pool list
  exit
EOF
  echo -e " \033[32;5mPortainer deployed\033[0m"
}

# Main script execution
main() {
  configure_time
  move_ssh_certs
  create_ssh_config
  add_ssh_keys
  copy_ssh_keys_to_first_manager
  install_dependencies
  initialize_swarm
  join_manager_nodes
  join_worker_nodes
  create_glusterfs_cluster
  configure_glusterfs_mount
  deploy_portainer
}

main