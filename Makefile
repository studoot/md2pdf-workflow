#
# Ensure we have a defined source document
#
ifeq ($(DOCUMENT),)
$(error Set variable 'DOCUMENT' in the environment or on the Make command-line)
endif

#
# Define NULL redirection appropriately for Windows vs everything else
#
ifeq ($(OS),Windows_NT)
ERROR_REDIRECT := 2>nul
else
ERROR_REDIRECT := 2>/dev/null
endif

#
# Find Git and Mercurial repository roots
#
HGROOT := $(shell hg root $(ERROR_REDIRECT))
GITROOT := $(shell git rev-parse --show-toplevel $(ERROR_REDIRECT))
#
# Calculate relative path from Hg->Git & Git->Hg. The closer repository (the one
# we'll use for the version) will have a relative path that differs from its
# root.
#
GITRELFROMHG := $(GITROOT:$(HGROOT)/%=%)
HGRELFROMGIT := $(HGROOT:$(GITROOT)/%=%)
#
# Conditionally calculate Mercurial version
#
ifneq ($(HGRELFROMGIT),$(HGROOT))
# Get the working copy status (for )
HGDIRTY   := $(findstring +,$(shell hg id -i $(ERROR_REDIRECT)))
SCMVERSION := $(shell hg log -r . -T "{latesttag}{sub('^-0', '', '-{latesttagdistance}')}/{shortest(node, 7)}$(HGDIRTY)" $(ERROR_REDIRECT))
endif
#
# Conditionally calculate Git version
#
ifneq ($(GITRELFROMHG),$(GITROOT))
# Get a commit description - this will be in the form <short-SHA1> or
# <latest-tag>-<latest-tag-distance>/g<short-SHA1>. In all cases, a '+' will be
# appended if the working copy is dirty.
SCMVERSION := $(shell git describe --long --always --tags --dirty=+ $(ERROR_REDIRECT))
# Replace the '-g' before the short SHA-1 hash with '/' (has no effect for the first form of description)
SCMVERSION := $(subst -g,/,$(SCMVERSION))
# Remove '-0' after the tag name when this commit is the tagged commit (has no effect for the first form of description)
SCMVERSION := $(subst -0/,/,$(SCMVERSION))
endif

.PHONY: all
all: pdf html

PRODUCTS = $(foreach var, $(filter DOCUMENT_%,$(.VARIABLES)), $($(var)))
.PHONY: clean
clean:
	$(RM) $(PRODUCTS)

LUA_FILTERS        := plantuml.lua
PANDOC_COMMON_OPTS := -f markdown+smart+auto_identifiers+ascii_identifiers+backtick_code_blocks+fenced_code_attributes $(foreach filter,$(LUA_FILTERS),--lua-filter=$(filter)) '--variable=scm-version:$(SCMVERSION)'

################################################################################
#
# LaTeX/PDF setup
#
DOCUMENT_TEX    := ${DOCUMENT:.md=.tex}
DOCUMENT_PDF    := ${DOCUMENT:.md=.pdf}
TEX_TEMPLATE    := default.latex
PANDOC_TEX_OPTS := $(PANDOC_COMMON_OPTS) --standalone --number-sections --listings --table-of-contents --template=$(TEX_TEMPLATE)\
    --variable=papersize:a4 --variable=fontsize:12pt --variable=documentclass:article --variable=classoption:final --variable=classoption:titlepage\
    --variable=mainfont:Cambria --variable=sansfont:Calibri '--variable=monofont:Lucida Console' '--variable=monofontoptions:Scale=0.75'\
    --variable=linkcolor:DarkSkyBlue --variable=citecolor:DarkSkyBlue --variable=filecolor:DarkSkyBlue --variable=toccolor:DarkSkyBlue --variable=urlcolor:DarkSkyBlue\
    --variable=linestretch:1.2 --variable=geometry:margin=1in --variable=listsonownpage:1
PANDOC_PDF_OPTS := $(PANDOC_TEX_OPTS) --pdf-engine xelatex
%.tex : %.md; pandoc $< -o $@ $(PANDOC_TEX_OPTS)
%.pdf : %.md; pandoc $< -o $@ $(PANDOC_PDF_OPTS)
.PHONY: tex
tex: $(DOCUMENT_TEX)
.PHONY: pdf
pdf: $(DOCUMENT_PDF)
$(DOCUMENT_PDF) $(DOCUMENT_TEX): $(TEX_TEMPLATE)

################################################################################
#
# DOCX setup
#
DOCUMENT_DOCX    := ${DOCUMENT:.md=.docx}
PANDOC_DOCX_OPTS := $(PANDOC_COMMON_OPTS) --standalone --to docx --self-contained
%.docx : %.md; pandoc $< -o $@ $(PANDOC_DOCX_OPTS)
.PHONY: docx
docx: $(DOCUMENT_DOCX)

################################################################################
#
# HTML setup
#
DOCUMENT_HTML    := ${DOCUMENT:.md=.html}
PANDOC_HTML_OPTS := $(PANDOC_COMMON_OPTS) --standalone --table-of-contents --to html5 --self-contained
%.html : %.md; pandoc $< -o $@ $(PANDOC_HTML_OPTS)
.PHONY: html
html: $(DOCUMENT_HTML)

################################################################################
#
# Native (Pandoc AST output) setup
#
DOCUMENT_AST    := ${DOCUMENT:.md=.ast}
PANDOC_AST_OPTS := $(PANDOC_COMMON_OPTS) --standalone --to native
%.ast : %.md; pandoc $< -o $@ $(PANDOC_AST_OPTS)
.PHONY: ast
ast: $(DOCUMENT_AST)
#
################################################################################

$(PRODUCTS): $(DOCUMENT) $(MAKEFILE_LIST) $(LUA_FILTERS)
