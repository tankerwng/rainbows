#!/bin/sh
. ./test-lib.sh
t_plan 5 "rack.hijack tests (Rack 1.5+ (Rack::VERSION >= [1,2]))"

t_begin "setup and start" && {
	rainbows_setup
	rainbows -D -c $unicorn_config hijack.ru
	rainbows_wait_start
}

t_begin "check request hijack" && {
	test "xrequest.hijacked" = x"$(curl -sSfv http://$listen/hijack_req)"
}

t_begin "check response hijack" && {
	test "xresponse.hijacked" = x"$(curl -sSfv http://$listen/hijack_res)"
}

t_begin "killing succeeds" && {
	kill $rainbows_pid
}

t_begin "check stderr" && {
	check_stderr
}

t_done
