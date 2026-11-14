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
        // 非計測時は省電力設定で潮汐・天気用の位置のみ取得 (M-7)
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 500
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = true
        authorizationStatus = locationManager.authorizationStatus
    }

    private var isFirstUpdateAfterStart = false
    /// GPSスパイク除外用の最大許容速度 (m/s): ボートの現実的上界 + 余裕 = 12 m/s (43.2 km/h)
    private let maxPlausibleSpeedMps: Double = 12.0

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

    private func configureAccuracy(forTracking active: Bool) {
        if active {
            locationManager.desiredAccuracy = LocationConstants.defaultAccuracy
            locationManager.distanceFilter = LocationConstants.distanceFilterMeters
            locationManager.pausesLocationUpdatesAutomatically = false
            // UIBackgroundModes に location が定義されている環境で計測中のみバックグラウンド更新を有効化 (C-7)
            locationManager.allowsBackgroundLocationUpdates = true
        } else {
            locationManager.allowsBackgroundLocationUpdates = false
            locationManager.pausesLocationUpdatesAutomatically = true
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager.distanceFilter = 500
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
        configureAccuracy(forTracking: true)

        requestPermission()
    }
    
    /// 一時停止から距離・航跡を保持したままトラッキングを再開する (C-6)
    func resumeTracking() {
        guard !isPreview else {
            print("Previewモードでは位置情報を使用しません。")
            return
        }
        
        isTracking = true
        isFirstUpdateAfterStart = true
        wasGpsLost = false
        configureAccuracy(forTracking: true)
        
        requestPermission()
    }
    
    /// ワークアウト計測中のトラッキングを停止する
    func stopTracking() {
        isTracking = false
        currentSpeed = 0.0
        configureAccuracy(forTracking: false)
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
            var didRecordValidTrackingPoint = false
            if self.isTracking {
                let isAccuracyOkForTraining = newLocation.horizontalAccuracy <= 20
                
                if !self.isFirstUpdateAfterStart, let previous = prevLocation {
                    let timeDelta = newLocation.timestamp.timeIntervalSince(previous.timestamp)
                    if isAccuracyOkForTraining && timeDelta > 0 {
                        let distance = newLocation.distance(from: previous)
                        let impliedSpeed = distance / timeDelta
                        
                        // 非現実的なGPSジャンプを除外 (M-7)
                        if impliedSpeed <= self.maxPlausibleSpeedMps {
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
                            didRecordValidTrackingPoint = true
                        } else {
                            self.wasGpsLost = true
                        }
                    } else if !isAccuracyOkForTraining {
                        self.wasGpsLost = true
                    }
                } else {
                    if isAccuracyOkForTraining {
                        // 初回・再開直後の開始点も航跡に記録する (M-7, C-6)
                        let isResumeGap = !self.routePoints.isEmpty
                        self.routePoints.append(LocationData(
                            latitude: newLocation.coordinate.latitude,
                            longitude: newLocation.coordinate.longitude,
                            isPostGap: isResumeGap ? true : false
                        ))
                        self.isFirstUpdateAfterStart = false
                        self.lastRecordedPointTime = newLocation.timestamp
                        self.wasGpsLost = false
                        didRecordValidTrackingPoint = true
                    } else {
                        self.wasGpsLost = true
                    }
                }
            }
            
            // 速度計算（計測停止中は0）
            let speed = newLocation.speed
            self.currentSpeed = (self.isTracking && speed >= 0) ? speed * LocationConstants.metersPerSecondToKmPerHour : 0.0 // km/h へ変換

            // 位置更新（ワークアウト中は有効ポイントのみ更新し、低精度・スパイク混入時の距離ジャンプを防止）
            if !self.isTracking || didRecordValidTrackingPoint || self.previousLocation == nil {
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
        configureAccuracy(forTracking: false)
    }
}
