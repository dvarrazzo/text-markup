package Text::Markup::Rest;

use 5.8.1;
use strict;

use File::Temp;

our $VERSION = '0.15';

# Use a Python script to customize the rst2html behaviour.
# The customized script allows to parse reST doucments including unknown roles
# and directives.
my $PYSCRIPT = <<END;
#!/usr/bin/env python
"""
Parse a reST file into HTML in a very forgiving way.

The script is meant to render specialized reST documents, such as Sphinx
files, preserving the content, while not emulating the original rendering.

The script is currently tested against docutils 0.7. Other version may break
it as it deals with the parser at a relatively low level.
"""

from docutils import nodes, utils
from docutils.core import publish_cmdline, default_description
from docutils.parsers.rst import Directive, directives, roles


# A generic directive to deal with any unknown directive we may find.

class any_directive(nodes.General, nodes.FixedTextElement): pass

class AnyDirective(Directive):
    """A directive returning its unaltered body."""
    optional_arguments = 100 # should suffice
    has_content = True

    def run(self):
        children = []
        children.append(nodes.strong(self.name, u"%s: " % self.name))
        # keep the arguments, drop the options
        for a in self.arguments:
            if a.startswith(':') and a.endswith(':'):
                break
            children.append(nodes.emphasis(a, u"%s " % a))
        content = u'\\n'.join(self.content)
        children.append(nodes.literal_block(content, content))
        node = any_directive(self.block_text, '', *children, dir_name=self.name)
        return [node]


# A generic role to deal with any unknown role we may find.

class any_role(nodes.Inline, nodes.TextElement): pass

class AnyRole:
    """A role to be rendered as a generic element with a specific class."""
    def __init__(self, role_name):
        self.role_name = role_name

    def __call__(self, role, rawtext, text, lineno, inliner,
                 options={}, content=[]):
        roles.set_classes(options)
        options['role_name'] = self.role_name
        node = any_role(rawtext, utils.unescape(text), **options)
        return [node], []


# Patch the parser so that when an unknown directive is found, a generic one
# is generated on the fly.

from docutils.parsers.rst.states import Body

def catchall_directive(self, match, **option_presets):
    type_name = match.group(1)
    directive_class, messages = directives.directive(
        type_name, self.memo.language, self.document)

    # in case it's missing, register a generic directive
    if not directive_class:
        directives.register_directive(type_name, AnyDirective)
        directive_class, messages = directives.directive(
            type_name, self.memo.language, self.document)
        assert directive_class, "can't find just defined directive"

    self.parent += messages
    return self.run_directive(
        directive_class, match, type_name, option_presets)

# Patch the constructs dispatch table
for i, (f, p) in enumerate(Body.explicit.constructs):
    if f is Body.directive.im_func is f:
        Body.explicit.constructs[i] = (catchall_directive, p)
        break
else:
    assert False, "can't find directive dispatch entry"

Body.directive = catchall_directive


# Patch the parser so that when an unknown interpreted text role is found,
# a generic one is generated on the fly.

from docutils.parsers.rst.states import Inliner

def catchall_interpreted(self, rawsource, text, role, lineno):
    role_fn, messages = roles.role(role, self.language, lineno,
                                   self.reporter)
    # in case it's missing, register a generic role
    if not role_fn:
        role_obj = AnyRole(role)
        roles.register_canonical_role(role, role_obj)
        role_fn, messages = roles.role(
            role, self.language, lineno, self.reporter)
        assert role_fn, "can't find just defined role"

    nodes, messages2 = role_fn(role, rawsource, text, lineno, self)
    return nodes, messages + messages2

Inliner.interpreted = catchall_interpreted


# Create a writer to deal with the generic element we may have created.

description = ('Generates (X)HTML documents from standalone reStructuredText '
               'sources.  Be extremely forgiving against unknown elements.  '
               + default_description)

from docutils.writers.html4css1 import Writer, HTMLTranslator

class MyTranslator(HTMLTranslator):
    def visit_any_directive(self, node):
        cls = node.get('dir_name')
        cls = cls and 'directive-%s' % cls or 'directive'
        self.body.append(self.starttag(node, 'div', CLASS=cls))

    def depart_any_directive(self, node):
        self.body.append('\\n</div>\\n')

    def visit_any_role(self, node):
        cls = node.get('role_name')
        cls = cls and 'role-%s' % cls or 'role'
        self.body.append(self.starttag(node, 'span', '', CLASS=cls))

    def depart_any_role(self, node):
        self.body.append('</span>')


writer = Writer()
writer.translator_class = MyTranslator

publish_cmdline(writer=writer, description=description)
END

sub parser {

    my ($file, $encoding, $opts) = @_;

    # Save the Python script into a temporary file.
    my $tmp = File::Temp->new(SUFFIX => '.py');
    print $tmp $PYSCRIPT;
    my $scrname = $tmp->filename;

    # Optional arguments to pass to rst2html
    my @OPTIONS = (
        '--no-raw', '--no-file-insertion', '--cloak-email-address',
        '--quiet', '--stylesheet=');

    open my $fh, "-|", "python $scrname @OPTIONS $file",
        or die "Cannot execute rst2html $file: $!\n";
    local $/;
    return <$fh>;
}

1;
__END__

=head1 Name

Text::Markup::Rest - reStructuredText parser for Text::Markup

=head1 Synopsis

  use Text::Markup;
  my $html = Text::Markup->new->parse(file => 'hello.rst');

=head1 Description

This is the L<reStructuredText|http://docutils.sourceforge.net/docs/user/rst/quickref.html>
parser for L<Text::Markup>.  It depends on the 'docutils'
Python package (which can be found as 'python-docutils' in many Linux
distribution, or installed using the command 'easy_install docutils').  It
recognizes files with the following extensions as reST:

=over

=item F<.rest>

=item F<.rst>

=back

=head1 Author

Daniele Varrazzo <daniele.varrazzo@gmail.com>

=head1 Copyright and License

Copyright (c) 2011 Daniele Varrazzo. Some Rights Reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
