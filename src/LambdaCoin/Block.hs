{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeSynonymInstances #-}
module LambdaCoin.Block where

import Control.Monad
import Crypto.Hash
import qualified Data.ByteArray as BA
import Data.ByteString (ByteString)
import Data.Hashable
import Data.Serialize
import Data.Time
import Data.Time.Clock.POSIX
import Data.Word

import LambdaCoin.TestData
import LambdaCoin.Transaction

type BlockHash = Digest SHA256
instance Hashable BlockHash where
    hashWithSalt i bh = hashWithSalt i $ (BA.convert bh :: ByteString)
type CommitmentHash = Digest SHA256

data BlockHeader = BlockHeader
    { prev :: BlockHash
    , commitmentHash :: CommitmentHash
    , timestamp :: UTCTime
    , nonce :: Word32
    }

data Block = Block
    { header :: BlockHeader
    , coinbaseTx :: Transaction
    , standardTxs :: [Transaction]
    }

instance Serialize Block where
    put b = do
        put $ header b
        put $ coinbaseTx b
        put $ standardTxs b
    get = do
        header <- get
        coinbaseTx <- get
        standardTxs <- get
        return Block{..}


instance Serialize BlockHeader where
    put bh = do
        putByteString . BA.convert . prev $ bh
        putByteString . BA.convert . commitmentHash $ bh
        putWord64be . floor . utcTimeToPOSIXSeconds . timestamp $ bh
        putWord32be $ nonce bh

    get = do
        prev' <- digestFromByteString <$> getByteString 32
        prev <- case prev' of
            Nothing -> fail "Could not read Blockhash"
            Just x -> return x
        commitmentHash' <- digestFromByteString <$> getByteString 32
        commitmentHash <- case commitmentHash' of
            Nothing -> fail "Could not read Blockhash"
            Just x -> return x
        timestamp <- posixSecondsToUTCTime . fromIntegral <$> getWord64be
        nonce <- getWord32be
        return BlockHeader{..}

genesisBlock :: Block
genesisBlock = Block
    { header = BlockHeader
        { prev = _
        , commitmentHash = _
        , timestamp = _
        , nonce = _
        }
    , coinbaseTx = Transaction
        { sInputs = []
        , sOutputs = [Output
            { idx = 0
            , dest = pkHash
            , value = 50 * 100000000
            }]
        }
    , standardTxs = []
    }