qhull.js: qhull.coffee
	coffee -cm $<
	#chromium quickhull.html > /dev/null 2>&1

doc/qhull.html: qhull.coffee
	# use docco-dev (supports developer comments)
	docco -c docs/docco.custom.css -t docs/docco.jst $<

watch:
	while true; do \
		make $(WATCHMAKE); \
		inotifywait -qre close_write .; \
	done
