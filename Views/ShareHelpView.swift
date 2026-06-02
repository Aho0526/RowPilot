import SwiftUI

struct ShareHelpView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(Theme.primaryGradient)
                                .padding(.top, 16)
                            
                            Text("About Export Formats".localized)
                                .font(Theme.headerFont())
                                .foregroundColor(Theme.textMain)
                        }
                        
                        // .rowpilot Format Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(Theme.accent)
                                    .font(.title3)
                                Text("RowPilot Data (.rowpilot)")
                                    .font(.headline)
                                    .foregroundColor(Theme.textMain)
                            }
                            
                            Text("rowpilot_desc".localized)
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                                .lineSpacing(4)
                        }
                        .padding()
                        .glassCardStyle(glowColor: Theme.accent, opacity: 0.08, cornerRadius: 16)
                        
                        // .csv Format Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "tablecells.fill")
                                    .foregroundColor(Theme.secondaryAccent)
                                    .font(.title3)
                                Text("CSV (.csv)")
                                    .font(.headline)
                                    .foregroundColor(Theme.textMain)
                                Spacer()
                                Text("RowPilot MAX")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Theme.secondaryAccent.opacity(0.2))
                                    .foregroundColor(Theme.secondaryAccent)
                                    .cornerRadius(8)
                            }
                            
                            Text("csv_desc".localized)
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                                .lineSpacing(4)
                        }
                        .padding()
                        .glassCardStyle(glowColor: Theme.secondaryAccent, opacity: 0.08, cornerRadius: 16)
                    }
                    .padding()
                }
            }
            .navigationTitle("About Export Formats".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close".localized) {
                        dismiss()
                    }
                    .foregroundColor(Theme.accent)
                }
            }
        }
    }
}

#Preview {
    ShareHelpView()
}
