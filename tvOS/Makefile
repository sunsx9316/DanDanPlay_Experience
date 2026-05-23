.PHONY: gen open clean build

gen:
	xcodegen generate
	python3 scripts/fix_pbxproj.py

open:
	open AniXPlayer.xcworkspace

clean:
	rm -rf ~/Library/Developer/Xcode/DerivedData/AniXPlayer-*

build:
	xcodebuild -workspace AniXPlayer.xcworkspace -scheme AniXPlayer -configuration Debug -destination 'platform=tvOS Simulator,name=Apple TV' build
