# akira-packages

Custom package repository for **Akira Linux** — a curated collection of hand-crafted `.xbps` source packages, delivering independent software configurations for your environment.

---

## ⚙️ Automation & CI/CD (GitOps)

This repository is designed to be powered by a fully automated GitOps pipeline to ensure stability and rapid software delivery:

- **Auto-Updates:** A dedicated automation bot monitors official upstream APIs. When a new version is released, it automatically updates the package templates, verifies checksums, and opens a Pull Request.
- **Continuous Integration (CI):** Every incoming template change is automatically verified on our build farm using GitHub Actions. We never merge packages that fail compilation.
- **Continuous Deployment (CD):** Once a Pull Request is merged, packages are automatically compiled, cryptographically signed, and deployed to the production VPS repository.

---

## 🚀 How to Use This Repository

### Method 1: Install Pre-built Binaries (Recommended)

You can connect the official Akira Linux remote repository directly to your target machine to install pre-compiled packages:

```bash
# Add the Akira Linux repository configuration
echo "repository=https://repo.akiralinux.org/current" | sudo tee /etc/xbps.d/akira.conf
# When prompted to import the public key, answer: Y

# Synchronize repositories and install any package
sudo xbps-install -S
sudo xbps-install <package-name>
```

### Method 2: Build Manually via xbps-src

If you prefer to compile packages locally a build machine:

1. **Initialize the Bootstrap Environment:**
    ```bash
    ./xbps-src binary-bootstrap
    ```
2. **Compile a Package:**
    ```bash
    ./xbps-src pkg <package_name>
    ```
3. **Install the Locally Generated Package:**
    ```bash
    xbps-install --repository hostdir/binpkgs <package_name>
    ```

---

## 📂 Directory Hierarchy

- `common/` — Shared build profiles, cross-compilation architectures, and core components.
- `etc/` — Local configuration overrides (e.g., `etc/conf`).
- `srcpkgs/` — The core directory containing standalone package build templates.
- `hostdir/` — Local directory for storage, cache compilation (`ccache`), and output binary packages.

---

## 🌐 Community & Connections

- 💬 **Telegram Chat** — Join us for development, support, and contribution discussions.
- 📢 **@akiralinux** — Official updates, distribution news, and repository announcements.

---

## 📜 License

This ports collection is distributed under the independent open-source terms specified in the `COPYING` file.
