#!/bin/bash
set -x
pkill redis-server
sleep 1
redis-server --port 6379 &> /dev/null &
redis-server --port 6380 --requirepass 'secret' &> /dev/null &

for v in `seq 7000 7005`; do
  redis-server --cluster-enabled yes --cluster-config-file /tmp/$v-nodes.conf --port $v &> /dev/null &
  sleep 1
  redis-cli -h 127.0.0.1 -p $v -c flushall
  redis-cli -h 127.0.0.1 -p $v -c cluster reset
done

echo yes | redis-cli --cluster create 127.0.0.1:7000 127.0.0.1:7001 127.0.0.1:7002 127.0.0.1:7003 127.0.0.1:7004 127.0.0.1:7005
