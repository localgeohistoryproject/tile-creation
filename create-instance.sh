#!/bin/bash
# Keep track of started time
now=$(date +"%T")
echo "Creation Script Started: $now"
# Import variables
set -o allexport
source .env
set +o allexport
echo "Variables set"
# Create local folder if missing
if [ ! -d "./local" ]; then
  mkdir local
  echo "Folder local created"
fi
# Create local launch template with variables
cat LaunchTemplate.json | envsubst > ./local/LaunchTemplate.json
echo "Customized launch template created"
# Launch AWS instance
INSTANCE_ID=$(aws ec2 run-instances --cli-input-json file://local/LaunchTemplate.json --query 'Instances[*].InstanceId' --output text)
echo "AWS instance $INSTANCE_ID created"
# Wait until instance running to move forward
INSTANCE_RUNNING=$(aws ec2 describe-instance-status --instance-ids ${INSTANCE_ID} --query 'InstanceStatuses[*].InstanceState.Name' --output text)
while [ "$INSTANCE_RUNNING" != "running" ]
do
  echo "Not yet running, waiting 30 seconds"
  sleep 30
  INSTANCE_RUNNING=$(aws ec2 describe-instance-status --instance-ids ${INSTANCE_ID} --query 'InstanceStatuses[*].InstanceState.Name' --output text)
done
# Get IP address
INSTANCE_IP=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} --query 'Reservations[*].Instances[*].PublicIpAddress' --output text)
echo "AWS Instance assigned to public IP ${INSTANCE_IP}"
# Copy files to instance
echo "Start file copying"
scp -i "${INSTANCE_KEY_FOLDER}${INSTANCE_KEY}.pem" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q "./.env" ubuntu@${INSTANCE_IP}:/home/ubuntu
while [ $? -gt 0 ]
do
  echo "Waiting 30 seconds to try again"
  sleep 30
  scp -i "${INSTANCE_KEY_FOLDER}${INSTANCE_KEY}.pem" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q "./.env" ubuntu@${INSTANCE_IP}:/home/ubuntu
done
scp -i "${INSTANCE_KEY_FOLDER}${INSTANCE_KEY}.pem" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q "./process-tile.sh" ubuntu@${INSTANCE_IP}:/home/ubuntu
scp -i "${INSTANCE_KEY_FOLDER}${INSTANCE_KEY}.pem" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q "./Simplified10.poly" ubuntu@${INSTANCE_IP}:/home/ubuntu
scp -i "${INSTANCE_KEY_FOLDER}${INSTANCE_KEY}.pem" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q "./Simplified25.poly" ubuntu@${INSTANCE_IP}:/home/ubuntu
# Run processes on server
echo "Make process script executable"
ssh -i "${INSTANCE_KEY_FOLDER}${INSTANCE_KEY}.pem" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@${INSTANCE_IP} 'chmod +x /home/ubuntu/process-tile.sh'
ssh -i "${INSTANCE_KEY_FOLDER}${INSTANCE_KEY}.pem" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@${INSTANCE_IP} 'sudo /home/ubuntu/process-tile.sh'
# Terminate instance and complete
sleep 30
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
now=$(date +"%T")
echo "Creation Script Completed: $now"