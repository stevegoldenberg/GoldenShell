# Security Features

This document outlines the security measures implemented in GoldenShell.

## Security Improvements

### 1. Network Security

- **SSH Removed from Security Group**: Direct SSH access (port 22) has been removed from the security group. All SSH access is now exclusively through Tailscale VPN.
- **Tailscale VPN Only**: Access to the instance is secured via Tailscale's encrypted VPN connection.
- **Minimal Attack Surface**: Only Tailscale UDP port (41641) is exposed to the internet.

### 2. IAM Permissions

- **Least Privilege Principle**: IAM policies follow the principle of least privilege with specific resource constraints.
- **Resource Tags**: EC2 stop permissions are limited to instances with the `Project=GoldenShell` tag.
- **CloudWatch Namespace Restriction**: CloudWatch permissions are scoped to the `GoldenShell` namespace.
- **SSM Parameter Store**: Tailscale auth key permissions are limited to `/goldenshell/*` parameters.

### 3. Data Protection

- **EBS Encryption**: Root volume is encrypted at rest using AWS-managed encryption keys.
- **Automated Backups**: Daily EBS snapshots with configurable retention (default: 7 days).
- **S3 State Encryption**: Terraform state is stored in S3 with server-side encryption enabled.
- **S3 Versioning**: Terraform state bucket has versioning enabled to protect against accidental deletion.

### 4. Instance Security

- **IMDSv2 Enforced**: Instance Metadata Service v2 is required, preventing certain types of SSRF attacks.
- **Secrets Management**: Tailscale auth key is stored in SSM Parameter Store (encrypted) instead of plain text in user-data.
- **Secure Secrets Handling**: Auth key is retrieved at runtime and cleared from memory after use.

### 5. Cost Protection

- **Budget Alerts**: AWS Budgets configured to alert at 80%, 90% (forecast), and 100% of monthly budget.
- **Resource Tagging**: All resources tagged for cost tracking and management.
- **Auto-Shutdown**: Instance automatically shuts down after configured idle period (default: 30 minutes).

### 6. Monitoring & Alerting

- **CloudWatch Alarms**: Monitors CPU usage and instance health.
- **Status Check Monitoring**: Alerts on instance or system status check failures.
- **Optional SNS Integration**: Can send alarms to email/SMS via SNS topics.

## Security Best Practices

### Before Deployment

1. **Review Variables**: Check `terraform.tfvars` to ensure all sensitive values are appropriate.
2. **Enable S3 Backend**: Run `./setup-backend.sh` to create encrypted S3 backend for state storage.
3. **Set Budget Email**: Add your email to `budget_email_addresses` to receive cost alerts.

### After Deployment

1. **Rotate Keys**: Regularly rotate your Tailscale auth keys.
2. **Update Auth Key**: Update SSM Parameter Store value when rotating:
   ```bash
   aws ssm put-parameter --name "/goldenshell/tailscale-auth-key" \
     --value "tskey-auth-NEW-KEY" --overwrite --type SecureString
   ```
3. **Monitor Costs**: Review AWS Cost Explorer regularly.
4. **Review Snapshots**: Ensure automated snapshots are working and retain what you need.
5. **Check CloudWatch Logs**: Review `/var/log/user-data.log` for any issues.

### SSH Key Management

- Store your AWS SSH private key securely.
- Use SSH key passphrases.
- Limit SSH key permissions: `chmod 600 ~/.ssh/your-key.pem`

### Tailscale Security

- Use ephemeral auth keys when possible.
- Enable Tailscale ACLs to restrict access between devices.
- Review Tailscale audit logs regularly.

## Threat Model

### Protected Against

- ✅ Unauthorized SSH access from the internet
- ✅ Credential exposure in Terraform state/code
- ✅ Data loss from accidental deletion
- ✅ Cost overruns without warning
- ✅ Instance metadata service v1 exploits
- ✅ Unencrypted data at rest

### Still Vulnerable To

- ⚠️ Compromised AWS credentials
- ⚠️ Compromised Tailscale account
- ⚠️ Vulnerabilities in installed software
- ⚠️ Social engineering attacks

## Incident Response

If you suspect a security incident:

1. **Immediately Stop the Instance**:
   ```bash
   aws ec2 stop-instances --instance-ids <instance-id>
   ```

2. **Take an EBS Snapshot** (for forensics):
   ```bash
   aws ec2 create-snapshot --volume-id <volume-id> --description "Incident response snapshot"
   ```

3. **Rotate All Credentials**:
   - Tailscale auth key
   - AWS access keys (if compromised)
   - Any application credentials stored on the instance

4. **Review CloudWatch Logs** and Tailscale audit logs for suspicious activity.

5. **If Safe to Proceed**, create a new instance from a clean AMI.

## Security Updates

- Keep software updated by running `apt update && apt upgrade` regularly.
- Review AWS security bulletins for EC2/VPC changes.
- Monitor Tailscale release notes for security patches.

## Reporting Security Issues

If you discover a security vulnerability in this project, please open a GitHub issue or contact the maintainer directly.
