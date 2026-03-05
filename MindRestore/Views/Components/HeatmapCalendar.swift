import SwiftUI

struct HeatmapCalendarView: View {
    let trainingDays: Set<Date>
    private let calendar = Calendar.current
    private let columns = 7
    private let weeks = 13 // ~3 months

    private var days: [Date] {
        let today = calendar.startOfDay(for: Date())
        let totalDays = weeks * columns
        return (0..<totalDays).compactMap {
            calendar.date(byAdding: .day, value: -(totalDays - 1 - $0), to: today)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Day labels
            HStack(spacing: 0) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: columns), spacing: 3) {
                ForEach(days, id: \.self) { date in
                    let isTrained = trainingDays.contains(calendar.startOfDay(for: date))
                    let isToday = calendar.isDateInToday(date)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(cellColor(isTrained: isTrained, isToday: isToday))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private func cellColor(isTrained: Bool, isToday: Bool) -> Color {
        if isTrained {
            return AppColors.accent
        } else if isToday {
            return AppColors.accent.opacity(0.2)
        }
        return Color(UIColor.tertiarySystemFill)
    }
}
