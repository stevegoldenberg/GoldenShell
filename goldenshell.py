#!/usr/bin/env python3
"""
GoldenShell - Deploy ephemeral Linux development environments in AWS
"""

import os
import sys
import click
import yaml
import json
import boto3
from pathlib import Path
from python_terraform import Terraform

CONFIG_DIR = Path.home() / ".goldenshell"
CONFIG_FILE = CONFIG_DIR / "config.yaml"


class Config:
    """Manage GoldenShell configuration"""

    def __init__(self):
        self.config_dir = CONFIG_DIR
        self.config_file = CONFIG_FILE
        self.config = self._load_config()

    def _load_config(self):
        """Load configuration from file"""
        if self.config_file.exists():
            with open(self.config_file, 'r') as f:
                return yaml.safe_load(f) or {}
        return {}

    def save(self):
        """Save configuration to file"""
        self.config_dir.mkdir(parents=True, exist_ok=True)
        with open(self.config_file, 'w') as f:
            yaml.dump(self.config, f, default_flow_style=False)

    def get(self, key, default=None):
        """Get configuration value"""
        return self.config.get(key, default)

    def set(self, key, value):
        """Set configuration value"""
        self.config[key] = value

    def display(self):
        """Display current configuration (masking sensitive values)"""
        display_config = self.config.copy()

        # Mask sensitive values
        if 'aws_access_key_id' in display_config:
            display_config['aws_access_key_id'] = '*' * 16
        if 'aws_secret_access_key' in display_config:
            display_config['aws_secret_access_key'] = '*' * 32
        if 'tailscale_auth_key' in display_config:
            display_config['tailscale_auth_key'] = '*' * 16

        return yaml.dump(display_config, default_flow_style=False)


@click.group()
def cli():
    """GoldenShell - Deploy ephemeral Linux development environments in AWS"""
    pass


@cli.command()
@click.option('--aws-access-key-id', prompt=True, help='AWS Access Key ID')
@click.option('--aws-secret-access-key', prompt=True, hide_input=True, help='AWS Secret Access Key')
@click.option('--aws-region', prompt=True, default='us-east-1', help='AWS Region')
@click.option('--tailscale-auth-key', prompt=True, hide_input=True, help='Tailscale Auth Key')
@click.option('--ssh-key-name', prompt=True, help='AWS SSH Key Pair Name')
def init(aws_access_key_id, aws_secret_access_key, aws_region, tailscale_auth_key, ssh_key_name):
    """Initialize GoldenShell configuration"""
    config = Config()

    config.set('aws_access_key_id', aws_access_key_id)
    config.set('aws_secret_access_key', aws_secret_access_key)
    config.set('aws_region', aws_region)
    config.set('tailscale_auth_key', tailscale_auth_key)
    config.set('ssh_key_name', ssh_key_name)

    config.save()

    click.echo(click.style('✓ Configuration saved successfully!', fg='green'))
    click.echo(f'Config location: {CONFIG_FILE}')


@cli.command()
def config():
    """View current configuration details"""
    config = Config()

    if not config.config:
        click.echo(click.style('No configuration found. Run "goldenshell init" first.', fg='yellow'))
        return

    click.echo(click.style('Current Configuration:', fg='cyan', bold=True))
    click.echo(config.display())


@cli.command()
@click.option('--instance-type', default='t3.medium', help='EC2 instance type')
def deploy(instance_type):
    """Deploy the AWS development environment"""
    config = Config()

    if not config.config:
        click.echo(click.style('Error: No configuration found. Run "goldenshell init" first.', fg='red'))
        sys.exit(1)

    click.echo(click.style('Deploying GoldenShell environment...', fg='cyan'))

    # Set up Terraform
    tf_dir = Path(__file__).parent / 'terraform'
    tf = Terraform(working_dir=str(tf_dir))

    # Prepare Terraform variables
    tf_vars = {
        'aws_region': config.get('aws_region'),
        'instance_type': instance_type,
        'key_name': config.get('ssh_key_name'),
        'tailscale_auth_key': config.get('tailscale_auth_key'),
    }

    # Set AWS credentials as environment variables
    os.environ['AWS_ACCESS_KEY_ID'] = config.get('aws_access_key_id')
    os.environ['AWS_SECRET_ACCESS_KEY'] = config.get('aws_secret_access_key')
    os.environ['AWS_DEFAULT_REGION'] = config.get('aws_region')

    try:
        # Initialize Terraform
        click.echo('Initializing Terraform...')
        tf.init()

        # Apply Terraform configuration
        click.echo('Creating AWS resources...')
        return_code, stdout, stderr = tf.apply(var=tf_vars, skip_plan=True)

        if return_code != 0:
            click.echo(click.style(f'Error deploying: {stderr}', fg='red'))
            sys.exit(1)

        # Get outputs
        outputs = tf.output(json=True)

        click.echo(click.style('\n✓ Deployment successful!', fg='green', bold=True))
        click.echo(f"\nInstance ID: {outputs.get('instance_id', {}).get('value', 'N/A')}")
        click.echo(f"Public IP: {outputs.get('public_ip', {}).get('value', 'N/A')}")
        click.echo(f"Tailscale IP: Check your Tailscale admin panel")

        # Save deployment info
        config.set('last_deployment', {
            'instance_id': outputs.get('instance_id', {}).get('value'),
            'public_ip': outputs.get('public_ip', {}).get('value'),
        })
        config.save()

    except Exception as e:
        click.echo(click.style(f'Error: {str(e)}', fg='red'))
        sys.exit(1)


@cli.command()
def status():
    """Check instance status and connection details"""
    config = Config()

    deployment = config.get('last_deployment')
    if not deployment:
        click.echo(click.style('No active deployment found.', fg='yellow'))
        return

    instance_id = deployment.get('instance_id')
    if not instance_id:
        click.echo(click.style('No instance ID found.', fg='yellow'))
        return

    # Set AWS credentials
    os.environ['AWS_ACCESS_KEY_ID'] = config.get('aws_access_key_id')
    os.environ['AWS_SECRET_ACCESS_KEY'] = config.get('aws_secret_access_key')

    try:
        ec2 = boto3.client('ec2', region_name=config.get('aws_region'))
        response = ec2.describe_instances(InstanceIds=[instance_id])

        if response['Reservations']:
            instance = response['Reservations'][0]['Instances'][0]
            state = instance['State']['Name']
            state_color = 'green' if state == 'running' else 'yellow' if state == 'stopped' else 'red'

            click.echo(click.style(f'Instance Status:', fg='cyan', bold=True))
            click.echo(f"Instance ID: {instance_id}")
            click.echo(f"State: {click.style(state, fg=state_color)}")
            click.echo(f"Instance Type: {instance.get('InstanceType', 'N/A')}")
            click.echo(f"Public IP: {instance.get('PublicIpAddress', 'N/A')}")

            if state == 'running':
                click.echo(f"\n{click.style('Connection Commands:', fg='cyan')}")
                click.echo(f"  SSH (Tailscale): ssh ubuntu@<tailscale-hostname>")
                click.echo(f"  Mosh (Tailscale): mosh ubuntu@<tailscale-hostname>")
                click.echo(f"  Web Terminal: http://{instance.get('PublicIpAddress', 'N/A')}:7681")
        else:
            click.echo(click.style('Instance not found.', fg='yellow'))

    except Exception as e:
        click.echo(click.style(f'Error: {str(e)}', fg='red'))


@cli.command()
def start():
    """Start the instance"""
    config = Config()

    deployment = config.get('last_deployment')
    if not deployment:
        click.echo(click.style('No active deployment found.', fg='yellow'))
        return

    instance_id = deployment.get('instance_id')
    if not instance_id:
        click.echo(click.style('No instance ID found.', fg='yellow'))
        return

    # Set AWS credentials
    os.environ['AWS_ACCESS_KEY_ID'] = config.get('aws_access_key_id')
    os.environ['AWS_SECRET_ACCESS_KEY'] = config.get('aws_secret_access_key')

    try:
        ec2 = boto3.client('ec2', region_name=config.get('aws_region'))

        # Check current state
        response = ec2.describe_instances(InstanceIds=[instance_id])
        if response['Reservations']:
            state = response['Reservations'][0]['Instances'][0]['State']['Name']

            if state == 'running':
                click.echo(click.style('Instance is already running!', fg='green'))
                return
            elif state == 'pending':
                click.echo(click.style('Instance is already starting...', fg='yellow'))
                return

        click.echo('Starting instance...')
        ec2.start_instances(InstanceIds=[instance_id])

        click.echo(click.style('✓ Instance started successfully!', fg='green'))
        click.echo('\nWait about 1-2 minutes for it to boot, then connect via:')
        click.echo('  ssh ubuntu@<tailscale-hostname>')

    except Exception as e:
        click.echo(click.style(f'Error: {str(e)}', fg='red'))
        sys.exit(1)


@cli.command()
def stop():
    """Stop the instance"""
    config = Config()

    deployment = config.get('last_deployment')
    if not deployment:
        click.echo(click.style('No active deployment found.', fg='yellow'))
        return

    instance_id = deployment.get('instance_id')
    if not instance_id:
        click.echo(click.style('No instance ID found.', fg='yellow'))
        return

    # Set AWS credentials
    os.environ['AWS_ACCESS_KEY_ID'] = config.get('aws_access_key_id')
    os.environ['AWS_SECRET_ACCESS_KEY'] = config.get('aws_secret_access_key')

    try:
        ec2 = boto3.client('ec2', region_name=config.get('aws_region'))

        # Check current state
        response = ec2.describe_instances(InstanceIds=[instance_id])
        if response['Reservations']:
            state = response['Reservations'][0]['Instances'][0]['State']['Name']

            if state == 'stopped':
                click.echo(click.style('Instance is already stopped!', fg='yellow'))
                return
            elif state == 'stopping':
                click.echo(click.style('Instance is already stopping...', fg='yellow'))
                return

        click.echo('Stopping instance...')
        ec2.stop_instances(InstanceIds=[instance_id])

        click.echo(click.style('✓ Instance stopped successfully!', fg='green'))

    except Exception as e:
        click.echo(click.style(f'Error: {str(e)}', fg='red'))
        sys.exit(1)


@cli.command()
@click.option('--tailscale-hostname', help='Tailscale hostname of the instance')
def ssh(tailscale_hostname):
    """SSH into the instance via Tailscale"""
    config = Config()

    if not tailscale_hostname:
        click.echo(click.style('Connection Options:', fg='cyan', bold=True))
        click.echo("\nTo connect via Tailscale:")
        click.echo("  1. Check your Tailscale admin panel for the hostname")
        click.echo("  2. Run: ssh ubuntu@<tailscale-hostname>")
        click.echo("\nTo connect via mosh (survives network drops):")
        click.echo("  mosh ubuntu@<tailscale-hostname>")
        click.echo("\nTo SSH with this command:")
        click.echo("  goldenshell ssh --tailscale-hostname <hostname>")
        return

    # Execute SSH command
    import subprocess
    try:
        subprocess.run(['ssh', f'ubuntu@{tailscale_hostname}'])
    except FileNotFoundError:
        click.echo(click.style('Error: ssh command not found. Please install OpenSSH.', fg='red'))
    except Exception as e:
        click.echo(click.style(f'Error: {str(e)}', fg='red'))


@cli.command()
def resize():
    """Change the instance type (requires instance restart)"""
    config = Config()

    deployment = config.get('last_deployment')
    if not deployment:
        click.echo(click.style('No active deployment found.', fg='yellow'))
        return

    instance_id = deployment.get('instance_id')
    if not instance_id:
        click.echo(click.style('No instance ID found.', fg='yellow'))
        return

    # Set AWS credentials
    os.environ['AWS_ACCESS_KEY_ID'] = config.get('aws_access_key_id')
    os.environ['AWS_SECRET_ACCESS_KEY'] = config.get('aws_secret_access_key')
    os.environ['AWS_DEFAULT_REGION'] = config.get('aws_region')

    try:
        ec2 = boto3.client('ec2', region_name=config.get('aws_region'))

        # Get current instance type
        response = ec2.describe_instances(InstanceIds=[instance_id])
        if response['Reservations']:
            instance = response['Reservations'][0]['Instances'][0]
            current_type = instance.get('InstanceType', 'unknown')
            current_state = instance['State']['Name']

            click.echo(click.style('Instance Resize', fg='cyan', bold=True))
            click.echo(f"\nCurrent instance type: {click.style(current_type, fg='green')}")
            click.echo(f"Current state: {current_state}\n")

            # Instance type options with descriptions
            instance_types = {
                '1': ('t3.micro', '2 vCPU, 1GB RAM - ~$7.50/month'),
                '2': ('t3.small', '2 vCPU, 2GB RAM - ~$15/month'),
                '3': ('t3.medium', '2 vCPU, 4GB RAM - ~$30/month (default)'),
                '4': ('t3.large', '2 vCPU, 8GB RAM - ~$60/month'),
                '5': ('t3.xlarge', '4 vCPU, 16GB RAM - ~$120/month'),
                '6': ('t3.2xlarge', '8 vCPU, 32GB RAM - ~$240/month'),
                '7': ('c6i.large', '2 vCPU, 4GB RAM - Compute optimized ~$60/month'),
                '8': ('c6i.xlarge', '4 vCPU, 8GB RAM - Compute optimized ~$120/month'),
            }

            click.echo(click.style('Available instance types:', fg='cyan'))
            for key, (itype, desc) in instance_types.items():
                marker = '→' if itype == current_type else ' '
                click.echo(f"  {marker} {key}. {itype:15} - {desc}")

            click.echo()
            choice = click.prompt('Select instance type (or press Enter to cancel)',
                                default='', show_default=False)

            if not choice or choice not in instance_types:
                click.echo('Cancelled.')
                return

            new_type = instance_types[choice][0]

            if new_type == current_type:
                click.echo(click.style(f'Instance is already {current_type}', fg='yellow'))
                return

            # Confirm the change
            click.echo(f"\nThis will change instance type from {current_type} to {new_type}")
            if current_state == 'running':
                click.echo(click.style('WARNING: Instance will be stopped and restarted!', fg='yellow'))

            if not click.confirm('Continue?'):
                click.echo('Cancelled.')
                return

            # Stop instance if running
            if current_state == 'running':
                click.echo('\nStopping instance...')
                ec2.stop_instances(InstanceIds=[instance_id])

                # Wait for instance to stop
                waiter = ec2.get_waiter('instance_stopped')
                click.echo('Waiting for instance to stop...')
                waiter.wait(InstanceIds=[instance_id])

            # Modify instance type
            click.echo(f'Changing instance type to {new_type}...')
            ec2.modify_instance_attribute(
                InstanceId=instance_id,
                InstanceType={'Value': new_type}
            )

            # Update Terraform tfvars file
            tf_dir = Path(__file__).parent / 'terraform'
            tfvars_file = tf_dir / 'terraform.tfvars'

            if tfvars_file.exists():
                click.echo('Updating terraform.tfvars...')
                with open(tfvars_file, 'r') as f:
                    content = f.read()

                # Update instance_type line
                import re
                content = re.sub(
                    r'instance_type\s*=\s*"[^"]*"',
                    f'instance_type = "{new_type}"',
                    content
                )

                with open(tfvars_file, 'w') as f:
                    f.write(content)

            click.echo(click.style(f'\n✓ Instance type changed to {new_type}', fg='green'))

            # Ask if user wants to start the instance
            if click.confirm('\nStart the instance now?', default=True):
                click.echo('Starting instance...')
                ec2.start_instances(InstanceIds=[instance_id])
                click.echo(click.style('✓ Instance started!', fg='green'))
                click.echo('Wait 1-2 minutes for it to boot, then connect via SSH.')

    except Exception as e:
        click.echo(click.style(f'Error: {str(e)}', fg='red'))
        sys.exit(1)


@cli.command()
@click.confirmation_option(prompt='Are you sure you want to destroy the environment?')
def destroy():
    """Tear down the AWS environment"""
    config = Config()

    if not config.config:
        click.echo(click.style('Error: No configuration found.', fg='red'))
        sys.exit(1)

    click.echo(click.style('Destroying GoldenShell environment...', fg='cyan'))

    # Set up Terraform
    tf_dir = Path(__file__).parent / 'terraform'
    tf = Terraform(working_dir=str(tf_dir))

    # Set AWS credentials as environment variables
    os.environ['AWS_ACCESS_KEY_ID'] = config.get('aws_access_key_id')
    os.environ['AWS_SECRET_ACCESS_KEY'] = config.get('aws_secret_access_key')
    os.environ['AWS_DEFAULT_REGION'] = config.get('aws_region')

    try:
        return_code, stdout, stderr = tf.destroy(auto_approve=True)

        if return_code != 0:
            click.echo(click.style(f'Error destroying: {stderr}', fg='red'))
            sys.exit(1)

        click.echo(click.style('✓ Environment destroyed successfully!', fg='green'))

        # Clear deployment info
        config.set('last_deployment', None)
        config.save()

    except Exception as e:
        click.echo(click.style(f'Error: {str(e)}', fg='red'))
        sys.exit(1)


if __name__ == '__main__':
    cli()