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

import { appTasks } from '@ohos/hvigor-ohos-plugin';
import fs from 'fs';
import path from 'path';
import childProcess from 'child_process';

function applyFlutterOhosPatches(): void {
    const projectDir = process.cwd();
    const flutterOhosDir = path.join(projectDir, 'oh_modules', '@ohos', 'flutter_ohos');
    const flutterViewFile = path.join(flutterOhosDir, 'src', 'main', 'ets', 'view', 'FlutterView.ets');
    const patchFile = path.join(projectDir, 'patches', 'flutter_ohos_2in1_surface_lifecycle.patch');

    if (!fs.existsSync(flutterViewFile) || !fs.existsSync(patchFile)) {
        return;
    }

    const flutterViewSource = fs.readFileSync(flutterViewFile, 'utf8');
    if (flutterViewSource.includes('ensureSurfaceAttached(): void')) {
        return;
    }

    childProcess.execFileSync('patch', ['-p1', '-i', patchFile], {
        cwd: flutterOhosDir,
        stdio: 'inherit'
    });
}

applyFlutterOhosPatches();

export default {
    system: appTasks,  /* Built-in plugin of Hvigor. It cannot be modified. */
    plugins:[]         /* Custom plugin to extend the functionality of Hvigor. */
}
