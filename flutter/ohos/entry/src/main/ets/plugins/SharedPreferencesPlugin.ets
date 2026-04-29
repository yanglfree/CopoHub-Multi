import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos';
import MethodChannel, { MethodCallHandler, MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import dataPreferences from '@ohos.data.preferences';

const CHANNEL_NAME = 'plugins.flutter.io/shared_preferences';
const PREFS_NAME = 'FlutterSharedPreferences';

export class SharedPreferencesPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private binding: FlutterPluginBinding | null = null;
  private prefs: dataPreferences.Preferences | null = null;

  getUniqueClassName(): string {
    return 'SharedPreferencesPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.binding = binding;
    this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);
    this.channel.setMethodCallHandler(this);

    const context = binding.getApplicationContext();
    dataPreferences.getPreferences(context, PREFS_NAME).then((prefs) => {
      this.prefs = prefs;
    }).catch(() => {});
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
    this.binding = null;
    this.prefs = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (!this.prefs) {
      result.error('UNAVAILABLE', 'SharedPreferences not initialized', null);
      return;
    }

    const args = call.args as Map<string, Object> | null;

    switch (call.method) {
      case 'getAll':
        this.getAll(result, null, null);
        break;

      case 'getAllWithParameters': {
        const prefix = args?.get('prefix') as string ?? 'flutter.';
        const allowList = args?.get('allowList') as string[] | null ?? null;
        this.getAll(result, prefix, allowList);
        break;
      }

      case 'setBool':
      case 'setInt':
      case 'setDouble':
      case 'setString':
      case 'setStringList': {
        const key = args?.get('key') as string | undefined;
        const value = args?.get('value') as Object | undefined;
        if (key === undefined || value === undefined) {
          result.error('PREFS_ERROR', 'Missing preference key or value', null);
          break;
        }
        this.setValue(key, value, result);
        break;
      }

      case 'remove': {
        const key = args?.get('key') as string | undefined;
        if (key === undefined) {
          result.error('PREFS_ERROR', 'Missing preference key', null);
          break;
        }
        this.prefs.delete(key).then(() => this.prefs!.flush()).then(() => {
          result.success(true);
        }).catch((e: Error) => result.error('PREFS_ERROR', e.message, null));
        break;
      }

      case 'clear':
        this.prefs.clear().then(() => this.prefs!.flush()).then(() => {
          result.success(true);
        }).catch((e: Error) => result.error('PREFS_ERROR', e.message, null));
        break;

      case 'clearWithParameters': {
        const prefix = args?.get('prefix') as string ?? 'flutter.';
        const allowList = args?.get('allowList') as string[] | null ?? null;
        this.clearWithPrefix(prefix, allowList, result);
        break;
      }

      default:
        result.notImplemented();
    }
  }

  private getAll(result: MethodResult, prefix: string | null, allowList: string[] | null): void {
    const all = this.prefs!.getAllSync();
    const out = new Map<string, Object>();
    for (const key of Object.keys(all)) {
      if (prefix !== null && !key.startsWith(prefix)) continue;
      if (allowList !== null && !allowList.includes(key)) continue;
      out.set(key, this.prefs!.getSync(key, '') as Object);
    }
    result.success(out);
  }

  private setValue(key: string, value: Object, result: MethodResult): void {
    this.prefs!.put(key, value).then(() => this.prefs!.flush()).then(() => {
      result.success(true);
    }).catch((e: Error) => result.error('PREFS_ERROR', e.message, null));
  }

  private clearWithPrefix(prefix: string, allowList: string[] | null, result: MethodResult): void {
    const all = this.prefs!.getAllSync();
    const keysToDelete = Object.keys(all).filter((k) => {
      if (!k.startsWith(prefix)) return false;
      if (allowList !== null && !allowList.includes(k)) return false;
      return true;
    });

    Promise.all(keysToDelete.map((k) => this.prefs!.delete(k)))
      .then(() => this.prefs!.flush())
      .then(() => result.success(true))
      .catch((e: Error) => result.error('PREFS_ERROR', e.message, null));
  }
}
