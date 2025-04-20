#!/bin/bash

if [[ -z "$1" || ! "$1" =~ ^[0-9]+$ || "$1" -lt 1 ]]; then
  echo "Invalid input. The given input must be a valid positive number."
  exit 1
fi

POLL_INTERVAL_SECONDS=2
EXECUTION_DURATION_HOURS=$1
# Set the threshold for the maximum allowed time in Init state (in minutes)
MAX_PENDING_TIME_MINUTES=1
MAX_PENDING_TIME_SECONDS=30
NAMESPACE="road"
EXECUTION_DURATION_SECONDS=$((EXECUTION_DURATION_HOURS * 60 * 60))
THRESHOLD_CPU=80   # CPU usage alert threshold in percentage
THRESHOLD_MEM=80   # Memory usage alert threshold in MiB

# Get the start time
START_TIME=$(date +%s)
START_TIME_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)

LOG_FILE="kube_events_$(date +%Y-%m-%d_%H-%M-%S).log"

convert_cpu_to_cores() {
    local cpu_value=$1
    if [[ "$cpu_value" == *m ]]; then
        echo "scale=3; ${cpu_value%m} / 1000" | bc  # Convert mCPU to cores
    else
        echo "$cpu_value"  # Already in cores
    fi
}

# Convert Memory units (`Mi`, `Gi` → MiB)
convert_mem_to_mib() {
    local mem_value=$1
    if [[ "$mem_value" == *Mi ]]; then
        echo "${mem_value%Mi}"  # Already in MiB
    elif [[ "$mem_value" == *Gi ]]; then
        echo $(( ${mem_value%Gi} * 1024 ))  # Convert GiB to MiB
    else
        echo "$mem_value"  # Unknown format, return as is
    fi
}

# Get resource limits for a given pod
get_pod_limits() {
    local pod=$1
    local resource_type=$2  # "cpu" or "memory"

    # Fetch resource limits using kubectl
    kubectl get pod "$pod" -n "$NAMESPACE" -o=jsonpath="{.spec.containers[*].resources.limits.$resource_type}" 2>/dev/null
}

print_node_metrics() {
    echo "--------------------------------------------------------------------------------------------" >> "$LOG_FILE"
    echo "$(date): Resource (CPU/memory) usage of nodes:" >> "$LOG_FILE"
    printf "\n%-30s %-10s %-10s %-15s %-10s %-20s\n" "Node" "CPU(cores)" "CPU(%)" "Memory(bytes)" "Memory(%)" "Notice" >> "$LOG_FILE"
    printf "%-30s %-10s %-10s %-15s %-10s %-20s\n" "------------------------------" "----------" "--------" "---------------" "----------" "--------------------">> "$LOG_FILE"

    # Get node resource usage
    kubectl top node --no-headers | while read -r node cpu_cores cpu_percent memory_bytes memory_percent; do
        cpu_usage=${cpu_percent%\%}  # Remove '%' from CPU value
        mem_usage=${memory_percent%\%}  # Remove '%' from Memory value
        alert="None"  # Default status

        # Check if CPU or Memory usage exceeds the threshold
        if [[ $cpu_usage -ge $THRESHOLD_CPU ]]; then
            alert="ALERT: High CPU"
        fi

        if [[ $mem_usage -ge $THRESHOLD_MEM ]]; then
            alert="ALERT: High Memory"
        fi

        # Print tabular output with alerts
        printf "%-30s %-10s %-10s %-15s %-10s %-20s\n" "$node" "$cpu_cores" "$cpu_percent" "$memory_bytes" "$memory_percent" "$alert" >> "$LOG_FILE"

    done
    echo "--------------------------------------------------------------------------------------------" >> "$LOG_FILE"

}

print_pod_metrics() {
    # Get resource usage for job pods
    echo "--------------------------------------------------------------------------------------------" >> "$LOG_FILE"
    echo "$(date): Resource (CPU/memory) usage of pods:" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    printf "%-40s %-20s %-25s %-20s\n" "Pod Name" "CPU Usage/Limit (%)" "Memory Usage/Limit (%)" "Notice" >> "$LOG_FILE"
    printf "%-40s %-20s %-25s %-20s\n" "----------------------------------------" "--------------------" "-------------------------" "--------------------" >> "$LOG_FILE"

    # Get resource usage for job pods
    kubectl top pods -n "$NAMESPACE" --no-headers | while read -r pod cpu mem; do
        # Convert CPU and memory usage
        cpu_usage=$(convert_cpu_to_cores "$cpu")
        mem_usage=$(convert_mem_to_mib "$mem")

        # Get pod limits
        cpu_limit_raw=$(get_pod_limits "$pod" "cpu")
        mem_limit_raw=$(get_pod_limits "$pod" "memory")

        # Convert limits to the same units
        cpu_limit=$(convert_cpu_to_cores "$cpu_limit_raw")
        mem_limit=$(convert_mem_to_mib "$mem_limit_raw")

        # Calculate CPU and Memory utilization %
        if [[ -n "$cpu_limit" && "$cpu_limit" != "0" ]]; then
            cpu_utilization=$(echo "scale=2; ($cpu_usage / $cpu_limit) * 100" | bc)
        else
            cpu_utilization=0
        fi

        if [[ -n "$mem_limit" && "$mem_limit" != "0" ]]; then
            mem_utilization=$(echo "scale=2; ($mem_usage / $mem_limit) * 100" | bc)
        else
            mem_utilization=0
        fi

        # Prepare alert messages
        alert_msg="None"
        if (( $(echo "$cpu_utilization >= $THRESHOLD_CPU" | bc -l) )); then
            alert_msg="ALERT: High CPU "
        fi
        if (( $(echo "$mem_utilization >= $THRESHOLD_MEM" | bc -l) )); then
            alert_msg="ALERT: High Memory"
        fi

        # Print output in a structured format
        printf "%-40s %-20s %-25s %-20s\n" "$pod" \
            "${cpu_usage}C/${cpu_limit}C (${cpu_utilization}%)" \
            "${mem_usage}Mi/${mem_limit}Mi (${mem_utilization}%)" \
            "$alert_msg" >> "$LOG_FILE"
    done
    
    echo "--------------------------------------------------------------------------------------------" >> "$LOG_FILE"
}


print_failed_pods() {
    # Get list of failed pods
    local failed_pods=$(kubectl -n $NAMESPACE get pods --field-selector=status.phase=Failed -o custom-columns="FAILED_POD:.metadata.name,REASON:.status.reason,EXIT_REASON:.status.containerStatuses[*].state.terminated.reason")
    #local output_with_no_header_line=$(awk 'NR>1' <<< "$failed_pods")
	local output_with_no_header_line=$(echo "$failed_jobs" | awk 'NR==1 || $3 != "<none>"')

    
    if [[ -z "$output_with_no_header_line" ]]; then
      echo "$(date): INFO: No pods found in failed state in the $NAMESPACE namespace."  >> "$LOG_FILE"
    else
      echo "$(date): ALERT: Failed pods found in the $NAMESPACE namespace."  >> "$LOG_FILE"
      echo "------------------------------------------------------------------"  >> "$LOG_FILE"
      echo "$failed_pods"  >> "$LOG_FILE"
    fi
    echo "" >> "$LOG_FILE"
    
}

print_failed_jobs() {
    # Get list of failed jobs
    failed_jobs=$(kubectl get job -n $NAMESPACE --field-selector status.successful=0 -o custom-columns="JOB:.metadata.name,FAILED:.status.failed,EXIT_REASON:.status.conditions[*].reason")
    local output_with_no_header_line=$(awk 'NR>1 && $3 != "<none>"' <<< "$failed_jobs")
    
    if [[ -z "$output_with_no_header_line" ]]; then
      echo "$(date): INFO: No jobs found in failed state in the $NAMESPACE namespace."  >> "$LOG_FILE"
    else
      echo "$(date): ALERT: Failed jobs found in the $NAMESPACE namespace."  >> "$LOG_FILE"
      echo "------------------------------------------------------------------"  >> "$LOG_FILE"
      echo "$failed_jobs" >> "$LOG_FILE"
    fi
    echo "" >> "$LOG_FILE"
    
}

print_init_pods() {

    # Get a list of pods in Init state
    pods_in_init=$(kubectl -n $NAMESPACE  get pods -o jsonpath='{.items[?(@.status.phase=="Pending")].metadata.name}' | tr ',' '\n')
 
    if [[ -z "$pods_in_init" ]]; then
      echo "$(date): INFO: No pods found in pending state in the $NAMESPACE namespace."  >> "$LOG_FILE"
    fi
    # Iterate through each pod in Init state
    for pod_name in $pods_in_init; do

      # Get the creation timestamp of the pod
      creation_timestamp=$(kubectl -n $NAMESPACE get pod "$pod_name" -o jsonpath='{.metadata.creationTimestamp}' | sed 's/T/\ /')

      # Calculate the time elapsed since creation
      elapsed_seconds=$(($(date +%s) - $(date -d "$creation_timestamp" +%s)))
      elapsed_minutes=$((elapsed_seconds / 60))

      echo "$(date): INFO: Pod $pod_name is in pending state for $elapsed_seconds second(s)." >> "$LOG_FILE"
      # Check if the pod has been in Init state for longer than the threshold
      if [[ $elapsed_seconds -ge $MAX_PENDING_TIME_SECONDS ]]; then
        if [[ $elapsed_minutes -ge 1 ]]; then
           echo "$(date): ALERT: Pod $pod_name is in pending state for $elapsed_minutes minute(s)." >> "$LOG_FILE"
        else
           echo "$(date): ALERT: Pod $pod_name is in pending state for $elapsed_seconds seconds." >> "$LOG_FILE"
        fi

          # Get pod events
          pod_events=$(kubectl -n $NAMESPACE describe pod "$pod_name" | grep -A10 "Events:")

          # Display pod events
          echo "Pod Events:" >>  "$LOG_FILE"
          echo "-----------" >>  "$LOG_FILE"
          echo "$pod_events" >> "$LOG_FILE"
          echo "" >> "$LOG_FILE"

          # Display node info
          echo "Scheduled node info:" >> "$LOG_FILE"
          echo "--------------------" >>  "$LOG_FILE"
          node_info=$(kubectl describe node $(kubectl -n $NAMESPACE get pod "$pod_name" -o jsonpath='{.spec.nodeName}'))
          echo "$node_info" >> "$LOG_FILE"
          echo "" >> "$LOG_FILE"
      else
         if [[ $elapsed_minutes -ge 1 ]]; then
             echo "$(date): WARNING: Pod $pod_name is in pending state for $elapsed_minutes minute(s)." >> "$LOG_FILE"
         else
             echo "$(date): WARNING: Pod $pod_name is in pending state for $elapsed_seconds seconds." >> "$LOG_FILE"
         fi
      fi
    done
}

print_cluster_warnings() {

    cluster_wide_warnings=$(kubectl get events --all-namespaces --field-selector type=Warning --sort-by='.metadata.creationTimestamp' --no-headers --output=custom-columns=TIMESTAMP:.metadata.creationTimestamp,TYPE:.type,NAMESPACE:.metadata.namespace,NAME:.metadata.name,MESSAGE:.message | awk  '$2 == "Warning" && $1 >= "'"$START_TIME_UTC"'"')
    if [[ -n "$cluster_wide_warnings" ]]; then
      echo "" >> "$LOG_FILE"
      echo "Cluster wide event warnings since start of execution:"  >> "$LOG_FILE"
      echo "-----------------------------------------------------"  >> "$LOG_FILE"
      echo "$cluster_wide_warnings"  >> "$LOG_FILE"
    fi
}

########################## Execution begins here ##########################

echo "------------------------------------------------------" >> "$LOG_FILE"
echo "Start time: $(date)" >> "$LOG_FILE"
echo "------------------------------------------------------" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

while true; do

    print_node_metrics
    
    print_pod_metrics
    
    print_failed_pods
    
    print_failed_jobs

    print_init_pods
    
    print_cluster_warnings
    
    # Check if the execution duration has been reached
    if [ $(( $(date +%s) - $START_TIME )) -ge $EXECUTION_DURATION_SECONDS ]; then
      echo "" >> "$LOG_FILE"
      echo "------------------------------------------------------" >> "$LOG_FILE"
      echo "End time: $(date)" >> "$LOG_FILE"
      echo "------------------------------------------------------" >> "$LOG_FILE"
      break
    fi
    printf "==========================================================================================================\n" >> "$LOG_FILE"
    # Sleep for POLL_INTERVAL_SECONDS seconds before the next check...
    echo "$(date): INFO: Sleeping for $POLL_INTERVAL_SECONDS seconds before the next check..."  >> "$LOG_FILE"
    sleep $POLL_INTERVAL_SECONDS
    printf "==========================================================================================================\n" >> "$LOG_FILE"
done
