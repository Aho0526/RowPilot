# RowPilot PM5 Communication Architecture v4.1
### Overview
In v4.1, we have updated and refined the communication specification to match the actual implementation. The traditional communication method that relied on “fixed-time waiting” remains eliminated in favor of a “State-Synchronized Architecture” that proceeds while monitoring the actual state (Machine Status) of the PM5.
Each PM5 is managed as an independent state machine, and the architecture is designed so that a delay or communication error in a single unit does not halt the entire system.

## 1. Communication Layer
### Extended CSAFE Frame
Prioritizing stability when multiple PM5s are connected, all communication is standardized to the Extended CSAFE Frame.

### Structure: F0 [Destination] [Source] [Payload] [Checksum] F2
- **Destination Address**: `0xFD` (Default secondary address)
- **Source Address**: `0x00` (Host)
- **Checksum**: XOR of payload (Frame Contents) bytes only (does not include Destination/Source addresses).
- **Byte Stuffing**: Applied to the entire packet between the `0xF0` start flag and `0xF2` stop flag. This includes the `Destination`, `Source`, `Payload`, and `Checksum`.
- **Stuffed control bytes**: `0xF0` ~ `0xF3` (escaped using standard CSAFE stuffing method: prefixing `0xF3` and applying offset/XOR).

---

## 2. Transmission Architecture
### CSAFECommandQueue
To prevent instability in BLE communication, all transmissions are managed by a dedicated queue (using Swift Actors to guarantee order per device).

### Global Write Limiter
To prevent congestion in the CoreBluetooth internal queue, the number of concurrent BLE writes is limited globally.
- `maxConcurrentWrites = 3`

### Write Timeout
Individual write operations have a dedicated timeout duration:
- `writeTimeout = 2.0s`
If a write does not complete within this window, the operation fails and the device state is updated.

---

### Inter-frame Delay
To comply with the CSAFE specification and ensure processing time on the PM5:
- **Minimum Inter-frame Gap**: `50ms` (standard gap inserted after each frame transmission).
- **Multi-frame Transmission Delay**: `150ms` (additional gap inserted between configuration chunks, e.g., during Variable Interval setup).

---

### Parallel / Sequential Hybrid
#### Within the Device
Sequential: Guarantees the transmission order to each PM5.

#### Between Devices
Parallel: Controls multiple PM5s in parallel.

---

## 3. v4.1 Workflow
### Phase 1 — TERMINATE
Send a forced reset to all PM5s.
- **CSAFE command**: `CSAFE_PM_SET_SCREENSTATE` with ScreenType = `WORKOUT` (0x01) and ScreenValue = `TERMINATE` (0x02).
- **Purpose**:
  - End the current workout
  - Initialize PM5 internal state
  - Start state synchronization

---

### Phase 2 — Machine Status Polling
After TERMINATE, monitor PM5 status via 4Hz polling.

#### Polling Target
Machine Status = Ready

#### Timeout
- `baseTimeout = 9.0s`

#### Dynamic Extension
If any of the following conditions are met:
- PM5 returns Busy (Status Byte Bit 5 is set)
- PM5 is in: `InUse` / `Finish` / `Pause` status
- State transition is detected (Machine Status changes)
##### → Automatically extend the polling deadline (e.g., reset timeout to 9.0s on state changes, or extend by 2.0s during busy operations).

### Purpose
Safely accommodate:
- Save operations
- Workout termination processing
- State transition delays
within the PM5.

---

### Phase 3 — CONFIG
After Ready synchronization is complete, individually send workout settings.
- **Opcode 0x01**: Set Workout Type
- **Opcode 0x03**: Set Workout Duration
- **Opcode 0x05**: Set Split Duration
- **Opcode 0x14**: Configure Workout
- **Opcode 0x13**: Set Screen State (Workout / Prepare to Row)

For Multi-frame Configuration (e.g. Variable Interval), frames are split to avoid builder limits (max 2 intervals per frame), transmitted sequentially with a `150ms` delay between them.

---

## 4. Fault Tolerance
### Healthy / Degraded Separation
Only when communication stops (e.g., 2.0s write timeout) or the state stagnates:
- Transition to `Degraded`.

### Isolation Design
In the event of a failure on a single unit:
- Queue stop, workflow stop, and UI stop shall not occur.
- **Degraded Device handling**: Settings/control commands (except for `POLL_STATUS`) are automatically skipped to prevent the queue from stalling. The device is marked as `Degraded` in the UI while other connected devices continue normally.

### Exponential Backoff Retry
When sending Configuration packets (Phase 3), if a write fails, it is retried up to 2 times with exponential backoff:
- **1st retry delay**: `100ms`
- **2nd retry delay**: `200ms`

---

## 5. Data Acquisition
### General Status (0x31)
Acquire:
- Distance
- Elapsed Time
- Workout State (byte index 8)

### Rowing Status (0x32)
Acquire:
- Stroke Rate
- Pace /500m

### Additional Stroke Data (0x36)
Acquire:
- Watts (Power)

### Power Data (0x33)
Acquire:
- Total Calories

### Data Point (0x22)
Acquire:
- CSAFE responses
- Machine Status (extracted from Status Byte Bits 3-0)
- Busy Flag (extracted from Status Byte Bit 5)

---

## 6. UI / UX Philosophy
v4.1 maintains an optimistic UI.
The dashboard loads immediately after a button is pressed, while status synchronization for each PM5 proceeds in the background.

### Goals
- Improve operational responsiveness
- Eliminate the feeling of waiting for communication
- Individual visualization of faulty devices

---

## 7. Design Philosophy
v4.1 is a “Stable Base Architecture” intended for actual operation and release on the App Store.
The objective is:
not to be theoretically the strongest,
but to prioritize reliability in real-world BLE environments above all else.

<hr>Version: 4.1<br>
Author: Kaito Nakahira / Antigravity AI<br>
Date: 2026-07-02
