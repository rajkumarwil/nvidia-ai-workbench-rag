#!/bin/bash

# Check if gedit is running
# -x flag only match processes whose name (or command line if -f is
# specified) exactly match the pattern. 

if pgrep -x "milvus" > /dev/null
then
    URLS=("http://localhost:8000/health" "http://localhost:19530/v1/vector/collections")

    for url in "${URLS[@]}"; do
        # Curl each URL, only outputting the HTTP status code
        status=$(curl -o /dev/null -s -w "%{http_code}" --max-time 3 "$url")
        
        # Check if the status is not 200
        if [[ $status -ne 200 ]]; then
            echo "Error: $url returned HTTP code $status"
            exit 1
        fi
    done
    
    # If loop completes without exiting, all URLs returned 200
    echo "All URLs returned HTTP code 200"
    exit 0
else
    # Start milvus
    echo "Starting Milvus"
    $HOME/.local/bin/milvus-server --data /mnt/milvus/ &
    
    # Start API
    echo "Starting API"
    cd /project/code/ && $HOME/.conda/envs/api-env/bin/python -m uvicorn chain_server.server:app --port=8000 --host='0.0.0.0' &

    # Wait for service to be reachable.
    ATTEMPTS=0
    MAX_ATTEMPTS=20
    
    while [ $(curl -o /dev/null -s -w "%{http_code}" "http://localhost:8000/health") -ne 200 ]; 
    do 
      ATTEMPTS=$(($ATTEMPTS+1))
      if [ ${ATTEMPTS} -eq ${MAX_ATTEMPTS} ]
      then
        echo "Max attempts reached: $MAX_ATTEMPTS. Server may have timed out. Stop the container and try again. "
        exit 1
      fi
      
      echo "Polling inference server. Awaiting status 200; trying again in 5s. "
      sleep 5
    done 
    
    echo "Service reachable. Happy chatting!"
    exit 0
    
    echo "RAG system ready"
    exit 0
fi
