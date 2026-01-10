---
description: This workflow enables full remote control of development on the Arkham host.
---

# Remote Development on Arkham

This workflow transitions all development operations (git, docker, minikube, build, deploy) from the local Samba-mounted environment to the native Arkham host via SSH.

## Setup

To use this workflow, ensure that SSH access to `arkham` is configured. Note: We use `-o ControlMaster=no -o ControlPath=none` to avoid Windows-specific SSH socket issues.

### 1. Verify Remote Connection

// turbo
Check if Arkham is reachable:

```powershell
ssh -o ControlMaster=no -o ControlPath=none arkham "hostname && pwd"
```

## Git Operations

Always run git on the remote host to avoid Samba overhead.
// turbo

```powershell
ssh -o ControlMaster=no -o ControlPath=none arkham "cd ~/personal/projects/wordwank && git status"
```

## Docker & Minikube

Execute all container commands remotely.
// turbo

```powershell
ssh -o ControlMaster=no -o ControlPath=none arkham "docker ps"
ssh -o ControlMaster=no -o ControlPath=none arkham "minikube status"
```

## Building and Deploying

Use the remote Makefile.
// turbo

```powershell
ssh -o ControlMaster=no -o ControlPath=none arkham "cd ~/personal/projects/wordwank && make build"
ssh -o ControlMaster=no -o ControlPath=none arkham "cd ~/personal/projects/wordwank && make deploy"
```

## Running the Backend (Perl/Mojolicious)

// turbo

```powershell
ssh -o ControlMaster=no -o ControlPath=none arkham "cd ~/personal/projects/wordwank/srv/backend && ./script/wordwank daemon"
```
