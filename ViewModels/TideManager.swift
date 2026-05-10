import Foundation
import CoreLocation
import Combine

class TideManager: ObservableObject {
    @Published var nearestStation: TideStation?
    @Published var currentTideData: TideData?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // @Published var currentDate is below
    @Published var currentDate: Date = Calendar.current.startOfDay(for: Date()) {
        didSet {
            // 日付が変わったらデータを更新
            updateCurrentTideData()
        }
    }
    
    @Published var cachedText: String?
    @Published var tideDataCache: [String: TideData] = [:] // Key: "yyyy-MM-dd"
    
    // Computed property for formatting dates, thread-safe (returns new instance)
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }
    
    // 全国 239 地点の観測所リスト (気象庁 潮位表掲載地点一覧より抜粋)
    private let stations: [TideStation] = [
        TideStation(id: "WN", name: "稚内", coordinate: CLLocationCoordinate2D(latitude: 45.4000, longitude: 141.6833)),
        TideStation(id: "KE", name: "枝幸", coordinate: CLLocationCoordinate2D(latitude: 44.9333, longitude: 142.5833)),
        TideStation(id: "A0", name: "紋別", coordinate: CLLocationCoordinate2D(latitude: 44.3500, longitude: 143.3667)),
        TideStation(id: "AS", name: "網走", coordinate: CLLocationCoordinate2D(latitude: 44.0167, longitude: 144.2833)),
        TideStation(id: "A6", name: "羅臼", coordinate: CLLocationCoordinate2D(latitude: 44.0167, longitude: 145.2000)),
        TideStation(id: "NM", name: "根室", coordinate: CLLocationCoordinate2D(latitude: 43.3500, longitude: 145.5833)),
        TideStation(id: "HN", name: "花咲", coordinate: CLLocationCoordinate2D(latitude: 43.2833, longitude: 145.5667)),
        TideStation(id: "KR", name: "釧路", coordinate: CLLocationCoordinate2D(latitude: 42.9833, longitude: 144.3667)),
        TideStation(id: "B1", name: "十勝", coordinate: CLLocationCoordinate2D(latitude: 42.3000, longitude: 143.3167)),
        TideStation(id: "A9", name: "浦河", coordinate: CLLocationCoordinate2D(latitude: 42.1667, longitude: 142.7667)),
        TideStation(id: "C8", name: "苫小牧東", coordinate: CLLocationCoordinate2D(latitude: 42.6000, longitude: 141.8167)),
        TideStation(id: "TM", name: "苫小牧西", coordinate: CLLocationCoordinate2D(latitude: 42.6333, longitude: 141.6167)),
        TideStation(id: "SO", name: "白老", coordinate: CLLocationCoordinate2D(latitude: 42.5167, longitude: 141.3167)),
        TideStation(id: "A8", name: "室蘭", coordinate: CLLocationCoordinate2D(latitude: 42.3500, longitude: 140.9500)),
        TideStation(id: "A3", name: "森", coordinate: CLLocationCoordinate2D(latitude: 42.1167, longitude: 140.6000)),
        TideStation(id: "HK", name: "函館", coordinate: CLLocationCoordinate2D(latitude: 41.7833, longitude: 140.7167)),
        TideStation(id: "Q0", name: "吉岡", coordinate: CLLocationCoordinate2D(latitude: 41.4500, longitude: 140.2333)),
        TideStation(id: "A5", name: "松前", coordinate: CLLocationCoordinate2D(latitude: 41.4167, longitude: 140.1000)),
        TideStation(id: "ES", name: "江差", coordinate: CLLocationCoordinate2D(latitude: 41.8667, longitude: 140.1333)),
        TideStation(id: "ZP", name: "奥尻", coordinate: CLLocationCoordinate2D(latitude: 42.0833, longitude: 139.4833)),
        TideStation(id: "OR", name: "奥尻港", coordinate: CLLocationCoordinate2D(latitude: 42.1667, longitude: 139.5167)),
        TideStation(id: "SE", name: "瀬棚", coordinate: CLLocationCoordinate2D(latitude: 42.4500, longitude: 139.8500)),
        TideStation(id: "B6", name: "寿都", coordinate: CLLocationCoordinate2D(latitude: 42.8000, longitude: 140.2333)),
        TideStation(id: "B5", name: "岩内", coordinate: CLLocationCoordinate2D(latitude: 42.9833, longitude: 140.5000)),
        TideStation(id: "Z8", name: "忍路", coordinate: CLLocationCoordinate2D(latitude: 43.2167, longitude: 140.8667)),
        TideStation(id: "B3", name: "小樽", coordinate: CLLocationCoordinate2D(latitude: 43.2000, longitude: 141.0000)),
        TideStation(id: "IK", name: "石狩新港", coordinate: CLLocationCoordinate2D(latitude: 43.2167, longitude: 141.3000)),
        TideStation(id: "B2", name: "留萌", coordinate: CLLocationCoordinate2D(latitude: 43.9500, longitude: 141.6333)),
        TideStation(id: "F3", name: "沓形", coordinate: CLLocationCoordinate2D(latitude: 45.1833, longitude: 141.1333)),
        TideStation(id: "Q1", name: "竜飛", coordinate: CLLocationCoordinate2D(latitude: 41.2500, longitude: 140.3833)),
        TideStation(id: "AO", name: "青森", coordinate: CLLocationCoordinate2D(latitude: 40.8333, longitude: 140.7667)),
        TideStation(id: "ZA", name: "浅虫", coordinate: CLLocationCoordinate2D(latitude: 40.9000, longitude: 140.8667)),
        TideStation(id: "Q2", name: "大湊", coordinate: CLLocationCoordinate2D(latitude: 41.2500, longitude: 141.1500)),
        TideStation(id: "B4", name: "大間", coordinate: CLLocationCoordinate2D(latitude: 41.5333, longitude: 140.9000)),
        TideStation(id: "SH", name: "下北", coordinate: CLLocationCoordinate2D(latitude: 41.3667, longitude: 141.2333)),
        TideStation(id: "XS", name: "むつ小川原", coordinate: CLLocationCoordinate2D(latitude: 40.9333, longitude: 141.3833)),
        TideStation(id: "HG", name: "八戸港", coordinate: CLLocationCoordinate2D(latitude: 40.5333, longitude: 141.5500)),
        TideStation(id: "XT", name: "久慈", coordinate: CLLocationCoordinate2D(latitude: 40.2000, longitude: 141.8000)),
        TideStation(id: "MY", name: "宮古", coordinate: CLLocationCoordinate2D(latitude: 39.6500, longitude: 141.9833)),
        TideStation(id: "Q6", name: "釜石", coordinate: CLLocationCoordinate2D(latitude: 39.2667, longitude: 141.8833)),
        TideStation(id: "OF", name: "大船渡", coordinate: CLLocationCoordinate2D(latitude: 39.0167, longitude: 141.7500)),
        TideStation(id: "AY", name: "鮎川", coordinate: CLLocationCoordinate2D(latitude: 38.3000, longitude: 141.5000)),
        TideStation(id: "E6", name: "石巻", coordinate: CLLocationCoordinate2D(latitude: 38.4000, longitude: 141.2667)),
        TideStation(id: "SG", name: "塩釜", coordinate: CLLocationCoordinate2D(latitude: 38.3167, longitude: 141.0333)),
        TideStation(id: "SD", name: "仙台新港", coordinate: CLLocationCoordinate2D(latitude: 38.2667, longitude: 141.0000)),
        TideStation(id: "ZM", name: "相馬", coordinate: CLLocationCoordinate2D(latitude: 37.8333, longitude: 140.9667)),
        TideStation(id: "ON", name: "小名浜", coordinate: CLLocationCoordinate2D(latitude: 36.9333, longitude: 140.9000)),
        TideStation(id: "D1", name: "日立", coordinate: CLLocationCoordinate2D(latitude: 36.5000, longitude: 140.6333)),
        TideStation(id: "D3", name: "大洗", coordinate: CLLocationCoordinate2D(latitude: 36.3000, longitude: 140.5667)),
        TideStation(id: "D2", name: "鹿島", coordinate: CLLocationCoordinate2D(latitude: 35.9333, longitude: 140.7000)),
        TideStation(id: "CS", name: "銚子漁港", coordinate: CLLocationCoordinate2D(latitude: 35.7500, longitude: 140.8667)),
        TideStation(id: "ZF", name: "勝浦", coordinate: CLLocationCoordinate2D(latitude: 35.1333, longitude: 140.2500)),
        TideStation(id: "MR", name: "布良", coordinate: CLLocationCoordinate2D(latitude: 34.9167, longitude: 139.8333)),
        TideStation(id: "TT", name: "館山", coordinate: CLLocationCoordinate2D(latitude: 34.9833, longitude: 139.8500)),
        TideStation(id: "KZ", name: "木更津", coordinate: CLLocationCoordinate2D(latitude: 35.3667, longitude: 139.9167)),
        TideStation(id: "QL", name: "千葉", coordinate: CLLocationCoordinate2D(latitude: 35.5667, longitude: 140.0500)),
        TideStation(id: "CB", name: "千葉港", coordinate: CLLocationCoordinate2D(latitude: 35.6000, longitude: 140.1000)),
        TideStation(id: "TK", name: "東京", coordinate: CLLocationCoordinate2D(latitude: 35.6500, longitude: 139.7667)),
        TideStation(id: "KW", name: "川崎", coordinate: CLLocationCoordinate2D(latitude: 35.5167, longitude: 139.7500)),
        TideStation(id: "YK", name: "京浜港", coordinate: CLLocationCoordinate2D(latitude: 35.4667, longitude: 139.6333)),
        TideStation(id: "QS", name: "横浜", coordinate: CLLocationCoordinate2D(latitude: 35.4500, longitude: 139.6500)),
        TideStation(id: "HM", name: "本牧", coordinate: CLLocationCoordinate2D(latitude: 35.4333, longitude: 139.6667)),
        TideStation(id: "QN", name: "横須賀", coordinate: CLLocationCoordinate2D(latitude: 35.2833, longitude: 139.6500)),
        TideStation(id: "Z1", name: "油壺", coordinate: CLLocationCoordinate2D(latitude: 35.1667, longitude: 139.6167)),
        TideStation(id: "OK", name: "岡田", coordinate: CLLocationCoordinate2D(latitude: 34.7833, longitude: 139.3833)),
        TideStation(id: "QO", name: "神津島", coordinate: CLLocationCoordinate2D(latitude: 34.2167, longitude: 139.1333)),
        TideStation(id: "MJ", name: "三宅島(坪田)", coordinate: CLLocationCoordinate2D(latitude: 34.0500, longitude: 139.5500)),
        TideStation(id: "QP", name: "三宅島(阿古)", coordinate: CLLocationCoordinate2D(latitude: 34.0667, longitude: 139.4833)),
        TideStation(id: "D4", name: "八丈島(八重根)", coordinate: CLLocationCoordinate2D(latitude: 33.1000, longitude: 139.7667)),
        TideStation(id: "QQ", name: "八丈島(神湊)", coordinate: CLLocationCoordinate2D(latitude: 33.1333, longitude: 139.8000)),
        TideStation(id: "CC", name: "父島", coordinate: CLLocationCoordinate2D(latitude: 27.1000, longitude: 142.2000)),
        TideStation(id: "MC", name: "南鳥島", coordinate: CLLocationCoordinate2D(latitude: 24.2833, longitude: 153.9833)),
        TideStation(id: "D8", name: "湘南港", coordinate: CLLocationCoordinate2D(latitude: 35.3000, longitude: 139.4833)),
        TideStation(id: "OD", name: "小田原", coordinate: CLLocationCoordinate2D(latitude: 35.2333, longitude: 139.1500)),
        TideStation(id: "Z3", name: "伊東", coordinate: CLLocationCoordinate2D(latitude: 34.9000, longitude: 139.1333)),
        TideStation(id: "D6", name: "下田", coordinate: CLLocationCoordinate2D(latitude: 34.6833, longitude: 138.9667)),
        TideStation(id: "QK", name: "南伊豆", coordinate: CLLocationCoordinate2D(latitude: 34.6333, longitude: 138.8833)),
        TideStation(id: "G9", name: "石廊崎", coordinate: CLLocationCoordinate2D(latitude: 34.6167, longitude: 138.8500)),
        TideStation(id: "Z4", name: "田子", coordinate: CLLocationCoordinate2D(latitude: 34.8000, longitude: 138.7667)),
        TideStation(id: "UC", name: "内浦", coordinate: CLLocationCoordinate2D(latitude: 35.0167, longitude: 138.8833)),
        TideStation(id: "SM", name: "清水港", coordinate: CLLocationCoordinate2D(latitude: 35.0167, longitude: 138.5167)),
        TideStation(id: "Z5", name: "焼津", coordinate: CLLocationCoordinate2D(latitude: 34.8667, longitude: 138.3333)),
        TideStation(id: "OM", name: "御前崎", coordinate: CLLocationCoordinate2D(latitude: 34.6167, longitude: 138.2167)),
        TideStation(id: "MI", name: "舞阪", coordinate: CLLocationCoordinate2D(latitude: 34.6833, longitude: 137.6167)),
        TideStation(id: "I4", name: "赤羽根", coordinate: CLLocationCoordinate2D(latitude: 34.6000, longitude: 137.1833)),
        TideStation(id: "G4", name: "三河", coordinate: CLLocationCoordinate2D(latitude: 34.7333, longitude: 137.3167)),
        TideStation(id: "G5", name: "形原", coordinate: CLLocationCoordinate2D(latitude: 34.7833, longitude: 137.1833)),
        TideStation(id: "G8", name: "衣浦", coordinate: CLLocationCoordinate2D(latitude: 34.8833, longitude: 136.9500)),
        TideStation(id: "ZD", name: "鬼崎", coordinate: CLLocationCoordinate2D(latitude: 34.9000, longitude: 136.8167)),
        TideStation(id: "NG", name: "名古屋", coordinate: CLLocationCoordinate2D(latitude: 35.0833, longitude: 136.8833)),
        TideStation(id: "G3", name: "四日市港", coordinate: CLLocationCoordinate2D(latitude: 34.9667, longitude: 136.6333)),
        TideStation(id: "TB", name: "鳥羽", coordinate: CLLocationCoordinate2D(latitude: 34.4833, longitude: 136.8167)),
        TideStation(id: "OW", name: "尾鷲", coordinate: CLLocationCoordinate2D(latitude: 34.0833, longitude: 136.2000)),
        TideStation(id: "KN", name: "熊野", coordinate: CLLocationCoordinate2D(latitude: 33.9333, longitude: 136.1667)),
        TideStation(id: "UR", name: "浦神", coordinate: CLLocationCoordinate2D(latitude: 33.5667, longitude: 135.9000)),
        TideStation(id: "KS", name: "串本", coordinate: CLLocationCoordinate2D(latitude: 33.4833, longitude: 135.7667)),
        TideStation(id: "SR", name: "白浜", coordinate: CLLocationCoordinate2D(latitude: 33.6833, longitude: 135.3833)),
        TideStation(id: "GB", name: "御坊", coordinate: CLLocationCoordinate2D(latitude: 33.8500, longitude: 135.1667)),
        TideStation(id: "H1", name: "下津", coordinate: CLLocationCoordinate2D(latitude: 34.1167, longitude: 135.1333)),
        TideStation(id: "Z9", name: "海南", coordinate: CLLocationCoordinate2D(latitude: 34.1500, longitude: 135.2000)),
        TideStation(id: "WY", name: "和歌山", coordinate: CLLocationCoordinate2D(latitude: 34.2167, longitude: 135.1500)),
        TideStation(id: "TN", name: "淡輪", coordinate: CLLocationCoordinate2D(latitude: 34.3333, longitude: 135.1833)),
        TideStation(id: "KK", name: "関空島", coordinate: CLLocationCoordinate2D(latitude: 34.4333, longitude: 135.2000)),
        TideStation(id: "J2", name: "岸和田", coordinate: CLLocationCoordinate2D(latitude: 34.4667, longitude: 135.3667)),
        TideStation(id: "IO", name: "泉大津", coordinate: CLLocationCoordinate2D(latitude: 34.5167, longitude: 135.4000)),
        TideStation(id: "SI", name: "堺", coordinate: CLLocationCoordinate2D(latitude: 34.6000, longitude: 135.4667)),
        TideStation(id: "OS", name: "大阪", coordinate: CLLocationCoordinate2D(latitude: 34.6500, longitude: 135.4333)),
        TideStation(id: "KB", name: "神戸", coordinate: CLLocationCoordinate2D(latitude: 34.6833, longitude: 135.2167)),
        TideStation(id: "Q4", name: "尼崎", coordinate: CLLocationCoordinate2D(latitude: 34.7000, longitude: 135.3833)),
        TideStation(id: "NS", name: "西宮", coordinate: CLLocationCoordinate2D(latitude: 34.7167, longitude: 135.3500)),
        TideStation(id: "AK", name: "明石", coordinate: CLLocationCoordinate2D(latitude: 34.6500, longitude: 134.9833)),
        TideStation(id: "ST", name: "洲本", coordinate: CLLocationCoordinate2D(latitude: 34.3500, longitude: 134.9000)),
        TideStation(id: "EI", name: "江井", coordinate: CLLocationCoordinate2D(latitude: 34.4667, longitude: 134.8333)),
        TideStation(id: "K1", name: "姫路(飾磨)", coordinate: CLLocationCoordinate2D(latitude: 34.7833, longitude: 134.6667)),
        TideStation(id: "SB", name: "三蟠", coordinate: CLLocationCoordinate2D(latitude: 34.6000, longitude: 133.9833)),
        TideStation(id: "UN", name: "宇野", coordinate: CLLocationCoordinate2D(latitude: 34.4833, longitude: 133.9500)),
        TideStation(id: "MM", name: "水島", coordinate: CLLocationCoordinate2D(latitude: 34.5333, longitude: 133.7333)),
        TideStation(id: "LG", name: "乙島", coordinate: CLLocationCoordinate2D(latitude: 34.5000, longitude: 133.6833)),
        TideStation(id: "IZ", name: "糸崎", coordinate: CLLocationCoordinate2D(latitude: 34.4000, longitude: 133.0833)),
        TideStation(id: "TH", name: "竹原", coordinate: CLLocationCoordinate2D(latitude: 34.3333, longitude: 132.9167)),
        TideStation(id: "Q9", name: "呉", coordinate: CLLocationCoordinate2D(latitude: 34.2333, longitude: 132.5500)),
        TideStation(id: "Q8", name: "広島", coordinate: CLLocationCoordinate2D(latitude: 34.3500, longitude: 132.4667)),
        TideStation(id: "QA", name: "徳山", coordinate: CLLocationCoordinate2D(latitude: 34.0333, longitude: 131.8000)),
        TideStation(id: "J9", name: "三田尻", coordinate: CLLocationCoordinate2D(latitude: 34.0333, longitude: 131.5833)),
        TideStation(id: "WH", name: "宇部", coordinate: CLLocationCoordinate2D(latitude: 33.9333, longitude: 131.2500)),
        TideStation(id: "CF", name: "長府", coordinate: CLLocationCoordinate2D(latitude: 34.0167, longitude: 131.0000)),
        TideStation(id: "A1", name: "弟子待", coordinate: CLLocationCoordinate2D(latitude: 33.9333, longitude: 130.9333)),
        TideStation(id: "TI", name: "田ノ首", coordinate: CLLocationCoordinate2D(latitude: 33.9167, longitude: 130.9167)),
        TideStation(id: "OH", name: "大山の鼻", coordinate: CLLocationCoordinate2D(latitude: 33.9167, longitude: 130.9000)),
        TideStation(id: "HR", name: "南風泊", coordinate: CLLocationCoordinate2D(latitude: 33.9500, longitude: 130.8833)),
        TideStation(id: "MT", name: "松山", coordinate: CLLocationCoordinate2D(latitude: 33.8667, longitude: 132.7167)),
        TideStation(id: "M3", name: "波止浜", coordinate: CLLocationCoordinate2D(latitude: 34.1000, longitude: 132.9333)),
        TideStation(id: "M0", name: "今治市小島", coordinate: CLLocationCoordinate2D(latitude: 34.1333, longitude: 132.9833)),
        TideStation(id: "M1", name: "来島航路", coordinate: CLLocationCoordinate2D(latitude: 34.1167, longitude: 132.9833)),
        TideStation(id: "L0", name: "今治", coordinate: CLLocationCoordinate2D(latitude: 34.0667, longitude: 133.0000)),
        TideStation(id: "NI", name: "新居浜", coordinate: CLLocationCoordinate2D(latitude: 33.9667, longitude: 133.2667)),
        TideStation(id: "L8", name: "伊予三島", coordinate: CLLocationCoordinate2D(latitude: 33.9833, longitude: 133.5500)),
        TideStation(id: "TX", name: "多度津", coordinate: CLLocationCoordinate2D(latitude: 34.2833, longitude: 133.7500)),
        TideStation(id: "AX", name: "青木", coordinate: CLLocationCoordinate2D(latitude: 34.3667, longitude: 133.6833)),
        TideStation(id: "J8", name: "与島", coordinate: CLLocationCoordinate2D(latitude: 34.3833, longitude: 133.8167)),
        TideStation(id: "TA", name: "高松", coordinate: CLLocationCoordinate2D(latitude: 34.3500, longitude: 134.0500)),
        TideStation(id: "KM", name: "小松島", coordinate: CLLocationCoordinate2D(latitude: 34.0167, longitude: 134.5833)),
        TideStation(id: "J6", name: "橘", coordinate: CLLocationCoordinate2D(latitude: 33.8667, longitude: 134.6333)),
        TideStation(id: "AW", name: "阿波由岐", coordinate: CLLocationCoordinate2D(latitude: 33.7667, longitude: 134.6000)),
        TideStation(id: "HW", name: "日和佐", coordinate: CLLocationCoordinate2D(latitude: 33.7167, longitude: 134.5500)),
        TideStation(id: "L7", name: "甲浦", coordinate: CLLocationCoordinate2D(latitude: 33.5500, longitude: 134.3000)),
        TideStation(id: "MU", name: "室戸岬", coordinate: CLLocationCoordinate2D(latitude: 33.2667, longitude: 134.1667)),
        TideStation(id: "KC", name: "高知", coordinate: CLLocationCoordinate2D(latitude: 33.5000, longitude: 133.5667)),
        TideStation(id: "V7", name: "須崎", coordinate: CLLocationCoordinate2D(latitude: 33.3833, longitude: 133.3000)),
        TideStation(id: "ZH", name: "久礼", coordinate: CLLocationCoordinate2D(latitude: 33.3333, longitude: 133.2500)),
        TideStation(id: "L6", name: "高知下田", coordinate: CLLocationCoordinate2D(latitude: 32.9333, longitude: 133.0000)),
        TideStation(id: "TS", name: "土佐清水", coordinate: CLLocationCoordinate2D(latitude: 32.7833, longitude: 132.9667)),
        TideStation(id: "SU", name: "片島", coordinate: CLLocationCoordinate2D(latitude: 32.9167, longitude: 132.7000)),
        TideStation(id: "UW", name: "宇和島", coordinate: CLLocationCoordinate2D(latitude: 33.2333, longitude: 132.5500)),
        TideStation(id: "N1", name: "日明", coordinate: CLLocationCoordinate2D(latitude: 33.9167, longitude: 130.8833)),
        TideStation(id: "N0", name: "砂津", coordinate: CLLocationCoordinate2D(latitude: 33.9000, longitude: 130.8833)),
        TideStation(id: "MO", name: "門司", coordinate: CLLocationCoordinate2D(latitude: 33.9500, longitude: 130.9500)),
        TideStation(id: "AH", name: "青浜", coordinate: CLLocationCoordinate2D(latitude: 33.9500, longitude: 131.0167)),
        TideStation(id: "O3", name: "苅田", coordinate: CLLocationCoordinate2D(latitude: 33.8000, longitude: 131.0000)),
        TideStation(id: "BP", name: "別府", coordinate: CLLocationCoordinate2D(latitude: 33.3000, longitude: 131.5000)),
        TideStation(id: "QC", name: "大分", coordinate: CLLocationCoordinate2D(latitude: 33.2667, longitude: 131.6833)),
        TideStation(id: "X5", name: "佐伯", coordinate: CLLocationCoordinate2D(latitude: 32.9500, longitude: 131.9667)),
        TideStation(id: "Z6", name: "細島", coordinate: CLLocationCoordinate2D(latitude: 32.4333, longitude: 131.6667)),
        TideStation(id: "MG", name: "宮崎", coordinate: CLLocationCoordinate2D(latitude: 31.9000, longitude: 131.4500)),
        TideStation(id: "AB", name: "油津", coordinate: CLLocationCoordinate2D(latitude: 31.5833, longitude: 131.4167)),
        TideStation(id: "X6", name: "志布志", coordinate: CLLocationCoordinate2D(latitude: 31.4833, longitude: 131.1167)),
        TideStation(id: "QG", name: "大泊", coordinate: CLLocationCoordinate2D(latitude: 31.0167, longitude: 130.6833)),
        TideStation(id: "KG", name: "鹿児島", coordinate: CLLocationCoordinate2D(latitude: 31.6000, longitude: 130.5667)),
        TideStation(id: "MK", name: "枕崎", coordinate: CLLocationCoordinate2D(latitude: 31.2667, longitude: 130.3000)),
        TideStation(id: "ZJ", name: "阿久根", coordinate: CLLocationCoordinate2D(latitude: 32.0167, longitude: 130.1833)),
        TideStation(id: "QH", name: "西之表", coordinate: CLLocationCoordinate2D(latitude: 30.7333, longitude: 131.0000)),
        TideStation(id: "TJ", name: "種子島", coordinate: CLLocationCoordinate2D(latitude: 30.4667, longitude: 130.9667)),
        TideStation(id: "QI", name: "中之島", coordinate: CLLocationCoordinate2D(latitude: 29.8500, longitude: 129.8500)),
        TideStation(id: "QJ", name: "名瀬", coordinate: CLLocationCoordinate2D(latitude: 28.4000, longitude: 129.5000)),
        TideStation(id: "O9", name: "奄美", coordinate: CLLocationCoordinate2D(latitude: 28.3167, longitude: 129.5333)),
        TideStation(id: "NK", name: "中城湾港", coordinate: CLLocationCoordinate2D(latitude: 26.3333, longitude: 127.8333)),
        TideStation(id: "ZO", name: "沖縄", coordinate: CLLocationCoordinate2D(latitude: 26.1833, longitude: 127.8167)),
        TideStation(id: "NH", name: "那覇", coordinate: CLLocationCoordinate2D(latitude: 26.2167, longitude: 127.6667)),
        TideStation(id: "DJ", name: "南大東", coordinate: CLLocationCoordinate2D(latitude: 25.8667, longitude: 131.2333)),
        TideStation(id: "R1", name: "平良", coordinate: CLLocationCoordinate2D(latitude: 24.8167, longitude: 125.2833)),
        TideStation(id: "IS", name: "石垣", coordinate: CLLocationCoordinate2D(latitude: 24.3333, longitude: 124.1667)),
        TideStation(id: "IJ", name: "西表", coordinate: CLLocationCoordinate2D(latitude: 24.3500, longitude: 123.7500)),
        TideStation(id: "YJ", name: "与那国", coordinate: CLLocationCoordinate2D(latitude: 24.4500, longitude: 122.9500)),
        TideStation(id: "O7", name: "水俣", coordinate: CLLocationCoordinate2D(latitude: 32.2000, longitude: 130.3667)),
        TideStation(id: "O5", name: "八代", coordinate: CLLocationCoordinate2D(latitude: 32.5167, longitude: 130.5667)),
        TideStation(id: "HS", name: "本渡瀬戸", coordinate: CLLocationCoordinate2D(latitude: 32.4333, longitude: 130.2167)),
        TideStation(id: "RH", name: "苓北", coordinate: CLLocationCoordinate2D(latitude: 32.4667, longitude: 130.0333)),
        TideStation(id: "MS", name: "三角", coordinate: CLLocationCoordinate2D(latitude: 32.6167, longitude: 130.4500)),
        TideStation(id: "KU", name: "熊本", coordinate: CLLocationCoordinate2D(latitude: 32.7500, longitude: 130.5667)),
        TideStation(id: "O6", name: "大牟田", coordinate: CLLocationCoordinate2D(latitude: 33.0167, longitude: 130.4167)),
        TideStation(id: "OU", name: "大浦", coordinate: CLLocationCoordinate2D(latitude: 32.9833, longitude: 130.2167)),
        TideStation(id: "KT", name: "口之津", coordinate: CLLocationCoordinate2D(latitude: 32.6000, longitude: 130.2000)),
        TideStation(id: "NS", name: "長崎", coordinate: CLLocationCoordinate2D(latitude: 32.7333, longitude: 129.8667)),
        TideStation(id: "KO", name: "皇后", coordinate: CLLocationCoordinate2D(latitude: 32.7167, longitude: 129.8333)),
        TideStation(id: "FE", name: "福江", coordinate: CLLocationCoordinate2D(latitude: 32.7000, longitude: 128.8500)),
        TideStation(id: "QD", name: "佐世保", coordinate: CLLocationCoordinate2D(latitude: 33.1500, longitude: 129.7167)),
        TideStation(id: "X2", name: "平戸瀬戸", coordinate: CLLocationCoordinate2D(latitude: 33.3667, longitude: 129.5833)),
        TideStation(id: "ZL", name: "仮屋", coordinate: CLLocationCoordinate2D(latitude: 33.4667, longitude: 129.8500)),
        TideStation(id: "KA", name: "唐津", coordinate: CLLocationCoordinate2D(latitude: 33.4667, longitude: 129.9667)),
        TideStation(id: "QF", name: "博多", coordinate: CLLocationCoordinate2D(latitude: 33.6167, longitude: 130.4000)),
        TideStation(id: "X3", name: "郷ノ浦", coordinate: CLLocationCoordinate2D(latitude: 33.7500, longitude: 129.6833)),
        TideStation(id: "QE", name: "厳原", coordinate: CLLocationCoordinate2D(latitude: 34.2000, longitude: 129.3000)),
        TideStation(id: "O1", name: "対馬", coordinate: CLLocationCoordinate2D(latitude: 34.2667, longitude: 129.3167)),
        TideStation(id: "N5", name: "対馬比田勝", coordinate: CLLocationCoordinate2D(latitude: 34.6500, longitude: 129.4833)),
        TideStation(id: "K5", name: "萩", coordinate: CLLocationCoordinate2D(latitude: 34.4333, longitude: 131.4167)),
        TideStation(id: "ZK", name: "須佐", coordinate: CLLocationCoordinate2D(latitude: 34.6333, longitude: 131.6000)),
        TideStation(id: "HA", name: "浜田", coordinate: CLLocationCoordinate2D(latitude: 34.9000, longitude: 132.0667)),
        TideStation(id: "SK", name: "境", coordinate: CLLocationCoordinate2D(latitude: 35.5500, longitude: 133.2500)),
        TideStation(id: "SA", name: "西郷", coordinate: CLLocationCoordinate2D(latitude: 36.2000, longitude: 133.3333)),
        TideStation(id: "ZE", name: "田後", coordinate: CLLocationCoordinate2D(latitude: 35.6000, longitude: 134.3167)),
        TideStation(id: "T6", name: "津居山", coordinate: CLLocationCoordinate2D(latitude: 35.6500, longitude: 134.8333)),
        TideStation(id: "T2", name: "宮津", coordinate: CLLocationCoordinate2D(latitude: 35.5333, longitude: 135.2000)),
        TideStation(id: "MZ", name: "舞鶴", coordinate: CLLocationCoordinate2D(latitude: 35.4833, longitude: 135.3833)),
        TideStation(id: "XM", name: "敦賀", coordinate: CLLocationCoordinate2D(latitude: 35.6667, longitude: 136.0667)),
        TideStation(id: "ZG", name: "三国", coordinate: CLLocationCoordinate2D(latitude: 36.2500, longitude: 136.1500)),
        TideStation(id: "T1", name: "金沢", coordinate: CLLocationCoordinate2D(latitude: 36.6167, longitude: 136.6000)),
        TideStation(id: "Z7", name: "輪島", coordinate: CLLocationCoordinate2D(latitude: 37.4000, longitude: 136.9000)),
        TideStation(id: "SZ", name: "能登", coordinate: CLLocationCoordinate2D(latitude: 37.5000, longitude: 137.1500)),
        TideStation(id: "XO", name: "七尾", coordinate: CLLocationCoordinate2D(latitude: 37.0500, longitude: 136.9667)),
        TideStation(id: "XQ", name: "伏木富山", coordinate: CLLocationCoordinate2D(latitude: 36.8000, longitude: 137.0667)),
        TideStation(id: "SN", name: "新湊", coordinate: CLLocationCoordinate2D(latitude: 36.7833, longitude: 137.1167)),
        TideStation(id: "TY", name: "富山", coordinate: CLLocationCoordinate2D(latitude: 36.7667, longitude: 137.2167)),
        TideStation(id: "I7", name: "生地", coordinate: CLLocationCoordinate2D(latitude: 36.8833, longitude: 137.4167)),
        TideStation(id: "T3", name: "直江津", coordinate: CLLocationCoordinate2D(latitude: 37.1833, longitude: 138.2500)),
        TideStation(id: "ZC", name: "柏崎", coordinate: CLLocationCoordinate2D(latitude: 37.3500, longitude: 138.5167)),
        TideStation(id: "S6", name: "新潟西港", coordinate: CLLocationCoordinate2D(latitude: 37.9333, longitude: 139.0667)),
        TideStation(id: "I5", name: "新潟東港", coordinate: CLLocationCoordinate2D(latitude: 37.9833, longitude: 139.2167)),
        TideStation(id: "ZN", name: "小木", coordinate: CLLocationCoordinate2D(latitude: 37.8167, longitude: 138.2833)),
        TideStation(id: "RZ", name: "両津", coordinate: CLLocationCoordinate2D(latitude: 38.0833, longitude: 138.4333)),
        TideStation(id: "S0", name: "佐渡", coordinate: CLLocationCoordinate2D(latitude: 38.3167, longitude: 138.5167)),
        TideStation(id: "QR", name: "粟島", coordinate: CLLocationCoordinate2D(latitude: 38.4667, longitude: 139.2500)),
        TideStation(id: "ZB", name: "鼠ヶ関", coordinate: CLLocationCoordinate2D(latitude: 38.5667, longitude: 139.5500)),
        TideStation(id: "S9", name: "酒田", coordinate: CLLocationCoordinate2D(latitude: 38.9167, longitude: 139.8167)),
        TideStation(id: "ZQ", name: "飛島", coordinate: CLLocationCoordinate2D(latitude: 39.1833, longitude: 139.5500)),
        TideStation(id: "S1", name: "秋田", coordinate: CLLocationCoordinate2D(latitude: 39.7500, longitude: 140.0667)),
        TideStation(id: "S2", name: "船川港", coordinate: CLLocationCoordinate2D(latitude: 39.9167, longitude: 139.8500)),
        TideStation(id: "ZI", name: "男鹿", coordinate: CLLocationCoordinate2D(latitude: 39.9500, longitude: 139.7000)),
        TideStation(id: "FK", name: "深浦", coordinate: CLLocationCoordinate2D(latitude: 40.6500, longitude: 139.9333))
    ]
    
    // 最寄りの観測所を探す
    func findNearestStation(location: CLLocation) {
        let sortedStations = stations.sorted {
            let loc1 = CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
            let loc2 = CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude)
            return location.distance(from: loc1) < location.distance(from: loc2)
        }
        
        guard let nearest = sortedStations.first else { return }
        
        // 既に同じ地点を表示中ならリロードしない
        if self.nearestStation?.id != nearest.id || self.currentTideData == nil {
            self.nearestStation = nearest
            // Infinite loop prevention: Set currentDate explicitly to trigger update
            // This is the entry point for initialization
            self.currentDate = Calendar.current.startOfDay(for: Date())
        }
    }
    
    // 日付変更 (スワイプ用)
    func changeDate(by days: Int) {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .day, value: days, to: currentDate) {
            // currentDate is already normalized, so adding days keeps it normalized
            self.currentDate = newDate
        }
    }
    
    private func updateCurrentTideData() {
        let key = self.dateFormatter.string(from: currentDate)
        if let data = self.tideDataCache[key] {
            self.currentTideData = data
        } else if let station = nearestStation {
            // データがない場合 (年が変わった等)
            fetchTideData(for: station, date: currentDate)
        }
    }
    
    // 気象庁のテキストデータを取得してパースする
    func fetchTideData(for station: TideStation, date: Date) {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        
        // 簡易チェック: その年のデータがキャッシュに少しでもあればOKとする
        let keyPrefix = "\(year)-"
        if self.tideDataCache.keys.contains(where: { $0.hasPrefix(keyPrefix) }) {
             // Cache hit logic
             let key = self.dateFormatter.string(from: date)
             if let data = self.tideDataCache[key] {
                 self.currentTideData = data
             }
             return
        }
        
        // Fetch new data
        self.isLoading = true
        self.errorMessage = nil
            
        let urlString = "https://www.data.jma.go.jp/gmd/kaiyou/data/db/tide/suisan/txt/\(year)/\(station.id).txt"
        
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid URL"
            self.isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.errorMessage = error.localizedDescription
                }
                return
            }
            
            guard let data = data, let text = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.errorMessage = "Data decoding failed"
                }
                return
            }
            
            // Background processing
            // Use local self? to call instance method
            let (cache, current) = self?.parseAllJMATextAndGetResult(text, station: station, targetDate: date) ?? ([:], nil)
            
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.cachedText = text
                self?.tideDataCache = cache
                self?.currentTideData = current
            }
        }.resume()
    }
    
    // テキスト全体をパースしてキャッシュと現在データを返す（バックグラウンド実行用）
    private func parseAllJMATextAndGetResult(_ text: String, station: TideStation, targetDate: Date) -> ([String: TideData], TideData?) {
        var tempCache: [String: TideData] = [:]
        var targetData: TideData?
        
        let lines = text.components(separatedBy: .newlines)
        
        // Local formatter for background thread safety and performance
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let targetKey = formatter.string(from: targetDate)
        
        for line in lines {
            let chars = Array(line)
            guard chars.count >= 80 else { continue }
            
            // 1. Hourly Data (0-72: 24 * 3 chars)
            var hourlyLevels: [HourlyTideLevel] = []
            for hour in 0..<24 {
                let start = hour * 3
                if start + 3 <= chars.count {
                    let valStr = String(chars[start..<start+3]).trimmingCharacters(in: .whitespaces)
                    if let val = Int(valStr) {
                        hourlyLevels.append(HourlyTideLevel(hour: hour, level: val))
                    }
                }
            }
            
            // 2. Date
            let yyStr = String(chars[72..<74]).trimmingCharacters(in: .whitespaces)
            let mmStr = String(chars[74..<76]).trimmingCharacters(in: .whitespaces)
            let ddStr = String(chars[76..<78]).trimmingCharacters(in: .whitespaces)
            
            guard let yy = Int(yyStr), let mm = Int(mmStr), let dd = Int(ddStr) else { continue }
            let year = 2000 + yy
            
            var dateComponents = DateComponents()
            dateComponents.year = year
            dateComponents.month = mm
            dateComponents.day = dd
            guard let date = Calendar.current.date(from: dateComponents) else { continue }
            
            // 3. High/Low Tides
            let highTides = parseTideEventsFromChars(chars, startOffset: 80, count: 4)
            let lowTides = parseTideEventsFromChars(chars, startOffset: 108, count: 4)
            
            let tideType = calculateTideType(date: date)
            
            let tideData = TideData(
                station: station,
                date: date,
                hourlyLevels: hourlyLevels,
                highTides: highTides,
                lowTides: lowTides,
                tideType: tideType
            )
            
            let key = formatter.string(from: date)
            tempCache[key] = tideData
            
            if key == targetKey {
                targetData = tideData
            }
        }
        
        return (tempCache, targetData)
    }
    
    private func parseTideEventsFromChars(_ chars: [Character], startOffset: Int, count: Int) -> [(time: String, level: Int)] {
        var events: [(time: String, level: Int)] = []
        
        for i in 0..<count {
            let offset = startOffset + (i * 7)
            if offset + 7 <= chars.count {
                let chunk = String(chars[offset..<offset+7])
                if chunk.contains("9999") { continue }
                
                let levelStr = chunk.suffix(3).trimmingCharacters(in: .whitespaces)
                
                if let level = Int(levelStr), let timeInt = Int(chunk.prefix(4).replacingOccurrences(of: " ", with: "0")) {
                     let hh = timeInt / 100
                     let mm = timeInt % 100
                     if hh < 24 && mm < 60 {
                        let formattedTime = String(format: "%02d:%02d", hh, mm)
                        events.append((time: formattedTime, level: level))
                     }
                }
            }
        }
        return events
    }
    
    private func calculateTideType(date: Date) -> String {
        // 日本時間基準
        let jst = TimeZone(identifier: "Asia/Tokyo")!
    
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = jst
    
        // 2024/01/11 20:57 JST（実際の新月時刻）
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 11
        components.hour = 20
        components.minute = 57
        components.timeZone = jst
    
        guard let baseNewMoon = calendar.date(from: components) else {
            return ""
        }

        // 平均朔望月
        let synodicMonth = 29.530588853
    
        // 秒差 → 日数
        let seconds = date.timeIntervalSince(baseNewMoon)
        let daysPassed = seconds / 86400.0
    
        // 月齢
        var moonAge = daysPassed.truncatingRemainder(dividingBy: synodicMonth)
    
        if moonAge < 0 {
            moonAge += synodicMonth
        }
    
        // 潮名判定（実務寄りに境界を少し広め）
        switch moonAge {
        case 0.0..<2.5,
             13.5..<17.0,
             28.0..<29.6:
            return "大潮"
        
        case 2.5..<6.0,
             11.0..<13.5,
             17.0..<20.0,
             26.0..<28.0:
            return "中潮"
        
        case 6.0..<10.0,
             20.0..<23.0:
            return "小潮"
        
        case 10.0..<11.0,
             23.0..<24.0:
            return "長潮"
        
        case 24.0..<26.0:
          return "若潮"
        
        default:
            return "中潮"
        }
    }
}
