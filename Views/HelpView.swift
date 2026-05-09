import SwiftUI

/// ヘルプコンテンツを表示するビュー
struct HelpView: View {
    let title: String
    let content: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(content)
                            .foregroundColor(Theme.textMain)
                            .lineSpacing(6)
                        
                        /* 
                        // 追加のヒントや画像などをここに配置可能
                        */
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// 共通のヘルプボタン
struct HelpCircleButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(Theme.accent)
                .background(Circle().fill(Theme.cardBackground))
                .shadow(radius: 4)
        }
    }
}
