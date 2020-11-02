module Data.Elf.Types
( Elf64_Half, Elf64_Word, Elf64_Sword, Elf64_Xword, Elf64_Sxword, Elf64_Addr, Elf64_Off, Elf64_Section, Elf64_Versym, UChar
) where

import Data.Word (Word8, Word16, Word32, Word64)
import Data.Int (Int32, Int64)


-- | Unsigned 16-bits integer
type Elf64_Half = Word16

-- | Unsigned 32-bits integer
type Elf64_Word = Word32
-- | Signed 32-bits integer
type Elf64_Sword = Int32

-- | Unsigned 64-bits integer
type Elf64_Xword = Word64
-- | Signed 64-bits integer
type Elf64_Sxword = Int64

-- | Unsigned 64-bits integer
type Elf64_Addr = Word64

-- | Unsigned 64-bits integer
type Elf64_Off = Word64

-- | Unsigned 16-bits integer
type Elf64_Section = Word16

-- | Unsigned 16-bits integer
type Elf64_Versym = Elf64_Half

-- | Unsigned 8-bits integer
type UChar = Word8