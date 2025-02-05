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
  TOT_GPU_COUNT=$(lspci|grep 'VGA\|Display' -c)
  TOT_CPU_COUNT=$(nproc)
  NET_CPU_COUNT=$(((TOT_CPU_COUNT*GPU_COUNT/TOT_GPU_COUNT)-GPU_COUNT-1))
  NET_CPU_COUNT_INT=${NET_CPU_COUNT%.*}
  printTitle "Net CPU Count = $NET_CPU_COUNT"
  if [ $GPU_COUNT -eq 0 ]; then
    printTitle "Error could not find any GPU"
    exit 1
  fi

  printTitle "Found $GPU_COUNT GPU"
  for ((i = 0; i < $GPU_COUNT; i++)); do
    printSubTitle "Starting GPU $i"
    screen -S "gpuminer" -X screen bash -c "./xengpuminer -d $i"
    sleep 3
    HR0=$(awk '{ if (FNR==1) {sum+=$0} } END {print sum} ' ./hash_rates/hashrate*)
    printSubTitle "Current total hash rate: $HR0 H/s"
  done
  
  # if [ $NET_CPU_COUNT_INT -gt 0 ]; then
  #   for ((j = 0; j < $NET_CPU_COUNT_INT; j++)); do
  #     printSubTitle "Starting CPU $j"
  #     screen -S "cpuminer" -X screen bash -c "./xengpuminer -m cpu"
  #     sleep 3
  #     HR0=$(awk '{ if (FNR==1) {sum+=$0} } END {print sum} ' ./hash_rates/hashrate*)
  #     printSubTitle "Current total hash rate: $HR0 H/s"
  #   done
  # fi



  if [ -f ./mining_cpu_count.txt ]; then
    CPU_COUNT=$(< ./mining_cpu_count.txt)
    printSubTitle "CPU_COUNT already set to $CPU_COUNT"
    for ((j = 0; j < $CPU_COUNT; j++)); do
      printSubTitle "Starting CPU $j"
      screen -S "cpuminer" -X screen bash -c "./xengpuminer -m cpu"
    done
    RESET_REQ=0
    export RESET_REQ
  else
    j=0
    sleep 60
    HR0=$(awk '{ if (FNR==1) {sum+=$0} } END {print sum} ' ./hash_rates/hashrate*)
    HR1=$HR0
    printSubTitle "Current total hash rate: $HR1 H/s"
    printSubTitle "Starting CPU $j"
    screen -S "cpuminer" -X screen bash -c "./xengpuminer -m cpu"
    sleep 3
    HR2=$(awk '{ if (FNR==1) {sum+=$0} } END {print sum} ' ./hash_rates/hashrate*)
    printSubTitle "Current total hash rate: $HR2 H/s"
    while (( $(echo "$HR2 > $HR1 + 2.0" | bc -l) && $j < $NET_CPU_COUNT_INT )); do
      ((j++))
      printSubTitle "Starting CPU $j"
      HR1=$HR2
      screen -S "cpuminer" -X screen bash -c "./xengpuminer -m cpu"
      sleep 3
      HR2=$(awk '{ if (FNR==1) {sum+=$0} } END {print sum} ' ./hash_rates/hashrate*)
      printSubTitle "Current total hash rate: $HR2 H/s"
    done
    CPU_COUNT=$j
    printSubTitle "Hash rate optimized succesfully!"
    "$CPU_COUNT" >mining_cpu_count.txt
  fi
else
  printTitle "Nothing to start, you are already mining!"
fi

cd_project_root