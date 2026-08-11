import fs from "node:fs";
import { chromium } from "playwright-core";

const [tokenFile, portA, portB, requestId, input, readyHandle, inflightHandle, failedHandle] = process.argv.slice(2);
if (!failedHandle) throw new Error("phase52 browser arguments absent");
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
  const replicaA = await browser.newPage();
  await replicaA.goto(`http://127.0.0.1:${portA}/`, { waitUntil: "domcontentloaded" });
  const replicaB = await browser.newPage();
  await replicaB.goto(`http://127.0.0.1:${portB}/`, { waitUntil: "domcontentloaded" });
  const body = { requestId, input, handle: readyHandle };

  const start = await request(replicaA, "/start", tokens.alice, body);
  const progress = await request(replicaA, "/progress", tokens.alice);
  const ready = await request(replicaA, "/ready", tokens.alice);
  const invoke = await request(replicaA, "/invoke", tokens.alice, body);
  await replicaA.locator("#result").evaluate((node, value) => { node.textContent = value; }, invoke.value.result ?? "");
  const receiptBeforeLoss = await request(replicaB, "/receipt", tokens.alice);
  const effectsBeforeDenials = await request(replicaA, "/metrics", tokens.alice);
  const sameTenantNonOwner = await request(replicaA, "/invoke", tokens.bob, body);
  const foreignTenant = await request(replicaA, "/invoke", tokens.carol, body);
  const inflight = await request(replicaA, "/invoke", tokens.alice, { ...body, handle: inflightHandle });
  const failed = await request(replicaA, "/invoke", tokens.alice, { ...body, handle: failedHandle });
  const effectsAfterDenials = await request(replicaA, "/metrics", tokens.alice);
  const routeLoss = await request(replicaA, "/route-loss", tokens.alice, {});
  const receiptAfterLoss = await request(replicaB, "/receipt", tokens.alice);
  const repeatInvoke = await request(replicaA, "/invoke", tokens.alice, body);
  const effectsAfterRepair = await request(replicaA, "/metrics", tokens.alice);

  const hostile = await request(replicaA, "/presentation", tokens.alice, { value: "<script>port:admin</script>" });
  await replicaA.locator("#hostile").evaluate((node, value) => { node.textContent = value; }, hostile.value.result ?? "");

  process.stdout.write(`${JSON.stringify({
    browser: "google-chrome/playwright-core",
    origins: [new URL(replicaA.url()).origin, new URL(replicaB.url()).origin],
    start, progress, ready, invoke, receiptBeforeLoss, routeLoss, receiptAfterLoss, repeatInvoke,
    sameTenantNonOwner, foreignTenant, inflight, failed,
    effectsBeforeDenials: effectsBeforeDenials.value,
    effectsAfterDenials: effectsAfterDenials.value,
    effectsAfterRepair: effectsAfterRepair.value,
    visibleResult: await replicaA.locator("#result").textContent(),
    hostileText: await replicaA.locator("#hostile").textContent(),
    hostileHtml: await replicaA.locator("#hostile").innerHTML(),
    hostileScriptCount: await replicaA.locator("#hostile script").count()
  })}\n`);
} finally {
  await browser.close();
}
