import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.revanthatmakuri.reactpod',
  appName: 'ReactPod',
  webDir: 'dist',
  bundledWebRuntime: false,
  server: {
    iosScheme: 'http',
  },
};

export default config;
