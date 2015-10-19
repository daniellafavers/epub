#!/usr/bin/perl

BEGIN
{
	# Look for libraries in the same directory as 
	my ($root) = $0 =~ m/(.+)\/mkbook.pl/;
	if ( $root eq "" ) {
		push(@INC, ".");
	} else {
		push(@INC, $root);
	}
}

use WebTK::Document;

my $arg;
my ($format, $file);
my @vars;
for $arg ( @ARGV )
{
	if ( substr ($arg, 0, 1) eq "-" )
	{
		$format = substr ($arg, 1);
	}
	else
	{
		if ( $arg =~ m/=/ )
		{
			push @vars, $arg;
		}
		else
		{
			$file = $arg;
		}
	}
}

if ( ! -e $file )
{
	print "Usage: mkbook.pl <template-file> [-hash|-text|-html|-rtf|-epub]\n";
	exit 0;
}

$doc = WebTK::Document->new ();
$doc->load_file ($file);
print $doc->render ($format, @vars);
