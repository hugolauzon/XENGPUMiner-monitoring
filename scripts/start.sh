#!/bin/bash

source scripts/utils.sh
cd_xengpuminer

#ps -x -o command | grep -x "python3 miner.py" -eq "python3 miner.py --logging-on"

if ! screen -list | grep -q "gpuminer"; then
  printTitle "Starting python3 miner.py --logging-on"
  screen -S "gpuminer" -dm bash -c "python3 miner.py --logging-on"
  screen -S "cpuminer" -dm bash -c "python3 miner.py --logging-on"

  sed -n 5p config.conf

  GPU_COUNT=$(nvidia-smi --list-gpus | wc -l)

  if [ $GPU_COUNT -eq 0 ]; then
    printTitle "Error could not find any GPU"
    exit 1
  fi

  printTitle "Found $GPU_COUNT GPU"
  for ((i = 0; i < $GPU_COUNT; i++)); do
    printSubTitle "Starting GPU $i"
    screen -S "gpuminer" -X screen bash -c "./xengpuminer -d $i"
  done
  
  if [ -z ${CPU_COUNT+x} ]; then
    for ((j = 0; j < $CPU_COUNT; j++)); do
      printSubTitle "Starting CPU $j"
      screen -S "cpuminer" -X screen bash -c "./xengpuminer -m cpu"
    done
    RESET_REQ = false
  else
    j = 0
    HR0 = $(awk '{ if (FNR==1) {sum+=$0} } END {print sum} ' ./hash_rates/hashrate*)
    HR1 = $HR0
    printSubTitle "Starting CPU $j"
    screen -S "cpuminer" -X screen bash -c "./xengpuminer -m cpu"
    HR2 = $(awk '{ if (FNR==1) {sum+=$0} } END {print sum} ' ./hash_rates/hashrate*)
    sleep 10
    while [$HR2 -gt $HR1]; do
      ((j++))
      printSubTitle "Starting CPU $j"
      HR1 = $HR2
      screen -S "cpuminer" -X screen bash -c "./xengpuminer -m cpu"
      sleep 10
      HR2 = $(awk '{ if (FNR==1) {sum+=$0} } END {print sum} ' ./hash_rates/hashrate*)
      printSubTitle "Current total hash rate: $HR2 H/s"
    done
    CPU_COUNT = $j
    if [$HR1 -gt (($HR2 + 30))]; then
      ((CPU_COUNT--))
      RESET_REQ = true
      printSubTitle "Started too many CPUs. Need a script reset."
    fi
  fi
else
  printTitle "Nothing to start, you are already mining!"
fi

cd_project_root
