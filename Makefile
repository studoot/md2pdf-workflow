ifeq ($(DOCUMENT),)
$(error Set variable 'DOCUMENT' in the environment or on the Make command-line)
endif

DOCUMENT_PDF = ${DOCUMENT:.md=.pdf}
DOCUMENT_TEX = ${DOCUMENT:.md=.tex}
DOCUMENT_AST = ${DOCUMENT:.md=.ast}
DOCUMENT_HTML = ${DOCUMENT:.md=.html}

ifeq ($(OS),Windows_NT)
ERROR_REDIRECT:=2>nul
else
ERROR_REDIRECT:=2>/dev/null
endif

HGROOT:=$(shell hg root $(ERROR_REDIRECT))
ifneq ($(HGROOT),)
# Get the working copy status (for )
HGCOMMIT:=$(shell hg id -i $(ERROR_REDIRECT))
SCMVERSION:=$(shell hg log -r . -T "{latesttag}{sub('^-0', '', '-{latesttagdistance}')}/{shortest(node, 7)}" $(ERROR_REDIRECT))/$(HGCOMMIT)
endif
GITROOT:=$(shell git rev-parse --show-toplevel $(ERROR_REDIRECT))
ifneq ($(GITROOT),)
# Get a commit description - this will be in the form <short-SHA1> or
# <latest-tag>-<latest-tag-distance>/g<short-SHA1>. In all cases, a '+' will be
# appended if the working copy is dirty.
SCMVERSION:=$(subst -0/,/,$(subst -g,/,$(shell git describe --long --always --tags --dirty=+ $(ERROR_REDIRECT))))
# Replace the '-g' before the short SHA-1 hash with '/' (has no effect for the first form of description)
SCMVERSION:=$(subst -g,/,$(SCMVERSION))
# Remove '-0' after the tag name when this commit is the tagged commit (has no effect for the first form of description)
SCMVERSION:=$(subst -0/,/,$(SCMVERSION))
endif

PANDOC_COMMON_OPTS = -f markdown+smart+auto_identifiers+ascii_identifiers
TEX_TEMPLATE       = pdf-template.tex
PANDOC_TEX_OPTS    = --standalone --number-sections --listings --template=$(TEX_TEMPLATE) --table-of-contents
PANDOC_PDF_OPTS    = $(PANDOC_TEX_OPTS) --pdf-engine xelatex
PANDOC_HTML_OPTS   = --standalone --table-of-contents --to html5
PANDOC_AST_OPTS    = --standalone
PANDOC_VARIABLES   = '--variable=scm-version:$(SCMVERSION)'

%.html : %.md; pandoc $< -o $@ $(MARKDOWN_DIALECT) $(PANDOC_HTML_OPTS) $(PANDOC_VARIABLES)
%.pdf : %.md; pandoc $< -o $@ $(MARKDOWN_DIALECT) $(PANDOC_TEX_OPTS) $(PANDOC_PDF_OPTS) $(PANDOC_VARIABLES)
%.tex : %.md; pandoc $< -o $@ $(MARKDOWN_DIALECT) $(PANDOC_TEX_OPTS) $(PANDOC_VARIABLES)
%.ast : %.md; pandoc $< -o $@ $(MARKDOWN_DIALECT) -t native $(PANDOC_VARIABLES)

.PHONY: all
all: pdf html

.PHONY: html
html: $(DOCUMENT_HTML)

.PHONY: pdf
pdf: $(DOCUMENT_PDF)

.PHONY: TeX
TeX: $(DOCUMENT_TEX)

.PHONY: ast
ast: $(DOCUMENT_AST)

.PHONY: clean
clean:
	rm -f $(DOCUMENT_PDF) $(DOCUMENT_TEX)

$(DOCUMENT_PDF) $(DOCUMENT_TEX) $(DOCUMENT_HTML) $(DOCUMENT_AST): $(DOCUMENT) $(MAKEFILE_LIST)
$(DOCUMENT_PDF) $(DOCUMENT_TEX): $(TEX_TEMPLATE)
