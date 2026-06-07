import SwiftUI

struct VariableIntervalEditorView: View {
    @Environment(\.dismiss) var dismiss
    
    let isEditing: Bool
    @State var intervalType: Int // 0: Distance, 1: Time, 2: Calories
    @State var distanceStr: String
    @State var caloriesStr: String
    @State var timeH: Int
    @State var timeM: Int
    @State var timeS: Int
    @State var restM: Int
    @State var restS: Int
    @State var showPace: Bool
    @State var paceM: Int
    @State var paceS: Int
    
    let onSave: (VariableIntervalEntry) -> Void
    
    init(entry: VariableIntervalEntry?, onSave: @escaping (VariableIntervalEntry) -> Void) {
        self.isEditing = entry != nil
        self.onSave = onSave
        
        let initialEntry = entry ?? VariableIntervalEntry.distanceEntry(meters: 500, rest: 60)
        
        if initialEntry.distanceMeters != nil {
            self._intervalType = State(initialValue: 0)
        } else if initialEntry.timeSeconds != nil {
            self._intervalType = State(initialValue: 1)
        } else {
            self._intervalType = State(initialValue: 2)
        }
        
        self._distanceStr = State(initialValue: initialEntry.distanceMeters.map { "\($0)" } ?? "")
        self._caloriesStr = State(initialValue: initialEntry.calories.map { "\($0)" } ?? "")
        
        let totalTime = initialEntry.timeSeconds ?? 0
        self._timeH = State(initialValue: totalTime / 3600)
        self._timeM = State(initialValue: (totalTime % 3600) / 60)
        self._timeS = State(initialValue: totalTime % 60)
        
        let rest = initialEntry.restSeconds
        self._restM = State(initialValue: rest / 60)
        self._restS = State(initialValue: rest % 60)
        
        if let pace = initialEntry.targetPace500mSeconds {
            self._showPace = State(initialValue: true)
            self._paceM = State(initialValue: pace / 60)
            self._paceS = State(initialValue: pace % 60)
        } else {
            self._showPace = State(initialValue: false)
            self._paceM = State(initialValue: 1)
            self._paceS = State(initialValue: 40)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        Picker("Interval Type", selection: $intervalType) {
                            Text("Distance".localized).tag(0)
                            Text("Time".localized).tag(1)
                            Text("Calories".localized).tag(2)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        // 距離 or 時間 or カロリー入力
                        if intervalType == 0 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Interval Distance".localized + " (m)")
                                    .foregroundColor(Theme.textSecondary)
                                TextField("100 - 60000", text: $distanceStr)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                    .font(.title)
                            }
                        } else if intervalType == 1 {
                            VStack(spacing: 8) {
                                Text("Interval Time".localized)
                                    .foregroundColor(Theme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                HStack(spacing: 0) {
                                    TimePickerColumn(value: $timeH, range: 0...9, label: "hh")
                                    Text(":").font(.title).foregroundColor(.white).offset(y: -10)
                                    TimePickerColumn(value: $timeM, range: 0...59, label: "mm")
                                    Text(":").font(.title).foregroundColor(.white).offset(y: -10)
                                    TimePickerColumn(value: $timeS, range: 0...59, label: "ss")
                                }
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(16)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Calories".localized + " (cal)")
                                    .foregroundColor(Theme.textSecondary)
                                TextField("5 - 65535", text: $caloriesStr)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                    .font(.title)
                            }
                        }
                        
                        // 休憩時間
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rest Duration (Max 9:55)".localized)
                                .foregroundColor(Theme.textSecondary)
                            HStack(spacing: 0) {
                                Spacer()
                                TimePickerColumn(value: $restM, range: 0...9, label: "mm")
                                Text(":").font(.title).foregroundColor(.white).offset(y: -10)
                                TimePickerColumn(value: $restS, range: 0...59, label: "ss")
                                Spacer()
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                        }
                        
                        // ターゲットペース（オプション）
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: $showPace) {
                                Text("Target Pace".localized)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .tint(Theme.accent)
                            
                            if showPace {
                                HStack(spacing: 0) {
                                    Spacer()
                                    TimePickerColumn(value: $paceM, range: 1...9, label: "mm")
                                    Text(":").font(.title).foregroundColor(.white).offset(y: -10)
                                    TimePickerColumn(value: $paceS, range: 0...59, label: "ss")
                                    Spacer()
                                }
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(16)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(isEditing ? "Edit Interval".localized : "Add Interval".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save".localized) {
                        save()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var isSaveDisabled: Bool {
        if intervalType == 0 {
            guard let dist = Int(distanceStr) else { return true }
            return dist < 100 || dist > 60000
        } else if intervalType == 1 {
            let totalSecs = timeH * 3600 + timeM * 60 + timeS
            return totalSecs < 20 || totalSecs > 36000
        } else {
            guard let cals = Int(caloriesStr) else { return true }
            return cals < 5 || cals > 65535
        }
    }
    
    private func save() {
        let restSecs = min(restM * 60 + restS, 595)
        let paceSecs = showPace ? (paceM * 60 + paceS) : nil
        
        if intervalType == 0 {
            if let dist = Int(distanceStr), dist >= 100 {
                let entry = VariableIntervalEntry(distanceMeters: dist, timeSeconds: nil, calories: nil, restSeconds: restSecs, targetPace500mSeconds: paceSecs)
                onSave(entry)
                dismiss()
            }
        } else if intervalType == 1 {
            let totalSecs = timeH * 3600 + timeM * 60 + timeS
            if totalSecs >= 20 {
                let entry = VariableIntervalEntry(distanceMeters: nil, timeSeconds: totalSecs, calories: nil, restSeconds: restSecs, targetPace500mSeconds: paceSecs)
                onSave(entry)
                dismiss()
            }
        } else {
            if let cals = Int(caloriesStr), cals >= 5 {
                let entry = VariableIntervalEntry(distanceMeters: nil, timeSeconds: nil, calories: cals, restSeconds: restSecs, targetPace500mSeconds: paceSecs)
                onSave(entry)
                dismiss()
            }
        }
    }
}
