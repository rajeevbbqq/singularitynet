module BondedApiExample
  ( -- bondedCallContractAdminCloseExample1
    --, bondedCallContractAdminDepositExample1
    bondedCallContractCreatePoolExample1
  --, bondedCallContractExample1
  , bondedCallContractUserStakeExample1
  ) where

import Contract.Prelude

import SdkApi
  ( BondedPoolArgs
  , InitialBondedArgs
  , SdkConfig
  , buildContractConfig
  -- , callCloseBondedPool
  , callCreateBondedPool
  -- , callDepositBondedPool
  , callUserStakeBondedPool
  )
import Contract.Monad (launchAff_)
import Control.Promise as Promise
import Data.BigInt as BigInt
-- import Data.Int as Int
import Effect.Aff (error)
import Effect.Class.Console (log)
import Record (merge)

------------------------ Used for Testing SDK ----------------------------------
defaultSdkConfig :: SdkConfig
defaultSdkConfig =
  { ctlServerConfig:
      { host: "localhost"
      , path: ""
      , port: 8081.0
      , secure: false
      }
  , ogmiosConfig:
      { host: "localhost"
      , path: ""
      , port: 1337.0
      , secure: false
      }
  , datumCacheConfig:
      { host: "localhost"
      , path: ""
      , port: 9999.0
      , secure: false
      }
  , networkId: zero
  , logLevel: "Info"
  }

-- Hardcoded initial parameters for testing.
testInitialBondedArgs :: Maybe InitialBondedArgs
testInitialBondedArgs = do
  -- Whilst some of these numbers are small, I'd rather use fromString to be safe
  -- in case we switch to larger numbers.
  iterations <- BigInt.fromString "3"
  start <- BigInt.fromString "1000"
  end <- BigInt.fromString "2000"
  userLength <- BigInt.fromString "100"
  bondingLength <- BigInt.fromString "4"
  numerator <- BigInt.fromString "10"
  denominator <- BigInt.fromString "100"
  minStake <- BigInt.fromString "1"
  maxStake <- BigInt.fromString "10000"
  let
    currencySymbol = "6f1a1f0c7ccf632cc9ff4b79687ed13ffe5b624cce288b364ebdce50"
    tokenName = "AGIX"
    bondedAssetClass = { currencySymbol, tokenName }
    interest = { numerator, denominator }
  pure
    { iterations
    , start
    , end
    , userLength
    , bondingLength
    , minStake
    , maxStake
    , bondedAssetClass
    , interest
    }

-- Bonded example: admin deposit, user head stake, admin deposit and admin close.
-- This doesn't seem to work, instead, we need to break down the example into
-- separate effects. See `bondedCallContractCreatePoolExample1`
-- `bondedCallContractUserStakeExample1`, `bondedCallContractAdminDepositExample1`
-- and `bondedCallContractAdminCloseExample1`.
--bondedCallContractExample1 :: Effect Unit
--bondedCallContractExample1 = launchAff_ do
--  adminCfg <- Promise.toAffE $ buildContractConfig defaultSdkConfig
--  iba <-
--    liftM
--      ( error
--          "bondedCallContractExample1: Could not create \
--          \InitialBondedArgs"
--      )
--      $ testInitialBondedArgs
--  log "STARTING AS ADMIN"
--  -- Create pool
--  bondedParams <- Promise.toAffE $ callCreateBondedPool adminCfg iba
--  log "SWITCH WALLETS NOW - CHANGE TO USER 1"
--  delay $ wrap $ Int.toNumber 100_00
--  -- User 1 stakes
--  userCfg <- Promise.toAffE $ buildContractConfig defaultSdkConfig
--  userStake <- liftM (error "bondedCallContractExample1: Cannot create BigInt")
--    $ BigInt.fromString "10"
--  Promise.toAffE $ callUserStakeBondedPool userCfg bondedParams userStake
--  log "SWITCH WALLETS NOW - CHANGE TO BACK TO ADMIN"
--  delay $ wrap $ Int.toNumber 100_00
--  -- Admin deposit
--  Promise.toAffE $ callDepositBondedPool adminCfg bondedParams
--  log "DON'T SWITCH WALLETS - STAY AS ADMIN"
--  delay $ wrap $ Int.toNumber 100_00
--  -- Admin close
--  Promise.toAffE $ callCloseBondedPool adminCfg bondedParams

-- Hardcoded to pass persistent parameters onto subsequent calls.
testBondedPoolArgs :: Maybe BondedPoolArgs
testBondedPoolArgs = do
  iba <- testInitialBondedArgs
  -- ****UPDATE THESE PARAMETERS IN ACCORDANCE TO WHAT IS LOGGED AFTER****
  -- bondedCallContractCreatePoolExample1
  let
    admin = "7df2b92eabfe7ee15d5bd05daf11572f3fcae3b7026851ab5d9d28e6"
    assocListCs = "c355f15087c2a3358c197bac069370fa8dee57c07604b6862378165b"
    nftCs = "7dbfb68c955a679825e39c50a4c495aca22c3c2a2888836d6c5e32ca"
  pure $ merge iba
    { "admin": admin, "assocListCs": assocListCs, "nftCs": nftCs }

-- These examples work when called separately. An example can be found inside
-- `exe/Main.purs`. Please update `testBondedPoolArgs` after running this
-- contract before resuming with next contracts.
-- Bonded pool creation:
bondedCallContractCreatePoolExample1 :: Effect Unit
bondedCallContractCreatePoolExample1 = launchAff_ do
  adminCfg <- Promise.toAffE $ buildContractConfig defaultSdkConfig
  iba <-
    liftM
      ( error
          "bondedCallContractCreatePoolExample1: Could not create \
          \InitialBondedArgs"
      )
      $ testInitialBondedArgs
  log "STARTING AS ADMIN"
  -- Create pool
  bondedParams <- Promise.toAffE $ callCreateBondedPool adminCfg iba
  log $ "admin: " <> show bondedParams.admin
  log $ "assocListCs: " <> show bondedParams.assocListCs
  log $ "nftCs: " <> show bondedParams.nftCs
  log "SWITCH WALLETS NOW - CHANGE TO USER 1"

-- Bonded user stake
bondedCallContractUserStakeExample1 :: Effect Unit
bondedCallContractUserStakeExample1 = launchAff_ do
  userCfg <- Promise.toAffE $ buildContractConfig defaultSdkConfig
  userStake <-
    liftM
      ( error
          "bondedCallContractUserStakeExample1: Cannot \
          \create BigInt"
      )
      $ BigInt.fromString "10"
  bondedParams <- liftM
    ( error
        "bondedCallContractUserStakeExample1: Cannot \
        \ get bonded pool parameters"
    )
    testBondedPoolArgs
  -- User 1 stake
  Promise.toAffE $ callUserStakeBondedPool userCfg bondedParams userStake
  log "SWITCH WALLETS NOW - CHANGE TO BACK TO ADMIN"

-- Bonded admin deposit (rewards)
--bondedCallContractAdminDepositExample1 :: Effect Unit
--bondedCallContractAdminDepositExample1 = launchAff_ do
--  adminCfg <- Promise.toAffE $ buildContractConfig defaultSdkConfig
--  bondedParams <- liftM
--    ( error
--        "bondedCallContractAdminDepositExample1: Cannot \
--        \ get bonded pool parameters"
--    )
--    testBondedPoolArgs
--  -- Admin deposit
--  Promise.toAffE $ callDepositBondedPool adminCfg bondedParams
--  log "DON'T SWITCH WALLETS - STAY AS ADMIN"

-- Bonded admin pool close
-- bondedCallContractAdminCloseExample1 :: Effect Unit
-- bondedCallContractAdminCloseExample1 = launchAff_ do
--   adminCfg <- Promise.toAffE $ buildContractConfig defaultSdkConfig
--   bondedParams <- liftM
--     ( error
--         "bondedCallContractAdminCloseExample1: Cannot \
--         \ get bonded pool parameters"
--     )
--     testBondedPoolArgs
--   -- Admin close
--   Promise.toAffE $ callCloseBondedPool adminCfg bondedParams
