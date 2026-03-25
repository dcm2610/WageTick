//
//  StoreManager.swift
//  WageTick
//

import StoreKit
import SwiftUI

@Observable
final class StoreManager {

    static let productID = "com.danielmorgan.WageTick.unlock"
    private static let unlockedKey = "premiumUnlocked"

    var isUnlocked: Bool = UserDefaults.standard.bool(forKey: unlockedKey)
    var isPurchasing = false
    var errorMessage: String?

    private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Purchase

    func purchase() async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            let products = try await Product.products(for: [Self.productID])
            guard let product = products.first else {
                errorMessage = "Product not available. Please try again later."
                return
            }
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await unlock()
                await transaction.finish()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Restore

    func restore() async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            for await result in Transaction.currentEntitlements {
                if let transaction = try? checkVerified(result),
                   transaction.productID == Self.productID {
                    await unlock()
                    await transaction.finish()
                }
            }
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    #if DEBUG
    func debugUnlock() {
        isUnlocked = true
        UserDefaults.standard.set(true, forKey: Self.unlockedKey)
    }
    #endif

    private func unlock() async {
        await MainActor.run {
            isUnlocked = true
            UserDefaults.standard.set(true, forKey: Self.unlockedKey)
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if let transaction = try? self.checkVerified(result),
                   transaction.productID == Self.productID {
                    await self.unlock()
                    await transaction.finish()
                }
            }
        }
    }
}
