import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var previousLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    @Published var totalDistance: Double = 0.0
    @Published var currentSpeed: Double = 0.0
    @Published var routePoints: [LocationData] = []
    @Published var isTracking: Bool = false

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
        authorizationStatus = locationManager.authorizationStatus
    }

    private var isFirstUpdateAfterStart = false

    /// 位置情報の権限をリクエストし、許可済みであれば位置情報の更新を開始する
    func requestPermission() {
        guard !isPreview else {
            print("Previewモードでは位置情報を使用しません。")
            return
        }

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse, .authorizedAlways:
            beginLocationUpdates()

        case .restricted, .denied:
            print("位置情報の使用が制限・拒否されています。")

        @unknown default:
            print("未知の認可状態")
        }
    }

    /// ワークアウト計測中のトラッキングを開始する
    func startTracking() {
        guard !isPreview else {
            print("Previewモードでは位置情報を使用しません。")
            return
        }

        isTracking = true
        totalDistance = 0.0
        routePoints = []
        isFirstUpdateAfterStart = true
        wasGpsLost = false
        lastRecordedPointTime = nil

        requestPermission()
    }
    
    /// ワークアウト計測中のトラッキングを停止する
    func stopTracking() {
        isTracking = false
    }
    
    // 許可変更時に呼ばれる（iOS 14+）
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
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
            let prevLocation = self.previousLocation

            // ワークアウト計測中のみ距離計算・ルートポイント蓄積を行う
            if self.isTracking {
                let isAccuracyOkForTraining = newLocation.horizontalAccuracy <= 20
                
                if !self.isFirstUpdateAfterStart, let previous = prevLocation {
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
            }
            
            // 速度計算
            let speed = newLocation.speed
            self.currentSpeed = (speed >= 0) ? speed * LocationConstants.metersPerSecondToKmPerHour : 0.0 // km/h へ変換

            // 位置更新（ワークアウト中は高精度ポイントのみ更新し、低精度ポイント混入時の距離ジャンプを防止）
            if !self.isTracking || newLocation.horizontalAccuracy <= 20 || self.previousLocation == nil {
                self.previousLocation = newLocation
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager Error: \(error.localizedDescription)")
    }

    func reset() {
        // 位置情報はクリアせず、積算値のみリセット
        totalDistance = 0.0
        currentSpeed = 0.0
        routePoints = []
        isTracking = false
        isFirstUpdateAfterStart = true 
        wasGpsLost = false
        lastRecordedPointTime = nil
    }
}
