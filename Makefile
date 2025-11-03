.PHONY: help init plan apply clean

help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  help    Show this help message"
	@echo "  init    Initialize Terraform"
	@echo "  plan    Create a Terraform execution plan"
	@echo "  apply   Refresh node pool state and apply the Terraform plan"
	@echo "  clean   Remove the local Terraform cache"

init:
	@echo "Initializing Terraform..."
	@terraform init

plan:
	@echo "Creating Terraform plan..."
	@terraform plan

apply:
	@echo "Applying Terraform plan..."
	@terraform apply -auto-approve

clean:
	@echo "Removing local Terraform cache..."
	@rm -rf .terraform
	@rm -f .terraform.lock.hcl
