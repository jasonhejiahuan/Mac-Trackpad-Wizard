import SwiftUI

struct TouchPreviewControls: View {
    @Bindable var model: AppModel
    var showsRestingTouches = false

    var body: some View {
        HStack(spacing: 12) {
            Picker("Visualization", selection: $model.visualizationMode) {
                ForEach(TouchVisualizationMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 360)

            Picker("Size", selection: $model.touchSurfaceSizeMode) {
                ForEach(TouchSurfaceSizeMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .frame(width: 155)

            Spacer()

            if showsRestingTouches {
                Toggle("Resting Touches", isOn: $model.showRestingTouches)
                    .toggleStyle(.switch)
            }
        }
    }
}
