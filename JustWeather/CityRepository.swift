import Foundation

actor CityRepository {
    private var cities: [CitySuggestion] = []

    func searchCities(_ query: String) async -> [CitySuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            return []
        }

        if cities.isEmpty {
            cities = loadCities()
        }

        return cities
            .lazy
            .filter { suggestion in
                suggestion.fullDisplay.localizedCaseInsensitiveContains(trimmed) ||
                suggestion.city.localizedCaseInsensitiveContains(trimmed)
            }
            .prefix(5)
            .map { $0 }
    }

    private func loadCities() -> [CitySuggestion] {
        guard let url = Bundle.main.url(forResource: "us_cities", withExtension: "txt"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }

        return contents
            .split(separator: "\n")
            .compactMap { line in
                let parts = line.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                guard parts.count >= 4,
                      let latitude = Double(parts[2]),
                      let longitude = Double(parts[3]) else {
                    return nil
                }

                return CitySuggestion(
                    city: parts[0],
                    state: parts[1],
                    latitude: latitude,
                    longitude: longitude
                )
            }
    }
}
