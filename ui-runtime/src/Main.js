const append = (parent, tag, attributes = {}) => {
  const element = document.createElement(tag);
  Object.entries(attributes).forEach(([name, value]) => {
    if (name === "text") element.textContent = value;
    else element.setAttribute(name, value);
  });
  parent.appendChild(element);
  return element;
};

const fetchJson = async (path, options = {}) => {
  const response = await fetch(path, options);
  if (!response.ok) throw new Error(`request failed: ${response.status}`);
  return response.json();
};

export const install = transition => headingFor => statusFor => () => {
  const bootstrap = async () => {
    const query = window.location.search;
    const plan = await fetchJson(`/ui/client-plan${query}`);
    const current = await fetchJson(`/ui/current-digest${query}`);
    const main = append(document.body, "main", { "aria-labelledby": "title" });
    const title = append(main, "h1", { id: "title", text: headingFor(plan.routes[0]) });
    title.tabIndex = -1;
    const errorSummary = append(main, "div", { id: "error-summary", role: "alert", text: "Validation error" });
    errorSummary.tabIndex = -1;
    errorSummary.hidden = true;
    const input = append(main, "input", { id: "value", "aria-label": "Value" });
    const edit = append(main, "button", { id: "edit", text: "Edit" });
    const submit = append(main, "button", { id: "submit", text: "Submit" });
    const cancel = append(main, "button", { id: "cancel", text: "Cancel" });
    const docs = append(main, "button", { id: "docs-link", text: "Documentation" });
    const modalOpener = append(main, "button", { id: "modal-opener", text: "Open modal" });
    const modal = append(main, "div", { id: "modal", role: "dialog", "aria-modal": "true" });
    modal.hidden = true;
    const modalFirst = append(modal, "button", { id: "modal-first-control", text: "First" });
    const modalSecond = append(modal, "button", { id: "modal-second-control", text: "Second" });
    const status = append(main, "div", { id: "status", role: "status", "aria-live": "polite", text: "ready" });
    const workflowButtons = (plan.events || [])
      .filter(event => ["start", "observe", "use-artifact"].includes(event))
      .map(event => [event, append(main, "button", { id: event, text: event })]);
    let state = "home";
    let challenge = "";
    let readyHandle = "";
    let socket;

    if (plan.digest !== current.digest) {
      state = "ReloadRequired";
      status.textContent = statusFor(state)(challenge);
      window.__AMOEBIUS_READY__ = true;
      return;
    }

    const challengeResponse = await fetchJson("/ui/challenge");
    challenge = challengeResponse.nonce;
    window.__AMOEBIUS_CHALLENGE__ = challenge;
    const socketProtocol = window.location.protocol === "https:" ? "wss:" : "ws:";
    socket = new WebSocket(`${socketProtocol}//${window.location.host}/ui/socket`);

    const apply = async event => {
      const outcome = transition(state)(event)(input.value);
      state = outcome.visibleState;
      errorSummary.hidden = outcome.focus !== "error-summary";
      if (outcome.route === "workflow") title.textContent = headingFor("workflow");
      if (outcome.effect.indexOf("POST ") === 0) {
        const path = outcome.effect.slice(5);
        const response = await fetch(path, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-CSRF": "csrf-v1",
            "X-Authority-Epoch": "7",
            "Idempotency-Key": `${event}-${challenge}`
          },
          body: JSON.stringify({ nonce: input.value || challenge, event, handle: readyHandle })
        });
        const payload = await response.json().catch(() => ({}));
        if (payload.handle) readyHandle = payload.handle;
        if (!response.ok) {
          outcome.visibleState = response.status === 404
            ? "Unavailable"
            : (response.headers.get("X-Amoebius-Result") || "Unavailable");
        } else if (payload.visible) outcome.visibleState = payload.visible;
      }
      state = outcome.visibleState;
      status.textContent = statusFor(state)(challenge);
      const focusTarget = outcome.focus === "new-route-h1" ? title : document.getElementById(outcome.focus);
      if (focusTarget) focusTarget.focus();
      window.__AMOEBIUS_LAST__ = outcome;
    };

    edit.addEventListener("click", () => { void apply("edit"); });
    submit.addEventListener("click", () => { void apply("submit"); });
    cancel.addEventListener("click", () => { void apply("cancel"); });
    workflowButtons.forEach(([event, button]) => button.addEventListener("click", () => { void apply(event); }));
    docs.addEventListener("click", () => {
      const outcome = transition(state)("open-docs")(input.value);
      window.__AMOEBIUS_LAST__ = outcome;
      window.open("https://docs.example.invalid/amoebius", "_blank", "noopener,noreferrer");
    });
    modalOpener.addEventListener("click", () => {
      modal.hidden = false;
      modalFirst.focus();
    });
    modal.addEventListener("keydown", event => {
      if (event.key === "Tab") {
        event.preventDefault();
        (document.activeElement === modalFirst ? modalSecond : modalFirst).focus();
      }
      if (event.key === "Escape") {
        modal.hidden = true;
        modalOpener.focus();
      }
    });
    window.__AMOEBIUS_SOCKET__ = socket;
    window.__AMOEBIUS_READY__ = true;
  };
  void bootstrap();
};
