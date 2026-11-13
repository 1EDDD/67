import SwiftUI
import UIKit

struct PresetPickerView: View {
    let onSelect: (DeviceResolutionPreset) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: PresetDeviceCategory?

    var body: some View {
        NavigationStack {
            List {
                if let category = selectedCategory {
                    Section {
                        ForEach(DeviceResolutionPreset.all.filter { $0.category == category }) { preset in
                            Button {
                                onSelect(preset)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Text(preset.name)
                                        .foregroundStyle(.primary)
                                    Spacer(minLength: 10)
                                    Text(preset.resolution.displayValue)
                                        .font(.body.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    Section {
                        categoryRow(.iphone, icon: "iphone")
                        categoryRow(.ipad, icon: "ipad")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(selectedCategory?.rawValue ?? "Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selectedCategory != nil {
                        Button {
                            selectedCategory = nil
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .toolbarBackground(Color(uiColor: .systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    private func categoryRow(_ category: PresetDeviceCategory, icon: String) -> some View {
        Button {
            selectedCategory = category
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 21))
                    .foregroundStyle(.tint)
                    .frame(width: 28)
                Text(category.rawValue)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
