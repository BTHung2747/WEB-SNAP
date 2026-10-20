'use strict';
// One offline launch only; Node observer delegates the original spawn unchanged.
const fs = require('node:fs');
const diag = require('./renderer_diagnostics');
const monitor = diag.observeChromium();
const pw = require('/opt/renderer');
(async () => {
  const report = { startUTC: new Date().toISOString(), stage: 'offline-launch-diagnostic', sourceNavigations: 0,
    uid: process.getuid(), node: process.version, playwright: require('/opt/renderer/package.json').version,
    requested: { browserSandbox: true, privateContext: true, ignoreHTTPSErrors: false, tlsValidation: true },
    observed: { browserLaunch: false, contextCreated: false, pageCreated: false, CDP: false,
      initialCookieCount: null, tlsValidationConfiguration: 'NOT_RUN', tlsHandshake: 'NOT_RUN_NETWORK_NONE' },
    cgroupBefore: diag.cgroupSnapshot(), diagnosticFixture: diag.selfTest() };
  let browser;
  try {
    if (report.playwright !== '1.63.0') throw new Error('Unexpected Playwright version');
    report.binaryInventory = fs.readFileSync('/opt/renderer-browser-sha256.txt', 'utf8');
    browser = await pw.chromium.launch({ headless: true, chromiumSandbox: true, timeout: 10000 });
    report.observed.browserLaunch = true; report.browserVersion = browser.version();
    const context = await browser.newContext({ serviceWorkers: 'block', javaScriptEnabled: false,
      acceptDownloads: false, ignoreHTTPSErrors: false });
    report.observed.contextCreated = true; report.observed.tlsValidationConfiguration = 'OBSERVED_FROM_CONTEXT_CREATION_OPTIONS';
    report.observed.initialCookieCount = (await context.cookies()).length;
    const page = await context.newPage(); report.observed.pageCreated = true;
    const session = await context.newCDPSession(page);
    report.protocol = await session.send('Browser.getVersion');
    await session.send('Fetch.enable', { patterns: [{ urlPattern: '*', requestStage: 'Response' }] });
    await session.send('Fetch.disable'); report.observed.CDP = true;
    report.capabilityStatus = 'PASS'; await context.close();
  } catch (error) {
    report.capabilityStatus = 'FAIL'; const errorLog = new diag.BoundedLog(); errorLog.push(error.stack || error);
    report.launchError = errorLog.report();
    fs.writeFileSync('/out/launch-error.sanitized.txt', report.launchError.text, { flag: 'wx' }); process.exitCode = 30;
    if (/namespace|sandbox|unshare/i.test(report.launchError.text)) report.namespaceReadOnly = diag.namespaceSnapshot();
  } finally {
    if (browser) await browser.close().catch(() => {});
    await new Promise(resolve => setImmediate(resolve));
    report.chromiumProcesses = monitor.finish(); report.cgroupAfter = diag.cgroupSnapshot(); report.endUTC = new Date().toISOString();
    fs.writeFileSync('/out/capability.json', JSON.stringify(report, null, 2), { flag: 'wx' });
    console.log(JSON.stringify({ capabilityStatus: report.capabilityStatus, observed: report.observed,
      processes: report.chromiumProcesses.map(p => ({ pid: p.pid, exitCode: p.exitCode, signal: p.signal, exitObserved: p.exitObserved })), sourceNavigations: 0 }));
  }
})();