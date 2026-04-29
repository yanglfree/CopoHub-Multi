import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos';
import MethodChannel, { MethodCallHandler, MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';

const CHANNEL_NAME = 'plugins.flutter.io/path_provider';

export class PathProviderPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private binding: FlutterPluginBinding | null = null;

  getUniqueClassName(): string {
    return 'PathProviderPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.binding = binding;
    this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
    this.binding = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    const context = this.binding?.getApplicationContext();
    if (!context) {
      result.error('UNAVAILABLE', 'Application context not available', null);
      return;
    }

    switch (call.method) {
      case 'getTemporaryDirectory':
      case 'getApplicationCacheDirectory':
        result.success(context.cacheDir);
        break;
      case 'getApplicationDocumentsDirectory':
      case 'getApplicationSupportDirectory':
        result.success(context.filesDir);
        break;
      default:
        result.notImplemented();
    }
  }
}
