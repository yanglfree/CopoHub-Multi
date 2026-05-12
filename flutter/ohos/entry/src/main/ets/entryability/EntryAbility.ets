/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd.
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import { FlutterAbility, FlutterEngine, FlutterManager } from '@ohos/flutter_ohos';
import { FullScreenListener } from '@ohos/flutter_ohos/src/main/ets/embedding/ohos/FlutterManager';
import window from '@ohos.window';
import { CopoHubClipboardPlugin } from '../plugins/CopoHubClipboardPlugin';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { IapPlugin } from '../plugins/IapPlugin';
import { PathProviderPlugin } from '../plugins/PathProviderPlugin';
import { SharedPreferencesPlugin } from '../plugins/SharedPreferencesPlugin';
import { SharePlugin } from '../plugins/SharePlugin';

/**
 * A FullScreenListener that safely absorbs errors from setWindowLayoutFullScreen.
 *
 * Background: on 2-in-1 (PC-mode) HarmonyOS devices, calling
 * setWindowLayoutFullScreen(true) can internally fail with
 * "SetWindowType(1958): permission denied". In newer HarmonyOS SDK versions
 * this API returns a Promise<void>; if that Promise rejects and goes unhandled
 * the ArkTS runtime can become unstable, which stops all platform-channel
 * handlers from responding. The result is that every pending Dart `await` on a
 * platform channel hangs indefinitely, runApp() is never reached, and after
 * ~60 s XCollie kills the process ("startup failed").
 *
 * By installing this listener BEFORE FlutterAbility.onWindowStageCreate runs
 * we ensure the rejection is silently swallowed so the runtime stays healthy.
 */
class SafeFullScreenListener implements FullScreenListener {
  private fullScreen: boolean = true;
  private skipCheck: boolean = false;

  useFullScreen(): boolean {
    return this.fullScreen;
  }

  setUseFullScreen(useFullScreen: boolean, context?: Context | null | undefined): void {
    this.fullScreen = useFullScreen;
    this.skipCheck = true;
    try {
      const ctx = context ?? getContext(this);
      const stage = FlutterManager.getInstance()
        .getWindowStage(FlutterManager.getInstance().getUIAbility(ctx));
      const win = stage?.getMainWindowSync();
      if (win) {
        // setWindowLayoutFullScreen can return void (older SDK) or Promise<void>
        // (newer SDK). Wrap in Promise.resolve so any async rejection is caught.
        const result = win.setWindowLayoutFullScreen(useFullScreen) as Object;
        if (result instanceof Promise) {
          (result as Promise<void>).catch(() => {});
        }
      }
    } catch (_) {
      // Silently ignore: full-screen may be unsupported on this device type.
    }
  }

  onScreenStateChanged(data: window.WindowStatusType): void {
    if (this.skipCheck) {
      return;
    }
    switch (data) {
      case window.WindowStatusType.FULL_SCREEN:
      case window.WindowStatusType.SPLIT_SCREEN:
      case window.WindowStatusType.FLOATING:
      case window.WindowStatusType.MAXIMIZE:
        this.fullScreen = true;
        break;
      default:
        this.fullScreen = false;
        break;
    }
  }
}

export default class EntryAbility extends FlutterAbility {
  // Stored so the window-focus callback can reach the engine after
  // configureFlutterEngine() has been called.
  private storedEngine: FlutterEngine | null = null;

  // Installed before super.onWindowStageCreate so that the DefaultFullScreenListener
  // is never used (see SafeFullScreenListener above).
  private readonly safeFullScreenListener = new SafeFullScreenListener();

  // Workaround for a Flutter-OH framework bug on 2-in-1 devices:
  // FlutterAbilityAndEntryDelegate calls handleChangeFocus(true) on ACTIVE
  // but forgets to call handleChangeFocus(false) on INACTIVE. When the window
  // loses IME focus the IME client is detached (error 12800009), but the
  // text-input handler still sends updateCursor on every frame → main-thread
  // flood → ANR.
  private readonly onWindowStageInactiveFix =
    (data: window.WindowStageEventType) => {
      if (data === window.WindowStageEventType.INACTIVE) {
        this.storedEngine
          ?.getTextInputChannel()
          ?.textInputMethodHandler
          ?.handleChangeFocus(false);
      }
    };

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    this.storedEngine = flutterEngine;
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    flutterEngine.getPlugins()?.add(new SharedPreferencesPlugin())
    flutterEngine.getPlugins()?.add(new PathProviderPlugin())
    flutterEngine.getPlugins()?.add(new CopoHubClipboardPlugin())
    flutterEngine.getPlugins()?.add(new SharePlugin(this.context))
    flutterEngine.getPlugins()?.add(new IapPlugin(this.context))
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Install the safe listener BEFORE super runs so that when
    // FlutterAbility.onWindowStageCreate calls setUseFullScreen(true) it uses
    // our error-tolerant implementation instead of DefaultFullScreenListener.
    FlutterManager.getInstance().setFullScreenListener(this.safeFullScreenListener);
    super.onWindowStageCreate(windowStage);
    try {
      windowStage.on('windowStageEvent', this.onWindowStageInactiveFix);
    } catch (err) {
      // Non-fatal: best-effort workaround only.
    }
  }

  onWindowStageWillDestroy(windowStage: window.WindowStage): void {
    try {
      windowStage.off('windowStageEvent', this.onWindowStageInactiveFix);
    } catch (err) {
      // Ignore
    }
    super.onWindowStageWillDestroy(windowStage);
  }
}
