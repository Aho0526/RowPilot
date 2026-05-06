import SwiftUI
import CoreBluetooth

/// PM5デバイスの名前変更・並び替え編集画面
/// ダッシュボードからシートで表示される
struct PM5EditView: View {
    @ObservedObject var viewModel: PM5ManagerViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                List {
                    // MARK: - Device List (Reorderable)
                    Section {
                        ForEach(viewModel.connectedDevices, id: \.identifier) { device in
                            PM5EditRow(
                                device: device,
                                viewModel: viewModel
                            )
                            .listRowBackground(Color.white.opacity(0.05))
                        }
                        .onMove { source, destination in
                            viewModel.moveDevice(from: source, to: destination)
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: "list.number")
                                .foregroundColor(Theme.accent)
                            Text("PM5デバイス一覧")
                                .foregroundColor(Theme.textSecondary)
                        }
                        .textCase(nil)
                    } footer: {
                        Text("ドラッグで並び替え、テキストをタップして名前を変更できます。名前を空にするとBLE名に戻ります。")
                            .foregroundColor(Theme.textSecondary)
                            .font(.caption)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active))
            }
            .navigationTitle("PM5 編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        isPresented = false
                    }
                    .fontWeight(.bold)
                    .foregroundColor(Theme.accent)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - PM5 Edit Row
struct PM5EditRow: View {
    let device: CBPeripheral
    @ObservedObject var viewModel: PM5ManagerViewModel
    
    @State private var editingName: String = ""
    @State private var isEditing: Bool = false
    @FocusState private var isFocused: Bool
    
    private var bleName: String {
        device.name ?? "Unknown PM5"
    }
    
    private var deviceNumber: Int {
        viewModel.deviceNumbers[device.identifier] ?? 0
    }
    
    private var isDisconnected: Bool {
        viewModel.disconnectedDeviceIDs.contains(device.identifier)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 番号バッジ
            Text("#\(deviceNumber)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 32, height: 22)
                .background(isDisconnected ? Color.gray : Theme.accent)
                .cornerRadius(6)
            
            // 接続ステータスインジケーター
            Circle()
                .fill(isDisconnected ? Color.gray : Color.green)
                .frame(width: 8, height: 8)
            
            // 名前表示・編集
            VStack(alignment: .leading, spacing: 3) {
                if isEditing {
                    TextField("カスタム名を入力", text: $editingName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.textMain)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .onSubmit {
                            commitEdit()
                        }
                        .onChange(of: isFocused) { _, focused in
                            if !focused {
                                commitEdit()
                            }
                        }
                } else {
                    Text(viewModel.displayName(for: device))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isDisconnected ? .gray : Theme.textMain)
                        .lineLimit(1)
                        .onTapGesture {
                            startEditing()
                        }
                }
                
                // BLE名（シリアルナンバー）を常に小さく表示
                HStack(spacing: 4) {
                    Image(systemName: "barcode")
                        .font(.system(size: 8))
                    Text(bleName)
                        .font(.system(size: 10, design: .monospaced))
                }
                .foregroundColor(Theme.textSecondary.opacity(0.7))
            }
            
            Spacer()
            
            // 編集ボタン
            if !isEditing {
                Button(action: { startEditing() }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.accent.opacity(0.7))
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { commitEdit() }) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
    
    private func startEditing() {
        let currentCustom = viewModel.deviceCustomNames[bleName]
        editingName = currentCustom ?? ""
        isEditing = true
        isFocused = true
    }
    
    private func commitEdit() {
        viewModel.setCustomName(editingName, for: bleName)
        isEditing = false
        isFocused = false
    }
}
