#!/usr/bin/env bash
set -euo pipefail

# Start Swarmex AWS cluster
# NOTE: Public IPs change on restart! Update DNS after starting.

INSTANCES="i-013089e382b888fed i-051240a94210fd140 i-09a230652cc4b2fd3"
REGION="us-east-1"

echo "Starting Swarmex cluster..."
aws ec2 start-instances --region $REGION --instance-ids $INSTANCES --output text

echo "Waiting for instances to be running..."
aws ec2 wait instance-running --region $REGION --instance-ids $INSTANCES

echo ""
echo "=== New IPs (update Cloudflare DNS!) ==="
aws ec2 describe-instances --region $REGION --instance-ids $INSTANCES \
  --query "Reservations[].Instances[].{Name:Tags[?Key=='Name']|[0].Value,PublicIp:PublicIpAddress}" \
  --output table

echo ""
echo "Update swarmex.apulab.info and *.swarmex.apulab.info in Cloudflare to the manager IP."
echo "Then wait ~2min for Docker Swarm to reconverge."
