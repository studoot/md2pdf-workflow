#!  /bin/bash
ROOT=$(dirname "$0")
usage() {
    echo "usage $0 [options] DOCUMENT"
    echo ""
    echo "Options"
    echo "  -h,--help      Display this message"
    echo "  -d,--docx      Produce DOCX"
    echo "  -m,--html      Produce HTML"
    echo "  -p,--pdf       Produce PDF"
    echo "  -t,--tex       Produce TeX"
}

scmversion() {
    #
    # Find Git and Mercurial repository roots
    #
    HGROOT=$(hg root 2>/dev/null)
    GITROOT=$(git rev-parse --show-toplevel 2>/dev/null)
    #
    # Calculate relative path from Hg->Git & Git->Hg. The closer repository (the one
    # we'll use for the version) will have a relative path that differs from its
    # root.
    #
    GITRELFROMHG=${GITROOT##${HGROOT}}
    HGRELFROMGIT=${HGROOT##${GITROOT}}
    #
    # Conditionally calculate Mercurial version
    #
    if [ "${HGROOT}" != "${HGRELFROMGIT}" ]; then
        # Get the working copy status
        hg log -r . -T "{latesttag}{sub('^-0', '', '-{latesttagdistance}')}/{shortest(node, 7)}$(hg id -i 2>/dev/null | tr -Cd +)" 2>/dev/null
    fi
    #
    # Conditionally calculate Git version
    #
    if [ "${GITRELFROMHG}" != "${GITROOT}" ]; then
        # Get a commit description - this will be in the form <short-SHA1> or
        # <latest-tag>-<latest-tag-distance>/g<short-SHA1>. In all cases, a '+' will be
        # appended if the working copy is dirty.
        # Replace the '-g' before the short SHA-1 hash with '/' (has no effect for the first form of description)
        # Remove '-0' after the tag name when this commit is the tagged commit (has no effect for the first form of description)
        git describe --long --always --tags --dirty=+ 2>/dev/null | sed -e 's/-g/\//;s/-0//'
    fi
}

# Check for dependencies
if ! command -v xelatex >&/dev/null; then
    NOPDF=1
fi
if ! command -v pandoc >&/dev/null; then
    printf >&2 "Unable to find pandoc - exiting\n"
    exit 1
fi

# Parse command line arguments
PARSED_OPTIONS=$(getopt -n "$0" -o hdmpt --long "help,docx,html,pdf,tex" -- "$@") || {
    printf "Argument parsing failed - exiting"
    exit 1
}
eval set -- "$PARSED_OPTIONS"
output_types=
while true; do
    case "$1" in
        -h | --help)
            usage
            shift
            ;;
        -d | --docx)
            "output_types+=[docx]"
            shift
            ;;
        -m | --html)
            "output_types+=[html]"
            shift
            ;;
        -p | --pdf)
            [ -z ${NOPDF} ] && "output_types+=[pdf]" || printf >&2 "Unable to find TeX tools for PDF output - PDF conversion disabled\n"
            shift
            ;;
        -t | --tex)
            "output_types+=[tex]"
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Unrecognised option $1"
            echo ""
            usage
            exit 1
            ;;
    esac
done
output_types=${output_types:-[pdf]}
PANDOC_COMMON_OPTS=("-f" "markdown+smart+auto_identifiers+ascii_identifiers+backtick_code_blocks+fenced_code_attributes+yaml_metadata_block+pandoc_title_block" "--variable=scm-version:$(scmversion)")
PANDOC_TEX_OPTS=("${PANDOC_COMMON_OPTS[@]}" --standalone --number-sections --listings --table-of-contents "--template=${ROOT}/default.latex"
    "--variable=papersize:a4" "--variable=fontsize:12pt"
    "--variable=documentclass:article" "--variable=classoption:final" "--variable=classoption:titlepage" "--variable=listsonownpage:1"
    "--variable=mainfont:Cambria" "--variable=sansfont:Calibri" "--variable=monofont:Lucida Console" "--variable=monofontoptions:Scale=0.75"
    "--variable=linkcolor:DarkSkyBlue" "--variable=citecolor:DarkSkyBlue" "--variable=filecolor:DarkSkyBlue" "--variable=toccolor:DarkSkyBlue" "--variable=urlcolor:DarkSkyBlue"
    "--variable=linestretch:1.2"
    "--variable=geometry:top=2cm" "--variable=geometry:left=1in" "--variable=geometry:right=1in" "--variable=geometry:bottom=1cm"
    "--variable=geometry:includeheadfoot=true")
PANDOC_PDF_OPTS=("${PANDOC_TEX_OPTS[@]}" "--pdf-engine=xelatex")
PANDOC_DOCX_OPTS=("${PANDOC_COMMON_OPTS[@]}" --standalone --to docx --self-contained)
PANDOC_HTML_OPTS=("${PANDOC_COMMON_OPTS[@]}" --standalone --table-of-contents --to html5 --self-contained)

for doc in "$@"; do
    [ -f "${doc}" ] || {
        printf >&2 "Document %s doesn't exist!\n" "${doc}"
        continue
    }

    if [[ "${output_types}" = *"[pdf]"* ]]; then
        pdf=${doc%%.md}.pdf
        printf "Converting %s to %s document %s\n" "${doc}" "PDF" "${pdf}"
        pandoc "${doc}" -o "${pdf}" "${PANDOC_PDF_OPTS[@]}"
    fi

    if [[ "${output_types}" = *"[tex]"* ]]; then
        tex=${doc%%.md}.tex
        printf "Converting %s to %s document %s\n" "${doc}" "TEX" "${tex}"
        pandoc "${doc}" -o "${tex}" "${PANDOC_TEX_OPTS[@]}"
    fi

    if [[ "${output_types}" = *"[docx]"* ]]; then
        docx=${doc%%.md}.docx
        printf "Converting %s to %s document %s\n" "${doc}" "DOCX" "${docx}"
        pandoc "${doc}" -o "${docx}" "${PANDOC_DOCX_OPTS[@]}"
    fi

    if [[ "${output_types}" = *"[html]"* ]]; then
        html=${doc%%.md}.html
        printf "Converting %s to %s document %s\n" "${doc}" "HTML" "${html}"
        pandoc "${doc}" -o "${html}" "${PANDOC_HTML_OPTS[@]}"
    fi

done
