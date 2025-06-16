#!/bin/bash

# Function to get the list of pods in the vplmn namespace
get_pods() {
    echo "Fetching pods in the vplmn namespace..."
    kubectl get pods -n vplmn
}

# Function to copy the pcap file from the specified pod
copy_pcap() {
    local pod_name
    local file_name

    # Prompt user for pod name
    read -p "Enter the pod name: " pod_name

    # Prompt user for file name
    read -p "Enter the file name to save as (without extension): " file_name

    # Execute the kubectl cp command
    echo "Copying pcap file from pod $pod_name..."
    kubectl cp "$pod_name:/pcap/sepp.pcap" "./pcap-logs/$file_name.pcap" -c sniffer -n vplmn
}

# Main script execution
get_pods
copy_pcap
