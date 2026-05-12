import Foundation
import StoreKit

enum SubscriptionProductId {
    static let weekly = "portfolio.showcase.weekly"
    static let yearly = "portfolio.showcase.yearly"
}

struct SubscriptionProductInfo {
    let productId: String
    let title: String
    let price: String
    let badge: String?
    let isTrial: Bool
}

@MainActor
final class SubscriptionStore: NSObject {

    static let subscriptionDisabledForDevelopment = true

    static let shared: SubscriptionStore = {
        let store = SubscriptionStore()
        return store
    }()

    private static let subscriptionProductIds: Set<String> = [SubscriptionProductId.weekly, SubscriptionProductId.yearly]

    private var storeKit2Products: [Any] = []
    private var sk1Products: [SKProduct] = []

    private var loadCompletion: (([SKProduct]) -> Void)?
    private var purchaseCompletion: ((Bool) -> Void)?
    private var restoreCompletion: ((Bool) -> Void)?

    private var productsLoaded = false
    private var transactionUpdatesTask: Task<Void, Never>?

    private(set) var purchasedProductIDs = Set<String>()

    private static let hasActiveSubscriptionKey = "subscription_store_has_active"
    private static let subscriptionPurchasedWithoutTrialKey = "subscription_purchased_without_trial"

    var hasActiveSubscription: Bool {
        get {
            if Self.subscriptionDisabledForDevelopment { return true }
            if #available(iOS 15.0, *) {
                return !purchasedProductIDs.isEmpty
            }
            return UserDefaults.standard.bool(forKey: Self.hasActiveSubscriptionKey)
        }
        set {
            guard !Self.subscriptionDisabledForDevelopment else { return }
            if #available(iOS 15.0, *) {
                return
            }
            UserDefaults.standard.set(newValue, forKey: Self.hasActiveSubscriptionKey)
        }
    }

    var hasActiveSubscriptionWithoutTrial: Bool {
        guard hasActiveSubscription else { return false }
        return UserDefaults.standard.bool(forKey: Self.subscriptionPurchasedWithoutTrialKey)
    }

    func setSubscriptionPurchasedWithoutTrial(_ withoutTrial: Bool) {
        UserDefaults.standard.set(withoutTrial, forKey: Self.subscriptionPurchasedWithoutTrialKey)
    }

    private override init() {
        super.init()
        if #available(iOS 15.0, *) {
            transactionUpdatesTask = observeTransactionUpdates()
        }
        SKPaymentQueue.default().add(self)
    }

    deinit {
        transactionUpdatesTask?.cancel()
        SKPaymentQueue.default().remove(self)
    }

    func checkSubscriptionStatus(completion: @escaping (Bool) -> Void) {
        if Self.subscriptionDisabledForDevelopment {
            completion(true)
            return
        }
        if #available(iOS 15.0, *) {
            Task {
                await updatePurchasedProducts()
                completion(hasActiveSubscription)
            }
            return
        }
        let transactions = SKPaymentQueue.default().transactions
        var hasValid = false
        for transaction in transactions {
            if transaction.transactionState == .purchased || transaction.transactionState == .restored {
                if Self.subscriptionProductIds.contains(transaction.payment.productIdentifier) {
                    hasValid = true
                    break
                }
            }
        }
        if hasValid {
            hasActiveSubscription = true
        }
        completion(hasActiveSubscription)
    }

    func loadProducts(completion: @escaping ([SubscriptionProductInfo]) -> Void) {
        if Self.subscriptionDisabledForDevelopment {
            completion([])
            return
        }
        if #available(iOS 15.0, *) {
            Task {
                await loadProductsStoreKit2(completion: completion)
            }
            return
        }
        let request = SKProductsRequest(productIdentifiers: Self.subscriptionProductIds)
        loadCompletion = { [weak self] prods in
            self?.sk1Products = prods
            let infos = prods.map { product -> SubscriptionProductInfo in
                let badge: String? = product.productIdentifier == SubscriptionProductId.yearly ? AppStrings.theBestOffer : nil
                return SubscriptionProductInfo(
                    productId: product.productIdentifier,
                    title: product.productIdentifier == SubscriptionProductId.yearly ? AppStrings.yearly : AppStrings.weekly,
                    price: product.localizedPrice(),
                    badge: badge,
                    isTrial: false
                )
            }
            DispatchQueue.main.async { completion(infos) }
        }
        request.delegate = self
        request.start()
    }

    func purchase(productId: String, completion: @escaping (Bool) -> Void) {
        if Self.subscriptionDisabledForDevelopment {
            hasActiveSubscription = true
            DispatchQueue.main.async { completion(true) }
            return
        }
        if #available(iOS 15.0, *) {
            Task {
                let success = await performPurchase(productId: productId)
                completion(success)
            }
            return
        }
        guard let product = sk1Products.first(where: { $0.productIdentifier == productId }) else {
            DispatchQueue.main.async { completion(false) }
            return
        }
        purchaseCompletion = completion
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }

    func restorePurchases(completion: @escaping (Bool) -> Void) {
        if Self.subscriptionDisabledForDevelopment {
            hasActiveSubscription = true
            DispatchQueue.main.async { completion(true) }
            return
        }
        if #available(iOS 15.0, *) {
            Task {
                do {
                    try await AppStore.sync()
                    await updatePurchasedProducts()
                    completion(hasActiveSubscription)
                } catch {
                    await updatePurchasedProducts()
                    completion(hasActiveSubscription)
                }
            }
            return
        }
        restoreCompletion = completion
        SKPaymentQueue.default().restoreCompletedTransactions()
    }

    @available(iOS 15.0, *)
    private func loadProductsStoreKit2(completion: @escaping ([SubscriptionProductInfo]) -> Void) async {
        do {
            let products = try await Product.products(for: Array(Self.subscriptionProductIds))
            self.storeKit2Products = products
            self.productsLoaded = true
            let infos = products.map { self.subscriptionProductInfo(from: $0) }
            completion(infos)
        } catch {
            self.storeKit2Products = []
            completion(self.fallbackProductInfos())
        }
    }

    @available(iOS 15.0, *)
    private func updatePurchasedProducts() async {
        var ids = Set<String>()
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard Self.subscriptionProductIds.contains(transaction.productID) else { continue }
            if transaction.revocationDate == nil {
                ids.insert(transaction.productID)
            }
        }
        purchasedProductIDs = ids
        UserDefaults.standard.set(!ids.isEmpty, forKey: Self.hasActiveSubscriptionKey)
    }

    @available(iOS 15.0, *)
    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            guard let self = self else { return }
            for await _ in Transaction.updates {
                await self.updatePurchasedProducts()
            }
        }
    }

    @available(iOS 15.0, *)
    private func performPurchase(productId: String) async -> Bool {
        let products = storeKit2Products.compactMap { $0 as? Product }
        guard let product = products.first(where: { $0.id == productId }) else { return false }
        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await updatePurchasedProducts()
                    return hasActiveSubscription
                case .unverified:
                    return false
                }
            case .userCancelled:
                return false
            case .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    @available(iOS 15.0, *)
    private func subscriptionProductInfo(from product: Product) -> SubscriptionProductInfo {
        let title = product.id == SubscriptionProductId.yearly ? AppStrings.yearly : AppStrings.weekly
        let badge: String? = product.id == SubscriptionProductId.yearly ? AppStrings.theBestOffer : nil
        return SubscriptionProductInfo(
            productId: product.id,
            title: title,
            price: product.displayPrice,
            badge: badge,
            isTrial: false
        )
    }

    @available(iOS 15.0, *)
    private func fallbackProductInfos() -> [SubscriptionProductInfo] {
        [
            SubscriptionProductInfo(productId: SubscriptionProductId.yearly, title: AppStrings.yearly, price: AppStrings.defaultYearlyPrice, badge: AppStrings.theBestOffer, isTrial: false),
            SubscriptionProductInfo(productId: SubscriptionProductId.weekly, title: AppStrings.weekly, price: AppStrings.defaultWeeklyPrice, badge: nil, isTrial: false)
        ]
    }

    private func finishPurchase(success: Bool) {
        if success { hasActiveSubscription = true }
        purchaseCompletion?(success)
        purchaseCompletion = nil
    }

    private func finishRestore(success: Bool) {
        if success { hasActiveSubscription = true }
        restoreCompletion?(success)
        restoreCompletion = nil
    }
}

extension SubscriptionStore: SKProductsRequestDelegate {
    nonisolated func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        Task { @MainActor in
            loadCompletion?(response.products)
            loadCompletion = nil
        }
    }

    nonisolated func request(_ request: SKRequest, didFailWithError error: Error) {
        Task { @MainActor in
            loadCompletion?([])
            loadCompletion = nil
        }
    }
}

extension SubscriptionStore: SKPaymentTransactionObserver {
    nonisolated func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        Task { @MainActor in
            self.applyUpdatedTransactions(transactions, on: queue)
        }
    }

    nonisolated func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        Task { @MainActor in
            if #available(iOS 15.0, *) {
                await updatePurchasedProducts()
            }
            finishRestore(success: hasActiveSubscription)
        }
    }

    nonisolated func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        Task { @MainActor in
            finishRestore(success: false)
        }
    }

    nonisolated func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {
        return true
    }

    private func applyUpdatedTransactions(_ transactions: [SKPaymentTransaction], on queue: SKPaymentQueue) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                if SubscriptionStore.subscriptionProductIds.contains(transaction.payment.productIdentifier) {
                    hasActiveSubscription = true
                    finishPurchase(success: true)
                }
                queue.finishTransaction(transaction)
            case .restored:
                if SubscriptionStore.subscriptionProductIds.contains(transaction.payment.productIdentifier) {
                    hasActiveSubscription = true
                }
                queue.finishTransaction(transaction)
            case .failed:
                finishPurchase(success: false)
                queue.finishTransaction(transaction)
            case .deferred, .purchasing:
                break
            @unknown default:
                break
            }
        }
    }
}

private extension SKProduct {
    func localizedPrice() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = priceLocale
        return formatter.string(from: price) ?? "\(price)"
    }
}
