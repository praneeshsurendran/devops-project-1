# DevOps Project 1

This project deploys a static website on an AWS EC2 instance using Terraform, Ansible, and GitHub Actions. Terraform provisions the network and server, Ansible installs and configures Nginx, and GitHub Actions runs the deployment when code is pushed to `main`.

The website displays **“Welcome to the DevOps World!”** and a message describing the deployment tools.

## Deployment flow

```text
Pull request targeting main
  └── Terraform init → validate → plan

Push to main (including a merged pull request)
  └── Terraform init → apply
        └── Read EC2 public IP and DNS name
              └── Install Ansible and configure the SSH private key
                    └── Wait for SSH access as ubuntu
                          └── Install Nginx and copy the website
                                └── Print the application URL
```

Both workflows run on GitHub-hosted `ubuntu-latest` runners and use AWS region `ap-southeast-2` (Sydney).

## Repository structure

```text
.github/workflows/
  plan.yml                 # Terraform checks for pull requests
  deploy.yml               # Infrastructure and website deployment
bootstrap/
  main.tf                  # Calls the state backend module
  providers.tf             # AWS provider and bootstrap state backend
  modules/state-backend/   # S3 bucket and its protection settings
infrastructure/
  main.tf                  # Connects the networking and compute modules
  providers.tf             # AWS provider and application state backend
  variables.tf             # SSH public key input
  outputs.tf               # EC2 public IP and public DNS outputs
  modules/vpc/             # VPC, public subnet, gateway, and routing
  modules/ec2/             # Ubuntu instance, SSH key pair, and security group
ansible/
  site.yml                 # Runs the webserver role with sudo privileges
  roles/webserver/
    tasks/main.yml         # Installs Nginx and deploys the page
    files/index.html       # Static website content
```

## What Terraform provisions

### Network

The networking module creates:

- A VPC with CIDR `10.0.0.0/16` and DNS hostnames enabled.
- A subnet with CIDR `10.0.1.0/24`, calculated using `cidrsubnet`, with automatic public IPv4 assignment enabled.
- An internet gateway attached to the VPC.
- A route table with `0.0.0.0/0` routed through the internet gateway.
- An association between that route table and the subnet.

The gateway and route make the subnet publicly reachable. Assigning an EC2 public IP alone does not provide internet connectivity.

### Compute

The compute module creates:

- An EC2 SSH key pair named `dev-key` using the supplied public key.
- A security group named `dev-web-sg` that allows inbound TCP port `22` for SSH and port `80` for HTTP from `0.0.0.0/0`, plus all outbound traffic.
- One `t3.micro` EC2 instance tagged `dev-web-server` in the public subnet.

Terraform selects the most recent Canonical Ubuntu 22.04 Jammy AMD64 AMI matching `ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*` in the configured region. The instance uses the SSH key pair and security group above.

The root module exports `server_public_ip` and `server_public_dns` for the deployment workflow. Resource names use the `dev` environment value configured in `infrastructure/main.tf`.

## Terraform state and bootstrap

Both Terraform roots use the AWS provider constraint `~> 6.0` and store state in the S3 bucket `praneesh-devops-tfstate-sydney-2026`:

| Terraform root | State object key |
| --- | --- |
| `bootstrap/` | `bootstrap/terraform.tfstate` |
| `infrastructure/` | `prod/terraform.tfstate` |

Both backends enable encryption and S3 lock files using `use_lockfile = true`. Although the infrastructure state key contains `prod`, the current resource environment is `dev`.

The bootstrap module manages the state bucket with versioning, default AES256 server-side encryption, all public access blocked, and Terraform `prevent_destroy` protection.

**First-time setup:** neither GitHub Actions workflow runs `bootstrap/`. The state bucket must exist before either workflow can initialize Terraform. The bootstrap configuration itself already points to that same bucket, so it cannot initialize against a bucket that does not yet exist. A fresh installation needs an initial bucket setup, such as provisioning the bootstrap resources with local state and then migrating that state to S3. Keep both backend bucket names aligned if you use a different bucket.

## Required setup

Configure these repository secrets under **Settings → Secrets and variables → Actions**:

| Secret | Purpose |
| --- | --- |
| `AWS_ACCESS_KEY_ID` | AWS credentials used by Terraform and the S3 backend. |
| `AWS_SECRET_ACCESS_KEY` | Matching AWS secret access key. |
| `TF_VAR_public_key` | Complete SSH public key registered as the EC2 key pair. |
| `SSH_PRIVATE_KEY` | Matching SSH private key used by the deployment runner. |

The AWS identity needs permission to manage the declared EC2 and VPC resources, query AMIs, and access the state bucket and its lock objects. Bootstrap also needs permission to manage the S3 bucket settings.

The public and private SSH keys must belong to the same key pair. Keep the private key's original multiline formatting when adding the secret.

The workflows currently authenticate using the access key secrets above. Pull request planning also needs access to the relevant secrets; fork pull requests generally do not receive repository secrets.

## What each workflow does

### Pull request: Terraform Plan

For pull requests targeting `main`, `.github/workflows/plan.yml`:

1. Checks out the repository and installs Terraform.
2. Runs `terraform init` in `infrastructure/`.
3. Runs `terraform validate`.
4. Runs `terraform plan -no-color` and shows the proposed changes in the workflow log.

This workflow does not apply infrastructure changes or deploy the website. Its plan is not saved for the deployment workflow to apply later.

### Push to main: Deploy Infrastructure & App

For every push to `main`, `.github/workflows/deploy.yml`:

1. Checks out the repository and installs Terraform.
2. Initializes `infrastructure/` and runs `terraform apply -auto-approve`. Terraform creates or updates the resources without an interactive approval step.
3. Reads the instance's public IP and public DNS name from Terraform outputs.
4. Installs Ansible on the runner, writes `SSH_PRIVATE_KEY` to `~/.ssh/deploy_key`, and sets its permissions to `400`.
5. Attempts SSH as `ubuntu` up to 30 times, with a five-second connection timeout and a five-second delay after each failed attempt. The check uses batch mode and disables strict host key checking. If all attempts fail, the step exits with an error and stops deployment.
6. Generates `ansible/inventory.ini` containing a `[webservers]` group and the instance's current public IP.
7. Runs `ansible-playbook -i inventory.ini site.yml -u ubuntu --private-key ~/.ssh/deploy_key`.
8. Prints `http://<server_public_dns>` after the playbook succeeds.

The deployment workflow creates its own Terraform plan as part of `apply`. There are no path filters, so a push to `main` runs the whole workflow even when only documentation or website content changes.

## What Ansible configures

`ansible/site.yml` targets all hosts in the generated inventory and runs the `webserver` role with privilege escalation (`become: yes`). The role:

1. Refreshes the APT package cache and ensures Nginx is installed.
2. Copies `ansible/roles/webserver/files/index.html` to `/var/www/html/index.html`, owned by `root:root` with permissions `0644`.
3. Ensures the Nginx service is running and enabled to start at boot.

To change the website, edit `ansible/roles/webserver/files/index.html` and push the change to `main`, or merge a pull request into `main`. The next successful deployment copies the updated page to the instance.

## Access and verification

After a successful deployment, open the HTTP URL printed by the final workflow step. You can also retrieve the current address from an initialized local Terraform checkout with AWS credentials configured:

```bash
terraform -chdir=infrastructure output -raw server_public_dns
terraform -chdir=infrastructure output -raw server_public_ip
```

The project serves the page over HTTP on port `80`. The repository does not configure HTTPS, a custom domain, a load balancer, or an Elastic IP. The public address can change after instance replacement or a stop/start, so use the latest outputs.

The final workflow step prints the URL; it does not perform an HTTP health check. To verify the page separately, run:

```bash
curl -f http://<server_public_dns>
```

## Troubleshooting deployment

| Symptom | What to check |
| --- | --- |
| SSH connection times out | Confirm the instance is running, has a public IP, and its subnet uses the route to an attached internet gateway. Check that the security group and network ACLs allow the connection. |
| SSH reports `Permission denied (publickey)` | Confirm `SSH_PRIVATE_KEY` matches `TF_VAR_public_key` and the login user is `ubuntu`. |
| Terraform initialization fails | Confirm the configured state bucket already exists in `ap-southeast-2` and the AWS identity can access state and lock objects. |
| Nginx installation fails | Confirm the instance has outbound internet access to Ubuntu package repositories. |
| Website is unreachable | Check the current public address, HTTP port `80`, the Nginx service, and the Ansible task results. |

The workflows do not automatically destroy resources after deployment. The EC2 instance, storage, public IPv4 address, and state bucket remain in AWS until explicitly removed and may incur charges. The bootstrap bucket has Terraform destruction protection enabled.
