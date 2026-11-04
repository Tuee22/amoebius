package org.amoebius.history;

import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.ByteBuffer;
import java.nio.channels.SelectionKey;
import java.nio.channels.Selector;
import java.nio.channels.SocketChannel;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Arrays;
import java.util.HexFormat;

/** Bounded synchronous client of the durable native history authority.
 * A timeout, lost response, denial or mismatched acknowledgement never grants
 * permission. Retrying an append must request a new physical reservation.
 * Installation, member credentials and effect-hook coverage are separate.
 */
public final class HistoryClient {
    private final InetSocketAddress endpoint;
    private final long member;
    private final byte[] credential;
    private final int timeoutMillis;
    private final SecureRandom random = new SecureRandom();

    public HistoryClient(InetSocketAddress endpoint, long member, byte[] credential, int timeoutMillis) {
        if (endpoint == null || endpoint.getPort() == 0 || member < 0
                || credential == null || credential.length != 32 || timeoutMillis <= 0) {
            throw new IllegalArgumentException("history-client-policy-invalid");
        }
        this.endpoint = endpoint;
        this.member = member;
        this.credential = credential.clone();
        this.timeoutMillis = timeoutMillis;
    }

    public void reserve(CapturedTransaction original) throws IOException { mutation(0, original); }
    public void apply(CapturedTransaction original) throws IOException { mutation(1, original); }
    public void appendAttempt(CapturedTransaction attempt) throws IOException {
        if (attempt == null) {
            throw new IOException("history-client-capture-required");
        }
        mutation(attempt.payloadCopy().length == attempt.canonicalBytes() ? 2 : 3, attempt);
    }
    public void openLog(String name) throws IOException { generation(4, "log.", name); }
    public void openSnapshot(String name) throws IOException { generation(5, "snapshot.", name); }

    private void mutation(int operation, CapturedTransaction capture) throws IOException {
        if (capture == null) {
            throw new IOException("history-client-capture-required");
        }
        ByteArrayOutputStream body = new ByteArrayOutputStream(56);
        DataOutputStream fields = new DataOutputStream(body);
        fields.writeLong(capture.zxid());
        fields.writeInt(capture.canonicalBytes());
        fields.write(HexFormat.of().parseHex(capture.canonicalSha256()));
        if (operation == 3) {
            byte[] payload = capture.payloadCopy();
            if (payload.length != capture.canonicalBytes()+12
                    || ByteBuffer.wrap(payload, capture.canonicalBytes(), 4).getInt() != 2) {
                throw new IOException("history-client-digest-profile-invalid");
            }
            fields.write(payload, capture.canonicalBytes(), 12);
        }
        exchange(operation, body.toByteArray());
    }

    private void generation(int operation, String prefix, String name) throws IOException {
        if (name == null || !name.matches(java.util.regex.Pattern.quote(prefix)+"[0-9a-f]{1,16}")) {
            throw new IOException("history-client-generation-name-invalid");
        }
        byte[] raw = name.getBytes(StandardCharsets.US_ASCII);
        ByteArrayOutputStream body = new ByteArrayOutputStream(raw.length+1);
        body.write(raw.length);
        body.writeBytes(raw);
        exchange(operation, body.toByteArray());
    }

    private synchronized void exchange(int operation, byte[] body) throws IOException {
        byte[] nonce = new byte[16];
        random.nextBytes(nonce);
        ByteArrayOutputStream bytes = new ByteArrayOutputStream(117);
        DataOutputStream request = new DataOutputStream(bytes);
        request.writeBytes("AHC1");
        request.writeLong(member);
        request.write(credential);
        request.write(nonce);
        request.writeByte(operation);
        request.write(body);
        byte[] payload = bytes.toByteArray();
        if (payload.length > 117) {
            throw new IOException("history-client-request-too-large");
        }
        ByteBuffer outgoing = ByteBuffer.allocate(4+payload.length);
        outgoing.putInt(payload.length).put(payload).flip();
        long deadline = System.nanoTime()+timeoutMillis*1_000_000L;
        byte[] response;
        try (Selector selector = Selector.open(); SocketChannel channel = SocketChannel.open()) {
            channel.configureBlocking(false);
            SelectionKey key = channel.register(selector, SelectionKey.OP_CONNECT);
            if (!channel.connect(endpoint)) {
                while (!channel.finishConnect()) {
                    await(selector, key, SelectionKey.OP_CONNECT, deadline);
                }
            }
            while (outgoing.hasRemaining()) {
                ensureTime(deadline);
                if (channel.write(outgoing) == 0) {
                    await(selector, key, SelectionKey.OP_WRITE, deadline);
                }
            }
            ByteBuffer incoming = ByteBuffer.allocate(54);
            while (true) {
                ensureTime(deadline);
                int count = channel.read(incoming);
                if (incoming.position() > 53) {
                    throw new IOException("history-client-response-too-large");
                }
                if (count < 0) {
                    break;
                }
                if (count == 0) {
                    await(selector, key, SelectionKey.OP_READ, deadline);
                }
            }
            if (incoming.position() != 53) {
                throw new IOException("history-client-response-truncated");
            }
            response = Arrays.copyOf(incoming.array(), 53);
        }
        ensureTime(deadline);
        if (!Arrays.equals(response, 0, 4, new byte[] {'A','H','G','1'}, 0, 4)
                || !MessageDigest.isEqual(Arrays.copyOfRange(response, 4, 20), nonce)
                || !MessageDigest.isEqual(Arrays.copyOfRange(response, 20, 52), sha256(payload))) {
            throw new IOException("history-client-response-identity-mismatch");
        }
        if (response[52] != 0) {
            throw new IOException("history-client-reservation-denied");
        }
    }

    private static void await(Selector selector, SelectionKey key, int operation, long deadline)
            throws IOException {
        long remaining = ensureTime(deadline);
        key.interestOps(operation);
        selector.select(Math.max(1, (remaining+999_999L)/1_000_000L));
        selector.selectedKeys().clear();
        ensureTime(deadline);
    }

    private static long ensureTime(long deadline) throws IOException {
        long remaining = deadline-System.nanoTime();
        if (remaining <= 0) {
            throw new IOException("history-client-deadline-exceeded");
        }
        return remaining;
    }

    private static byte[] sha256(byte[] value) throws IOException {
        try {
            return MessageDigest.getInstance("SHA-256").digest(value);
        } catch (NoSuchAlgorithmException failure) {
            throw new IOException("history-client-sha256-unavailable", failure);
        }
    }
}
