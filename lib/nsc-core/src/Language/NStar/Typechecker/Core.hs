{-# LANGUAGE GADTs #-}
{-# LANGUAGE StandaloneDeriving #-}

{-|
  Module: Language.NStar.Typechecker.Core
  Description: NStar's typechecking core language
  Copyright: (c) Mesabloo, 2020
  License: BSD3
  Stability: experimental
-}

module Language.NStar.Typechecker.Core
(
  TypedProgram(..)
, TypedDataSection(..), TypedRODataSection(..), TypedUDataSection(..), TypedCodeSection(..)
, TypedStatement(..)
,  -- * Re-exports
  module Language.NStar.Syntax.Core
) where

import Language.NStar.Syntax.Core (Type(..), Kind(..), Register(..), Instruction(..))
import Data.Located (Located)
import Data.Text (Text)

data TypedProgram =
  TProgram
    (Located TypedDataSection)
    (Located TypedRODataSection)
    (Located TypedUDataSection)
    (Located TypedCodeSection)

data TypedDataSection where
  TData :: [()]
        -> TypedDataSection

data TypedRODataSection where
  TROData :: [()]
          -> TypedRODataSection

data TypedUDataSection where
  TUData :: [()]
         -> TypedUDataSection

data TypedCodeSection where
  TCode :: [Located TypedStatement]
        -> TypedCodeSection

data TypedStatement where
  -- | A label stripped off its context.
  TLabel :: Located Text         -- ^ the name of the label
         -> TypedStatement
  -- | An instruction with type information attached to it.
  TInstr :: Located Instruction  -- ^ the typed instruction
         -> [Located Type]       -- ^ type information of the arguments
                                 --
                                 -- Note: we take a list of types because all instructions do not necessarily share the same number of arguments
         -> TypedStatement

deriving instance Show TypedStatement
