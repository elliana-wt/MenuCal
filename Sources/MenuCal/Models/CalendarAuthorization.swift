enum CalendarAuthorization: Equatable {
    case notDetermined
    case fullAccess
    case denied
    case restricted
}

enum LoginItemStatus: Equatable {
    case notRegistered
    case enabled
    case requiresApproval
    case unavailable
}
