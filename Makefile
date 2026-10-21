.PHONY: build test package clean

build: ## Build the universal app into build/
	./scripts/build.sh

test: ## Check the camera protocol frames
	./scripts/test.sh

package: build ## Zip the app and write its checksum
	cd build && ditto -c -k --keepParent "OBS Bot Control.app" OBS-Bot-Control.zip
	cd build && shasum -a 256 OBS-Bot-Control.zip > OBS-Bot-Control.zip.sha256

clean:
	rm -rf build
