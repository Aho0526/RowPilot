import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var previousLocation: CLLocation?

    @Published var totalDistance: Double = 0.0
    @Published var currentSpeed: Double = 0.0

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
        isFirstUpdateAfterStart = true
        
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
    
    // ... (stopTracking etc)
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
        guard newLocation.horizontalAccuracy >= 0 && newLocation.horizontalAccuracy <= LocationConstants.tideAccuracyThreshold else {
            return
        }

        // 2. キャッシュされた古いデータを無視 (例: 10秒以上前)
        let howRecent = newLocation.timestamp.timeIntervalSinceNow
        guard abs(howRecent) < 10 else { return }

        DispatchQueue.main.async {
            // セッション開始直後、またはpreviousLocationがない場合は距離加算しない
            if !self.isFirstUpdateAfterStart, let previous = self.previousLocation {
                // トレーニング記録用の距離計算はより厳密な精度(20m)を維持する場合、ここでチェック
                if newLocation.horizontalAccuracy <= 20 {
                    let distance = newLocation.distance(from: previous)
                    self.totalDistance += distance
                }
            } else {
                // 初回更新（スキップ）
                self.isFirstUpdateAfterStart = false
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
        // 次回の開始時に距離が飛ばないようにフラグをリセット(念のため)
        isFirstUpdateAfterStart = true 
    }
}
