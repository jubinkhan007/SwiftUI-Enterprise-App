import SwiftUI
import DesignSystem

public struct ChatInputBar: View {
    @Binding var text: String
    let isEditing: Bool
    let onCancelEdit: (() -> Void)?
    let onSend: () -> Void
    
    public init(text: Binding<String>, isEditing: Bool = false, onCancelEdit: (() -> Void)? = nil, onSend: @escaping () -> Void) {
        self._text = text
        self.isEditing = isEditing
        self.onCancelEdit = onCancelEdit
        self.onSend = onSend
    }
    
    public var body: some View {
        HStack(spacing: AppSpacing.sm) {
            if isEditing {
                Button(action: { onCancelEdit?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(AppColors.statusError)
                }
            }
            
            TextField("Type a message...", text: $text)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppColors.surfaceElevated)
                .clipShape(Capsule())
            
            Button(action: onSend) {
                Image(systemName: isEditing ? "checkmark.circle.fill" : "arrow.up.circle.fill")
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
