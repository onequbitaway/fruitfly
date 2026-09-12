import AppKit
import SwiftUI

struct ControlPanel: View {
    @ObservedObject var controller: PetController
    @State private var showDetails = false
    private let blue = Color(red: 0.27, green: 0.39, blue: 0.82)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Fruitfly").font(.system(size: 25, weight: .semibold, design: .rounded))
                    Text("A small pet for your desktop.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(nsImage: FlyPainter.icon(size: 48)).frame(width: 48, height: 48)
            }
            HStack(spacing: 7) {
                Circle().fill(controller.paused || controller.hidden ? Color.gray : Color.green).frame(width: 6, height: 6)
                Text(controller.hidden ? "Hidden" : (controller.paused ? "Paused" : controller.stateName))
                Spacer()
                Text("\(controller.meals) \(controller.meals == 1 ? "crumb" : "crumbs") eaten").foregroundStyle(.secondary)
            }.font(.system(size: 12))
            VStack(spacing: 9) {
                Button(action: controller.placeFood) {
                    Label("Place food", systemImage: "plus").frame(maxWidth: .infinity).padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent).tint(blue).controlSize(.large)
                .keyboardShortcut("f", modifiers: [])
                Text("Or hold Option and double-click.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Divider()
            HStack {
                Text("Fly size").font(.system(size: 12))
                Slider(value: $controller.size, in: 0.8...2.2).tint(blue).accessibilityLabel("Fly size")
                Text("\(Int(controller.size / 1.3 * 100))%")
                    .font(.system(size: 11)).monospacedDigit().frame(width: 34, alignment: .trailing)
            }
            Toggle("Show brain activity", isOn: $controller.showBrain)
                .disabled(controller.world.circuit == nil)
                .toggleStyle(.switch).controlSize(.small).font(.system(size: 12)).tint(blue)
            HStack(spacing: 8) {
                Button { controller.paused.toggle() } label: {
                    Label(controller.paused ? "Resume" : "Pause", systemImage: controller.paused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                Button { controller.hidden.toggle() } label: {
                    Label(controller.hidden ? "Show fly" : "Hide fly", systemImage: controller.hidden ? "eye" : "eye.slash")
                        .frame(maxWidth: .infinity)
                }
            }.buttonStyle(.bordered).controlSize(.regular)
            HStack {
                Button("Bring fly here", action: controller.bringHere)
                Spacer()
                Button("Clear food", action: controller.clearFood).disabled(controller.crumbCount == 0)
            }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Color.accentColor)
            Divider()
            Button { showDetails.toggle() } label: {
                HStack {
                    Image(systemName: "info.circle")
                    Text("About the fly")
                    Spacer()
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down").font(.system(size: 9))
                }
            }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
            if showDetails {
                VStack(alignment: .leading, spacing: 8) {
                    if let circuit = controller.world.circuit {
                        Text("A small smell circuit uses \(circuit.neuronCount.formatted()) cells from the MaleCNS fly brain map.")
                        Text("The brain view shows live model values. Each dot is one cell. Dot positions do not show anatomy.")
                        Text("The circuit changes speed and turns. Food search, rest, and eating use programmed rules.")
                    } else {
                        Text("Brain data is missing. Movement uses programmed rules. Download a fresh copy to restore the data.")
                    }
                    Text("Option-double-click also reaches the app below. Use Place food to capture one click instead.")
                    Text("The app stays on one screen. Use Bring fly here to move it to another screen.")
                    Link("Code and data sources", destination: URL(string: "https://github.com/onequbitaway/fruitfly")!)
                }.font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Text("Runs on your Mac. No account.").font(.system(size: 10)).foregroundStyle(.tertiary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q").buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .frame(width: 310)
    }
}
