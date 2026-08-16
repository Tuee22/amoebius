import crypto from "node:crypto";
import fs from "node:fs";
import http from "node:http";
import net from "node:net";
import path from "node:path";
import { spawn, spawnSync } from "node:child_process";

const role = process.argv[2] ?? "run";

if (role === "authority") {
  const [key, subject, tenant, permission, grant, epoch, nonce] = process.argv.slice(3);
  const claims = [subject, tenant, permission, grant, epoch, nonce].join("|");
  const signature = crypto.createHmac("sha256", key).update(claims).digest("hex");
  process.stdout.write(`${claims}.${signature}\n`);
  process.exit(0);
}

if (role === "handler") {
  const [portFile, logFile, capability] = process.argv.slice(3);
  const server = net.createServer(socket => {
    const chunks = [];
    socket.on("data", chunk => {
      chunks.push(chunk);
      const payload = Buffer.concat(chunks).toString("utf8");
      if (!socket.__handled && payload.includes("\n")) {
        socket.__handled = true;
        if (payload.startsWith(`${capability}\t`)) {
          fs.appendFileSync(logFile, payload.slice(capability.length + 1));
        }
        socket.end("{}");
      }
    });
  });
  server.listen(0, "127.0.0.1", () => fs.writeFileSync(portFile, `${server.address().port}\n`));
  process.on("SIGTERM", () => server.close(() => process.exit(0)));
} else {
  await runBoundary();
}

async function runBoundary() {
  const binary = process.argv[3];
  const mutant = process.argv[4] ?? "";
  if (!binary) throw new Error("amoebius binary path is required");

  const temporaryRoot = process.env.AMOEBIUS_TEST_TMP;
  if (!temporaryRoot) throw new Error("AMOEBIUS_TEST_TMP must name the checkout-local test root");
  fs.mkdirSync(temporaryRoot, { recursive: true });
  const temporary = fs.mkdtempSync(path.join(temporaryRoot, "run-"));
  const handlerPortFile = path.join(temporary, "handler.port");
  const handlerLog = path.join(temporary, "handler.log");
  const serverPortFile = path.join(temporary, "server.port");
  const auditFile = path.join(temporary, "audit.log");
  const signingKey = crypto.randomBytes(32).toString("hex");
  const sessionNonce = crypto.randomBytes(24).toString("hex");
  const handler = spawn(process.execPath, [process.argv[1], "handler", handlerPortFile, handlerLog, signingKey], {
    stdio: ["ignore", "pipe", "pipe"]
  });
  let server;
  const startupChildren = [];
  try {
    await waitForFile(handlerPortFile, handler);
    server = spawnServer(binary, {
      portFile: serverPortFile,
      handlerPortFile,
      signingKey,
      sessionNonce,
      auditFile,
      mutant
    });
    await waitForFile(serverPortFile, server);
    const port = Number(fs.readFileSync(serverPortFile, "utf8").trim());
    const own = mint(signingKey, "alice", "tenant-a", "write", "active", "7", sessionNonce);
    const foreign = mint(signingKey, "alice", "tenant-b", "write", "active", "7", sessionNonce);
    const revoked = mint(signingKey, "alice", "tenant-a", "write", "revoked", "7", sessionNonce);
    const freshNonce = crypto.randomBytes(20).toString("hex");
    const common = token => ({
      Authorization: `Bearer ${token}`,
      Origin: "same-origin",
      "X-CSRF": "csrf-v1",
      "X-Authority-Epoch": "7"
    });

    const httpRows = [];
    httpRows.push(await observedRequest("client-plan", port, "GET", "/ui/client-plan", {}, ""));
    httpRows.push(await observedRequest("read-own", port, "POST", "/ui/action/read", {
      ...common(own), "Idempotency-Key": "read-key"
    }, freshNonce));
    httpRows.push(await observedRequest("read-foreign", port, "POST", "/ui/action/read", {
      ...common(foreign), "X-Tenant": "tenant-a", "Idempotency-Key": "foreign-key"
    }, freshNonce));
    httpRows.push(await observedRequest("mutate-own", port, "POST", "/ui/action/mutate", {
      ...common(own), "Idempotency-Key": "mutation-key"
    }, freshNonce));
    const replay = await observedRequest("mutate-replay", port, "POST", "/ui/action/mutate", {
      ...common(own), "Idempotency-Key": "mutation-key"
    }, freshNonce);
    httpRows.push(await observedRequest("bad-origin", port, "POST", "/ui/action/mutate", {
      ...common(own), Origin: "https://evil.invalid", "Idempotency-Key": "origin-key"
    }, freshNonce));
    httpRows.push(await observedRequest("stale", port, "POST", "/ui/action/mutate", {
      ...common(own), "X-Authority-Epoch": "6", "Idempotency-Key": "stale-key"
    }, freshNonce));
    httpRows.push(await observedRequest("server-plan-probe", port, "GET", "/ui/server-plan/known-digest", {
      Authorization: `Bearer ${own}`
    }, ""));
    const revokedRow = await observedRequest("revoked", port, "POST", "/ui/action/mutate", {
      ...common(revoked), "Idempotency-Key": "revoked-key"
    }, freshNonce);

    const publicPaths = ["/", "/index.html", "/ui.js", "/ui.css", "/ui/client-plan"];
    const publicAssets = [];
    for (const publicPath of publicPaths) {
      publicAssets.push(await observedRequest(publicPath, port, "GET", publicPath, {}, ""));
    }
    const forbiddenPaths = [
      "/ui/server-plan",
      "/ui/server-plan/known-digest",
      "/assets/server-plan.json",
      "/ui/dispatch-table",
      "/ui/server-plan/known-digest?download=1"
    ];
    const privateProbes = [];
    for (const forbiddenPath of forbiddenPaths) {
      privateProbes.push(await observedRequest(forbiddenPath, port, "GET", forbiddenPath, {
        Authorization: `Bearer ${own}`, Accept: "application/json"
      }, ""));
    }

    await directHandlerProbe(Number(fs.readFileSync(handlerPortFile, "utf8").trim()));
    const websocket = [];
    websocket.push(await websocketRequest("wrong-origin", port, own, sessionNonce, { Origin: "https://evil.invalid" }));
    websocket.push(await websocketRequest("stale-program", port, own, sessionNonce, { "X-Program": "plan-old" }));
    websocket.push(await websocketRequest("cross-scope", port, own, sessionNonce, { "X-Scope": "tenant-b", "X-Envelope-Scope": "tenant-b" }));
    websocket.push(await websocketRequest("missing-envelope", port, own, sessionNonce, { "X-Envelope-Stream": "" }));
    websocket.push(await websocketRequest("valid", port, own, sessionNonce, {}));
    websocket.push(await websocketRequest("replayed-nonce", port, own, sessionNonce, {}));

    const coordinatorPortFile = path.join(temporary, "coordinator-loss.port");
    const coordinatorChild = spawnServer(binary, {
      portFile: coordinatorPortFile, handlerPortFile, signingKey, sessionNonce,
      auditFile: path.join(temporary, "coordinator-loss.audit"), mutant,
      extra: ["--coordinator", "unavailable"]
    });
    startupChildren.push(coordinatorChild);
    await waitForFile(coordinatorPortFile, coordinatorChild);
    websocket.push(await websocketRequest(
      "coordinator-loss",
      Number(fs.readFileSync(coordinatorPortFile, "utf8").trim()),
      own,
      sessionNonce,
      {}
    ));
    coordinatorChild.kill("SIGTERM");

    const startup = [{ case: "canonical", ready: true }];
    for (const startupCase of [
      ["missing", ["--registry-count", "0"]],
      ["duplicate", ["--registry-count", "2"]],
      ["contract-mismatch", ["--handler-contract", "mismatch"]],
      ["abi-mismatch", ["--abi", "ui-server-v0"]]
    ]) {
      const [caseName, extra] = startupCase;
      const childPortFile = path.join(temporary, `${caseName}.port`);
      const childAudit = path.join(temporary, `${caseName}.audit`);
      const child = spawnServer(binary, {
        portFile: childPortFile, handlerPortFile, signingKey, sessionNonce,
        auditFile: childAudit, mutant, extra
      });
      startupChildren.push(child);
      const ready = await waitForReadyOrExit(childPortFile, child, 800);
      startup.push({ case: caseName, ready });
      if (ready) child.kill("SIGTERM");
    }

    await waitFor(() => fs.existsSync(handlerLog), 1000).catch(() => {});
    await new Promise(resolve => setTimeout(resolve, 100));
    const effects = readEffects(handlerLog);
    const audits = fs.existsSync(auditFile) ? fs.readFileSync(auditFile, "utf8").trim().split("\n").filter(Boolean) : [];
    const result = {
      freshNonce,
      http: httpRows,
      replay,
      revoked: revokedRow,
      effects,
      audits,
      publicAssets,
      privateProbes,
      websocket,
      startup,
      authorityProcesses: 3,
      handlerProcessObserved: effects.some(row => row.body.includes(freshNonce)),
      privateCanaryCount: privateProbes.filter(row => row.body.includes("private-canary")).length
    };

    if (mutant) {
      const locus = mutantLocus(mutant, result);
      if (locus) {
        process.stdout.write(`ui-server-boundary-mutant: RED ${mutant} ${locus}\n`);
        process.exitCode = 1;
        return;
      }
    }
    process.stdout.write(`${JSON.stringify(result)}\n`);
  } finally {
    if (server && server.exitCode === null) server.kill("SIGTERM");
    for (const child of startupChildren) if (child.exitCode === null) child.kill("SIGTERM");
    if (handler.exitCode === null) handler.kill("SIGTERM");
    await Promise.all([server, handler, ...startupChildren].filter(Boolean).map(waitForExit));
    fs.rmSync(temporary, { recursive: true, force: true });
  }
}

function spawnServer(binary, options) {
  const args = [
    "serve-ui",
    "--port-file", options.portFile,
    "--handler-port-file", options.handlerPortFile,
    "--signing-key", options.signingKey,
    "--current-epoch", "7",
    "--session-nonce", options.sessionNonce,
    "--audit-file", options.auditFile,
    ...(options.extra ?? [])
  ];
  return spawn(binary, args, {
    env: { ...process.env, AMOEBIUS_PHASE22_MUTANT: options.mutant ?? "" },
    stdio: ["ignore", "pipe", "pipe"]
  });
}

function mint(...claims) {
  const result = spawnSync(process.execPath, [process.argv[1], "authority", ...claims], { encoding: "utf8" });
  if (result.status !== 0) throw new Error(`authority failed: ${result.stderr}`);
  return result.stdout.trim();
}

function observedRequest(caseName, port, method, target, headers, body) {
  return new Promise((resolve, reject) => {
    const request = http.request({ hostname: "127.0.0.1", port, method, path: target, headers }, response => {
      const chunks = [];
      response.on("data", chunk => chunks.push(chunk));
      response.on("end", () => resolve({
        case: caseName,
        status: response.statusCode,
        tag: response.headers["x-amoebius-result"] ?? "",
        body: Buffer.concat(chunks).toString("utf8"),
        headers: response.headers
      }));
    });
    request.on("error", reject);
    request.end(body);
  });
}

function websocketRequest(caseName, port, token, nonce, overrides) {
  const fields = {
    Host: `127.0.0.1:${port}`,
    Upgrade: "websocket",
    Connection: "Upgrade",
    Authorization: `Bearer ${token}`,
    Origin: "same-origin",
    "Sec-WebSocket-Key": crypto.randomBytes(16).toString("base64"),
    "Sec-WebSocket-Version": "13",
    "Sec-WebSocket-Protocol": "amoebius-ui-v1",
    "X-Session-Nonce": nonce,
    "X-Program": "plan-single-v1",
    "X-ABI": "ui-server-v1",
    "X-Scope": "tenant-a",
    "X-Envelope-Application": "app-a",
    "X-Envelope-Session": "session-a",
    "X-Envelope-Subject-Epoch": "7",
    "X-Envelope-Scope": "tenant-a",
    "X-Envelope-Scope-Epoch": "7",
    "X-Envelope-Program": "plan-single-v1",
    "X-Envelope-ABI": "ui-server-v1",
    "X-Envelope-Stream": "stream-a",
    "X-Envelope-Cursor": "0",
    ...overrides
  };
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({ host: "127.0.0.1", port });
    const chunks = [];
    socket.on("connect", () => {
      const headers = Object.entries(fields).map(([name, value]) => `${name}: ${value}`).join("\r\n");
      socket.write(`GET /ui/socket HTTP/1.1\r\n${headers}\r\n\r\n`);
    });
    socket.on("data", chunk => chunks.push(chunk));
    socket.on("end", finish);
    socket.on("close", finish);
    socket.on("error", reject);
    function finish() {
      if (socket.__finished) return;
      socket.__finished = true;
      const line = Buffer.concat(chunks).toString("utf8").split("\r\n", 1)[0] ?? "";
      const status = Number(line.split(" ")[1] ?? 0);
      resolve({ case: caseName, status });
    }
  });
}

function directHandlerProbe(port) {
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({ host: "127.0.0.1", port }, () => socket.end("caller-spoof\tdirect-effect\n"));
    socket.on("data", () => {});
    socket.on("close", resolve);
    socket.on("error", reject);
  });
}

function readEffects(logFile) {
  if (!fs.existsSync(logFile)) return [];
  return fs.readFileSync(logFile, "utf8").trim().split("\n").filter(Boolean).map(line => {
    const [caseName, handler, tenant, subject, key, ...body] = line.split("\t");
    return { case: caseName, handler, tenant, subject, key, body: body.join("\t") };
  });
}

function mutantLocus(mutant, result) {
  const httpByCase = new Map(result.http.map(row => [row.case, row]));
  const effects = result.effects;
  const startup = new Map(result.startup.map(row => [row.case, row.ready]));
  const loci = {
    "M-trust-tenant-header": () => httpByCase.get("read-foreign")?.status === 200 && "foreign-token-spoof",
    "M-dispatch-before-authorize": () => effects.length > 2 && "zero-denied-handler-bytes",
    "M-skip-current-epoch": () => httpByCase.get("stale")?.status === 202 && "stale-epoch",
    "M-disable-origin-check": () => httpByCase.get("bad-origin")?.status === 202 && "origin-denial",
    "M-drop-csp-header": () => !httpByCase.get("client-plan")?.headers["content-security-policy"] && "security-header",
    "M-ready-with-unresolved-handler": () => startup.get("missing") === true && "missing-handler-readiness",
    "M-server-first-handler-wins": () => startup.get("duplicate") === true && "duplicate-handler-readiness",
    "M-serve-server-plan-as-client-asset": () => result.privateCanaryCount > 0 && "private-plan-probe",
    "M-new-idempotency-key-on-retry": () => effects.filter(row => row.handler === "data-write").length > 1 && "idempotent-replay"
  };
  return loci[mutant]?.() || "";
}

async function waitForFile(file, child) {
  await waitFor(() => {
    if (child.exitCode !== null) throw new Error(`process exited before writing ${file}`);
    return fs.existsSync(file) && fs.readFileSync(file, "utf8").trim() !== "";
  }, 3000);
}

async function waitForReadyOrExit(file, child, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (fs.existsSync(file)) return true;
    if (child.exitCode !== null) return false;
    await new Promise(resolve => setTimeout(resolve, 20));
  }
  return fs.existsSync(file);
}

async function waitFor(predicate, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (predicate()) return;
    await new Promise(resolve => setTimeout(resolve, 20));
  }
  throw new Error("timed out waiting for boundary process");
}

function waitForExit(child) {
  if (!child || child.exitCode !== null) return Promise.resolve();
  return new Promise(resolve => {
    child.once("exit", resolve);
    setTimeout(() => {
      if (child.exitCode === null) child.kill("SIGKILL");
      resolve();
    }, 500);
  });
}
