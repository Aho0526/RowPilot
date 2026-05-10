import SwiftUI

struct SOSSettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var contactName: String = ""
    @State private var contactPhone: String = ""
    @State private var userName: String = ""
    @State private var mapSelection: SOSMapSelection = .both
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // 説明文
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("SOS Settings".localized)
                                .font(Theme.subHeaderFont())
                                .foregroundColor(Theme.textMain)
                        }
                        
                        Text("SOS Message Hint".localized)
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Theme.cardBackground)
                    .cornerRadius(16)
                    
                    // 入力セクション
                    VStack(spacing: 20) {
                        sosInputField(label: "User Name".localized, text: $userName, icon: "person.fill", placeholder: "RowPilot User")
                        sosInputField(label: "Contact Name".localized, text: $contactName, icon: "person.badge.shield.checkmark.fill", placeholder: "Guardian Name")
                        sosInputField(label: "Phone Number".localized, text: $contactPhone, icon: "phone.fill", placeholder: "09012345678")
                            .keyboardType(.phonePad)
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    .cornerRadius(16)
                    
                    // Map Selection
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "map.fill")
                                .foregroundColor(Theme.accent)
                                .frame(width: 20)
                            Text("Map Type".localized)
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        Picker("Map Type".localized, selection: $mapSelection) {
                            ForEach(SOSMapSelection.allCases, id: \.self) { selection in
                                Text(selection.rawValue.localized).tag(selection)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    .cornerRadius(16)
                    
                    // 保存ボタン
                    Button(action: saveSettings) {
                        Text("Done".localized)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.primaryGradient)
                            .cornerRadius(12)
                    }
                    .padding(.top, 10)
                    
                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle("Emergency Contact".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            contactName = settingsManager.settings.sosContactName
            contactPhone = settingsManager.settings.sosContactPhone
            userName = settingsManager.settings.sosUserName
            mapSelection = settingsManager.settings.sosMapSelection
        }
    }
    
    private func sosInputField(label: String, text: Binding<String>, icon: String, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Theme.accent)
                    .frame(width: 20)
                Text(label)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(.vertical, 8)
                .foregroundColor(Theme.textMain)
            
            Divider()
                .background(Theme.textSecondary.opacity(0.3))
        }
    }
    
    private func saveSettings() {
        settingsManager.settings.sosContactName = contactName
        settingsManager.settings.sosContactPhone = contactPhone
        settingsManager.settings.sosUserName = userName
        settingsManager.settings.sosMapSelection = mapSelection
        dismiss()
    }
}

#Preview {
    NavigationStack {
        SOSSettingsView()
    }
}
