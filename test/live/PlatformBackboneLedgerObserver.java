/*
 * Read-only external observer against the baked Pulsar 4.0.6 / BookKeeper
 * 4.17.2 APIs. Never uses amoebius's admission or geometry implementation.
 * BookKeeper.getLedgerManager().readLedgerMetadata is the authoritative
 * metadata lookup; a timeout, HTTP error or unknown BK error fails closed.
 *
 * https://github.com/apache/bookkeeper/blob/release-4.17.2/bookkeeper-server/src/main/java/org/apache/bookkeeper/client/BookKeeper.java
 * https://github.com/apache/pulsar/blob/v4.0.6/pulsar-client-admin-api/src/main/java/org/apache/pulsar/common/policies/data/ManagedLedgerInternalStats.java
 */
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import org.apache.bookkeeper.client.BookKeeper;
import org.apache.bookkeeper.client.BKException;
import org.apache.bookkeeper.conf.ClientConfiguration;

class PlatformBackboneLedgerObserver {
    public static void main(String[] args) throws Exception {
        ClientConfiguration config = new ClientConfiguration();
        config.setMetadataServiceUri("zk+hierarchical://zookeeper.pulsar-system.svc.cluster.local:2181/ledgers");
        config.setNumWorkerThreads(1);
        config.setNumIOThreads(1);
        ObjectMapper json = new ObjectMapper();
        HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5))
            .followRedirects(HttpClient.Redirect.NORMAL).build();
        try (BookKeeper bookkeeper = new BookKeeper(config);
             BufferedReader input = new BufferedReader(new InputStreamReader(System.in))) {
            System.out.println("PHASE30_OBSERVER_READY");
            System.out.flush();
            String line;
            while ((line = input.readLine()) != null) {
                if (line.length() > 256 || !line.matches("[a-zA-Z0-9_-]{1,128}"))
                    throw new IllegalArgumentException("observer-topic-scope");
                URI uri = URI.create("http://broker.pulsar-system.svc:8080/admin/v2/persistent/phase30/drill/"
                    + line + "/internalStats");
                HttpResponse<String> response = http.send(HttpRequest.newBuilder(uri)
                    .timeout(Duration.ofSeconds(5)).GET().build(), HttpResponse.BodyHandlers.ofString());
                if (response.statusCode() != 200 || response.body().length() > 1048576)
                    throw new IllegalStateException("observer-stats-http-" + response.statusCode());
                JsonNode stats = json.readTree(response.body());
                if (!stats.has("ledgers") || !stats.has("currentLedgerSize") || stats.get("ledgers").size() > 128)
                    throw new IllegalStateException("observer-incomplete-stats");
                long hot = 0;
                // Pulsar's ledger-info map keeps the active ledger's size at
                // zero until close. Its live size is a separate stats field.
                long currentId = -1;
                for (JsonNode ledger : stats.get("ledgers"))
                    currentId = Math.max(currentId, ledger.required("ledgerId").longValue());
                ArrayNode ledgerRows = json.createArrayNode();
                for (JsonNode ledger : stats.get("ledgers")) {
                    long id = ledger.required("ledgerId").longValue();
                    long bytes = ledger.required("size").longValue();
                    if (id == currentId || ledger.required("entries").longValue() < 0 || bytes < 0)
                        bytes = Math.max(bytes, stats.required("currentLedgerSize").longValue());
                    if (id < 0 || bytes < 0) throw new IllegalStateException("observer-ledger-extent");
                    boolean exists = true;
                    org.apache.bookkeeper.client.api.LedgerMetadata metadata = null;
                    try {
                        metadata = bookkeeper.getLedgerManager().readLedgerMetadata(id).get(5, TimeUnit.SECONDS).getValue();
                    } catch (ExecutionException failed) {
                        Throwable cause = failed.getCause();
                        if (cause instanceof BKException.BKNoSuchLedgerExistsOnMetadataServerException
                            || cause instanceof BKException.BKNoSuchLedgerExistsException) exists = false;
                        else throw failed;
                    }
                    // An offloaded flag alone never earns deletion credit.
                    boolean credited = ledger.required("offloaded").booleanValue() && !exists;
                    if (!credited) hot = Math.addExact(hot, bytes);
                    ObjectNode row = json.createObjectNode();
                    row.put("ledgerId", id); row.put("bytes", bytes); row.put("bookkeeperMetadataExists", exists);
                    row.put("offloaded", ledger.get("offloaded").booleanValue()); row.put("deletionCredited", credited);
                    row.put("bookkeeperClosed", metadata != null && metadata.isClosed());
                    row.put("bookkeeperLengthBytes", metadata == null ? -1 : metadata.getLength());
                    ledgerRows.add(row);
                }
                ObjectNode result = json.createObjectNode();
                result.put("topic", line); result.put("hotTierBytes", hot);
                result.set("ledgers", ledgerRows); result.set("brokerStats", stats);
                System.out.println("PHASE30_OBSERVATION " + json.writeValueAsString(result));
                System.out.flush();
            }
        }
    }
}
