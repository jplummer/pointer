import Foundation

struct GroundTargetsPayload: Decodable {
  let schemaVersion: Int
  let targets: [GroundTarget]
}

struct GroundTarget: Decodable, Identifiable, Hashable {
  let id: String
  let displayName: String
  let group: String
  let latitude: Double
  let longitude: Double
  let notes: String
  let sources: [String]
}

enum GroundTargetsBundle {
  static func loadTargets() -> [GroundTarget] {
    guard let url = Bundle.main.url(forResource: "GroundTargets", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let payload = try? JSONDecoder().decode(GroundTargetsPayload.self, from: data)
    else {
      return []
    }
    return payload.targets
  }
}
