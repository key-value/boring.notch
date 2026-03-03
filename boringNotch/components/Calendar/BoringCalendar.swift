//
//  BoringCalendar.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 08/09/24.
//

import Defaults
import SwiftUI

struct Config: Equatable {
    //    var count: Int = 10  // 3 days past + today + 7 days future
    var past: Int = 7
    var future: Int = 14
    var steps: Int = 1  // Each step is one day
    var spacing: CGFloat = 0
    var showsText: Bool = true
    var offset: Int = 2  // Number of dates to the left of the selected date
}

struct WheelPicker: View {
    @EnvironmentObject var vm: BoringViewModel
    @Binding var selectedDate: Date
    @State private var scrollPosition: Int?
    @State private var haptics: Bool = false
    @State private var byClick: Bool = false
    let config: Config

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: config.spacing) {
                let spacerNum = config.offset
                let dateCount = totalDateItems()
                let totalItems = dateCount + 2 * spacerNum
                ForEach(0..<totalItems, id: \.self) { index in
                    if index < spacerNum || index >= spacerNum + dateCount {
                        // Leading/trailing spacers sized to match a date cell
                        Spacer()
                            .frame(width: 24, height: 24)
                            .id(index)
                    } else {
                        let date = dateForItemIndex(index: index, spacerNum: spacerNum)
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                        dateButton(date: date, isSelected: isSelected, id: index) {
                            selectedDate = date
                            byClick = true
                            withAnimation {
                                scrollPosition = index
                            }
                            if Defaults[.enableHaptics] {
                                haptics.toggle()
                            }
                        }
                    }
                }
            }
            .frame(height: 50)
            .scrollTargetLayout()
        }
        .scrollIndicators(.never)
        .scrollPosition(id: $scrollPosition, anchor: .center)
        .scrollTargetBehavior(.viewAligned)  // Ensures scroll view snaps the centered view
        .safeAreaPadding(.horizontal)
        .sensoryFeedback(.alignment, trigger: haptics)
        .onChange(of: scrollPosition) { oldValue, newValue in
            if !byClick {
                handleScrollChange(newValue: newValue, config: config)
            } else {
                byClick = false
            }
        }
        .onAppear {
            scrollToToday(config: config)
        }
        // When parent updates the bound selectedDate (e.g., view reopen), center the wheel on it
        .onChange(of: selectedDate) { _, newValue in
            let targetIndex = indexForDate(newValue)
            if scrollPosition != targetIndex {
                byClick = true
                withAnimation {
                    scrollPosition = targetIndex
                }
            }
        }
    }

    private func dateButton(
        date: Date, isSelected: Bool, id: Int, onClick: @escaping () -> Void
    ) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        return Button(action: onClick) {
            VStack(spacing: 8) {
                dayText(date: dateToString(for: date), isToday: isToday, isSelected: isSelected)
                dateCircle(date: date, isToday: isToday, isSelected: isSelected)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .background(isSelected ? Color.effectiveAccentBackground : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .id(id)
    }

    private func dayText(date: String, isToday: Bool, isSelected: Bool) -> some View {
        Text(date)
            .font(.caption)
            .foregroundColor(isSelected ? .white : Color(white: 0.65))
    }

    private func dateCircle(date: Date, isToday: Bool, isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isToday ? Color.effectiveAccent : .clear)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 0)
                )
            Text("\(date.date)")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : Color(white: isToday ? 0.9 : 0.65))
        }
    }

    func handleScrollChange(newValue: Int?, config: Config) {
        guard let newIndex = newValue else { return }
        let spacerNum = config.offset
        let dateCount = totalDateItems()
        guard (spacerNum..<(spacerNum + dateCount)).contains(newIndex) else { return }
        let date = dateForItemIndex(index: newIndex, spacerNum: spacerNum)
        if !Calendar.current.isDate(date, inSameDayAs: selectedDate) {
            selectedDate = date
            if Defaults[.enableHaptics] {
                haptics.toggle()
            }
        }
    }

    private func scrollToToday(config: Config) {
        let today = Date()
        byClick = true
        scrollPosition = indexForDate(today)
        selectedDate = today
    }

    // MARK: - Index/Date mapping with steps and spacers
    private func indexForDate(_ date: Date) -> Int {
        let spacerNum = config.offset
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let startDate = cal.startOfDay(for: cal.date(byAdding: .day, value: -config.past, to: today) ?? today)
        let target = cal.startOfDay(for: date)
        let days = cal.dateComponents([.day], from: startDate, to: target).day ?? 0
        let stepIndex = max(0, min(days / max(config.steps, 1), totalDateItems() - 1))
        return spacerNum + stepIndex
    }

    private func dateForItemIndex(index: Int, spacerNum: Int) -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let startDate = cal.date(byAdding: .day, value: -config.past, to: today) ?? today
        let stepIndex = index - spacerNum
        return cal.date(byAdding: .day, value: stepIndex * max(config.steps, 1), to: startDate) ?? today
    }

    private func totalDateItems() -> Int {
        let range = config.past + config.future
        let step = max(config.steps, 1)
        return Int(ceil(Double(range) / Double(step))) + 1
    }

    private func dateToString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

struct CalendarView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject private var calendarManager = CalendarManager.shared
    @State private var selectedDate = Date()

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(selectedDate.formatted(.dateTime.month(.abbreviated)))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text(selectedDate.formatted(.dateTime.year()))
                    .font(.headline)
                    .fontWeight(.light)
                    .foregroundColor(Color(white: 0.65))
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    navButton(systemName: "chevron.up") {
                        shiftSelectedDate(years: -1)
                    }
                    navButton(systemName: "chevron.left") {
                        shiftSelectedDate(months: -1)
                    }
                    navButton(systemName: "chevron.right") {
                        shiftSelectedDate(months: 1)
                    }
                    navButton(systemName: "chevron.down") {
                        shiftSelectedDate(years: 1)
                    }
                }
            }
            MonthGrid(monthDate: selectedDate, selectedDate: selectedDate) { date in
                selectedDate = date
            }
        }
        .listRowBackground(Color.clear)
        .frame(height: 120)
        .onChange(of: selectedDate) {
            Task {
                await calendarManager.updateCurrentDate(selectedDate)
            }
        }
        .onChange(of: vm.notchState) { _, _ in
            Task {
                await calendarManager.updateCurrentDate(Date.now)
                selectedDate = Date.now
            }
        }
        .onAppear {
            Task {
                await calendarManager.updateCurrentDate(Date.now)
                selectedDate = Date.now
            }
        }
    }

    private func navButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.caption2)
                .foregroundColor(Color(white: 0.8))
                .frame(width: 12, height: 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func shiftSelectedDate(months: Int) {
        selectedDate = adjustedDate(byAddingMonths: months, to: selectedDate)
    }

    private func shiftSelectedDate(years: Int) {
        selectedDate = adjustedDate(byAddingYears: years, to: selectedDate)
    }

    private func adjustedDate(byAddingMonths months: Int, to date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day else { return date }
        let base = cal.date(from: DateComponents(year: year, month: month, day: 1)) ?? date
        let targetMonthStart = cal.date(byAdding: .month, value: months, to: base) ?? base
        let range = cal.range(of: .day, in: .month, for: targetMonthStart) ?? 1..<2
        let clampedDay = min(day, range.count)
        return cal.date(bySetting: .day, value: clampedDay, of: targetMonthStart) ?? targetMonthStart
    }

    private func adjustedDate(byAddingYears years: Int, to date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day else { return date }
        let base = cal.date(from: DateComponents(year: year, month: month, day: 1)) ?? date
        let targetMonthStart = cal.date(byAdding: .year, value: years, to: base) ?? base
        let range = cal.range(of: .day, in: .month, for: targetMonthStart) ?? 1..<2
        let clampedDay = min(day, range.count)
        return cal.date(bySetting: .day, value: clampedDay, of: targetMonthStart) ?? targetMonthStart
    }
}

struct CalendarModuleView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject private var calendarManager = CalendarManager.shared
    @State private var selectedDate = Date()

    var body: some View {
        VStack(spacing: 6) {
            header
            GeometryReader { proxy in
                let total = max(proxy.size.width, 1)
                let rightWidth = total * 0.30
                let leftWidth = total - rightWidth
                HStack(alignment: .top, spacing: 8) {
                    MonthGrid(monthDate: selectedDate, selectedDate: selectedDate) { date in
                        selectedDate = date
                    }
                    .frame(width: leftWidth, alignment: .leading)
                    DateDetailView(selectedDate: selectedDate)
                        .frame(width: rightWidth, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .listRowBackground(Color.clear)
        .frame(height: 140, alignment: .top)
        .onChange(of: selectedDate) {
            Task {
                await calendarManager.updateCurrentDate(selectedDate)
            }
        }
        .onChange(of: vm.notchState) { _, _ in
            Task {
                await calendarManager.updateCurrentDate(Date.now)
                selectedDate = Date.now
            }
        }
        .onAppear {
            Task {
                await calendarManager.updateCurrentDate(Date.now)
                selectedDate = Date.now
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(selectedDate.formatted(.dateTime.month(.abbreviated)))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Text(selectedDate.formatted(.dateTime.year()))
                .font(.headline)
                .fontWeight(.light)
                .foregroundColor(Color(white: 0.65))
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                navButton(systemName: "chevron.up") {
                    shiftSelectedDate(years: -1)
                }
                navButton(systemName: "chevron.left") {
                    shiftSelectedDate(months: -1)
                }
                navButton(systemName: "chevron.right") {
                    shiftSelectedDate(months: 1)
                }
                navButton(systemName: "chevron.down") {
                    shiftSelectedDate(years: 1)
                }
            }
        }
    }

    private func navButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.caption2)
                .foregroundColor(Color(white: 0.8))
                .frame(width: 12, height: 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func shiftSelectedDate(months: Int) {
        selectedDate = adjustedDate(byAddingMonths: months, to: selectedDate)
    }

    private func shiftSelectedDate(years: Int) {
        selectedDate = adjustedDate(byAddingYears: years, to: selectedDate)
    }

    private func adjustedDate(byAddingMonths months: Int, to date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day else { return date }
        let base = cal.date(from: DateComponents(year: year, month: month, day: 1)) ?? date
        let targetMonthStart = cal.date(byAdding: .month, value: months, to: base) ?? base
        let range = cal.range(of: .day, in: .month, for: targetMonthStart) ?? 1..<2
        let clampedDay = min(day, range.count)
        return cal.date(bySetting: .day, value: clampedDay, of: targetMonthStart) ?? targetMonthStart
    }

    private func adjustedDate(byAddingYears years: Int, to date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day else { return date }
        let base = cal.date(from: DateComponents(year: year, month: month, day: 1)) ?? date
        let targetMonthStart = cal.date(byAdding: .year, value: years, to: base) ?? base
        let range = cal.range(of: .day, in: .month, for: targetMonthStart) ?? 1..<2
        let clampedDay = min(day, range.count)
        return cal.date(bySetting: .day, value: clampedDay, of: targetMonthStart) ?? targetMonthStart
    }
}

struct MonthGrid: View {
    let monthDate: Date
    let selectedDate: Date
    let onSelect: (Date) -> Void

    private let calendar = Calendar.current

    private var startOfMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)) ?? monthDate
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        var symbols = formatter.veryShortStandaloneWeekdaySymbols ?? []
        let firstIndex = max(0, calendar.firstWeekday - 1)
        if firstIndex > 0 {
            symbols = Array(symbols[firstIndex...] + symbols[..<firstIndex])
        }
        return symbols
    }

    private var dayItems: [Date?] {
        let range = calendar.range(of: .day, in: .month, for: startOfMonth) ?? 1..<2
        let dayCount = range.count
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var items = Array<Date?>(repeating: nil, count: leading)
        items.append(contentsOf: (0..<dayCount).map {
            calendar.date(byAdding: .day, value: $0, to: startOfMonth)
        })
        let trailing = max(0, 42 - items.count)
        if trailing > 0 {
            items.append(contentsOf: Array(repeating: nil, count: trailing))
        }
        return items
    }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 1) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundColor(Color(white: 0.6))
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7),
                spacing: 1
            ) {
                ForEach(0..<dayItems.count, id: \.self) { index in
                    if let date = dayItems[index] {
                        dayCell(for: date)
                    } else {
                        Color.clear
                            .frame(height: 12)
                    }
                }
            }
        }
    }

    private func dayCell(for date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        return Button(action: {
            onSelect(date)
        }) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.effectiveAccentBackground)
                } else if isToday {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.effectiveAccent.opacity(0.8), lineWidth: 1)
                }
                HStack(spacing: 4) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.caption2)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(isSelected ? .white : Color(white: isToday ? 0.9 : 0.65))
                    Text(lunarDayString(for: date))
                        .font(.caption2)
                        .scaleEffect(0.6, anchor: .center)
                        .foregroundColor(isSelected ? .white.opacity(0.9) : Color(white: 0.55))
                }
            }
            .frame(height: 16)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func lunarDayString(for date: Date) -> String {
        let chinese = Calendar(identifier: .chinese)
        let comps = chinese.dateComponents([.month, .day, .isLeapMonth], from: date)
        let month = comps.month ?? 1
        let day = comps.day ?? 1
        let isLeap = comps.isLeapMonth ?? false
        let monthNames = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"]
        let dayNames = [
            "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
            "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
            "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"
        ]
        let monthIndex = max(1, min(month, 12)) - 1
        let dayIndex = max(1, min(day, 30)) - 1
        let monthName = monthIndex < monthNames.count ? monthNames[monthIndex] : "正"
        let dayName = dayIndex < dayNames.count ? dayNames[dayIndex] : "初一"
        if day == 1 {
            return "\(isLeap ? "闰" : "")\(monthName)月"
        }
        return dayName
    }
}

struct WeekWheelView: View {
    @Binding var selectedDate: Date

    var body: some View {
        ZStack(alignment: .top) {
            WheelPicker(
                selectedDate: $selectedDate,
                config: Config(past: 3, future: 3, steps: 1, spacing: 0, showsText: true, offset: 1)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(alignment: .top) {
                LinearGradient(
                    colors: [Color.black, .clear], startPoint: .leading, endPoint: .trailing
                )
                .frame(width: 14)
                Spacer()
                LinearGradient(
                    colors: [.clear, Color.black], startPoint: .leading, endPoint: .trailing
                )
                .frame(width: 14)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 50, maxHeight: 50, alignment: .leading)
    }
}

struct DateDetailView: View {
    let selectedDate: Date

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: selectedDate)
    }

    private var weekdayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: selectedDate)
    }

    private var lunarString: String {
        let calendar = Calendar(identifier: .chinese)
        let comps = calendar.dateComponents([.month, .day, .isLeapMonth], from: selectedDate)
        let month = comps.month ?? 1
        let day = comps.day ?? 1
        let isLeap = comps.isLeapMonth ?? false
        let monthNames = ["正月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "冬月", "腊月"]
        let dayNames = [
            "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
            "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
            "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"
        ]
        let monthIndex = max(1, min(month, 12)) - 1
        let dayIndex = max(1, min(day, 30)) - 1
        let monthName = monthIndex < monthNames.count ? monthNames[monthIndex] : "正月"
        let dayName = dayIndex < dayNames.count ? dayNames[dayIndex] : "初一"
        return "农历 \(isLeap ? "闰" : "")\(monthName)\(dayName)"
    }

    private var holidayString: String {
        holidayName(for: selectedDate) ?? "节假日：无"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dateString)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Text(weekdayString)
                .font(.caption)
                .foregroundColor(Color(white: 0.65))
            Text(lunarString)
                .font(.caption)
                .foregroundColor(Color(white: 0.65))
            Text(holidayString)
                .font(.caption)
                .foregroundColor(Color(white: 0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func holidayName(for date: Date) -> String? {
        let gregorian = Calendar.current
        let comps = gregorian.dateComponents([.month, .day], from: date)
        let month = comps.month ?? 0
        let day = comps.day ?? 0
        let solarKey = String(format: "%02d-%02d", month, day)
        let solarHolidays: [String: String] = [
            "01-01": "节假日：元旦",
            "05-01": "节假日：劳动节",
            "10-01": "节假日：国庆节"
        ]
        if let solar = solarHolidays[solarKey] {
            return solar
        }

        let chinese = Calendar(identifier: .chinese)
        let lunar = chinese.dateComponents([.month, .day, .isLeapMonth], from: date)
        guard let lunarMonth = lunar.month, let lunarDay = lunar.day else { return nil }
        if lunar.isLeapMonth == true { return nil }
        let lunarKey = String(format: "%02d-%02d", lunarMonth, lunarDay)
        let lunarHolidays: [String: String] = [
            "01-01": "节假日：春节",
            "01-15": "节假日：元宵节",
            "05-05": "节假日：端午节",
            "07-07": "节假日：七夕",
            "08-15": "节假日：中秋节",
            "09-09": "节假日：重阳节",
            "12-08": "节假日：腊八",
            "12-23": "节假日：小年"
        ]
        if let lunarHoliday = lunarHolidays[lunarKey] {
            return lunarHoliday
        }

        // 除夕：腊月最后一天
        if lunarMonth == 12 {
            let range = chinese.range(of: .day, in: .month, for: date) ?? 1..<2
            if lunarDay == range.count {
                return "节假日：除夕"
            }
        }

        return nil
    }
}

struct EmptyEventsView: View {
    let selectedDate: Date
    
    var body: some View {
        VStack {
            Image(systemName: "calendar.badge.checkmark")
                .font(.title)
                .foregroundColor(Color(white: 0.65))
            Text(Calendar.current.isDateInToday(selectedDate) ? "No events today" : "No events")
                .font(.subheadline)
                .foregroundColor(.white)
            Text("Enjoy your free time!")
                .font(.caption)
                .foregroundColor(Color(white: 0.65))
        }
    }
}

struct EventListView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject private var calendarManager = CalendarManager.shared
    let events: [EventModel]
    @Default(.autoScrollToNextEvent) private var autoScrollToNextEvent
    @Default(.showFullEventTitles) private var showFullEventTitles


    static func filteredEvents(events: [EventModel]) -> [EventModel] {
        events.filter { event in
            if event.type.isReminder {
                if case .reminder(let completed) = event.type {
                    return !completed || !Defaults[.hideCompletedReminders]
                }
            }
            // Filter out all-day events if setting is enabled
            if event.isAllDay && Defaults[.hideAllDayEvents] {
                return false
            }
            return true
        }
    }

    private var filteredEvents: [EventModel] {
        Self.filteredEvents(events: events)
    }

    private func scrollToRelevantEvent(proxy: ScrollViewProxy) {
        let now = Date()
        // Determine a single target using preferred search order:
        // 1) first non-all-day upcoming/in-progress event
        // 2) first all-day event
        // 3) last event (fallback)
        let nonAllDayUpcoming = filteredEvents.first(where: { !$0.isAllDay && $0.end > now })
        let firstAllDay = filteredEvents.first(where: { $0.isAllDay })
        let lastEvent = filteredEvents.last
        guard let target = nonAllDayUpcoming ?? firstAllDay ?? lastEvent else { return }

        Task { @MainActor in
            withTransaction(Transaction(animation: nil)) {
                proxy.scrollTo(target.id, anchor: .top)
            }
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(filteredEvents) { event in
                    Button(action: {
                        if let url = event.calendarAppURL() {
                            openURL(url)
                        }
                    }) {
                        eventRow(event)
                    }
                    .id(event.id)
                    .padding(.leading, -5)
                    .buttonStyle(PlainButtonStyle())
                    .listRowSeparator(.automatic)
                    .listRowSeparatorTint(.gray.opacity(0.2))
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollIndicators(.never)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .onAppear {
                scrollToRelevantEvent(proxy: proxy)
            }
            .onChange(of: filteredEvents) { _, _ in
                scrollToRelevantEvent(proxy: proxy)
            }
        }
        Spacer(minLength: 0)
    }

    private func eventRow(_ event: EventModel) -> some View {
        if event.type.isReminder {
            let isCompleted: Bool
            if case .reminder(let completed) = event.type {
                isCompleted = completed
            } else {
                isCompleted = false
            }
            return AnyView(
                HStack(spacing: 8) {
                    ReminderToggle(
                        isOn: Binding(
                            get: { isCompleted },
                            set: { newValue in
                                Task {
                                    await calendarManager.setReminderCompleted(
                                        reminderID: event.id, completed: newValue
                                    )
                                }
                            }
                        ),
                        color: Color(event.calendar.color)
                    )
                    .opacity(1.0)  // Ensure the toggle is always fully opaque
                    HStack {
                        Text(event.title)
                            .font(.callout)
                            .foregroundColor(.white)
                            .lineLimit(showFullEventTitles ? nil : 1)
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 4) {
                            if event.isAllDay {
                                Text("All-day")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            } else {
                                Text(event.start, style: .time)
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                        }
                    }
                    .opacity(
                        isCompleted
                            ? 0.4
                            : event.start < Date.now && Calendar.current.isDateInToday(event.start)
                                ? 0.6 : 1.0
                    )
                }
                .padding(.vertical, 4)
            )
        } else {
            return AnyView(
                HStack(alignment: .top, spacing: 4) {
                    Rectangle()
                        .fill(Color(event.calendar.color))
                        .frame(width: 3)
                        .cornerRadius(1.5)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .lineLimit(showFullEventTitles ? nil : 2)

                        if let location = event.location, !location.isEmpty {
                            Text(location)
                                .font(.caption)
                                .foregroundColor(Color(white: 0.65))
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 4) {
                        if event.isAllDay {
                            Text("All-day")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .lineLimit(1)
                        } else {
                            Text(event.start, style: .time)
                                .foregroundColor(.white)
                            Text(event.end, style: .time)
                                .foregroundColor(Color(white: 0.65))
                        }
                    }
                    .font(.caption)
                    .frame(minWidth: 44, alignment: .trailing)
                }
                .opacity(
                    event.eventStatus == .ended && Calendar.current.isDateInToday(event.start)
                        ? 0.6 : 1.0)
            )
        }
    }
}

struct ReminderToggle: View {
    @Binding var isOn: Bool
    var color: Color

    var body: some View {
        Button(action: {
            isOn.toggle()
        }) {
            ZStack {
                // Outer ring
                Circle()
                    .strokeBorder(color, lineWidth: 2)
                    .frame(width: 14, height: 14)
                // Inner fill
                if isOn {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }
                Circle()
                    .fill(Color.black.opacity(0.001))
                    .frame(width: 14, height: 14)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(0)
        .accessibilityLabel(isOn ? "Mark as incomplete" : "Mark as complete")
    }
}

#Preview {
    CalendarView()
        .frame(width: 215, height: 130)
        .background(.black)
        .environmentObject(BoringViewModel())
}
