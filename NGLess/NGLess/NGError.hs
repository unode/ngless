{-# LANGUAGE OverloadedStrings, FlexibleContexts #-}
module NGLess.NGError
    ( NGError(..)
    , NGErrorType(..)
    , NGLessIO
    , NGLess
    , runNGLess
    , testNGLessIO
    , throwShouldNotOccur
    , throwScriptError
    , throwDataError
    , throwSystemError
    , throwGenericError
    ) where

import           Control.DeepSeq
import           Control.Monad.Except
import           Control.Monad.Trans.Resource

-- | An error in evaluating an ngless script
-- Normally, it's easier to use the function interface of 'throwShouldNotOccur' and friends
data NGErrorType =
    ShouldNotOccur -- ^ bug in ngless
    | ScriptError -- ^ bug in user script
    | DataError -- ^ bad input
    | SystemError -- ^ system/IO issue
    | GenericError -- ^ arbitrary error message
    deriving (Show, Eq)

instance NFData NGErrorType where
    rnf !_ = ()

data NGError = NGError !NGErrorType !String
    deriving (Show, Eq)

instance NFData NGError where
    rnf !_ = ()

type NGLessIO = ExceptT NGError (ResourceT IO)
type NGLess = Either NGError


runNGLess :: (MonadError NGError m) => Either NGError a -> m a
runNGLess (Left err) = throwError err
runNGLess (Right v) = return v

testNGLessIO :: NGLessIO a -> IO a
testNGLessIO act = do
        perr <- (runResourceT . runExceptT) act
        return (showError perr)
    where
        showError (Right a) = a
        showError (Left e) = error (show e)

-- | Internal bug: user is requested to submit a bug report
throwShouldNotOccur :: (MonadError NGError m) => String -> m a
throwShouldNotOccur = throwError . NGError ShouldNotOccur

-- | Script error: user can fix error by re-writing the script
throwScriptError :: (MonadError NGError m) => String -> m a
throwScriptError = throwError . NGError ScriptError

-- | Data error: problem with input data
throwDataError :: (MonadError NGError m) => String -> m a
throwDataError = throwError . NGError DataError

-- | System error: issues such as *subcommand failed* or *out of disk*
throwSystemError :: (MonadError NGError m) => String -> m a
throwSystemError = throwError . NGError SystemError

-- | Generic error: any error message
throwGenericError :: (MonadError NGError m) => String -> m a
throwGenericError = throwError . NGError GenericError

