import SwiftUI

struct FixedExpenseListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = FixedExpenseListViewModel()
    @State private var showingForm = false
    @State private var editingExpense: FixedExpense?

    var body: some View {
        VStack(spacing: 0) {
            MonthNavigator(
                yearMonth: viewModel.yearMonth,
                onPrevious: { viewModel.navigateMonth(by: -1) },
                onNext: { viewModel.navigateMonth(by: 1) }
            )
            .padding()

            VStack(spacing: 0) {
                HStack {
                    Label("\(viewModel.paidCount)/\(viewModel.fixedExpenses.count) Paid", systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Total: \(viewModel.totalAmount.asCurrency(code: appState.defaultCurrency))")
                        .font(.subheadline.bold())
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                List {
                    ForEach(viewModel.fixedExpenses) { expense in
                        FixedExpenseRow(
                            expense: expense,
                            isPaid: viewModel.isPaid(expense)
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteExpense(expense) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                editingExpense = expense
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                    }
                }
                .listStyle(.plain)
                .overlay {
                    if viewModel.fixedExpenses.isEmpty && !viewModel.isLoading {
                        EmptyStateView(
                            title: "No Fixed Expenses",
                            message: "Add recurring bills or copy from the previous month.",
                            systemImage: "calendar.badge.clock"
                        )
                    }
                }
            }
            .monthPageTransition(
                yearMonth: viewModel.yearMonth,
                direction: viewModel.navigationDirection
            )
        }
        .navigationTitle("Fixed Expenses")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingForm = true
                    } label: {
                        Label("New Fixed Expense", systemImage: "plus")
                    }
                    Button {
                        Task { await viewModel.copyFromPreviousMonth() }
                    } label: {
                        Label("Copy from Previous Month", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            FixedExpenseFormSheet(yearMonth: viewModel.yearMonth) {
                await viewModel.load()
            }
        }
        .sheet(item: $editingExpense) { expense in
            FixedExpenseFormSheet(yearMonth: viewModel.yearMonth, editing: expense) {
                await viewModel.load()
            }
        }
        .swipeToNavigateMonth(
            onPrevious: { viewModel.navigateMonth(by: -1) },
            onNext: { viewModel.navigateMonth(by: 1) }
        )
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}
