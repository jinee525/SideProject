//
//  Item.swift
//  SteadyToday
//
//  Created by 85114 on 1/14/26.
//

import Foundation
import SwiftData

// MARK: - Helpers

enum RoutineActionType: Int, Codable, CaseIterable, Identifiable {
    case weeklyN = 0
    case weekdayRepeat = 1
    case timeBased = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .weeklyN: return "주 N회"
        case .weekdayRepeat: return "요일 반복"
        case .timeBased: return "누적 시간 기록"
        }
    }
}

enum TimeRecordMode: Int, Codable, CaseIterable, Identifiable {
    case timer = 0
    case manual = 1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .timer: return "타이머"
        case .manual: return "수동 입력"
        }
    }
}

/// Monday-based weekday bitmask (Mon=bit0 ... Sun=bit6)
struct WeekdayMask: OptionSet, Codable, Hashable {
    let rawValue: Int

    static let mon = WeekdayMask(rawValue: 1 << 0)
    static let tue = WeekdayMask(rawValue: 1 << 1)
    static let wed = WeekdayMask(rawValue: 1 << 2)
    static let thu = WeekdayMask(rawValue: 1 << 3)
    static let fri = WeekdayMask(rawValue: 1 << 4)
    static let sat = WeekdayMask(rawValue: 1 << 5)
    static let sun = WeekdayMask(rawValue: 1 << 6)

    static let all: WeekdayMask = [.mon, .tue, .wed, .thu, .fri, .sat, .sun]

    @MainActor
    static func from(date: Date) -> WeekdayMask {
        from(date: date, calendar: .steadyMondayCalendar)
    }

    @MainActor
    static func from(date: Date, calendar: Calendar) -> WeekdayMask {
        // Apple weekday: 1=Sun, 2=Mon, ... 7=Sat
        let apple = calendar.component(.weekday, from: date)
        let mondayIndex = (apple + 5) % 7 // Sun(1)->6, Mon(2)->0, ... Sat(7)->5
        return WeekdayMask(rawValue: 1 << mondayIndex)
    }

    @MainActor
    var displayStringKR: String {
        if isEmpty { return "" }
        let map: [(WeekdayMask, String)] = [
            (.mon, "월"), (.tue, "화"), (.wed, "수"), (.thu, "목"), (.fri, "금"), (.sat, "토"), (.sun, "일"),
        ]
        return map.compactMap { contains($0.0) ? $0.1 : nil }.joined()
    }
}

extension Calendar {
    static var steadyMondayCalendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        cal.minimumDaysInFirstWeek = 1
        return cal
    }
}

extension Date {
    func startOfDay(calendar: Calendar = .steadyMondayCalendar) -> Date {
        calendar.startOfDay(for: self)
    }

    func weekInterval(calendar: Calendar = .steadyMondayCalendar) -> DateInterval {
        let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self))!
        let end = calendar.date(byAdding: .day, value: 7, to: start)!
        return DateInterval(start: start, end: end)
    }

    /// 해당 월의 시작일 00:00 ~ 다음 달 1일 00:00 (end 미포함)
    func monthInterval(calendar: Calendar = .steadyMondayCalendar) -> (start: Date, end: Date) {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: self))!
        let end = calendar.date(byAdding: .month, value: 1, to: start)!
        return (start, end)
    }
}

// MARK: - Models

@Model
final class PlanYear {
    var year: Int
    var goalTitle: String
    @Relationship(deleteRule: .cascade) var categories: [MandalartCategory] = []

    init(year: Int, goalTitle: String = "") {
        self.year = year
        self.goalTitle = goalTitle
    }
}

@Model
final class MandalartCategory {
    var name: String
    /// Preset color key for category dot (e.g. "blue", "green").
    var colorKey: String
    var sortOrder: Int
    var planYear: PlanYear?
    @Relationship(deleteRule: .cascade) var actions: [RoutineAction] = []

    init(name: String, colorKey: String = "blue", sortOrder: Int = 0, planYear: PlanYear? = nil) {
        self.name = name
        self.colorKey = colorKey
        self.sortOrder = sortOrder
        self.planYear = planYear
    }
}

@Model
final class RoutineAction {
    var name: String
    var typeRaw: Int
    var weeklyTargetN: Int
    var repeatWeekdaysRaw: Int
    var isActive: Bool
    /// 활성화 시작 날짜 (nil이면 무제한)
    var startDate: Date?
    /// 활성화 종료 날짜 (nil이면 무제한)
    var endDate: Date?
    /// Global ordering for Today list (user drag&drop).
    var todayOrder: Int
    /// Ordering inside a category detail list.
    var categoryOrder: Int
    // Time-based config
    var timeRecordModeRaw: Int
    /// Daily target in minutes (goal mode)
    var timeTargetMinutes: Int

    var category: MandalartCategory?
    @Relationship(deleteRule: .cascade) var checks: [ActionCheck] = []
    @Relationship(deleteRule: .cascade) var timeSessions: [TimeSession] = []

    var type: RoutineActionType {
        get { RoutineActionType(rawValue: typeRaw) ?? .weeklyN }
        set { typeRaw = newValue.rawValue }
    }

    var repeatWeekdays: WeekdayMask {
        get { WeekdayMask(rawValue: repeatWeekdaysRaw) }
        set { repeatWeekdaysRaw = newValue.rawValue }
    }

    var timeRecordMode: TimeRecordMode {
        get { TimeRecordMode(rawValue: timeRecordModeRaw) ?? .timer }
        set { timeRecordModeRaw = newValue.rawValue }
    }

    init(
        name: String,
        type: RoutineActionType,
        weeklyTargetN: Int = 3,
        repeatWeekdays: WeekdayMask = [],
        isActive: Bool = true,
        startDate: Date? = nil,
        endDate: Date? = nil,
        todayOrder: Int = 0,
        categoryOrder: Int = 0,
        category: MandalartCategory? = nil,
        timeRecordMode: TimeRecordMode = .timer,
        timeTargetMinutes: Int = 60
    ) {
        self.name = name
        self.typeRaw = type.rawValue
        self.weeklyTargetN = weeklyTargetN
        self.repeatWeekdaysRaw = repeatWeekdays.rawValue
        self.isActive = isActive
        self.startDate = startDate
        self.endDate = endDate
        self.todayOrder = todayOrder
        self.categoryOrder = categoryOrder
        self.category = category
        self.timeRecordModeRaw = timeRecordMode.rawValue
        self.timeTargetMinutes = timeTargetMinutes
    }

    @MainActor
    func isScheduled(on date: Date) -> Bool {
        isScheduled(on: date, calendar: .steadyMondayCalendar)
    }

    @MainActor
    func isScheduled(on date: Date, calendar: Calendar) -> Bool {
        switch type {
        case .weeklyN:
            return true
        case .weekdayRepeat:
            let todayMask = WeekdayMask.from(date: date, calendar: calendar)
            return repeatWeekdays.contains(todayMask)
        case .timeBased:
            let todayMask = WeekdayMask.from(date: date, calendar: calendar)
            return repeatWeekdays.contains(todayMask)
        }
    }
    
    /// 특정 날짜에 액션이 활성화되어 있는지 확인 (isActive + 활성화 기간 체크)
    @MainActor
    func isActive(on date: Date, calendar: Calendar = .steadyMondayCalendar) -> Bool {
        guard isActive else { return false }
        
        let dayStart = date.startOfDay(calendar: calendar)
        
        // 시작 날짜 체크
        if let startDate = startDate {
            let startDayStart = startDate.startOfDay(calendar: calendar)
            if dayStart < startDayStart {
                return false
            }
        }
        
        // 종료 날짜 체크
        if let endDate = endDate {
            let endDayStart = endDate.startOfDay(calendar: calendar)
            if dayStart > endDayStart {
                return false
            }
        }
        
        return true
    }
}

@Model
final class ActionCheck {
    var day: Date
    var createdAt: Date
    var action: RoutineAction?

    init(day: Date, createdAt: Date = .now, action: RoutineAction? = nil) {
        self.day = day
        self.createdAt = createdAt
        self.action = action
    }
}

@Model
final class GratitudeEntry {
    /// 날짜 (startOfDay 기준, 수정 가능)
    var day: Date
    /// 감사 내용
    var text: String?
    /// 이미지 파일명 (Documents 디렉토리 기준)
    var imageURL: String?
    var createdAt: Date
    var updatedAt: Date

    init(day: Date, text: String? = nil, imageURL: String? = nil, createdAt: Date = .now, updatedAt: Date = .now) {
        self.day = day
        self.text = text
        self.imageURL = imageURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class TimeSession {
    var createdAt: Date
    var startAt: Date?
    var endAt: Date?
    var durationMinutes: Int
    var attributedDay: Date
    var isManual: Bool
    var action: RoutineAction?

    var isOngoing: Bool { startAt != nil && endAt == nil }

    init(
        attributedDay: Date,
        durationMinutes: Int = 0,
        isManual: Bool = false,
        startAt: Date? = nil,
        endAt: Date? = nil,
        action: RoutineAction? = nil
    ) {
        self.createdAt = .now
        self.attributedDay = attributedDay
        self.durationMinutes = durationMinutes
        self.isManual = isManual
        self.startAt = startAt
        self.endAt = endAt
        self.action = action
    }
}

