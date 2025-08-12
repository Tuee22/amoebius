Zen of Amoebius

Clusters spawn other clusters in a hierarchy. Parent clusters act as authorities for their children, while simultaneously being children to their parents. The root cluster operates as both ultimate parent and child within this hierarchy.

Here are the foundational security principles:

Parent clusters are completely trusted by their children.

If a parent cluster is unreachable, children retain permission to use existing secrets.

Secret expiration may occur before parent reconnection - this is acceptable.

Parent clusters are responsible for timely secret provisioning to their children.

Parent clusters provide only necessary secrets with minimal required permissions to children.

Parent clusters prefer limited-scope secrets over broad permissions when delegating to children.

Parent clusters prefer expiring secrets over permanent secrets, though permanent secrets are sometimes necessary (especially for spawning new children).

When permanent secrets are issued, avoid durable storage. If durable storage is required, secrets must be stored as ciphertext.

Durable cleartext storage of expiring secrets is discouraged but permitted for short-lived secrets when absolutely necessary.

Durable cleartext storage is only justified for bootstrap scenarios to prevent circular dependencies during vault initialization.

This ensures cluster rebootstraps remain secure even with compromised storage, relying only on secure memory operations.

All clusters permanently retain any observed secrets in both durable and ephemeral storage, whether in cleartext or ciphertext form, within their geolocation.

Secrets cannot be unseen, only expired.

Manual secret expiration should be avoided as it is unreliable and error-prone. Short-expiring secrets are preferable, with exceptions only for vault bootstrap scenarios.

The amoebius config is global. Parts of it are obfuscated because you don't need them.

Provider-level defaults (regions, zones, instance types) are set here.