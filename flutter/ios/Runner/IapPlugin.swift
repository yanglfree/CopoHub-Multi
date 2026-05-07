import Flutter
import StoreKit

private let channelName = "com.youdroid/iap"

// ── Product ID mapping ─────────────────────────────────────────────────────────

private enum PlanType: String {
    case monthly, yearly, lifetime
}

private let productIds: [String] = [
    "com.youdroid.copohub.promonthly",
    "com.youdroid.copohub.proyearly",
    "com.youdroid.copohub.prolifetime",
]

private func planType(for productId: String) -> PlanType? {
    switch productId {
    case "com.youdroid.copohub.promonthly": return .monthly
    case "com.youdroid.copohub.proyearly": return .yearly
    case "com.youdroid.copohub.prolifetime": return .lifetime
    default: return nil
    }
}

// ── IapPlugin ──────────────────────────────────────────────────────────────────

@objc class IapPlugin: NSObject, FlutterPlugin {

    private var channel: FlutterMethodChannel?
    // Pending results for in-flight calls.
    private var pendingQueryResult: FlutterResult?
    private var pendingPurchaseResult: FlutterResult?
    private var pendingRestoreResult: FlutterResult?
    private var restoredTransactions: [[String: Any]] = []

    // MARK: – Registration

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = IapPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        instance.channel = channel
        SKPaymentQueue.default().add(instance)
    }

    // MARK: – FlutterPlugin

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "queryProducts":
            queryProducts(call: call, result: result)
        case "createPurchase":
            createPurchase(call: call, result: result)
        case "queryOwnedPurchases":
            restorePurchases(result: result)
        case "finishPurchase":
            // iOS StoreKit 1 finishes transactions automatically in the observer.
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: – queryProducts

    private func queryProducts(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard pendingQueryResult == nil else {
            result(FlutterError(code: "ALREADY_IN_PROGRESS", message: "Query already in progress", details: nil))
            return
        }
        let args = call.arguments as? [String: Any]
        let ids = (args?["productIds"] as? [String]) ?? productIds
        pendingQueryResult = result
        let request = SKProductsRequest(productIdentifiers: Set(ids))
        request.delegate = self
        request.start()
    }

    // MARK: – createPurchase

    private func createPurchase(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard SKPaymentQueue.canMakePayments() else {
            result(FlutterError(code: "PAYMENTS_DISABLED", message: "In-app purchases are disabled on this device", details: nil))
            return
        }
        guard pendingPurchaseResult == nil else {
            result(FlutterError(code: "ALREADY_IN_PROGRESS", message: "Purchase already in progress", details: nil))
            return
        }
        let args = call.arguments as? [String: Any]
        guard let productId = args?["productId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "productId is required", details: nil))
            return
        }

        pendingPurchaseResult = result

        // Fetch product then enqueue payment.
        let request = SKProductsRequest(productIdentifiers: [productId])
        request.delegate = self
        request.start()
        // Tag request so delegate knows it's for purchase, not query.
        objc_setAssociatedObject(request, &AssocKey.purchaseProductId, productId, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    // MARK: – restorePurchases

    private func restorePurchases(result: @escaping FlutterResult) {
        guard pendingRestoreResult == nil else {
            result(FlutterError(code: "ALREADY_IN_PROGRESS", message: "Restore already in progress", details: nil))
            return
        }
        pendingRestoreResult = result
        restoredTransactions = []
        SKPaymentQueue.default().restoreCompletedTransactions()
    }

    // MARK: – Helpers

    private func priceString(from product: SKProduct) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        return formatter.string(from: product.price) ?? "\(product.price)"
    }

    private func expiryMs(for planType: PlanType) -> Int {
        var date = Date()
        switch planType {
        case .monthly:
            date = Calendar.current.date(byAdding: .month, value: 1, to: date) ?? date
        case .yearly:
            date = Calendar.current.date(byAdding: .year, value: 1, to: date) ?? date
        case .lifetime:
            return 0
        }
        return Int(date.timeIntervalSince1970 * 1000)
    }
}

// ── Association key for purchase product ID ────────────────────────────────────

private enum AssocKey {
    static var purchaseProductId = "purchaseProductId"
}

// ── SKProductsRequestDelegate ──────────────────────────────────────────────────

extension IapPlugin: SKProductsRequestDelegate {

    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        let purchaseId = objc_getAssociatedObject(request, &AssocKey.purchaseProductId) as? String

        if let productId = purchaseId {
            // This was a purchase-intent request.
            guard let product = response.products.first(where: { $0.productIdentifier == productId }) else {
                let result = pendingPurchaseResult
                pendingPurchaseResult = nil
                result?(FlutterError(code: "PRODUCT_NOT_FOUND", message: "Product \(productId) not found in store", details: nil))
                return
            }
            let payment = SKPayment(product: product)
            SKPaymentQueue.default().add(payment)
        } else {
            // This was a queryProducts request.
            let result = pendingQueryResult
            pendingQueryResult = nil
            let items: [[String: Any]] = response.products.map { product in
                [
                    "id": product.productIdentifier,
                    "localPrice": priceString(from: product),
                    "originalLocalPrice": priceString(from: product),
                ]
            }
            result?(items)
        }
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        if let result = pendingQueryResult {
            pendingQueryResult = nil
            result(FlutterError(code: "QUERY_FAILED", message: error.localizedDescription, details: nil))
        } else if let result = pendingPurchaseResult {
            pendingPurchaseResult = nil
            result(FlutterError(code: "PURCHASE_FAILED", message: error.localizedDescription, details: nil))
        }
    }
}

// ── SKPaymentTransactionObserver ───────────────────────────────────────────────

extension IapPlugin: SKPaymentTransactionObserver {

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased, .restored:
                handleSuccessfulTransaction(transaction)
            case .failed:
                handleFailedTransaction(transaction)
            case .deferred, .purchasing:
                break
            @unknown default:
                break
            }
        }
    }

    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        let result = pendingRestoreResult
        pendingRestoreResult = nil
        result?(restoredTransactions)
    }

    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        let result = pendingRestoreResult
        pendingRestoreResult = nil
        result?(FlutterError(code: "RESTORE_FAILED", message: error.localizedDescription, details: nil))
    }

    private func handleSuccessfulTransaction(_ transaction: SKPaymentTransaction) {
        let productId = transaction.payment.productIdentifier
        let plan = planType(for: productId) ?? .lifetime

        SKPaymentQueue.default().finishTransaction(transaction)

        if transaction.transactionState == .restored {
            // Collect restored purchases; respond after restoreCompleted fires.
            restoredTransactions.append([
                "productId": productId,
                "planType": plan.rawValue,
                "expiryMs": expiryMs(for: plan),
            ])
        } else {
            // New purchase — respond immediately.
            let result = pendingPurchaseResult
            pendingPurchaseResult = nil
            result?([
                "planType": plan.rawValue,
                "expiryMs": expiryMs(for: plan),
                "purchaseToken": "",
                "purchaseOrderId": "",
            ])
        }
    }

    private func handleFailedTransaction(_ transaction: SKPaymentTransaction) {
        SKPaymentQueue.default().finishTransaction(transaction)
        let error = transaction.error as? SKError
        let result = pendingPurchaseResult
        pendingPurchaseResult = nil

        if error?.code == .paymentCancelled {
            result?(FlutterError(code: "USER_CANCELLED", message: "Purchase was cancelled", details: nil))
        } else {
            result?(FlutterError(
                code: "PURCHASE_FAILED",
                message: error?.localizedDescription ?? "Purchase failed",
                details: nil
            ))
        }
    }
}
