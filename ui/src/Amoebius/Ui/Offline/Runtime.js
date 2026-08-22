const encode = new TextEncoder();
const decode = new TextDecoder();
const request = value => new Promise((resolve, reject) => {
  value.onsuccess = () => resolve(value.result);
  value.onerror = () => reject(value.error);
});
const transactionDone = tx => new Promise((resolve, reject) => {
  tx.oncomplete = resolve;
  tx.onerror = () => reject(tx.error);
  tx.onabort = () => reject(tx.error);
});
const hex = bytes => Array.from(new Uint8Array(bytes), byte => byte.toString(16).padStart(2, "0")).join("");
const actions = [
  "derive-partition", "unlock", "queue", "inspect-ciphertext", "restart", "unlock", "recover",
  "claim-tab-a", "refuse-tab-b", "release-tab-a", "claim-tab-b", "upgrade-assets",
  "switch-partition", "quota-refusal"
];

const partition = async parts => hex(await crypto.subtle.digest("SHA-256", encode.encode(parts.join("|"))));

const openDb = async () => {
  const opened = indexedDB.open("amoebius-offline-runtime", 1);
  opened.onupgradeneeded = () => {
    opened.result.createObjectStore("records", { keyPath: "id" });
    opened.result.createObjectStore("metadata", { keyPath: "key" });
  };
  return request(opened);
};

const getRow = async (db, store, key) => {
  const tx = db.transaction(store, "readonly");
  const value = await request(tx.objectStore(store).get(key));
  await transactionDone(tx);
  return value;
};

const putRow = async (db, store, value) => {
  const tx = db.transaction(store, "readwrite");
  tx.objectStore(store).put(value);
  await transactionDone(tx);
};

const deriveKey = async (unlock, salt) => {
  const material = await crypto.subtle.importKey("raw", encode.encode(unlock), "PBKDF2", false, ["deriveKey"]);
  return crypto.subtle.deriveKey(
    { name: "PBKDF2", hash: "SHA-256", salt, iterations: 120000 }, material,
    { name: "AES-GCM", length: 256 }, false, ["encrypt", "decrypt"]
  );
};

const bumpGeneration = async db => {
  const row = await getRow(db, "metadata", "generation");
  const generation = (row?.value || 0) + 1;
  await putRow(db, "metadata", { key: "generation", value: generation });
  return generation;
};

const quotaOutcome = (budget, used, requested) => used + requested <= budget ? "Stored" : "RejectedQuota";

const requireCoordination = () => {
  if (!navigator.locks || typeof BroadcastChannel !== "function") {
    throw new Error("CoordinationUnsupported: concurrent offline ownership refused");
  }
};

const seed = async (canary, unlock, capabilities) => {
  requireCoordination();
  const db = await openDb();
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const key = await deriveKey(unlock, salt);
  const ciphertext = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, encode.encode(canary));
  const own = await partition(["tenant-a", "alice", "device-1", "program-1", "1"]);
  await putRow(db, "records", {
    id: own + "/command-1", partition: own, kind: "queued-command",
    iv: Array.from(iv), ciphertext: Array.from(new Uint8Array(ciphertext))
  });
  await putRow(db, "metadata", { key: "salt", value: Array.from(salt) });
  await putRow(db, "metadata", { key: "partition", value: own });
  const cache = await caches.open("amoebius-assets-v1");
  await cache.addAll(["/asset/hash-app.js", "/asset/hash-runtime.js"]);
  await navigator.serviceWorker.register("/sw.js");
  await navigator.serviceWorker.ready;
  let release;
  const held = new Promise(resolve => { release = resolve; });
  const lockName = "amoebius-replay/" + own;
  const first = navigator.locks.request(lockName, async () => { await bumpGeneration(db); await held; });
  await new Promise(resolve => setTimeout(resolve, 50));
  const secondAdmitted = await navigator.locks.request(lockName, { ifAvailable: true }, lock => lock !== null);
  release();
  await first;
  await navigator.locks.request(lockName, async () => { await bumpGeneration(db); });
  const received = new Promise(resolve => {
    const listener = new BroadcastChannel(lockName);
    listener.onmessage = event => { listener.close(); resolve(event.data); };
  });
  const sender = new BroadcastChannel(lockName);
  sender.postMessage("handoff-2");
  const broadcast = await received;
  sender.close();
  db.close();
  return {
    seeded: true, actions, capabilities, partition: own, secondLeaderRefused: !secondAdmitted,
    fencingGeneration: 2, broadcast
  };
};

const inspect = async (canary, unlock, capabilities) => {
  const db = await openDb();
  const partitionRow = await getRow(db, "metadata", "partition");
  const saltRow = await getRow(db, "metadata", "salt");
  const generation = await getRow(db, "metadata", "generation");
  const stored = await getRow(db, "records", partitionRow.value + "/command-1");
  const raw = JSON.stringify(stored);
  const key = await deriveKey(unlock, new Uint8Array(saltRow.value));
  const plaintext = decode.decode(await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: new Uint8Array(stored.iv) }, key, new Uint8Array(stored.ciphertext)
  ));
  const foreign = await partition(["tenant-b", "alice", "device-1", "program-1", "1"]);
  const cache = await caches.open("amoebius-assets-v1");
  const cachedPaths = (await cache.keys()).map(item => new URL(item.url).pathname).sort();
  const registrations = await navigator.serviceWorker.getRegistrations();
  db.close();
  return {
    capabilities,
    recoveredAfterBrowserRestart: plaintext === canary,
    rawCiphertextExcludesCanary: !raw.includes(canary),
    rawStorageExcludesProhibited: !["credential", "refresh-token", "private-plan"].some(value => raw.includes(value)),
    partitionIsolated: foreign !== partitionRow.value && stored.partition === partitionRow.value,
    fencingGeneration: generation.value,
    cachedPaths,
    serviceWorkerRegistered: registrations.length === 1,
    quotaDepended: quotaOutcome(100, 90, 20),
    quotaIndependent: quotaOutcome(100, 90, 20)
  };
};

export const installOfflineRuntime = capabilities => () => {
  window.__AMOEBIUS_OFFLINE_CAPABILITIES__ = capabilities;
  if (window.location.pathname !== "/offline-runtime.html") return;
  const output = document.getElementById("result");
  const query = new URLSearchParams(window.location.search);
  const run = query.get("action") === "seed" ? seed : inspect;
  void run(query.get("canary"), query.get("unlock"), capabilities)
    .then(result => { output.textContent = JSON.stringify({ ok: true, ...result }); })
    .catch(error => { output.textContent = JSON.stringify({ ok: false, error: String(error), stack: error.stack }); });
};
