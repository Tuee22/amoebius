import fs from "node:fs";
import { chromium } from "playwright-core";

const [tokenFile, portA, portB, requestId, input, handle] = process.argv.slice(2);
if (!tokenFile || !portA || !portB || !requestId || !input || !handle) {
  throw new Error("phase50 browser arguments absent");
}
const tokens = JSON.parse(fs.readFileSync(tokenFile, "utf8"));
const browser = await chromium.launch({
  executablePath: "/usr/bin/google-chrome",
  headless: true,
  args: [
    "--no-sandbox", "--disable-background-networking", "--disable-component-update",
    "--disable-domain-reliability", "--disable-sync", "--disable-default-apps",
    "--disable-client-side-phishing-detection", "--dns-prefetch-disable",
    "--metrics-recording-only", "--no-first-run", "--safebrowsing-disable-auto-update",
    "--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE 127.0.0.1"
  ]
});

async function request(page, path, token, body) {
  return page.evaluate(async ({ path, token, body }) => {
    const response = await fetch(path, {
      method: body === undefined ? "GET" : "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: body === undefined ? undefined : JSON.stringify(body)
    });
    let value = {};
    try { value = await response.json(); } catch {}
    return { status: response.status, value };
  }, { path, token, body });
}

try {
  const own = await browser.newPage();
  await own.goto(`http://127.0.0.1:${portA}/`, { waitUntil: "domcontentloaded" });
  const body = { requestId, input, handle };
  const start = await request(own, "/start", tokens.alice, body);
  const progress = await request(own, "/progress", tokens.alice);
  const ready = await request(own, "/ready", tokens.alice);
  const invoke = await request(own, "/invoke", tokens.alice, body);
  await own.locator("#result").evaluate((node, value) => { node.textContent = value; }, invoke.value.result ?? "");

  const replica = await browser.newPage();
  await replica.goto(`http://127.0.0.1:${portB}/`, { waitUntil: "domcontentloaded" });
  const receipt = await request(replica, "/receipt", tokens.alice);

  const foreignBefore = await request(own, "/metrics", tokens.alice);
  const foreign = await request(own, "/invoke", tokens.carol, body);
  const foreignAfter = await request(own, "/metrics", tokens.alice);

  const hostile = await request(own, "/presentation", tokens.alice, { value: "<script>port:admin</script>" });
  await own.locator("#hostile").evaluate((node, value) => { node.textContent = value; }, hostile.value.result ?? "");

  process.stdout.write(`${JSON.stringify({
    browser: "google-chrome/playwright-core",
    origins: [new URL(own.url()).origin, new URL(replica.url()).origin],
    start, progress, ready, invoke,
    visibleResult: await own.locator("#result").textContent(),
    receipt,
    foreignStatus: foreign.status,
    foreignBody: foreign.value,
    foreignEffectsBefore: foreignBefore.value,
    foreignEffectsAfter: foreignAfter.value,
    hostileText: await own.locator("#hostile").textContent(),
    hostileHtml: await own.locator("#hostile").innerHTML(),
    hostileScriptCount: await own.locator("#hostile script").count()
  })}\n`);
} finally {
  await browser.close();
}
