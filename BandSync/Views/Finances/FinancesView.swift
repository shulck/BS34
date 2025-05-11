import SwiftUI
import Charts

struct FinancesView: View {
    @StateObject private var service = FinanceService.shared
    @State private var showAdd = false
    @State private var showScanner = false
    @State private var showChart = false
    @State private var scannedText = ""
    @State private var extractedFinanceRecord: FinanceRecord?

    // States for filtering
    @State private var showFilter = false
    @State private var filterType: FilterType = .all
    @State private var filterPeriod: FilterPeriod = .allTime

    // Enumerations for filtering
    enum FilterType: String, CaseIterable {
        case all = "All"
        case income = "Income"
        case expense = "Expenses"
    }

    enum FilterPeriod: String, CaseIterable {
        case allTime = "All time"
        case thisMonth = "Current month"
        case last3Months = "3 months"
        case thisYear = "Current year"
    }

    // Filtered records
    private var filteredRecords: [FinanceRecord] {
        let filtered = service.records

        // Filter by type
        let typeFiltered = filtered.filter { record in
            switch filterType {
            case .all: return true
            case .income: return record.type == .income
            case .expense: return record.type == .expense
            }
        }

        // Filter by period
        return typeFiltered.filter { record in
            let calendar = Calendar.current
            let now = Date()
            let recordDate = record.date

            switch filterPeriod {
            case .allTime:
                return true
            case .thisMonth:
                let components = calendar.dateComponents([.year, .month], from: now)
                let startOfMonth = calendar.date(from: components)!
                return recordDate >= startOfMonth
            case .last3Months:
                let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now)!
                return recordDate >= threeMonthsAgo
            case .thisYear:
                let components = calendar.dateComponents([.year], from: now)
                let startOfYear = calendar.date(from: components)!
                return recordDate >= startOfYear
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Summary section
                summarySection

                // Filter section
                filterSection

                // Transaction list with improved design
                transactionListSection
            }
            .navigationTitle("Finances")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Receipt scanner button
                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "doc.text.viewfinder")
                    }

                    // Chart button
                    Button {
                        showChart.toggle()
                    } label: {
                        Image(systemName: "chart.bar")
                    }

                    // Add transaction button
                    Button {
                        showAdd = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .onAppear {
                if let groupId = AppState.shared.user?.groupId {
                    service.fetch(for: groupId)
                }
            }
            .sheet(isPresented: $showAdd) {
                AddTransactionView()
            }
            .sheet(isPresented: $showScanner) {
                ReceiptScannerView(recognizedText: $scannedText, extractedFinanceRecord: $extractedFinanceRecord)
            }
            .sheet(isPresented: $showChart) {
                FinanceChartView(records: filteredRecords)
            }
        }
    }

    // Improved summary section
    private var summarySection: some View {
        VStack(spacing: 0) {
            // Information panel with general data
            HStack(spacing: 20) {
                // Income
                VStack(spacing: 8) {
                    Text("Income")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text("+\(Int(totalIncome))")
                        .font(.title3.bold())
                        .foregroundColor(.green)

                    // Small income visualization
                    Capsule()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 60, height: 4)
                        .overlay(
                            Capsule()
                                .fill(Color.green)
                                .frame(width: totalIncome > 0 ? min(60, 60 * CGFloat(totalIncome / (totalIncome + totalExpense))) : 0, height: 4),
                            alignment: .leading
                        )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.05))
                .cornerRadius(10)

                // Expenses
                VStack(spacing: 8) {
                    Text("Expenses")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text("-\(Int(totalExpense))")
                        .font(.title3.bold())
                        .foregroundColor(.red)

                    // Small expense visualization
                    Capsule()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 60, height: 4)
                        .overlay(
                            Capsule()
                                .fill(Color.red)
                                .frame(width: totalExpense > 0 ? min(60, 60 * CGFloat(totalExpense / (totalIncome + totalExpense))) : 0, height: 4),
                            alignment: .leading
                        )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.05))
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.top, 10)

            Divider()
                .padding(.horizontal)
                .padding(.top, 10)

            // Total profit
            HStack {
                Text("Profit")
                    .font(.headline)
                Spacer()
                Text("\(Int(profit))")
                    .font(.headline)
                    .foregroundColor(profit >= 0 ? .green : .red)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(profit >= 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    )
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            // Mini balance chart
            if !filteredRecords.isEmpty {
                let balanceHistory = calculateBalanceHistory()

                HStack {
                    Text("Balance dynamics")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    // Percentage dynamics
                    if balanceHistory.count > 1 {
                        let change = balanceHistory.last! - balanceHistory.first!
                        let percentage = balanceHistory.first! != 0 ? (change / abs(balanceHistory.first!)) * 100 : 0

                        Text(percentage >= 0 ? "+\(Int(percentage))%" : "\(Int(percentage))%")
                            .font(.caption)
                            .foregroundColor(percentage >= 0 ? .green : .red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(percentage >= 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                            )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 5)

                GeometryReader { geometry in
                    Path { path in
                        guard balanceHistory.count > 1 else { return }

                        let width = geometry.size.width
                        let height = geometry.size.height - 5

                        // Find minimum and maximum values for scaling
                        let minValue = balanceHistory.min() ?? 0
                        let maxValue = balanceHistory.max() ?? 0
                        let range = max(1.0, maxValue - minValue) // avoid division by zero

                        // Initial point of the chart
                        let firstX: CGFloat = 0
                        let firstY = height - (CGFloat(balanceHistory[0] - minValue) / CGFloat(range)) * height
                        path.move(to: CGPoint(x: firstX, y: firstY))

                        // Draw chart line
                        for i in 1..<balanceHistory.count {
                            let x = width * CGFloat(i) / CGFloat(balanceHistory.count - 1)
                            let y = height - (CGFloat(balanceHistory[i] - minValue) / CGFloat(range)) * height
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [profit >= 0 ? .green : .red, .blue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                }
                .frame(height: 30)
                .padding(.horizontal)
                .padding(.bottom, 10)
            }

            Divider()
        }
        .background(Color.gray.opacity(0.05))
    }

    // Improved filter section
    private var filterSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut) {
                    showFilter.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .foregroundColor(filterType != .all || filterPeriod != .allTime ? .blue : .gray)

                    Text("Filter")
                        .font(.subheadline)

                    if filterType != .all || filterPeriod != .allTime {
                        Text("active")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.1))
                            )
                            .foregroundColor(.blue)
                    }

                    Spacer()

                    Image(systemName: showFilter ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .buttonStyle(PlainButtonStyle())

            if showFilter {
                VStack(spacing: 12) {
                    // Transaction type
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Type:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Picker("", selection: $filterType) {
                            ForEach(FilterType.allCases, id: \.self) { type in
                                HStack {
                                    Circle()
                                        .fill(type == .income ? Color.green : type == .expense ? Color.red : Color.gray)
                                        .frame(width: 8, height: 8)
                                    Text(type.rawValue).tag(type)
                                }
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Period
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Period:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack {
                            ForEach(FilterPeriod.allCases, id: \.self) { period in
                                Button {
                                    filterPeriod = period
                                } label: {
                                    Text(period.rawValue)
                                        .font(.caption)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(filterPeriod == period ? Color.blue : Color.gray.opacity(0.1))
                                        )
                                        .foregroundColor(filterPeriod == period ? .white : .primary)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    // Reset filter button
                    Button {
                        filterType = .all
                        filterPeriod = .allTime
                    } label: {
                        Text("Reset filter")
                            .font(.footnote)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(filterType != .all || filterPeriod != .allTime ? 1 : 0.5))
                            )
                    }
                    .disabled(filterType == .all && filterPeriod == .allTime)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(.opacity)
            }

            Divider()
        }
    }

    // Improved transaction list
    private var transactionListSection: some View {
        List {
            // If there are records - show them
            if !filteredRecords.isEmpty {
                // Group records by date (month)
                ForEach(groupedByMonth(), id: \.key) { monthData in
                    // Use simpler Section syntax
                    Section {
                        ForEach(monthData.records) { record in
                            NavigationLink {
                                TransactionDetailView(record: record)
                            } label: {
                                transactionRowView(for: record)
                            }
                            .contextMenu {
                                Button(action: {
                                    // Creates a copy for repeating transaction
                                }) {
                                    Label("Repeat", systemImage: "arrow.triangle.2.circlepath")
                                }
                            }
                        }
                    } header: {
                        monthHeaderView(for: monthData.key)
                    }
                }
            } else {
                // Empty state
                VStack(spacing: 20) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.7))
                        .padding(.top, 40)

                    Text("No financial records")
                        .font(.headline)
                        .foregroundColor(.gray)

                    Text("Add income or expense by clicking the «+» button in the top right corner")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray.opacity(0.7))
                        .padding(.horizontal)

                    Button {
                        showAdd = true
                    } label: {
                        Text("Add record")
                            .font(.headline)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.top, 10)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(PlainListStyle())
    }

    // Helper functions for improved design

    // Grouping by month
    private func groupedByMonth() -> [MonthRecords] {
        let grouped = Dictionary(grouping: filteredRecords) { record -> Date in
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: record.date)
            return calendar.date(from: components) ?? record.date
        }

        return grouped.map { (key, value) in
            MonthRecords(key: key, records: value)
        }.sorted { $0.key > $1.key }
    }

    // Month grouping structure
    struct MonthRecords {
        let key: Date
        let records: [FinanceRecord]
    }

    // Month header
    private func monthHeaderView(for date: Date) -> some View {
        HStack {
            // Month indicator
            Text(monthFormatter.string(from: date))
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            // Total amount for month
            let monthSummary = calculateMonthSummary(for: date)
            Text(monthSummary >= 0 ? "+\(Int(monthSummary))" : "\(Int(monthSummary))")
                .foregroundColor(monthSummary >= 0 ? .green : .red)
                .font(.subheadline.bold())
        }
        .padding(.vertical, 5)
    }

    // Calculate total for month
    private func calculateMonthSummary(for date: Date) -> Double {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)

        return filteredRecords
            .filter {
                let recordComponents = calendar.dateComponents([.year, .month], from: $0.date)
                return recordComponents.year == components.year && recordComponents.month == components.month
            }
            .reduce(0) { sum, record in
                sum + (record.type == .income ? record.amount : -record.amount)
            }
    }

    // Month formatter
    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }

    // Transaction row
    private func transactionRowView(for record: FinanceRecord) -> some View {
        HStack(spacing: 12) {
            // Category icon
            ZStack {
                Circle()
                    .fill(record.type == .income ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: categoryIcon(for: record.category))
                    .font(.system(size: 16))
                    .foregroundColor(record.type == .income ? .green : .red)
            }

            // Transaction information
            VStack(alignment: .leading, spacing: 4) {
                Text(record.category)
                    .font(.headline)

                HStack {
                    Text(dateFormatter.string(from: record.date))
                        .font(.caption)
                        .foregroundColor(.gray)

                    if !record.details.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.gray)

                        Text(record.details)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Amount
            Text("\(record.type == .income ? "+" : "-")\(Int(record.amount))")
                .font(.headline)
                .foregroundColor(record.type == .income ? .green : .red)
        }
        .padding(.vertical, 4)
    }

    // Date formatter for row
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    // Get icon for category
    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Logistics": return "car.fill"
        case "Food": return "fork.knife"
        case "Equipment": return "guitars"
        case "Accommodation": return "house.fill"
        case "Promotion": return "megaphone.fill"
        case "Other": return "ellipsis.circle.fill"
        case "Performances": return "music.note"
        case "Merch": return "tshirt.fill"
        case "Royalties": return "music.quarternote.3"
        case "Sponsorship": return "dollarsign.circle"
        default: return "questionmark.circle"
        }
    }

    // Calculate balance history for mini chart
    private func calculateBalanceHistory() -> [Double] {
        var sortedRecords = filteredRecords.sorted { $0.date < $1.date }

        // Limit number of points for chart
        if sortedRecords.count > 15 {
            let step = sortedRecords.count / 15
            sortedRecords = stride(from: 0, to: sortedRecords.count, by: step).map { sortedRecords[$0] }
        }

        var balance: Double = 0
        var history: [Double] = []

        for record in sortedRecords {
            if record.type == .income {
                balance += record.amount
            } else {
                balance -= record.amount
            }
            history.append(balance)
        }

        // If we have less than two points, add more
        if history.count < 2 {
            if history.isEmpty {
                history = [0, 0]
            } else {
                history.append(history[0])
            }
        }

        return history
    }

    // Computed properties for statistics (using filtered data)
    private var totalIncome: Double {
        filteredRecords.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var totalExpense: Double {
        filteredRecords.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var profit: Double {
        totalIncome - totalExpense
    }
}
