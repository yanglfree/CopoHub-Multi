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
import { FlutterPage } from '@ohos/flutter_ohos'

let storage = LocalStorage.getShared()
const EVENT_BACK_PRESS = 'EVENT_BACK_PRESS'

@Entry(storage)
@Component
struct Index {
  @LocalStorageLink('viewId') viewId: string = "";
  @State baseWidth: number = 0;
  @State baseHeight: number = 0;
  @State scaleX: number = 1;
  @State scaleY: number = 1;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      FlutterPage({
        viewId: this.viewId,
        xComponentRenderFit: RenderFit.TOP_LEFT,
        enableFrameCacheForSmooth: false
      })
        .width(this.baseWidth > 0 ? this.baseWidth : '100%')
        .height(this.baseHeight > 0 ? this.baseHeight : '100%')
        .scale({
          x: this.scaleX,
          y: this.scaleY,
          centerX: '0vp',
          centerY: '0vp'
        })
        .onAppear(() => {
          // The 2-in-1 window can be measured before its drawable rect is
          // available. Let EntryAbility push the final viewport into Flutter
          // after the ArkUI page is visible.
          const ctx = getContext(this) as common.UIAbilityContext;
          ctx.eventHub.emit('flutterPageAppear');
        })
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const width = Number(newArea.width);
      const height = Number(newArea.height);
      if (width <= 0 || height <= 0) {
        return;
      }
      if (this.baseWidth <= 0 || this.baseHeight <= 0) {
        this.baseWidth = width;
        this.baseHeight = height;
      }
      this.scaleX = width / this.baseWidth;
      this.scaleY = height / this.baseHeight;
    })
  }

  onBackPress(): boolean {
    const context = getContext(this) as common.UIAbilityContext;
    context.eventHub.emit(EVENT_BACK_PRESS)
    return true
  }
}
