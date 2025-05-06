import SwiftUI

struct AlertSettingsView: View {
    @EnvironmentObject private var alertManager: PriceAlertManager
    @EnvironmentObject private var vm: DashboardViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAddAlert = false
    @State private var selectedSymbol: String = ""
    @State private var alertPrice: String = ""
    @State private var alertType: AlertType = .priceAbove
    
    var body: some View {
        NavigationStack {
            VStack {
                if alertManager.alerts.isEmpty {
                    ContentUnavailableView(
                        "No Alerts",
                        systemImage: "bell.slash",
                        description: Text("Add price alerts to receive haptic feedback when prices reach your targets.")
                    )
                } else {
                    List {
                        ForEach(alertManager.alerts) { alert in
                            AlertRow(alert: alert)
                        }
                        .onDelete(perform: deleteAlerts)
                    }
                }
            }
            .navigationTitle("Price Alerts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showingAddAlert = true
                    }) {
                        Label("Add Alert", systemImage: "plus")
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddAlert) {
                AddAlertView(
                    isPresented: $showingAddAlert,
                    symbols: vm.allSymbols
                )
                .environmentObject(alertManager)
            }
        }
    }
    
    private func deleteAlerts(at offsets: IndexSet) {
        for index in offsets {
            alertManager.removeAlert(id: alertManager.alerts[index].id)
        }
    }
}

struct AlertRow: View {
    @EnvironmentObject private var alertManager: PriceAlertManager
    let alert: PriceAlert
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.symbol)
                    .font(.headline)
                
                HStack {
                    Text(alert.type.description)
                        .font(.subheadline)
                    
                    Text(String(format: "%.2f", alert.price))
                        .font(.subheadline)
                        .bold()
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { alert.isActive },
                set: { _ in alertManager.toggleAlert(id: alert.id) }
            ))
        }
        .padding(.vertical, 4)
    }
}

struct AddAlertView: View {
    @EnvironmentObject private var alertManager: PriceAlertManager
    @Binding var isPresented: Bool
    
    let symbols: [String]
    
    @State private var selectedSymbol: String = ""
    @State private var alertPrice: String = ""
    @State private var alertType: AlertType = .priceAbove
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Symbol")) {
                    Picker("Select Symbol", selection: $selectedSymbol) {
                        ForEach(symbols, id: \.self) { symbol in
                            Text(symbol).tag(symbol)
                        }
                    }
                }
                
                Section(header: Text("Alert Details")) {
                    Picker("Alert Type", selection: $alertType) {
                        ForEach(AlertType.allCases) { type in
                            Text(type.description).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    TextField("Price", text: $alertPrice)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add Price Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAlert()
                    }
                    .disabled(selectedSymbol.isEmpty || alertPrice.isEmpty)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                if !symbols.isEmpty {
                    selectedSymbol = symbols[0]
                }
            }
        }
    }
    
    private func saveAlert() {
        guard let price = Double(alertPrice) else {
            errorMessage = "Please enter a valid price"
            showingError = true
            return
        }
        
        alertManager.addAlert(symbol: selectedSymbol, price: price, type: alertType)
        isPresented = false
    }
}

extension DashboardViewModel {
    /// Get all symbol names
    var allSymbols: [String] {
        let stockSymbols = stockQuotes.map { $0.symbol }
        let cryptoSymbols = cryptoQuotes.map { $0.symbol }
        return stockSymbols + cryptoSymbols
    }
} 