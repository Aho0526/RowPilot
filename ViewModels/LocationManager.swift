import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var previousLocation: CLLocation?

    @Published var totalDistance: Double = 0.0
    @Published var currentSpeed: Double = 0.0
    @Published var routePoints: [LocationData] = []

    private var wasGpsLost = false
    private var lastRecordedPointTime: Date?

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = LocationConstants.defaultAccuracy
        locationManager.distanceFilter = LocationConstants.distanceFilterMeters
        locationManager.allowsBackgroundLocationUpdates = false
    }

    private var isFirstUpdateAfterStart = false

    func startTracking() {
        guard !isPreview else {
            print("Previewモードでは位置情報を使用しません。")
            return
        }

        // 距離はリセットするが、前回の位置情報(信号強度用)は保持する
        // ただし、距離計算の飛びを防ぐためにフラグを立てる
        totalDistance = 0.0
        routePoints = []
        isFirstUpdateAfterStart = true
        wasGpsLost = false
        lastRecordedPointTime = nil
        
        // 権限リクエストのみ（UIスレッド警告回避のため locationServicesEnabled を使用しない）
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse, .authorizedAlways:
            // すぐに開始（※許可がある場合）
            beginLocationUpdates()

        case .restricted, .denied:
            print("位置情報の使用が制限・拒否されています。")

        @unknown default:
            print("未知の認可状態")
        }
    }
    
    func stopTracking() {
        locationManager.stopUpdatingLocation()
    }
    
    // 許可変更時に呼ばれる（iOS 14+）
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            beginLocationUpdates()
        case .denied, .restricted:
            print("位置情報が拒否または制限されています。")
        default:
            break
        }
    }
    
    private func beginLocationUpdates() {
        locationManager.startUpdatingLocation()
    }

    // 毎回位置情報が更新されるたびに呼ばれる
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }

        // 1. 精度フィルタ (潮汐情報用には緩和された閾値を使用)
        let isAccuracyOkForTide = newLocation.horizontalAccuracy >= 0 && newLocation.horizontalAccuracy <= LocationConstants.tideAccuracyThreshold
        // 2. キャッシュされた古いデータを無視 (例: 10秒以上前)
        let howRecent = newLocation.timestamp.timeIntervalSinceNow
        let isRecentOk = abs(howRecent) < 10

        if !isAccuracyOkForTide || !isRecentOk {
            DispatchQueue.main.async {
                self.wasGpsLost = true
            }
            return
        }

        DispatchQueue.main.async {
            // トレーニング記録用の距離計算はより厳密な精度(20m)を維持する場合、ここでチェック
            let isAccuracyOkForTraining = newLocation.horizontalAccuracy <= 20
            
            if !self.isFirstUpdateAfterStart, let previous = self.previousLocation {
                if isAccuracyOkForTraining {
                    let distance = newLocation.distance(from: previous)
                    self.totalDistance += distance
                    
                    var isGap = self.wasGpsLost
                    if let lastTime = self.lastRecordedPointTime {
                        let timeDiff = newLocation.timestamp.timeIntervalSince(lastTime)
                        if timeDiff > 15 {
                            isGap = true
                        }
                    }
                    
                    self.routePoints.append(LocationData(
                        latitude: newLocation.coordinate.latitude,
                        longitude: newLocation.coordinate.longitude,
                        isPostGap: isGap
                    ))
                    
                    self.lastRecordedPointTime = newLocation.timestamp
                    self.wasGpsLost = false
                } else {
                    self.wasGpsLost = true
                }
            } else {
                if isAccuracyOkForTraining {
                    // 初回更新
                    self.isFirstUpdateAfterStart = false
                    self.lastRecordedPointTime = newLocation.timestamp
                    self.wasGpsLost = false
                } else {
                    self.wasGpsLost = true
                }
            }
            
            // 速度計算
            let speed = newLocation.speed
            self.currentSpeed = (speed >= 0) ? speed * LocationConstants.metersPerSecondToKmPerHour : 0.0 // km/h へ変換

            // 位置更新（TideManagerなどが利用）
            self.previousLocation = newLocation
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager Error: \(error.localizedDescription)")
    }

    // LocationManager に追加
    func reset() {
        // 位置情報はクリアせず、積算値のみリセット
        totalDistance = 0.0
        currentSpeed = 0.0
        routePoints = []
        // 次回の開始時に距離が飛ばないようにフラグをリセット(念のため)
        isFirstUpdateAfterStart = true 
        wasGpsLost = false
        lastRecordedPointTime = nil
    }
}
