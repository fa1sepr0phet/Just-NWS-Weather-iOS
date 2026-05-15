import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = WeatherViewModel()
    @AppStorage("justWeather.theme") private var appTheme: AppTheme = .system
    @AppStorage("justWeather.temperatureUnit") private var temperatureUnit: TemperatureUnit = .fahrenheit
    @AppStorage("justWeather.notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("justWeather.showTutorial") private var showTutorial = true
    @State private var isShowingSearch = false

    private var currentPeriod: NWSForecastPeriod? {
        viewModel.forecastResult?.currentPeriod
    }

    private var mood: WeatherMood {
        mapWeatherMood(
            forecast: currentPeriod?.shortForecast ?? "",
            isDaytime: currentPeriod?.isDaytime ?? true
        )
    }

    private var currentVisuals: WeatherVisuals {
        visuals(for: mood, theme: appTheme)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: currentVisuals.colors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                WeatherAtmosphereView(mood: mood)
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if let result = viewModel.forecastResult, !result.alerts.isEmpty {
                            AlertBanner(result: result)
                        }

                        if !viewModel.savedLocations.isEmpty {
                            Text("Saved locations")
                                .font(.headline)
                                .foregroundStyle(currentVisuals.chromeColor)

                            SavedLocationChips(
                                locations: viewModel.savedLocations,
                                textColor: currentVisuals.chromeColor,
                                onSelect: viewModel.loadSavedLocation
                            )
                        }

                        if viewModel.isLoading {
                            ProgressView("Loading forecast...")
                                .tint(currentVisuals.chromeColor)
                                .foregroundStyle(currentVisuals.chromeColor)
                        }

                        if let result = viewModel.forecastResult {
                            if let current = result.currentPeriod {
                                WeatherHeroCard(
                                    period: current,
                                    locationName: result.locationName,
                                    temperatureUnit: temperatureUnit,
                                    visuals: currentVisuals,
                                    nwsURL: nwsURL(latitude: result.latitude, longitude: result.longitude)
                                )
                            }

                            if !result.upcomingPeriods.isEmpty {
                                Divider()
                                    .overlay(currentVisuals.chromeColor.opacity(0.3))

                                Text("Upcoming forecast")
                                    .font(.headline)
                                    .foregroundStyle(currentVisuals.chromeColor)

                                ForEach(groupedForecastPeriods(result.upcomingPeriods), id: \.self) { periods in
                                    ForecastCard(
                                        periods: periods,
                                        temperatureUnit: temperatureUnit,
                                        visuals: currentVisuals,
                                        nwsURL: nwsURL(latitude: result.latitude, longitude: result.longitude)
                                    )
                                }
                            }
                        } else if !viewModel.isLoading {
                            EmptyForecastView(
                                textColor: currentVisuals.chromeColor,
                                onSearch: { isShowingSearch = true },
                                onCurrentLocation: viewModel.useCurrentLocation
                            )
                        }
                    }
                    .padding(16)
                }
                .refreshable {
                    viewModel.refreshForecast()
                }
            }
            .navigationTitle(viewModel.locationName)
            .toolbar {
                ToolbarItemGroup(placement: toolbarPlacement) {
                    Button {
                        viewModel.prepareSearch()
                        isShowingSearch = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                    .accessibilityLabel("Search and saved locations")

                    Menu {
                        Picker("Temperature", selection: $temperatureUnit) {
                            ForEach(TemperatureUnit.allCases) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }

                        Toggle("Weather Alerts", isOn: $notificationsEnabled)

                        Divider()

                        Picker("Theme", selection: $appTheme) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.rawValue).tag(theme)
                            }
                        }

                        Divider()

                        Button {
                            showTutorial = true
                        } label: {
                            Label("App Tutorial", systemImage: "questionmark.circle")
                        }
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")

                    Button {
                        viewModel.refreshForecast()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel("Refresh forecast")
                }
            }
            .sheet(isPresented: $isShowingSearch) {
                SearchSheet(
                    viewModel: viewModel,
                    visuals: currentVisuals,
                    onDone: { isShowingSearch = false }
                )
            }
            .overlay {
                if showTutorial {
                    TutorialOverlay {
                        showTutorial = false
                    }
                }
            }
            .alert("Weather unavailable", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.dismissError() } }
            )) {
                Button("OK", role: .cancel) {
                    viewModel.dismissError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .task {
                viewModel.configure(modelContext: modelContext)
            }
        }
    }
}

private struct SearchSheet: View {
    @ObservedObject var viewModel: WeatherViewModel
    let visuals: WeatherVisuals
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Search")
                            .font(.headline)

                        TextField("Address or ZIP code", text: Binding(
                            get: { viewModel.searchQuery },
                            set: viewModel.updateSearchQuery
                        ))
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.search)
                            .onSubmit {
                                viewModel.searchAddress()
                                onDone()
                            }

                        if !viewModel.citySuggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(viewModel.citySuggestions) { suggestion in
                                    Button {
                                        viewModel.selectCitySuggestion(suggestion)
                                        onDone()
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "magnifyingglass")
                                                .foregroundStyle(.secondary)
                                            Text(suggestion.fullDisplay)
                                                .foregroundStyle(.primary)
                                            Spacer()
                                        }
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 12)
                                    }
                                    .buttonStyle(.plain)

                                    if suggestion.id != viewModel.citySuggestions.last?.id {
                                        Divider()
                                    }
                                }
                            }
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }

                        TextField("Save as label (optional)", text: $viewModel.saveLabel)
                            .textFieldStyle(.roundedBorder)

                        HStack(spacing: 12) {
                            Button {
                                viewModel.searchAddress()
                                onDone()
                            } label: {
                                Label("Search forecast", systemImage: "magnifyingglass")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button {
                                viewModel.useCurrentLocation()
                                onDone()
                            } label: {
                                Label("Current location", systemImage: "location")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if !viewModel.savedLocations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Manage saved locations")
                                .font(.headline)

                        ForEach(viewModel.savedLocations) { location in
                            HStack(spacing: 12) {
                                Button {
                                    viewModel.loadSavedLocation(location)
                                    onDone()
                                } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(location.label)
                                            .font(.body)
                                        Text(location.address)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)

                                Spacer()

                                Button(role: .destructive) {
                                    viewModel.deleteSavedLocation(location)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .accessibilityLabel("Delete \(location.label)")
                            }
                                .padding(.vertical, 6)
                        }
                    }
                }
                }
                .padding(20)
            }
            .navigationTitle("Locations")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
        .weatherSheetSizing()
    }
}

private var toolbarPlacement: ToolbarItemPlacement {
#if os(iOS) || os(visionOS)
    .topBarTrailing
#else
    .automatic
#endif
}

private extension View {
    @ViewBuilder
    func weatherSheetSizing() -> some View {
#if os(iOS) || os(visionOS)
        presentationDetents([.medium, .large])
#else
        self
#endif
    }
}


private struct EmptyForecastView: View {
    let textColor: Color
    let onSearch: () -> Void
    let onCurrentLocation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Search an address or use your current location to load a forecast.")
                .font(.body)

            HStack {
                Button(action: onSearch) {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)

                Button(action: onCurrentLocation) {
                    Label("Current location", systemImage: "location")
                }
                .buttonStyle(.bordered)
            }
        }
        .foregroundStyle(textColor)
        .padding(.top, 12)
    }
}

private struct TutorialOverlay: View {
    let onDismiss: () -> Void
    @State private var step = 0

    private let steps = [
        "Welcome to Just NWS Weather. Pull down to refresh the forecast for your selected location.",
        "Open the settings button to search for a city, change units, and manage saved locations.",
        "Type a city or ZIP code. City suggestions are matched locally from the bundled U.S. city list.",
        "Saved locations stay on this device. Weather data comes from the National Weather Service.",
        "You're all set: no ads, no tracking, just weather."
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.86)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button("Skip", action: onDismiss)
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer()

                Text(steps[step])
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)

                Button {
                    if step < steps.count - 1 {
                        step += 1
                    } else {
                        onDismiss()
                    }
                } label: {
                    Text(step < steps.count - 1 ? "Continue" : "Got it")
                        .frame(maxWidth: 220)
                }
                .buttonStyle(.borderedProminent)

                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == step ? Color.accentColor : Color.white.opacity(0.32))
                            .frame(width: 8, height: 8)
                    }
                }

                Spacer()
            }
            .padding(32)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Item.self, SavedLocation.self, PointCacheEntry.self, WeatherSnapshot.self], inMemory: true)
}
