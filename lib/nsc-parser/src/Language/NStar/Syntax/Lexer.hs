{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ViewPatterns #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

{-|
  Module: Language.NStar.Syntax.Lexer
  Description: NStar's lexer
  Copyright: (c) Mesabloo, 2020
  License: BSD3
  Stability: experimental
-}

module Language.NStar.Syntax.Lexer
( lexFile ) where

import Language.NStar.Syntax.Core (Token(..), LToken)
import Language.NStar.Syntax.Internal (located, megaparsecBundleToDiagnostic)
import qualified Text.Megaparsec as MP
import qualified Text.Megaparsec.Char as MPC
import qualified Text.Megaparsec.Char.Lexer as MPL
import Data.Text (Text)
import qualified Data.Text as Text (pack, toLower)
import Data.Char (isSpace)
import Data.Function ((&))
import Text.Diagnose (Diagnostic, diagnostic, (<++>))
import Data.Bifunctor (first, second, bimap)
import Control.Applicative (liftA2)
import Console.NStar.Flags (LexerFlags(..))
import Control.Monad.Writer (WriterT, runWriterT)
import Data.Foldable (foldl')
import Language.NStar.Syntax.Errors

type Lexer a = WriterT [LexicalWarning] (MP.Parsec LexicalError Text) a

-- | @space@ only parses any whitespace (not accounting for newlines and vertical tabs) and discards them.
space :: (?lexerFlags :: LexerFlags) => Lexer ()
space = MPL.space spc MP.empty MP.empty
  where spc = () <$ MP.satisfy (and . (<$> [isSpace, (/= '\n'), (/= '\r'), (/= '\v'), (/= '\f')]) . (&))

-- | @lexeme p@ applies @p@ and ignores any space after, if @p@ succeeds. If @p@ fails, @lexeme p@ also fails.
lexeme :: (?lexerFlags :: LexerFlags) => Lexer a -> Lexer a
lexeme = MPL.lexeme space

-- | @symbol str@ tries to parse @str@ exactly, and discards spaces after.
symbol :: (?lexerFlags :: LexerFlags) => Text -> Lexer Text
symbol = MPL.symbol space

-- | Case insensitive variant of 'symbol'.
symbol' :: (?lexerFlags :: LexerFlags) => Text -> Lexer Text
symbol' = MPL.symbol' space

---------------------------------------------------------------------------------------------------------------------------

-- | Runs the program lexer on a given file, and returns either all the tokens identified in the source, or an error.
lexFile :: (?lexerFlags :: LexerFlags)
        => FilePath                                     -- ^ File name
        -> Text                                         -- ^ File content
        -> Either (Diagnostic [] String Char) ([LToken], Diagnostic [] String Char)
lexFile file input =
  bimap (megaparsecBundleToDiagnostic "Lexical error on input") (second toDiagnostic) $ MP.runParser (runWriterT lexProgram) file input
  where
    toDiagnostic warns = foldl' (<++>) diagnostic (fromLexicalWarning <$> warns)


-- | Transforms a source code into a non-empty list of tokens (accounting for 'EOF').
lexProgram :: (?lexerFlags :: LexerFlags) => Lexer [LToken]
lexProgram = lexeme (pure ()) *> ((<>) <$> tokens <*> ((: []) <$> eof))
  where
    tokens = MP.many . lexeme $ MP.choice
      [ comment, identifierOrKeyword, literal, anySymbol, eol ]

-- | Parses an end of line and returns 'EOL'.
eol :: (?lexerFlags :: LexerFlags) => Lexer LToken
eol = located (EOL <$ MPC.eol)

-- | Parses an end of file and returns 'EOF'.
--
--   Note that all files end with 'EOF'.
eof :: (?lexerFlags :: LexerFlags) => Lexer LToken
eof = located (EOF <$ MP.eof)

-- | Parses any kind of comment, inline or multiline.
comment :: (?lexerFlags :: LexerFlags) => Lexer LToken
comment = lexeme $ located (inline MP.<|> multiline)
  where
    inline = InlineComment . Text.pack <$> (symbol "#" *> MP.manyTill MP.anySingle (MP.lookAhead (() <$ MPC.eol MP.<|> MP.eof)))
    multiline = MultilineComment . Text.pack <$> (symbol "/*" *> MP.manyTill MP.anySingle (symbol "*/"))

-- | Parses any symbol like @[@ or @,@.
anySymbol :: (?lexerFlags :: LexerFlags) => Lexer LToken
anySymbol = lexeme . located . MP.choice $ sat <$> symbols
 where
   sat (ret, sym) = ret <$ MPC.string sym

   symbols =
     [ (LParen, "("), (LBrace, "{"), (LBracket, "["), (LAngle, "<")
     , (RParen, ")"), (RBrace, "}"), (RBracket, "]"), (RAngle, ">")
     , (Star, "*")
     , (Dollar, "$")
     , (Percent, "%")
     , (Comma, ",")
     , (DoubleColon, "::"), (Colon, ":")
     , (Dot, ".")
     , (Minus, "-") ]

-- | Tries to parse an identifier. If the result appears to be a keyword, it instead returns a keyword.
identifierOrKeyword :: (?lexerFlags :: LexerFlags) => Lexer LToken
identifierOrKeyword = lexeme $ located do
  transform . Text.pack
           <$> ((:) <$> MPC.letterChar
                    <*> MP.many (MPC.alphaNumChar MP.<|> MPC.char '_'))
 where
    transform :: Text -> Token
    transform w@(Text.toLower -> rw) = case rw of
      -- Instructions
      "mov"    -> Mov
      "ret"    -> Ret
      "jmp"    -> Jmp
      "call"   -> Call
      -- Registers
      "rax"    -> Rax
      "rbx"    -> Rbx
      "rcx"    -> Rcx
      "rdx"    -> Rdx
      "rdi"    -> Rdi
      "rsi"    -> Rsi
      "rsp"    -> Rsp
      "rbp"    -> Rbp
      -- Keywords
      "forall" -> Forall
      "sptr"   -> Sptr
      -- Identifier
      _        -> Id w

-- | Parses a literal value (integer or character).
literal :: (?lexerFlags :: LexerFlags) => Lexer LToken
literal = lexeme . located $ MP.choice
  [ Integer <$> prefixed "0b" (Text.pack <$> MP.some binary)
  , Integer <$> prefixed "0x" (Text.pack <$> MP.some hexadecimal)
  , Integer <$> prefixed "0o" (Text.pack <$> MP.some octal)
  , Integer . Text.pack <$> MP.some decimal
  , Char <$> MP.between (MPC.char '\'') (MPC.char '\'') charLiteral ]
 where
   charLiteral = escapeChar MP.<|> MP.satisfy (liftA2 (&&) (/= '\n') (/= '\r'))
   escapeChar = MPC.char '\\' *> (codes MP.<|> MP.customFailure UnrecognizedEscapeSequence)
   codes = MP.choice
     [ '\a'   <$ MPC.char 'a'   -- Bell
     , '\b'   <$ MPC.char 'b'   -- Backspace
     , '\ESC' <$ MPC.char 'e'   -- Escape character
     , '\f'   <$ MPC.char 'f'   -- Formfeed page break
     , '\n'   <$ MPC.char 'n'   -- Newline (Line feed)
     , '\r'   <$ MPC.char 'r'   -- Carriage return
     , '\t'   <$ MPC.char 't'   -- Horizontal tab
     , '\v'   <$ MPC.char 'v'   -- Vertical tab
     , '\\'   <$ MPC.char '\\'  -- Backslash
     , '\''   <$ MPC.char '\''  -- Apostrophe
     , '"'    <$ MPC.char '"'   -- Double quotation mark
     , '\0'   <$ MPC.char '0'   -- Null character
       -- TODO: add support for unicode escape sequences "\uHHHH" and "\uHHHHHHHH"
     ]

   binary, octal, decimal, hexadecimal :: Lexer Char
   binary      = MP.choice $ MPC.char <$> [ '0', '1' ]
   octal       = MP.choice $ binary : (MPC.char <$> [ '2', '3', '4', '5', '6', '7' ])
   decimal     = MP.choice $ octal : (MPC.char <$> [ '8', '9' ])
   hexadecimal = MP.choice $ decimal : (MPC.char' <$> [ 'a', 'b', 'c', 'd', 'e', 'f' ])
   {-# INLINE binary #-}
   {-# INLINE octal #-}
   {-# INLINE decimal #-}
   {-# INLINE hexadecimal #-}

   prefixed :: (c ~ MP.Tokens Text) => c -> Lexer c -> Lexer c
   prefixed prefix p = (<>) <$> MPC.string' prefix <*> p
   {-# INLINE prefixed #-}
