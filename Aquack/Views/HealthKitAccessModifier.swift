//
//  HealthKitAccessModifier.swift
//  Asks for permission to get access to Health
//  Aquack
//

import HealthKitUI
import SwiftUI

/// Attach to the screen with the Connect button; increment `trigger` on tap.
struct HealthKitAccessModifier: ViewModifier {
    @Binding var trigger: Int
    let onFinished: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 17.4, *) {
            content
                .healthDataAccessRequest(
                    store: HealthManager.shared.store,
                    shareTypes: [],
                    readTypes: HealthManager.readTypes,
                    trigger: trigger
                ) { _ in
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        onFinished()
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    func healthKitAccessOnTrigger(_ trigger: Binding<Int>, onFinished: @escaping () -> Void) -> some View {
        modifier(HealthKitAccessModifier(trigger: trigger, onFinished: onFinished))
    }
}
