import Foundation
import SwiftUI

struct WeatherAtmosphereView: View {
    let mood: WeatherMood

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                switch mood {
                case .rain, .storm:
                    drawRain(context: context, size: size, time: time)
                case .snow:
                    drawSnow(context: context, size: size, time: time)
                case .sunny:
                    drawSun(context: context, size: size, time: time)
                default:
                    break
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func drawRain(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        for index in 0..<56 {
            let x = CGFloat((index * 47) % 100) / 100 * size.width
            let speed = 180 + CGFloat(index % 8) * 18
            let y = CGFloat(time * Double(speed) + Double(index * 31)).truncatingRemainder(dividingBy: size.height + 48) - 48
            let path = Path { path in
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x + 8, y: y + 28))
            }
            context.stroke(path, with: .color(.white.opacity(0.32)), lineWidth: 2)
        }
    }

    private func drawSnow(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        for index in 0..<44 {
            let baseX = CGFloat((index * 37) % 100) / 100 * size.width
            let drift = CGFloat(sin(time + Double(index)) * 18)
            let speed = 32 + CGFloat(index % 7) * 6
            let y = CGFloat(time * Double(speed) + Double(index * 41)).truncatingRemainder(dividingBy: size.height + 24) - 24
            let radius = CGFloat(2 + index % 4)
            context.fill(
                Path(ellipseIn: CGRect(x: baseX + drift, y: y, width: radius * 2, height: radius * 2)),
                with: .color(.white.opacity(0.7))
            )
        }
    }

    private func drawSun(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let center = CGPoint(x: size.width - 88, y: 96)
        let radius: CGFloat = 52
        let rotation = CGFloat(time.truncatingRemainder(dividingBy: 20) / 20 * .pi * 2)

        for index in 0..<12 {
            let angle = rotation + CGFloat(index) * (.pi * 2 / 12)
            let start = CGPoint(x: center.x + cos(angle) * (radius + 12), y: center.y + sin(angle) * (radius + 12))
            let end = CGPoint(x: center.x + cos(angle) * (radius + 40), y: center.y + sin(angle) * (radius + 40))
            let path = Path { path in
                path.move(to: start)
                path.addLine(to: end)
            }
            context.stroke(path, with: .color(Color.yellow.opacity(0.52)), lineWidth: 7)
        }

        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
            with: .color(Color.yellow.opacity(0.88))
        )
    }
}

struct WeatherHeroCard: View {
    let period: NWSForecastPeriod
    let locationName: String
    let temperatureUnit: TemperatureUnit
    let visuals: WeatherVisuals
    let nwsURL: URL?

    var body: some View {
        Link(destination: nwsURL ?? URL(string: "https://weather.gov")!) {
            VStack(alignment: .leading, spacing: 12) {
                Text(locationName)
                    .font(.headline)

                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: symbolName(for: period.shortForecast ?? period.name, isDaytime: period.isDaytime))
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 52)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatTemperature(period.temperature, sourceUnit: period.temperatureUnit, targetUnit: temperatureUnit))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .lineLimit(1)

                        Text(period.shortForecast ?? period.name)
                            .font(.title3.weight(.semibold))
                    }
                }

                if let detailedForecast = period.detailedForecast, !detailedForecast.isEmpty {
                    Text(detailedForecast)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 14) {
                    MetricPill(label: "Wind", value: "\(period.windSpeed ?? "--") \(period.windDirection ?? "")")

                    if let precip = period.probabilityOfPrecipitation?.value {
                        MetricPill(label: "Rain", value: "\(Int(precip))%")
                    }
                }
            }
            .foregroundStyle(visuals.textColor)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(visuals.cardColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct ForecastCard: View {
    let periods: [NWSForecastPeriod]
    let temperatureUnit: TemperatureUnit
    let visuals: WeatherVisuals
    let nwsURL: URL?

    private var dayPeriod: NWSForecastPeriod? {
        periods.first(where: \.isDaytime) ?? periods.first
    }

    private var nightPeriod: NWSForecastPeriod? {
        periods.first { !$0.isDaytime } ?? periods.last
    }

    var body: some View {
        if let dayPeriod {
            Link(destination: nwsURL ?? URL(string: "https://weather.gov")!) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(dayPeriod.name.replacingOccurrences(of: " Night", with: ""))
                            .font(.headline)

                        Spacer()

                        Label(formatTemperature(dayPeriod.temperature, sourceUnit: dayPeriod.temperatureUnit, targetUnit: temperatureUnit), systemImage: "sun.max")
                            .labelStyle(.titleAndIcon)

                        if let nightPeriod, nightPeriod.number != dayPeriod.number {
                            Label(formatTemperature(nightPeriod.temperature, sourceUnit: nightPeriod.temperatureUnit, targetUnit: temperatureUnit), systemImage: "moon")
                                .labelStyle(.titleAndIcon)
                                .foregroundStyle(visuals.textColor.opacity(0.66))
                        }
                    }

                    HStack(spacing: 10) {
                        Image(systemName: symbolName(for: dayPeriod.shortForecast ?? "", isDaytime: dayPeriod.isDaytime))
                            .font(.title3)
                            .foregroundStyle(.blue)

                        Text(dayPeriod.shortForecast ?? "Forecast unavailable")
                            .font(.body)
                    }

                    if let nightPeriod, nightPeriod.number != dayPeriod.number {
                        Text("Evening: \(nightPeriod.shortForecast ?? "")")
                            .font(.subheadline)
                            .foregroundStyle(visuals.textColor.opacity(0.72))
                    }
                }
                .foregroundStyle(visuals.textColor)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(visuals.cardColor.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

struct SavedLocationChips: View {
    let locations: [SavedLocation]
    let textColor: Color
    let onSelect: (SavedLocation) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(locations) { location in
                    Button {
                        onSelect(location)
                    } label: {
                        Label(location.label, systemImage: "mappin.and.ellipse")
                            .lineLimit(1)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white.opacity(0.25))
                    .foregroundStyle(textColor)
                }
            }
        }
    }
}

struct AlertBanner: View {
    let result: ForecastLoadResult

    var body: some View {
        Link(destination: nwsURL(latitude: result.latitude, longitude: result.longitude)) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)

                Text("Hazardous weather conditions reported")
                    .font(.subheadline.weight(.bold))

                Spacer()
            }
            .padding(12)
            .foregroundStyle(.primary)
            .background(Color.red.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct MetricPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
    }
}

func groupedForecastPeriods(_ periods: [NWSForecastPeriod]) -> [[NWSForecastPeriod]] {
    var groups: [[NWSForecastPeriod]] = []
    var indexByName: [String: Int] = [:]

    for period in periods {
        let key = period.name.replacingOccurrences(of: " Night", with: "")
        if let index = indexByName[key] {
            groups[index].append(period)
        } else {
            indexByName[key] = groups.count
            groups.append([period])
        }
    }

    return groups
}

func nwsURL(latitude: Double, longitude: Double) -> URL {
    URL(string: "https://forecast.weather.gov/MapClick.php?lat=\(latitude)&lon=\(longitude)")!
}

func symbolName(for forecast: String, isDaytime: Bool) -> String {
    let text = forecast.lowercased()

    if text.contains("storm") || text.contains("thunder") {
        return "cloud.bolt.rain.fill"
    }

    if text.contains("snow") || text.contains("flurr") || text.contains("sleet") {
        return "snowflake"
    }

    if text.contains("rain") || text.contains("shower") || text.contains("drizzle") {
        return "cloud.rain.fill"
    }

    if text.contains("cloud") || text.contains("overcast") {
        return isDaytime ? "cloud.sun.fill" : "cloud.moon.fill"
    }

    return isDaytime ? "sun.max.fill" : "moon.stars.fill"
}

func formatTemperature(_ value: Int, sourceUnit: String, targetUnit: TemperatureUnit) -> String {
    let isCelsiusSource = sourceUnit.caseInsensitiveCompare("C") == .orderedSame

    switch targetUnit {
    case .fahrenheit:
        if isCelsiusSource {
            let converted = (Double(value) * 9 / 5) + 32
            return "\(Int(converted.rounded()))°F"
        }
        return "\(value)°F"
    case .celsius:
        if !isCelsiusSource {
            let converted = (Double(value) - 32) * 5 / 9
            return "\(Int(converted.rounded()))°C"
        }
        return "\(value)°C"
    }
}
