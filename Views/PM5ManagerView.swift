import SwiftUI

/// マネージャー用PM5接続管理画面
/// 検出済みPM5の追加・接続済みPM5の削除・ワークアウト設定への遷移を提供
struct PM5ManagerView: View {
    @EnvironmentObject var viewModel: PM5ManagerViewModel
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - Bluetooth Status & Scan Control
                    PracticeSection(title: "Bluetooth", icon: "antenna.radiowaves.left.and.right") {
                        HStack {
                            Text(viewModel.isBluetoothPoweredOn ? "Bluetooth ON".localized : "Bluetooth OFF".localized)
                                .fontWeight(.bold)
                                .foregroundColor(viewModel.isBluetoothPoweredOn ? .green : .red)
                            Spacer()
                            if viewModel.isScanning {
                                ProgressView()
                                    .tint(Theme.accent)
                            }
                        }
                        
                        Button(action: {
                            if viewModel.isScanning {
                                viewModel.stopScanning()
                            } else {
                                viewModel.startScanning()
                            }
                        }) {
                            Text(viewModel.isScanning ? "Stop Scan".localized : "Scanning PM5".localized)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(viewModel.isBluetoothPoweredOn
                                    ? Theme.primaryGradient
                                    : LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(!viewModel.isBluetoothPoweredOn)
                    }
                    
                    // MARK: - Error Message
                    if let error = viewModel.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                            Text(error)
                                .foregroundColor(.white)
                                .font(.subheadline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.3))
                        .cornerRadius(12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // MARK: - Discovered Devices
                    if !viewModel.availableDevices.isEmpty {
                        PracticeSection(title: "Discovered PM5".localized, icon: "rower") {
                            ForEach(viewModel.availableDevices, id: \.identifier) { device in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(device.name ?? "Unknown PM5")
                                            .foregroundColor(Theme.textMain)
                                            .fontWeight(.medium)
                                        Text(device.identifier.uuidString.prefix(8) + "...")
                                            .font(.caption2)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if viewModel.connectingDeviceIDs.contains(device.identifier) {
                                        ProgressView()
                                            .tint(Theme.accent)
                                            .padding(.trailing, 8)
                                        Text("Connecting...".localized)
                                            .font(.caption)
                                            .foregroundColor(Theme.accent)
                                    } else {
                                        Button(action: {
                                            viewModel.addDevice(device)
                                        }) {
                                            Text("Add".localized)
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(Theme.primaryGradient)
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    // MARK: - Connected Devices
                    PracticeSection(title: "\("Connected PM5".localized) (\(viewModel.connectedDevices.count)\("Devices".localized))", icon: "checkmark.circle.fill") {
                        if viewModel.connectedDevices.isEmpty {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(Theme.textSecondary)
                                Text("Add PM5 Message".localized)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .padding(.vertical, 8)
                        } else {
                            ForEach(viewModel.connectedDevices, id: \.identifier) { device in
                                let isDisconnected = viewModel.disconnectedDeviceIDs.contains(device.identifier)
                                HStack {
                                    Image(systemName: isDisconnected ? "circle.slash" : "checkmark.circle.fill")
                                        .foregroundColor(isDisconnected ? .gray : .green)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(device.name ?? "Unknown PM5")
                                            .foregroundColor(isDisconnected ? Theme.textSecondary : Theme.textMain)
                                            .fontWeight(.medium)
                                        Text(isDisconnected ? "Reconnecting".localized : "Connected".localized)
                                            .font(.caption)
                                            .foregroundColor(isDisconnected ? .gray : .green)
                                    }
                                    
                                    Spacer()
                                    
                                    if isDisconnected {
                                        ProgressView()
                                            .tint(.gray)
                                            .scaleEffect(0.8)
                                    }
                                    
                                    Button(action: {
                                        viewModel.removeDevice(device)
                                    }) {
                                        Text("Delete".localized)
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.red.opacity(0.8))
                                            .cornerRadius(8)
                                    }
                                }
                                .padding()
                                .background(isDisconnected ? Color.gray.opacity(0.1) : Color.white.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    // MARK: - Next Button
                    NavigationLink {
                        ManagerWorkoutSetupView(viewModel: viewModel)
                    } label: {
                        HStack {
                            Text("Next".localized)
                                .font(.headline)
                                .fontWeight(.bold)
                            Image(systemName: "arrow.right")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.canProceed
                            ? Theme.primaryGradient
                            : LinearGradient(colors: [.gray.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                        .cornerRadius(16)
                        .shadow(color: viewModel.canProceed ? Theme.accent.opacity(0.3) : .clear,
                                radius: 10, x: 0, y: 5)
                    }
                    .disabled(!viewModel.canProceed)
                    .padding(.top, 8)
                    
                }
                .padding()
            }
        }
        .navigationTitle("PM5 Manager".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .animation(.easeInOut(duration: 0.3), value: viewModel.errorMessage)
        .animation(.easeInOut(duration: 0.3), value: viewModel.connectedDevices.count)
    }
}
