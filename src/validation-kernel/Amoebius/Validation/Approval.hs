{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.Approval
  ( Approval (..)
  , ApprovalError (..)
  , CandidateBinding (..)
  , TrustRoot (..)
  , approvalPayload
  , verifyApproval
  ) where

import Amoebius.Validation.PolicyContract.Internal
  ( AutomationRole (CandidateEvidenceOnly)
  , StatusMutationAuthority (HumanUserOnly)
  , automationRole
  , canonicalPolicyContract
  , orderingContract
  , phaseDomainUpper
  , phaseOrdinalNumber
  , promotionAuthority
  , promotionAuthorityMarker
  , promotionContract
  , statusMutationAuthority
  )
import Crypto.Error (CryptoFailable (CryptoFailed, CryptoPassed))
import Crypto.PubKey.Ed25519 qualified as Ed25519
import Data.ByteString (ByteString)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding

data CandidateBinding = CandidateBinding
  { candidatePhase :: Text
  , candidateSourceDigest :: Text
  , candidateContractDigest :: Text
  , candidateHarnessDigest :: Text
  , candidateEvidenceDigest :: Text
  , candidatePredecessorDigest :: Text
  , candidateApprovalNonce :: Text
  , candidatePriorSourceDigests :: Set Text
  }
  deriving (Eq, Ord, Show)

data TrustRoot = TrustRoot
  { trustRootId :: Text
  , trustRootPublicKey :: ByteString
  , trustRootEstablishedBefore :: Text
  }
  deriving (Eq, Show)

data Approval = Approval
  { approvalAuthority :: Text
  , approvalTrustRootId :: Text
  , approvalPhase :: Text
  , approvalSourceDigest :: Text
  , approvalContractDigest :: Text
  , approvalHarnessDigest :: Text
  , approvalEvidenceDigest :: Text
  , approvalPredecessorDigest :: Text
  , approvalNonce :: Text
  , approvalIssuedAt :: Text
  , approvalSignature :: ByteString
  }
  deriving (Eq, Show)

data ApprovalError
  = ApprovalPolicyContractMismatch
  | ApprovalAuthorityNotHuman
  | ApprovalTrustRootMismatch
  | ApprovalTrustRootNotPrior
  | ApprovalBindingMalformed
  | ApprovalPhaseMismatch
  | ApprovalSourceMismatch
  | ApprovalContractMismatch
  | ApprovalHarnessMismatch
  | ApprovalEvidenceMismatch
  | ApprovalPredecessorMismatch
  | ApprovalNonceMissing
  | ApprovalNonceMismatch
  | ApprovalReplay
  | ApprovalIssuedAtMissing
  | ApprovalPublicKeyInvalid
  | ApprovalSignatureInvalid
  | ApprovalExternalAnchorUnavailable
  deriving (Eq, Ord, Show)

approvalPayload :: Approval -> ByteString
approvalPayload approval =
  TextEncoding.encodeUtf8
    ( "amoebius-human-approval-v1\n"
        <> field "authority" (approvalAuthority approval)
        <> field "trust-root" (approvalTrustRootId approval)
        <> field "phase" (approvalPhase approval)
        <> field "source" (approvalSourceDigest approval)
        <> field "contract" (approvalContractDigest approval)
        <> field "harness" (approvalHarnessDigest approval)
        <> field "evidence" (approvalEvidenceDigest approval)
        <> field "predecessor" (approvalPredecessorDigest approval)
        <> field "nonce" (approvalNonce approval)
        <> field "issued-at" (approvalIssuedAt approval)
    )
 where
  field key value = key <> "=" <> value <> "\n"

verifyApproval :: TrustRoot -> CandidateBinding -> Set Text -> Approval -> Either ApprovalError ()
verifyApproval trust candidate consumedNonces approval = do
  require (canonicalBinding trust candidate approval) ApprovalBindingMalformed
  require canonicalPromotionBoundary ApprovalPolicyContractMismatch
  require (approvalAuthority approval == canonicalHumanAuthority) ApprovalAuthorityNotHuman
  require (approvalTrustRootId approval == trustRootId trust) ApprovalTrustRootMismatch
  require
    ( not (nullText (trustRootEstablishedBefore trust))
        && trustRootEstablishedBefore trust /= candidateSourceDigest candidate
        && Set.member (trustRootEstablishedBefore trust) (candidatePriorSourceDigests candidate)
    )
    ApprovalTrustRootNotPrior
  require (approvalPhase approval == candidatePhase candidate) ApprovalPhaseMismatch
  require (approvalSourceDigest approval == candidateSourceDigest candidate) ApprovalSourceMismatch
  require (approvalContractDigest approval == candidateContractDigest candidate) ApprovalContractMismatch
  require (approvalHarnessDigest approval == candidateHarnessDigest candidate) ApprovalHarnessMismatch
  require (approvalEvidenceDigest approval == candidateEvidenceDigest candidate) ApprovalEvidenceMismatch
  require (approvalPredecessorDigest approval == candidatePredecessorDigest candidate) ApprovalPredecessorMismatch
  require (not (nullText (approvalNonce approval))) ApprovalNonceMissing
  require (approvalNonce approval == candidateApprovalNonce candidate) ApprovalNonceMismatch
  require (not (Set.member (approvalNonce approval) consumedNonces)) ApprovalReplay
  require (not (nullText (approvalIssuedAt approval))) ApprovalIssuedAtMissing
  publicKey <- case Ed25519.publicKey (trustRootPublicKey trust) of
    CryptoPassed value -> Right value
    CryptoFailed _ -> Left ApprovalPublicKeyInvalid
  signature <- case Ed25519.signature (approvalSignature approval) of
    CryptoPassed value -> Right value
    CryptoFailed _ -> Left ApprovalSignatureInvalid
  require (Ed25519.verify publicKey (approvalPayload approval) signature) ApprovalSignatureInvalid
  -- A caller-supplied key, prior-source set, and nonce set cannot establish
  -- human authority. Until the dispatcher acquires an externally anchored
  -- trust root, durable replay state, freshness policy, and retrievable
  -- evidence binding, even a structurally valid signature must refuse.
  require False ApprovalExternalAnchorUnavailable
 where
  require True _ = Right ()
  require False problem = Left problem
  nullText = (== "")

canonicalHumanAuthority :: Text
canonicalHumanAuthority =
  promotionAuthorityMarker (promotionAuthority (promotionContract canonicalPolicyContract))

canonicalPromotionBoundary :: Bool
canonicalPromotionBoundary =
  automationRole contract == CandidateEvidenceOnly
    && statusMutationAuthority contract == HumanUserOnly
 where
  contract = promotionContract canonicalPolicyContract

canonicalBinding :: TrustRoot -> CandidateBinding -> Approval -> Bool
canonicalBinding trust candidate approval =
  all singleLine fields
    && all (not . Text.null) coreFields
    && Text.length (candidatePhase candidate) == 2
    && Text.all (\character -> character >= '0' && character <= '9') (candidatePhase candidate)
    && candidatePhase candidate <= canonicalUpperPhaseText
    && all sha256Text candidateDigests
    && sha256Text (trustRootEstablishedBefore trust)
    && all sha256Text (Set.toAscList (candidatePriorSourceDigests candidate))
    && predecessorText (candidatePredecessorDigest candidate)
    && not (Text.null (candidateApprovalNonce candidate))
 where
  fields =
    [ trustRootId trust
    , trustRootEstablishedBefore trust
    , candidatePhase candidate
    , candidateSourceDigest candidate
    , candidateContractDigest candidate
    , candidateHarnessDigest candidate
    , candidateEvidenceDigest candidate
    , candidatePredecessorDigest candidate
    , candidateApprovalNonce candidate
    , approvalAuthority approval
    , approvalTrustRootId approval
    , approvalPhase approval
    , approvalSourceDigest approval
    , approvalContractDigest approval
    , approvalHarnessDigest approval
    , approvalEvidenceDigest approval
    , approvalPredecessorDigest approval
    , approvalNonce approval
    , approvalIssuedAt approval
    ]
  coreFields =
    [ trustRootId trust
    , trustRootEstablishedBefore trust
    , candidatePhase candidate
    , candidatePredecessorDigest candidate
    , candidateApprovalNonce candidate
    ]
  candidateDigests =
    [ candidateSourceDigest candidate
    , candidateContractDigest candidate
    , candidateHarnessDigest candidate
    , candidateEvidenceDigest candidate
    ]
  singleLine value =
    not (Text.any (`elem` ['\r', '\n', '\0']) value)
  predecessorText value = value == "genesis" || sha256Text value
  sha256Text value =
    Text.length value == 64
      && Text.all
        (\character -> (character >= '0' && character <= '9') || (character >= 'a' && character <= 'f'))
        value

canonicalUpperPhaseText :: Text
canonicalUpperPhaseText =
  let upper = phaseOrdinalNumber (phaseDomainUpper (orderingContract canonicalPolicyContract))
   in Text.justifyRight 2 '0' (Text.pack (show upper))
