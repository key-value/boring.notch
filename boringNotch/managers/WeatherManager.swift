//
//  WeatherManager.swift
//  boringNotch
//
//  Created by Codex on 2026-03-02.
//

import CoreLocation
import Foundation

enum WeatherStatus: Equatable {
    case idle
    case requestingLocation
    case loading
    case ready
    case denied
    case error(String)
}

struct WeatherCurrent: Equatable {
    let temperature: Double
    let apparentTemperature: Double?
    let weatherCode: Int
    let isDay: Bool
    let windSpeed: Double?
    let humidity: Double?
}

struct HourlyForecast: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let temperature: Double
    let weatherCode: Int
}

struct WeatherCondition: Equatable {
    let title: String
    let systemImage: String
}

@MainActor
final class WeatherManager: NSObject, ObservableObject {
    static let shared = WeatherManager()

    @Published var status: WeatherStatus = .idle
    @Published var locationName: String = "Current Location"
    @Published var current: WeatherCurrent?
    @Published var hourly: [HourlyForecast] = []
    @Published var dailyHigh: Double?
    @Published var dailyLow: Double?
    @Published var lastUpdated: Date?

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var fetchTask: Task<Void, Never>?
    private let isMetric = Locale.current.usesMetricSystem

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = 1000
    }

    func start() {
        handleAuthorizationChange()
    }

    func refresh() {
        requestLocation()
    }

    var windUnit: String {
        isMetric ? "km/h" : "mph"
    }

    var temperatureUnitParameter: String {
        isMetric ? "celsius" : "fahrenheit"
    }

    var windspeedUnitParameter: String {
        isMetric ? "kmh" : "mph"
    }

    static func condition(for code: Int, isDay: Bool) -> WeatherCondition {
        switch code {
        case 0:
            return WeatherCondition(
                title: "Clear",
                systemImage: isDay ? "sun.max.fill" : "moon.stars.fill"
            )
        case 1, 2:
            return WeatherCondition(
                title: "Partly cloudy",
                systemImage: isDay ? "cloud.sun.fill" : "cloud.moon.fill"
            )
        case 3:
            return WeatherCondition(title: "Cloudy", systemImage: "cloud.fill")
        case 45, 48:
            return WeatherCondition(title: "Fog", systemImage: "cloud.fog.fill")
        case 51, 53, 55, 56, 57:
            return WeatherCondition(title: "Drizzle", systemImage: "cloud.drizzle.fill")
        case 61, 63, 65:
            return WeatherCondition(title: "Rain", systemImage: "cloud.rain.fill")
        case 66, 67:
            return WeatherCondition(title: "Freezing rain", systemImage: "cloud.sleet.fill")
        case 71, 73, 75, 77:
            return WeatherCondition(title: "Snow", systemImage: "cloud.snow.fill")
        case 80, 81, 82:
            return WeatherCondition(title: "Showers", systemImage: "cloud.heavyrain.fill")
        case 85, 86:
            return WeatherCondition(title: "Snow showers", systemImage: "cloud.snow.fill")
        case 95:
            return WeatherCondition(title: "Thunderstorm", systemImage: "cloud.bolt.rain.fill")
        case 96, 99:
            return WeatherCondition(title: "Thunderstorm", systemImage: "cloud.bolt.fill")
        default:
            return WeatherCondition(title: "Unknown", systemImage: "questionmark")
        }
    }

    private func handleAuthorizationChange() {
        guard CLLocationManager.locationServicesEnabled() else {
            status = .denied
            return
        }
        switch authorizationStatus() {
        case .notDetermined:
            status = .requestingLocation
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            status = .denied
        case .authorizedAlways, .authorizedWhenInUse:
            if let cached = locationManager.location {
                updateLocationName(for: cached)
                fetchWeather(for: cached.coordinate)
            } else {
                requestLocation()
            }
        @unknown default:
            status = .denied
        }
    }

    private func authorizationStatus() -> CLAuthorizationStatus {
        if #available(macOS 14.0, *) {
            return locationManager.authorizationStatus
        }
        return CLLocationManager.authorizationStatus()
    }

    private func requestLocation() {
        status = .requestingLocation
        locationManager.requestLocation()
    }

    private func updateLocationName(for location: CLLocation) {
        Task {
            let placemarks = try? await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks?.first {
                let name = [placemark.locality, placemark.administrativeArea]
                    .compactMap { $0 }
                    .joined(separator: " ")
                if !name.isEmpty {
                    locationName = name
                }
            }
        }
    }

    private func fetchWeather(for coordinate: CLLocationCoordinate2D) {
        fetchTask?.cancel()
        fetchTask = Task {
            status = .loading
            do {
                let response = try await requestForecast(for: coordinate)
                apply(response: response)
                lastUpdated = Date()
                status = .ready
            } catch {
                status = .error("Unable to load weather")
            }
        }
    }

    private func requestForecast(for coordinate: CLLocationCoordinate2D) async throws -> OpenMeteoResponse {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", coordinate.longitude)),
            URLQueryItem(
                name: "current",
                value: "temperature_2m,apparent_temperature,weather_code,is_day,relative_humidity_2m,wind_speed_10m"
            ),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "forecast_days", value: "1"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "temperature_unit", value: temperatureUnitParameter),
            URLQueryItem(name: "windspeed_unit", value: windspeedUnitParameter)
        ]
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
    }

    private func apply(response: OpenMeteoResponse) {
        if let currentData = response.current {
            let isDay = (currentData.is_day ?? 1) == 1
            current = WeatherCurrent(
                temperature: currentData.temperature_2m,
                apparentTemperature: currentData.apparent_temperature,
                weatherCode: currentData.weather_code,
                isDay: isDay,
                windSpeed: currentData.wind_speed_10m,
                humidity: currentData.relative_humidity_2m
            )
        }

        if let daily = response.daily {
            dailyHigh = daily.temperature_2m_max.first
            dailyLow = daily.temperature_2m_min.first
        }

        hourly = buildHourlyForecast(from: response)
    }

    private func buildHourlyForecast(from response: OpenMeteoResponse) -> [HourlyForecast] {
        guard let hourlyData = response.hourly else { return [] }
        let count = min(hourlyData.time.count, hourlyData.temperature_2m.count, hourlyData.weather_code.count)
        let timeZone = TimeZone(identifier: response.timezone ?? "") ?? .current
        let now = Date()
        var results: [HourlyForecast] = []

        for idx in 0..<count {
            guard let date = parseHourlyDate(hourlyData.time[idx], timeZone: timeZone) else { continue }
            if date < now { continue }
            results.append(
                HourlyForecast(
                    date: date,
                    temperature: hourlyData.temperature_2m[idx],
                    weatherCode: hourlyData.weather_code[idx]
                )
            )
            if results.count >= 4 {
                break
            }
        }
        return results
    }

    private func parseHourlyDate(_ value: String, timeZone: TimeZone) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        return formatter.date(from: value)
    }
}

extension WeatherManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        handleAuthorizationChange()
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        handleAuthorizationChange()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        updateLocationName(for: location)
        fetchWeather(for: location.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if case .denied = status {
            return
        }
        status = .error("Location unavailable")
    }
}

private struct OpenMeteoResponse: Decodable {
    struct Current: Decodable {
        let time: String
        let temperature_2m: Double
        let apparent_temperature: Double?
        let weather_code: Int
        let is_day: Int?
        let relative_humidity_2m: Double?
        let wind_speed_10m: Double?
    }

    struct Hourly: Decodable {
        let time: [String]
        let temperature_2m: [Double]
        let weather_code: [Int]
    }

    struct Daily: Decodable {
        let time: [String]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
    }

    let timezone: String?
    let current: Current?
    let hourly: Hourly?
    let daily: Daily?
}
