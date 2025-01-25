#!/bin/bash

# ArgoNodes.sh
# Kyle Bryenton - 2025-01-25
#
# This will how what's running in each node on the Argo cluster

#!/bin/bash

for node in {1..65} 72 73 ; do 
  echo -en "$node" 
  squeue -w "argo$node" | sed '/JOBID/d' | paste -sd ' ' 
done

