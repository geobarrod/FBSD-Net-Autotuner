# FreeBSD Network Autotuner

## Purpose
Dynamically adjusts the TCP stack, congestion control algorithm, buffers, and queues based on real-time network metrics such as latency, packet loss, jitter, throughput, kernel drops, and out-of-order segments.  
It is designed to optimize FreeBSD networking performance in diverse and changing conditions.

---

## Usage
```sh
sudo fbsd-net-autotuner [-d] [-l]
```

## Options
- `-d` → Add date and time to the event log.  
- `-l` → Log events to the file `/var/log/fbsd-net-autotuner.log`.

---

## Configuration Variables
You can override these defaults by exporting environment variables before running the script:

| Variable       | Default   | Description                          |
|----------------|-----------|--------------------------------------|
| `TARGET_HOST`  | `8.8.8.8` | Host used for ping measurements      |
| `IFACE`        | `wlan0`   | Network interface to monitor         |
| `PING_COUNT`   | `10`      | Number of pings per round            |
| `INTERVAL_SEC` | `60`      | Interval between measurements (sec)  |

---

## Features
- Classifies network conditions into tiers: **very_slow, slow, medium, fast, very_fast**.
- Dynamically selects TCP congestion control algorithm and stack:
  - Algorithms: `cubic`, `chd`, `htcp`, `dctcp`, `cdg`, `vegas`
  - Stacks: `freebsd`, `bbr`, `rack`
- Adjusts:
  - Buffer sizes (recv/send, maxsockbuf)
  - ECN (Explicit Congestion Notification)
  - Keepalive
  - Delayed ACK (tier-based and jitter override)
  - SACK (Selective ACK)
  - Initial congestion window (`initcwnd_segments`)
  - TSO (toggle based on kernel drops)
  - ABC (`net.inet.tcp.abc_l_var`) → controls cwnd growth aggressiveness
  - Reassembly Queue (`net.inet.tcp.reass.maxqueuelen`) → adapts to out-of-order segments
- Monitors:
  - RTT (latency)
  - Packet loss
  - Jitter
  - Throughput
  - Kernel intr_queue_drops
  - Out-of-order segments
- Applies changes immediately via `sysctl` and persists them in `/etc/sysctl.conf`.
- Flexible logging:
  - Terminal only
  - Terminal + date
  - File logging

---

## Network Tier Classification
The script evaluates **RTT (latency)**, **packet loss**, **throughput**, and also **jitter/out-of-order** to classify the connection:

| Tier        | Conditions (examples)                                   | Behavior                        |
|-------------|---------------------------------------------------------|---------------------------------|
| very_slow   | RTT ≥ 250ms or loss ≥ 5%                                | Conservative buffers, Vegas/CHD |
| slow        | RTT ≥ 150ms or loss ≥ 2% or throughput < 2 Mbps         | Larger buffers, Vegas/HTCP      |
| medium      | RTT ≥ 80ms or throughput < 20 Mbps                      | Balanced buffers, HTCP/Cubic    |
| fast        | RTT ≥ 30ms or throughput < 200 Mbps                     | Aggressive buffers, DCTCP/HTCP  |
| very_fast   | RTT < 30ms and throughput ≥ 1 Gbps                      | Maximum buffers, BBR/RACK       |

---

## Requirements
- FreeBSD system with root privileges.
- Utilities: `sysctl`, `ping`, `netstat`.

---

## Notes
- The script runs in an infinite loop. Stop it with `Ctrl+C`.  
- Ensure `/etc/sysctl.conf` is writable for persistence.  
- `delayed_ack` tier setting may be overridden by jitter detection.  
- `abc_l_var` and `reass.maxqueuelen` are tuned dynamically based on stability and out-of-order metrics.

---

## Example
Run with logging to file and timestamps:
```sh
sudo fbsd-net-autotuner -d -l
```

---

## Installation
Clone the repository and run the installer:
```sh
git clone https://github.com/geobarrod/FBSD-Net-Autotuner.git
cd fbsd-net-autotuner
sudo make install
```

---

## Uninstallation
To remove the fbsd-net-autotuner and service:
```sh
cd fbsd-net-autotuner
sudo make uninstall
```

---

## Changelog

### v1.0 — 2025-12-05
- Initial release of **FreeBSD Network Autotuner**.
- Features:
  - Dynamic classification of network tiers (very_slow, slow, medium, fast, very_fast).
  - Automatic selection of TCP congestion control algorithms (`cubic`, `chd`, `htcp`, `dctcp`, `cdg`, `vegas`).
  - Dynamic stack selection (`freebsd`, `bbr`, `rack`).
  - Buffer tuning based on throughput and RTT.
  - ECN, keepalive, delayed ACK, and SACK adjustments.
  - Initial congestion window (`initcwnd_segments`) tuning.
  - TSO toggle based on kernel intr_queue_drops.
  - Logging options: terminal, terminal+date, file logging.
- Persistence of sysctl changes in `/etc/sysctl.conf`.

---

### v1.1 — 2025-12-10
- Added **BDP estimation** and buffer tuning based on Bandwidth-Delay Product.
- Improved dynamic IW tuning with jitter and packet loss conditions.
- Enhanced intr_queue_maxlen adjustment when drops are detected.
- Extended logging to include BDP values.

---

### v1.2 — 2025-12-15
- Added **jitter measurement** via ping statistics.
- Integrated jitter-based override for `delayed_ack`.
- Improved logging clarity for jitter-based adjustments.

---

### v1.3 — 2025-12-20
- Added **out-of-order segment measurement** using `netstat -s`.
- Introduced dynamic tuning for:
  - `net.inet.tcp.abc_l_var` (Appropriate Byte Counting).
  - `net.inet.tcp.reass.maxqueuelen` (TCP reassembly queue length).
- Extended log output to include out-of-order metrics.
- Documented override behavior for `delayed_ack` when jitter is high.

---

### v1.4 — 2025-12-25
- Refactored `loss_pct` extraction to use `sed` (simpler and more robust).
- Suggested alternative with `awk` regex for portability.
- Improved `set_sysctl_if_needed` to ensure persistence and added recommendation for explicit logging of applied changes.
- Updated README.md:
  - Added ABC and reassembly queue features.
  - Documented out-of-order monitoring.
  - Clarified notes on jitter overrides and dynamic tuning.
