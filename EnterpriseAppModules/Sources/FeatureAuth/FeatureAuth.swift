import SwiftUI

/// `FeatureAuth` provides enterprise-ready login & registration UI wired to the Vapor `/api/auth/*` endpoints.
///
/// Entry points:
/// - `AuthFlowView`: standalone login/register flow.
/// - `AuthGateView`: swaps between auth flow and authenticated content based on session state.
public enum FeatureAuth {}

