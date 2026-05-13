import SwiftUI

/// マネージャー用ワークアウト設定画面
/// 接続中の全PM5に共通の距離・時間設定を送信する
struct ManagerWorkoutSetupView: View {
    @ObservedObject var viewModel: PM5ManagerViewModel
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 30) {
                // ヘッダー
                VStack(spacing: 8) {
                    Text("Workout Setup".localized)
                        .font(Theme.headerFont())
                        .foregroundColor(Theme.textMain)
                    
                    Text("\(viewModel.connectedDevices.count)\("Bulk Send Message".localized)")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.top, 20)
                
                // ワークアウトタイプ選択
                NavigationLink {
                    ManagerDistanceSetupView(viewModel: viewModel)
                } label: {
                    ManagerWorkoutButton(title: "Single Distance".localized, icon: "arrow.right.to.line.alt",
                                         subtitle: "100m 〜 60,000m")
                }
                
                NavigationLink {
                    ManagerTimeSetupView(viewModel: viewModel)
                } label: {
                    ManagerWorkoutButton(title: "Single Time".localized, icon: "clock.fill",
                                         subtitle: "Min duration is 20s".localized)
                }
                
                Spacer()
                
                // 送信中インジケーター
                if viewModel.isSending {
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
                
                // 接続中PM5一覧（コンパクト表示）
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connected PM5s".localized)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    
                    ForEach(viewModel.connectedDevices, id: \.identifier) { device in
                        let isDisconnected = viewModel.disconnectedDeviceIDs.contains(device.identifier)
                        HStack(spacing: 8) {
                            Circle()
                                .fill(isDisconnected ? Color.gray : Color.green)
                                .frame(width: 8, height: 8)
                            Text(device.name ?? "Unknown PM5")
                                .font(.caption)
                                .foregroundColor(isDisconnected ? .gray : Theme.textMain)
                            if isDisconnected {
                                Text("Reconnecting".localized)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .padding(.bottom, 20)
            }
            .padding()
        }
        .navigationTitle("Workout Setup".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Workout Button
struct ManagerWorkoutButton: View {
    let title: String
    let icon: String
    let subtitle: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(subtitle)
                    .font(.caption)
                    .opacity(0.8)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.title3)
                .opacity(0.6)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .frame(height: 100)
        .background(Theme.primaryGradient)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Distance Setup
struct ManagerDistanceSetupView: View {
    @ObservedObject var viewModel: PM5ManagerViewModel
    @State private var distance: String = ""
    @State private var splitDistance: String = ""
    @State private var navigateToDashboard: Bool = false
    
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
                                // 距離が入力されたら、自動でその1/5をスプリットに設定
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
                
                Text("※ \(viewModel.connectedDevices.count)\("Bulk Send Message".localized)")
                    .font(.subheadline)
                    .foregroundColor(Theme.accent)
                
                Button(action: {
                    if let d = Int(distance), let s = Int(splitDistance) {
                        viewModel.resetAndStartWorkout(distance: d, split: max(s, 100))
                    }
                }) {
                    Text("Send to all PM5s".localized)
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
        .navigationDestination(isPresented: $navigateToDashboard) {
            ManagerWorkoutDashboardView(viewModel: viewModel)
        }
        .onChange(of: viewModel.showDashboard) { _, newValue in
            if newValue {
                navigateToDashboard = true
                viewModel.showDashboard = false
            }
        }
    }
}

// MARK: - Time Setup
struct ManagerTimeSetupView: View {
    @ObservedObject var viewModel: PM5ManagerViewModel
    @State private var hours: Int = 0
    @State private var minutes: Int = 2
    @State private var seconds: Int = 0
    @State private var splitMinutes: Int = 0
    @State private var splitSeconds: Int = 30
    @State private var navigateToDashboard: Bool = false
    
    @State private var isAutoSplit: Bool = true
    
    private var totalSeconds: Int {
        hours * 3600 + minutes * 60 + seconds
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
                        let autoSplit = newValue / 5
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
                
                Text("※ \(viewModel.connectedDevices.count)\("Bulk Send Message".localized)")
                    .font(.subheadline)
                    .foregroundColor(Theme.accent)
                
                Button(action: {
                    if totalSeconds >= 20 {
                        let split = splitMinutes * 60 + splitSeconds
                        viewModel.resetAndStartWorkout(time: totalSeconds, split: split)
                    }
                }) {
                    Text("Send to all PM5s".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.primaryGradient)
                        .cornerRadius(12)
                }
                .disabled(totalSeconds < 20)
                
                Text("Min Time Message".localized)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Time Setup".localized)
        .navigationDestination(isPresented: $navigateToDashboard) {
            ManagerWorkoutDashboardView(viewModel: viewModel)
        }
        .onChange(of: viewModel.showDashboard) { _, newValue in
            if newValue {
                navigateToDashboard = true
                viewModel.showDashboard = false
            }
        }
    }
}
