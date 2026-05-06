import SwiftUI

struct TermsView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    Text("Terms of Service".localized)
                        .font(Theme.headerFont())
                        .foregroundColor(Theme.textMain)
                        .padding(.top)
                    
                    Text("Terms_LastUpdated".localized)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    
                    Divider().overlay(Theme.textSecondary.opacity(0.3))
                    
                    // Sections
                    TermSection(title: "Term_1_Title".localized, content: "Term_1_Content".localized)
                    
                    TermSection(title: "Term_2_Title".localized, content: "Term_2_Content".localized)
                    
                    TermSection(title: "Term_3_Title".localized, content: "Term_3_Content".localized)

                    TermSection(title: "Term_4_Title".localized, content: "Term_4_Content".localized)
                    
                    TermSection(title: "Term_5_Title".localized, content: "Term_5_Content".localized)

                    
                    TermSection(title: "Term_6_Title".localized, content: "Term_6_Content".localized)
                    
                    TermSection(title: "Term_7_Title".localized, content: "Term_7_Content".localized)
                    
                    TermSection(title: "Term_8_Title".localized, content: "Term_8_Content".localized)
                    
                    TermSection(title: "Term_9_Title".localized, content: "Term_9_Content".localized)
                    
                    TermSection(title: "Term_10_Title".localized, content: "Term_10_Content".localized)
                    
                    TermSection(title: "Term_11_Title".localized, content: "Term_11_Content".localized)
                    
                    // Footer Spacing
                    Color.clear.frame(height: 40)
                }
                .padding()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TermSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Theme.subHeaderFont())
                .foregroundColor(Theme.accent)
            
            Text(content)
                .font(.body)
                .foregroundColor(Theme.textSecondary) // Slightly dimmed for readability
                .lineSpacing(6)
        }
        .padding()
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        TermsView()
    }
}
