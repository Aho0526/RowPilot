import SwiftUI

struct WorkoutSetupView: View {
    @ObservedObject var ergManager: RowErgManager
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Select Workout Type".localized)
                    .font(Theme.headerFont())
                    .foregroundColor(Theme.textMain)
                    .padding(.top, 40)
                
                NavigationLink(destination: SingleDistanceSetupView(ergManager: ergManager)) {
                    LargeWorkoutButton(title: "Single Distance".localized, icon: "arrow.right.to.line.alt")
                }
                
                NavigationLink(destination: SingleTimeSetupView(ergManager: ergManager)) {
                    LargeWorkoutButton(title: "Single Time".localized, icon: "clock.fill")
                }
                
                NavigationLink(destination: SingleCaloriesSetupView(ergManager: ergManager)) {
                    LargeWorkoutButton(title: "Single Calories".localized, icon: "flame.fill")
                }
                
                NavigationLink(destination: FixedIntervalSetupView(ergManager: ergManager)) {
                    LargeWorkoutButton(title: "Fixed Interval".localized, icon: "repeat")
                }
                
                NavigationLink(destination: VariableIntervalSetupView(ergManager: ergManager)) {
                    LargeWorkoutButton(title: "Variable Interval".localized, icon: "repeat.1")
                }
                
                Spacer()
                
                if ergManager.isResearchWriteBusy {
                    HStack {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(Theme.accent)
                        Text("Sending CSAFE...".localized)
                            .foregroundColor(Theme.accent)
                            .bold()
                    }
                    .padding(.bottom, 40)
                }
            }
            .padding()
        }
        .navigationTitle("Workout Setup".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LargeWorkoutButton: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(Theme.primaryGradient)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

struct SingleDistanceSetupView: View {
    @ObservedObject var ergManager: RowErgManager
    @State private var distance: String = ""
    @State private var splitDistance: String = ""
    @Environment(\.dismiss) var dismiss
    
    private var isSendDisabled: Bool {
        guard let d = Int(distance), d >= 100 else { return true }
        if let s = Int(splitDistance) {
            let minSplit = max(100, Int(ceil(Double(d) / 50.0)))
            if s < minSplit || s > d {
                return true
            }
        } else {
            return true
        }
        return false
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Single Distance".localized)
                    .font(Theme.headerFont())
                    .foregroundColor(Theme.textMain)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Distance".localized + " (m)")
                        .foregroundColor(Theme.textSecondary)
                    TextField("100 - 60000", text: $distance)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .font(.title)
                        .onChange(of: distance) { _, newValue in
                            if let d = Int(newValue) {
                                let autoSplit = d / 5
                                splitDistance = "\(max(autoSplit, 100))"
                            }
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Split Distance".localized + " (m)")
                        .foregroundColor(Theme.textSecondary)
                    TextField("Min 100m", text: $splitDistance)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .font(.title2)
                }
                
                Text("Distance Range".localized)
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                
                Button(action: {
                    if let d = Int(distance), let s = Int(splitDistance) {
                        let minSplit = max(100, Int(ceil(Double(d) / 50.0)))
                        let finalSplit = min(max(s, minSplit), d)
                        ergManager.setWorkoutDistance(meters: d, split: finalSplit)
                        dismiss()
                    }
                }) {
                    Text("Send to PM5".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.primaryGradient)
                        .cornerRadius(12)
                }
                .disabled(isSendDisabled)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Distance Setup".localized)
    }
}

struct SingleTimeSetupView: View {
    @ObservedObject var ergManager: RowErgManager
    @State private var hours: Int = 0
    @State private var minutes: Int = 2
    @State private var seconds: Int = 0
    @State private var splitMinutes: Int = 0
    @State private var splitSeconds: Int = 30
    @State private var isAutoSplit: Bool = true
    @Environment(\.dismiss) var dismiss
    
    private var isSendDisabled: Bool {
        let total = totalSeconds
        if total < 20 { return true }
        if !isAutoSplit {
            let split = splitMinutes * 60 + splitSeconds
            let minSplit = max(20, Int(ceil(Double(total) / 50.0)))
            if split < minSplit || split > total {
                return true
            }
        }
        return false
    }
    
    private var totalSeconds: Int {
        (hours * 3600) + (minutes * 60) + seconds
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Single Time".localized)
                    .font(Theme.headerFont())
                    .foregroundColor(Theme.textMain)
                
                HStack(spacing: 0) {
                    TimePickerColumn(value: $hours, range: 0...9, label: "hh")
                    Text(":").font(.title).foregroundColor(.white).offset(y: -10)
                    TimePickerColumn(value: $minutes, range: 0...59, label: "mm")
                    Text(":").font(.title).foregroundColor(.white).offset(y: -10)
                    TimePickerColumn(value: $seconds, range: 0...59, label: "ss")
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
                .onChange(of: totalSeconds) { _, newValue in
                    if isAutoSplit {
                        let minSplit = max(20, Int(ceil(Double(newValue) / 50.0)))
                        let rawSplit = newValue / 5
                        let autoSplit = min(max(rawSplit, minSplit), newValue)
                        splitMinutes = autoSplit / 60
                        splitSeconds = autoSplit % 60
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Split Time".localized)
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        Button(action: { isAutoSplit.toggle() }) {
                            Text(isAutoSplit ? "Auto (1/5)".localized : "Manual".localized)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(isAutoSplit ? Theme.accent.opacity(0.2) : Color.gray.opacity(0.2))
                                .foregroundColor(isAutoSplit ? Theme.accent : .gray)
                                .cornerRadius(8)
                        }
                    }
                    
                    HStack(spacing: 0) {
                        TimePickerColumn(value: $splitMinutes, range: 0...59, label: "mm")
                            .disabled(isAutoSplit)
                        Text(":").font(.title).foregroundColor(.white).offset(y: -10)
                        TimePickerColumn(value: $splitSeconds, range: 0...59, label: "ss")
                            .disabled(isAutoSplit)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .opacity(isAutoSplit ? 0.6 : 1.0)
                }
                
                Button(action: {
                    let totalSeconds = (hours * 3600) + (minutes * 60) + seconds
                    if totalSeconds >= 20 {
                        let minSplit = max(20, Int(ceil(Double(totalSeconds) / 50.0)))
                        let split = min(max(splitMinutes * 60 + splitSeconds, minSplit), totalSeconds)
                        ergManager.setWorkoutTime(seconds: totalSeconds, split: split)
                        dismiss()
                    }
                }) {
                    Text("Send to PM5".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.primaryGradient)
                        .cornerRadius(12)
                }
                .disabled(isSendDisabled)
                
                Text("Min Time Message".localized)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Time Setup".localized)
    }
}

// MARK: - Fixed Interval Setup
struct FixedIntervalSetupView: View {
    @ObservedObject var ergManager: RowErgManager
    @State private var intervalType: Int = 0 // 0: Distance, 1: Time, 2: Calories
    @State private var distance: String = ""
    @State private var calories: String = ""
    @State private var hours: Int = 0
    @State private var minutes: Int = 2
    @State private var seconds: Int = 0
    @State private var restMinutes: Int = 1
    @State private var restSeconds: Int = 0
    @Environment(\.dismiss) var dismiss
    
    private var totalSeconds: Int { hours * 3600 + minutes * 60 + seconds }
    private var totalRestSeconds: Int { min(restMinutes * 60 + restSeconds, 595) }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    Text("Fixed Interval".localized)
                        .font(Theme.headerFont())
                        .foregroundColor(Theme.textMain)
                    
                    Picker("Interval Type", selection: $intervalType) {
                        Text("Distance".localized).tag(0)
                        Text("Time".localized).tag(1)
                        Text("Calories".localized).tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    if intervalType == 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Interval Distance".localized + " (m)")
                                .foregroundColor(Theme.textSecondary)
                            TextField("100 - 60000", text: $distance)
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
                                TimePickerColumn(value: $hours, range: 0...9, label: "hh")
                                Text(":").font(.title).foregroundColor(.white).offset(y: -10)
                                TimePickerColumn(value: $minutes, range: 0...59, label: "mm")
                                Text(":").font(.title).foregroundColor(.white).offset(y: -10)
                                TimePickerColumn(value: $seconds, range: 0...59, label: "ss")
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Interval Calories".localized + " (cal)")
                                .foregroundColor(Theme.textSecondary)
                            TextField("5 - 65535", text: $calories)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                                .font(.title)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rest Duration (Max 9:55)".localized)
                            .foregroundColor(Theme.textSecondary)
                        HStack(spacing: 0) {
                            Spacer()
                            TimePickerColumn(value: $restMinutes, range: 0...9, label: "mm")
                            Text(":").font(.title).foregroundColor(.white).offset(y: -10)
                            TimePickerColumn(value: $restSeconds, range: 0...59, label: "ss")
                            Spacer()
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                    }
                    
                    Button(action: {
                        if intervalType == 0 {
                            if let d = Int(distance) {
                                ergManager.setFixedIntervalDistance(meters: d, rest: totalRestSeconds)
                                dismiss()
                            }
                        } else if intervalType == 1 {
                            if totalSeconds >= 20 {
                                ergManager.setFixedIntervalTime(seconds: totalSeconds, rest: totalRestSeconds)
                                dismiss()
                            }
                        } else {
                            if let c = Int(calories) {
                                ergManager.setFixedIntervalCalories(calories: c, rest: totalRestSeconds)
                                dismiss()
                            }
                        }
                    }) {
                        Text("Send to PM5".localized)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.primaryGradient)
                            .cornerRadius(12)
                    }
                    .disabled(intervalType == 0 ? (Int(distance) == nil) : (intervalType == 1 ? (totalSeconds < 20) : (Int(calories) == nil || Int(calories)! < 5)))
                    
                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle("Interval Setup".localized)
    }
}

// MARK: - Variable Interval Setup
struct VariableIntervalSetupView: View {
    @ObservedObject var ergManager: RowErgManager
    @State private var intervals: [VariableIntervalEntry] = []
    @State private var isShowingEditor = false
    @State private var editingIndex: Int? = nil
    @State private var hasPresentedInitialEditor = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                // Main List
                List {
                    ForEach(intervals.indices, id: \.self) { index in
                        VariableIntervalRowView(
                            index: index,
                            entry: intervals[index],
                            onCopy: {
                                copyInterval(at: index)
                            },
                            onTap: {
                                editingIndex = index
                                isShowingEditor = true
                            }
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .onDelete(perform: deleteIntervals)
                    .onMove(perform: moveIntervals)
                    
                    // Add Button
                    Button(action: {
                        editingIndex = nil
                        isShowingEditor = true
                    }) {
                        Text(intervals.isEmpty ? "Add Interval".localized : "Add Next Interval".localized)
                            .font(.headline)
                            .foregroundColor(Theme.mainBackground)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(30)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 24, leading: 40, bottom: 24, trailing: 40))
                }
                .listStyle(PlainListStyle())
                .padding(.top, 16)
                
                Button(action: {
                    ergManager.setVariableIntervalWorkout(intervals: intervals)
                    dismiss()
                }) {
                    Text("Send to PM5".localized)
                        .font(.headline)
                        .foregroundColor(Theme.mainBackground)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.accent)
                        .cornerRadius(30)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .disabled(intervals.isEmpty)
                .opacity(intervals.isEmpty ? 0.5 : 1.0)
            }
        }
        .navigationTitle("Variable Interval".localized)
        .onAppear {
            if intervals.isEmpty && !hasPresentedInitialEditor {
                hasPresentedInitialEditor = true
                isShowingEditor = true
            }
        }
        .sheet(isPresented: $isShowingEditor) {
            VariableIntervalEditorView(
                entry: editingIndex != nil ? intervals[editingIndex!] : intervals.last
            ) { newEntry in
                if let index = editingIndex {
                    intervals[index] = newEntry
                } else {
                    intervals.append(newEntry)
                }
            }
        }
    }
    
    private func copyInterval(at index: Int) {
        let entryToCopy = intervals[index]
        intervals.insert(entryToCopy, at: index + 1)
    }
    
    private func deleteIntervals(at offsets: IndexSet) {
        intervals.remove(atOffsets: offsets)
    }
    
    private func moveIntervals(from source: IndexSet, to destination: Int) {
        intervals.move(fromOffsets: source, toOffset: destination)
    }
}

// MARK: - Single Calories Setup
struct SingleCaloriesSetupView: View {
    @ObservedObject var ergManager: RowErgManager
    @State private var calories: String = ""
    @State private var splitCalories: String = ""
    @Environment(\.dismiss) var dismiss
    
    private var isSendDisabled: Bool {
        guard let c = Int(calories), c >= 5 && c <= 65535 else { return true }
        if let s = Int(splitCalories) {
            let minSplit = max(5, Int(ceil(Double(c) / 50.0)))
            if s < minSplit || s > c {
                return true
            }
        } else {
            return true
        }
        return false
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Single Calories".localized)
                    .font(Theme.headerFont())
                    .foregroundColor(Theme.textMain)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Calories".localized + " (cal)")
                        .foregroundColor(Theme.textSecondary)
                    TextField("5 - 65535", text: $calories)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .font(.title)
                        .onChange(of: calories) { _, newValue in
                            if let c = Int(newValue) {
                                let autoSplit = c / 5
                                splitCalories = "\(max(autoSplit, 5))"
                            }
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Split Calories".localized + " (cal)")
                        .foregroundColor(Theme.textSecondary)
                    TextField("Min 5 cal", text: $splitCalories)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .font(.title2)
                }
                
                Text("Calories Range".localized)
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                
                Button(action: {
                    if let c = Int(calories), let s = Int(splitCalories) {
                        let minSplit = max(5, Int(ceil(Double(c) / 50.0)))
                        let finalSplit = min(max(s, minSplit), c)
                        ergManager.setWorkoutCalories(calories: c, split: finalSplit)
                        dismiss()
                    }
                }) {
                    Text("Send to PM5".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.primaryGradient)
                        .cornerRadius(12)
                }
                .disabled(isSendDisabled)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Calories Setup".localized)
    }
}

