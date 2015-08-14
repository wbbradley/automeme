deploy:
	ssh automeme -C 'cd $$GOPATH/src/github.com/wbbradley/automeme; git fetch; git checkout -B master origin/master; git show HEAD'
	ssh automeme -C 'cd $$GOPATH/src/github.com/wbbradley/automeme; pkill automeme && go build automeme && ./automeme -port 80 | tee automeme.log &'
