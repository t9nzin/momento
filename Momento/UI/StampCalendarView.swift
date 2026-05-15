import SwiftUI
import SwiftData

struct StampCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Memento.createdAt) private var allMementos: [Memento]

    @State private var visibleMonth: Date = Calendar.current.startOfMonth(for: .now)

    private let calendar = Calendar.current
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]
    private let accent = Color(red: 1.0, green: 0.24, blue: 0.28)

    private var monthStamps: [Memento] {
        allMementos.filter { calendar.isDate($0.createdAt, equalTo: visibleMonth, toGranularity: .month) }
    }

    private var heroStamp: Memento? {
        monthStamps.min { $0.createdAt < $1.createdAt }
    }

    private var stampByDay: [Date: Memento] {
        Dictionary(grouping: monthStamps) { calendar.startOfDay(for: $0.createdAt) }
            .compactMapValues { stamps in
                stamps.max { $0.createdAt < $1.createdAt }
            }
    }

    private var monthTitle: String {
        visibleMonth.formatted(.dateTime.month(.wide))
    }

    private var yearTitle: String {
        visibleMonth.formatted(.dateTime.year())
    }

    private var gridDays: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: visibleMonth),
              let dayRange = calendar.range(of: .day, in: .month, for: visibleMonth) else {
            return Array(repeating: nil, count: 42)
        }

        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leadingBlanks = firstWeekday - 1
        let dates = dayRange.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: interval.start)
        }
        let cells: [Date?] = Array(repeating: nil, count: leadingBlanks) + dates
        let trailingCount = (7 - cells.count % 7) % 7
        let padded = cells + Array(repeating: nil, count: trailingCount)
        return padded.count >= 42 ? Array(padded.prefix(42)) : padded + Array(repeating: nil, count: 42 - padded.count)
    }

    var body: some View {
        ZStack {
            Color(red: 0.965, green: 0.965, blue: 0.972)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                monthHero
                    .padding(.top, 34)
                    .padding(.bottom, 34)

                calendarGrid
            }
        }
        .gesture(monthSwipeGesture)
    }

    private var header: some View {
        ZStack {
            Text("Calendar")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.black)

            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.78))
                        .frame(width: 42, height: 42)
                        .background(
                            ZStack {
                                Circle().fill(Color.white.opacity(0.72))
                                Circle().fill(Color.white.opacity(0.22))
                            }
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.75), Color.white.opacity(0.15), Color.clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.8
                                )
                        )
                        .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 18)
        }
        .frame(height: 42)
        .padding(.horizontal, 0)
        .padding(.top, 4)
        .offset(y: -4)
    }

    private var monthHero: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text(yearTitle)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color.black.opacity(0.45))

                Text(monthTitle)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.92))
            }
            .frame(width: 132, alignment: .leading)

            Group {
                if let heroStamp {
                    calendarStampImage(heroStamp)
                } else {
                    placeholderHeroStamp
                }
            }
            .frame(width: 138, height: 200)
            .shadow(color: .black.opacity(0.13), radius: 18, x: 0, y: 10)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 38)
    }

    private var placeholderHeroStamp: some View {
        let shape = PostageStampShape(bite: 5.6, spacing: 14.5)
        return RoundedRectangle(cornerRadius: 0)
            .fill(Color.white.opacity(0.58))
            .overlay(
                Image(systemName: "calendar")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.20))
            )
            .clipShape(shape)
    }

    private var calendarGrid: some View {
        VStack(spacing: 0) {
            weekdayRow

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(Array(gridDays.enumerated()), id: \.offset) { idx, date in
                    dayCell(date, index: idx)
                }
            }
        }
        .background(Color.white.opacity(0.34))
        .padding(.horizontal, 10)
    }

    private var weekdayRow: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { idx, symbol in
                Text(symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.42))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .overlay(alignment: .trailing) {
                        if idx < 6 {
                            Rectangle()
                                .fill(Color.black.opacity(0.06))
                                .frame(width: 1)
                        }
                    }
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 1)
        }
    }

    private func dayCell(_ date: Date?, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            if let date {
                let day = calendar.component(.day, from: date)
                let stamp = stampByDay[calendar.startOfDay(for: date)]

                if let stamp {
                    calendarStampImage(stamp)
                        .frame(width: 28, height: 40)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    dayNumber(day, isToday: calendar.isDateInToday(date))
                        .padding(.top, 9)
                        .padding(.trailing, 10)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .overlay(alignment: .trailing) {
            if index % 7 != 6 {
                Rectangle()
                    .fill(Color.black.opacity(0.06))
                    .frame(width: 1)
            }
        }
        .overlay(alignment: .bottom) {
            if index < gridDays.count - 7 {
                Rectangle()
                    .fill(Color.black.opacity(0.06))
                    .frame(height: 1)
            }
        }
    }

    private func dayNumber(_ day: Int, isToday: Bool) -> some View {
        Text("\(day)")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.black.opacity(0.48))
            .frame(width: isToday ? 24 : nil, height: isToday ? 24 : nil)
            .background {
                if isToday {
                    Circle()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                }
            }
    }

    private func calendarStampImage(_ stamp: Memento) -> some View {
        let shape = PostageStampShape(bite: 5.6, spacing: 14.5)
        return ZStack {
            if let image = MementoStore.image(for: stamp) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.black.opacity(0.08)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(shape)
        .overlay {
            LinearGradient(
                colors: [Color.black.opacity(0.07), .clear, Color.black.opacity(0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(shape)
        }
    }

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard abs(value.translation.width) > 48 else { return }
                let monthOffset = value.translation.width < 0 ? 1 : -1
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    visibleMonth = calendar.date(byAdding: .month, value: monthOffset, to: visibleMonth) ?? visibleMonth
                }
            }
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }
}

#Preview {
    StampCalendarView()
}
