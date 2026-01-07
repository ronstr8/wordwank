# wordwank 💥

A word-game engine for the eldritch age, designed for Kubernetes.

> "In the beginning, there was the Word. Toward the end, we recreated @tilemasters from LambdaMOO."

Wordwank is a polyglot microservices platform built as an exercise in modern design and distributed systems. It combines Go, Rust, Java, and Nginx into a seamless, high-performance game universe.

---

## 🛠 Prerequisites

Before embarking on your descent into the word-void, ensure your host (e.g., Ubuntu) has the following tools installed:

- **Docker**: For building and running containers.
- **Minikube**: Our local Kubernetes sanctuary.
- **kubectl**: The command-line interface for our cluster.
- **Helm**: To manage our eldritch charts.
- **socat**: Required for bridging the cluster to your local network.

### Quick Install (Ubuntu/Debian)

```bash
# Install core tools
sudo apt update
sudo apt install -y docker.io kubectl helm socat

# Install Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

---

## 🚀 Getting Started

### 1. Initialize the Universe

Start Minikube and prepare the base addons (Registry, Ingress, and MetalLB):

```bash
minikube start --driver=docker --cpus 4 --memory 8192
make minikube-setup
```

### 2. Configure Networking

MetalLB needs a pool of IPs to hand out to our services. Our Makefile automates this by detecting your Minikube network:

```bash
# Install the MetalLB manifests
make metallb-install

# Configure the IP pool
make metallb-config
```

### 3. Build & Deploy

This will build all polyglot services, push them to the local Minikube registry, and deploy the umbrella Helm chart:

```bash
make build
make deploy
```

### 4. Expose to the Outer World

To access the game from another machine (like your Necronomicon laptop) on your home network:

1. **Start the Bridge**: Run this on your server (e.g., Arkham) to proxy traffic from port 80 to the Ingress:

    ```bash
    make expose
    ```

2. **Update Hosts**: On your client machine, map the hostname to your server's IP:

    ```text
    # In /etc/hosts or C:\Windows\System32\drivers\etc\hosts
    192.168.1.<ARKHAM_IP> arkham.fazigu.org
    ```

Navigate to `http://arkham.fazigu.org` to begin.

---

## 📐 Architecture

- **frontend**: React-based UI (Vite/Nginx).
- **gatewayd**: Go-based WebSocket hub for real-time play.
- **tilemasters**: Go-based game engine & scoring rules.
- **playerd**: Java/Spring Boot service for persistent stats (Redis).
- **wordd**: Rust-based high-speed word validator.
- **dictd**: Dictionary definition service.

---
*Created by Quinn. Boilerplated with love by Antigravity.*
