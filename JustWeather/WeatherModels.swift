import Foundation
import SwiftData

struct NWSPointsResponse: Decodable, Sendable {
    let properties: NWSPointProperties
}

struct NWSPointProperties: Decodable, Sendable {
    let gridId: String
    let gridX: Int
    let gridY: Int
    let forecast: URL
    let forecastHourly: URL
    let forecastGridData: URL
    let timeZone: String?
    let relativeLocation: NWSRelativeLocation?
}

struct NWSRelativeLocation: Decodable, Sendable {
    let properties: NWSRelativeLocationProperties?
}

struct NWSRelativeLocationProperties: Decodable, Sendable {
    let city: String?
    let state: String?
}

struct NWSForecastResponse: Decodable, Sendable {
    let properties: NWSForecastProperties
}

struct NWSForecastProperties: Decodable, Sendable {
    let updated: String?
    let periods: [NWSForecastPeriod]
}

struct NWSForecastPeriod: Decodable, Identifiable, Hashable, Sendable {
    var id: Int { number }

    let number: Int
    let name: String
    let startTime: String
    let endTime: String
    let isDaytime: Bool
    let temperature: Int
    let temperatureUnit: String
    let shortForecast: String?
    let detailedForecast: String?
    let windSpeed: String?
    let windDirection: String?
    let probabilityOfPrecipitation: NWSQuantifiedValue?
}

struct NWSQuantifiedValue: Decodable, Hashable, Sendable {
    let value: Double?
    let unitCode: String?
}

struct NWSAlertsResponse: Decodable, Sendable {
    let features: [NWSAlertFeature]
}

struct NWSAlertFeature: Decodable, Sendable {
    let properties: NWSAlertProperties
}

struct NWSAlertProperties: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let areaDesc: String?
    let headline: String?
    let description: String?
    let instruction: String?
    let severity: String?
    let certainty: String?
    let urgency: String?
    let event: String?
}

struct CitySuggestion: Identifiable, Hashable, Sendable {
    nonisolated var id: String { "\(city)-\(state)-\(latitude)-\(longitude)" }

    let city: String
    let state: String
    let latitude: Double
    let longitude: Double

    nonisolated var fullDisplay: String {
        "\(city), \(state)"
    }
}

enum TemperatureUnit: String, CaseIterable, Identifiable, Sendable {
    case fahrenheit = "Fahrenheit"
    case celsius = "Celsius"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .fahrenheit:
            "F"
        case .celsius:
            "C"
        }
    }
}

@Model
final class SavedLocation {
    var label: String
    var address: String
    var latitude: Double
    var longitude: Double
    var city: String?
    var state: String?

    init(
        label: String,
        address: String,
        latitude: Double,
        longitude: Double,
        city: String? = nil,
        state: String? = nil
    ) {
        self.label = label
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.city = city
        self.state = state
    }
}

@Model
final class PointCacheEntry {
    @Attribute(.unique) var key: String
    var gridId: String
    var gridX: Int
    var gridY: Int
    var forecastURL: URL
    var forecastHourlyURL: URL
    var forecastGridDataURL: URL
    var timeZone: String?
    var city: String?
    var state: String?
    var cachedAt: Date

    init(
        key: String,
        gridId: String,
        gridX: Int,
        gridY: Int,
        forecastURL: URL,
        forecastHourlyURL: URL,
        forecastGridDataURL: URL,
        timeZone: String?,
        city: String?,
        state: String?,
        cachedAt: Date = Date()
    ) {
        self.key = key
        self.gridId = gridId
        self.gridX = gridX
        self.gridY = gridY
        self.forecastURL = forecastURL
        self.forecastHourlyURL = forecastHourlyURL
        self.forecastGridDataURL = forecastGridDataURL
        self.timeZone = timeZone
        self.city = city
        self.state = state
        self.cachedAt = cachedAt
    }
}

@Model
final class WeatherSnapshot {
    @Attribute(.unique) var id: String
    var locationName: String
    var latitude: Double
    var longitude: Double
    var temperature: Int
    var temperatureUnit: String
    var shortForecast: String
    var windSpeed: String
    var windDirection: String
    var updatedAt: Date
    var isDaytime: Bool

    init(
        id: String = "latest",
        locationName: String,
        latitude: Double,
        longitude: Double,
        temperature: Int,
        temperatureUnit: String,
        shortForecast: String,
        windSpeed: String,
        windDirection: String,
        updatedAt: Date = Date(),
        isDaytime: Bool
    ) {
        self.id = id
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.temperature = temperature
        self.temperatureUnit = temperatureUnit
        self.shortForecast = shortForecast
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.updatedAt = updatedAt
        self.isDaytime = isDaytime
    }
}

struct ForecastLoadResult: Sendable {
    let forecast: NWSForecastResponse
    let alerts: [NWSAlertProperties]
    let locationName: String
    let latitude: Double
    let longitude: Double
    let source: ForecastSource

    var currentPeriod: NWSForecastPeriod? {
        forecast.properties.periods.first
    }

    var upcomingPeriods: [NWSForecastPeriod] {
        Array(forecast.properties.periods.dropFirst())
    }
}

enum ForecastSource: Equatable, Sendable {
    case currentLocation
    case addressSearch(String)
    case savedLocation(String)
    case coordinates
}

extension Double {
    var roundedCoordinate: Double {
        (self * 10_000).rounded() / 10_000
    }
}
