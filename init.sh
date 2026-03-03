#!/bin/bash

# Fix Siege Log Path Error: Create a custom config to use /tmp/
echo "logfile = /tmp/siege.log" > /tmp/.siegerc
export SIEGERC="/tmp/.siegerc"

# System Setup
service nginx start >/dev/null 2>&1
ulimit -n 10000 2>/dev/null
sysctl -w net.ipv4.tcp_tw_reuse=1 >/dev/null 2>&1

# Print the CSV Header once
echo "Run,CPU_Avg,Trans,Elapsed,Data,Resp_Time,Trans_Rate,Throughput,Concurrent,OK,Failed"

counter=1
while true; do
    # 1. Setup temp files and clear previous data
    CPU_LOG="/tmp/cpu_samples.txt"
    SIEGE_LOGFILE="/tmp/siege.log"
    
    rm -f $CPU_LOG $SIEGE_LOGFILE
    touch $SIEGE_LOGFILE
    chmod 777 $SIEGE_LOGFILE
    
    # Kill any hung processes
    pkill -9 siege 2>/dev/null
    
    # Clear Nginx logs after each run to prevent I/O bloat
    truncate -s 0 /var/log/nginx/access.log 2>/dev/null
    truncate -s 0 /var/log/nginx/error.log 2>/dev/null

    # 2. Start CPU Monitor (Background)
    (while true; do 
        top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}' >> $CPU_LOG
        sleep 2
    done) & 
    MONITOR_PID=$!

    # 3. Run Siege (Quiet Mode -q)
    # -l triggers logging to the file defined in /tmp/.siegerc
    siege -q -i -c 50 -d 0.1 -t 1M -l -H "Connection: Keep-Alive" -f /etc/siege/urls.txt

    # 4. Immediate Cleanup
    # Redirect stderr to hide the "Killed" job control message
    { kill -9 $MONITOR_PID && wait $MONITOR_PID; } 2>/dev/null
    pkill -9 siege 2>/dev/null


    # 5. Process CPU Average
    AVG_CPU=$(awk '{ sum += $1; n++ } END { if (n > 0) printf "%.2f", sum / n; else print "0.00" }' $CPU_LOG)

    # 6. Extract Siege values and print to STDOUT
    if [ -s $SIEGE_LOGFILE ]; then
        # Skip column 1 (Date/Time) and format the rest as CSV
        SIEGE_VALS=$(tail -n 1 $SIEGE_LOGFILE | awk -F', ' '{for (i=2; i<=NF; i++) printf ",%s", $i}')
        
        # Output the joined CSV row
        echo "${counter},${AVG_CPU}${SIEGE_VALS}"
    fi

    ((counter++))
    # Cooldown for TCP stack stability
    sleep 30
done
