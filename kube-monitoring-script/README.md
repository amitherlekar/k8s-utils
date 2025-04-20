This script captures warnings, pending pods, failed pods, failed jobs, pod metrics and node metrics. This script is for those implementation teams where they deploy your Kubernetes apps, but fail to recognize the need to have a formal monitoring tool like Prometheus to see how your app is behaving in real time.

### **1. Prequisites**
1. Deploy Metrics API on the cluster: https://github.com/kubernetes-sigs/metrics-server
2. The script makes use of kubectl and jq. Make sure they are already installed on the machine where the script executes.

### **2. How to run?**
Download the script on the machine. Edit the script variable to change the namespace of your app: `NAMESPACE`

```bash
# cd kube-monitoring-script/
# chmod +x monitorKubeEvents.sh
```
Then execute it as a background job

nohup ./monitorKubeEvents.sh <duration in hours>  >> nohup_kube_monitor_$(date +%Y-%m-%d_%H-%M-%S).log 2>&1 &

For example, the command below executes the script for four hours:
```bash
# nohup ./monitorKubeEvents.sh 4  >> nohup_kube_monitor_$(date +%Y-%m-%d_%H-%M-%S).log 2>&1 &
```