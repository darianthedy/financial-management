import CoreGraphics
import SwiftUI

/// How the Transactions Summary (F3) is presented (iPhone Duo plan D3.2).
///
/// A trailing `.inspector` column needs room beside the list | detail split:
/// the inner display in landscape (951 pt) fits list 300 + detail + inspector
/// 300, but portrait (669 pt) would squeeze the detail to nothing. There, on
/// compact width, and in drill-down embeddings it stays the sheet it is today.
enum SummaryPresentation: Equatable {
    case inspector
    case sheet

    /// The inspector column's width range (pt).
    static let inspectorWidth: (min: CGFloat, ideal: CGFloat, max: CGFloat) = (280, 300, 360)

    /// The narrowest screen that tiles list | detail | inspector: the list's
    /// 300 pt minimum, a 300 pt detail and the ideal inspector.
    static let minimumInspectorScreenWidth: CGFloat = 900

    static func style(isTabRoot: Bool, sizeClass: UserInterfaceSizeClass?, width: CGFloat) -> SummaryPresentation {
        guard isTabRoot, sizeClass == .regular, width >= minimumInspectorScreenWidth else { return .sheet }
        return .inspector
    }
}
