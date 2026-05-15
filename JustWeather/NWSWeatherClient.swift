import Foundation

struct NWSWeatherClient {
    private let baseURL = URL(string: "https://api.weather.gov")!
    private let session: URLSession

    nonisolated init(session: URLSession = .shared) {
        self.session = session
    }

    func pointMetadata(latitude: Double, longitude: Double) async throws -> NWSPointsResponse {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = "/points/\(latitude.roundedCoordinate),\(longitude.roundedCoordinate)"

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        return try await fetch(url)
    }

    func forecast(from url: URL) async throws -> NWSForecastResponse {
        try await fetch(url)
    }

    func activeAlerts(latitude: Double, longitude: Double) async throws -> NWSAlertsResponse {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = "/alerts/active"
        components?.queryItems = [
            URLQueryItem(name: "point", value: "\(latitude.roundedCoordinate),\(longitude.roundedCoordinate)")
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        return try await fetch(url)
    }

    private func fetch<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("JustWeather Apple clone (contact: https://github.com/fa1sepr0phet/JustWeather)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/geo+json, application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WeatherError.requestFailed
        }

        if httpResponse.statusCode == 404 {
            throw WeatherError.unsupportedLocation
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw WeatherError.requestFailed
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

enum WeatherError: LocalizedError {
    case requestFailed
    case unsupportedLocation
    case locationUnavailable
    case geocodingFailed(String)
    case repositoryNotReady

    var errorDescription: String? {
        switch self {
        case .requestFailed:
            "The weather service did not return a usable response."
        case .unsupportedLocation:
            "Unable to retrieve location. The National Weather Service only provides data for the United States."
        case .locationUnavailable:
            "Could not get the current device location. Make sure location is on and try again."
        case .geocodingFailed(let address):
            "No location match found for '\(address)'."
        case .repositoryNotReady:
            "Weather storage is not ready yet."
        }
    }
}
