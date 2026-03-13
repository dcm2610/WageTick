//
//  DepartmentsView.swift
//  WageTick
//

import SwiftUI
import SwiftData

struct DepartmentsView: View {
    var showDoneButton: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Department.name) private var departments: [Department]
    @State private var showAddSheet = false
    @State private var editingDepartment: Department?

    var body: some View {
        List {
            if departments.isEmpty {
                ContentUnavailableView(
                    "No Departments",
                    systemImage: "building.2",
                    description: Text("Add departments to split shifts across different pay rates.")
                )
            } else {
                ForEach(departments) { dept in
                    Button {
                        editingDepartment = dept
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dept.name)
                                    .foregroundStyle(.primary)
                                Text("£\(String(format: "%.2f", NSDecimalNumber(decimal: dept.hourlyRate).doubleValue))/hr")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            HStack(spacing: 6) {
                                if dept.isBaseRate {
                                    Text("Base rate")
                                        .font(.caption2)
                                        .foregroundStyle(.tint)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(.tint.opacity(0.12), in: .capsule)
                                }
                                if !dept.isActive {
                                    Text("Inactive")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(.secondary.opacity(0.15), in: .capsule)
                                }
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            modelContext.delete(dept)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Departments")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    if showDoneButton && !departments.isEmpty {
                        Button("Done") { dismiss() }
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            DepartmentFormView(department: nil)
        }
        .sheet(item: $editingDepartment) { dept in
            DepartmentFormView(department: dept)
        }
    }
}

struct DepartmentFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Department.name) private var allDepartments: [Department]

    /// nil = creating a new department; non-nil = editing existing.
    let department: Department?

    @State private var name: String = ""
    @State private var hourlyRate: Decimal = 15
    @State private var isActive: Bool = true
    @State private var isBaseRate: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Department Name") {
                    TextField("e.g. Warehouse", text: $name)
                }

                Section("Hourly Rate") {
                    HStack(spacing: 4) {
                        Text("£").foregroundStyle(.secondary)
                        TextField("0.00", value: $hourlyRate, format: .number)
                            .keyboardType(.decimalPad)
                    }
                }

                Section {
                    Toggle("Base rate", isOn: $isBaseRate)
                } footer: {
                    Text("Mark this as your default department. Its rate will be used as the base hourly wage on new shifts. Only one department can be the base rate at a time.")
                }

                Section {
                    Toggle("Active", isOn: $isActive)
                } footer: {
                    Text("Inactive departments won't appear when creating new shifts.")
                }
            }
            .navigationTitle(department == nil ? "New Department" : "Edit Department")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(department == nil ? "Add" : "Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let dept = department {
                    name = dept.name
                    hourlyRate = dept.hourlyRate
                    isActive = dept.isActive
                    isBaseRate = dept.isBaseRate
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        // If marking as base rate, clear it from any other department first
        if isBaseRate {
            for dept in allDepartments where dept !== department {
                dept.isBaseRate = false
            }
        }

        if let dept = department {
            dept.name = trimmedName
            dept.hourlyRate = hourlyRate
            dept.isActive = isActive
            dept.isBaseRate = isBaseRate
        } else {
            let newDept = Department(name: trimmedName, hourlyRate: hourlyRate, isActive: isActive, isBaseRate: isBaseRate)
            modelContext.insert(newDept)
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        DepartmentsView()
    }
    .modelContainer(for: Department.self, inMemory: true)
}
