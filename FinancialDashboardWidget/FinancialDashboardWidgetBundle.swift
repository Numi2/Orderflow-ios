import WidgetKit
import SwiftUI

@main
struct FinancialDashboardWidgetBundle: WidgetBundle {
    var body: some Widget {
        FinancialDashboardWidget()
        if #available(iOS 16.1, *) {
            FinancialDashboardLiveActivity()
        }
    }
} 