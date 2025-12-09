# Terraform Configuration for binocular-cv

This directory contains the Terraform configuration for the `binocular-cv` project.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html)
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)

## Usage

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Apply the Terraform configuration:
   ```bash
   terraform apply
   ```

## GPU Quota Issue

The `gpu-pool-l4` node pool in `gke.tf` is configured to use an `nvidia-l4` GPU. This may fail to create if you do not have sufficient quota for this GPU type in the `us-west1` region.

If you encounter an error related to the `gpu-pool-l4` node pool, you can work around the issue by commenting out the `guest_accelerator` block in `gke.tf` and changing the `machine_type` to a standard machine type, such as `n1-standard-1`.

To request a quota increase, please follow the instructions in the [Google Cloud documentation](https://cloud.google.com/compute/quotas#requesting_additional_quota).
