# RowPilot Tide Information Architecture

### Overview
RowPilot integrates real-time tide information sourced directly from the Japan Meteorological Agency (JMA) to provide rowers with accurate and actionable tidal data.
Tide conditions are a critical safety and performance factor for on-water rowing, and this feature is designed to be available instantly — without any account registration or third-party API key.

---

## 1. Data Source
### Japan Meteorological Agency (JMA) Open Data
RowPilot fetches tidal observation data from the JMA's publicly available dataset.

```
https://www.data.jma.go.jp/gmd/kaiyou/data/db/tide/suisan/txt/{year}/{stationId}.txt
```

- **Format**: Fixed-width plain text (`.txt`)
- **Update Cycle**: Annually published; hourly tide level data for the entire year
- **Authentication**: None required — completely open access
- **Coverage**: 239 tidal observation stations across all of Japan

---

## 2. Station Selection
### Automatic GPS-Based Nearest Station Detection
When the user opens the tide view, RowPilot uses CoreLocation to obtain the device's current coordinates and automatically selects the nearest tidal observation station.

#### Selection Algorithm
1. Retrieve user location via `CLLocationManager`
2. Calculate the geodesic distance from the user's location to all 239 registered stations
3. Select the station with the minimum distance

```swift
let sortedStations = stations.sorted {
    let loc1 = CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
    let loc2 = CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude)
    return location.distance(from: loc1) < location.distance(from: loc2)
}
```

#### Station Coverage
All 239 stations listed in the JMA Tide Tables are registered, covering:
- Hokkaido, Tohoku, Kanto, Chubu, Kinki, Chugoku, Shikoku, Kyushu
- Remote islands: Ogasawara, Okinawa, Ishigaki, Miyako, Yonaguni, etc.

---

## 3. Data Parsing
### JMA Text Format
Each row in the JMA text file corresponds to one calendar day and uses a fixed-width encoding.

| Byte Range | Content |
|---|---|
| 0 – 71 | Hourly tide levels (24 × 3 chars, unit: cm) |
| 72 – 73 | Year (last 2 digits, YY) |
| 74 – 75 | Month (MM) |
| 76 – 77 | Day (DD) |
| 80 – 107 | High tide events (up to 4 events × 7 chars) |
| 108 – 135 | Low tide events (up to 4 events × 7 chars) |

#### High/Low Tide Event Block (7 chars per event)
```
[HHMM][Level (3 chars)]
```
- `9999` in the time field indicates a null/invalid entry and is skipped.

---

## 4. Tide Type Classification
### Moon-Age Based Algorithm
RowPilot classifies each day's tide type based on the lunar calendar, computed from a known reference new moon.

**Reference New Moon**: January 11, 2024, 20:57 JST
**Synodic Month**: 29.530588853 days

| Moon Age Range (days) | Tide Type |
|---|---|
| 0.0 – 2.5, 13.5 – 17.0, 28.0 – 29.6 | 大潮 (Spring Tide) |
| 2.5 – 6.0, 11.0 – 13.5, 17.0 – 20.0, 26.0 – 28.0 | 中潮 (Moderate Tide) |
| 6.0 – 10.0, 20.0 – 23.0 | 小潮 (Neap Tide) |
| 10.0 – 11.0, 23.0 – 24.0 | 長潮 (Long Tide) |
| 24.0 – 26.0 | 若潮 (Young Tide) |

---

## 5. Caching Strategy
### Full-Year In-Memory Cache
To minimize network requests and ensure offline usability during a training session, RowPilot caches the entire year's data in memory upon the first fetch.

- **Cache Key Format**: `"yyyy-MM-dd"` (e.g., `"2026-06-25"`)
- **Cache Scope**: Per station, per year
- **Re-fetch Trigger**: Year change (e.g., January 1st of a new year)
- **Date Navigation**: Users can swipe to browse past and future dates without triggering additional network requests

---

## 6. UI Design Principles
- **Zero Configuration**: The tide view activates automatically when location permission is granted. No manual station selection required.
- **Date Swipe Navigation**: Users can navigate to any date within the cached year by swiping, enabling pre-training planning.
- **Graceful Degradation**: If the network is unavailable, the last cached data is displayed without error interruption.

---

## 7. Privacy & Permissions
| Permission | Purpose | Required |
|---|---|---|
| Location (When In Use) | Nearest station detection | Yes |
| Network Access | JMA data fetch | Yes |

- No tide data or location data is transmitted to RowPilot servers.
- All data is fetched directly from JMA's public endpoints.
- Location is used locally on-device only.

---

<hr>Version: 1.0<br>
Author: Kaito Nakahira / Antigravity AI<br>
Date: 2026-06-25
