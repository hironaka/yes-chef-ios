import SwiftUI

struct Waveform: View {
    var level: Float
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 4, height: height(for: index))
                    .animation(.easeInOut(duration: 0.1), value: level)
            }
        }
    }
    
    private func height(for index: Int) -> CGFloat {
        // Create a symmetric wave pattern
        let baseHeight: CGFloat = 10
        let maxHeight: CGFloat = 50
        
        // Simple bell curve-ish scaling based on index
        let scale: CGFloat
        switch index {
        case 0, 4: scale = 0.4
        case 1, 3: scale = 0.7
        case 2: scale = 1.0
        default: scale = 0.5
        }
        
        // Dynamic height based on level
        let dynamicHeight = baseHeight + (maxHeight - baseHeight) * CGFloat(level) * scale
        return dynamicHeight
    }
}

#Preview {
    Waveform(level: 0.5)
}
