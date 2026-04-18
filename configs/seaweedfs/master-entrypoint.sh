#!/bin/sh
# Resolve container IP at runtime for SeaweedFS master advertisement
MY_IP=$(hostname -i | awk '{print $1}')
echo "Starting SeaweedFS master with IP: $MY_IP"
exec weed master -ip="$MY_IP" -ip.bind=0.0.0.0 -defaultReplication=001
