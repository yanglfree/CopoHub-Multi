import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos';
import MethodChannel, {
  MethodCallHandler,
  MethodResult,
} from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import fileUri from '@ohos.file.fileuri';
import { common } from '@kit.AbilityKit';

const CHANNEL_NAME = 'dev.fluttercommunity.plus/share';

export class SharePlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private readonly abilityContext: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.abilityContext = context;
  }

  getUniqueClassName(): string {
    return 'SharePlugin';
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
      case 'share':
        this.handleShare(call, result);
        break;
      case 'shareFiles':
        this.handleShareFiles(call, result);
        break;
      default:
        result.notImplemented();
    }
  }

  // ── share (text) ────────────────────────────────────────────────────────────

  private handleShare(call: MethodCall, result: MethodResult): void {
    const text: string = ((call.argument('text') as string) ?? '').trim();
    const subject: string = (call.argument('subject') as string) ?? '';
    try {
      const record: systemShare.SharedRecord = {
        utd: utd.UniformDataType.PLAIN_TEXT,
        content: text,
        description: subject,
      };
      const sharedData = new systemShare.SharedData(record);
      const controller = new systemShare.ShareController(sharedData);
      controller.show(this.abilityContext, {})
        .then(() => result.success(null))
        .catch((e: Error) => result.error('SHARE_ERROR', e.message, null));
    } catch (e) {
      result.error('SHARE_ERROR', `${e}`, null);
    }
  }

  // ── shareFiles ──────────────────────────────────────────────────────────────

  private handleShareFiles(call: MethodCall, result: MethodResult): void {
    const paths: string[] = (call.argument('paths') as string[]) ?? [];
    const mimeTypes: string[] = (call.argument('mimeTypes') as string[]) ?? [];
    const subject: string = (call.argument('subject') as string) ?? '';
    const text: string = (call.argument('text') as string) ?? '';

    if (paths.length === 0) {
      result.success(null);
      return;
    }

    try {
      const mime: string = mimeTypes.length > 0 ? mimeTypes[0] : 'image/png';
      const utdId: string = mime.startsWith('image/')
        ? utd.UniformDataType.IMAGE
        : utd.UniformDataType.FILE;

      // Convert sandbox absolute path to a shareable file URI.
      const uri: string = fileUri.getUriFromPath(paths[0]);
      const description: string = subject || text;

      const record: systemShare.SharedRecord = {
        utd: utdId,
        uri: uri,
        description: description,
      };
      const sharedData = new systemShare.SharedData(record);
      const controller = new systemShare.ShareController(sharedData);
      controller.show(this.abilityContext, {})
        .then(() => result.success(null))
        .catch((e: Error) => result.error('SHARE_ERROR', e.message, null));
    } catch (e) {
      result.error('SHARE_ERROR', `${e}`, null);
    }
  }
}
