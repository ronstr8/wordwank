# wordwank 💥

A fast-paced word game with familiar roots. You can call it any variation of wordw*nk and it will still be wordwank. Even wordsplat. And go ahead and register those domains, you disgusting pathetic people who squat on the piles of others.

Wordwank is a polyglot microservices platform built as an exercise in modern developer environment practices, distributed systems, and agentic coding. It combines Perl, Rust, and Nginx into a seamless, high-performance game universe.

> [!NOTE]
> The latest development version of the game is running at [wordwank.fazigu.org](https://wordwank.fazigu.org). It is sometimes stable, sometimes crashing into the abyss, and often filled with extra annoying bugs. You have been warned.

*Yes, AI wrote a lot of this, and I like that--even emojis and em-dashes. I'm writing these words here, and tweak the code as necessary, but with Antigravity, it's like I have several different coworkers to call upon to get the project done. It's a massive leap forward for productivity. Every hacker is now his own team.*

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

Alternatively, minikube is available as a snap package, but you're likely better off just blindly running that binary you curled above.

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

*I've always struggled to get Ingress just right to better mirror production on my development environment. MetalLB and a little `socat` tunnel to the Ingress controller were the missing pieces.*

### 3. Build & Deploy

This will build all polyglot services, push them to the local Minikube registry, and deploy the umbrella Helm chart:

```bash
make build && make deploy && watch kubectl -n wordwank get pods
```

### 4. Expose to the Outer World

To access the game from another machine on your home network:

1. **Update Hosts**: On your client machine, add an entry for the host name you've configured in `values.yaml`, so replace the hostname call below if necessary:

```bash
echo "$( minikube ip ) $( hostname )" | sudo tee -a /etc/hosts
```

2.**Start the Bridge**: In a separate terminal/tab (as this needs to stay open for as long as you want to access the game), run the following to proxy HTTP (port 80) and HTTPS (port 443) traffic to the Ingress:

```bash
make expose
```

### 5. Setup SSL Certificates (Optional but Recommended)

Install cert-manager and configure Let's Encrypt for automatic SSL certificates:

**Important**: First edit `helm/resources/letsencrypt-issuer.yaml` and replace the email addresses with your actual email. This email will be used for Let's Encrypt certificate expiry notifications. You can use `make cert-manager-setup` to do this automatically.

```bash
make cert-manager-setup
```

This will install cert-manager and apply a NAT workaround (hostAliases patch) that allows cert-manager to perform self-checks in your local Minikube environment. The certificate should be issued within 1-2 minutes.

*Note: The setup uses Let's Encrypt production by default. Your domain must be publicly accessible on port 80 for HTTP-01 validation to succeed.*

### 6. PLAYTIME

Navigate to `https://wordwank.fazigu.org` (or `http://` if you skipped SSL setup) to begin.

*My heathen prayers reach out to you, hoping that it works the first time. It took me so long to get comfortable with hooking my development environment up to the outside world in a way that didn't seem hacky and better mirrored the production environment, but I think this finally gets it right. Over the five years at my last job, nobody there seemed to care or wanted to brainstorm/troubleshoot the issue. I wish I'd had Antigravity back then.*

---

## 📐 Architecture

- **frontend**: React-based UI (Vite/Nginx).
- **backend**: Perl (Mojolicious) service handling authentication, API, and WebSocket.
- **wordd**: Rust-based high-speed word validator.
- **dictd**: Dictionary definition service.

---
*Created by Ron "Quinn" Straight and Antigravity using a variety of models.*
