import Foundation

struct GhostDataPoint {
    let timeOffset: TimeInterval
    let distance: Double
    let pace: Double
    let spm: Int
}

class GhostRaceTracker {
    let record: RowingRecord
    var timeline: [GhostDataPoint] = []
    
    init(record: RowingRecord) {
        self.record = record
        calculateTimeline()
    }
    
    private func calculateTimeline() {
        guard let points = record.dataPoints, !points.isEmpty else {
            // dataPointsが無い場合は、全体平均から一定速度で走らせるフォールバックを作る
            let avgSpeed = record.distance / max(record.duration, 1) // m/s
            let totalSec = Int(record.duration)
            for s in 0...totalSec {
                timeline.append(GhostDataPoint(
                    timeOffset: Double(s),
                    distance: Double(s) * avgSpeed,
                    pace: record.averagePace,
                    spm: record.averageSPM
                ))
            }
            return
        }
        
        // 時系列データがある場合
        let sortedPoints = points.sorted { $0.timeOffset < $1.timeOffset }
        
        // 過去のデータポイントに distance（累積距離）の記録が含まれているか判定
        let hasDistance = sortedPoints.contains { $0.distance != nil }
        
        if hasDistance {
            // 新仕様: 保存された距離データを直接使用する
            for p in sortedPoints {
                timeline.append(GhostDataPoint(
                    timeOffset: p.timeOffset,
                    distance: p.distance ?? 0.0,
                    pace: p.pace,
                    spm: p.spm
                ))
            }
        } else {
            // 旧仕様 (互換性維持): pace から累積距離を算出する
            var currentDist = 0.0
            timeline.append(GhostDataPoint(
                timeOffset: 0,
                distance: 0,
                pace: sortedPoints.first?.pace ?? record.averagePace,
                spm: sortedPoints.first?.spm ?? record.averageSPM
            ))
            
            for i in 1..<sortedPoints.count {
                let prev = sortedPoints[i-1]
                let curr = sortedPoints[i]
                
                let dt = curr.timeOffset - prev.timeOffset
                let pace = curr.pace > 0 ? curr.pace : record.averagePace
                let speed = pace > 0 ? (500.0 / pace) : 0.0
                let dd = dt * speed
                currentDist += dd
                
                timeline.append(GhostDataPoint(
                    timeOffset: curr.timeOffset,
                    distance: currentDist,
                    pace: pace,
                    spm: curr.spm
                ))
            }
        }
    }
    
    /// 与えられた経過秒数におけるゴーストの状態を返す
    func getStatus(at time: TimeInterval) -> (distance: Double, pace: Double, spm: Int) {
        guard !timeline.isEmpty else { return (0, 0, 0) }
        
        if time <= 0 {
            let first = timeline.first!
            return (first.distance, first.pace, first.spm)
        }
        
        if time >= timeline.last!.timeOffset {
            let last = timeline.last!
            // ゴール後は最大距離で固定
            return (last.distance, last.pace, last.spm)
        }
        
        // 二分探索で該当区間を検索
        var low = 0
        var high = timeline.count - 1
        
        while low < high - 1 {
            let mid = (low + high) / 2
            if timeline[mid].timeOffset <= time {
                low = mid
            } else {
                high = mid
            }
        }
        
        let p0 = timeline[low]
        let p1 = timeline[high]
        
        let tDiff = p1.timeOffset - p0.timeOffset
        guard tDiff > 0 else { return (p0.distance, p0.pace, p0.spm) }
        
        let ratio = (time - p0.timeOffset) / tDiff
        let dist = p0.distance + (p1.distance - p0.distance) * ratio
        let pace = p0.pace + (p1.pace - p0.pace) * ratio
        
        // SPMは線形補間して四捨五入
        let spm = Int(round(Double(p0.spm) + Double(p1.spm - p0.spm) * ratio))
        
        return (dist, pace, spm)
    }
}
