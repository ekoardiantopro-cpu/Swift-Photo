import {defineConfig} from '@playwright/test';
export default defineConfig({
  testDir:'./tests', workers:1, fullyParallel:false, reporter:'line',
  use:{baseURL:'http://127.0.0.1:4183', channel:'msedge', headless:true},
  webServer:{command:'node scripts/serve.mjs',url:'http://127.0.0.1:4183',reuseExistingServer:false,timeout:20000},
});
