import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos';
import MethodChannel, {
  MethodCallHandler,
  MethodResult,
} from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import { iap } from '@kit.IAPKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import util from '@ohos.util';

const CHANNEL_NAME = 'com.youdroid/iap';

const MONTHLY_PRODUCT_ID = 'com.youdroid.copo_promonthly';
const YEARLY_PRODUCT_ID = 'com.youdroid.copo_proyearly';
const LIFETIME_PRODUCT_ID = 'com.youdroid.copo_prolifetime';

type ProPlanType = 'monthly' | 'yearly' | 'lifetime' | '';

interface PurchaseResult {
  planType: ProPlanType;
  expiryMs: number;
  purchaseToken: string;
  purchaseOrderId: string;
}

interface OwnedPurchase {
  productId: string;
  planType: ProPlanType;
  expiryMs: number;
}

interface SubscriptionInfo {
  planType: ProPlanType;
  expiryMs: number;
}

export class IapPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private context: common.UIAbilityContext | null = null;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  getUniqueClassName(): string {
    return 'IapPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'queryProducts':
        this.queryProducts(call, result);
        break;
      case 'createPurchase':
        this.createPurchase(call, result);
        break;
      case 'queryOwnedPurchases':
        this.queryOwnedPurchases(result);
        break;
      case 'finishPurchase':
        this.finishPurchase(call, result);
        break;
      default:
        result.notImplemented();
    }
  }

  // ── queryProducts ────────────────────────────────────────────────────────────

  private async queryProducts(call: MethodCall, result: MethodResult): Promise<void> {
    const context = this.context;
    if (!context) {
      result.error('NO_CONTEXT', 'Context is not available', null);
      return;
    }

    try {
      const productIds = (call.argument('productIds') as string[] | null) || [
        MONTHLY_PRODUCT_ID,
        YEARLY_PRODUCT_ID,
        LIFETIME_PRODUCT_ID,
      ];

      const subscriptionIds = productIds.filter(id => id !== LIFETIME_PRODUCT_ID);
      const nonConsumIds = productIds.filter(id => id === LIFETIME_PRODUCT_ID);

      const snapshots: Record<string, Object>[] = [];

      if (subscriptionIds.length > 0) {
        try {
          const params: iap.QueryProductsParameter = {
            productType: iap.ProductType.AUTORENEWABLE,
            productIds: subscriptionIds,
          };
          const products = await iap.queryProducts(context, params);
          for (let i = 0; i < products.length; i++) {
            snapshots.push(this.productSnapshot(products[i]));
          }
        } catch (e) {
          console.warn('[IapPlugin] queryProducts subscription failed:', e);
        }
      }

      if (nonConsumIds.length > 0) {
        try {
          const params: iap.QueryProductsParameter = {
            productType: iap.ProductType.NONCONSUMABLE,
            productIds: nonConsumIds,
          };
          const products = await iap.queryProducts(context, params);
          for (let i = 0; i < products.length; i++) {
            snapshots.push(this.productSnapshot(products[i]));
          }
        } catch (e) {
          console.warn('[IapPlugin] queryProducts nonconsumable failed:', e);
        }
      }

      result.success(snapshots);
    } catch (error) {
      const err = error as BusinessError;
      result.error(`${err.code}`, err.message, null);
    }
  }

  // ── createPurchase ───────────────────────────────────────────────────────────

  private async createPurchase(call: MethodCall, result: MethodResult): Promise<void> {
    const context = this.context;
    if (!context) {
      result.error('NO_CONTEXT', 'Context is not available', null);
      return;
    }

    try {
      const productId = call.argument('productId') as string;
      const productTypeStr = call.argument('productType') as string;
      const productType = productTypeStr === 'nonconsumable'
        ? iap.ProductType.NONCONSUMABLE
        : iap.ProductType.AUTORENEWABLE;
      const planType = this.planTypeForProductId(productId);

      const purchaseParam: iap.PurchaseParameter = {
        productType,
        productId,
      };

      const purchaseResult = await iap.createPurchase(context, purchaseParam);

      let purchaseToken = '';
      let purchaseOrderId = '';
      let expiryMs = 0;

      if (productType === iap.ProductType.NONCONSUMABLE) {
        const purchaseData = JSON.parse(purchaseResult.purchaseData) as Record<string, Object>;
        const jwsPurchaseOrder = (purchaseData['jwsPurchaseOrder'] as string) || '';
        if (jwsPurchaseOrder) {
          const payload = this.decodeJWSPayload(jwsPurchaseOrder);
          purchaseToken = (payload['purchaseToken'] as string) || '';
          purchaseOrderId = (payload['purchaseOrderId'] as string) || '';
        }
      } else {
        const parsed = this.parseSubscriptionInfo(purchaseResult.purchaseData, planType);
        expiryMs = parsed.expiryMs > 0 ? parsed.expiryMs : this.estimateExpiry(planType);

        const purchaseData2 = JSON.parse(purchaseResult.purchaseData) as Record<string, Object>;
        const jws = (purchaseData2['jwsSubscriptionStatus'] as string) || '';
        if (jws) {
          const p = this.decodeJWSPayload(jws);
          purchaseToken = (p['purchaseToken'] as string) || '';
          purchaseOrderId = (p['purchaseOrderId'] as string) || '';
          const lastStatus = p['lastSubscriptionStatus'] as Record<string, Object>;
          if (lastStatus) {
            const lastOrder = lastStatus['lastPurchaseOrder'] as Record<string, Object>;
            if (lastOrder) {
              if (!purchaseToken) { purchaseToken = (lastOrder['purchaseToken'] as string) || ''; }
              if (!purchaseOrderId) { purchaseOrderId = (lastOrder['purchaseOrderId'] as string) || ''; }
            }
          }
        }
      }

      const purchaseRes: PurchaseResult = {
        planType,
        expiryMs,
        purchaseToken,
        purchaseOrderId,
      };
      result.success(purchaseRes as Object);
    } catch (error) {
      const err = error as BusinessError;
      if (err.code === iap.IAPErrorCode.PRODUCT_OWNED) {
        // Already owned — query for real expiry and return success.
        await this.handleAlreadyOwned(call, result);
      } else {
        result.error(`${err.code}`, err.message, null);
      }
    }
  }

  private async handleAlreadyOwned(call: MethodCall, result: MethodResult): Promise<void> {
    const context = this.context!;
    const productId = call.argument('productId') as string;
    const planType = this.planTypeForProductId(productId);

    let expiryMs = 0;
    try {
      const queryParam: iap.QueryPurchasesParameter = {
        productType: iap.ProductType.AUTORENEWABLE,
      };
      const queryResult = await iap.queryPurchases(context, queryParam);
      if (queryResult.purchaseDataList && queryResult.purchaseDataList.length > 0) {
        const parsed = this.parseSubscriptionInfo(queryResult.purchaseDataList[0], planType);
        expiryMs = parsed.expiryMs > 0 ? parsed.expiryMs : this.estimateExpiry(planType);
      } else {
        expiryMs = this.estimateExpiry(planType);
      }
    } catch (e) {
      expiryMs = this.estimateExpiry(planType);
    }

    const purchaseRes: PurchaseResult = {
      planType,
      expiryMs,
      purchaseToken: '',
      purchaseOrderId: '',
    };
    result.success(purchaseRes as Object);
  }

  // ── queryOwnedPurchases ──────────────────────────────────────────────────────

  private async queryOwnedPurchases(result: MethodResult): Promise<void> {
    const context = this.context;
    if (!context) {
      result.error('NO_CONTEXT', 'Context is not available', null);
      return;
    }

    try {
      const owned: OwnedPurchase[] = [];

      // Query non-consumable (lifetime).
      try {
        const ncParam: iap.QueryPurchasesParameter = { productType: iap.ProductType.NONCONSUMABLE };
        const ncResult = await iap.queryPurchases(context, ncParam);
        if (ncResult.purchaseDataList && ncResult.purchaseDataList.length > 0) {
          const lifetimePurchase: OwnedPurchase = {
            productId: LIFETIME_PRODUCT_ID,
            planType: 'lifetime',
            expiryMs: 0,
          };
          owned.push(lifetimePurchase);
        }
      } catch (e) {
        console.warn('[IapPlugin] queryPurchases nonconsumable failed:', e);
      }

      // Query auto-renewable subscriptions.
      try {
        const subParam: iap.QueryPurchasesParameter = { productType: iap.ProductType.AUTORENEWABLE };
        const subResult = await iap.queryPurchases(context, subParam);
        if (subResult.purchaseDataList && subResult.purchaseDataList.length > 0) {
          for (let i = 0; i < subResult.purchaseDataList.length; i++) {
            const parsed = this.parseSubscriptionInfo(subResult.purchaseDataList[i], 'yearly');
            const expiryMs = parsed.expiryMs > 0 ? parsed.expiryMs : this.estimateExpiry(parsed.planType);
            const subPurchase: OwnedPurchase = {
              productId: this.productIdForPlanType(parsed.planType),
              planType: parsed.planType,
              expiryMs,
            };
            owned.push(subPurchase);
          }
        }
      } catch (e) {
        console.warn('[IapPlugin] queryPurchases subscription failed:', e);
      }

      result.success(owned as Object);
    } catch (error) {
      const err = error as BusinessError;
      result.error(`${err.code}`, err.message, null);
    }
  }

  // ── finishPurchase ───────────────────────────────────────────────────────────

  private async finishPurchase(call: MethodCall, result: MethodResult): Promise<void> {
    const context = this.context;
    if (!context) {
      result.success(null);
      return;
    }

    try {
      const productTypeStr = call.argument('productType') as string;
      const purchaseToken = (call.argument('purchaseToken') as string) || '';
      const purchaseOrderId = (call.argument('purchaseOrderId') as string) || '';

      if (!purchaseToken || !purchaseOrderId) {
        result.success(null);
        return;
      }

      const productType = productTypeStr === 'nonconsumable'
        ? iap.ProductType.NONCONSUMABLE
        : iap.ProductType.AUTORENEWABLE;

      await iap.finishPurchase(context, { productType, purchaseToken, purchaseOrderId });
      result.success(null);
    } catch (error) {
      // finishPurchase failures are non-fatal.
      console.warn('[IapPlugin] finishPurchase failed:', error);
      result.success(null);
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  private productSnapshot(product: iap.Product): Record<string, Object> {
    let localPrice = this.formatPrice(product.localPrice || product.price);
    let originalLocalPrice = this.formatPrice(product.originalLocalPrice || '');
    if (!originalLocalPrice) {
      originalLocalPrice = localPrice;
    }
    const snapshot: Record<string, Object> = {
      'id': product.id,
      'localPrice': localPrice,
      'originalLocalPrice': originalLocalPrice,
    };
    return snapshot;
  }

  private formatPrice(price: string): string {
    if (price.endsWith('.00')) {
      return price.substring(0, price.length - 3);
    }
    return price;
  }

  private planTypeForProductId(productId: string): ProPlanType {
    if (productId === MONTHLY_PRODUCT_ID) return 'monthly';
    if (productId === YEARLY_PRODUCT_ID) return 'yearly';
    if (productId === LIFETIME_PRODUCT_ID) return 'lifetime';
    return '';
  }

  private productIdForPlanType(planType: ProPlanType): string {
    if (planType === 'monthly') return MONTHLY_PRODUCT_ID;
    if (planType === 'yearly') return YEARLY_PRODUCT_ID;
    if (planType === 'lifetime') return LIFETIME_PRODUCT_ID;
    return '';
  }

  private estimateExpiry(planType: ProPlanType): number {
    const date = new Date();
    if (planType === 'monthly') {
      date.setMonth(date.getMonth() + 1);
      return date.getTime();
    } else if (planType === 'yearly') {
      date.setFullYear(date.getFullYear() + 1);
      return date.getTime();
    }
    return 0;
  }

  private decodeJWSPayload(jws: string): Record<string, Object> {
    const parts = jws.split('.');
    if (parts.length < 2) { const empty: Record<string, Object> = {}; return empty; }
    try {
      let base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
      const mod = base64.length % 4;
      if (mod === 2) base64 += '==';
      else if (mod === 3) base64 += '=';
      const helper = new util.Base64Helper();
      const decoded = helper.decodeSync(base64);
      const decoder = util.TextDecoder.create('utf-8');
      const json = decoder.decodeWithStream(decoded);
      return JSON.parse(json) as Record<string, Object>;
    } catch (e) {
      console.error('[IapPlugin] JWS decode failed:', e);
      const emptyResult: Record<string, Object> = {};
      return emptyResult;
    }
  }

  private parseSubscriptionInfo(
    purchaseDataStr: string,
    fallbackPlanType: ProPlanType
  ): SubscriptionInfo {
    let planType: ProPlanType = fallbackPlanType;
    let expiryMs = 0;

    try {
      const data = JSON.parse(purchaseDataStr) as Record<string, Object>;
      const jws = (data['jwsSubscriptionStatus'] as string) || '';
      if (!jws) { const earlyInfo: SubscriptionInfo = { planType, expiryMs }; return earlyInfo; }

      const payload = this.decodeJWSPayload(jws);

      const productId = (payload['productId'] as string) || '';
      const resolved = this.planTypeForProductId(productId);
      if (resolved) planType = resolved;

      const tryExpiry = (raw: Object): number => {
        if (typeof raw === 'number') return raw > 0 ? raw : 0;
        if (typeof raw === 'string') {
          const n = parseInt(raw, 10);
          return Number.isNaN(n) ? 0 : n;
        }
        return 0;
      };

      const topExpiry = payload['expiresDate'];
      if (topExpiry !== undefined) expiryMs = tryExpiry(topExpiry);

      const lastStatus = payload['lastSubscriptionStatus'] as Record<string, Object>;
      if (lastStatus) {
        const statusExpiry = lastStatus['expiresDate'];
        if (statusExpiry !== undefined) expiryMs = tryExpiry(statusExpiry);

        const lastOrder = lastStatus['lastPurchaseOrder'] as Record<string, Object>;
        if (lastOrder) {
          const orderProductId = (lastOrder['productId'] as string) || '';
          const orderPlanType = this.planTypeForProductId(orderProductId);
          if (orderPlanType) planType = orderPlanType;
          const orderExpiry = lastOrder['expiresDate'];
          if (orderExpiry !== undefined) expiryMs = tryExpiry(orderExpiry);
        }
      }

      // Convert seconds to milliseconds if needed.
      if (expiryMs > 0 && expiryMs < 1_000_000_000_000) {
        expiryMs = expiryMs * 1000;
      }
    } catch (e) {
      console.error('[IapPlugin] parseSubscriptionInfo error:', e);
    }

    const info: SubscriptionInfo = { planType, expiryMs };
    return info;
  }
}
