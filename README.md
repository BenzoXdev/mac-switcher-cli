### Ultimate MAC Switcher CLI

 


---

> Take full control of your network identity in seconds. Whether you're a pentester, privacy advocate, or just curious, MAC Switcher CLI lets you reliably spoof your MAC address on Linux and Windows—with a single intuitive script.



## 🚀 Why MAC Switcher CLI?

Zero configuration: Automatically installs dependencies on first run.

Cross-platform: Works on Linux (ip/ifconfig) and Windows (PowerShell).

Rock-solid reliability: Built-in MAC validation, dry-run mode, error handling, and optional logging.

Professional UX: ASCII banners, interactive spinners, colorful feedback, clipboard support.

One file, all-in-one: Clone it, chmod +x, and go—no config overhead.


# 🌟 Key Features

Feature	Benefit

Auto-install dependencies	No manual setup
Random MAC generator	Generate valid MACs instantly
Dry-Run mode (-d)	Simulate commands without changing anything
JSON output (-j)	Easy integration with scripts/automation
Logging (-l)	Keep track of all MAC address changes
Clipboard copy	New MAC auto-copied to clipboard
Pro Terminal UI	ASCII banners + spinners = great UX


# 🎯 Installation & Quick Start

## Linux

1. Clone the repo

```
git clone https://github.com/BenzoXdev/mac-switcher-cli.git
cd mac-switcher-cli
```

2. Make the script executable

```
chmod +x mac-switcher.js
```

3. Run it

```
sudo ./mac-switcher.js [options]
```


## Windows (PowerShell as Administrator)

1. Clone the repo

```
git clone https://github.com/BenzoXdev/mac-switcher-cli.git
cd mac-switcher-cli
```

2. Install required modules

```
npm install
```

3. Run it

```
.\\mac-switcher.js [options]
```


> 🔐 Tip: Always run as administrator (Windows) or with sudo (Linux) for full access.



### ⚙️ Usage Examples

Prompted interface selection + custom MAC
```

sudo ./mac-switcher.js

Generate & apply random MAC

sudo ./mac-switcher.js -g -l

Dry-Run mode

./mac-switcher.js -d

JSON output example

sudo ./mac-switcher.js -j -g

{
  "oldMac": "aa:bb:cc:dd:ee:ff",
  "newMac": "12:34:56:78:9a:bc"
}

```
🛡 License

Distributed under the MIT License. See LICENSE for details.


---

Protect your network identity—start spoofing your MAC address safely and professionally!
