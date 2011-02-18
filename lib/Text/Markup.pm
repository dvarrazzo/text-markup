package Text::Markup;

use 5.8.1;
use strict;
use Text::Markup::None;
use Carp;

our $VERSION = '0.10';

my %REGEX_FOR;
my %PARSER_FOR;

sub register {
    my ($class, $name, $regex) = @_;
    $class = caller;
    $REGEX_FOR{$name}  = $regex;
    $PARSER_FOR{$name} = $class->can('parser')
        or croak "No parser() function defind in $class";
}

sub formats {
    sort keys %REGEX_FOR;
}

sub new {
    my $class = shift;
    bless { @_ } => $class;
}

sub parse {
    my $self = shift;
    my %p = @_;
    my $file = $p{from} or croak "No from parameter passed to parse()";

    my $parser = $self->get_parser(\%p);
    my $fh = $self->output_handle_for($p{to});
    print $fh $parser->($file, $p{options});
    return $self;
}

sub default_format {
    my $self = shift;
    return $self->{default_format} unless @_;
    $self->{default_format} = shift;
}

sub get_parser {
    my ($self, $p) = @_;
    my $format = $p->{format}
             || $self->guess_format($p->{from})
             || $self->default_format || 'none';
    return $PARSER_FOR{$format} || Text::Markup::None->can('parser');
}

sub guess_format {
    my ($self, $file) = @_;
    for my $format (keys %REGEX_FOR) {
        return $format if $file =~ qr{[.]$REGEX_FOR{$format}$};
    }
    return;
}

sub output_handle_for {
    my ($self, $to) = @_;
    if (!defined $to) {
        binmode *STDOUT, ':utf8';
        return *STDOUT;
    }
    open my $fh, '>:utf8', $to or die "Cannot open $to: $!\n";
    return $fh;
}

1;
__END__

=head1 Name

Text::Markup - Parse text markup into HTML

=head1 Synopsis

  my $parser = Text::Markup->new(
      default_format => 'markdown',
      disallow => [qw(script)],
      strip    => [qw(font)],
  );

  $parser->parse(
      file   => $markup_file,
      format => 'markdown',
  );

=head1 Description



=head1 Interface

=head2 Constructor

=head3 C<new>

  my $parser = Text::Markup->new(
      default_format => 'markdown',
      disallow => [qw(script)],
      strip    => [qw(font)],
  );

Supported parameters:

=over

=item C<default_format>

The default format to use if one isn't passed to C<parse()> and one can't be
guessed.

=back

=head2 Instance Methods

=head3 C<parse>

    $parser->parse(
        file => $file_to_parse,
        to   => $file_to_write_to,
    );

Parse a file and write the results to another file. Parameters:

=over

=item C<from>

The file from which to read the markup to be parsed.

=item C<to>

The file to which to write the output. If none is specified, the output will
be written to C<STDOUT>.

=item C<format>

The markup format in the file, which determines the parser used to parse it.
If not specified, Text::Markup will try to guess the format from the file's
suffix. If it can't guess, it falls back on C<default_format>. And if that
attribute is not set, it uses the C<none> parser, which simply encodes the
entire file and wraps it in a C<< <pre> >> element.

=item C<options>

An array reference of options for the parser. See the documentation of the
various parser modules for details.

=back

=head1 See Also

=over

=item *

The L<markup|https://github.com/github/markup> Ruby provides similar
functionality, and is used to parse F<README.your_favorite_markup> on GitHub.

=back

=head1 Support

This module is stored in an open L<GitHub
repository|http://github.com/theory/text-markup/>. Feel free to fork and
contribute!

Please file bug reports via L<GitHub
Issues|http://github.com/theory/text-markup/issues/> or by sending mail to
L<bug-Text-Markup@rt.cpan.org|mailto:bug-Text-Markup@rt.cpan.org>.

=head1 Author

David E. Wheeler <david@justatheory.com>

=head1 Copyright and License

Copyright (c) 2011 David E. Wheeler. Some Rights Reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut