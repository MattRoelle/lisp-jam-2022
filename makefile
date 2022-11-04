VERSION=0.1.0
LOVE_VERSION=11.4
NAME=change-me
ITCH_ACCOUNT=change-me-too
URL=https://gitlab.com/alexjgriffith/min-love2d-fennel
AUTHOR="Your Name"
DESCRIPTION="Minimal setup for trying out Phil Hagelberg's fennel/love game design process."
GITHUB_USERNAME := $(shell grep GITHUB_USERNAME credentials.private | cut -d= -f2)
GITHUB_PAT := $(shell grep GITHUB_PAT credentials.private | cut -d= -f2)
LIBS := $(wildcard lib/*)
LUA := $(wildcard *.lua)
SRC := $(wildcard *.fnl)

run: ; love .

count: ; cloc *.fnl

clean: ; rm -rf releases/*

LOVEFILE=releases/$(NAME)-$(VERSION).love

$(LOVEFILE): $(LUA) $(SRC) $(LIBS)
	mkdir -p releases/
	find $^ -type f | LC_ALL=C sort | env TZ=UTC zip -r -q -9 -X $@ -@

love: $(LOVEFILE)

# platform-specific distributables

REL=$(PWD)/buildtools/love-release.sh # https://p.hagelb.org/love-release.sh
FLAGS=-a "$(AUTHOR)" --description $(DESCRIPTION) \
	--love $(LOVE_VERSION) --url $(URL) --version $(VERSION) --lovefile $(LOVEFILE)

releases/$(NAME)-$(VERSION)-x86_64.AppImage: $(LOVEFILE)
	cd buildtools/appimage && \
	./build.sh $(LOVE_VERSION) $(PWD)/$(LOVEFILE) $(GITHUB_USERNAME) $(GITHUB_PAT)
	mv buildtools/appimage/game-x86_64.AppImage $@

releases/$(NAME)-$(VERSION)-macos.zip: $(LOVEFILE)
	$(REL) $(FLAGS) -M
	mv releases/$(NAME)-macos.zip $@

releases/$(NAME)-$(VERSION)-win.zip: $(LOVEFILE)
	$(REL) $(FLAGS) -W32
	mv releases/$(NAME)-win32.zip $@

releases/$(NAME)-$(VERSION)-web.zip: $(LOVEFILE)
	buildtools/love-js/love-js.sh releases/$(NAME)-$(VERSION).love $(NAME) -v=$(VERSION) -a=$(AUTHOR) -o=releases

linux: releases/$(NAME)-$(VERSION)-x86_64.AppImage
mac: releases/$(NAME)-$(VERSION)-macos.zip
windows: releases/$(NAME)-$(VERSION)-win.zip
web: releases/$(NAME)-$(VERSION)-web.zip


runweb: $(LOVEFILE)
	buildtools/love-js/love-js.sh $(LOVEFILE) $(NAME) -v=$(VERSION) -a=$(AUTHOR) -o=releases -r -n
# If you release on itch.io, you should install butler:
# https://itch.io/docs/butler/installing.html

uploadlinux: releases/$(NAME)-$(VERSION)-x86_64.AppImage
	butler push $^ $(ITCH_ACCOUNT)/$(NAME):linux --userversion $(VERSION)
uploadmac: releases/$(NAME)-$(VERSION)-macos.zip
	butler push $^ $(ITCH_ACCOUNT)/$(NAME):mac --userversion $(VERSION)
uploadwindows: releases/$(NAME)-$(VERSION)-win.zip
	butler push $^ $(ITCH_ACCOUNT)/$(NAME):windows --userversion $(VERSION)
uploadweb: releases/$(NAME)-$(VERSION)-web.zip
	butler push $^ $(ITCH_ACCOUNT)/$(NAME):web --userversion $(VERSION)

upload: uploadlinux uploadmac uploadwindows

release: linux mac windows upload cleansrc
