package org.amoebius.history;

import java.io.IOException;
import java.lang.ref.ReferenceQueue;
import java.lang.ref.WeakReference;
import java.nio.ByteBuffer;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import org.apache.jute.Record;
import org.apache.zookeeper.txn.TxnDigest;
import org.apache.zookeeper.txn.TxnHeader;

/** Retain original transaction identity across application and append attempts.
 *
 * Unique canonical records and their conservative framed debit live for this
 * registry's entire lifetime. Weak object aliases may be collected; doing so
 * never refunds that debit. This is a bounded local capture registry, not a
 * durable quota reservation, a heap bound, or permission to apply/append.
 */
public final class CaptureRegistry {
    private final int maximumUniqueFramedBytes;
    private final int maximumAliasEntries;
    private final int maximumCanonicalBytes;
    private final Map<Long, CapturedTransaction> originals = new HashMap<>();
    private final Map<IdentityPair, CapturedTransaction> aliases = new HashMap<>();
    private final ReferenceQueue<Object> collected = new ReferenceQueue<>();
    private int uniqueFramedBytes;

    public CaptureRegistry(int maximumUniqueFramedBytes, int maximumAliasEntries) {
        if (maximumUniqueFramedBytes <= 0 || maximumAliasEntries <= 0) {
            throw new IllegalArgumentException("history-registry-policy-invalid");
        }
        this.maximumUniqueFramedBytes = maximumUniqueFramedBytes;
        this.maximumAliasEntries = maximumAliasEntries;
        this.maximumCanonicalBytes = Math.max(36, maximumUniqueFramedBytes-25);
    }

    public synchronized CapturedTransaction forApplication(TxnHeader header, Record transaction)
            throws IOException {
        return capture(header, transaction, null, false);
    }

    public synchronized CapturedTransaction forAppend(TxnHeader header, Record transaction, TxnDigest digest)
            throws IOException {
        return capture(header, transaction, digest, true);
    }

    public synchronized int uniqueFramedBytes() { return uniqueFramedBytes; }
    public synchronized int uniqueTransactions() { return originals.size(); }
    public synchronized int aliasEntries() {
        drainCollected();
        return aliases.size();
    }

    private CapturedTransaction capture(TxnHeader header, Record transaction, TxnDigest digest,
                                        boolean append) throws IOException {
        drainCollected();
        CapturedTransaction current;
        try {
            current = CapturedTransaction.capture(header, transaction, null, maximumCanonicalBytes);
        } catch (CapturedTransaction.ByteLimitException limit) {
            throw new IOException("history-registry-unique-byte-limit", limit);
        }
        IdentityPair lookup = new IdentityPair(header, transaction, null);
        CapturedTransaction original = aliases.get(lookup);
        boolean newAlias = original == null;
        if (original != null) {
            byte[] retained = original.canonicalCopy();
            byte[] observed = current.canonicalCopy();
            if (!Arrays.equals(retained, observed) && !compatibleFailedMulti(retained, observed)) {
                throw new IOException("history-registry-alias-body-changed");
            }
        } else {
            original = originals.get(current.zxid());
            if (original != null && !Arrays.equals(original.canonicalCopy(), current.canonicalCopy())) {
                throw new IOException("history-registry-zxid-conflict");
            }
            if (original == null) {
                original = current;
            }
        }
        boolean newUnique = !originals.containsKey(original.zxid());
        // Serialization failures and ordinary denials publish neither an alias
        // nor a unique charge. Append payloads always use the retained original.
        CapturedTransaction result = append ? original.withDigest(digest) : original;
        if (newUnique && original.maximumModernFramedBytes() > maximumUniqueFramedBytes-uniqueFramedBytes) {
            throw new IOException("history-registry-unique-byte-limit");
        }
        if (newAlias && aliases.size() >= maximumAliasEntries) {
            throw new IOException("history-registry-alias-entry-limit");
        }
        if (newUnique) {
            originals.put(original.zxid(), original);
            uniqueFramedBytes += original.maximumModernFramedBytes();
        }
        if (newAlias) {
            aliases.put(new IdentityPair(header, transaction, collected), original);
        }
        return result;
    }

    /** DataTree3.9.3 changes child opcodes after first seeing an Error child.
     * Only that pinned failed-Multi shape may differ on a known object alias.
     * The complete header, vector order, child data and original Error opcodes
     * remain exact. Successful Multi mutation never obtains this exception.
     */
    private static boolean compatibleFailedMulti(byte[] original, byte[] current) {
        if (original.length != current.length || original.length < 36
                || !Arrays.equals(original, 0, 32, current, 0, 32)
                || ByteBuffer.wrap(original, 28, 4).getInt() != 14) {
            return false;
        }
        ByteBuffer first = ByteBuffer.wrap(original);
        ByteBuffer next = ByteBuffer.wrap(current);
        first.position(32);
        next.position(32);
        int count = first.getInt();
        if (count != next.getInt() || count <= 0 || count > first.remaining()/8) {
            return false;
        }
        boolean failed = false;
        for (int i = 0; i < count; i++) {
            if (first.remaining() < 8 || next.remaining() < 8) {
                return false;
            }
            int oldType = first.getInt();
            int newType = next.getInt();
            int oldLength = first.getInt();
            int newLength = next.getInt();
            if (oldType == -1) {
                failed = true;
            }
            if (!supportedMultiChild(oldType)
                    || (newType != oldType && (oldType == -1 || newType != -1))
                    || oldLength != newLength || oldLength < 0
                    || oldLength > first.remaining() || oldLength > next.remaining()) {
                return false;
            }
            int dataLength = Math.max(0, oldLength);
            if (!Arrays.equals(original, first.position(), first.position()+dataLength,
                               current, next.position(), next.position()+dataLength)) {
                return false;
            }
            first.position(first.position()+dataLength);
            next.position(next.position()+dataLength);
        }
        return failed && !first.hasRemaining() && !next.hasRemaining();
    }

    private static boolean supportedMultiChild(int type) {
        return switch (type) {
            case 1, 15, 21, 19, 2, 20, 5, -1, 13 -> true;
            default -> false;
        };
    }

    private void drainCollected() {
        Part part;
        while ((part = (Part) collected.poll()) != null) {
            aliases.remove(part.owner);
        }
        aliases.keySet().removeIf(pair -> pair.header.get() == null || pair.transaction.get() == null);
    }

    private static final class IdentityPair {
        final Part header;
        final Part transaction;
        final int hash;

        IdentityPair(Object header, Object transaction, ReferenceQueue<Object> queue) {
            this.hash = 31*System.identityHashCode(header)+System.identityHashCode(transaction);
            this.header = new Part(header, queue, this);
            this.transaction = new Part(transaction, queue, this);
        }

        @Override public int hashCode() { return hash; }

        @Override public boolean equals(Object other) {
            if (this == other) {
                return true;
            }
            if (!(other instanceof IdentityPair pair)) {
                return false;
            }
            Object left = header.get();
            Object right = transaction.get();
            return left != null && right != null && left == pair.header.get() && right == pair.transaction.get();
        }
    }

    private static final class Part extends WeakReference<Object> {
        final IdentityPair owner;

        Part(Object value, ReferenceQueue<Object> queue, IdentityPair owner) {
            super(value, queue);
            this.owner = owner;
        }
    }
}
