module Main (main) where

{-
  This executable can generate CBOR encodings of the NFT minting policy and
  the BondedPool validator. It takes the necessary arguments from the CLI
  to generate them. The resulting scripts are *fully* applied.

-}

import BondedPool (hbondedPoolValidator)
import Cardano.Binary qualified as CBOR
import Codec.Serialise (serialise)
import Data.Aeson (KeyValue ((.=)), encode, object)
import Data.ByteString.Base16 qualified as Base16
import Data.ByteString.Lazy qualified as LBS
import Data.ByteString.Short qualified as SBS
import Data.Text.Encoding qualified as Text
import NFT (hbondedStakingNFTPolicy)
import Options.Applicative (
  CommandFields,
  Mod,
  Parser,
  ParserInfo,
  ReadM,
  argument,
  auto,
  command,
  execParser,
  fullDesc,
  help,
  info,
  long,
  metavar,
  progDesc,
  short,
  showDefault,
  strArgument,
  option,
  str,
  switch,
  subparser,
  value,
 )
import Plutarch.Api.V1 (mintingPolicySymbol, validatorHash)
import Plutus.V1.Ledger.Api (
  PubKeyHash,
  MintingPolicy(getMintingPolicy), Validator(getValidator))
import Plutus.V1.Ledger.Scripts (Script)
import Plutus.V1.Ledger.Tx (TxOutRef (TxOutRef))
import Plutus.V1.Ledger.TxId (TxId)
import Types (BondedPoolParams (BondedPoolParams))

serialisePlutusScript :: String -> FilePath -> Script -> IO ()
serialisePlutusScript title filepath scrpt = do
  let scriptSBS = SBS.toShort . LBS.toStrict . serialise $ scrpt
      scriptRawCBOR = CBOR.serialize' scriptSBS
      scriptType = "PlutusScriptV1" :: String
      plutusJson =
        object
          [ "type" .= scriptType
          , "description" .= title
          , "cborHex" .= Text.decodeUtf8 (Base16.encode scriptRawCBOR)
          ]
      content = encode plutusJson
  LBS.writeFile filepath content

main :: IO ()
main = do
  args <- execParser opts
  pure ()
  case cliCommand args of
    SerialiseNFT txOutRef -> do
      let policy = hbondedStakingNFTPolicy txOutRef
          cs = mintingPolicySymbol policy
      serialisePlutusScript "SingularityNet NFT Policy - Applied"
        (maybe "nft_policy.json" id $ outPath args)
        (getMintingPolicy policy)
      if printHash args
        then putStrLn $ "Currency symbol: " <> show cs
        else pure ()
    SerialiseValidator txOutRef pkh -> do
        let policy = hbondedStakingNFTPolicy txOutRef
            cs = mintingPolicySymbol policy
            validator = hbondedPoolValidator $ BondedPoolParams pkh cs
            vh = validatorHash validator
        serialisePlutusScript "SingularityNet Bonded Pool Validator - Applied"
          (maybe "validator.json" id $ outPath args)
          (getValidator validator)
        if printHash args
          then do putStrLn $ "Validator hash: " <> show vh
                  putStrLn $ "Currency symbol: " <> show cs
          else pure ()

-- Parsers --
data CLI = CLI {
  outPath :: Maybe FilePath,
  printHash :: Bool,
  cliCommand :: CLICommand  
}

data CLICommand
  = SerialiseNFT TxOutRef
  | SerialiseValidator TxOutRef PubKeyHash
  
opts :: ParserInfo CLI
opts = info parser ( 
  fullDesc
  <> progDesc "Serialise the NFT policy or the validator"
  )
  
parser :: Parser CLI
parser = CLI <$>
  outOption
  <*> printHashSwitch
  <*> commandParser

commandParser :: Parser CLICommand
commandParser = subparser $ serialiseNFTCommand <> serialiseValidatorCommand

serialiseNFTCommand :: Mod CommandFields CLICommand
serialiseNFTCommand =
  command "nft" $
    info
      (SerialiseNFT <$> txOutRefParser)
      (fullDesc <> progDesc "Serialise the NFT minting policy by providing a UTXO")

serialiseValidatorCommand :: Mod CommandFields CLICommand
serialiseValidatorCommand =
  command "validator" $
    info
      ( SerialiseValidator
          <$> txOutRefParser
          <*> pubKeyHashParser
      )
      ( fullDesc
          <> progDesc
            "Serialise the validator by providing a UTXO (used to \
            \ obtain the appropiate minting policy) and the stake pool operator's public \
            \ key hash"
      )

pubKeyHashParser :: Parser PubKeyHash
pubKeyHashParser =
  strArgument
    ( metavar "PKH"
        <> help "The public key hash corresponding to the stake pool's wallet"
    )

txOutRefParser :: Parser TxOutRef
txOutRefParser = TxOutRef <$> txIdParser <*> integerParser

txIdParser :: Parser TxId
txIdParser =
  strArgument
    ( metavar "TXID"
        <> help "The transaction id containing the desired output"
    )

integerParser :: Parser Integer
integerParser =
  argument
    (auto :: ReadM Integer)
    ( metavar "IDX"
        <> help "The index of the output"
    )

outOption :: Parser (Maybe FilePath)
outOption =
  option (Just <$> str)
    ( long "out"
        <> short 'o'
        <> metavar "OUT"
        <> help "Location of serialised file"
        <> value Nothing
        <> showDefault
    )

printHashSwitch :: Parser Bool
printHashSwitch = switch (
  long "print-hash" <>
  short 'v'
  )