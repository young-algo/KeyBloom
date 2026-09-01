import SwiftUI

enum PerceptualColor {
    static func bloom(
        hue: Double,
        lightness: Double = 0.80,
        chroma: Double = 0.18,
        opacity: Double = 1
    ) -> Color {
        let degrees = wrappedHue(hue) * 360
        var fittedChroma = chroma
        var rgb = linearSRGB(lightness: lightness, chroma: fittedChroma, hueDegrees: degrees)

        while fittedChroma > 0.02, !inGamut(rgb) {
            fittedChroma -= 0.01
            rgb = linearSRGB(lightness: lightness, chroma: fittedChroma, hueDegrees: degrees)
        }

        return Color(
            .sRGBLinear,
            red: clamp(rgb.r),
            green: clamp(rgb.g),
            blue: clamp(rgb.b),
            opacity: opacity
        )
    }

    private static func linearSRGB(
        lightness: Double,
        chroma: Double,
        hueDegrees: Double
    ) -> (r: Double, g: Double, b: Double) {
        let h = hueDegrees * .pi / 180
        let a = chroma * cos(h)
        let b = chroma * sin(h)
        let lPrime = lightness + 0.3963377774 * a + 0.2158037573 * b
        let mPrime = lightness - 0.1055613458 * a - 0.0638541728 * b
        let sPrime = lightness - 0.0894841775 * a - 1.2914855480 * b
        let l = lPrime * lPrime * lPrime
        let m = mPrime * mPrime * mPrime
        let s = sPrime * sPrime * sPrime

        return (
            4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.0041960863 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        )
    }

    private static func inGamut(_ rgb: (r: Double, g: Double, b: Double)) -> Bool {
        let range = -0.001...1.001
        return range.contains(rgb.r) && range.contains(rgb.g) && range.contains(rgb.b)
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    static func wrappedHue(_ hue: Double) -> Double {
        let value = hue.truncatingRemainder(dividingBy: 1)
        return value < 0 ? value + 1 : value
    }
}
