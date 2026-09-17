import SwiftUI

// SDK 27 also exports a State macro. Command Line Tools currently omit its
// SwiftUIMacros plugin. This alias selects the system property-wrapper type
// unambiguously; it adds no storage, observation, rendering, or custom control.
typealias ViewState<Value> = SwiftUI.State<Value>
