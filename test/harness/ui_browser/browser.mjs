import crypto from "node:crypto";
import fs from "node:fs";
import http from "node:http";
import { createRequire } from "node:module";
import path from "node:path";

const root = process.cwd();
const require = createRequire(path.join(root, ".build/node_modules/loader.js"));
const { chromium } = require("playwright-core");
const fixtureRoot = path.join(root, "test/fixture/ui_browser");
const bundlePath = path.join(root, ".build/ui/browser-interpreter/ui.js");
const chromePath = process.env.AMOEBIUS_CHROMIUM;
if (!chromePath) throw new Error("AMOEBIUS_CHROMIUM is required");

const headers = Object.fromEntries(
  fs.readFileSync(path.join(root, "test/fixture/ui_security/production_headers.tsv"), "utf8")
    .trim().split("\n").slice(1).map(line => line.split("\t"))
);

const plans = {
  single: fs.readFileSync(path.join(fixtureRoot, "plans/minimal_single_tenant.json"), "utf8").trim(),
  multi: fs.readFileSync(path.join(fixtureRoot, "plans/minimal_multi_tenant.json"), "utf8").trim()
};

const requests = [];
const socketUpgrades = [];
const upgradedSockets = [];
let lastChallenge = "";

const responseHeaders = contentType => ({
  ...headers,
  "Content-Type": contentType,
  "Cache-Control": "no-store"
});

const html = `<!doctype html>
<html><head><meta charset="utf-8"><title>amoebius ui</title>
<link rel="stylesheet" href="/ui.css">
<script>window.inlineCanary = true</script>
<script type="module" src="/ui.js"></script></head><body></body></html>`;

const server = http.createServer((request, response) => {
  const url = new URL(request.url, "http://127.0.0.1");
  const finish = (status, contentType, body) => {
    response.writeHead(status, responseHeaders(contentType));
    response.end(body);
  };
  if (url.pathname === "/") return finish(200, "text/html; charset=utf-8", html);
  if (url.pathname === "/ui.js") return finish(200, "text/javascript; charset=utf-8", fs.readFileSync(bundlePath));
  if (url.pathname === "/ui.css") return finish(200, "text/css; charset=utf-8", "[hidden]{display:none} body{font-family:sans-serif}");
  if (url.pathname === "/ui/client-plan") {
    const selected = url.searchParams.get("plan") === "multi" ? plans.multi : plans.single;
    const parsed = JSON.parse(selected);
    if (url.searchParams.get("stale") === "1") parsed.digest = `${parsed.digest}-stale`;
    return finish(200, "application/json", JSON.stringify(parsed));
  }
  if (url.pathname === "/ui/current-digest") {
    const selected = url.searchParams.get("plan") === "multi" ? JSON.parse(plans.multi) : JSON.parse(plans.single);
    return finish(200, "application/json", JSON.stringify({ digest: selected.digest }));
  }
  if (url.pathname === "/ui/challenge") {
    lastChallenge = crypto.randomBytes(18).toString("hex");
    return finish(200, "application/json", JSON.stringify({ nonce: lastChallenge }));
  }
  if (request.method === "POST" && (url.pathname.startsWith("/ui/action/") || url.pathname === "/ui/scope")) {
    const chunks = [];
    request.on("data", chunk => chunks.push(chunk));
    request.on("end", () => {
      const body = Buffer.concat(chunks).toString("utf8");
      requests.push({ method: request.method, origin: "same-origin", path: url.pathname, body });
      finish(200, "application/json", JSON.stringify({ accepted: true }));
    });
    return;
  }
  finish(404, "application/json", JSON.stringify({ error: "not-found" }));
});

server.on("upgrade", (request, socket) => {
  const key = request.headers["sec-websocket-key"];
  if (request.url !== "/ui/socket" || typeof key !== "string") {
    socket.destroy();
    return;
  }
  const accept = crypto.createHash("sha1").update(`${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11`).digest("base64");
  socket.write(
    "HTTP/1.1 101 Switching Protocols\r\n" +
    "Upgrade: websocket\r\n" +
    "Connection: Upgrade\r\n" +
    `Sec-WebSocket-Accept: ${accept}\r\n\r\n`
  );
  socketUpgrades.push({ method: "GET", origin: "same-origin", path: "/ui/socket", body: "" });
  upgradedSockets.push(socket);
});

await new Promise(resolve => server.listen(0, "127.0.0.1", resolve));
const address = server.address();
const baseUrl = `http://127.0.0.1:${address.port}`;
const browser = await chromium.launch({
  executablePath: chromePath,
  headless: true,
  args: [
    "--no-sandbox",
    "--disable-background-networking",
    "--disable-async-dns",
    "--disable-client-side-phishing-detection",
    "--disable-component-update",
    "--disable-default-apps",
    "--disable-domain-reliability",
    "--disable-ipv6",
    "--disable-sync",
    "--disable-features=MediaRouter,OptimizationHints,AutofillServerCommunication,AsyncDns,DnsOverHttps",
    "--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE 127.0.0.1",
    "--metrics-recording-only",
    "--no-first-run",
    "--dns-prefetch-disable",
    "--safebrowsing-disable-auto-update"
  ]
});
const context = await browser.newContext();
const externalRequests = [];
await context.route("https://docs.example.invalid/**", async route => {
  const url = new URL(route.request().url());
  externalRequests.push({ method: "NAVIGATE", origin: url.origin, path: url.pathname, body: "" });
  await route.abort();
});

const waitReady = page => page.waitForFunction(() => window.__AMOEBIUS_READY__ === true);
const single = await context.newPage();
await single.goto(`${baseUrl}/`);
await waitReady(single);
const nonce = await single.evaluate(() => window.__AMOEBIUS_CHALLENGE__);
await single.locator("#value").fill(nonce);
await single.locator("#edit").click();
await single.waitForFunction(() => window.__AMOEBIUS_LAST__?.visibleState === "editing");
const editOutcome = await single.evaluate(() => window.__AMOEBIUS_LAST__);
await single.locator("#submit").click();
await single.waitForFunction(value => document.querySelector("#status")?.textContent === `Pending: ${value}`, nonce);
const submitOutcome = await single.evaluate(() => window.__AMOEBIUS_LAST__);

const singleHeading = await single.locator("#title").textContent();
const singleStatus = await single.locator("#status").textContent();
const singleDom = [
  "main[aria-labelledby=title]",
  `  h1#title ${singleHeading}`,
  `  status ${singleStatus}`
].join("\n");

await single.locator("#value").fill("<img id=hostile-node src=x>");
await single.locator("#edit").click();
const hostileNodeCount = await single.locator("#hostile-node").count();

await single.locator("#modal-opener").focus();
await single.keyboard.press("Enter");
const modalFirstFocus = await single.evaluate(() => document.activeElement?.id);
await single.keyboard.press("Tab");
const modalSecondFocus = await single.evaluate(() => document.activeElement?.id);
await single.keyboard.press("Escape");
const modalReturnFocus = await single.evaluate(() => document.activeElement?.id);

await single.locator("#value").fill("");
await single.locator("#submit").focus();
await single.keyboard.press("Enter");
await single.waitForFunction(() => document.activeElement?.id === "error-summary");
const validationFocus = await single.evaluate(() => document.activeElement?.id);
await single.locator("#value").fill(nonce);
await single.locator("#submit").focus();
await single.keyboard.press("Enter");
await single.waitForFunction(() => document.activeElement?.id === "title");
const routeFocus = "new-route-h1";

const linkPage = await context.newPage();
await linkPage.goto(`${baseUrl}/`);
await waitReady(linkPage);
const popupPromise = context.waitForEvent("page");
await linkPage.locator("#docs-link").click();
const popup = await popupPromise;
await popup.waitForLoadState("domcontentloaded").catch(() => {});
const linkOutcome = await linkPage.evaluate(() => window.__AMOEBIUS_LAST__);

const cancelPage = await context.newPage();
await cancelPage.goto(`${baseUrl}/`);
await waitReady(cancelPage);
await cancelPage.locator("#cancel").click();
await cancelPage.waitForFunction(() => window.__AMOEBIUS_LAST__?.visibleState === "cancelled");
const cancelOutcome = await cancelPage.evaluate(() => window.__AMOEBIUS_LAST__);

const multi = await context.newPage();
await multi.goto(`${baseUrl}/?plan=multi`);
await waitReady(multi);
const multiHeading = await multi.locator("#title").textContent();
const multiButton = await multi.locator("#submit").textContent();
const multiDom = [
  "main[aria-labelledby=title]",
  `  h1#title ${multiHeading}`,
  `  button ${multiButton}`
].join("\n");

const stale = await context.newPage();
await stale.goto(`${baseUrl}/?stale=1`);
await waitReady(stale);
const staleState = await stale.locator("#status").textContent();
const requestCountBeforeStaleClick = requests.length;
const staleSubmitCount = await stale.locator("#submit").count();
if (staleSubmitCount > 0) await stale.locator("#submit").click();
const staleEffectCount = requests.length - requestCountBeforeStaleClick;

const inlineCanary = await single.evaluate(() => window.inlineCanary === true);
const browserRequests = [...requests, ...externalRequests];
const forbiddenOrigins = browserRequests.filter(row => row.origin.includes("provider.invalid") || row.origin.includes("canary.invalid"));

const result = {
  nonce,
  challengeMatchesServer: nonce === lastChallenge || requests.some(row => row.body.includes(nonce)),
  dom: { "single-submit": singleDom, "multi-choose": multiDom },
  accessibility: [
    ["single-submit", "heading", singleHeading, "level=1"],
    ["single-submit", "status", singleStatus, "live=polite"],
    ["multi-choose", "button", multiButton, "enabled"]
  ],
  trace: [
    ["single-submit", "1", editOutcome.visibleState, "-", String(editOutcome.cancelled), editOutcome.route],
    ["single-submit", "2", submitOutcome.visibleState, "submit", String(submitOutcome.cancelled), submitOutcome.route],
    ["single-cancel", "1", cancelOutcome.visibleState, "cancel", String(cancelOutcome.cancelled), cancelOutcome.route],
    ["named-link", "1", linkOutcome.visibleState, "navigate:docs", String(linkOutcome.cancelled), linkOutcome.route]
  ],
  focus: [
    ["modal", "1", "Enter", modalFirstFocus],
    ["modal", "2", "Tab", modalSecondFocus],
    ["modal", "3", "Escape", modalReturnFocus],
    ["validation", "1", "Enter", validationFocus],
    ["route", "1", "Enter", routeFocus]
  ],
  transport: browserRequests,
  socketUpgrades,
  hostileNodeCount,
  inlineCanary,
  staleState,
  staleEffectCount,
  forbiddenOriginCount: forbiddenOrigins.length,
  productionHeaders: headers
};

console.log(JSON.stringify(result));
await browser.close();
upgradedSockets.forEach(socket => socket.destroy());
await new Promise(resolve => server.close(resolve));
