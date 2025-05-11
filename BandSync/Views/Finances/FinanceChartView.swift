// FinanceChartView.swift

import SwiftUI
import Charts

struct FinanceChartView: View {
    let records: [FinanceRecord]
    @State private var chartType: ChartType = .monthly
    @State private var showLegend = true
    @State private var selectedIndex: Int? = nil

    enum ChartType: String, CaseIterable {
        case monthly = "MONTHLY"
        case category = "CATEGORY"

        var localizedName: String {
            switch self {
            case .monthly:
                return NSLocalizedString("By Month", comment: "Chart type: Monthly")
            case .category:
                return NSLocalizedString("By Category", comment: "Chart type: Category")
            }
        }
    }

    private var monthlyRecords: [(month: Date, income: Double, expense: Double)] {
        let calendar = Calendar.current
        let groupedRecords = Dictionary(grouping: records) { record in
            calendar.date(from: calendar.dateComponents([.year, .month], from: record.date)) ?? Date()
        }

        return groupedRecords.map { (month, records) in
            let income = records.filter { $0.type == .income }.reduce(0.0) { $0 + $1.amount }
            let expense = records.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.amount }
            return (month, income, expense)
        }.sorted { $0.month < $1.month }
    }

    private var categoryRecords: [(category: String, amount: Double, isIncome: Bool)] {
        let income = Dictionary(grouping: records.filter { $0.type == .income }) { $0.category }
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
            .map { (category: $0.key, amount: $0.value, isIncome: true) }

        let expense = Dictionary(grouping: records.filter { $0.type == .expense }) { $0.category }
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
            .map { (category: $0.key, amount: $0.value, isIncome: false) }

        return (income + expense).sorted { $0.amount > $1.amount }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(NSLocalizedString("Financial Statistics", comment: "Main chart screen title"))
                    .font(.title2.bold())

                Text(String(format: NSLocalizedString("Total Records: %d", comment: "Total record count"), records.count))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top)

            VStack(spacing: 15) {
                HStack {
                    ForEach(ChartType.allCases, id: \.self) { type in
                        Button {
                            withAnimation {
                                chartType = type
                                selectedIndex = nil
                            }
                        } label: {
                            Text(type.localizedName)
                                .font(.subheadline)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(chartType == type ? Color.blue : Color.clear)
                                        .shadow(color: chartType == type ? Color.blue.opacity(0.3) : .clear, radius: 3)
                                )
                                .foregroundColor(chartType == type ? .white : .primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                HStack(spacing: 20) {
                    statCard(
                        title: NSLocalizedString("Income", comment: "Income stat label"),
                        value: totalIncome,
                        color: .green
                    )
                    statCard(
                        title: NSLocalizedString("Expense", comment: "Expense stat label"),
                        value: totalExpense,
                        color: .red
                    )
                    statCard(
                        title: NSLocalizedString("Balance", comment: "Balance stat label"),
                        value: profit,
                        color: profit >= 0 ? .green : .red
                    )
                }
            }
            .padding()

            Divider()
                .padding(.horizontal)

            ScrollView {
                VStack(spacing: 20) {
                    if records.isEmpty {
                        emptyStateView
                    } else {
                        switch chartType {
                        case .monthly:
                            improvedMonthlyChartView
                        case .category:
                            improvedCategoryChartView
                        }
                    }
                }
                .padding()
            }

            if showLegend && !records.isEmpty {
                legendView
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color.secondary.opacity(0.05).ignoresSafeArea())
    }

    private func statCard(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text("\(Int(value))")
                .font(.headline)
                .foregroundColor(color)

            Rectangle()
                .fill(color)
                .frame(width: 30, height: 3)
                .cornerRadius(1.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 5)
        )
    }

    private var totalIncome: Double {
        records.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var totalExpense: Double {
        records.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var profit: Double {
        totalIncome - totalExpense
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.7))
                .padding(.top, 40)

            Text(NSLocalizedString("No data to display", comment: "Empty state title"))
                .font(.headline)
                .foregroundColor(.gray)

            Text(NSLocalizedString("Add financial transactions to view the statistics.", comment: "Empty state message"))
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray.opacity(0.7))
                .padding(.horizontal)
                .padding(.bottom, 20)
        }
    }

    // Improved monthly chart
    private var improvedMonthlyChartView: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Title with period
            if !monthlyRecords.isEmpty {
                let startDate = monthlyRecords.last?.month ?? Date()
                let endDate = monthlyRecords.first?.month ?? Date()

                Text(String(format: NSLocalizedString("Finances from %@ to %@", comment: "Chart period"), monthFormatter.string(from: startDate), monthFormatter.string(from: endDate)))
                    .font(.headline)
                    .padding(.horizontal)
            }

            if monthlyRecords.isEmpty {
                Text(NSLocalizedString("No data for selected period", comment: "No data message"))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                // Chart
                ZStack(alignment: .top) {
                    // Main chart
                    Chart {
                        ForEach(monthlyRecords.indices, id: \.self) { index in
                            let record = monthlyRecords[index]

                            // Income
                            BarMark(
                                x: .value("Month", record.month, unit: .month),
                                y: .value("Income", record.income)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green.opacity(0.7), .green.opacity(0.9)],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .cornerRadius(4)
                            .opacity(selectedIndex == nil || selectedIndex == index ? 1 : 0.5)

                            // Expenses (negative values)
                            BarMark(
                                x: .value("Month", record.month, unit: .month),
                                y: .value("Expense", -record.expense)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red.opacity(0.7), .red.opacity(0.9)],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .cornerRadius(4)
                            .opacity(selectedIndex == nil || selectedIndex == index ? 1 : 0.5)
                        }

                        // Balance line
                        if monthlyRecords.count > 1 {
                            LineMark(
                                x: .value("Month", monthlyRecords[0].month, unit: .month),
                                y: .value("Balance", monthlyRecords[0].income - monthlyRecords[0].expense)
                            )
                            .foregroundStyle(.blue)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                            .opacity(0.8)

                            ForEach(1..<monthlyRecords.count, id: \.self) { index in
                                LineMark(
                                    x: .value("Month", monthlyRecords[index].month, unit: .month),
                                    y: .value("Balance", monthlyRecords[index].income - monthlyRecords[index].expense)
                                )
                                .foregroundStyle(.blue)
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                                .opacity(0.8)
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(shortMonthFormatter.string(from: date))
                                }
                            }
                        }
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let xPosition = value.location.x
                                            let chartWidth = geometry.size.width
                                            let stepWidth = chartWidth / CGFloat(monthlyRecords.count)

                                            // Get selected point index
                                            let index = min(max(Int(xPosition / stepWidth), 0), monthlyRecords.count - 1)
                                            selectedIndex = index
                                        }
                                        .onEnded { _ in
                                            selectedIndex = nil
                                        }
                                )
                        }
                    }
                    .frame(height: 300)
                    .padding(.vertical)
                    .animation(.easeInOut, value: selectedIndex)

                    // Display details for selected month
                    if let selectedIndex = selectedIndex, selectedIndex < monthlyRecords.count {
                        let record = monthlyRecords[selectedIndex]

                        VStack(spacing: 8) {
                            Text(monthFormatter.string(from: record.month))
                                .font(.headline)

                            HStack(spacing: 20) {
                                Label("+\(Int(record.income))", systemImage: "arrow.down")
                                    .foregroundColor(.green)

                                Label("-\(Int(record.expense))", systemImage: "arrow.up")
                                    .foregroundColor(.red)

                                Label("\(Int(record.income - record.expense))", systemImage: "equal")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .padding(.bottom)
            }
        }
    }

    // Improved category chart
    private var improvedCategoryChartView: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Finance type selector for categories
            HStack {
                Text(NSLocalizedString("Categories:", comment: "Categories label"))
                    .font(.headline)

                Picker("", selection: Binding(
                    get: { self.categoryFilter },
                    set: { newFilter in
                        withAnimation {
                            self.categoryFilter = newFilter
                            self.selectedIndex = nil
                        }
                    }
                )) {
                    Text(NSLocalizedString("All", comment: "All filter")).tag(CategoryFilter.all)
                    Text(NSLocalizedString("Income", comment: "Income filter")).tag(CategoryFilter.income)
                    Text(NSLocalizedString("Expenses", comment: "Expenses filter")).tag(CategoryFilter.expense)
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)

            // Income/expense panel
            HStack(spacing: 10) {
                // Income
                VStack(alignment: .leading, spacing: 5) {
                    Text(NSLocalizedString("Income", comment: "Income label"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(Int(totalIncome))")
                        .font(.headline)
                        .foregroundColor(.green)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.green.opacity(0.2))
                                .frame(width: geo.size.width, height: 6)
                                .cornerRadius(3)

                            Rectangle()
                                .fill(Color.green)
                                .frame(width: totalIncome > 0 && profit > 0
                                       ? geo.size.width * CGFloat(totalIncome / (totalIncome + totalExpense))
                                       : 0,
                                       height: 6)
                                .cornerRadius(3)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                )

                // Expenses
                VStack(alignment: .leading, spacing: 5) {
                    Text(NSLocalizedString("Expenses", comment: "Expenses label"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\(Int(totalExpense))")
                        .font(.headline)
                        .foregroundColor(.red)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.red.opacity(0.2))
                                .frame(width: geo.size.width, height: 6)
                                .cornerRadius(3)

                            Rectangle()
                                .fill(Color.red)
                                .frame(width: totalExpense > 0 && profit < 0
                                       ? geo.size.width * CGFloat(totalExpense / (totalIncome + totalExpense))
                                       : 0,
                                       height: 6)
                                .cornerRadius(3)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                )
            }
            .padding(.horizontal)

            if filteredCategoryRecords.isEmpty {
                Text(NSLocalizedString("No data for selected type", comment: "No data for selected type"))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                // Category chart
                Chart {
                    ForEach(filteredCategoryRecords.indices, id: \.self) { index in
                        let record = filteredCategoryRecords[index]

                        BarMark(
                            x: .value("Amount", record.amount),
                            y: .value("Category", record.category)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    record.isIncome ? .green.opacity(0.7) : .red.opacity(0.7),
                                    record.isIncome ? .green : .red
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(6)
                        .opacity(selectedIndex == nil || selectedIndex == index ? 1 : 0.5)
                        .annotation(position: .trailing) {
                            Text("\(Int(record.amount))")
                                .font(.caption)
                                .foregroundColor(record.isIncome ? .green : .red)
                                .padding(4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.9))
                                )
                        }
                    }
                }
                .chartXAxis(.automatic)
                .chartYAxis {
                    AxisMarks { value in
                        if let category = value.as(String.self) {
                            AxisValueLabel {
                                HStack(spacing: 4) {
                                    let isIncome = filteredCategoryRecords.first { $0.category == category }?.isIncome ?? false
                                    Circle()
                                        .fill(isIncome ? Color.green : Color.red)
                                        .frame(width: 8, height: 8)

                                    Text(category)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let yPosition = value.location.y
                                        let chartHeight = geometry.size.height
                                        let stepHeight = chartHeight / CGFloat(filteredCategoryRecords.count)

                                        // Get selected category index
                                        let index = min(max(Int(yPosition / stepHeight), 0), filteredCategoryRecords.count - 1)
                                        selectedIndex = index
                                    }
                                    .onEnded { _ in
                                        selectedIndex = nil
                                    }
                            )
                    }
                }
                .frame(height: CGFloat(filteredCategoryRecords.count * 40))
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .animation(.easeInOut, value: selectedIndex)
                .padding(.bottom)

                // If category is selected, show details
                if let selectedIndex = selectedIndex, selectedIndex < filteredCategoryRecords.count {
                    let record = filteredCategoryRecords[selectedIndex]

                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(record.category)
                                .font(.headline)

                            Text(record.isIncome ? NSLocalizedString("Income", comment: "Income type") : NSLocalizedString("Expense", comment: "Expense type"))
                                .font(.subheadline)
                                .foregroundColor(record.isIncome ? .green : .red)
                        }

                        Spacer()

                        Text("\(Int(record.amount))")
                            .font(.title3.bold())
                            .foregroundColor(record.isIncome ? .green : .red)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(record.isIncome ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    )
                    .padding(.horizontal)
                    .transition(.scale.combined(with: .opacity))
                }

                // Additional information about transactions in selected category
                if let selectedIndex = selectedIndex, selectedIndex < filteredCategoryRecords.count {
                    let record = filteredCategoryRecords[selectedIndex]

                    let categoryTransactions = records.filter {
                        $0.category == record.category &&
                        (record.isIncome ? $0.type == .income : $0.type == .expense)
                    }

                    Text(NSLocalizedString("Recent Transactions", comment: "Recent transactions label"))
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)

                    ForEach(categoryTransactions.prefix(3)) { transaction in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(transaction.details.isEmpty ? NSLocalizedString("No description", comment: "No description label") : transaction.details)")
                                    .fontWeight(.medium)

                                Text(dateFormatter.string(from: transaction.date))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text("\(Int(transaction.amount))")
                                .fontWeight(.semibold)
                                .foregroundColor(transaction.type == .income ? .green : .red)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        .background(Color.white)
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    // Legend
    private var legendView: some View {
        HStack {
            switch chartType {
            case .monthly:
                legendItem(color: .green, text: NSLocalizedString("Income", comment: "Income legend"))
                legendItem(color: .red, text: NSLocalizedString("Expenses", comment: "Expenses legend"))
                legendItem(color: .blue, text: NSLocalizedString("Balance", comment: "Balance legend"))
            case .category:
                switch categoryFilter {
                case .all:
                    legendItem(color: .green, text: NSLocalizedString("Income", comment: "Income legend"))
                    legendItem(color: .red, text: NSLocalizedString("Expenses", comment: "Expenses legend"))
                case .income:
                    legendItem(color: .green, text: NSLocalizedString("Income", comment: "Income legend"))
                case .expense:
                    legendItem(color: .red, text: NSLocalizedString("Expenses", comment: "Expenses legend"))
                }
            }

            Spacer()

            // Toggle legend button
            Button {
                withAnimation {
                    showLegend.toggle()
                }
            } label: {
                Image(systemName: showLegend ? "eye.slash" : "eye")
                    .foregroundColor(.secondary)
                    .padding(4)
                    .background(
                        Circle()
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
        )
    }

    // Legend item
    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.trailing, 8)
    }

    // Properties for improved charts

    // Category filter
    @State private var categoryFilter: CategoryFilter = .all

    enum CategoryFilter {
        case all
        case income
        case expense
    }

    // Filtered category records
    private var filteredCategoryRecords: [(category: String, amount: Double, isIncome: Bool)] {
        switch categoryFilter {
        case .all:
            return categoryRecords
        case .income:
            return categoryRecords.filter { $0.isIncome }
        case .expense:
            return categoryRecords.filter { !$0.isIncome }
        }
    }

    // Date formatters
    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }

    private var shortMonthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}
