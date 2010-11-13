default :
	@echo no default rule

-include local/custom.mk

release :
	-rm -r build
	sake all release kits=s60_30 cert=self pys60=1
	sake all release kits=s60_30 cert=dev pys60=1
	sake all release kits=s60_50 cert=self pys60=2
	sake all release kits=s60_50 cert=dev pys60=2

upload-dry :
	sake upload dry=true

upload :
	sake upload

