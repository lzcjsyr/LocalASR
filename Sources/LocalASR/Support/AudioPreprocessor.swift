import Foundation

enum AudioPreprocessor {
    static func trimSilence(_ samples: [Float], sampleRate: Int = 16_000) -> [Float]? {
        guard !samples.isEmpty, sampleRate > 0 else { return nil }

        let frameLength = max(1, sampleRate / 50)
        let hopLength = max(1, sampleRate / 100)
        var windows = [(start: Int, end: Int, rms: Double, peak: Double)]()

        for start in stride(from: 0, to: samples.count, by: hopLength) {
            let end = min(samples.count, start + frameLength)
            guard end > start else { continue }

            var sumOfSquares = 0.0
            var peak = 0.0
            for sample in samples[start..<end] {
                let magnitude = abs(Double(sample))
                sumOfSquares += magnitude * magnitude
                peak = max(peak, magnitude)
            }

            let rms = sqrt(sumOfSquares / Double(end - start))
            windows.append((start: start, end: end, rms: rms, peak: peak))
        }

        guard !windows.isEmpty else { return nil }

        let sortedRMS = windows.map(\.rms).sorted()
        let noiseIndex = min(sortedRMS.count - 1, sortedRMS.count / 5)
        let noiseFloor = sortedRMS[noiseIndex]
        let maximumRMS = sortedRMS.last ?? 0
        let rmsThreshold = max(0.008, min(noiseFloor * 2.5, maximumRMS * 0.6))
        let peakThreshold = max(0.018, rmsThreshold * 1.4)

        let activeWindows = windows.filter { window in
            window.rms >= rmsThreshold && window.peak >= peakThreshold
        }
        guard let firstActive = activeWindows.first, let lastActive = activeWindows.last else {
            return nil
        }

        let padding = sampleRate * 35 / 100
        let start = max(0, firstActive.start - padding)
        let end = min(samples.count, lastActive.end + padding)
        guard end > start else { return nil }
        return Array(samples[start..<end])
    }
}
