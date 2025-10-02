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
    """Check if environment is running"""
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

            click.echo(click.style(f'Instance Status:', fg='cyan', bold=True))
            click.echo(f"Instance ID: {instance_id}")
            click.echo(f"State: {state}")
            click.echo(f"Public IP: {instance.get('PublicIpAddress', 'N/A')}")
        else:
            click.echo(click.style('Instance not found.', fg='yellow'))

    except Exception as e:
        click.echo(click.style(f'Error: {str(e)}', fg='red'))


@cli.command()
def connect():
    """Get connection details for the environment"""
    config = Config()

    deployment = config.get('last_deployment')
    if not deployment:
        click.echo(click.style('No active deployment found.', fg='yellow'))
        return

    click.echo(click.style('Connection Details:', fg='cyan', bold=True))
    click.echo(f"\nSSH (via public IP):")
    click.echo(f"  ssh ubuntu@{deployment.get('public_ip')}")
    click.echo(f"\nSSH (via Tailscale):")
    click.echo(f"  Check your Tailscale admin panel for the hostname")
    click.echo(f"  ssh ubuntu@<tailscale-hostname>")


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