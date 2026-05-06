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
        .frame(height: 100)
        .background(Theme.primaryGradient)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

struct SingleDistanceSetupView: View {
    @ObservedObject var ergManager: RowErgManager
    @State private var distance: String = ""
    @Environment(\.dismiss) var dismiss
    
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
                }
                
                Text("Distance Range".localized)
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                
                Button(action: {
                    if let d = Int(distance) {
                        ergManager.setWorkoutDistance(meters: d)
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
                .disabled(Int(distance) == nil)
                
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
    @Environment(\.dismiss) var dismiss
    
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
                
                Button(action: {
                    let totalSeconds = (hours * 3600) + (minutes * 60) + seconds
                    if totalSeconds >= 20 {
                        ergManager.setWorkoutTime(seconds: totalSeconds)
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
                .disabled((hours * 3600 + minutes * 60 + seconds) < 20)
                
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

struct TimePickerColumn: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let label: String
    
    var body: some View {
        VStack {
            Picker("", selection: $value) {
                ForEach(range, id: \.self) { i in
                    Text(String(format: "%02d", i)).tag(i)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 70, height: 120)
            .clipped()
            Text(label)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
    }
}
