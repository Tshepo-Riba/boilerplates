# Ansible Installation

## Update Repositories
First, update the package repositories on your system:

```bash
sudo apt update
```

## Install Dependencies
Install software-properties-common, which allows you to manage the software repositories:

```bash
sudo apt install software-properties-common
```

## Add Ansible Repository
Add the Ansible PPA (Personal Package Archive) to your system's repositories:

```bash
sudo add-apt-repository --yes --update ppa:ansible/ansible
```
## Install Ansible
Finally, install Ansible using the following command:

```bash
sudo apt install ansible
```

## Verification
To verify that Ansible has been installed correctly, you can check its version:

```bash
ansible --version
```

This should display the installed version of Ansible along with some additional information.

## Configuration
After installation, you may need to configure Ansible according to your requirements. Refer to the [Ansible Documentation](https://docs.ansible.com/)
 for more information on how to configure and use Ansible effectively.
