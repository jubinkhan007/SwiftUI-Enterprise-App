import SwiftUI
import DesignSystem

public struct ChatInputBar: View {
    @Binding var text: String
    let onSend: () -> Void
    
    public init(text: Binding<String>, onSend: @escaping () -> Void) {
        self._text = text
        self.onSend = onSend
    }
    
    public var body: some View {
        HStack(spacing: AppSpacing.sm) {
            TextField("Type a message...", text: $text)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppColors.surfaceElevated)
                .clipShape(Capsule())
            
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundColor(text.trimmingCharacters(in: .whitespaces).isEmpty ? AppColors.textSecondary : AppColors.brandPrimary)
            }
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
        .background(AppColors.backgroundPrimary)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(AppColors.borderDefault)
                .padding(.top, 0),
            alignment: .top
        )
    }
}
