#!/bin/bash
# per-folder excluded files CRUD
. "${APITEST_LIB:-$(dirname "$0")/../lib.sh}"
F="_apitest_folder_$$"
P="/settings/excluded-files/per-folder/$F"
expect_status "PUT list" 200 PUT "$P" '["a.md","b.md"]'
expect_status "GET one" 200 GET "$P"
expect_jq "list == [a,b]" '. == ["a.md","b.md"]'
expect_status "POST entry c.md" 201 POST "$P/entries" '{"filename":"c.md"}'
expect_status "DELETE entry a.md" 204 DELETE "$P/entries/a.md"
expect_status "GET one (after)" 200 GET "$P"
expect_jq "a.md gone, c.md present" 'any(.[]; .=="c.md") and (any(.[]; .=="a.md")|not)'
expect_status "DELETE folder" 204 DELETE "$P"
expect_status "GET one (deleted)" 404 GET "$P"
api_finish
