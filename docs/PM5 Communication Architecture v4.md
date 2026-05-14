# RowPilot PM5 Communication Architecture v4
### Overview
v4では、従来の「固定時間待機」に依存した通信方式を廃止し、
 PM5の実際の状態（Machine Status）を監視しながら進行する
 “State-Synchronized Architecture” を採用している。
各PM5は独立した state machine として管理され、
 1台の遅延や通信異常が全体を停止させない構造となっている。

## 1. Communication Layer
### Extended CSAFE Frame
複数PM5接続時の安定性を優先し、
 すべての通信を Extended CSAFE Frame へ統一。

### F0 [Destination] [Source] [Payload] [Checksum] F2
- Addressing
- Field
- Value
- Destination
- 0xFD
- Source
- 0x00

Byte Stuffing
制御バイト：
0xF0 ~ 0xF3
を payload 内で検出した場合、
 CSAFE仕様に基づき byte stuffing を実施。

---

## 2. Transmission Architecture
CSAFECommandQueue
BLE通信の不安定化を防ぐため、
 全送信を専用 queue で管理。


### Global Write Limiter 
CoreBluetooth内部queueの詰まりを防ぐため、
 同時BLE write数を制限。
maxConcurrentWrites = 3

---
### Inter-frame Gap
CSAFE仕様準拠のため、
 全フレーム送信間に minimum 50ms gap を挿入。
interFrameGap = 50ms

---
### Parallel / Sequential Hybrid
#### Device内部
Sequential
各PM5への送信順序を保証。

#### Device間
Parallel
複数PM5を並列制御。

---

## 3. v4 Workflow
### Phase 1 — TERMINATE
全PM5へ強制リセットを送信。
目的：
- 既存Workout終了
- PM5内部状態初期化
- 状態同期開始

---
### Phase 2 — Machine Status Polling
TERMINATE後、
 4Hz polling により PM5状態を監視。

#### Polling Target
Machine Status = Ready

#### Timeout
baseTimeout = 9.0s

#### Dynamic Extension
以下を検知した場合：
- Busy
- InUse
- Finish
- state transition
##### → deadline を自動延長。


### Purpose
PM5内部の：
- save処理
- workout終了処理
- state transition遅延
を安全に吸収。

---
### Phase3 — CONFIG
Ready同期完了後、
 Workout設定を個別送信。
例：
- Distance
- Time
- Split
- Screen State

---

## 4. Fault Tolerance
Healthy / Degraded Separation
通信停止または状態停滞時のみ：
Degraded
へ移行。

#### Isolation Design
1台の異常で：
- queue停止
- workflow停止
- UI停止
を発生させない。

---

## 5. Data Acquisition
### General Status (0x31)
取得：
- Distance
- Elapsed Time

### Rowing Status (0x32)
取得：
Stroke Rate
Pace /500m

### Data Point (0x22)
取得：
- CSAFE responses
- Machine Status

---

## 6. UI / UX Philosophy
v4では optimistic UI を採用。
ボタン押下直後に dashboard 遷移を行い、
 各PM5の状態同期はバックグラウンドで進行する。

### Goals
- 操作レスポンス向上
- 通信待機感の排除
- 異常デバイスの個別可視化

---

## 7. Design Philosophy
v4は「研究用」ではなく、
 実運用・App Store投入を前提とした
 “Stable Base Architecture” として設計されている。
目的は：
理論上最強
ではなく、
BLE実環境で壊れないこと
を最優先とする。

以上

---
## あとがき
AIを用いてRowPilot内のマネージャーモードにおける通信アーキテクチャを
言語化しています。
また、v4(本誌の内容)は2026/5/13に作成、適用されたものです。
改訂版(v4.1など)があれば順次公開します。
