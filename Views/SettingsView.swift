import SwiftUI

/// View for managing app settings
struct SettingsView: View {
    // MARK: - Environment
    
    @EnvironmentObject private var vm: DashboardViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var polygonApiKey: String = ""
    @State private var binanceApiKey: String = ""
    @State private var binanceSecretKey: String = ""
    @State private var storageTypeSelection: QuoteStoreType = .memory
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedTheme: ThemeMode = .system
    
    // MARK: - User defaults
    
    @AppStorage(AppConfig.storageTypeKey) private var storageTypePreference: String = "memory"
    
    // MARK: - Init
    
    init() {
        // Get current storage type from preferences
        let keychainManager = KeychainManager(service: "com.financialdashboard")
        
        // Load saved API keys if available (just to show that they exist)
        if let key = keychainManager.retrievePolygonApiKey() {
            _polygonApiKey = State(initialValue: "••••••••" + String(key.suffix(4)))
        }
        
        if let key = keychainManager.retrieveBinanceApiKey() {
            _binanceApiKey = State(initialValue: "••••••••" + String(key.suffix(4)))
        }
        
        if let key = keychainManager.retrieveBinanceSecretKey() {
            _binanceSecretKey = State(initialValue: "••••••••" + String(key.suffix(4)))
        }
        
        // Set initial storage type selection
        switch storageTypePreference {
        case "coreData":
            _storageTypeSelection = State(initialValue: .coreData)
        case "sqlite":
            _storageTypeSelection = State(initialValue: .sqlite)
        default:
            _storageTypeSelection = State(initialValue: .memory)
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - API Keys Section
                Section(header: Text("API Keys")) {
                    VStack(alignment: .leading) {
                        Text("Polygon.io API Key")
                            .font(.headline)
                            .padding(.bottom, 2)
                        
                        SecureField("Enter API Key", text: $polygonApiKey)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading) {
                        Text("Binance API Key")
                            .font(.headline)
                            .padding(.bottom, 2)
                        
                        SecureField("Enter API Key", text: $binanceApiKey)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading) {
                        Text("Binance Secret Key")
                            .font(.headline)
                            .padding(.bottom, 2)
                        
                        SecureField("Enter Secret Key", text: $binanceSecretKey)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    .padding(.vertical, 4)
                    
                    Button("Save API Keys") {
                        saveApiKeys()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                }
                
                // MARK: - Theme Section
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $selectedTheme) {
                        ForEach(ThemeMode.allCases, id: \.self) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedTheme) { newValue in
                        themeManager.setTheme(newValue)
                    }
                    
                    HStack {
                        Text("Current Theme")
                        Spacer()
                        Text(selectedTheme.rawValue)
                            .foregroundStyle(.secondary)
                    }
                }
                .onAppear {
                    selectedTheme = themeManager.themeMode
                }
                
                // MARK: - Storage Section
                Section(header: Text("Data Storage")) {
                    Picker("Storage Type", selection: $storageTypeSelection) {
                        Text("In-Memory").tag(QuoteStoreType.memory)
                        Text("Core Data").tag(QuoteStoreType.coreData)
                        Text("SQLite").tag(QuoteStoreType.sqlite)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: storageTypeSelection) { _ in
                        saveStoragePreference()
                    }
                    
                    HStack {
                        Text("Current Storage")
                        Spacer()
                        Text(storageTypeDescription)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // MARK: - Info Section
                Section(header: Text("About"), footer: Text("Changing storage type requires a restart.")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert(alertMessage, isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Description of the selected storage type
    private var storageTypeDescription: String {
        switch storageTypeSelection {
        case .memory:
            return "Volatile (In-Memory)"
        case .coreData:
            return "Persistent (Core Data)"
        case .sqlite:
            return "Persistent (SQLite)"
        }
    }
    
    // MARK: - Private Methods
    
    /// Save API keys to keychain
    private func saveApiKeys() {
        // Don't update if keys are masked (unchanged)
        let polygonKeyChanged = !polygonApiKey.isEmpty && !polygonApiKey.hasPrefix("••••••••")
        let binanceKeyChanged = !binanceApiKey.isEmpty && !binanceApiKey.hasPrefix("••••••••")
        let binanceSecretChanged = !binanceSecretKey.isEmpty && !binanceSecretKey.hasPrefix("••••••••")
        
        // Update the keys in the view model
        vm.saveApiCredentials(
            polygonApiKey: polygonKeyChanged ? polygonApiKey : nil,
            binanceApiKey: binanceKeyChanged ? binanceApiKey : nil,
            binanceSecretKey: binanceSecretChanged ? binanceSecretKey : nil
        )
        
        // Show alert
        alertMessage = "API keys saved successfully."
        showingAlert = true
        
        // Mask the keys
        if polygonKeyChanged {
            polygonApiKey = "••••••••" + String(polygonApiKey.suffix(4))
        }
        
        if binanceKeyChanged {
            binanceApiKey = "••••••••" + String(binanceApiKey.suffix(4))
        }
        
        if binanceSecretChanged {
            binanceSecretKey = "••••••••" + String(binanceSecretKey.suffix(4))
        }
    }
    
    /// Save storage preference to UserDefaults
    private func saveStoragePreference() {
        // Save to user defaults
        switch storageTypeSelection {
        case .memory:
            storageTypePreference = "memory"
        case .coreData:
            storageTypePreference = "coreData"
        case .sqlite:
            storageTypePreference = "sqlite"
        }
        
        // Show alert about restart
        alertMessage = "Storage preference saved. Changes will take effect after restarting the app."
        showingAlert = true
    }
} 