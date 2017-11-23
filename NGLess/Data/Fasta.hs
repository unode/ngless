{- Copyright 2017 NGLess Authors
 - License: MIT
 -}
{-# LANGUAGE FlexibleContexts #-}
module Data.Fasta
    ( FastaSeq(..)
    , faseqLength
    , faConduit
    , faWriteC
    , faWriteConduit
    ) where

import qualified Data.ByteString as B
import qualified Data.Conduit as C
import           Data.Conduit ((.|))
import qualified Data.Conduit.Combinators as C
import           Data.Word
import           Control.Monad.Except
import           Control.DeepSeq

import NGLess.NGError
import Utils.Conduit

data FastaSeq = FastaSeq
                { seqheader :: !B.ByteString
                , seqdata :: !B.ByteString
                } deriving (Eq, Show)

instance NFData FastaSeq where
    rnf !_ = ()

faseqLength :: FastaSeq -> Int
faseqLength = B.length . seqdata

greaterThanSign :: Word8
greaterThanSign = 62

faConduit :: (MonadIO m, MonadError NGError m) => C.Conduit B.ByteString m FastaSeq
faConduit = linesC .| faConduit'

faConduit' :: (MonadIO m, MonadError NGError m) => C.Conduit ByteLine m FastaSeq
faConduit' = C.await >>= \case
                Nothing -> return ()
                Just (ByteLine header)
                  | B.null header -> throwDataError ("Unexpected empty string at line 1")
                  | B.head header == greaterThanSign -> getdata (1 :: Int) (B.drop 1 header) []
                  | otherwise -> throwDataError"Unexpected data"
  where
    getdata !n header toks = C.await >>= \case
                                Nothing -> C.yield $ FastaSeq header (B.concat $ reverse toks)
                                Just (ByteLine next)
                                    | B.null next -> throwDataError ("Unexpected empty string at line " ++ show (n+1) ++ " (expected header line).")
                                    | B.head next == greaterThanSign -> do
                                            C.yield $ FastaSeq header (B.concat $ reverse toks)
                                            getdata (n+1) (B.drop 1 next) []
                                    | otherwise -> getdata (n+1) header (next:toks)

faWriteC :: (Monad m) => C.Conduit FastaSeq m B.ByteString
faWriteC = C.awaitForever $ \(FastaSeq h s) -> do
    C.yield ">"
    C.yield h
    C.yield "\n"
    C.yield s
    C.yield "\n"

faWriteConduit :: (Monad m) => [FastaSeq] -> C.Source m B.ByteString
faWriteConduit fas = C.yieldMany fas .| faWriteC