import SwiftUI

struct VariableIntervalRowView: View {
    let index: Int
    let entry: VariableIntervalEntry
    let onCopy: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Index Circle
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.2))
                    .frame(width: 32, height: 32)
                Text("\(index + 1)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.accent)
            }
            
            // Work Duration
            if let dist = entry.distanceMeters {
                Text("\(dist) m")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 80, alignment: .leading)
            } else if let time = entry.timeSeconds {
                Text(formatTime(time))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 80, alignment: .leading)
            }
            
            Spacer()
            
            // Rest Duration
            Text("休憩： " + formatTime(entry.restSeconds))
                .font(.system(size: 16))
                .foregroundColor(Theme.textSecondary)
            
            Spacer()
            
            // Copy Button
            Button(action: onCopy) {
                Image(systemName: "plus.square.on.square")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.accent)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Drag Indicator
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 20))
                .foregroundColor(Theme.textSecondary.opacity(0.6))
                .padding(.leading, 8)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            ZStack {
                Theme.mainBackground
                Color.white.opacity(0.05)
            }
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        if m > 0 {
            return String(format: "%d:%02d", m, s)
        } else {
            return String(format: ":%02d", s)
        }
    }
}
