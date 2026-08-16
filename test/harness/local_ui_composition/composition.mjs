import crypto from "node:crypto";
import fs from "node:fs";
import http from "node:http";
import net from "node:net";
import { createRequire } from "node:module";
import path from "node:path";
import { spawn, spawnSync } from "node:child_process";

const root = process.cwd();
const require = createRequire(path.join(root, ".build/node_modules/loader.js"));
const { chromium } = require("playwright-core");

const role = process.argv[2] ?? "run";

if (role === "authority") {
  const [key, subject, tenant, permission, grant, epoch, nonce] = process.argv.slice(3);
  const claims = [subject, tenant, permission, grant, epoch, nonce].join("|");
  const signature = crypto.createHmac("sha256", key).update(claims).digest("hex");
  process.stdout.write(`${claims}.${signature}\n`);
  process.exit(0);
}

if (role === "domain") {
  const [portFile, logFile, capability, adapter, mutant] = process.argv.slice(3);
  let workflowNonce = "";
  let readyHandle = "";
  const server = net.createServer(socket => {
    const chunks = [];
    socket.on("data", chunk => {
      chunks.push(chunk);
      const payload = Buffer.concat(chunks).toString("utf8");
      if (socket.__handled || !payload.includes("\n")) return;
      socket.__handled = true;
      if (!payload.startsWith(`${capability}\t`)) {
        socket.end(JSON.stringify({ error: "BypassDenied" }));
        return;
      }
      const [actionCase, handler, tenant, subject, key, ...bodyParts] = payload.slice(capability.length + 1).trimEnd().split("\t");
      const bodyText = bodyParts.join("\t");
      let body = {};
      try { body = JSON.parse(bodyText); } catch {}
      if (handler === "workflow-start") {
        workflowNonce = String(body.nonce ?? "");
        append({ boundary: "ui-server", effect: `workflow-start:${workflowNonce}`, tenant, subject, adapter, key });
        if (mutant === "M-ready-before-receipt") {
          socket.end(JSON.stringify({ visible: "Artifact ready" }));
        } else {
          socket.end(JSON.stringify({ visible: "Workflow running", workId: `work:${workflowNonce}` }));
        }
        return;
      }
      if (handler === "workflow-observe" && workflowNonce) {
        readyHandle = `artifact:${tenant}:${subject}:${workflowNonce}`;
        append({ boundary: "fake-workflow", effect: `workflow-ready:${workflowNonce}`, tenant, subject, adapter, key });
        socket.end(JSON.stringify({ visible: "Artifact ready", handle: readyHandle }));
        return;
      }
      if (handler === "artifact-use" && body.handle === readyHandle) {
        append({ boundary: "ui-server", effect: `artifact-use:${workflowNonce}`, tenant, subject, adapter, key });
        const visible = mutant === "owner_key_swap" ? "Result foreign-owner-value" : `Result ${workflowNonce}`;
        socket.end(JSON.stringify({ visible, result: workflowNonce }));
        return;
      }
      socket.end(JSON.stringify({ error: "NotReady" }));
      function append(value) {
        fs.appendFileSync(logFile, `${JSON.stringify({ case: actionCase, ...value })}\n`);
      }
    });
  });
  server.listen(0, "127.0.0.1", () => fs.writeFileSync(portFile, `${server.address().port}\n`));
  process.on("SIGTERM", () => server.close(() => process.exit(0)));
} else {
  await runComposition();
}

async function runComposition() {
  const binary = process.argv[3];
  const bundle = process.argv[4];
  const mutant = process.argv[5] ?? "";
  if (!binary || !bundle) throw new Error("amoebius binary and generic bundle paths are required");
  const temporaryRoot = process.env.AMOEBIUS_TEST_TMP;
  if (!temporaryRoot) throw new Error("AMOEBIUS_TEST_TMP must name the checkout-local test root");
  fs.mkdirSync(temporaryRoot, { recursive: true });
  const temporary = fs.mkdtempSync(path.join(temporaryRoot, "run-"));
  const chromePath = process.env.AMOEBIUS_CHROMIUM;
  if (!chromePath) throw new Error("AMOEBIUS_CHROMIUM is required");
  const browser = await chromium.launch({
    executablePath: chromePath,
    headless: true,
    args: [
      "--no-sandbox", "--disable-background-networking", "--disable-component-update",
      "--disable-domain-reliability", "--disable-sync", "--disable-default-apps",
      "--disable-client-side-phishing-detection",
      "--disable-features=MediaRouter,OptimizationHints,AutofillServerCommunication,AsyncDns,DnsOverHttps",
      "--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE 127.0.0.1", "--dns-prefetch-disable",
      "--metrics-recording-only", "--no-first-run", "--safebrowsing-disable-auto-update"
    ]
  });
  try {
    const single = await runApplication({ binary, bundle, browser, temporary, mode: "single", adapter: "infernix-shaped", mutant });
    const multi = await runApplication({ binary, bundle, browser, temporary, mode: "multi", adapter: "jitML-shaped", mutant });
    const result = {
      applications: [single.application, multi.application],
      visible: [...single.visible, ...multi.visible],
      singleEffects: single.effects,
      multiEffects: multi.effects,
      denials: multi.denials,
      freshNonce: single.nonce,
      genericBundleDigest: crypto.createHash("sha256").update(fs.readFileSync(bundle)).digest("hex"),
      browserOrigins: [...single.browserOrigins, ...multi.browserOrigins],
      directBypass: multi.directBypass,
      privateByteCount: multi.privateByteCount
    };
    if (mutant) {
      const locus = mutantLocus(mutant, result);
      if (locus) {
        process.stdout.write(`local-ui-composition-mutant: RED ${mutant} ${locus}\n`);
        process.exitCode = 1;
        return;
      }
    }
    process.stdout.write(`${JSON.stringify(result)}\n`);
  } finally {
    await browser.close();
    fs.rmSync(temporary, { recursive: true, force: true });
  }
}

async function runApplication(options) {
  const { binary, bundle, browser, temporary, mode, adapter, mutant } = options;
  const prefix = path.join(temporary, mode);
  const domainPortFile = `${prefix}.domain.port`;
  const domainLog = `${prefix}.domain.log`;
  const serverPortFile = `${prefix}.server.port`;
  const auditFile = `${prefix}.audit.log`;
  const planFile = `${prefix}.plan.json`;
  const challengeFile = `${prefix}.challenge`;
  const signingKey = crypto.randomBytes(32).toString("hex");
  const sessionNonce = crypto.randomBytes(24).toString("hex");
  const digest = `composition-${mode}-v1`;
  const planDigest = mutant === "M-mix-client-server-plan" && mode === "single" ? `${digest}-server-swap` : digest;
  fs.writeFileSync(planFile, JSON.stringify({
    digest, mode: mode === "single" ? "single-tenant" : "multi-tenant",
    routes: ["home", "workflow"], events: ["start", "observe", "use-artifact"]
  }));
  const domain = spawn(process.execPath, [process.argv[1], "domain", domainPortFile, domainLog, signingKey, adapter, mutant], {
    stdio: ["ignore", "pipe", "pipe"]
  });
  let server;
  let serverErrors = "";
  try {
    await waitForFile(domainPortFile, domain);
    server = spawn(binary, [
      "serve-ui", "--port-file", serverPortFile, "--handler-port-file", domainPortFile,
      "--signing-key", signingKey, "--current-epoch", "7", "--session-nonce", sessionNonce,
      "--audit-file", auditFile, "--client-plan-file", planFile, "--plan-digest", planDigest,
      "--challenge-file", challengeFile, "--ui-bundle-file", bundle
    ], { stdio: ["ignore", "pipe", "pipe"] });
    server.stderr.on("data", chunk => { serverErrors += chunk.toString("utf8"); });
    await waitForFile(serverPortFile, server);
    const port = Number(fs.readFileSync(serverPortFile, "utf8").trim());
    const nonce = crypto.randomBytes(20).toString("hex");
    fs.writeFileSync(challengeFile, `${nonce}\n`);
    const own = mint(signingKey, "alice", "tenant-a", "write", "active", "7", sessionNonce);
    const bob = mint(signingKey, "bob", "tenant-a", "write", "active", "7", sessionNonce);
    const carol = mint(signingKey, "carol", "tenant-b", "write", "active", "7", sessionNonce);
    const context = await browser.newContext({ extraHTTPHeaders: { Authorization: `Bearer ${own}` } });
    const page = await context.newPage();
    const browserOrigins = [];
    const actionResponses = [];
    const pageErrors = [];
    page.on("request", request => browserOrigins.push(new URL(request.url()).origin));
    page.on("requestfailed", request => pageErrors.push(`${request.url()} ${request.failure()?.errorText}`));
    page.on("pageerror", error => pageErrors.push(String(error)));
    page.on("console", message => { if (message.type() === "error") pageErrors.push(message.text()); });
    page.on("response", async response => {
      if (response.url().includes("/ui/action/")) {
        actionResponses.push({ url: response.url(), status: response.status(), body: await response.text().catch(() => "<unreadable>") });
      }
    });
    await page.goto(`http://127.0.0.1:${port}/`);
    try {
      await page.waitForFunction(() => window.__AMOEBIUS_READY__ === true, null, { timeout: 5000 });
    } catch {
      throw new Error(`browser did not become ready for ${mode}/${mutant}: ${JSON.stringify(pageErrors)} server=${serverErrors}`);
    }
    const initialStatus = await page.locator("#status").textContent();
    if (initialStatus === "ReloadRequired") {
      await context.close();
      return {
        application: { mode, adapter, digest, events: ["start", "observe", "use-artifact"] },
        visible: [{ case: mode, step: "1", visible: initialStatus }],
        nonce,
        effects: [],
        multiEffects: [],
        denials: [],
        browserOrigins: [...new Set(browserOrigins)],
        directBypass: "network-denied",
        privateByteCount: 0
      };
    }
    await page.locator("#value").fill(nonce);
    await page.locator("#start").click();
    const firstExpected = mutant === "M-ready-before-receipt" ? "Artifact ready" : "Workflow running";
    await page.waitForFunction(expected => document.querySelector("#status")?.textContent === expected, firstExpected);
    const visible = [{ case: mode, step: "1", visible: await page.locator("#status").textContent() }];
    await page.locator("#observe").click();
    await page.waitForFunction(() => document.querySelector("#status")?.textContent === "Artifact ready");
    visible.push({ case: mode, step: "2", visible: await page.locator("#status").textContent() });
    await page.locator("#use-artifact").click();
    const finalExpected = mutant === "owner_key_swap" ? "Result foreign-owner-value" : `Result ${nonce}`;
    await page.waitForTimeout(300);
    const finalActual = await page.locator("#status").textContent();
    if (finalActual !== finalExpected) {
      throw new Error(`artifact result mismatch: expected ${finalExpected}, got ${finalActual}; effects=${JSON.stringify(readJsonLines(domainLog))}; responses=${JSON.stringify(actionResponses)}`);
    }
    visible.push({ case: mode, step: "3", visible: await page.locator("#status").textContent() });
    await context.close();

    const effectsBeforeDenials = readJsonLines(domainLog);
    const denials = [];
    let directBypass = "network-denied";
    let privateByteCount = 0;
    if (mode === "multi") {
      const copiedHandle = `artifact:tenant-a:alice:${nonce}`;
      const foreignToken = mutant === "M-drop-handle-tenant" ? own : carol;
      denials.push(await actionRequest("foreign-tenant", port, foreignToken, "/ui/action/use-artifact", copiedHandle, {}));
      denials.push(await actionRequest("same-tenant-foreign", port, bob, "/ui/action/use-artifact", copiedHandle, {}));
      denials.push(await actionRequest("caller-tenant-header", port, carol, "/ui/action/use-artifact", copiedHandle, { "X-Tenant": "tenant-a" }));
      denials.push(await actionRequest("non-ready-handle", port, own, "/ui/action/use-artifact", "artifact:not-ready", {}));
      const bypassCount = readJsonLines(domainLog).length;
      if (mutant === "M-direct-workflow-fetch") {
        await rawDomainBypass(Number(fs.readFileSync(domainPortFile, "utf8").trim()), signingKey, nonce);
        directBypass = "provider-bytes";
      } else {
        const bypassContext = await browser.newContext({ extraHTTPHeaders: { Authorization: `Bearer ${own}` } });
        const bypassPage = await bypassContext.newPage();
        await bypassPage.goto(`http://127.0.0.1:${port}/`);
        await bypassPage.waitForFunction(() => window.__AMOEBIUS_READY__ === true);
        directBypass = await bypassPage.evaluate(async backend => {
          try { await fetch(backend); return "provider-bytes"; } catch { return "network-denied"; }
        }, `http://127.0.0.1:${fs.readFileSync(domainPortFile, "utf8").trim()}/workflow`);
        await bypassContext.close();
      }
      const effectsAfterBypass = readJsonLines(domainLog);
      if (mutant !== "M-direct-workflow-fetch" && effectsAfterBypass.length !== bypassCount) directBypass = "provider-bytes";
      privateByteCount = denials.filter(row => row.body.includes(nonce)).length;
      visible.push({ case: "multi", step: "2", visible: denials[0].tag });
    }
    const allEffects = readJsonLines(domainLog);
    return {
      application: { mode, adapter, digest, events: ["start", "observe", "use-artifact"] }, visible, nonce,
      effects: effectsBeforeDenials,
      multiEffects: allEffects,
      denials,
      browserOrigins: [...new Set(browserOrigins)],
      directBypass,
      privateByteCount
    };
  } finally {
    if (server?.exitCode === null) server.kill("SIGTERM");
    if (domain.exitCode === null) domain.kill("SIGTERM");
    await Promise.all([server, domain].filter(Boolean).map(waitForExit));
  }
}

function actionRequest(caseName, port, token, target, handle, extraHeaders) {
  const body = JSON.stringify({ event: "use-artifact", handle });
  return new Promise((resolve, reject) => {
    const request = http.request({
      hostname: "127.0.0.1", port, method: "POST", path: target,
      headers: {
        Authorization: `Bearer ${token}`, Origin: "same-origin", "X-CSRF": "csrf-v1",
        "X-Authority-Epoch": "7", "Idempotency-Key": `${caseName}-key`,
        "Content-Type": "application/json", ...extraHeaders
      }
    }, response => {
      const chunks = [];
      response.on("data", chunk => chunks.push(chunk));
      response.on("end", () => resolve({
        case: caseName, status: String(response.statusCode),
        tag: response.headers["x-amoebius-result"] ?? "", body: Buffer.concat(chunks).toString("utf8")
      }));
    });
    request.on("error", reject);
    request.end(body);
  });
}

function rawDomainBypass(port, capability, nonce) {
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({ host: "127.0.0.1", port }, () => {
      socket.write(`${capability}\tdirect\tworkflow-start\ttenant-a\talice\tdirect-key\t${JSON.stringify({ nonce })}\n`);
    });
    socket.on("data", () => {});
    socket.on("close", resolve);
    socket.on("error", reject);
  });
}

function mint(...claims) {
  const result = spawnSync(process.execPath, [process.argv[1], "authority", ...claims], { encoding: "utf8" });
  if (result.status !== 0) throw new Error(`authority failed: ${result.stderr}`);
  return result.stdout.trim();
}

function readJsonLines(file) {
  if (!fs.existsSync(file)) return [];
  return fs.readFileSync(file, "utf8").trim().split("\n").filter(Boolean).map(JSON.parse);
}

function mutantLocus(mutant, result) {
  const multiForeign = result.denials.find(row => row.case === "foreign-tenant");
  const loci = {
    // Any 2xx means the foreign tenant's copied handle was accepted. Naming one success
    // code made the detector miss the attack it exists to catch: `use-artifact` is a
    // mutation, so the boundary answers 202, and a predicate looking only for 200 reported
    // the mutant as surviving-undetected rather than as caught.
    "M-drop-handle-tenant": () => Number(multiForeign?.status) >= 200
      && Number(multiForeign?.status) < 300 && "copied-handle-scope",
    "M-direct-workflow-fetch": () => result.directBypass === "provider-bytes" && "browser-backend-edge",
    "M-mix-client-server-plan": () => result.visible.some(row => row.visible === "ReloadRequired") && "plan-pair-digest",
    "M-ready-before-receipt": () => result.visible.some(row => row.step === "1" && row.visible === "Artifact ready") && "ready-order",
    "owner_key_swap": () => result.visible.some(row => row.visible.includes("foreign-owner-value")) && "owner-key-dom"
  };
  return loci[mutant]?.() || "";
}

async function waitForFile(file, child) {
  const deadline = Date.now() + 4000;
  while (Date.now() < deadline) {
    if (fs.existsSync(file) && fs.readFileSync(file, "utf8").trim()) return;
    if (child.exitCode !== null) throw new Error(`process exited before writing ${file}`);
    await new Promise(resolve => setTimeout(resolve, 20));
  }
  throw new Error(`timed out waiting for ${file}`);
}

function waitForExit(child) {
  if (!child || child.exitCode !== null) return Promise.resolve();
  return new Promise(resolve => {
    child.once("exit", resolve);
    setTimeout(() => { if (child.exitCode === null) child.kill("SIGKILL"); resolve(); }, 500);
  });
}
