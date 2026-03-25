//
//  WageTickApp.swift
//  WageTick
//
//  Created by Dan Morgan on 11/03/2026.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct WageTickApp: App {

    var sharedModelContainer: ModelContainer = .shared
    @AppStorage("hasSeenDepartmentOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false
    @State private var storeManager = StoreManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(storeManager)
                .onAppear {
                    RecurringShiftGenerator.extendIfNeeded(
                        context: sharedModelContainer.mainContext
                    )
                    if !hasSeenOnboarding {
                        showOnboarding = true
                    }
                }
                .sheet(isPresented: $showOnboarding) {
                    DepartmentOnboardingView(isPresented: $showOnboarding)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Department Onboarding

struct DepartmentOnboardingView: View {
    @Binding var isPresented: Bool
    @State private var navigateToDepartments = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header icon
                ZStack {
                    Circle()
                        .fill(.tint.opacity(0.12))
                        .frame(width: 90, height: 90)
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 38, weight: .medium))
                        .foregroundStyle(.tint)
                }
                .padding(.top, 48)
                .padding(.bottom, 20)

                // Title
                Text("Department Splits")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 36)

                // Feature bullets
                VStack(spacing: 0) {
                    FeatureBullet(
                        icon: "scissors",
                        color: .blue,
                        title: "Split any shift",
                        description: "Divide a shift across multiple departments, each with its own hourly rate."
                    )
                    Divider()
                    FeatureBullet(
                        icon: "exclamationmark.triangle.fill",
                        color: .orange,
                        title: "Helpful reminders",
                        description: "We'll badge upcoming recurring shifts and notify you 2 hours early when departments haven't been set."
                    )
                    Divider()
                    FeatureBullet(
                        icon: "chart.bar.fill",
                        color: .green,
                        title: "Earnings by department",
                        description: "Your Stats page breaks down total hours and pay per department across all completed shifts."
                    )
                }
                .background(.secondary.opacity(0.07), in: .rect(cornerRadius: 16))
                .padding(.horizontal)

                Spacer()

                // Actions
                VStack(spacing: 12) {
                        Button {
                            navigateToDepartments = true
                        } label: {
                            Text("Set Up Departments")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal)

                        Button {
                            dismiss()
                        } label: {
                            Text("Not Now")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 32)
            }
            .navigationDestination(isPresented: $navigateToDepartments) {
                DepartmentsView(showDoneButton: true)
                    .onDisappear { dismiss() }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func dismiss() {
        UserDefaults.standard.set(true, forKey: "hasSeenDepartmentOnboarding")
        isPresented = false
    }
}

#Preview {
    DepartmentOnboardingView(isPresented: .constant(true))
}

private struct FeatureBullet: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
}
