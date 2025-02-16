# Tools

PHPMD ?= phpmd
NPM ?= npm
MSGFMT ?= msgfmt
PHP ?= php
JAVA ?= java

# Variables

DESTDIR ?= deploy

# Javascript compiler

JSDEPLOY = $(DESTDIR)/client
DEPLOYPURIFY = $(JSDEPLOY)/dompurify

JSCOMPILER ?= $(JAVA) -jar tools/lib/compiler.jar
CSSCOMPILER ?= $(JAVA) -jar tools/lib/yuicompressor-2.4.8.jar

JSOPTIONS = --externs client/externs.js \
	--compilation_level SIMPLE --warning_level VERBOSE --jscomp_off=es5Strict --strict_mode_input=false \
	--jscomp_off=globalThis --jscomp_off=misplacedTypeAnnotation --jscomp_off=nonStandardJsDocs \
	--jscomp_off=missingProperties --jscomp_off=invalidCasts --jscomp_off=checkTypes \
	--jscomp_warning=visibility --jscomp_warning=unknownDefines --jscomp_warning=undefinedVars \
	--jscomp_warning=strictModuleDepCheck --jscomp_warning=deprecated \
	--jscomp_error=checkVars --jscomp_warning=checkRegExp --jscomp_warning=accessControls

# Server files

DISTFILES = $(addprefix $(DESTDIR)/,config.php.dist debug.php.dist)
ROBOTS = $(addprefix $(DESTDIR)/, robots.txt)
LANGTXT = $(wildcard server/language/*/language.txt)
LANGTXTDEST = $(addprefix $(DESTDIR)/, $(LANGTXT))
POS = $(wildcard server/language/*/LC_MESSAGES/grommunio_web.po)
MOS = $(patsubst %.po,$(DESTDIR)/%.mo,$(POS))
INCLUDES = $(shell find server/includes -name '*.php')
PHPFILES = $(filter-out $(DESTDIR)/config.php, $(filter-out $(DESTDIR)/debug.php, $(patsubst %.php,$(DESTDIR)/%.php,$(wildcard *.php) $(INCLUDES))))
SERVERROOTFILES = $(addprefix $(DESTDIR)/,server/manifest.dtd)
IS_SUPPORTED_BUILD ?= $(if $(filter 1, $(SUPPORTED_BUILD)), supported validate-supported)

# Client files

CSS = $(wildcard client/resources/css/*.* client/resources/css/*/*.* client/extjs/ux/css/ux-all.css client/extjs/resources/css/*.css)
CSSDEST = $(addprefix $(DESTDIR)/, $(CSS))
IMAGEDIR = client/resources/images
APPICONS = $(wildcard $(IMAGEDIR)/app-icons/*.*)
APPICONSSCSS = client/resources/scss/base/_icons.scss
APPICONSEXTENSIONSFILE = client/resources/images/app-icons.extensions.json
IMAGES = $(filter-out $(APPICONSEXTENSIONSFILE), $(wildcard $(IMAGEDIR)/*.* $(IMAGEDIR)/whatsnew/*.*))
IMAGESDEST = $(addprefix $(DESTDIR)/, $(IMAGES))
EXTJSMODFILES = $(wildcard client/extjs-mod/*.js)
ICONEXTENSIONSFILE = client/resources/iconsets/extensions.json
ICONSETS = $(notdir $(filter-out client/resources/iconsets/extensions.json, $(wildcard client/resources/iconsets/*)))
ICONS = $(foreach iconsetdir,$(ICONSETS),$(wildcard client/resources/iconsets/$(iconsetdir)/src/png/*/*.png))
ICONSETSDEST = $(addprefix $(DESTDIR)/client/resources/iconsets/, $(ICONSETS))
ICONSETSCSS = $(foreach iconsetdir,$(ICONSETS),client/resources/iconsets/$(iconsetdir)/$(iconsetdir)-icons.css)
ICONSETSCSSDEST = $(addprefix $(DESTDIR)/, $(ICONSETSCSS))
EXTJS = client/extjs/ext-base.js client/extjs/ext-all.js
THIRDPARTY = $(shell find client/third-party -name '*.js') client/third-party/tokenizr/tokenizr.js

PURIFYJS = client/dompurify/purify.min.js
DEPLOYPURIFYJS = $(DEPLOYPURIFY)/purify.js

POFILES = $(wildcard server/language/*/*/*.po)
JSFILES = $(shell find client/zarafa -name '*.js')

# Build

.PHONY: deploy server client all

all: deploy

deploy: server client plugins css

build: node_modules deploy
test: jstest

server: $(MOS) $(LANGTXTDEST) $(PHPFILES) $(DISTFILES) $(ROBOTS) $(DESTDIR)/version $(DESTDIR)/cachebuster $(SERVERROOTFILES)

client: $(CSSDEST) $(ICONSETSDEST) $(IMAGESDEST) js
	cp -r client/resources/fonts $(DESTDIR)/client/resources/
	cp -r client/zarafa/core/themes $(DESTDIR)/client/
	rm -rf $(DESTDIR)/client/themes/*/js
	cp -r client/resources/scss $(DESTDIR)/client/resources/scss
	# TODO use separate targets

css:
	find $(DESTDIR)/client -name "*.css" -exec $(CSSCOMPILER) -o {}.min {} \; -exec mv {}.min {} \;
	find $(DESTDIR)/plugins -name "*.css" -exec $(CSSCOMPILER) -o {}.min {} \; -exec mv {}.min {} \;

js: $(JSDEPLOY)/fingerprint.js $(JSDEPLOY)/resize.js $(TEMPATEJSDEST) $(JSDEPLOY)/grommunio.js $(JSDEPLOY)/extjs-mod/extjs-mod.js $(JSDEPLOY)/extjs/ext-base-all.js $(DESTDIR)/client/third-party/ux-thirdparty.js $(DEPLOYPURIFYJS) $(JSDEPLOY)/filepreviewer/pdfjs/build/pdf.worker.js $(JSDEPLOY)/filepreviewer/pdfjs/build/pdf.js $(JSDEPLOY)/filepreviewer/pdfjs/web/viewer.js
	cp -r client/tinymce $(DESTDIR)/client/
	cp -r client/tinymce-languages $(DESTDIR)/client/
	cp -r client/tinymce-plugins $(DESTDIR)/client/
	cp -r client/extjs $(DESTDIR)/client/
	cp -r client/filepreviewer $(DESTDIR)/client/
	rm $(DESTDIR)/client/extjs/ext-base.js
	rm $(DESTDIR)/client/extjs/ext-all.js
	rm $(DESTDIR)/client/extjs/resources/css/reset-min.css
	rm $(DESTDIR)/client/extjs/resources/css/xtheme-blue.css
	# TODO use separate targets

$(DESTDIR)/%.php: %.php
	php -l $<
	mkdir -p $$(dirname $@)
	cp $< $@

$(ROBOTS): robots.txt
	cp $< $@

$(DESTDIR)/%.mo : %.po
	mkdir -p $$(dirname $@)
	$(MSGFMT) -v -o $@ $<

$(DESTDIR)/%: %
	mkdir -p $$(dirname $@)
	cp $< $@

$(DESTDIR)/version: version
	cp $< $@

$(DESTDIR)/client/extjs/ext-base-all.js: $(EXTJS)
	cat $+ > $@

$(JSDEPLOY)/fingerprint.js: client/fingerprint.js
	mkdir -p $(JSDEPLOY)
	cat client/fingerprint.js > $(JSDEPLOY)/fingerprint-debug.js
	$(JSCOMPILER) --js $< --js_output_file $@ $(JSOPTIONS)

$(JSDEPLOY)/grommunio.js: $(JSFILES)
	$(PHP) tools/loadorder.php grommunio $(@:.js=-debug.js)
	$(JSCOMPILER) --js $(@:.js=-debug.js) --js_output_file $@ \
		--source_map_location_mapping=$(JSDEPLOY)/\| \
		--output_wrapper="%output%//# sourceMappingURL=$(shell basename $@.map)" \
		--create_source_map $@.map \
		$(JSOPTIONS)

$(JSDEPLOY)/extjs-mod/extjs-mod.js: $(EXTJSMODFILES)
	mkdir -p $(JSDEPLOY)/extjs-mod
	$(PHP) tools/loadorder.php extjs $(@:.js=-debug.js)
	$(JSCOMPILER) --js $(@:.js=-debug.js) --js_output_file $@ \
		--source_map_location_mapping=$(JSDEPLOY)/extjs-mod/\| \
		--output_wrapper="%output%//# sourceMappingURL=$(shell basename $@.map)" \
		--create_source_map $@.map $(JSOPTIONS)

$(JSDEPLOY)/resize.js: client/resize.js
	mkdir -p $(JSDEPLOY)
	cat client/resize.js > $(JSDEPLOY)/resize-debug.js
	$(JSCOMPILER) --js $(@:.js=-debug.js) --js_output_file $@

$(JSDEPLOY)/filepreviewer/pdfjs/build/pdf.worker.js: client/filepreviewer/pdfjs/build/pdf.worker.js
	mkdir -p $(JSDEPLOY)/filepreviewer/pdfjs/build
	cat $^ > $(@:.js=-debug.js)
	$(JSCOMPILER) --js $(@:.js=-debug.js) --js_output_file $@ \
		--source_map_location_mapping=$(JSDEPLOY)/\| \
		--output_wrapper="%output%//# sourceMappingURL=$(shell basename $@.map)" \
		--create_source_map $@.map \
		$(JSOPTIONS) --jscomp_off=checkVars

$(JSDEPLOY)/filepreviewer/pdfjs/build/pdf.js: client/filepreviewer/pdfjs/build/pdf.js
	mkdir -p $(JSDEPLOY)/filepreviewer/pdfjs/build
	cat $^ > $(@:.js=-debug.js)
	$(JSCOMPILER) --js $(@:.js=-debug.js) --js_output_file $@ \
		--source_map_location_mapping=$(JSDEPLOY)/\| \
		--output_wrapper="%output%//# sourceMappingURL=$(shell basename $@.map)" \
		--create_source_map $@.map \
		$(JSOPTIONS) --jscomp_off=checkVars

$(JSDEPLOY)/filepreviewer/pdfjs/web/viewer.js: client/filepreviewer/pdfjs/web/viewer.js
	mkdir -p $(JSDEPLOY)/filepreviewer/pdfjs/web
	cat $^ > $(@:.js=-debug.js)
	$(JSCOMPILER) --js $(@:.js=-debug.js) --js_output_file $@ \
		--source_map_location_mapping=$(JSDEPLOY)/\| \
		--output_wrapper="%output%//# sourceMappingURL=$(shell basename $@.map)" \
		--create_source_map $@.map \
		$(JSOPTIONS) --jscomp_off=checkVars

$(DEPLOYPURIFYJS): $(PURIFYJS)
	mkdir -p $(DEPLOYPURIFY)
	# concatenate using cat
	cat $^ > $(@:.js=-debug.js)
	$(JSCOMPILER) --js $(@:.js=-debug.js) --js_output_file $@ \
		--source_map_location_mapping=$(JSDEPLOY)/\| \
		--output_wrapper="%output%//# sourceMappingURL=$(shell basename $@.map)" \
		--create_source_map $@.map \
		$(JSOPTIONS) --jscomp_off=checkVars

$(JSDEPLOY)/third-party/ux-thirdparty.js: $(THIRDPARTY)
	mkdir -p $(JSDEPLOY)/third-party
	# concatenate using cat
	cat $^ > $(@:.js=-debug.js)
	$(JSCOMPILER) --js $(@:.js=-debug.js) --js_output_file $@ \
		--source_map_location_mapping=$(JSDEPLOY)/\| \
		--output_wrapper="%output%//# sourceMappingURL=$(shell basename $@.map)" \
		--create_source_map $@.map \
		$(JSOPTIONS) --jscomp_off=checkVars

$(JSDEPLOY)/third-party/TinyMceTextArea-debug.js: client/third-party/tinymce/TinyMceTextArea.js
	mkdir -p $(JSDEPLOY)/third-party
	cp $< $@
	$(JSCOMPILER) --js $< --js_output_file $@

config:
	cp $(DESTDIR)/config.php.dist $(DESTDIR)/config.php

# Test

.PHONY: lint
lint: vendor
	$(NPM) run lint -- --cache

.PHONY: lintci
lintci: vendor
	$(NPM) run lint -- --quiet -f junit -o eslint.xml client/zarafa/ || true

.PHONY: jstest
jstest: build
	$(NPM) run jsunit

.PHONY: jstestci
jstestci: build
	$(NPM) run jsunit -- --reporters junit

.PHONY: jstestcov
jstestcov: build
	$(NPM) run jsunit -- --reporters coverage

open-coverage: jstestcov
	${BROWSER} test/js/coverage/report-html/index.html

.PHONY: phplint
phplint:
	$(PHPMD) server text .phpmd.xml

.PHONY: phplintcli
phplintci:
	$(PHPMD) server xml .phpmd.xml --ignore-violations-on-exit | python tools/violations_to_junit.py > phpmd.xml

# NPM

.PHONY: vendor
vendor: node_modules

node_modules:
	$(NPM) install

# Icons

.SECONDEXPANSION:
$(ICONSETSDEST): $$(subst deploy/,,$$@)/iconset.json $$@/$$(notdir $$@)-icons.css
	mkdir -p $@
	cp $< $@

$(ICONSETSCSSDEST): $$(subst deploy/,,$$@)
	mkdir -p $(@D)
	cp $< $@

.PHONY: iconsets
iconsets: $(ICONS) node_modules
	$(NPM) run iconsets

# This rule should not be enabled until our build server supports nodejs.
# Just create the iconsets locally by running `npm run iconsets` whenever
# something has changed.
#$(ICONSETSCSS): $$(@D)/src/png/*/*.png $(ICONEXTENSIONSFILE) node_modules
#	$(NPM) run iconsets:$(notdir $(@D))

# this rule creates the file client/resources/scss/base/_icons.scss
# since the scss files are not compiled during the build (yet),
# this rule can only be used locally for now.
.PHONY: app-icons
app-icons: $(APPICONSSCSS)

$(APPICONSSCSS): $(APPICONS) $(APPICONSEXTENSIONSFILE) node_modules
	$(NPM) run app-icons

# Tokenizr library

# This rule should not be enabled until our build server supports nodejs.
# Just build the tokenizr library locally by running `make tokenizr` whenever
# something has changed. (i.e. the tokenizr lib has been updated)
#client/third-party/tokenizr/tokenizr.js: tokenizr
#	$(NPM) run build:tokenizr

.PHONY: tokenizr
tokenizr: node_modules
	$(NPM) run build:tokenizr

# Plugins

.PHONY: plugins
plugins:
	make -C plugins

.PHONY: clean
clean:
	make -C plugins clean
	@rm -rf deploy
	@rm -rf node_modules

print-%  :
	@echo $* = $($*)
