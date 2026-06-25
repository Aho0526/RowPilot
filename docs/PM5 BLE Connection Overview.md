# RowPilot PM5 BLE Connection Overview

### Overview
RowPilot connects to Concept2 PM5 performance monitors via Bluetooth Low Energy (BLE) using the CSAFE (Communication Standard for Fitness Equipment) protocol.
This document describes the connection model, supported features, and data acquisition strategy at a level suitable for open reference.

---

## 1. BLE Connection Model
### Multi-Device Support
RowPilot is designed for multi-boat environments such as crew training sessions.
Multiple PM5 monitors can be connected and controlled simultaneously, with each unit managed as an independent state machine.

- **Max Connections**: Limited by iOS CoreBluetooth constraints (typically up to 8 peripherals)
- **Parallelism**: Commands to separate PM5 units are dispatched in parallel
- **Isolation**: A failure or delay on one unit does not halt communication with others

### Connection Flow
```
Scan → Discover PM5 → Connect → Discover Services → Discover Characteristics → Subscribe Notifications → Ready
```

#### CSAFE Service UUID
```
CE060030-43E5-11E4-916C-0800200C9A66
```

#### Key Characteristics
| Characteristic | Direction | Purpose |
|---|---|---|
| TX (Write) | App → PM5 | Send CSAFE commands |
| RX (Notify) | PM5 → App | Receive CSAFE responses |

---

## 2. CSAFE Protocol
### Frame Format
RowPilot uses the Extended CSAFE frame format for all communication to ensure compatibility when multiple PM5 units are connected.

```
F0 [Destination] [Source] [Payload] [Checksum] F2
```

- **Destination**: `0xFD` (PM5)
- **Source**: `0x00` (Host device)

### Byte Stuffing
Control bytes in the range `0xF0`–`0xF3` within the payload are escaped in accordance with the CSAFE specification to prevent framing collisions.

---

## 3. Key Data Streams
RowPilot reads the following data from each PM5 during an active workout session.

| CSAFE Command | Data Acquired |
|---|---|
| `0x31` General Status | Distance (m), Elapsed Time |
| `0x32` Rowing Status | Stroke Rate (SPM), Pace (/500m) |
| `0x22` Data Point | Machine Status, CSAFE response status |

### Polling Interval
Data is polled at **4 Hz** during an active workout, providing smooth real-time updates to the RowPilot dashboard without saturating the BLE bandwidth.

---

## 4. Workout Programming
### Supported Workout Types
RowPilot supports programming workouts directly to the PM5 from the app.

| Workout Type | CSAFE Code |
|---|---|
| Fixed Time | `0x01` |
| Fixed Distance | `0x02` |
| Variable Intervals | `0x08` |

### Variable Interval Strategy
Variable Interval workouts (multiple work/rest segments with different distances or times) require a multi-frame transaction due to PM5 firmware buffer constraints.
Each interval is sent in its own CSAFE frame sequentially, followed by a finalization command.
See [Variable Interval Communication Architecture](./Variable%20Interval%20Communication%20Architecture.md) for full protocol details.

---

## 5. Machine Status Synchronization
Before programming a new workout, RowPilot ensures all connected PM5 units are in a `Ready` state.

### Synchronization Phases
1. **TERMINATE** — Send a reset to all PM5s to end any ongoing workout and clear internal state
2. **Status Polling** — Monitor Machine Status at 4 Hz until all units report `Ready`
3. **CONFIG** — Transmit workout parameters (distance, time, split, screen state) to each unit

### Timeout & Resilience
- Base timeout: **9.0 seconds**
- The timeout is dynamically extended if transitional states (`Busy`, `InUse`, `Finish`) are detected, accommodating PM5-side save operations and state transitions.

For full details on the state-synchronized architecture, see [PM5 Communication Architecture v4](./PM5%20Communication%20Architecture%20v4.md).

---

## 6. Transmission Safeguards
To ensure stability in real-world BLE environments:

| Safeguard | Value | Purpose |
|---|---|---|
| Inter-Frame Gap | 50 ms | Compliance with CSAFE spec; prevents frame collisions |
| Max Concurrent Writes | 3 | Prevents CoreBluetooth internal queue congestion |
| Per-Device Queue | Sequential | Guarantees frame ordering per PM5 |

---

## 7. Design Philosophy
The PM5 communication stack in RowPilot is built for reliability in real-world environments, not theoretical throughput.

- **Optimistic UI**: The dashboard loads immediately after a button press; BLE synchronization proceeds in the background.
- **Fault Isolation**: No single PM5 failure causes a system-wide halt.
- **Production-Ready**: The architecture is designed for App Store release, prioritizing correctness and user experience over raw performance.

---

<hr>Version: 1.0<br>
Author: Kaito Nakahira / Antigravity AI<br>
Date: 2026-06-25
