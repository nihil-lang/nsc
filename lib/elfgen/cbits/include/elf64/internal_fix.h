#ifndef ELFGEN_ELF64_INTERNAL_FIX_H
#define ELFGEN_ELF64_INTERNAL_FIX_H

#include "section_header.h"

char const *get_section_name(elf_section_header const *section);

int find_section_index_by_name(elf_section_header const **sections, unsigned int size, char const *name);

int find_section_symbol_by_index(Elf64_Sym **symtab, unsigned int symtab_len, int section_index);

#endif