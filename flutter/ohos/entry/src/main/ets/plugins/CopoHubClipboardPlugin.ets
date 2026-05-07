import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos';
import MethodChannel, { MethodCallHandler, MethodResult } from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import pasteboard from '@ohos.pasteboard';
import { BusinessError } from '@ohos.base';

const CHANNEL_NAME = 'com.youdroid/clipboard';

export class CopoHubClipboardPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;

  getUniqueClassName(): string {
    return 'CopoHubClipboardPlugin';
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
      case 'getText':
        this.getText(result);
        break;
      default:
        result.notImplemented();
    }
  }

  private getText(result: MethodResult): void {
    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      systemPasteboard.getData((err: BusinessError, data: pasteboard.PasteData) => {
        if (err) {
          result.error('PASTEBOARD_ERROR', err.message, err.code);
          return;
        }

        let text = '';
        const count = data.getRecordCount();
        for (let index = 0; index < count; index++) {
          const record = data.getRecord(index);
          if (record.mimeType === pasteboard.MIMETYPE_TEXT_PLAIN) {
            text += record.plainText;
          }
        }
        result.success(text);
      });
    } catch (error) {
      result.error('PASTEBOARD_ERROR', `${error}`, null);
    }
  }
}
