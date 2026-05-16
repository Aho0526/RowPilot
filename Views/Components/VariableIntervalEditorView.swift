import SwiftUI

struct VariableIntervalEditorView: View {
    @Environment(\.dismiss) var dismiss
    
    let isEditing: Bool
    @State var useDistance: Bool
    @State var distanceStr: String
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
        
        self._useDistance = State(initialValue: initialEntry.distanceMeters != nil)
        self._distanceStr = State(initialValue: initialEntry.distanceMeters.map { "\($0)" } ?? "")
        
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
                        Picker("Interval Type", selection: $useDistance) {
                            Text("Distance".localized).tag(true)
                            Text("Time".localized).tag(false)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        // 距離 or 時間入力
                        if useDistance {
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
                        } else {
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
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func save() {
        let restSecs = min(restM * 60 + restS, 595)
        let paceSecs = showPace ? (paceM * 60 + paceS) : nil
        
        if useDistance {
            if let dist = Int(distanceStr) {
                let entry = VariableIntervalEntry(distanceMeters: dist, timeSeconds: nil, restSeconds: restSecs, targetPace500mSeconds: paceSecs)
                onSave(entry)
                dismiss()
            }
        } else {
            let totalSecs = timeH * 3600 + timeM * 60 + timeS
            if totalSecs >= 20 {
                let entry = VariableIntervalEntry(distanceMeters: nil, timeSeconds: totalSecs, restSeconds: restSecs, targetPace500mSeconds: paceSecs)
                onSave(entry)
                dismiss()
            }
        }
    }
}
