//
//  DaySchedule.swift
//  rent-a-car
//

import Foundation

struct DaySchedule: Codable, Identifiable {
    var id: String { day }
    var day: String
    var hours: String

    var isToday: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date()) == day
    }

    static let defaultWeek: [DaySchedule] = [
        DaySchedule(day: "Monday",    hours: "9:00 AM – 6:00 PM"),
        DaySchedule(day: "Tuesday",   hours: "9:00 AM – 6:00 PM"),
        DaySchedule(day: "Wednesday", hours: "9:00 AM – 6:00 PM"),
        DaySchedule(day: "Thursday",  hours: "9:00 AM – 6:00 PM"),
        DaySchedule(day: "Friday",    hours: "9:00 AM – 6:00 PM"),
        DaySchedule(day: "Saturday",  hours: "10:00 AM – 4:00 PM"),
        DaySchedule(day: "Sunday",    hours: "Closed"),
    ]
}
