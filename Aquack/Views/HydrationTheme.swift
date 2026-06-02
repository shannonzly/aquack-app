//
//  HydrationTheme.swift
//  Overall theme: glass panels, blue and white, bubbles
//  Aquack
//

import SwiftUI
import UIKit

enum HydrationTheme {
    static let accent = Color(red: 0.29, green: 0.56, blue: 0.92)
    static let accentSoft = Color(red: 0.62, green: 0.80, blue: 0.97)
    static let skyTop = Color(red: 0.88, green: 0.94, blue: 0.99)
    static let skyMid = Color(red: 0.95, green: 0.97, blue: 1.0)
    static let skyBottom = Color(red: 0.86, green: 0.93, blue: 0.99)
    static let glassFill = Color.white.opacity(0.42)
    static let glassStroke = Color.white.opacity(0.65)
    static let fieldFill = Color.white.opacity(0.55)
    static let label = Color(red: 0.49, green: 0.55, blue: 0.60)
    static let title = Color(red: 0.10, green: 0.12, blue: 0.16)
    static let waterShallow = Color(red: 0.55, green: 0.82, blue: 0.95)
    static let waterDeep = Color(red: 0.28, green: 0.62, blue: 0.86)
    static let iconGrayTop = Color(red: 0.62, green: 0.68, blue: 0.74)
    static let iconGrayBottom = Color(red: 0.48, green: 0.54, blue: 0.60)
}

enum HomeLayout {
    static let horizontalPadding: CGFloat = 28
    static let heroTopInset: CGFloat = 10
    static let sectionSpacing: CGFloat = 24
    static let cardSpacing: CGFloat = 14
    /// Small breathing room above the floating tab bar inset.
    static let floatingTabBarInset: CGFloat = 12
    static let heroProgressRingSize: CGFloat = 152
    static let heroProgressRingStroke: CGFloat = 14
    static let heroCardCornerRadius: CGFloat = 24
    static let heroGoalCardMaxWidth: CGFloat = 232
    static let heroButtonMaxWidth: CGFloat = 210

    /// One full screen of scroll content before the stats section.
    static func heroViewportHeight(in totalHeight: CGFloat) -> CGFloat {
        totalHeight
    }
}

// MARK: - Typography

enum HydrationTypography {
    /// Screen and card titles — 17 pt bold
    static let pageTitle = Font.headline.weight(.bold)
    /// Primary readable text — toggles, buttons, paragraphs — 15 pt
    static let body = Font.subheadline
    /// Emphasized body — row values, tips — 15 pt semibold
    static let bodyEmphasis = Font.subheadline.weight(.semibold)
    /// Secondary text — subtitles, hints, units — 13 pt
    static let footnote = Font.footnote
    /// Section labels, field labels — 13 pt semibold
    static let footnoteEmphasis = Font.footnote.weight(.semibold)
    /// Hero ring percentage — large blue numeral.
    static let heroPercent = Font.system(size: 34, weight: .bold, design: .rounded)
    /// Large numbers — profile hero, etc.
    static let metricLarge = Font.system(.title2, design: .rounded).weight(.bold)
    /// Medium numbers — stat tiles, goal card — 20 pt bold rounded
    static let metricMedium = Font.system(.title3, design: .rounded).weight(.bold)
}

extension View {
    func hydrationBodyText() -> some View {
        font(HydrationTypography.body)
            .foregroundStyle(HydrationTheme.title)
    }

    func hydrationFootnote() -> some View {
        font(HydrationTypography.footnote)
            .foregroundStyle(HydrationTheme.label)
    }

    func hydrationFormCard() -> some View {
        font(HydrationTypography.body)
            .foregroundStyle(HydrationTheme.title)
    }
}

struct HomeScrollDepth: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Background

struct FlatBubble: View {
    var diameter: CGFloat
    var opacity: Double
    var color: Color

    var body: some View {
        Circle()
            .fill(color.opacity(opacity))
            .frame(width: diameter, height: diameter)
    }
}

struct DriftingFlatBubble: View {
    var diameter: CGFloat
    var opacity: Double
    var color: Color
    var baseOffset: CGSize
    var driftPhase: Double
    var driftScale: CGFloat = 1

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let driftX = sin(elapsed * 0.42 + driftPhase) * 10 * driftScale
            let driftY = cos(elapsed * 0.36 + driftPhase * 1.25) * 14 * driftScale

            FlatBubble(diameter: diameter, opacity: opacity, color: color)
                .offset(
                    x: baseOffset.width + driftX,
                    y: baseOffset.height + driftY
                )
        }
    }
}

struct FloatingBubble: View {
    var diameter: CGFloat
    var opacity: Double
    var offset: CGSize
    var tint: Color? = nil

    var body: some View {
        FlatBubble(
            diameter: diameter,
            opacity: opacity,
            color: tint ?? .white
        )
        .offset(offset)
    }
}

/// Shared sky gradient used across the home scroll surface.
private struct HomeSkyGradient: View {
    var body: some View {
        LinearGradient(
            colors: [
                HydrationTheme.skyTop,
                HydrationTheme.skyMid,
                HydrationTheme.skyMid,
                HydrationTheme.skyBottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct HomeBackgroundBubbles: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = max(geo.size.height, 1)

            ZStack {
                DriftingFlatBubble(
                    diameter: 360,
                    opacity: 0.16,
                    color: HydrationTheme.accentSoft,
                    baseOffset: CGSize(width: -w * 0.38, height: h * 0.06),
                    driftPhase: 0.4,
                    driftScale: 1.1
                )
                DriftingFlatBubble(
                    diameter: 300,
                    opacity: 0.13,
                    color: HydrationTheme.waterShallow,
                    baseOffset: CGSize(width: w * 0.34, height: h * 0.42),
                    driftPhase: 2.0,
                    driftScale: 1.0
                )
                DriftingFlatBubble(
                    diameter: 420,
                    opacity: 0.11,
                    color: HydrationTheme.accentSoft,
                    baseOffset: CGSize(width: -w * 0.12, height: h * 0.78),
                    driftPhase: 3.8,
                    driftScale: 0.9
                )
            }
        }
        .allowsHitTesting(false)
    }
}

struct HomeScrollBackground: View {
    var body: some View {
        ZStack {
            HomeSkyGradient()
            HomeBackgroundBubbles()
        }
        .ignoresSafeArea()
    }
}

struct AmbientPageBackground: View {
    var bubbleIntensity: Double = 1.0

    var body: some View {
        ZStack {
            HomeSkyGradient()

            FloatingBubble(
                diameter: 340,
                opacity: 0.18 * bubbleIntensity,
                offset: CGSize(width: -120, height: -180),
                tint: HydrationTheme.accentSoft
            )
            FloatingBubble(
                diameter: 280,
                opacity: 0.14 * bubbleIntensity,
                offset: CGSize(width: 140, height: 80),
                tint: HydrationTheme.waterShallow
            )
            FloatingBubble(
                diameter: 400,
                opacity: 0.11 * bubbleIntensity,
                offset: CGSize(width: -40, height: 360),
                tint: HydrationTheme.accentSoft
            )
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

struct RisingWaterFill: View {
    var progress: Double

    var body: some View {
        GeometryReader { geo in
            let clamped = min(max(progress, 0), 1)
            let waterHeight = max(geo.size.height * clamped, clamped > 0.002 ? 8 : 0)

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                ZStack(alignment: .top) {
                    LinearGradient(
                        colors: [
                            HydrationTheme.waterShallow.opacity(0.92),
                            HydrationTheme.waterDeep.opacity(0.95)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: waterHeight)

                    WaterSurfaceWave()
                        .fill(HydrationTheme.waterShallow.opacity(0.85))
                        .frame(height: 12)
                        .offset(y: -5)
                }
                .frame(height: waterHeight, alignment: .bottom)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
    }
}

private struct WaterSurfaceWave: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: 0, y: h * 0.55))
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.35),
            control1: CGPoint(x: w * 0.18, y: h * 0.15),
            control2: CGPoint(x: w * 0.32, y: h * 0.65)
        )
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.5),
            control1: CGPoint(x: w * 0.68, y: h * 0.05),
            control2: CGPoint(x: w * 0.82, y: h * 0.7)
        )
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()
        return path
    }
}

// MARK: - Home hero chrome

struct HomeStatsTipsButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                Text("Stats & tips")
                    .font(HydrationTypography.bodyEmphasis)
            }
            .foregroundStyle(HydrationTheme.accent)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .glassSurface(cornerRadius: 22)
        }
        .buttonStyle(.plain)
    }
}

struct HydrationPageShell<Content: View>: View {
    var interactive: Bool = false
    var bubbleIntensity: Double = 0.85
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            AmbientPageBackground(bubbleIntensity: bubbleIntensity)
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .if(!interactive) { view in
            view.ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }
}

// MARK: - Icons

struct GradientIconStyle: View {
    var systemName: String
    var size: CGFloat
    var active: Bool

    private var gradient: LinearGradient {
        if active {
            return LinearGradient(
                colors: [HydrationTheme.accent, HydrationTheme.waterDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [HydrationTheme.iconGrayTop, HydrationTheme.iconGrayBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(gradient)
    }
}

struct GradientIconBadge: View {
    var systemName: String
    var colors: [Color]
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Circle()
            )
    }
}

// MARK: - Brand & headers

struct AquackCharacterImage: View {
    var size: CGFloat = 72

    var body: some View {
        Image("Character")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("Aquack character")
    }
}

struct AquackBrandHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)
            AquackCharacterImage(size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Aquack")
                    .font(HydrationTypography.pageTitle)
                    .foregroundStyle(HydrationTheme.title)
                Text("sip by sip")
                    .font(HydrationTypography.footnote)
                    .foregroundStyle(HydrationTheme.label)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .glassSurface(cornerRadius: HomeLayout.heroCardCornerRadius)
    }
}

struct PageHeroHeader: View {
    var title: String
    var subtitle: String
    var systemImage: String? = nil
    var useCharacter: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            if useCharacter {
                AquackCharacterImage(size: 44)
            } else if let systemImage {
                GradientIconBadge(
                    systemName: systemImage,
                    colors: [HydrationTheme.accent, HydrationTheme.waterDeep],
                    size: 40
                )
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HydrationTypography.pageTitle)
                    .foregroundStyle(HydrationTheme.title)
                Text(subtitle)
                    .font(HydrationTypography.footnote)
                    .foregroundStyle(HydrationTheme.label)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, HomeLayout.cardSpacing + 4)
        .padding(.vertical, HomeLayout.cardSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(cornerRadius: 22)
    }
}

struct CapsuleSectionHeader: View {
    var title: String
    var systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            GradientIconStyle(systemName: systemImage, size: 12, active: true)
            Text(title.uppercased())
                .font(HydrationTypography.footnoteEmphasis)
                .tracking(0.4)
                .foregroundStyle(HydrationTheme.accent)
            Rectangle()
                .fill(HydrationTheme.accentSoft.opacity(0.7))
                .frame(height: 1)
        }
        .padding(.top, 4)
    }
}

struct ThemedSectionHeader: View {
    var title: String
    var systemImage: String

    var body: some View {
        CapsuleSectionHeader(title: title, systemImage: systemImage)
    }
}

// MARK: - Glass components

struct GlassCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HomeLayout.cardSpacing) { content }
            .padding(HomeLayout.cardSpacing + 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(cornerRadius: 20)
            .hydrationFormCard()
    }
}

struct GlassInsetField: View {
    var label: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .decimalPad

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(HydrationTypography.footnoteEmphasis)
                .foregroundStyle(HydrationTheme.label)
            TextField(label, text: $text)
                .textFieldStyle(.plain)
                .keyboardType(keyboard)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(HydrationTheme.fieldFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                )
                .foregroundStyle(HydrationTheme.title)
                .font(HydrationTypography.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProfileMenuPicker<Selection: Hashable, Content: View>: View {
    var title: String
    @Binding var selection: Selection
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(HydrationTypography.footnoteEmphasis)
                .foregroundStyle(HydrationTheme.label)
            Picker(title, selection: $selection, content: content)
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(HydrationTheme.fieldFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                )
                .tint(HydrationTheme.accent)
                .font(HydrationTypography.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Buttons

struct PrimaryWaterButton: View {
    var title: String
    var systemImage: String? = nil
    var disabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                }
                Text(title)
                    .font(HydrationTypography.bodyEmphasis)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(
            LinearGradient(
                colors: [HydrationTheme.accent, HydrationTheme.waterDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: Capsule()
        )
        .shadow(color: HydrationTheme.accent.opacity(0.28), radius: 8, y: 3)
        .opacity(disabled ? 0.5 : 1)
        .disabled(disabled)
    }
}

struct OutlineWaterButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                Text(title)
                    .font(HydrationTypography.bodyEmphasis)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .foregroundStyle(HydrationTheme.accent)
        .glassSurface(cornerRadius: 22)
    }
}

struct GlassChipButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(HydrationTypography.footnote)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(HydrationTheme.accent)
        .glassSurface(cornerRadius: 16)
    }
}

struct BackPillButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.semibold))
                Text("Back")
                    .font(HydrationTypography.footnoteEmphasis)
            }
            .foregroundStyle(HydrationTheme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .glassSurface(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Keyboard dismissal

private extension UIApplication {
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Scroll view that dismisses the keyboard when scrolling or tapping outside text fields.
struct KeyboardDismissingScrollView<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            content
                .frame(maxWidth: .infinity, alignment: .top)
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.dismissKeyboard()
                }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

struct GlassSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(HydrationTheme.glassFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        HydrationTheme.glassStroke,
                                        Color.white.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
            }
    }
}

extension View {
    func hydrationPageContent() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, HomeLayout.horizontalPadding)
            .padding(.top, HomeLayout.heroTopInset)
    }

    func hydrationSectionStack() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, HomeLayout.horizontalPadding)
            .padding(.top, HomeLayout.sectionSpacing)
            .padding(.bottom, HomeLayout.cardSpacing)
    }

    func glassSurface(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassSurfaceModifier(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    fileprivate func `if`<Transformed: View>(
        _ condition: Bool,
        transform: (Self) -> Transformed
    ) -> some View {
        if condition { transform(self) } else { self }
    }
}

extension UserInfo.ActivityLevel {
    var displayLabel: String {
        switch self {
        case .low: return "Light (1-3 times a week)"
        case .moderate: return "Moderate (3-5 times a week)"
        case .high: return "Active (6+ times a week)"
        }
    }
}
