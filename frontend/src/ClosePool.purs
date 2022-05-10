module ClosePool (closePoolContract) where

import Contract.Prelude

import Contract.Address (getWalletAddress, ownPaymentPubKeyHash)
import Contract.Monad (Contract, liftContractM, liftedE, liftedE', liftedM)
import Contract.PlutusData (PlutusData, Redeemer(..), toData)
import Contract.Prim.ByteArray (byteArrayToHex)
import Contract.ScriptLookups as ScriptLookups
import Contract.Transaction (BalancedSignedTransaction(BalancedSignedTransaction), balanceAndSignTx, submit)
import Contract.TxConstraints (TxConstraints, mustSpendScriptOutput)
import Contract.Utxos (utxosAt)
import Scripts.BondedPoolValidator (mkBondedPoolValidator)
import Settings (bondedStakingTokenName, hardCodedParams)
import Types (BondedStakingAction(..), PoolInfo(PoolInfo))
import Utils (getUtxoWithNFT, logInfo_)

closePoolContract :: PoolInfo -> Contract () Unit
closePoolContract (PoolInfo poolInfo) = do
  -- Get fields from pool info
  let poolAddr = poolInfo.poolAddr
      nftCs = poolInfo.stateNftCs
      assocListCs = poolInfo.assocListCs
  adminPkh <- liftedM "closePoolContract: Cannot get admin's pkh"
    ownPaymentPubKeyHash
  logInfo_ "Admin PaymentPubKeyHash" adminPkh
  -- Get the (Nami) wallet address
  adminAddr <- liftedM "closePoolContract: Cannot get wallet Address"
    getWalletAddress
  -- Get utxos at the wallet address
  adminUtxos <-
    liftedM "closePoolContract: Cannot get user Utxos" $ utxosAt adminAddr
  -- Get the token name of state NFT
  stateTokenName <-
    liftContractM "closePoolcontract: Cannot get state token name"
      bondedStakingTokenName
  -- Get the bonded pool's utxo
  bondedPoolUtxos <-
    liftedM "closePoolContract: Cannot get pool's utxos at pool address" $
      utxosAt poolAddr
  (Tuple poolTxInput _poolTxOutput) <-
    liftContractM "closePoolContract: Cannot get state utxo" $
      getUtxoWithNFT bondedPoolUtxos nftCs stateTokenName
  -- Create parameters of the pool and validator
  params <- liftContractM "closePoolContract: Failed to create parameters" $
    hardCodedParams adminPkh nftCs assocListCs
  validator <- liftedE' "closePoolContract: Cannot create validator" $
    mkBondedPoolValidator params
  -- We build the transaction
  let
    redeemer = Redeemer $ toData $ CloseAct

    lookup :: ScriptLookups.ScriptLookups PlutusData
    lookup = mconcat
      [ ScriptLookups.validator validator
      , ScriptLookups.unspentOutputs $ unwrap adminUtxos
      , ScriptLookups.unspentOutputs $ unwrap bondedPoolUtxos
      ]

    -- Seems suspect, not sure if typed constraints are working as expected
    constraints :: TxConstraints Unit Unit
    constraints =
      mconcat
        [
          mustSpendScriptOutput poolTxInput redeemer
        ]

  unattachedBalancedTx <-
    liftedE $ ScriptLookups.mkUnbalancedTx lookup constraints
  BalancedSignedTransaction { signedTxCbor } <-
    liftedM
      "closePoolContract: Cannot balance, reindex redeemers, attach datums/\
      \redeemers and sign"
      $ balanceAndSignTx unattachedBalancedTx
  -- Submit transaction using Cbor-hex encoded `ByteArray`
  transactionHash <- submit signedTxCbor
  logInfo_ "closePoolContract: Transaction successfully submitted with hash"
    $ byteArrayToHex
    $ unwrap transactionHash