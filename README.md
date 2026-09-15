# akira-packages

This repository contains the independent source packages collection to build binary packages for the **Akira Linux** distribution, utilizing the `xbps-src` build system.

## 🚀 Quick Start

### 1. Requirements

Before building, ensure your system has the following core tools installed:

- GNU bash
- git
- curl
- core POSIX utilities

### 2. Initialize the Bootstrap Environment

To set up the initial build container using pre-existing binary packages, run:

```bash
./xbps-src binary-bootstrap
```

### 3. Build a Package

To build a package, specify the `pkg` target along with the package name:

```bash
./xbps-src pkg <package_name>
```

Once the compilation finishes, generated binary packages will be stored locally in `hostdir/binpkgs`.

### 4. Install Your Package

You can install the compiled package directly using `xbps-install`:

```bash
xbps-install --repository hostdir/binpkgs <package_name>
```

---

## 📂 Directory Hierarchy

- `common/` - Shared build profiles, configurations, and core scripts.
- `etc/` - Configuration files (e.g., `etc/conf` for local overrides).
- `srcpkgs/` - The core directory where all package templates and build instructions reside.
- `hostdir/` - Contains downloaded sources, caches (`ccache`), and final binary packages (`binpkgs`).

---

## 🛠 Configuration Overrides

If you need to enable restricted packages or customize compilation flags (`CFLAGS`, `LDFLAGS`), avoid editing `etc/defaults.conf`. Instead, append your settings directly to `etc/conf`:

```bash
# Allow building restricted packages
echo "XBPS_ALLOW_RESTRICTED=yes" >> etc/conf

# Example: Custom optimization flags
echo 'XBPS_CFLAGS="-O2 -pipe"' >> etc/conf
```

## 📜 License

This project is distributed under the same licensing terms as the original ports collection. See the `COPYING` file for detailed information.
