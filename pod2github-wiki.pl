#!/usr/bin/env perl
use 5.014;
use strict;
use warnings;
no warnings qw[ uninitialized numeric ];

=encoding UTF-8

=head1 NAME

C<< pod2github-wiki.pl >> - mirror the POD documentation of a repo of Perl scripts in the GitHub wiki.

=head1 SYNOPSIS

    perl pod2github-wiki.pl [OPTIONS]

=head1 DESCRIPTION

This script is not one of B<< the >> scripts, but is concerned with the
maintenance of the GitHub repo.

The script assumes that you have

=over

=item *

a local clone of a GitHub repository containing Perl scripts/modules
with POD documentation,

=item *

a 'README.pod',

=item *

a repository containing a collection of Perl scripts,

=item *

a git subtree in a directory 'wiki', representing the wiki repo on
GitHub associated with your repo,

=item *

a 'Home.md' in the wiki.

=item *

a directory C<< templates >> with two files

=over

=item *

'readme-preamble.pod', and

=item *

'wiki-preamble.md' containing the texts which shall go before the
generated text.

=back

=item *

I<< pandoc >> in your PATH
(L<< https://github.com/jgm/pandoc|https://github.com/jgm/pandoc >>)

=item *

the prerequisite CPAN modules installed (see the C<< -c >> option!)

=back

It does the following as needed:

=over

=item *

updates the README with an ASCIIbetical list of the scripts along with
the first paragraph of the DESCRIPTION section of each script's POD
documentation as a summary.

=item *

updates the repository wiki homepage with an HTML table with

=over

=item *

the name of each script/module/code file,

=item *

links to the wiki page and code for each script,

=item *

the latest code file modification date,

=back

=item *

copies the scripts' POD documentation to wiki pages,

=item *

C<< git add >>s the modified files, (You have to commit/push them
yourself -- that's a feature!)

=back

=head1 OPTIONS

The following options are recognised (defaults in parentheses):

=over

=item C<< -f >>, C<< --[no-]force >> (false)

Normally the README/wiki are only updated if the modification time of
any of I<< the >> scripts is later than that of the README or the
corresponding wiki page, but this option overrides that.

=item C<< -i >>, C<< --include-regex >> I<< REGEX >> (C<< \.p[lm]\z >>)

The files to get documentation from/for are obtained from the output of
C<< git ls-files >> as grepped agains this regular expression. If you
want to limit it to some specific directory/-ies include them in the
pattern:

    -i '\A(?:script|lib)/.*\.p[lm]\z'

=item C<< -e >>, C<< --exclude-regex >> I<< REGEX >> (C<< (?!) >>)

After the C<< git ls-files >> output is filtered against the
C<< --include-regex >> pattern the files which matched that pattern are
grepped against this pattern, excluding matching files, e.g.

    -e '\Alib/My/Module/Internals/'

=item C<< -r >>, C<< --repo-dir >> I<< PATH >> (C<< . >>)

Path to the local repo directory, unless it's the current directory.

=item C<< -w >>, C<< --wiki-dir >> I<< PATH >> (C<< REPO-DIR/wiki >>)

Path to the wiki subtree directory.

=item C<< -t >>, C<< --templates-dir >> I<< PATH >>
(C<< REPO-DIR/doc-templates >>)

Path to the directory containing the templates for the readme and the
wiki homepage. These I<< must >> be called C<< readme-preamble.pod >>
and C<< wiki-preamble.md >> and are nothing fancy: just literal markup
to which the generated content is appended.

=item C<< -c >>, C<< --cpan-prereqs >>

Show the script's CPAN prerequisites. This is done without loading those
prerequisites, so that you can do this:

    perl pod2github-wiki.pl -c | cpanm

=item C<< -h >>, C<< --help >>

Show the help text.

=item C<< -m >>, C<< --manual >>, C<< --man >>

Show the entire manual

=back

=head1 Q & A

=over

=item Why not convert the POD to Markdown?

Because neither GitHub's Markdown nor L<< Pod::Markdown|Pod::Markdown >>
supports definition lists like this one.

=item Why then Markdown in the wiki homepage?

Because POD doesn't support tables.

=item Does this script work under my OS?

It's not guaranteed to work I<< anywhere >>, but it is known to work
under Linux. Windows is a I<< big >> maybe.

=item Why C<< pandoc >>?

Why not? This script was originally used to maintain a repo with
pandoc-related scripts, and I'm as yet too lazy to remove the
dependency.

=item Can I use this script as a git pre-commit hook?

I do that. You might want to place its repo in a subtree in your repo,
make your own branch, edit the option defaults in the C<< BEGIN >> block
at the top of the script file, make it executable and make
C<< .git/hooks/pre-commit >> a symbolic link to it.

=item How do I make a git subtree?

L<< https://makingsoftware.wordpress.com/2013/02/16/using-git-subtrees-for-repository-separation/ >>

=back

=head1 COPYRIGHT

Copyright 2015- Benct Philip Jonsson.

L<< bpjonsson@gmail.com|mailto:bpjonsson@gmail.com >>
L<< https://github.com/bpj|https://github.com/bpj >>

=head1 LICENSE

This script is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See
L<< http://dev.perl.org/licenses/|http://dev.perl.org/licenses/ >>

=cut

# option targets,
my( $force,            #
    $include_re,       #
    $exclude_re,       #
    $repo_dir,         #
    $wiki_dir,         #
    $templates_dir,    #
    $show_prereqs,     #
    $show_help,        #
    $show_man,         #
);

BEGIN {
    # Run GOL before loading other modules so that --cpan-prereqs works as intended.
    use Getopt::Long qw[ GetOptionsFromArray :config no_ignore_case ];
    use Pod::Usage;

    $include_re = '\.p[lm]\z';
    $exclude_re = '(?!)';    # /(?!)/ -- the never-matching regex
    # $repo_dir;
    # $wiki_dir;
    # $templates_dir;

    GetOptionsFromArray(
        \@ARGV,
        'force|f!'                                     => \$force,
        'include_regex|include-regex|includeregex|i=s' => \$include_re,
        'exclude_regex|exclude-regex|excluderegex|e=s' => \$exclude_re,
        'repo_dir|repo_dir|repodir|r=s'                => \$repo_dir,
        'wiki_dir|wiki_dir|wikidir|w=s'                => \$wiki_dir,
        'templates_dir|templates_dir|templatesdir|r=s' => \$templates_dir,
        'cpan_prereqs|cpan-prereqs|cpanprereqs|c'      => \$show_prereqs,
        'help|h'                                       => \$show_help,
        'manual|man|m'                                 => \$show_man,
    ) or pod2usage( 2 );

    pod2usage(1) if $show_help;
    pod2usage(-exitval => 0, -verbose => 2) if $show_man;
    print <<'PREREQS' and exit(0) if $show_prereqs;
Git::Repository
IPC::Run
Path::Tiny~0.068
Pod::Abstract
Time::Moment
WWW::Shorten
utf8::all
PREREQS
}

# use autodie 2.12;

# no indirect;
# no autovivification;

use utf8::all;
use Path::Tiny 0.068 qw[ path tempfile tempdir cwd ];
use Git::Repository;
use Pod::Abstract;
use Pod::Abstract::BuildNode qw[ node ];
use Pod::Abstract::Filter::cut;
use Pod::Usage;
use WWW::Shorten 'GitHub';
use Time::Moment;
## Using run() instead of system():
    use IPC::Run qw( run timeout );

my $url = 'https://github.com/bpj/bpj-pandoc-scripts/blob/master/scripts/';

my $cut = Pod::Abstract::Filter::cut->new;

$repo_dir = cwd unless length $repo_dir;

$repo_dir = path($repo_dir);
 
$include_re = qr/$include_re/;       #
$exclude_re = qr/$exclude_re/;       #
$wiki_dir   ||= $repo_dir->child('wiki');         #
$templates_dir ||= $repo_dir->child('doc-templates');    #

{
    my %dirs = (
        repo_dir      => \$repo_dir,
        templates_dir => \$templates_dir,
        wiki_dir      => \$wiki_dir,
    );

    while ( my ( $name => $dir_ref ) = each %dirs ) {
        ${$dir_ref}->is_dir or die "Couldn't find '$name' directory\n";
    }
}

my $repo = Git::Repository->new( work_tree => $repo_dir->stringify );

my @files = sort grep { $_->is_file }
  map { path $_ } grep { /$include_re/ and !/$exclude_re/ } $repo->run( 'ls-files' );

scalar @files or exit;

my $readme          = $repo_dir->child('README.pod');
my $wiki_home       = $wiki_dir->child( 'Home.md' );
my $readme_mtime    = $readme->is_file ? $readme->stat->mtime : 0;
my $wiki_home_mtime = $wiki_home->is_file ? $wiki_home->stat->mtime : 0;

my(@summaries, );
my @wiki_index = ( "|\n|:---|:---|:---|:---|" );
my $update_readme = my $update_wiki = $force;

DOC:
for my $perl ( @files ) {
    my $perl_mtime = $perl->stat->mtime;
    my $perl_date = Time::Moment->from_epoch($perl_mtime)->at_utc->strftime('%F');
    my $name = $perl->basename;
    my $base = $perl->basename('.pl');
    my $short_url = makeashorterlink($url . "/$name");
    push @wiki_index, "| `$name` | \[\[doc|$base\]\] | [code]($short_url) | $perl_date |";
    my $pod = $wiki_dir->child( $base . '.pod' );
    my $fh = $perl->openr_utf8;
    my $pa = Pod::Abstract->load_filehandle($fh);
    $pa = $cut->filter( $pa );
    my($summary) = $pa->select(q{/head1[@heading eq 'DESCRIPTION']/:paragraph(0)});
    push @summaries, "=head3 $name", $summary ? $summary->pod : "Documentation for $name still to be written!";
    $update_readme ||= $perl_mtime > $readme_mtime;
    $update_wiki ||= $perl_mtime > $wiki_home_mtime;
    next DOC unless
           $force
        or !$pod->is_file
        or $perl_mtime > $pod->stat->mtime
        ;
    $repo->run( add => $perl );
    my($link) = node->from_pod( qq!This is the documentation for L<< $name|$short_url >>.\n\n! );
    if (my($h1) = $pa->select('/head1(0)') ) {
        $link->insert_before($h1);
    }
    elsif ( my($enc) = $pa->select('/encoding(0)') ) {
        $link->insert_after($enc);
    }
    elsif ( my($child) = $pa->children ) {
        $link->insert_before($child);
    }
    else {
        $pa->unshift($link);
    }
    $pod->spew_utf8( $pa->pod );
    $repo->run( add => $pod );
}

if ( $update_readme ) {
    my $preamble = $templates_dir->child('readme-preamble.pod');
    $preamble->is_file or die "Couldn't find file $preamble.\n"
    $preamble->copy( $readme );
    $readme->append_utf8(join "\n\n", @summaries);
    $repo->run( add => $readme );
}

if ( $update_wiki ) {
    my $preamble = $templates_dir->child('wiki-preamble.md');
    $preamble->is_file or die "Couldn't find file $preamble.\n"
    $preamble->copy( $wiki_home );
    my $in = join "\n", @wiki_index;
    my($out, $err);
    my @pandoc = qw[ pandoc -r markdown -w html ];
    run \@pandoc, \$in, \$out, \$err, timeout( 10 ) or die "pandoc: $err";
    $wiki_home->append_utf8($out);
    $repo->run( add => $wiki_home );
}

__END__
