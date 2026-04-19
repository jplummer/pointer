import SwiftUI

struct ContentView: View {
  var body: some View {
    ZStack {
      ArrowSceneView()
        .ignoresSafeArea()
      VStack {
        Text("Pointer")
          .font(.title2.weight(.semibold))
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(.ultraThinMaterial, in: Capsule())
        Spacer()
        Text("Tilt the device to look around the arrow. Bearing math comes next.")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding()
      }
      .padding(.top, 16)
    }
  }
}

