import SwiftUI

struct ContentView: View {
  @StateObject private var aimSession = AimSession()

  var body: some View {
    ZStack {
      CameraPreviewView()
        .ignoresSafeArea()

      ArrowSceneView()
        .ignoresSafeArea()

      VStack(spacing: 0) {
        TargetPickerExpando(session: aimSession)
          .padding(.horizontal, 16)
          .padding(.top, 12)

        Spacer(minLength: 0)

        footerBar
      }
    }
  }

  private var footerBar: some View {
    Text(footerCopy)
      .font(.footnote.weight(.medium))
      .foregroundStyle(Color.white)
      .multilineTextAlignment(.center)
      .padding(.horizontal, 18)
      .padding(.vertical, 14)
      .frame(maxWidth: .infinity)
      .background {
        Rectangle()
          .fill(Color.black.opacity(0.78))
          .ignoresSafeArea(edges: .bottom)
      }
      .overlay(alignment: .top) {
        Divider()
          .overlay(Color.white.opacity(0.18))
      }
  }

  private var footerCopy: String {
    switch aimSession.aimMode {
    case .stubMotionReference:
      return "Next: Core Location + bearing math → arrow follows catalog picks."
    case .ground:
      return "Catalog pick saved. Arrow still uses the motion stub until Core Location lands."
    }
  }
}
