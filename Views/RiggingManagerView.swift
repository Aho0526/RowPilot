import SwiftUI

struct RiggingManagerView: View {
    @ObservedObject private var riggingManager = RiggingManager.shared
    @State private var showingEditor = false
    @State private var showingSettings = false
    @State private var editorConfig: RiggingConfig? = nil
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Create New Header Button
                    Button(action: {
                        editorConfig = nil
                        showingEditor = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                            Text("Create New Setup".localized)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Theme.accent, lineWidth: 1.5)
                                .background(Theme.accent.opacity(0.1).cornerRadius(12))
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    if riggingManager.configs.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "pencil.and.ruler.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.textSecondary.opacity(0.4))
                                .padding(.top, 40)
                            Text("No Rigging Setups".localized)
                                .foregroundColor(Theme.textSecondary)
                                .font(.subheadline)
                        }
                    } else {
                        // Config list
                        LazyVStack(spacing: 14) {
                            ForEach(riggingManager.configs) { config in
                                let isActive = riggingManager.activeConfigId == config.id
                                
                                RiggingConfigRowCard(
                                    config: config,
                                    isActive: isActive,
                                    onSelect: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                            riggingManager.selectActiveConfig(id: config.id)
                                        }
                                    },
                                    onEdit: {
                                        editorConfig = config
                                        showingEditor = true
                                    },
                                    onDelete: {
                                        withAnimation {
                                            riggingManager.deleteConfig(id: config.id)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Rigging Setups List".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                if let config = editorConfig {
                    RiggingEditorView(config: config)
                } else {
                    RiggingEditorView()
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            RiggingSettingsSheet()
        }
    }
}

// MARK: - Row Card Component

struct RiggingConfigRowCard: View {
    let config: RiggingConfig
    let isActive: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Selection Indicator Button
                Button(action: onSelect) {
                    ZStack {
                        Circle()
                            .stroke(isActive ? Theme.accent : Color.white.opacity(0.3), lineWidth: 2)
                            .frame(width: 24, height: 24)
                        
                        if isActive {
                            Circle()
                                .fill(Theme.accent)
                                .frame(width: 14, height: 14)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(config.name)
                            .font(.headline)
                            .foregroundColor(Theme.textMain)
                            .lineLimit(1)
                        
                        if isActive {
                            Text("Active Setup Indicator".localized)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.accent.cornerRadius(4))
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: config.boatType.iconName)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        Text(config.boatType.displayName)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        Text("•")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary.opacity(0.5))
                        Text(formatDate(config.date))
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .foregroundColor(Theme.accent)
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(12)
            
            // Sub-details panel
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Oar".localized)
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text("L:\(String(format: "%.0f", config.oarTotalLength))/I:\(String(format: "%.0f", config.oarInboard))/G:\(String(format: "%.0f", config.oarGripDiameter))")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.textMain.opacity(0.9))
                }
                
                Divider()
                    .frame(height: 20)
                    .background(Color.white.opacity(0.15))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Span".localized)
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text("\(String(format: "%.1f", config.boatSpan))")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.textMain.opacity(0.9))
                }
                
                Divider()
                    .frame(height: 20)
                    .background(Color.white.opacity(0.15))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Height".localized)
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text("\(String(format: "%.1f", config.boatWorkHeight))")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.textMain.opacity(0.9))
                }
                
                Divider()
                    .frame(height: 20)
                    .background(Color.white.opacity(0.15))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pitch".localized)
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text("\(String(format: "%.0f", config.boatPitch))°(\(config.boatLateralPitch))/\(String(format: "%.0f", config.oarSleevePitch))°")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.textMain.opacity(0.9))
                }
                
                Divider()
                    .frame(height: 20)
                    .background(Color.white.opacity(0.15))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Footplate".localized)
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text("\(String(format: "%.0f", config.boatFootplateAngle))°/\(String(format: "%.0f", config.boatFootplateHeight))cm")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.textMain.opacity(0.9))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.15))
            .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Theme.accent.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: date)
    }
}

// Helper extension to specify corners to round

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Rigging Settings Sheet

struct RiggingSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("showAllRiggingValuesWhenIdle") private var showAllRiggingValuesWhenIdle: Bool = true
    @AppStorage("footstretchMeasurementMethod") private var footstretchMeasurementMethod: String = "fromHeel"
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("Customize how rigging values are displayed in the preview diagrams.".localized)
                        .font(.footnote)
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal)
                        .padding(.top, 16)
                    
                    VStack(spacing: 16) {
                        // Toggle 1: Show all values when idle
                        Toggle(isOn: $showAllRiggingValuesWhenIdle) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Show all values when idle".localized)
                                    .font(.body)
                                    .foregroundColor(Theme.textMain)
                                Text("Displays configured values on the diagrams even when no field is selected.".localized)
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .tint(Theme.accent)
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        // Picker: Footstretch measurement basis
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Footstretch Measurement".localized)
                                .font(.body)
                                .foregroundColor(Theme.textMain)
                            
                            Text("Select the reference point for measuring footstretch length.".localized)
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                                .padding(.bottom, 4)
                            
                            Picker("Footstretch Measurement".localized, selection: $footstretchMeasurementMethod) {
                                Text("From Heel".localized).tag("fromHeel")
                                Text("From Shoe Center".localized).tag("fromCenter")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.horizontal, 2)
                        }
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle("Rigging Settings".localized)
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
