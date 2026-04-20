import SwiftUI

/// Selected catalog row drives ground aim (`ArrowSceneView` + Core Location).
final class AimSession: ObservableObject {
  enum AimMode: Equatable {
    case ground(GroundTarget)

    var title: String {
      switch self {
      case .ground(let t): return t.displayName
      }
    }

    var caption: String {
      switch self {
      case .ground(let t): return t.notes
      }
    }
  }

  /// Convenience for UI that always uses a catalog row (no alternate aim modes yet).
  var selectedGroundTarget: GroundTarget {
    switch aimMode {
    case .ground(let t): return t
    }
  }

  @Published var pickerExpanded = false
  @Published var aimMode: AimMode

  let catalog: [GroundTarget]

  private static let groupOrder = [
    "seven_ancient_wonders",
    "new7_wonders_winner",
    "new7_finalist",
    "seed_plan",
  ]

  init() {
    catalog = GroundTargetsBundle.loadTargets()
    guard let first = catalog.first else {
      preconditionFailure("GroundTargets.json must contain at least one catalog entry.")
    }
    aimMode = .ground(first)
  }

  var groupedCatalog: [(key: String, title: String, targets: [GroundTarget])] {
    let grouped = Dictionary(grouping: catalog, by: \.group)
    return Self.groupOrder.compactMap { key in
      guard let list = grouped[key], !list.isEmpty else { return nil }
      let sorted = list.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
      return (key, Self.groupSectionTitle(key), sorted)
    }
  }

  private static func groupSectionTitle(_ key: String) -> String {
    switch key {
    case "seven_ancient_wonders": return "Seven ancient wonders"
    case "new7_wonders_winner": return "New 7 Wonders · winners"
    case "new7_finalist": return "New 7 Wonders · finalists"
    case "seed_plan": return "More places"
    default: return key.replacingOccurrences(of: "_", with: " ").capitalized
    }
  }
}

struct TargetPickerExpando: View {
  @ObservedObject var session: AimSession

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button {
        withAnimation(.snappy(duration: 0.28)) {
          session.pickerExpanded.toggle()
        }
      } label: {
        HStack(alignment: .top, spacing: 10) {
          VStack(alignment: .leading, spacing: 6) {
            Text("Pointing at")
              .font(.caption.weight(.semibold))
              .tracking(0.6)
              .foregroundStyle(Color.white.opacity(0.92))
            Text(session.aimMode.title)
              .font(.title3.weight(.bold))
              .foregroundStyle(Color.white)
              .multilineTextAlignment(.leading)
              .shadow(color: .black.opacity(0.45), radius: 3, x: 0, y: 1)
            if !session.pickerExpanded {
              Text(session.aimMode.caption)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(4)
            }
          }
          Spacer(minLength: 8)
          Image(systemName: session.pickerExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
            .font(.title2)
            .foregroundStyle(Color.white.opacity(0.88))
            .accessibilityHidden(true)
        }
      }
      .buttonStyle(.plain)

      if session.pickerExpanded {
        Divider()
          .overlay(Color.white.opacity(0.14))
          .padding(.vertical, 12)

        ScrollViewReader { proxy in
          ScrollView {
            VStack(alignment: .leading, spacing: 18) {
              ForEach(session.groupedCatalog, id: \.key) { section in
                catalogSection(title: section.title, targets: section.targets)
              }
            }
            .padding(.bottom, 6)
            .onAppear {
              // LazyVStack omitted: distant rows must exist before scrollTo(…) or reopening leaves you at the top.
              scrollSelectionIntoView(proxy: proxy)
            }
          }
          .frame(maxHeight: 320)
        }
      }
    }
    .padding(14)
    .background {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(Color.black.opacity(0.62))
        .overlay {
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        }
    }
    .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Pointing at, \(session.aimMode.title)")
  }

  private func scrollSelectionIntoView(proxy: ScrollViewProxy) {
    let id = session.selectedGroundTarget.id
    Task { @MainActor in
      // One layout pass so ScrollView has resolved content size after expand.
      try? await Task.sleep(for: .milliseconds(32))
      withAnimation(.easeInOut(duration: 0.28)) {
        proxy.scrollTo(id, anchor: .center)
      }
    }
  }

  private func catalogSection(title: String, targets: [GroundTarget]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionHeader(title)
      ForEach(targets) { target in
        selectRow(
          title: target.displayName,
          subtitle: nil,
          selected: session.selectedGroundTarget.id == target.id
        ) {
          session.aimMode = .ground(target)
          session.pickerExpanded = false
        }
        .id(target.id)
      }
    }
  }

  private func sectionHeader(_ text: String) -> some View {
    Text(text)
      .font(.caption.weight(.semibold))
      .foregroundStyle(Color.white.opacity(0.72))
      .textCase(.uppercase)
      .tracking(0.5)
  }

  private func selectRow(title: String, subtitle: String?, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.white)
            .multilineTextAlignment(.leading)
          if let subtitle {
            Text(subtitle)
              .font(.caption)
              .foregroundStyle(Color.white.opacity(0.65))
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        Spacer(minLength: 8)
        if selected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(Color.accentColor)
            .accessibilityLabel("Selected")
        }
      }
      .padding(.vertical, 8)
      .padding(.horizontal, 10)
      .background {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(selected ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
      }
    }
    .buttonStyle(.plain)
  }
}
