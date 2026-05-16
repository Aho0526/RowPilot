import SwiftUI

struct TimePickerColumn: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let label: String
    
    var body: some View {
        VStack {
            Picker("", selection: $value) {
                ForEach(range, id: \.self) { i in
                    Text(String(format: "%02d", i)).tag(i)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 70, height: 120)
            .clipped()
            Text(label)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
        }
    }
}
