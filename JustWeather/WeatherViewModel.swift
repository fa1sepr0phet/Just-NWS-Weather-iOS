import Foundation
import Combine
import SwiftData

@MainActor
final class WeatherViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var saveLabel = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var forecastResult: ForecastLoadResult?
    @Published var savedLocations: [SavedLocation] = []
    @Published var citySuggestions: [CitySuggestion] = []

    private var repository: WeatherRepository?
    private let cityRepository = CityRepository()
    private var searchTask: Task<Void, Never>?

    var locationName: String {
        forecastResult?.locationName ?? "NWS Weather"
    }

    func configure(modelContext: ModelContext) {
        guard repository == nil else {
            return
        }

        repository = WeatherRepository(modelContext: modelContext)
        reloadSavedLocations()

        Task { @MainActor in
            await refreshLatestSnapshot()
        }
    }

    func prepareSearch() {
        searchTask?.cancel()
        searchQuery = ""
        saveLabel = ""
        citySuggestions = []
    }

    func updateSearchQuery(_ value: String) {
        searchQuery = value
        searchTask?.cancel()

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            citySuggestions = []
            return
        }

        searchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else {
                return
            }
            citySuggestions = await cityRepository.searchCities(trimmed)
        }
    }

    func selectCitySuggestion(_ suggestion: CitySuggestion) {
        searchTask?.cancel()
        searchQuery = suggestion.fullDisplay
        citySuggestions = []

        let label = saveLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        launchLoad {
            guard let repository = self.repository else {
                throw WeatherError.repositoryNotReady
            }
            return try await repository.loadForecastForSuggestion(
                suggestion,
                label: label.isEmpty ? nil : label
            )
        }
    }

    func useCurrentLocation() {
        launchLoad {
            guard let repository = self.repository else {
                throw WeatherError.repositoryNotReady
            }
            return try await repository.loadCurrentLocationForecast()
        }
    }

    func searchAddress() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return
        }

        citySuggestions = []
        let label = saveLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        launchLoad {
            guard let repository = self.repository else {
                throw WeatherError.repositoryNotReady
            }
            return try await repository.loadForecastForAddress(
                address: query,
                label: label.isEmpty ? nil : label
            )
        }
    }

    func refreshForecast() {
        guard let result = forecastResult else {
            useCurrentLocation()
            return
        }

        launchLoad {
            guard let repository = self.repository else {
                throw WeatherError.repositoryNotReady
            }
            return try await repository.loadForecast(
                latitude: result.latitude,
                longitude: result.longitude,
                source: result.source
            )
        }
    }

    func loadSavedLocation(_ location: SavedLocation) {
        launchLoad {
            guard let repository = self.repository else {
                throw WeatherError.repositoryNotReady
            }
            return try await repository.loadForecastForSavedLocation(location)
        }
    }

    func deleteSavedLocation(_ location: SavedLocation) {
        do {
            try repository?.deleteSavedLocation(location)
            reloadSavedLocations()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    private func refreshLatestSnapshot() async {
        do {
            if let result = try await repository?.refreshLatestSnapshot() {
                forecastResult = result
            }
        } catch {
            errorMessage = nil
        }
    }

    private func reloadSavedLocations() {
        do {
            savedLocations = try repository?.savedLocations() ?? []
        } catch {
            savedLocations = []
        }
    }

    private func launchLoad(_ load: @escaping () async throws -> ForecastLoadResult) {
        Task { @MainActor in
            isLoading = true
            errorMessage = nil

            do {
                forecastResult = try await load()
                searchQuery = ""
                saveLabel = ""
                citySuggestions = []
                reloadSavedLocations()
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }
}
