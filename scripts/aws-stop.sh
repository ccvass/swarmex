#!/usr/bin/env bash
set -euo pipefail

# Stop Swarmex AWS cluster to save costs (~$6/day when running)
# Instances keep their data (EBS volumes persist when stopped)

INSTANCES="i-013089e382b888fed i-051240a94210fd140 i-09a230652cc4b2fd3"
REGION="us-east-1"

echo "Stopping Swarmex cluster..."
aws ec2 stop-instances --region $REGION --instance-ids $INSTANCES --output text
echo "Instances stopping. Cost drops to ~$0.30/day (EBS only)."
echo "Run scripts/aws-start.sh to restart."
