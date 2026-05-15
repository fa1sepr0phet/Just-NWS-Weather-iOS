import CoreLocation
import Foundation
import MapKit
import SwiftData

@MainActor
final class WeatherRepository {
    private let modelContext: ModelContext
    private let client: NWSWeatherClient
    private let locationProvider: DeviceLocationProvider

    init(
        modelContext: ModelContext,
        client: NWSWeatherClient? = nil,
        locationProvider: DeviceLocationProvider? = nil
    ) {
        self.modelContext = modelContext
        self.client = client ?? NWSWeatherClient()
        self.locationProvider = locationProvider ?? DeviceLocationProvider()
    }

    func savedLocations() throws -> [SavedLocation] {
        var descriptor = FetchDescriptor<SavedLocation>(
            sortBy: [SortDescriptor(\.label, order: .forward)]
        )
        descriptor.fetchLimit = 100
        return try modelContext.fetch(descriptor)
    }

    func deleteSavedLocation(_ location: SavedLocation) throws {
        modelContext.delete(location)
        try modelContext.save()
    }

    func loadCurrentLocationForecast() async throws -> ForecastLoadResult {
        let coordinate = try await locationProvider.currentCoordinate()
        return try await loadForecast(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            source: .currentLocation
        )
    }

    func loadForecastForAddress(address: String, label: String?) async throws -> ForecastLoadResult {
        let request = MKGeocodingRequest(addressString: address)
        guard let mapItems = try await request?.mapItems,
              let mapItem = mapItems.first else {
            throw WeatherError.geocodingFailed(address)
        }

        let addressRepresentations = mapItem.addressRepresentations
        let cityName = addressRepresentations?.cityName
        let cityWithContext = addressRepresentations?.cityWithContext
        let stateCode = cityWithContext?.stateCodeFromCityContext
        let matchedAddress = [
            mapItem.name,
            cityWithContext,
            mapItem.address?.shortAddress,
            mapItem.address?.fullAddress
        ]
            .compactMap { $0 }
            .removingDuplicates()
            .joined(separator: ", ")
            .ifBlank(address)

        let result = try await loadForecast(
            latitude: mapItem.location.coordinate.latitude,
            longitude: mapItem.location.coordinate.longitude,
            source: .addressSearch(matchedAddress)
        )

        if let label, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            saveLocation(
                label: label,
                address: matchedAddress,
                latitude: result.latitude,
                longitude: result.longitude,
                city: cityName,
                state: stateCode
            )
        }

        return result
    }

    func loadForecastForSuggestion(_ suggestion: CitySuggestion, label: String?) async throws -> ForecastLoadResult {
        let result = try await loadForecast(
            latitude: suggestion.latitude,
            longitude: suggestion.longitude,
            source: .addressSearch(suggestion.fullDisplay)
        )

        if let label, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            saveLocation(
                label: label,
                address: suggestion.fullDisplay,
                latitude: result.latitude,
                longitude: result.longitude,
                city: suggestion.city,
                state: suggestion.state
            )
        }

        return result
    }

    func loadForecastForSavedLocation(_ location: SavedLocation) async throws -> ForecastLoadResult {
        let result = try await loadForecast(
            latitude: location.latitude,
            longitude: location.longitude,
            source: .savedLocation(location.label)
        )

        let displayName = location.label.ifBlank(result.locationName)
        let adjusted = ForecastLoadResult(
            forecast: result.forecast,
            alerts: result.alerts,
            locationName: displayName,
            latitude: result.latitude,
            longitude: result.longitude,
            source: .savedLocation(location.label)
        )
        try saveSnapshot(adjusted)
        return adjusted
    }

    func refreshLatestSnapshot() async throws -> ForecastLoadResult? {
        var descriptor = FetchDescriptor<WeatherSnapshot>()
        descriptor.fetchLimit = 1
        guard let snapshot = try modelContext.fetch(descriptor).first else {
            return nil
        }

        return try await loadForecast(
            latitude: snapshot.latitude,
            longitude: snapshot.longitude,
            source: .coordinates
        )
    }

    func loadForecast(latitude: Double, longitude: Double, source: ForecastSource = .coordinates) async throws -> ForecastLoadResult {
        let roundedLatitude = latitude.roundedCoordinate
        let roundedLongitude = longitude.roundedCoordinate
        let point = try await getOrFetchPoint(latitude: roundedLatitude, longitude: roundedLongitude)

        let forecast = try await client.forecast(from: point.forecastURL)
        let alerts = await loadAlerts(latitude: roundedLatitude, longitude: roundedLongitude)

        let result = ForecastLoadResult(
            forecast: forecast,
            alerts: alerts,
            locationName: buildDisplayName(
                city: point.city,
                state: point.state,
                fallback: "\(roundedLatitude), \(roundedLongitude)"
            ),
            latitude: roundedLatitude,
            longitude: roundedLongitude,
            source: source
        )

        try saveSnapshot(result)
        return result
    }

    private func loadAlerts(latitude: Double, longitude: Double) async -> [NWSAlertProperties] {
        do {
            return try await client.activeAlerts(latitude: latitude, longitude: longitude).features.map(\.properties)
        } catch {
            return []
        }
    }

    private func getOrFetchPoint(latitude: Double, longitude: Double) async throws -> PointCacheEntry {
        let key = "\(latitude),\(longitude)"
        var descriptor = FetchDescriptor<PointCacheEntry>()
        descriptor.fetchLimit = 500

        if let cached = try modelContext.fetch(descriptor).first(where: { $0.key == key }) {
            return cached
        }

        let point = try await client.pointMetadata(latitude: latitude, longitude: longitude)
        let properties = point.properties
        let entry = PointCacheEntry(
            key: key,
            gridId: properties.gridId,
            gridX: properties.gridX,
            gridY: properties.gridY,
            forecastURL: properties.forecast,
            forecastHourlyURL: properties.forecastHourly,
            forecastGridDataURL: properties.forecastGridData,
            timeZone: properties.timeZone,
            city: properties.relativeLocation?.properties?.city,
            state: properties.relativeLocation?.properties?.state
        )

        modelContext.insert(entry)
        try modelContext.save()
        return entry
    }

    private func saveLocation(label: String, address: String, latitude: Double, longitude: Double, city: String?, state: String?) {
        let location = SavedLocation(
            label: label.trimmingCharacters(in: .whitespacesAndNewlines),
            address: address,
            latitude: latitude,
            longitude: longitude,
            city: city,
            state: state
        )
        modelContext.insert(location)
        try? modelContext.save()
    }

    private func saveSnapshot(_ result: ForecastLoadResult) throws {
        guard let current = result.currentPeriod else {
            return
        }

        var descriptor = FetchDescriptor<WeatherSnapshot>()
        descriptor.fetchLimit = 10

        if let snapshot = try modelContext.fetch(descriptor).first(where: { $0.id == "latest" }) {
            snapshot.locationName = result.locationName
            snapshot.latitude = result.latitude
            snapshot.longitude = result.longitude
            snapshot.temperature = current.temperature
            snapshot.temperatureUnit = current.temperatureUnit
            snapshot.shortForecast = current.shortForecast?.ifBlank("Forecast unavailable") ?? "Forecast unavailable"
            snapshot.windSpeed = current.windSpeed?.ifBlank("--") ?? "--"
            snapshot.windDirection = current.windDirection?.ifBlank("--") ?? "--"
            snapshot.updatedAt = Date()
            snapshot.isDaytime = current.isDaytime
        } else {
            modelContext.insert(
                WeatherSnapshot(
                    locationName: result.locationName,
                    latitude: result.latitude,
                    longitude: result.longitude,
                    temperature: current.temperature,
                    temperatureUnit: current.temperatureUnit,
                    shortForecast: current.shortForecast?.ifBlank("Forecast unavailable") ?? "Forecast unavailable",
                    windSpeed: current.windSpeed?.ifBlank("--") ?? "--",
                    windDirection: current.windDirection?.ifBlank("--") ?? "--",
                    isDaytime: current.isDaytime
                )
            )
        }

        try modelContext.save()
    }

    private func buildDisplayName(city: String?, state: String?, fallback: String) -> String {
        [city, state]
            .compactMap { $0?.ifBlank(nil) }
            .joined(separator: ", ")
            .ifBlank(fallback)
    }
}

private extension Array where Element == String {
    func removingDuplicates() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}

extension String {
    func ifBlank(_ fallback: String?) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? (fallback ?? "") : trimmed
    }

    var stateCodeFromCityContext: String? {
        split(separator: ",")
            .dropFirst()
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .ifBlank(nil)
    }
}
