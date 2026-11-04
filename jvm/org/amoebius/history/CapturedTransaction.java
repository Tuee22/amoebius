package org.amoebius.history;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Objects;
import org.apache.jute.BinaryOutputArchive;
import org.apache.jute.Record;
import org.apache.zookeeper.txn.TxnDigest;
import org.apache.zookeeper.txn.TxnHeader;

/** Immutable original bytes, captured before append or application.
 *
 * Canonical identity excludes the optional digest; physical attempts use the
 * exact payload including that digest. This class neither reserves a quota nor
 * establishes a transaction/import's authority. The owning interceptor must
 * retain this first capture across Multi's subsequent in-place mutation.
 */
public final class CapturedTransaction {
    private final long zxid;
    private final byte[] canonical;
    private final byte[] payload;
    private final String canonicalSha256;

    private CapturedTransaction(long zxid, byte[] canonical, byte[] payload) throws IOException {
        this.zxid = zxid;
        this.canonical = canonical;
        this.payload = payload;
        try {
            this.canonicalSha256 = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(canonical));
        } catch (NoSuchAlgorithmException failure) {
            throw new IOException("history-sha256-unavailable", failure);
        }
    }

    public static CapturedTransaction capture(TxnHeader header, Record transaction, TxnDigest digest,
                                              int maximumCanonicalBytes) throws IOException {
        if (header == null || transaction == null || maximumCanonicalBytes < 36
                || maximumCanonicalBytes > Integer.MAX_VALUE-25) {
            throw new IOException("history-capture-input-invalid");
        }
        BoundedBytes stream = new BoundedBytes(maximumCanonicalBytes);
        BinaryOutputArchive archive = BinaryOutputArchive.getArchive(stream);
        // Deliberately bypass Request.getSerializeData's IOException fallback.
        header.serialize(archive, "hdr");
        transaction.serialize(archive, "txn");
        byte[] canonical = stream.bytes();
        if (canonical.length < 36) {
            throw new IOException("history-canonical-record-too-short");
        }
        long zxid = ByteBuffer.wrap(canonical, 12, 8).getLong();
        if (zxid <= 0) {
            throw new IOException("history-canonical-zxid-invalid");
        }
        if (digest != null) {
            stream.allowDigestSuffix();
            digest.serialize(archive, "digest");
        }
        byte[] payload = stream.bytes();
        if (digest != null && (payload.length != canonical.length+12
                || ByteBuffer.wrap(payload, canonical.length, 4).getInt() != 2)) {
            throw new IOException("history-digest-profile-unsupported");
        }
        return new CapturedTransaction(zxid, canonical, payload);
    }

    /** Materialize one append payload from the retained original canonical body.
     * Application entry can lack a digest that a later append supplies. Never
     * reserialize a possibly mutated Multi just to add/remove that suffix.
     * A caller still needs a separate durable physical-attempt reservation.
     */
    public CapturedTransaction withDigest(TxnDigest digest) throws IOException {
        BoundedBytes stream = new BoundedBytes(canonical.length+12);
        stream.write(canonical);
        if (digest != null) {
            digest.serialize(BinaryOutputArchive.getArchive(stream), "digest");
        }
        byte[] rebound = stream.bytes();
        if (digest != null && (rebound.length != canonical.length+12
                || ByteBuffer.wrap(rebound, canonical.length, 4).getInt() != 2)) {
            throw new IOException("history-digest-profile-unsupported");
        }
        return new CapturedTransaction(zxid, canonical, rebound);
    }

    public long zxid() { return zxid; }
    public int canonicalBytes() { return canonical.length; }
    public String canonicalSha256() { return canonicalSha256; }
    public byte[] canonicalCopy() { return canonical.clone(); }
    public byte[] payloadCopy() { return payload.clone(); }
    public int physicalFramedBytes() { return payload.length+13; }
    public int maximumModernFramedBytes() { return canonical.length+25; }

    // Distinguish our own bounded sink from checked failures thrown by Jute
    // serializers. Callers must never interpret an arbitrary exception string.
    static final class ByteLimitException extends IOException {
        private ByteLimitException() { super("history-canonical-or-digest-byte-limit"); }
    }

    private static final class BoundedBytes extends OutputStream {
        private final ByteArrayOutputStream bytes;
        private int maximum;

        BoundedBytes(int maximum) {
            this.maximum = maximum;
            this.bytes = new ByteArrayOutputStream(Math.min(maximum, 512));
        }

        void allowDigestSuffix() { maximum += 12; }
        byte[] bytes() { return bytes.toByteArray(); }

        @Override public void write(int value) throws IOException {
            ensureFits(1);
            bytes.write(value);
        }

        @Override public void write(byte[] source, int offset, int length) throws IOException {
            Objects.checkFromIndexSize(offset, length, source.length);
            ensureFits(length);
            bytes.write(source, offset, length);
        }

        private void ensureFits(int length) throws IOException {
            if (length > maximum-bytes.size()) {
                throw new ByteLimitException();
            }
        }
    }
}
