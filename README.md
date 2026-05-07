# FreeBSD Network Autotuner

## Purpose
The Network Autotuner was conceived as a mechanism for dynamic adjustment of kernel networking parameters in real time, particularly under high network load conditions where static sysctl values are insufficient.

- Monitor live network metrics: latency (RTT), packet loss, jitter, throughput, interrupt queue drops, out‑of‑order segments, FIN‑WAIT states, NIC speed.
- Apply immediate and persistent changes to kernel variables (sysctl, loader.conf) to optimize performance.
- Automatically adapt to changing traffic conditions without manual intervention, ensuring stability and efficient bandwidth utilization.

Key components:
  - Dynamic TCP stack selection:
    - FreeBSD -> default stack, robust under normal conditions.
    - BBR -> optimized for high capacity and low latency.
    - RACK -> effective in networks with reordering or packet loss.
  - Congestion control algorithms available:
    - Cubic -> modern standard, balanced performance.
    - CHD / HD -> resilient under moderate loss.
    - HTCP -> suited for high‑capacity, long‑RTT links.
    - DCTCP -> efficient in ECN‑enabled environments.
    - CDG -> designed for high jitter scenarios.
    - Vegas -> excellent for low latency and zero loss.
  - Dynamic buffer and queue tuning:
    - Adjusts recvspace, sendspace, recvbuf_max, sendbuf_max based on BDP (Bandwidth‑Delay Product).
    - Adapts intr_queue_maxlen when drops are detected.
    - Tunes initcwnd_segments according to link stability.
    - Enables/disables TSO, SACK, delayed ACK, keepalive depending on jitter and loss.

The Network Autotuner is an adaptive system that:
  - Continuously observes real‑time network conditions.
  - Selects the most appropriate TCP stack and congestion control algorithm.
  - Adjusts buffers, queues, and critical kernel parameters to maintain optimal performance under heavy load.

Essentially, it acts as an automatic orchestrator of tunables, ensuring the system remains efficient and stable even in adverse traffic scenarios.

---

## Usage
```sh
sudo fbsd-net-autotuner [-d] [-l] [-n]
```

## Options
- `-d` → Add date and time to the event log.
- `-l` → Log events to the file `/var/log/fbsd-net-autotuner.log`.
- `-n` → Simulation mode active (dry-run): no changes applied, only logged.

---

## Configuration Variables
You can override these defaults by exporting environment variables before running the script:

| Variable       | Default | Description                                                                                                                                    |
|----------------|---------|------------------------------------------------------------------------------------------------------------------------------------------------|
| `TARGET_HOST`  | auto    | Host used for ping measurements. Selected dynamically from public resolvers (1.1.1.1, 1.0.0.1, 8.8.8.8, 8.8.4.4, 9.9.9.9) based on lowest RTT. |
| `IFACE`        | auto    | Network interface to monitor. Auto-detected from default route or falls back to the first interface.                                           |
| `PING_COUNT`   | 10      | Number of pings per round                                                                                                                      |
| `INTERVAL_SEC` | 60      | Interval between measurements (sec)                                                                                                            |

---

## Features
- Auto-selects the most responsive `TARGET_HOST` from a resilient list of public resolvers.  
- Detects NIC speed robustly (validates numeric values, defaults to 1000 Mbps).  
- Classifies network conditions into tiers: `very_slow`, `slow`, `medium`, `fast`, `very_fast`.  
- Dynamically selects TCP congestion control algorithm and stack:
  - Algorithms: `cubic`, `chd`, `htcp`, `dctcp`, `cdg`, `vegas`.
  - Stacks: `freebsd`, `bbr`, `rack`.
- Adjusts:
  - Buffer sizes (recv/send, `maxsockbuf`).
  - ECN (Explicit Congestion Notification).
  - Keepalive.
  - Delayed ACK (tier-based with jitter override).
  - SACK (Selective ACK).
  - Initial congestion window (`initcwnd_segments`).
  - TSO (toggle based on kernel drops).
  - ABC (`net.inet.tcp.abc_l_var`) → controls cwnd growth aggressiveness.
  - Reassembly queue (`net.inet.tcp.reass.maxqueuelen`) → adapts to out-of-order segments.
  - Enables `net.inet.tcp.fast_finwait2_recycle` only if FIN-WAIT-2 exceeds 5% of ESTABLISHED.
- Monitors:
  - RTT (latency).
  - Packet loss.
  - Jitter.
  - Throughput.
  - Kernel `intr_queue_drops`.
  - Out-of-order segments.
  - FIN-WAIT-1 sockets (diagnostic only, logged).
  - FIN-WAIT-2 sockets (dynamic tuning).
- Tunes mbuf clusters and jumbo buffers based on NIC speed (1G, 10G, 40G).
- Tunes UDP receive buffer size based on NIC speed.
- Applies changes immediately via `sysctl` and persists them in `/etc/sysctl.conf`.
- Configures ISR tunables (`maxthreads`, `bindthreads`, `defaultqlimit`, `maxqlimit`) via `/boot/loader.conf` (requires reboot).
- Adds automatic comments with timestamp in `/etc/sysctl.conf` and `/boot/loader.conf` to mark lines generated by the autotuner for traceability.
- Flexible logging:
  - Terminal only.
  - Terminal + date.
  - File logging.
- Automatic backup creation for **/etc/sysctl.conf** and **/boot/loader.conf** for safe rollback.
- Simulation mode active (dry-run): no changes applied, only logged.

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
- Reboot required for loader.conf tunables (`net.isr.*`).

---

## Monitored Metrics
The net-autotuner continuously measures and logs the following metrics to guide dynamic tuning decisions:

| Metric            | Source/Method                          | Purpose / Usage                                                                 |
|-------------------|----------------------------------------|---------------------------------------------------------------------------------|
| RTT (latency)     | `ping` statistics                      | Classify network tier (very_slow → very_fast).                                  |
| Packet loss       | `ping` statistics                      | Detect unstable links, adjust buffers and congestion control.                   |
| Jitter            | Min/Max RTT difference                 | Override delayed ACK when jitter is high.                                       |
| Throughput        | `netstat -I <iface>` bytes per second  | Classify tier, estimate Bandwidth-Delay Product (BDP).                          |
| Intr queue drops  | `sysctl net.inet.ip.intr_queue_drops`  | Increase `intr_queue_maxlen`, toggle TSO if persistent.                         |
| Out-of-order segs | `netstat -s`                           | Adjust TCP reassembly queue length (`reass.maxqueuelen`).                       |
| FIN-WAIT-1 conns  | `netstat -an | grep FIN_WAIT_1`        | Logged for diagnostic visibility (no dynamic tuning applied).                   |
| FIN-WAIT-2 conns  | `netstat -an | grep FIN_WAIT_2`        | Dynamically tuned via `net.inet.tcp.fast_finwait2_recycle` (threshold >5%).     |
| ESTABLISHED conns | `netstat -an | grep ESTABLISHED`       | Used as baseline for FIN-WAIT-2 ratio calculation.                              |

---

## Notes
- The script runs in an infinite loop. Stop it with `Ctrl+C`.
- Ensure `/etc/sysctl.conf` and `/boot/loader.conf` is writable for persistence.
- Ensure that the congestion control algorithms (cubic, chd, htcp, dctcp, cdg, vegas) can load.
- Ensure that the TCP stacks (freebsd, bbr, rack) can load.
- `delayed_ack` tier setting may be overridden by jitter detection.
- `abc_l_var` and `reass.maxqueuelen` are tuned dynamically based on stability and out-of-order metrics.
- **FIN-WAIT-1**: monitored only, useful for diagnostics, no sysctl tuning available.  
- **FIN-WAIT-2**: dynamically managed; `fast_finwait2_recycle` enabled only if >5% of ESTABLISHED.  
- All metrics are logged in extended output for traceability and performance analysis.

---

## Example
Simulation mode active (dry-run): no changes applied, only logged:
```sh
sudo fbsd-net-autotuner -n
```

Run with logging to file and timestamps:
```sh
sudo fbsd-net-autotuner -d -l
```

---

## Installation
Clone the repository and run the installer:
```sh
git clone https://github.com/geobarrod/FBSD-Net-Autotuner.git
cd FBSD-Net-Autotuner
sudo make install
```

---

## Uninstallation
To remove the fbsd-net-autotuner and service:
```sh
cd FBSD-Net-Autotuner
sudo make uninstall
```

---

## Changelog

### v1.0 — 2025-12-05
- Initial release of **FreeBSD Network Autotuner**.

### v1.1 — 2025-12-10
- Added **BDP estimation** and buffer tuning.

### v1.2 — 2025-12-15
- Added **jitter measurement** and override for delayed ACK.

### v1.3 — 2025-12-20
- Added **out-of-order segment measurement** and dynamic tuning for ABC and reassembly queue.

### v1.4 — 2025-12-25
- Refactored `loss_pct` extraction.
- Improved persistence logic in `set_sysctl_if_needed`.

### v1.5 — 2026-01-09
- Automatic selection of `TARGET_HOST`.
- Robust NIC speed detection.
- Mbuf cluster and UDP buffer tuning.
- ISR tuning via `/boot/loader.conf`.

### v1.6 — 2026-01-11
- Added monitoring of **FIN-WAIT-1 sockets** as a diagnostic metric (logged, no dynamic tuning).
- Integrated dynamic tuning for **FIN-WAIT-2 sockets**:
  - Uses `net.inet.tcp.fast_finwait2_recycle`.
  - Enabled only if FIN-WAIT-2 exceeds 5% of ESTABLISHED connections.
  - Restores default when ratio ≤5%.
  - Idempotent logging: changes are logged only when state transitions occur.
- Extended log output to include `finwait1_conns`, `finwait2_conns`, and `est_conns`.

### v1.7 — 2026-01-14
- Introduced **adaptive congestion control (CC) selection**:
  - Chooses CC algorithm dynamically (Vegas, HTCP, DCTCP, CDG, CHD/HD, Cubic) based on RTT, loss, jitter, and throughput.
- Introduced **adaptive TCP stack selection**:
  - Chooses stack dynamically (BBR, RACK, FreeBSD) based on throughput, RTT, loss, and jitter.

### v1.8 — 2026-01-16
- Unified latency and jitter measurement:
  - Now extracts avg RTT, stddev jitter, peak jitter (max−min), and packet loss in a single call to ping.
  - Liminates redundant double ping calls, reducing system load and ensuring consistent metrics from the same sample set.
- Dual jitter metrics:
  - Added stddev jitter (statistical variability).
  - Added peak jitter (max RTT − min RTT) for visibility into extreme spikes.
  - Both values are logged for richer diagnostics.
- Extended logging:
  - Log entries now include jitter and jitter_peak alongside RTT, loss, throughput, and other metrics.
  - Provides clearer insight into both average variability and worst‑case latency fluctuations.
- Adaptive tuning logic updated to use stddev jitter as the primary jitter metric for decisions.
- Code efficiency: reduced duplicate calls to ping, improving performance and accuracy.
- Corrected parsing of ping output to reliably capture min/avg/max/stddev values.
- Fixed issue where RTT and jitter previously reported identical values due to incorrect field extraction.
- Improved resilience against empty or malformed ping output lines.

### v1.9 — 2026-04-25
- Added RACK/TLP tuning parameters for improved performance in high-latency and reordering-prone networks.
- Added standard TCP stack tuning parameters.

### v2.0 — 2026-04-25
- Automatic backup creation for **/etc/sysctl.conf** and **/boot/loader.conf** for safe rollback.
- Resolved problem with un‑commented variables in **/etc/sysctl.conf** and **/boot/loader.conf**.

### v2.1 — 2026-04-29
- Simulation mode active (dry-run): no changes applied, only logged.
