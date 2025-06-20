# 🚀 WordPress Auto Installer (One-Command Setup)

This script allows you to set up a fresh WordPress installation in your domain directory with just **one command**. It automatically clones a boilerplate, downloads WordPress, sets up configuration, installs plugins (like **UpdraftPlus**), and activates your custom theme.

---

## 🧩 What You Need

- A domain folder on your server (e.g. `/var/www/vhosts/your-domain.com/`)
- PHP with CLI access
- MySQL/MariaDB database (already created)
- SSH access to the domain folder

---

## 🛠️ How to Use

1. **Upload only the `install.sh` file** to your domain path (where WordPress should be installed).

2. **Open the SSH terminal**, and go into your domain directory:

```bash
cd /var/www/vhosts/your-domain.com/
````

3. **Run the install script**:

```bash
bash install.sh
```

4. The script will:

   * Clone the WordPress boilerplate

   * Download and configure WordPress

   * Ask you required setup questions (DB, site title, URL, admin info)

   * Automatically install and activate the following plugins:

     * Contact Form 7
     * WK Google Analytics
     * Cookie Law Info
     * **UpdraftPlus** (for backups)

   * Set up your custom theme

   * Remove sample content, unused themes, and cache

   * Apply clean permalink and comment settings

---

## ⚙️ Features

* ✅ Fully interactive prompts
* ✅ Keeps everything inside your domain folder
* ✅ No zip or manual copying needed
* ✅ Deletes temporary `.wp-cli-cache` automatically
* 🔐 Production-ready setup with backups and basic hardening

---

## 🧼 After Setup

You’ll see a summary like:

```bash
✅ WordPress installation complete!
🌐 Site URL: https://yourdomain.com
👤 Admin Username: admin
🔐 Admin Password: ***********
```

Then visit `https://yourdomain.com/wp-admin` and log in.

---
