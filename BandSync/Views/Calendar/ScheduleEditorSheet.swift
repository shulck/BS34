//
//  ScheduleEditorSheet.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 02.04.2025.
//
import SwiftUI

struct ScheduleEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var schedule: [String]?
    @State private var workingSchedule: [String] = []
    @State private var newItem = ""
    @State private var isEditMode: EditMode = .inactive

    var body: some View {
        NavigationView {
            scheduleContent
                .navigationTitle("Daily Schedule")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(
                    leading: Button("Cancel") { dismiss() },
                    trailing: Button("Save") {
                        schedule = workingSchedule.isEmpty ? nil : workingSchedule
                        dismiss()
                    }
                )
                .environment(\.editMode, $isEditMode)
                .onAppear {
                    if let existingSchedule = schedule {
                        workingSchedule = existingSchedule
                    }
                }
        }
    }

    private var scheduleContent: some View {
        VStack {
            // Field for adding a new item
            HStack {
                TextField("New schedule item", text: $newItem)
                    .textFieldStyle(.roundedBorder)

                Button(action: {
                    if !newItem.isEmpty {
                        withAnimation {
                            workingSchedule.append(newItem)
                            newItem = ""
                        }
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()

            // List of existing items
            scheduleList

            // Format hint
            formatHint
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button(action: {
                    isEditMode = (isEditMode == .active) ? .inactive : .active
                }) {
                    Text(isEditMode == .active ? "Done" : "Edit")
                }
            }
        }
    }

    private var scheduleList: some View {
        List {
            ForEach(workingSchedule.indices, id: \.self) { index in
                scheduleRow(for: index)
            }
            .onMove { source, destination in
                workingSchedule.move(fromOffsets: source, toOffset: destination)
            }
            .onDelete { indexSet in
                workingSchedule.remove(atOffsets: indexSet)
            }
        }
    }

    private func scheduleRow(for index: Int) -> some View {
        HStack {
            // Time and event description
            if workingSchedule[index].contains(" - ") {
                let components = workingSchedule[index].split(separator: " - ", maxSplits: 1)
                if components.count == 2 {
                    Text(String(components[0]))
                        .bold()
                        .frame(width: 70, alignment: .leading)

                    Text(String(components[1]))
                }
            } else {
                Text(workingSchedule[index])
            }

            Spacer()

            // Delete button shown only when not in edit mode
            if isEditMode == .inactive {
                Button(action: {
                    withAnimation {
                        // Explicitly specify array type before method call
                        // to avoid ambiguity
                        workingSchedule.removeAll(where: { $0 == workingSchedule[index] })
                        // Alternative:
                        // let indexToRemove = index
                        // workingSchedule.remove(at: indexToRemove)
                    }
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
    }

    private var formatHint: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tip: for time indication use format")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("«10:00 - Event description»")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
        .padding()
    }
}
