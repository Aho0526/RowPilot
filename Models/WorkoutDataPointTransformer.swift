import Foundation

/// WorkoutDataPoint配列をJSON Data として CoreData に保存するカスタムTransformer
@objc(WorkoutDataPointTransformer)
final class WorkoutDataPointTransformer: ValueTransformer {
    
    override class func transformedValueClass() -> AnyClass {
        return NSData.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    /// [WorkoutDataPoint] -> Data (保存時)
    override func transformedValue(_ value: Any?) -> Any? {
        guard let points = value as? [WorkoutDataPoint] else { return nil }
        do {
            let data = try JSONEncoder().encode(points)
            return data as NSData
        } catch {
            print("WorkoutDataPointTransformer: Encode error: \(error)")
            return nil
        }
    }
    
    /// Data -> [WorkoutDataPoint] (読み込み時)
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        do {
            return try JSONDecoder().decode([WorkoutDataPoint].self, from: data)
        } catch {
            print("WorkoutDataPointTransformer: Decode error: \(error)")
            return nil
        }
    }
    
    /// AppDelegate や App init で呼び出して登録する
    static func register() {
        let name = NSValueTransformerName(rawValue: "WorkoutDataPointTransformer")
        ValueTransformer.setValueTransformer(WorkoutDataPointTransformer(), forName: name)
    }
}
