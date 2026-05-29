import SwiftUI

/// クルー情報を編集するためのシート
struct CrewEditSheet: View {
    let recordId: UUID
    let existingCrewInfo: CrewInfo?
    let onSave: (CrewInfo) -> Void
    let onDelete: () -> Void
    
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedBoatType: BoatType
    @State private var memberNames: [String]
    @State private var showDeleteConfirmation = false
    
    init(recordId: UUID, existingCrewInfo: CrewInfo?, onSave: @escaping (CrewInfo) -> Void, onDelete: @escaping () -> Void) {
        self.recordId = recordId
        self.existingCrewInfo = existingCrewInfo
        self.onSave = onSave
        self.onDelete = onDelete
        
        let boatType = existingCrewInfo?.boatType ?? .eight
        _selectedBoatType = State(initialValue: boatType)
        _memberNames = State(initialValue: existingCrewInfo?.members ?? Array(repeating: "", count: boatType.totalSeats))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - ボートタイプ選択
                        boatTypeSelector
                        
                        // MARK: - プレビュー
                        previewSection
                        
                        // MARK: - クルー名入力
                        crewNameInputs
                        
                        // MARK: - 削除ボタン（既存データがある場合）
                        if existingCrewInfo != nil {
                            deleteButton
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("クルー編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(Theme.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save".localized) {
                        let crewInfo = CrewInfo(boatType: selectedBoatType, members: memberNames)
                        onSave(crewInfo)
                        dismiss()
                    }
                    .foregroundColor(Theme.accent)
                    .fontWeight(.bold)
                }
            }
            .confirmationDialog("クルー情報を削除しますか？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("削除", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel".localized, role: .cancel) {}
            }
        }
    }
    
    // MARK: - Boat Type Selector
    
    private var boatTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("艇種を選択", systemImage: "sailboat.fill")
                .font(Theme.subHeaderFont())
                .foregroundColor(Theme.textMain)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(BoatType.allCases) { boatType in
                    boatTypeButton(boatType)
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(20)
    }
    
    private func boatTypeButton(_ boatType: BoatType) -> some View {
        let isSelected = selectedBoatType == boatType
        
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedBoatType = boatType
                // 座席数が変わるのでメンバー配列を調整
                adjustMemberNames(for: boatType)
            }
        }) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Theme.accent : Theme.accent.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: boatType.iconName)
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .white : Theme.accent)
                }
                
                Text(boatType.rawValue)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? Theme.accent : Theme.textMain)
                
                Text(boatType.displayName)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Theme.accent.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Theme.accent : Color.clear, lineWidth: 2)
            )
        }
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("プレビュー", systemImage: "eye.fill")
                .font(Theme.subHeaderFont())
                .foregroundColor(Theme.textMain)
            
            BoatDiagramView(
                crewInfo: CrewInfo(boatType: selectedBoatType, members: memberNames)
            )
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(20)
    }
    
    // MARK: - Crew Name Inputs
    
    private var crewNameInputs: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("クルー名", systemImage: "person.text.rectangle.fill")
                .font(Theme.subHeaderFont())
                .foregroundColor(Theme.textMain)
            
            let labels = selectedBoatType.seatLabels
            
            ForEach(0..<selectedBoatType.totalSeats, id: \.self) { index in
                let isCox = selectedBoatType.hasCoxswain && index == selectedBoatType.totalSeats - 1
                
                HStack(spacing: 12) {
                    // 座席ラベルバッジ
                    ZStack {
                        Circle()
                            .fill(isCox ? Color.orange.opacity(0.2) : Theme.accent.opacity(0.2))
                            .frame(width: 36, height: 36)
                        
                        if isCox {
                            Image(systemName: "megaphone.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)
                        } else {
                            Text(labels[index])
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.accent)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if isCox {
                            Text("コックス")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Text(seatDescription(index: index, labels: labels))
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        
                        TextField("名前を入力", text: memberNameBinding(at: index))
                            .textFieldStyle(.plain)
                            .font(.body)
                            .foregroundColor(Theme.textMain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.background.opacity(0.5))
                            .cornerRadius(10)
                    }
                }
                
                if index < selectedBoatType.totalSeats - 1 {
                    Divider()
                        .background(Theme.textSecondary.opacity(0.2))
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(20)
    }
    
    // MARK: - Delete Button
    
    private var deleteButton: some View {
        Button(action: {
            showDeleteConfirmation = true
        }) {
            HStack {
                Image(systemName: "trash.fill")
                Text("クルー情報を削除")
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(14)
        }
    }
    
    // MARK: - Helpers
    
    private func memberNameBinding(at index: Int) -> Binding<String> {
        Binding<String>(
            get: {
                guard index < memberNames.count else { return "" }
                return memberNames[index]
            },
            set: { newValue in
                guard index < memberNames.count else { return }
                memberNames[index] = newValue
            }
        )
    }
    
    private func adjustMemberNames(for boatType: BoatType) {
        let targetCount = boatType.totalSeats
        if memberNames.count < targetCount {
            memberNames.append(contentsOf: Array(repeating: "", count: targetCount - memberNames.count))
        } else if memberNames.count > targetCount {
            memberNames = Array(memberNames.prefix(targetCount))
        }
    }
    
    private func seatDescription(index: Int, labels: [String]) -> String {
        let label = labels[index]
        switch label {
        case "Bow": return "バウ（1番）"
        case "Stroke": return "ストローク（\(selectedBoatType.rowerCount)番）"
        default: return "\(label)番"
        }
    }
}
