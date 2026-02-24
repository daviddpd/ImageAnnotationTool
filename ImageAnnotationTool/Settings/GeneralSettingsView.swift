import SwiftUI

enum ImageAnnotationToolSettingsKeys {
    static let bottomInspectorFontScale = "settings.general.bottomInspectorFontScale"
}

struct GeneralSettingsTab: View {
    @AppStorage(ImageAnnotationToolSettingsKeys.bottomInspectorFontScale) private var bottomInspectorFontScale: Double = 1.5
    
    var body: some View {
        Form {
            Section("Bottom Inspector Font Size") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Size")
                        Spacer()
                        Text("\(Int((clampedBottomInspectorFontScale * 100).rounded()))%")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    
                    Slider(value: $bottomInspectorFontScale, in: 1.0...3.0, step: 0.1)
                    
                    HStack(spacing: 10) {
                        Button("Smaller") {
                            bottomInspectorFontScale = max(1.0, (bottomInspectorFontScale - 0.1).roundedToTenth)
                        }
                        Button("Larger") {
                            bottomInspectorFontScale = min(3.0, (bottomInspectorFontScale + 0.1).roundedToTenth)
                        }
                        Spacer()
                        Button("Reset to 150%") {
                            bottomInspectorFontScale = 1.5
                        }
                    }
                    .font(.system(size: 12))
                    
                    Text("Applies only to the bottom inspector panel in the annotation workspace. Other panels are unchanged.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
    
    private var clampedBottomInspectorFontScale: Double {
        min(max(bottomInspectorFontScale, 1.0), 3.0)
    }
}

private extension Double {
    var roundedToTenth: Double {
        (self * 10).rounded() / 10
    }
}

struct GeneralSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralSettingsTab()
    }
}
