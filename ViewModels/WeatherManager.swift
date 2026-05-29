import Foundation
import CoreLocation
import Combine

/// Open-Meteo API（無料・キー不要）を使った天気情報ViewModel
class WeatherManager: ObservableObject {
    @Published var weatherCode: Int? = nil
    @Published var temperature: Double? = nil
    @Published var precipitationProbability: Int? = nil // %
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private var lastFetchLocation: CLLocation? = nil
    private var lastFetchTime: Date? = nil
    private let cacheInterval: TimeInterval = 30 * 60 // 30分キャッシュ
    
    /// WMOコードからSFSymbol名と説明文を返す
    static func symbolAndLabel(for code: Int) -> (symbol: String, label: String) {
        switch code {
        case 0:
            return ("sun.max.fill", "Clear")
        case 1:
            return ("sun.max.fill", "Mainly Clear")
        case 2:
            return ("cloud.sun.fill", "Partly Cloudy")
        case 3:
            return ("cloud.fill", "Overcast")
        case 45, 48:
            return ("cloud.fog.fill", "Foggy")
        case 51, 53, 55:
            return ("cloud.drizzle.fill", "Drizzle")
        case 56, 57:
            return ("cloud.sleet.fill", "Freezing Drizzle")
        case 61, 63, 65:
            return ("cloud.rain.fill", "Rain")
        case 66, 67:
            return ("cloud.sleet.fill", "Freezing Rain")
        case 71, 73, 75:
            return ("cloud.snow.fill", "Snow")
        case 77:
            return ("cloud.snow.fill", "Snow Grains")
        case 80, 81, 82:
            return ("cloud.heavyrain.fill", "Showers")
        case 85, 86:
            return ("cloud.snow.fill", "Snow Showers")
        case 95:
            return ("cloud.bolt.fill", "Thunderstorm")
        case 96, 99:
            return ("cloud.bolt.rain.fill", "Thunderstorm w/ Hail")
        default:
            return ("cloud.fill", "Unknown")
        }
    }
    
    /// 取得済みシンボル
    var currentSymbol: String {
        guard let code = weatherCode else { return "questionmark.circle" }
        return Self.symbolAndLabel(for: code).symbol
    }
    
    /// 取得済みラベル
    var currentLabel: String {
        guard let code = weatherCode else { return "--" }
        return Self.symbolAndLabel(for: code).label
    }
    
    func fetchWeather(for location: CLLocation) {
        // 30分以内かつ近い場所のキャッシュは再取得しない
        if let last = lastFetchTime, let lastLoc = lastFetchLocation,
           Date().timeIntervalSince(last) < cacheInterval,
           lastLoc.distance(from: location) < 5000 {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        // current_weather + 直近1時間の降水確率(hourly)を取得
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current_weather=true&hourly=precipitation_probability&forecast_days=1&timezone=auto"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let currentWeather = json["current_weather"] as? [String: Any] else {
                    self.errorMessage = "Parse error"
                    return
                }
                
                self.weatherCode = currentWeather["weathercode"] as? Int
                self.temperature = currentWeather["temperature"] as? Double
                
                // 現在時刻に最も近い降水確率を取得
                if let hourly = json["hourly"] as? [String: Any],
                   let times = hourly["time"] as? [String],
                   let probs = hourly["precipitation_probability"] as? [Int] {
                    let currentTimeStr = currentWeather["time"] as? String ?? ""
                    if let idx = times.firstIndex(where: { $0 == currentTimeStr }) {
                        self.precipitationProbability = probs[idx]
                    } else if !probs.isEmpty {
                        self.precipitationProbability = probs[0]
                    }
                }
                
                self.lastFetchLocation = location
                self.lastFetchTime = Date()
            }
        }.resume()
    }
}
