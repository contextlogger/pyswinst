KIT := s60_30
CERT := dev
DEVICE := default

default :
	@echo no default rule

symbian : symbian30 symbian50

symbian30 :
	sake cert=dev kits=s60_30

symbian50 :
	sake cert=dev kits=s60_50 pys60=2

bin :
	sake cert=$(CERT) kits=$(KIT)

bin-all :
	-rm -r build
	sake all release kits=s60_30 cert=self pys60=1
	sake all release kits=s60_30 cert=dev pys60=1
	sake all release kits=s60_50 cert=self pys60=2
	sake all release kits=s60_50 cert=dev pys60=2

apidoc :
	sake --trace cxxdoc

.PHONY : web

web :
	cp -a ../tools/web/hiit.css web/
	../tools/bin/txt2tags --target xhtml --infile web/index.txt2tags.txt --outfile web/index.html --encoding utf-8 --verbose -C web/config.t2t

HTDOCS := ../contextlogger.github.com
PAGEPATH := pyswinst
PAGEHOME := $(HTDOCS)/$(PAGEPATH)
DLPATH := $(PAGEPATH)/download
DLHOME := $(HTDOCS)/$(DLPATH)
MKINDEX := ../tools/bin/make-index-page.rb

release :
	-mkdir -p $(DLHOME)
	cp -a download/* $(DLHOME)/
	$(MKINDEX) $(DLHOME)
	cp -a web/*.css $(PAGEHOME)/
	cp -a web/*.html $(PAGEHOME)/
	chmod -R a+rX $(PAGEHOME)

upload :
	cd $(HTDOCS) && git add $(PAGEPATH) && git commit -a -m updates && git push

-include local/custom.mk
