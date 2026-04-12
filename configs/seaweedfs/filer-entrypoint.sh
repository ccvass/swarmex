#!/bin/sh
# Wait for master to be ready, then start filer
echo "Waiting for SeaweedFS master..."
until wget -qO- http://seaweedfs-master:9333/cluster/status >/dev/null 2>&1; do
  sleep 2
done
echo "Master ready, starting filer"
exec weed filer -master=seaweedfs-master:9333
