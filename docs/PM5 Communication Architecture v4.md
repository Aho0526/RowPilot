# RowPilot PM5 Communication Architecture v4
### Overview
In v4, we have eliminated the traditional communication method that relied on “fixed-time waiting”
and adopted a “State-Synchronized Architecture” that proceeds while monitoring
the actual state (Machine Status) of the PM5.
Each PM5 is managed as an independent state machine,
and the architecture is designed so that a delay or communication error in a single unit does not halt the entire system.

--- 
## 1. Communication Layer
#### Extended CSAFE Frame
Prioritizing stability when multiple PM5s are connected,
all communication is standardized to the Extended CSAFE Frame.

#### F0 [Destination] [Source] [Payload] [Checksum] F2
- Addressing
- Field
- Value
- Destination
- 0xFD
- Source
- 0x00

Byte Stuffing
Control bytes:
0xF0 ~ 0xF3
If detected within the payload,
byte stuffing is performed in accordance with the CSAFE specification.

---

## 2. Transmission Architecture
CSAFECommandQueue
To prevent instability in BLE communication,
all transmissions are managed by a dedicated queue.


### Global Write Limiter 
To prevent congestion in the CoreBluetooth internal queue,
 the number of concurrent BLE writes is limited.
maxConcurrentWrites = 3

---
### Inter-frame Gap
To comply with the CSAFE specification,
 a minimum 50ms gap is inserted between all frame transmissions.
interFrameGap = 50ms

---
### Parallel / Sequential Hybrid
#### Within the Device
Sequential
Guarantees the transmission order to each PM5.

### Between Devices
Parallel
Controls multiple PM5s in parallel.

---

## 3. v4 Workflow
### Phase 1 — TERMINATE
Send a forced reset to all PM5s.
Purpose:
- End the current workout
- Initialize PM5 internal state
- Start state synchronization

---
### Phase 2 — Machine Status Polling
After TERMINATE,
 monitor PM5 status via 4Hz polling.

#### Polling Target
Machine Status = Ready

#### Timeout
baseTimeout = 9.0s

#### Dynamic Extension
If any of the following are detected:
- Busy
- InUse
- Finish
- State transition
### → Automatically extend the deadline.


## Purpose
Safely accommodate:
- Save operations
- Workout termination processing
- State transition delays
within the PM5.

---
### Phase 3 — CONFIG
After Ready synchronization is complete,
 individually send workout settings.
Example:
- Distance
- Time
- Split
- Screen State

---

## 4. Fault Tolerance
Healthy / Degraded Separation
Only when communication stops or the state stagnates:
Transition to
Degraded.

### Isolation Design
In the event of a failure on a single unit:
- Queue stop
- Workflow stop
- UI stop
shall not occur.

---

## 5. Data Acquisition
### General Status (0x31)
Acquire:
- Distance
- Elapsed Time

### Rowing Status (0x32)
Acquire:
Stroke Rate
Pace /500m

### Data Point (0x22)
Acquire:
- CSAFE responses
- Machine Status

---

## 6. UI / UX Philosophy
v4 adopts an optimistic UI.
The dashboard loads immediately after a button is pressed,
 while status synchronization for each PM5 proceeds in the background.

### Goals
- Improve operational responsiveness
- Eliminate the feeling of waiting for communication
- Individual visualization of faulty devices

---

## 7. Design Philosophy
v4 is not designed for “research purposes,”
but rather as a “Stable Base Architecture”
intended for actual operation and release on the App Store.
The objective is:
not to be theoretically the strongest,
but to prioritize
reliability in real-world BLE environments
above all else.


<hr>Document Version: 1.1<br>
Author: Kaito Nakahira / Antigravity AI<br>
Date: 2026-05-18
