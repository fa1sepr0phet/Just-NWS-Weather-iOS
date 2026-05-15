import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    case midnight = "Midnight"

    var id: String { rawValue }
}

enum WeatherMood {
    case sunny
    case cloudy
    case rain
    case storm
    case snow
    case clearNight
    case cloudyNight
}

struct WeatherVisuals {
    let colors: [Color]
    let cardColor: Color
    let textColor: Color
    let chromeColor: Color
}

func mapWeatherMood(forecast: String, isDaytime: Bool) -> WeatherMood {
    let text = forecast.lowercased()

    if text.contains("storm") || text.contains("thunder") {
        return .storm
    }

    if text.contains("snow") || text.contains("flurr") || text.contains("sleet") {
        return .snow
    }

    if text.contains("rain") || text.contains("shower") || text.contains("drizzle") {
        return .rain
    }

    if text.contains("cloud") || text.contains("overcast") {
        return isDaytime ? .cloudy : .cloudyNight
    }

    return isDaytime ? .sunny : .clearNight
}

func visuals(for mood: WeatherMood, theme: AppTheme) -> WeatherVisuals {
    if theme == .midnight {
        return WeatherVisuals(
            colors: [.black, .black],
            cardColor: Color(red: 0.07, green: 0.07, blue: 0.07).opacity(0.82),
            textColor: .white,
            chromeColor: .white
        )
    }

    switch mood {
    case .sunny:
        return WeatherVisuals(
            colors: [Color(red: 0.41, green: 0.72, blue: 1.0), Color(red: 0.67, green: 0.85, blue: 1.0), Color(red: 1.0, green: 0.84, blue: 0.48)],
            cardColor: .white.opacity(0.72),
            textColor: .black,
            chromeColor: .white
        )
    case .cloudy:
        return WeatherVisuals(
            colors: [Color(red: 0.56, green: 0.64, blue: 0.69), Color(red: 0.72, green: 0.78, blue: 0.82), Color(red: 0.89, green: 0.91, blue: 0.93)],
            cardColor: .white.opacity(0.74),
            textColor: .black,
            chromeColor: .white
        )
    case .rain:
        return WeatherVisuals(
            colors: [Color(red: 0.21, green: 0.36, blue: 0.49), Color(red: 0.31, green: 0.43, blue: 0.48), Color(red: 0.49, green: 0.60, blue: 0.64)],
            cardColor: .white.opacity(0.76),
            textColor: .black,
            chromeColor: .white
        )
    case .storm:
        return WeatherVisuals(
            colors: [Color(red: 0.09, green: 0.13, blue: 0.24), Color(red: 0.14, green: 0.22, blue: 0.36), Color(red: 0.24, green: 0.31, blue: 0.46)],
            cardColor: .white.opacity(0.78),
            textColor: .black,
            chromeColor: .white
        )
    case .snow:
        return WeatherVisuals(
            colors: [Color(red: 0.87, green: 0.92, blue: 0.97), Color(red: 0.96, green: 0.98, blue: 0.99), .white],
            cardColor: .white.opacity(0.8),
            textColor: .black,
            chromeColor: .black
        )
    case .clearNight:
        return WeatherVisuals(
            colors: [Color(red: 0.04, green: 0.07, blue: 0.12), Color(red: 0.08, green: 0.14, blue: 0.24), Color(red: 0.13, green: 0.23, blue: 0.37)],
            cardColor: .white.opacity(0.78),
            textColor: .black,
            chromeColor: .white
        )
    case .cloudyNight:
        return WeatherVisuals(
            colors: [Color(red: 0.10, green: 0.15, blue: 0.20), Color(red: 0.17, green: 0.24, blue: 0.31), Color(red: 0.25, green: 0.36, blue: 0.46)],
            cardColor: .white.opacity(0.78),
            textColor: .black,
            chromeColor: .white
        )
    }
}
