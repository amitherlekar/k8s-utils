This script captures warnings, pending pods, failed pods, failed jobs, pod metrics and node metrics. This script is for those implementation teams where they deploy your Kubernetes apps, but fail to recognize the need to have a formal monitoring tool like Prometheus to see how your app behaves in real time with the given resource constraints.

### **1. Prequisites**
1. Deploy Metrics API on the cluster: https://github.com/kubernetes-sigs/metrics-server
2. The script makes use of kubectl and jq. Make sure they are already installed on the machine where the script executes.

### **2. How to run?**
Download the script on the machine. Edit the `NAMESPACE` variable within the script to change it to the namespace of your app.

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

When the job completes, it finishes logging all the monitored messages in a log file that looks something like this: `kube_events_2025-04-20_12-54-30.log`

Sample log snippet

```bash
--------------------------------------------------------------------------------------------
Thu Apr  3 14:05:50 IST 2025: Resource (CPU/memory) usage of nodes:

Node                           CPU(cores) CPU(%)     Memory(bytes)   Memory(%)  Notice              
------------------------------ ---------- --------   --------------- ---------- --------------------
ln8cirmaster1                  1260m      31%        6107Mi          38%        None                
ln8cirmaster2                  187m       4%         2586Mi          16%        None                
ln8cirmaster3                  197m       4%         2549Mi          16%        None                
ln8cirworker1                  1912m      47%        5299Mi          33%        None                
ln8cirworker2                  3640m      91%        3868Mi          24%        ALERT: High CPU     
ln8cirworker3                  2404m      60%        4776Mi          30%        None                
ln8cirworker4                  1926m      48%        4334Mi          27%        None                
ln8cirworker5                  2826m      70%        4655Mi          29%        None                
--------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
Thu Apr  3 14:05:50 IST 2025: Resource (CPU/memory) usage of pods:

Pod Name                                 CPU Usage/Limit (%)  Memory Usage/Limit (%)    Notice              
---------------------------------------- -------------------- ------------------------- --------------------
activemq-0                               .019C/1C (1.00%)     679Mi/2048Mi (33.00%)     None                
api-7698fd749c-7mn67                     .008C/.500C (1.00%)  132Mi/512Mi (25.00%)      None                
api-7698fd749c-7x67r                     .007C/.500C (1.00%)  124Mi/512Mi (24.00%)      None                
fe-supervised-job-7lp5f-ww79x            .948C/2C (47.00%)    696Mi/10240Mi (6.00%)     None                
fe-supervised-job-8jp25-kjspf            .951C/2C (47.00%)    736Mi/10240Mi (7.00%)     None                
fe-supervised-job-92fwb-j2wgl            .993C/2C (49.00%)    733Mi/10240Mi (7.00%)     None                
fe-supervised-job-j64dg-dwcff            .991C/2C (49.00%)    703Mi/10240Mi (6.00%)     None                
fe-supervised-job-w7j9p-v4m8v            .974C/2C (48.00%)    717Mi/10240Mi (7.00%)     None                
fe-supervised-job-xq29k-254gj            .993C/2C (49.00%)    707Mi/10240Mi (6.00%)     None                
mariadb-0                                16.677C/1C (1667.00%) 201Mi/3072Mi (6.00%)      ALERT: High CPU                
scanner-job-279wv-gqlnq                  .193C/2C (9.00%)     1071Mi/3072Mi (34.00%)    None                
scanner-job-2tckd-ggp2g                  .136C/2C (6.00%)     1095Mi/3072Mi (35.00%)    None                
scanner-job-7jlrv-bvwf8                  .343C/2C (17.00%)    751Mi/3072Mi (24.00%)     None                
scanner-job-8rlxt-9zqmm                  .327C/2C (16.00%)    1110Mi/3072Mi (36.00%)    None                
scanner-job-dvcd8-wm6hn                  .336C/2C (16.00%)    774Mi/3072Mi (25.00%)     None                
scanner-job-fncmk-64tdg                  .821C/2C (41.00%)    1153Mi/3072Mi (37.00%)    None                
scanner-job-mh2sm-76m46                  .380C/2C (19.00%)    907Mi/3072Mi (29.00%)     None                
scanner-job-n27qn-zhj64                  .340C/2C (17.00%)    797Mi/3072Mi (25.00%)     None                
scanner-job-n8kj5-4g2q2                  .393C/2C (19.00%)    814Mi/3072Mi (26.00%)     None                
scanner-job-phfmm-5gwkn                  .370C/2C (18.00%)    743Mi/3072Mi (24.00%)     None                
--------------------------------------------------------------------------------------------
Thu Apr  3 14:05:55 IST 2025: INFO: No pods found in failed state in the road namespace.

Thu Apr  3 14:05:55 IST 2025: ALERT: Failed jobs found in the road namespace.
------------------------------------------------------------------
JOB                          FAILED   EXIT_REASON
analysis-sensor-job-gvhdr    <none>   <none>
fe-supervised-job-7lp5f      <none>   <none>
fe-supervised-job-8jp25      <none>   <none>
fe-supervised-job-92fwb      <none>   <none>
fe-supervised-job-hxsfw      <none>   <none>
fe-supervised-job-j64dg      <none>   <none>
fe-supervised-job-m8x4j      <none>   <none>
fe-supervised-job-w7j9p      <none>   <none>
fe-supervised-job-xq29k      <none>   <none>
model-supervised-job-j4kst   <none>   <none>
scanner-job-279wv            <none>   <none>
scanner-job-2mdlx            <none>   <none>
scanner-job-2tckd            <none>   <none>
scanner-job-7jlrv            <none>   <none>
scanner-job-8rlxt            <none>   <none>
scanner-job-dvcd8            <none>   <none>
scanner-job-mh2sm            <none>   <none>
scanner-job-n27qn            <none>   <none>
scanner-job-n8kj5            <none>   <none>
scanner-job-phfmm            <none>   <none>

Thu Apr  3 14:05:56 IST 2025: INFO: Pod analysis-sensor-job-gvhdr-8ntmp is in pending state for 1 second(s).
Thu Apr  3 14:05:56 IST 2025: WARNING: Pod analysis-sensor-job-gvhdr-8ntmp is in pending state for 1 seconds.
Thu Apr  3 14:05:56 IST 2025: INFO: Pod fe-supervised-job-hxsfw-5qbxn is in pending state for 2 second(s).
Thu Apr  3 14:05:56 IST 2025: WARNING: Pod fe-supervised-job-hxsfw-5qbxn is in pending state for 2 seconds.
Thu Apr  3 14:05:56 IST 2025: INFO: Pod scanner-job-2mdlx-jtsj4 is in pending state for 1 second(s).
Thu Apr  3 14:05:56 IST 2025: WARNING: Pod scanner-job-2mdlx-jtsj4 is in pending state for 1 seconds.
```
