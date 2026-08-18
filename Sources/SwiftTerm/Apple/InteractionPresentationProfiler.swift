#if os(macOS) || os(iOS) || os(visionOS)
import Foundation
#if canImport(os)
import os
#endif

struct InteractionPresentationFrame {
    let maximumToken: UInt64?
}

private struct ProfileInteraction {
    let token: UInt64
#if canImport(os)
    let handlerToMarker: OSSignpostID
    var markerToPresent: OSSignpostID?
#endif
}

/// Privacy-safe correlation for deterministic, opt-in profiling input.
/// Only opaque IDs and timings are emitted; key values, coordinates, terminal
/// bytes, and terminal contents are never retained or logged.
final class InteractionPresentationProfiler: @unchecked Sendable {
    private static let marker = Array("\u{1b}]9999;shepherd-profile\u{7}".utf8)
#if canImport(os)
    private static let log = OSLog(
        subsystem: "org.tirania.SwiftTerm",
        category: "InteractionProfile"
    )
#endif
    private let enabled: Bool
    private let lock = NSLock()
    private var nextToken: UInt64 = 0
#if canImport(os)
    private var awaitingHandler: [UInt64: OSSignpostID] = [:]
#endif
    private var awaitingMarker: [ProfileInteraction] = []
    private var awaitingPresentation: [ProfileInteraction] = []
    private var markerMatchLength = 0

    init(enabled: Bool? = nil) {
        self.enabled = enabled
            ?? (ProcessInfo.processInfo.environment["SWIFTTERM_PROFILE"] == "1")
    }

    func postedSyntheticKey() -> UInt64? {
        guard enabled else { return nil }
        lock.lock()
        defer { lock.unlock() }
        nextToken &+= 1
#if canImport(os)
        let id = OSSignpostID(log: Self.log)
        awaitingHandler[nextToken] = id
        os_signpost(.begin, log: Self.log, name: "SyntheticKey.PostToHandler", signpostID: id)
#endif
        return nextToken
    }

    func receivedSyntheticKey(_ token: UInt64) {
        guard enabled else { return }
        lock.lock()
        defer { lock.unlock() }
#if canImport(os)
        guard let postID = awaitingHandler.removeValue(forKey: token) else { return }
        os_signpost(.end, log: Self.log, name: "SyntheticKey.PostToHandler", signpostID: postID)
        let markerID = OSSignpostID(log: Self.log)
        os_signpost(.begin, log: Self.log, name: "SyntheticKey.HandlerToMarker", signpostID: markerID)
        awaitingMarker.append(ProfileInteraction(
            token: token,
            handlerToMarker: markerID,
            markerToPresent: nil
        ))
#endif
    }

    func observeOutput(_ bytes: ArraySlice<UInt8>) {
        guard enabled else { return }
        lock.lock()
        defer { lock.unlock() }
        for byte in bytes {
            if byte == Self.marker[markerMatchLength] {
                markerMatchLength += 1
                if markerMatchLength == Self.marker.count {
                    markerMatchLength = 0
                    markNextInteractionDamage()
                }
            } else {
                markerMatchLength = byte == Self.marker[0] ? 1 : 0
            }
        }
    }

    func captureFrame() -> InteractionPresentationFrame {
        guard enabled else { return InteractionPresentationFrame(maximumToken: nil) }
        lock.lock()
        defer { lock.unlock() }
        return InteractionPresentationFrame(maximumToken: awaitingPresentation.last?.token)
    }

    func presented(_ frame: InteractionPresentationFrame) {
        guard enabled, let maximumToken = frame.maximumToken else { return }
        lock.lock()
        defer { lock.unlock() }
        let count = awaitingPresentation.prefix { $0.token <= maximumToken }.count
        let completed = awaitingPresentation.prefix(count)
#if canImport(os)
        for interaction in completed {
            guard let id = interaction.markerToPresent else { continue }
            os_signpost(.end, log: Self.log, name: "SyntheticKey.MarkerToPresent", signpostID: id)
        }
#endif
        awaitingPresentation.removeFirst(count)
    }

    private func markNextInteractionDamage() {
        guard !awaitingMarker.isEmpty else { return }
        var interaction = awaitingMarker.removeFirst()
#if canImport(os)
        os_signpost(
            .end, log: Self.log, name: "SyntheticKey.HandlerToMarker",
            signpostID: interaction.handlerToMarker)
        let presentID = OSSignpostID(log: Self.log)
        os_signpost(
            .begin, log: Self.log, name: "SyntheticKey.MarkerToPresent",
            signpostID: presentID)
        interaction.markerToPresent = presentID
#endif
        awaitingPresentation.append(interaction)
    }
}
#endif
