default:

SHELL      = bash
VERBOSE   ?= -s
MAKEFLAGS += $(VERBOSE)
MSG        = @echo generate $@ ...
GOSH      := ./tool/gosh/gosh --style html --html-img-format png --utf8

# list of authors corresponds to the subdirectories in content/
AUTHORS := $(notdir $(wildcard content/*))

# ignore the author if there is no author.txt
INCOMPLETE_AUTHORS :=
$(foreach A,$(AUTHORS), $(if $(wildcard content/$A/author.txt),,\
	$(eval INCOMPLETE_AUTHORS += $A)))
AUTHORS := $(filter-out $(INCOMPLETE_AUTHORS),$(AUTHORS))


# obtain author names and further info
$(foreach A,$(AUTHORS),$(eval AUTHOR_NAME($A)  += $(shell cat authors/$A/name)))
$(foreach A,$(AUTHORS),$(eval AUTHOR_FLAIR($A) += $(shell cat authors/$A/flair)))

# https://stackoverflow.com/questions/52674/simplest-way-to-reverse-the-order-of-strings-in-a-make-variable
reverse = $(if $(1),$(call reverse,$(wordlist 2,$(words $(1)),$(1)))) $(firstword $(1))

# list of postings per author
$(foreach A,$(AUTHORS),\
  $(eval POSTINGS($A) := $(patsubst %.txt,%,\
    $(basename $(call reverse,$(sort $(notdir $(wildcard content/$A/2???-??-??-*.txt))))))))

# list of all postings, each in the form <title>/<author>
ALL_POSTINGS := $(foreach A,$(AUTHORS),$(addsuffix /$A,${POSTINGS($A)}))

# access each part of a tuple of the form 'first_part/second_part'
first_part  = $(firstword $(subst /, ,$1))
second_part = $(notdir $1)

# access information about postings of the given path <author>/<posting>
author_name  = ${AUTHOR_NAME($(call first_part,$1))}
author_flair = ${AUTHOR_FLAIR($(call first_part,$1))}

# list of postings and authors sorted by date (most recent first)
REV_POSTINGS := $(call reverse,$(sort $(ALL_POSTINGS)))
REV_AUTHORS  := $(foreach P,$(REV_POSTINGS),$(call second_part,$P))

# list of authors ordered by their most recent contribution
RECENT_AUTHORS :=
$(foreach A,$(REV_AUTHORS),$(if $(filter $A,$(RECENT_AUTHORS)),,\
	$(eval RECENT_AUTHORS += $A)))

# list of most recent postings
RECENT_POSTINGS := $(foreach P,\
                     $(wordlist 1,100,$(REV_POSTINGS)),\
                       $(call second_part,$P)/$(call first_part,$P))

HTML_DIRS := html $(addprefix html/,$(AUTHORS))
$(HTML_DIRS):
	mkdir -p $@

# list of HTML postings to generate
POSTINGS_HTML := $(foreach A,$(AUTHORS),$(addprefix html/$A/,$(POSTINGS($A))))

# files to generate
GENERATED_FILES := $(POSTINGS_HTML) \
                   html/index html/base.css html/w3.css html/icon.ico \
                   html/rss html/RSS \
                   $(foreach A,$(AUTHORS),html/$A/author.png) \
                   $(foreach A,$(AUTHORS),html/$A/index) \
                   $(foreach A,$(AUTHORS),html/$A/author) \
                   $(foreach A,$(AUTHORS),\
                     $(addprefix html/$A/,$(notdir $(wildcard content/$A/*.png)))) \
                   $(addprefix html/,$(notdir $(wildcard style/*.png)))

# generate author information snippets before any of the author's postings
$(foreach A,$(AUTHORS),$(eval $(addprefix html/$A/,${POSTINGS($A)}) : html/$A/author))

default: $(GENERATED_FILES)

$(GENERATED_FILES): $(wildcard style/*) Makefile $(HTML_DIRS)

gosh_metadata_args = --link $1 \
                     --author "$(call author_name,$1)" \
                     --flair ' $(call author_flair,$1) '

html/%: content/%.txt
	$(MSG)
	$(GOSH) --style style/nice_date.gosh --style style/posting.gosh --top-path "../" \
	        $(call gosh_metadata_args,$*) $< > $@

# front page depends on the most recent postings
html/index: $(addprefix content/,$(addsuffix .txt,$(RECENT_POSTINGS)))

#
# Front page with list of authors and summaries of the most recent postings
#
html/index:
	$(MSG)
	cat style/front-header > $@
	cat style/front-title >> $@
	echo "    <main class=\"content w3-row-padding w3-auto\">" >> $@
	echo "      <div id=\"authors-large\" class=\"w3-col x1 w3-hide-small w3-hide-medium\">" >> $@
	echo "        <div class=\"authors menu\">" >> $@
	echo "          <div class=\"menu-inner\">" >> $@
	echo "            <div class=\"menu-title\">Authors</div>" >> $@
	echo "            <ul>" >> $@
	$(foreach A,$(RECENT_AUTHORS), \
	  echo "              <li><a href=\"$A/index\">" \
	       "<img src=\"$A/author.png\" alt=\"${AUTHOR_NAME($A)} avatar\"/>${AUTHOR_NAME($A)}<br/>" \
	       "<span class=\"flair\">${AUTHOR_FLAIR($A)}</span></a></li>" >> $@;)
	echo "            </ul>" >> $@
	echo "          </div> <!-- menu-inner -->" >> $@
	echo "        </div> <!-- authors menu -->" >> $@
	echo "      </div> <!-- authors-large -->" >> $@
	echo "      <div id=\"posts\" class=\"w3-col x3\">" >> $@
	echo "        <div id=\"post-list\">" >> $@
	echo "          <ul>" >> $@
	$(foreach P,$(RECENT_POSTINGS), \
	  $(GOSH) --style style/nice_date.gosh --style style/summary.gosh \
	          $(call gosh_metadata_args,$P) content/$P.txt >> $@;)
	echo "          </ul>" >> $@
	echo "        </div> <!-- post-list -->" >> $@
	echo "      </div> <!-- posts -->" >> $@
	echo "      <div id=\"authors-small\" class=\"w3-col w3-hide-large\">" >> $@
	echo "        <div class=\"authors menu\">" >> $@
	echo "          <div class=\"menu-inner\">" >> $@
	echo "            <div class=\"menu-title\">Authors</div>" >> $@
	echo "            <ul>" >> $@
	$(foreach A,$(RECENT_AUTHORS), \
	  echo "            <li><a href=\"$A/index\">" \
	       "<img src=\"$A/author.png\" alt=\"${AUTHOR_NAME($A)} avatar\"/>${AUTHOR_NAME($A)}<br/>" \
	       "<span class=\"flair\">${AUTHOR_FLAIR($A)}</span></a></li>" >> $@;)
	echo "            </ul>" >> $@
	echo "          </div> <!-- menu-inner -->" >> $@
	echo "        </div> <!-- authors menu -->" >> $@
	echo "      </div> <!-- authors-small -->" >> $@
	cat style/external-links-menu >> $@
	cat style/footer >> $@

html/rss:
	$(MSG)
	cat style/rss-header > $@
	$(foreach P,$(RECENT_POSTINGS), \
	  $(GOSH) --style style/nice_date.gosh --style style/rss_item.gosh \
	          $(call gosh_metadata_args,$P) content/$P.txt >> $@;)
	cat style/rss-footer >> $@

html/RSS: html/rss
	cp $< $@

#
# <author>/author information snippet presented to the left of the
# author's content
#
html/%/author:
	$(MSG)
	$(GOSH) --style style/author.gosh --top-path "../" \
	        $(call gosh_metadata_args,$*/$P) content/$*/author.txt > $@;

# let all <author>/index files depend on <author>/author files
$(foreach A,$(AUTHORS),$(eval html/$A/author : content/$A/author.txt))
$(foreach A,$(AUTHORS),$(eval html/$A/index : html/$A/author))

#
# <author>/index with a list of all postings written by the author
#
html/%/index:
	$(MSG)
	cat style/subdir/header-top > $@
	echo "    <title>Genodians.org: posts of $(shell cat authors/$*/name)</title>" >> $@
	cat style/subdir/header-bottom >> $@
	cat style/subdir/title >> $@
	echo "    <main class=\"content w3-row-padding w3-auto\">" >> $@
	echo "      <div id=\"author-all\" class=\"w3-col x1\">" >> $@
	cat html/$*/author >> $@
	echo "      </div> <!-- author-all -->" >> $@
	echo "      <div id=\"posts\" class=\"w3-col x3\">" >> $@
	echo "        <div id=\"post-list\">" >> $@
	echo "          <ul>" >> $@
	$(foreach P,${POSTINGS($*)}, \
	  $(GOSH) --style style/nice_date.gosh --style style/summary.gosh --top-path "../" \
	          $(call gosh_metadata_args,$*/$P) content/$*/$P.txt >> $@;)
	echo "          </ul>" >> $@
	echo "        </div> <!-- post-list -->" >> $@
	echo "      </div> <!-- posts -->" >> $@
	cat style/external-links-menu >> $@
	cat style/footer >> $@

html/%.css: style/%.css
	cp $< $@
html/%.ico: style/%.ico
	cp $< $@
html/%.png: style/%.png
	cp $< $@
html/%.png: content/%.png
	cp $< $@
html/%/author.png: content/%/author.png
	cp $< $@

clean:
	rm -rf html


#
# Debugging support
#
# The following rules download and archive the content of all authors.
# By using the resulting content.tar archive, the genodians scenario can be
# executed without the download and extraction phase.
#

ALL_AUTHORS := $(notdir $(wildcard authors/*))

$(foreach A,$(ALL_AUTHORS),$(eval AUTHOR_ZIP_URL($A) += $(shell cat authors/$A/zip_url)))

author_zip_url = ${AUTHOR_ZIP_URL($(call first_part,$1))}

downloaded_content:
	mkdir -p downloaded_content
	(\
		cd downloaded_content; \
		$(foreach A,$(ALL_AUTHORS),\
			mkdir -p $A; \
			wget -O $A.zip $(call author_zip_url,$A); \
			unzip -j -d $A $A.zip; \
			rm $A.zip; \
		) \
	)

content.tar: downloaded_content
	tar cf content.tar -C downloaded_content .

clean: clean_downloaded_content

clean_downloaded_content:
	rm -rf downloaded_content content.tar

