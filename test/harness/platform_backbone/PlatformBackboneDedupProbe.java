import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.TimeUnit;
import org.apache.pulsar.client.api.Consumer;
import org.apache.pulsar.client.api.Message;
import org.apache.pulsar.client.api.Producer;
import org.apache.pulsar.client.api.PulsarClient;
import org.apache.pulsar.client.api.SubscriptionInitialPosition;

/** Live native-protocol probe that injects one repeated producer sequence id. */
public final class PlatformBackboneDedupProbe {
  private static final byte[] CBOR_ONE = new byte[] {(byte) 0xa1, 0x65, 0x70, 0x68, 0x61, 0x73, 0x65, 0x18, 0x1e};
  private static final byte[] CBOR_DUPLICATE = "duplicate-must-not-arrive".getBytes(StandardCharsets.UTF_8);
  private static final byte[] CBOR_TWO = new byte[] {(byte) 0xa1, 0x63, 0x73, 0x65, 0x71, 0x08};

  private PlatformBackboneDedupProbe() {}

  public static void main(String[] arguments) throws Exception {
    if (arguments.length != 2) {
      throw new IllegalArgumentException("usage: Phase30DedupProbe SERVICE_URL TOPIC");
    }
    String serviceUrl = arguments[0];
    String topic = arguments[1];
    String subscription = "phase30-dedup-observer-" + System.nanoTime();
    try (PulsarClient client = PulsarClient.builder().serviceUrl(serviceUrl).operationTimeout(30, TimeUnit.SECONDS).build();
        Producer<byte[]> producer = client.newProducer().topic(topic).producerName("phase30-sequenced-producer")
            .enableBatching(false).initialSequenceId(7).create()) {
      producer.newMessage().sequenceId(7).value(CBOR_ONE).send();
      producer.newMessage().sequenceId(7).value(CBOR_DUPLICATE).send();
      producer.newMessage().sequenceId(8).value(CBOR_TWO).send();
    }
    try (PulsarClient client = PulsarClient.builder().serviceUrl(serviceUrl).operationTimeout(30, TimeUnit.SECONDS).build();
        Consumer<byte[]> consumer = client.newConsumer().topic(topic).subscriptionName(subscription)
            .subscriptionInitialPosition(SubscriptionInitialPosition.Earliest).subscribe()) {
      List<byte[]> received = new ArrayList<>();
      for (int index = 0; index < 2; index++) {
        Message<byte[]> message = consumer.receive(30, TimeUnit.SECONDS);
        if (message == null) {
          throw new IllegalStateException("missing expected deduplicated message " + index);
        }
        received.add(message.getData());
        consumer.acknowledge(message);
      }
      Message<byte[]> unexpected = consumer.receive(3, TimeUnit.SECONDS);
      if (unexpected != null) {
        throw new IllegalStateException("duplicate sequence reached the consumer");
      }
      boolean byteIdentical = received.stream().anyMatch(value -> Arrays.equals(value, CBOR_ONE))
          && received.stream().anyMatch(value -> Arrays.equals(value, CBOR_TWO));
      if (!byteIdentical || received.stream().anyMatch(value -> Arrays.equals(value, CBOR_DUPLICATE))) {
        throw new IllegalStateException("CBOR payload mismatch");
      }
      System.out.println("phase30-dedup-probe: PASS native=true sequenceIds=7,7,8 delivered=2 cborByteIdentical=true");
    }
  }
}
