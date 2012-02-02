#!/usr/bin/env perl

use strict;
use Test::More;
eval "use Test::Spelling";
plan skip_all => "Test::Spelling required for testing POD spelling" if $@;

add_stopwords(<DATA>);
all_pod_files_spelling_ok();

__DATA__
FooBar
Trac
lowercased
UTF
BOM
wiki
MediaWiki
Markdown
MultiMarkdown
UI
GitHub
Varrazzo
reST
reStructuredText
docutils
