# GIBedrock

**GIBedrock** is **Gaming Innovators’ official modular framework** for developing secure, compliant, and scalable casino games using the [Godot Engine](https://godotengine.org/). It is designed for full GLI certification and includes built-in modules for:

- 🔐 Encrypted data persistence (AES-256)
- 📋 Secure audit logs (CSV, JSON, XML)
- 🎰 Native RNG integration (GLI-19 Compliant)
- 🧩 Modular architecture (Autoload, DI-ready)
- 🛡️ SHA-256 signature validation for all critical files
- 🧾 OTP support, metadata, receipts, export system
- 🎮 Seamless integration for VLTs, slots, and roulette games

---

## 🎮 How to Use GIBedrock as a Git Submodule in Your Godot Project

This section explains how to securely embed **GIBedrock** as a submodule within your own game repository, ensuring consistent file paths, centralized updates, and compliance integrity.

---

## 📦 Cloning a Project with GIBedrock Already Configured

If you are cloning a project that **already includes GIBedrock** as a submodule, simply use:

```bash
git clone --recurse-submodules https://github.com/YOUR_ORG/YOUR_GAME_PROJECT.git

# 🛠️ Adding GIBedrock Manually as a Submodule

To manually add the **GIBedrock framework** into an existing Godot project, follow these steps:

### 1. Open your project root directory:

```bash
cd your-game-project/
```

### 2. Add GIBedrock as a submodule under the recommended path (`scripts/core/gibedrock`):

```bash
git submodule add https://github.com/GamingInnovators/gibedrock.git scripts/core/gibedrock
```

### 3. Initialize and sync the submodule:

```bash
git submodule update --init --recursive
```

### 4. Commit the changes:

```bash
git commit -am "🔗 Added GIBedrock as a secure submodule dependency"
```

---

## 🧱 Recommended Directory Structure

```
your-game-project/
├── project.godot
├── scripts/
│   └── core/
│       └── gibedrock/
│           ├── autoloads/
│           ├── utils/
│           ├── modules/
│           └── ...
```

---

## 🔄 Updating GIBedrock Manually

To update your local copy of GIBedrock with the latest changes from the upstream repository:

```bash
cd scripts/core/gibedrock
git pull origin main
cd ../../..
git add scripts/core/gibedrock
git commit -m "⬆️ Updated GIBedrock to latest version"
```

---

## 🔐 Using GIBedrock as a Private Submodule (Advanced)

If you need GIBedrock to remain private, you have two secure options:

- **GitHub Deploy Keys** (recommended for read-only CI/CD access)
- **GitHub Personal Access Token (PAT)**

We recommend using **SSH-based deploy keys** for enhanced security in CI/CD pipelines.

📖 GitHub reference:  
[Using Git submodules securely](https://docs.github.com/en/get-started/using-git/using-submodules-in-git#cloning-a-project-with-submodules)

---

## ⚙️ Example Autoload Configuration (`project.godot`)

To enable GIBedrock core systems as singletons, add these entries to your `project.godot`:

```ini
[autoload]
AuditLogManager="*res://scripts/core/gibedrock/autoloads/audit_log_manager.gd"
SettingsManager="*res://scripts/core/gibedrock/autoloads/settings_manager.gd"
SystemBootstrap="*res://scripts/core/gibedrock/autoloads/system_bootstrap_manager.gd"
OtpManager="*res://scripts/core/gibedrock/autoloads/otp_manager.gd"
```

> These autoloads follow a strict initialization order to ensure integrity and full compliance.

---

## 🧪 Validating GIBedrock in Your Project

After integration, run your project with:

```bash
godot4 --path .
```

You can now safely interact with GIBedrock like so:

```gdscript
SettingsManager.get_setting("rng_state_file")
AuditLogManager.append_entry("🎯 Test passed")
```

---

## ✅ License & Compliance

GIBedrock is developed and maintained by [Gaming Innovators](https://github.com/GamingInnovators).

It is intended for **commercial use in regulated markets** and adheres to:

- [GLI-19](https://gaminglabs.com/gli-standards)
- [GLI-11](https://gaminglabs.com/gli-standards)
- [GLI-33](https://gaminglabs.com/gli-standards)

For business inquiries, licensing or security audits, contact:

📧 `legal@gaminginnovators.com`

---

## 📎 Summary

| Feature                   | Description                                           |
|--------------------------|-------------------------------------------------------|
| 🔐 Secure by Design       | SHA-256, AES-256, signature + validation built-in     |
| 🧩 Modular & Scalable     | Use in any Godot project without path conflicts        |
| 🔁 Easily Updateable      | Pull upstream updates with one command                |
| 🔧 GLI-Ready Autoloads    | Bootstrap, Logging, Configuration, OTP support        |
| 🛠️ Compatible with CI/CD  | Designed for automation pipelines and secure builds    |

---

## 🔒 Integrity & Distribution (Advanced)

To ensure that GIBedrock is not tampered with in cloned or distributed environments:

### 🔍 1. Verifying SHA-256 of `GIBedrock` Directory

From the root of your project:

```bash
sha256sum -b $(find scripts/core/gibedrock -type f | sort) > gibedrock_checksum.sha256
```

Compare this against the original `.sha256` file (if provided) or regenerate it in your CI/CD pipeline.

### 📦 2. Distributing as an Internal Tarball

For organizations with limited internet access:

```bash
tar -czf gibedrock_package.tar.gz scripts/core/gibedrock
```

Then extract it manually on the target project:

```bash
tar -xzf gibedrock_package.tar.gz -C scripts/core/
```

---

## 📌 Best Practices

- Never **edit GIBedrock** files directly inside your project.  
  Instead, extend or override via your own modules.
- Keep submodules **up-to-date** regularly.
- Use **audit logs** and **signatures** in all critical paths.

---

## 🧰 Need Support?

- 📖 [Godot Engine Documentation](https://docs.godotengine.org/)
- 💼 [Gaming Innovators GitHub](https://github.com/GamingInnovators)
- 📬 Email support: `support@gaminginnovators.com`

---

## 🧠 Future Improvements (Planned)

- Remote OTA module sync
- Built-in licensing system
- Plugin generator for slot and VLT variants
- Support for GLI-21 and emerging jurisdictions

---

> _This documentation is automatically verified and signed as part of the GI pipeline using SHA-256 and XSD schemas._  
> Last updated: `{{YYYY-MM-DD}}` – Maintainer: `Gaming Innovators`

