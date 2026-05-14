import hilog from '@ohos.hilog';

const STARTUP_LOG_DOMAIN: number = 0xC0F0;
const STARTUP_LOG_TAG: string = 'CopoHubStartup';

export class StartupLogger {
  static info(message: string): void {
    console.warn(`[${STARTUP_LOG_TAG}] ${message}`);
    hilog.info(STARTUP_LOG_DOMAIN, STARTUP_LOG_TAG, message);
  }

  static warn(message: string): void {
    console.warn(`[${STARTUP_LOG_TAG}] ${message}`);
    hilog.warn(STARTUP_LOG_DOMAIN, STARTUP_LOG_TAG, message);
  }

  static error(message: string, error?: Object): void {
    if (error === undefined || error === null) {
      console.warn(`[${STARTUP_LOG_TAG}] ${message}`);
      hilog.error(STARTUP_LOG_DOMAIN, STARTUP_LOG_TAG, message);
      return;
    }
    console.warn(`[${STARTUP_LOG_TAG}] ${message}: ${String(error)}`);
    hilog.error(STARTUP_LOG_DOMAIN, STARTUP_LOG_TAG, `${message}: ${String(error)}`);
  }
}
