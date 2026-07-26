import AppKit
import SwiftUI

@MainActor
struct CalendarPopoverView: View {
    @StateObject private var store: CalendarStore
    @State private var selectedDate: Date
    @State private var displayedMonth: Date
    @State private var automationError: String?

    private let calendar = Calendar.autoupdatingCurrent
    private let calendarOpener: any CalendarOpening

    init(provider: any EventProviding, calendarOpener: any CalendarOpening) {
        let today = Date()
        _store = StateObject(wrappedValue: CalendarStore(provider: provider))
        _selectedDate = State(initialValue: today)
        _displayedMonth = State(initialValue: today)
        self.calendarOpener = calendarOpener
    }

    var body: some View {
        VStack(spacing: 0) {
            CalendarHeaderView(
                displayedMonth: displayedMonth,
                goToPreviousMonth: { moveMonth(by: -1) },
                goToToday: goToToday,
                goToNextMonth: { moveMonth(by: 1) }
            )

            MonthGridView(
                displayedMonth: displayedMonth,
                selectedDate: selectedDate,
                calendar: calendar,
                onSelect: selectDate
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            Divider()

            EventListView(
                selectedDate: selectedDate,
                store: store,
                onOpenEvent: openEvent
            )

            Divider()

            footer
        }
        .frame(width: 360, height: 560)
        .background(.regularMaterial)
        .task {
            store.refresh(for: selectedDate, calendar: calendar)
        }
        .onChange(of: selectedDate) { _, newDate in
            store.refresh(for: newDate, calendar: calendar)
        }
        .alert(
            "无法打开系统日历",
            isPresented: Binding(
                get: { automationError != nil },
                set: { if !$0 { automationError = nil } }
            )
        ) {
            Button("打开自动化设置") {
                SystemSettingsOpener.openAutomationPrivacy()
            }
            Button("好", role: .cancel) {}
        } message: {
            Text(automationError ?? "")
        }
    }

    private var footer: some View {
        HStack {
            SettingsLink {
                Label("设置", systemImage: "gearshape")
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("退出", systemImage: "power")
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 18)
        .frame(height: 42)
    }

    private func moveMonth(by offset: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) else {
            return
        }
        displayedMonth = newMonth
        selectedDate = CalendarGridBuilder(calendar: calendar).startOfMonth(containing: newMonth)
    }

    private func goToToday() {
        let today = Date()
        displayedMonth = today
        selectedDate = today
    }

    private func selectDate(_ date: Date) {
        selectedDate = date
        if !calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month) {
            displayedMonth = date
        }
    }

    private func openEvent(_ event: CalendarEventSummary) {
        do {
            try calendarOpener.open(event)
        } catch {
            automationError = error.localizedDescription
        }
    }
}

private struct CalendarHeaderView: View {
    let displayedMonth: Date
    let goToPreviousMonth: () -> Void
    let goToToday: () -> Void
    let goToNextMonth: () -> Void

    var body: some View {
        HStack {
            Text(displayedMonth, format: .dateTime.year().month(.wide))
                .font(.system(size: 22, weight: .semibold))

            Spacer()

            Button(action: goToPreviousMonth) {
                Image(systemName: "chevron.left")
            }
            .help("上个月")

            Button(action: goToToday) {
                Image(systemName: "circle.circle")
            }
            .help("回到今天")

            Button(action: goToNextMonth) {
                Image(systemName: "chevron.right")
            }
            .help("下个月")
        }
        .buttonStyle(.borderless)
        .font(.system(size: 14, weight: .semibold))
        .padding(.horizontal, 18)
        .frame(height: 56)
    }
}

private struct MonthGridView: View {
    let displayedMonth: Date
    let selectedDate: Date
    let calendar: Calendar
    let onSelect: (Date) -> Void

    private var builder: CalendarGridBuilder {
        CalendarGridBuilder(calendar: calendar)
    }

    var body: some View {
        VStack(spacing: 4) {
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(builder.weekdaySymbols().enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 22)
                }
            }

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(builder.days(containing: displayedMonth)) { day in
                    dayButton(day)
                }
            }
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    }

    private func dayButton(_ day: CalendarDay) -> some View {
        let isSelected = calendar.isDate(day.date, inSameDayAs: selectedDate)

        return Button {
            onSelect(day.date)
        } label: {
            Text(String(calendar.component(.day, from: day.date)))
                .font(.system(size: 14, weight: day.isToday || isSelected ? .semibold : .regular))
                .foregroundStyle(foregroundStyle(for: day, isSelected: isSelected))
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(backgroundStyle(for: day, isSelected: isSelected))
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 34)
        .help(day.date.formatted(date: .long, time: .omitted))
    }

    private func foregroundStyle(for day: CalendarDay, isSelected: Bool) -> Color {
        if isSelected || day.isToday {
            return .white
        }
        return day.isInDisplayedMonth ? .primary : .secondary.opacity(0.55)
    }

    private func backgroundStyle(for day: CalendarDay, isSelected: Bool) -> Color {
        if isSelected {
            return .accentColor
        }
        if day.isToday {
            return .accentColor.opacity(0.72)
        }
        return .clear
    }
}

private struct EventListView: View {
    let selectedDate: Date
    @ObservedObject var store: CalendarStore
    let onOpenEvent: (CalendarEventSummary) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedDate, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 18)
                .padding(.top, 12)

            Group {
                switch store.authorization {
                case .notDetermined:
                    permissionPrompt
                case .denied, .restricted:
                    deniedPrompt
                case .fullAccess:
                    eventContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionPrompt: some View {
        ContentUnavailableView {
            Label("显示系统日程", systemImage: "calendar.badge.clock")
        } description: {
            Text("允许 MenuCal 读取日历后，这里会显示所选日期的事件。")
        } actions: {
            Button("允许读取日历") {
                Task {
                    await store.requestAccess(for: selectedDate)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isLoading)
        }
    }

    private var deniedPrompt: some View {
        ContentUnavailableView {
            Label("无法读取日历", systemImage: "calendar.badge.exclamationmark")
        } description: {
            Text("请在系统设置的“隐私与安全性”中允许 MenuCal 访问日历。")
        } actions: {
            Button("打开系统设置") {
                SystemSettingsOpener.openCalendarPrivacy()
            }
        }
    }

    @ViewBuilder
    private var eventContent: some View {
        if store.isLoading {
            ProgressView()
        } else if store.events.isEmpty {
            ContentUnavailableView(
                "没有日程",
                systemImage: "calendar",
                description: Text("这一天暂时没有安排。")
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(store.events) { event in
                        EventRow(event: event) {
                            onOpenEvent(event)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
        }
    }
}

private struct EventRow: View {
    let event: CalendarEventSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(event.calendarColor.swiftUIColor)
                    .frame(width: 4, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(timeDescription)
                        if let location = event.location {
                            Text("·")
                            Text(location)
                                .lineLimit(1)
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.primary.opacity(0.001))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private var timeDescription: String {
        if event.isAllDay {
            return "全天"
        }
        let start = event.startDate.formatted(date: .omitted, time: .shortened)
        let end = event.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start)–\(end)"
    }
}

private extension CalendarColor {
    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}
