//
//  WeatherAttributionView.swift
//  Aquack
//

import SwiftUI
import WeatherKit

/// Required WeatherKit attribution: Apple Weather trademark and legal data-sources link.
struct WeatherAttributionView: View {
    @ObservedObject private var weather = WeatherManager.shared

    private static let fallbackLegalURL = URL(string: "https://developer.apple.com/weatherkit/data-source-attribution/")!

    var body: some View {
        HStack(spacing: 8) {
            markBadge

            Link(destination: weather.attribution?.legalPageURL ?? Self.fallbackLegalURL) {
                Text("Weather Data Sources")
                    .font(.caption2)
                    .foregroundStyle(HydrationTheme.label)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            await weather.loadAttributionIfNeeded()
        }
    }

    @ViewBuilder
    private var markBadge: some View {
        Group {
            if let url = weather.displayMarkURL() {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(height: 10)
                    case .failure:
                        markFallback
                    default:
                        markFallback
                    }
                }
            } else {
                markFallback
            }
        }
        .frame(width: 64, height: 22)
        .background(
            HydrationTheme.accentSoft.opacity(0.35),
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
    }

    private var markFallback: some View {
        HStack(spacing: 2) {
            Image(systemName: "apple.logo")
                .font(.system(size: 8, weight: .medium))
            Text("Weather")
                .font(.system(size: 8, weight: .medium))
        }
        .foregroundStyle(HydrationTheme.title.opacity(0.7))
    }
}
