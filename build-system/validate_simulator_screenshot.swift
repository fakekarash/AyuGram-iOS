import AppKit
import Darwin
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: validate_simulator_screenshot.swift <screenshot.png>\n", stderr)
    exit(2)
}

let screenshotPath = CommandLine.arguments[1]
guard let image = NSImage(contentsOfFile: screenshotPath),
      let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff) else {
    fputs("::error::Unable to decode simulator screenshot\n", stderr)
    exit(2)
}

let width = bitmap.pixelsWide
let height = bitmap.pixelsHigh
guard width > 0 && height > 0 else {
    fputs("::error::Simulator screenshot has invalid dimensions\n", stderr)
    exit(2)
}

let xStart = width / 20
let xEnd = width - xStart
let yStart = height / 8
let yEnd = height - yStart
let stride = max(2, min(width, height) / 250)

var buckets = Set<Int>()
var minimumLuminance = 1.0
var maximumLuminance = 0.0
var samples = 0

for y in Swift.stride(from: yStart, to: yEnd, by: stride) {
    for x in Swift.stride(from: xStart, to: xEnd, by: stride) {
        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
            continue
        }
        let red = Double(color.redComponent)
        let green = Double(color.greenComponent)
        let blue = Double(color.blueComponent)
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        minimumLuminance = min(minimumLuminance, luminance)
        maximumLuminance = max(maximumLuminance, luminance)
        let bucket = (Int(red * 15.0) << 8) | (Int(green * 15.0) << 4) | Int(blue * 15.0)
        buckets.insert(bucket)
        samples += 1
    }
}

let luminanceRange = maximumLuminance - minimumLuminance
print("Screenshot samples=\(samples) colorBuckets=\(buckets.count) luminanceRange=\(String(format: "%.3f", luminanceRange))")

if samples == 0 || buckets.count < 6 || luminanceRange < 0.12 {
    fputs("::error::Simulator screenshot is blank or lacks rendered application UI\n", stderr)
    exit(1)
}
