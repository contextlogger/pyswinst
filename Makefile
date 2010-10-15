default :
	@echo no default rule

-include local/custom.mk

release :
	-rm -r build
	sake all release kits=s60_30 cert=self
	sake all release kits=s60_30 cert=dev

upload-dry :
	sake upload dry=true

upload :
	sake upload

