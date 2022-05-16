module Utils
  ( big
  , getUtxoWithNFT
  , jsonReader
  , logInfo_
  , mkBondedPoolParams
  , nat
  ) where

import Contract.Prelude

import Contract.Address (PaymentPubKeyHash)
import Contract.Monad (Contract, logInfo, tag)
import Contract.Numeric.Natural (Natural, fromBigInt')
import Contract.Transaction (TransactionInput, TransactionOutput, UtxoM)
import Contract.Value (TokenName)
import Data.Argonaut
  ( Json
  , class DecodeJson
  , JsonDecodeError(TypeMismatch)
  , caseJsonObject
  , getField
  )
import Data.Array (filter, head)
import Data.BigInt (BigInt, fromInt)
import Data.Identity (Identity(Identity))
import Data.Map (toUnfoldable)
import Plutus.ToPlutusType (toPlutusType)
import Plutus.Types.CurrencySymbol (CurrencySymbol)
import Plutus.Types.Value (valueOf)
import Types
  ( BondedPoolParams(BondedPoolParams)
  , InitialBondedParams(InitialBondedParams)
  )

-- | Helper to decode the local inputs such as unapplied minting policy and
-- typed validator
jsonReader
  :: forall (a :: Type)
   . DecodeJson a
  => String
  -> Json
  -> Either JsonDecodeError a
jsonReader field = caseJsonObject (Left $ TypeMismatch "Expected Object")
  $ flip getField field

-- | Get the UTXO with the NFT defined by its `CurrencySymbol` and `TokenName`.
-- If more than one UTXO contains the NFT, something is seriously wrong.
getUtxoWithNFT
  :: UtxoM
  -> CurrencySymbol
  -> TokenName
  -> Maybe (Tuple TransactionInput TransactionOutput)
getUtxoWithNFT utxoM cs tn =
  let
    utxos = filter hasNFT $ toUnfoldable $ unwrap utxoM
  in
    if length utxos > 1 then Nothing
    else head utxos
  where
  hasNFT
    :: Tuple TransactionInput TransactionOutput
    -> Boolean
  hasNFT (Tuple _ txOutput') =
    let
      txOutput = unwrap txOutput'
      Identity plutusValue = toPlutusType txOutput.amount
    in
      valueOf plutusValue cs tn == one

-- | Convert from `Int` to `Natural`
nat :: Int -> Natural
nat = fromBigInt' <<< fromInt

-- | Convert from `Int` to `BigInt`
big :: Int -> BigInt
big = fromInt

logInfo_
  :: forall (r :: Row Type) (a :: Type)
   . Show a
  => String
  -> a
  -> Contract r Unit
logInfo_ k = flip logInfo mempty <<< tag k <<< show

-- Creates the `BondedPoolParams` from the `InitialBondedParams` and runtime
-- parameters from the user.
mkBondedPoolParams
  :: PaymentPubKeyHash
  -> CurrencySymbol
  -> CurrencySymbol
  -> InitialBondedParams
  -> BondedPoolParams
mkBondedPoolParams admin nftCs assocListCs (InitialBondedParams ibp) = do
  BondedPoolParams
    { iterations: ibp.iterations
    , start: ibp.start
    , end: ibp.end
    , userLength: ibp.userLength
    , bondingLength: ibp.bondingLength
    , interest: ibp.interest
    , minStake: ibp.minStake
    , maxStake: ibp.maxStake
    , admin
    , bondedAssetClass: ibp.bondedAssetClass
    , nftCs
    , assocListCs
    }