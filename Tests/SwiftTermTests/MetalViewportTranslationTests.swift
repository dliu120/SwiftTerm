#if os(macOS) || os(iOS) || os(visionOS)
import Testing
@testable import SwiftTerm

struct MetalViewportTranslationTests {
    @Test func unchangedViewportHasNoTranslation() {
        #expect(metalRowTranslationY(builtRow: 14, currentRow: 14,
                                     builtYDisp: 12, currentYDisp: 12, rowStride: 36) == 0)
    }

    @Test func advancingViewportMovesCachedGeometryByItsRowDelta() {
        #expect(metalRowTranslationY(builtRow: 14, currentRow: 14,
                                     builtYDisp: 12, currentYDisp: 15, rowStride: 36) == 108)
    }

    @Test func retreatingViewportMovesCachedGeometryByItsRowDelta() {
        #expect(metalRowTranslationY(builtRow: 14, currentRow: 14,
                                     builtYDisp: 15, currentYDisp: 12, rowStride: 36) == -108)
    }

    @Test func translationPreservesFractionalScaledRowStride() {
        #expect(metalRowTranslationY(builtRow: 8, currentRow: 8,
                                     builtYDisp: 4, currentYDisp: 6, rowStride: 27.5) == 55)
    }

    @Test func lineRotationPreservesItsViewportPosition() {
        #expect(metalRowTranslationY(builtRow: 8, currentRow: 7,
                                     builtYDisp: 4, currentYDisp: 3, rowStride: 27.5) == 0)
    }
}
#endif
