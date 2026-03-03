//
//  WeatherView.swift
//  boringNotch
//
//  Created by Codex on 2026-03-02.
//

import SwiftUI

struct WeatherView: View {
    @ObservedObject private var weather = WeatherManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            weather.start()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(weather.locationName)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer(minLength: 0)
            Button(action: {
                weather.refresh()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    @ViewBuilder
    private var content: some View {
        switch weather.status {
        case .idle, .requestingLocation, .loading:
            LoadingStateView(text: weather.status == .requestingLocation ? "Requesting location..." : "Loading weather...")
        case .denied:
            ErrorStateView(
                title: "Location access denied",
                message: "Enable location in System Settings to show weather.",
                actionTitle: "Retry",
                action: { weather.start() }
            )
        case .error(let message):
            ErrorStateView(
                title: "Weather unavailable",
                message: message,
                actionTitle: "Retry",
                action: { weather.refresh() }
            )
        case .ready:
            if let current = weather.current {
                ReadyStateView(
                    current: current,
                    high: weather.dailyHigh,
                    low: weather.dailyLow,
                    hourly: weather.hourly,
                    windUnit: weather.windUnit
                )
            } else {
                LoadingStateView(text: "Loading weather...")
            }
        }
    }

    private var headerSubtitle: String {
        switch weather.status {
        case .ready:
            if let current = weather.current {
                return WeatherManager.condition(for: current.weatherCode, isDay: current.isDay).title
            }
            return "Weather"
        case .denied:
            return "Location disabled"
        case .error:
            return "Weather unavailable"
        case .requestingLocation:
            return "Requesting location..."
        case .loading:
            return "Loading weather..."
        case .idle:
            return "Weather"
        }
    }
}

private struct LoadingStateView: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.7)
                .tint(.gray)
            Text(text)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}

private struct ErrorStateView: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)
            Text(message)
                .font(.caption)
                .foregroundColor(.gray)
            Button(actionTitle, action: action)
                .buttonStyle(PlainButtonStyle())
                .font(.caption)
                .foregroundColor(Color.effectiveAccent)
        }
        .padding(.vertical, 4)
    }
}

private struct ReadyStateView: View {
    let current: WeatherCurrent
    let high: Double?
    let low: Double?
    let hourly: [HourlyForecast]
    let windUnit: String

    private var condition: WeatherCondition {
        WeatherManager.condition(for: current.weatherCode, isDay: current.isDay)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Image(systemName: condition.systemImage)
                        .font(.title2)
                        .foregroundColor(.white)
                    Text(tempString(current.temperature))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                    if let feels = current.apparentTemperature {
                        Text("Feels like \(tempString(feels))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 4) {
                    if let high = high, let low = low {
                        Text("H \(tempString(high))  L \(tempString(low))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    if let wind = current.windSpeed {
                        Text("Wind \(String(format: "%.0f", wind)) \(windUnit)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    if let humidity = current.humidity {
                        Text("Humidity \(String(format: "%.0f", humidity))%")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }

            if !hourly.isEmpty {
                HStack(spacing: 8) {
                    ForEach(hourly) { item in
                        HourlyCell(forecast: item)
                    }
                }
            }
        }
    }

    private func tempString(_ value: Double) -> String {
        "\(Int(round(value)))°"
    }
}

private struct HourlyCell: View {
    let forecast: HourlyForecast

    private var condition: WeatherCondition {
        WeatherManager.condition(for: forecast.weatherCode, isDay: true)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(forecast.date.formatted(.dateTime.hour().locale(Locale.current)))
                .font(.caption2)
                .foregroundColor(.gray)
            Image(systemName: condition.systemImage)
                .font(.caption)
                .foregroundColor(.white)
            Text("\(Int(round(forecast.temperature)))°")
                .font(.caption2)
                .foregroundColor(.white)
        }
        .frame(minWidth: 34)
    }
}

#Preview {
    WeatherView()
        .frame(width: 320, height: 150)
        .background(.black)
        .environmentObject(BoringViewModel())
}
