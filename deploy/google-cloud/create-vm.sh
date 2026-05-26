#!/usr/bin/env bash
set -euo pipefail

PROJECT="${GCP_PROJECT:?Set GCP_PROJECT}"
REGION="${GCP_REGION:-us-central1}"
ZONE="${GCP_ZONE:-us-central1-a}"
VM_NAME="${CAIO_VM_NAME:-caio-prod}"
ADDRESS_NAME="${CAIO_ADDRESS_NAME:-caio-prod-ip}"
MACHINE_TYPE="${CAIO_MACHINE_TYPE:-e2-standard-4}"
BOOT_DISK_SIZE="${CAIO_BOOT_DISK_SIZE:-100GB}"
DATA_DISK_SIZE="${CAIO_DATA_DISK_SIZE:-200GB}"

gcloud config set project "$PROJECT" >/dev/null

if ! gcloud compute addresses describe "$ADDRESS_NAME" --region "$REGION" >/dev/null 2>&1; then
  gcloud compute addresses create "$ADDRESS_NAME" --region "$REGION"
fi

STATIC_IP="$(gcloud compute addresses describe "$ADDRESS_NAME" --region "$REGION" --format='value(address)')"

if ! gcloud compute firewall-rules describe caio-allow-http-https >/dev/null 2>&1; then
  gcloud compute firewall-rules create caio-allow-http-https \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:80,tcp:443 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=http-server,https-server
fi

gcloud compute instances create "$VM_NAME" \
  --zone="$ZONE" \
  --machine-type="$MACHINE_TYPE" \
  --image-family=ubuntu-2404-lts-amd64 \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size="$BOOT_DISK_SIZE" \
  --boot-disk-type=pd-balanced \
  --create-disk=name="${VM_NAME}-data",mode=rw,auto-delete=no,size="$DATA_DISK_SIZE",type=pd-balanced,device-name=caio-data \
  --address="$STATIC_IP" \
  --tags=http-server,https-server \
  --shielded-secure-boot

cat <<INFO

VM created.
Static IP: $STATIC_IP

Create DNS A records:
  caio-jobs.com      -> $STATIC_IP
  www.caio-jobs.com  -> $STATIC_IP

Then SSH:
  gcloud compute ssh "$VM_NAME" --zone "$ZONE"

INFO
