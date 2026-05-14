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

import common from '@ohos.app.ability.common';
import { display } from '@kit.ArkUI';
import { FlutterAbility, FlutterEngine, FlutterManager } from '@ohos/flutter_ohos';
import { FullScreenListener } from '@ohos/flutter_ohos/src/main/ets/embedding/ohos/FlutterManager';
import window from '@ohos.window';
import { CopoHubClipboardPlugin } from '../plugins/CopoHubClipboardPlugin';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { IapPlugin } from '../plugins/IapPlugin';
import { PathProviderPlugin } from '../plugins/PathProviderPlugin';
import { SharedPreferencesPlugin } from '../plugins/SharedPreferencesPlugin';
import { SharePlugin } from '../plugins/SharePlugin';
import { StartupLogger } from '../utils/StartupLogger';

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
  // Tracks the most recent window status so useFullScreen() can correctly
  // return false for windowed (FLOATING) mode on 2-in-1 devices.
  private windowStatus: window.WindowStatusType | null = null;

  // Called before super.onWindowStageCreate so we know the initial window
  // mode before skipCheck is set to true by setUseFullScreen().
  applyWindowStatus(status: window.WindowStatusType): void {
    this.windowStatus = status;
  }

  useFullScreen(): boolean {
    if (this.isDecoratedWindowMode()) {
      return false;
    }
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
        this.applyWindowStatus(win.getWindowStatus());
        if (useFullScreen && this.isDecoratedWindowMode()) {
          // In 2-in-1 windowed/maximized mode the system title bar is outside
          // the drawable area. Forcing layout fullscreen makes ArkUI ignore
          // that safe area and sizes Flutter to windowRect instead of
          // drawableRect.
          return;
        }
        // setWindowLayoutFullScreen can return void (older SDK) or Promise<void>
        // (newer SDK). Wrap in Promise.resolve so any async rejection is caught.
        const result = win.setWindowLayoutFullScreen(useFullScreen);
        Promise.resolve(result).catch((err: Object) => {
          StartupLogger.warn(`SafeFullScreenListener.setUseFullScreen rejected: ${String(err)}`);
        });
      }
    } catch (err) {
      StartupLogger.warn(`SafeFullScreenListener.setUseFullScreen failed: ${String(err)}`);
      // Silently ignore: full-screen may be unsupported on this device type.
    }
  }

  onScreenStateChanged(data: window.WindowStatusType): void {
    // Always track the current window status so useFullScreen() stays accurate,
    // even after skipCheck is set to true by setUseFullScreen().
    this.windowStatus = data;
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

  private isDecoratedWindowMode(): boolean {
    return this.windowStatus === window.WindowStatusType.FLOATING ||
      this.windowStatus === window.WindowStatusType.MAXIMIZE;
  }
}

export default class EntryAbility extends FlutterAbility {
  // Stored so the window-focus callback can reach the engine after
  // configureFlutterEngine() has been called.
  private storedEngine: FlutterEngine | null = null;

  // Installed before super.onWindowStageCreate so that the DefaultFullScreenListener
  // is never used (see SafeFullScreenListener above).
  private readonly safeFullScreenListener = new SafeFullScreenListener();

  private viewportSyncWindow: window.Window | null = null;
  private viewportSyncTimerIds: number[] = [];
  private surfaceAttachmentTimerIds: number[] = [];

  private readonly onWindowSizeChangeSync = (data: window.Size) => {
    this.syncFlutterViewportToWindow('windowSizeChange', true);
    this.scheduleDeferredViewportSync('windowSizeChange');
    this.scheduleSurfaceAttachment('windowSizeChange', true);
  };

  private readonly onWindowRectChangeSync = (data: window.RectChangeOptions) => {
    this.syncFlutterViewportToWindow('windowRectChange', true);
    this.scheduleDeferredViewportSync('windowRectChange');
    this.scheduleSurfaceAttachment('windowRectChange', true);
  };

  private readonly onWindowStatusChangeSync = (data: window.WindowStatusType) => {
    this.safeFullScreenListener.applyWindowStatus(data);
    this.syncFlutterViewportToWindow(`windowStatusChange.${data}`, true);
    this.scheduleDeferredViewportSync(`windowStatusChange.${data}`);
    this.scheduleSurfaceAttachment(`windowStatusChange.${data}`, true);
  };

  // Workaround for a Flutter-OH framework bug on 2-in-1 devices:
  // FlutterAbilityAndEntryDelegate calls handleChangeFocus(true) on ACTIVE
  // but forgets to call handleChangeFocus(false) on INACTIVE. When the window
  // loses IME focus the IME client is detached (error 12800009), but the
  // text-input handler still sends updateCursor on every frame, causing a
  // main-thread flood and eventually ANR.
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

  provideFlutterEngine(context: common.Context): FlutterEngine | null {
    const flutterEngine = new FlutterEngine(context, null, null, null);
    flutterEngine.init(
      context,
      this.getFlutterShellArgs().toArray() ?? [],
      this.shouldRestoreAndSaveState()
    );
    return flutterEngine;
  }

  attachToEngineAutomatically(): boolean {
    // On 2-in-1 devices the FlutterView is created before ArkUI has created
    // the native XComponent. Attaching the engine at that point puts the native
    // side into a preload path that never becomes the visible first frame.
    // We attach explicitly after XComponent surface creation instead.
    return false;
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Detect the current window status BEFORE installing the listener so that
    // useFullScreen() already knows whether we're in windowed (FLOATING) mode
    // when setUseFullScreen is called inside super.onWindowStageCreate.
    try {
      const initStatus = windowStage.getMainWindowSync().getWindowStatus();
      this.safeFullScreenListener.applyWindowStatus(initStatus);
    } catch (err) {
      StartupLogger.warn(`EntryAbility.onWindowStageCreate.initWindowStatusFailed: ${String(err)}`);
    }
    // Install the safe listener BEFORE super runs so that when
    // FlutterAbility.onWindowStageCreate calls setUseFullScreen(true) it uses
    // our error-tolerant implementation instead of DefaultFullScreenListener.
    FlutterManager.getInstance().setFullScreenListener(this.safeFullScreenListener);
    super.onWindowStageCreate(windowStage);
    this.syncFlutterViewportToWindow('afterSuper');
    try {
      windowStage.on('windowStageEvent', this.onWindowStageInactiveFix);
    } catch (err) {
      StartupLogger.warn(`EntryAbility.onWindowStageCreate.windowStageEventListenerFailed: ${String(err)}`);
      // Non-fatal: best-effort workaround only.
    }
    this.registerViewportSyncListeners(windowStage);
    try {
      this.context.eventHub.on('flutterPageAppear', () => {
        this.syncFlutterViewportToWindow('flutterPageAppear', true);
        this.scheduleDeferredViewportSync('flutterPageAppear');
      });
    } catch (err) {
      StartupLogger.warn(`EntryAbility.onWindowStageCreate.flutterPageAppearListenerFailed: ${String(err)}`);
    }
    try {
      this.context.eventHub.on('flutterSurfaceCreated', (viewId: string) => {
        this.scheduleSurfaceAttachment(`flutterSurfaceCreated.${viewId}`);
      });
    } catch (err) {
      StartupLogger.warn(`EntryAbility.onWindowStageCreate.flutterSurfaceCreatedListenerFailed: ${String(err)}`);
    }
  }

  onWindowStageWillDestroy(windowStage: window.WindowStage): void {
    this.clearDeferredViewportSync();
    this.clearSurfaceAttachment();
    this.unregisterViewportSyncListeners();
    try {
      this.context.eventHub.off('flutterPageAppear');
    } catch (err) {
      StartupLogger.warn(`EntryAbility.onWindowStageWillDestroy.flutterPageAppearListenerRemoveFailed: ${String(err)}`);
    }
    try {
      this.context.eventHub.off('flutterSurfaceCreated');
    } catch (err) {
      StartupLogger.warn(
        `EntryAbility.onWindowStageWillDestroy.flutterSurfaceCreatedListenerRemoveFailed: ${String(err)}`
      );
    }
    try {
      windowStage.off('windowStageEvent', this.onWindowStageInactiveFix);
    } catch (err) {
      StartupLogger.warn(`EntryAbility.onWindowStageWillDestroy.windowStageEventListenerRemoveFailed: ${String(err)}`);
      // Ignore
    }
    super.onWindowStageWillDestroy(windowStage);
  }

  private registerViewportSyncListeners(windowStage: window.WindowStage): void {
    try {
      const mainWindow = windowStage.getMainWindowSync();
      this.viewportSyncWindow = mainWindow;
      mainWindow.on('windowSizeChange', this.onWindowSizeChangeSync);
      mainWindow.on('windowRectChange', this.onWindowRectChangeSync);
      mainWindow.on('windowStatusChange', this.onWindowStatusChangeSync);
    } catch (err) {
      StartupLogger.warn(`EntryAbility.viewportSync.listenersRegisterFailed: ${String(err)}`);
    }
  }

  private unregisterViewportSyncListeners(): void {
    try {
      this.viewportSyncWindow?.off('windowSizeChange', this.onWindowSizeChangeSync);
      this.viewportSyncWindow?.off('windowRectChange', this.onWindowRectChangeSync);
      this.viewportSyncWindow?.off('windowStatusChange', this.onWindowStatusChangeSync);
    } catch (err) {
      StartupLogger.warn(`EntryAbility.viewportSync.listenersRemoveFailed: ${String(err)}`);
    }
    this.viewportSyncWindow = null;
  }

  private scheduleDeferredViewportSync(reason: string): void {
    this.clearDeferredViewportSync();
    [0, 32, 100, 260, 900].forEach((delay: number) => {
      const timerId = setTimeout(() => {
        this.viewportSyncTimerIds = this.viewportSyncTimerIds.filter((id: number) => id !== timerId);
        this.syncFlutterViewportToWindow(`${reason}.deferred${delay}`, true);
      }, delay);
      this.viewportSyncTimerIds.push(timerId);
    });
  }

  private clearDeferredViewportSync(): void {
    this.viewportSyncTimerIds.forEach((timerId: number) => {
      clearTimeout(timerId);
    });
    this.viewportSyncTimerIds = [];
  }

  private scheduleSurfaceAttachment(reason: string, force: boolean = false): void {
    this.clearSurfaceAttachment();
    [0, 32, 120, 260, 900].forEach((delay: number) => {
      const timerId = setTimeout(() => {
        this.surfaceAttachmentTimerIds = this.surfaceAttachmentTimerIds.filter((id: number) => id !== timerId);
        this.retryFlutterViewAttachment(`${reason}.deferred${delay}`, force);
      }, delay);
      this.surfaceAttachmentTimerIds.push(timerId);
    });
  }

  private clearSurfaceAttachment(): void {
    this.surfaceAttachmentTimerIds.forEach((timerId: number) => {
      clearTimeout(timerId);
    });
    this.surfaceAttachmentTimerIds = [];
  }

  private retryFlutterViewAttachment(reason: string, force: boolean = false): void {
    try {
      const flutterView = this.getFlutterView();
      if (flutterView === null || this.storedEngine === null) {
        return;
      }
      if (!force && flutterView.hasRenderedFirstFrame()) {
        return;
      }
      if (!flutterView.isAttachedToFlutterEngine()) {
        flutterView.attachToFlutterEngine(this.storedEngine);
      } else {
        flutterView.ensureSurfaceAttached();
      }
      flutterView.onSurfaceCreated();
      this.syncFlutterViewportToWindow(`attachmentRetry.${reason}`, true);
      this.storedEngine.processPendingMessages();
    } catch (err) {
      StartupLogger.warn(`EntryAbility.attachmentRetry.${reason}.failed: ${String(err)}`);
    }
  }

  private syncFlutterViewportToWindow(reason: string, callPreDraw: boolean = false): void {
    try {
      const flutterView = this.getFlutterView();
      if (flutterView === null) {
        return;
      }
      const properties = this.viewportSyncWindow?.getWindowProperties()
        ?? FlutterManager.getInstance()
          .getWindowStage(FlutterManager.getInstance().getUIAbility(this.context))
          .getMainWindowSync()
          .getWindowProperties();
      const rect = this.preferredViewportRect(properties);
      if (rect.width <= 0 || rect.height <= 0) {
        return;
      }
      const densityPixels = this.preferredDevicePixelRatio();
      StartupLogger.warn(
        `EntryAbility.viewportSync.${reason} rect=${rect.width}x${rect.height} density=${densityPixels}`
      );
      flutterView.ensureSurfaceAttached();
      if (callPreDraw) {
        // preDraw corrects the native frame buffer dimensions that
        // attachToFlutterEngine initialised with the full-display size
        // (updateSize(displayInfo.width, displayInfo.height), e.g. 3120x2080).
        flutterView.preDraw(rect.width, rect.height);
      }
      flutterView.updateNativeSurfaceMetrics(rect.width, rect.height, densityPixels);
      flutterView.onAreaChange(null);
      this.storedEngine?.processPendingMessages();
    } catch (err) {
      StartupLogger.warn(`EntryAbility.viewportSync.${reason}.failed: ${String(err)}`);
    }
  }

  private preferredViewportRect(properties: window.WindowProperties): window.Rect {
    const drawableRect = properties.drawableRect;
    if (drawableRect.width > 0 && drawableRect.height > 0) {
      return drawableRect;
    }
    return properties.windowRect;
  }

  private preferredDevicePixelRatio(): number {
    const status = this.viewportSyncWindow?.getWindowStatus();
    if (status === window.WindowStatusType.FLOATING || status === window.WindowStatusType.MAXIMIZE) {
      return 1.0;
    }
    return display.getDefaultDisplaySync().densityPixels;
  }
}
