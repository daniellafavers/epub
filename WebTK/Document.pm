# ============================================================================
package WebTK::Document;

# ============================================================================
# DIRECTIVES
# ============================================================================
use WebTK::Document::XHtml;
use WebTK::Document::Text;
use WebTK::Document::Rtf;
use WebTK::Document::Kindle;
use WebTK::Document::EPub;
use strict;

# ============================================================================
# POD HEADER
# ============================================================================

=pod
	
=head1 WebTK::Document
	
Document formatting base class.
	
=head1 SYNOPSIS
 
 use WebTK::Document;
 my $document = WebTK::Document->new ();
 $document->load ($input);
 $document->render ();

=head1 AUTHOR
	
Daniel LaFavers
	
=head1 DESCRIPTION
	
The Document base class provides functions for loading an input file for output
processing by a sub class document object. For example, the WebTK::Document::Rtf
module provides a function for rendering a document as an RTF file.
	
An input text file has specific rules about it structure, but instead of using
markup, the text file is designed to be able to stand on its own as a plain text
file.
	
Each type of paragraph is described in the INPUT FORMAT section below. Each description
explains both the input format of that paragraph type and how it is encoded
by the load function for output translation.

=head1 SEE ALSO
	
The following document types are available. Normally you will use one of the
following modules to load and render documents.
	
=over 4

=item WebTK::Document::XHtml
	
Convert text files to XHTML with an embedded style sheet.

=item WebTK::Document::Text
	
Convert text files to plain text.

=item WebTK::Document::Rtf

Convert text files to RTF.
	
=back
	
=cut

# ============================================================================
# CLASS METHODS
# ============================================================================

# ----------------------------------------------------------------------------
=pod
	
=head1 CONSTRUCTOR
	
=over 4
	
=item $document = WebTK::Document->new ();

Creates a new empty Document object. The constructor takes
no arguments.

You can create content for a document by loading it from a text file.
	
=back
	
=cut
sub new
{
	my $class = shift;
	my $file = shift;
	
	# Create the object
	my $self = { };
	$self->{varfcn} = undef;
	bless $self, $class;

	my (%vars, @paras, %numkeys);
	$self->{variables} = \%vars;
	$self->{paragraphs} = \@paras;
	$self->{numkeys} = \%numkeys;
	
	return $self;
}

# ============================================================================
# OBJECT METHODS
# ============================================================================

=pod

=head1 OBJECT METHODS

=cut

# ----------------------------------------------------------------------------
=pod
	
=over 4

=item $document->set_var_function
	
This var function will be passed to the Draw objects used by the
Document class

=back
	
=cut
sub set_var_function
{
    my $self = shift;
    $self->{varfcn} = shift;
}
	
# ----------------------------------------------------------------------------
# Load a file and return a format object
=pod
	
=over 4
	
=item $document->load_file ($input_file);

The load_file function reads the text file and populates document content.
The text file must conform to the paragraph type specifications explained
in the INPUT FORMAT section below to be properly interpreted.

=back
	
=cut
sub load_file
{
	my $self = shift;
	my $file = shift;
	my $lines = $self->_load_file ($file);
	$self->_load_array ($lines, $self->{paragraphs});
	$self->{variables}->{load_file} = $file;
}

# ----------------------------------------------------------------------------
# Load from a buffer and return a format object
=pod
	
=over 4
	
=item $document->load_text ($input_file);

The load_text function reads the text buffer and populates document content.
The text buffer must contain new line characters to separate lines, and must
conform to the paragraph type specifications explained in the INPUT FORMAT
section below to be properly interpreted.

=back
	
=cut
sub load_text
{
	my $self = shift;
	my $text = shift;
	
	my (@lines);
	
	@lines = split /\n/, $text;
	$self->_load_array (\@lines, $self->{paragraphs});
	$self->{variables}->{load_file} = "nofile";
}

# ----------------------------------------------------------------------------
# Load from an array of lines
=pod
	
=over 4
	
=item $document->load_array (\@array_of_lines);
	
This function reads document content from an array of lines,
rather than from a file. The lines must conform to the paragraph
type specifications explained in the INPUT FORMAT section below to
be properly interpreted.
	
Make sure you have empty lines to separate paragraphs.

=back
	
=cut
sub load_array
{
	my $self = shift;
	my $lines = shift;
	return $self->_load_array ($lines, $self->{paragraphs});
}

# ----------------------------------------------------------------------------
=pod 
	
=over 4
	
=item $document->render ();

Renders the document. The base class function simply lists the paragraph
types and all of the data fields.
	
Sub class document types will render the content for the specific format.

=back
	
=cut
	
# ----------------------------------------------------------------------------
sub render
{
	my $self = shift;
	my $format = shift;
	my $vars = $self->{variables};
	my $writer;
	
	# Override variables
	my ($var, $n, $v);
	for $var ( @_ )
	{
		# Variables must match the form "n=v"
		($n, $v) = $var =~ m/(\w+)\s*=\s*(.+)/;
		if ( $n ne "" && $v ne "" )
		{
			$vars->{$n} = $v;
		}
	}
	
	if    ( $format eq "hash"   ) { $writer = WebTK::Document::Hash->new ($self); }
	elsif ( $format eq "text"   ) { $writer = WebTK::Document::Text->new ($self); }
	elsif ( $format eq "html"   ) { $writer = WebTK::Document::XHtml->new ($self); }
	elsif ( $format eq "kindle" ) { $writer = WebTK::Document::Kindle->new ($self); }
	elsif ( $format eq "rtf"    ) { $writer = WebTK::Document::Rtf->new ($self); }
	elsif ( $format eq "epub"   ) { $writer = WebTK::Document::EPub->new ($self); }
	else                          { $writer = WebTK::Document::Text->new ($self); }

	if ( $self->{varfcn} ) { $writer->set_var_function ($self->{varfcn}); }
	
	return $writer->render;
}

# ----------------------------------------------------------------------------
sub renderHash
{
	my $self = shift;
	my $writer = WebTK::Document::Hash->new ($self);
	if ( $self->{varfcn} ) { $writer->set_var_function ($self->{varfcn}); }
	return $writer->render ();
}

# ----------------------------------------------------------------------------
=pod
	
=over 4

=item $document->formatText (\&sub)

Passes all text to the given function. The function must return
as string to replace the text.

=back
	
=cut
sub formatText
{
	my $self = shift;
	my $subref = shift;
	my @params = @_;
	
	my $para;
	for $para ( @{$self->{paragraphs}} )
	{
		if ( $para->{type} =~ m/^heading/ )
		{
			$para->{data} = &$subref ($para->{data}, @params);
		}
		elsif ( $para->{type} =~ m/list/ )
		{
			my $item;
			for $item ( @{$para->{items}} )
			{
				$item->{data} = &$subref ($item->{data}, @params);
			}
		}
		elsif ( $para->{type} eq "table" )
		{
			my ($row, $cell);
			for $row ( @{$para->{rows}} )
			{
				for $cell ( @{$row->{cells}} )
				{
					$cell->{data} = &$subref ($cell->{data}, @params);
				}
			}
		}
		
#       Leave source code unaltered
# 		elsif ( $para->{type} eq "source code" )
# 		{
# 			my ($line, @newlines);
# 			for $line ( @{$para->{lines}} )
# 			{
# 				push @newlines, &$subref ($line, @params);
# 			}
# 			$para->{lines} = \@newlines;
# 		}
		
		elsif ( $para->{type} eq "text" )
		{
			$para->{data} = &$subref ($para->{data}, @params);
		}
	}
}

# ============================================================================
# INTERNAL METHODS
# ============================================================================

sub _load_file
{
	my $self = shift;
	my $file = shift;
	
	my (@lines);
	
	# Open the file
	if ( ! open (INPUT, "<$file") )
	{
		die "Unable to open $file: $!";
	}
	
	# Load the entire file into a list of lines
	@lines = <INPUT>;
	chomp @lines;
	
	# Done with the file
	close INPUT;

	return \@lines;
}

sub _load_array
{
	my $self = shift;
	my $lines = shift;
	my $paralist = shift;
	
	my ($paragraphs, %variables);	
	
	# Separate the lines into a list of paragraphs
	$paragraphs = $self->_create_paragraphs ($lines);

	# Identify paragrapy types
	$self->_identify_paragraph_types ($paragraphs);

	# Trim spaces and blank lines
	$self->_trim ($paragraphs);

	# Process tables into cells
	$self->_parse_tables ($paragraphs);

	# Collect variables
	$self->_get_variables ($paragraphs, $self->{variables});
	
	# Move all $para->{lines} to $para->{data}
	$self->_combine_lines ($paragraphs);
	
	# Identify lists - Create list objects - series of list type paragraphs
	$self->_make_lists ($paragraphs);

	# Add paragraphs to the paragagraph list for this document
	push @$paralist, @$paragraphs;
}

# ----------------------------------------------------------------------------
# Put paragraph into the list. Or, if it is an include statement, load
# the specified file and add its paragraphs
sub _add_para_to_list
{
	my $self = shift;
	my $paragraphs = shift;
	my $para = shift;
	
	my $linecount = scalar @{$para->{lines}};
	if ( $linecount == 1 )
	{
		my $line = $para->{lines}[0];
		if ( $line =~ m/^\#include\s+\S+/ )
		{
			my $file;
			($file) = $line =~ m/^\#include\s+(\S+)/;
			
			if ( -e $file )
			{
				my ($lines, $p);
				$lines = $self->_load_file ($file, $paragraphs);
				$p = $self->_create_paragraphs ($lines);
				push @$paragraphs, @$p;
				return;
			}
			else
			{
				my %tmp_para;
				$tmp_para{type} = "unknown";
				$tmp_para{lines} = [ "-------#ERROR: File $file not found." ];
				push @$paragraphs, \%tmp_para;
			}
		}
	}
	push @$paragraphs, $para;
}

# ----------------------------------------------------------------------------
# Each paragraph is a hash containing a type name and a list of lines. Other
# hash fields may be added once the paragraph type is identified.
sub _create_paragraphs
{
	my $self = shift;
	my $lines = shift;
	my $default_paragraph_type = "unknown";
	
	my ($line, @paragraphs, $para_line_count, $is_blank, $para, $look_for_end);
	
	$para_line_count = 0;
	$look_for_end = 0;
  LINE: 
	for $line ( @$lines )
	{
		# Look for a command to set the default paragraph type
		if ( $line =~ m/^\&.+/ )
		{
			($default_paragraph_type) =
				$line =~ m/^\&(.+)/;
			next LINE;
		}
		
		# Blank line or not?
		$is_blank = ( $line =~ m/^\s*$/ ) ? 1 : 0;
		
		if ( $look_for_end )
		{
			if ( $line =~ m/^\@end/ )
			{
				$look_for_end = 0;
				$self->_add_para_to_list (\@paragraphs, $para);
				$para_line_count = 0;
				next LINE;
			}
		}
		
		
		if ( $is_blank && $look_for_end == 0 )
		{
			# Looking for the start of the next paragraph
			next LINE if ( $para_line_count == 0 );
			
			# End of paragraph
			$self->_add_para_to_list (\@paragraphs, $para);
			$para_line_count = 0;
		}
		
		else
		{
			if ( $para_line_count == 0 )
			{
				# Make a new paragraph
				my %para;
				$para = \%para;
				$para->{type} = $default_paragraph_type;
				$para_line_count = 1;

				# If this is a paragraph marker consume
				# all lines up to the end marker
				if ( $line =~ m/^\@.+/ )
				{
					my $type;
					($type) = $line =~ m/^\s*\@(.+)/;
					$para->{type} = $type;
					$look_for_end = 1;
				}
				else
				{
					# Not a special paragraph type marker - add it to the paragraph
					$para->{lines} = [ $line ];
				}
			}
			else
			{
				# Copy this line to the paragraph line list
				$para_line_count ++;
				push @{$para->{lines}}, $line;
			}
		}
	}

	if ( $para_line_count )
	{
		$self->_add_para_to_list (\@paragraphs, $para);
	}
	
	return \@paragraphs;
}

# ----------------------------------------------------------------------------
sub _identify_paragraph_types
{
	my $self = shift;
	my $paragraphs = shift;
	
	my ($para, $num_lines, $first_line, $last_line, $mark, $l);
	my ($istable, $captionline, $table_lines, $setvar_lines, $captop);
	
  PARA:
	for $para ( @$paragraphs )
	{
		# Rules often use these
		$num_lines = scalar @{$para->{lines}};
		$first_line = $para->{lines}[0];
		$last_line = $para->{lines}[$num_lines-1];

		# Skip paragraphs if they are already typed
		if ( $para->{type} ne "unknown" )
		{
			next PARA;
		}
		
		# Look for separator line
		if ( $num_lines == 1 && $first_line =~ m/^\s*-+\s*$/ )
		{
			$para->{type} = "separator";
			$para->{data} = "";
			next PARA;
		}
		
		# Look for page break
		if ( $num_lines == 1 && $first_line =~ m/^\s*\^+\s*$/ )
		{
			$para->{type} = "page break";
			$para->{data} = "";
			next PARA;
		}
		
		# Look for block paragraphs - first line is >>>>
		if ( $first_line =~ m/^\s*>+\s*$/ )
		{
			$para->{type} = "block";
			shift @{$para->{lines}};
			next PARA;
		}
		
		# Look for source code
		if ( $first_line =~ m/^\s*-+\s*$/ &&
			 $last_line =~ m/^\s*-+\s*$/ )
		{
			$para->{type} = "source code";
			shift @{$para->{lines}};
			pop @{$para->{lines}};
			next PARA;
		}
		
		# Look for heading paragraph types
		if ( $num_lines >= 2 )
		{
			# Heading level 1 - underlined by ===
			if ( $last_line =~ m/^\s*=+\s*$/ )
			{
				$para->{type} = "heading";
				$para->{level} = 1;
				splice @{$para->{lines}}, $num_lines-1;
				next PARA;
			}
			
			# Heading level 2 - underlined by ---
			if ( $last_line =~ m/^\s*-+\s*$/ )
			{
				$para->{type} = "heading";
				$para->{level} = 2;
				splice @{$para->{lines}}, $num_lines-1;
				next PARA;
			}

			# Heading level 3 - underlined by ...
			if ( $last_line =~ m/^\s*\.+\s*$/ )
			{
				$para->{type} = "heading";
				$para->{level} = 3;
				splice @{$para->{lines}}, $num_lines-1;
				next PARA;
			}
		}
		
		# Heading at any level - such as : 4> Heading text
		if ( ($mark) = $first_line =~ m/^\s*(\d+)>/ )
		{
			my ($replace, $level);
			($replace) = $first_line =~ m/^\s*\d+>\s*([^>]+)/;
			$level = $mark;
			splice @{$para->{lines}}, 0, 1, $replace;
			$para->{type} = "heading";
			$para->{level} = $level;
			next PARA;
		}

		# Part break
		if ( $num_lines == 1 && $first_line =~ m/^--\s+.+\s+--\s*$/ )
		{
			$para->{type} = "part";
			my $part;
			($part) = $first_line =~ m/^--\s+(.+)\s+--\s*$/;
			splice @{$para->{lines}}, 0, 1, $part;
			next PARA;
		}
		
		# Nav point
		if ( $num_lines == 1 && $first_line =~ m/^<.+>/ )
		{
			$para->{type} = "navpoint";
			my $navtxt;
			($navtxt) = $first_line =~ m/<(.+)>/;
			splice @{$para->{lines}}, 0, 1, $navtxt;
			next PARA;
		}
		
		# Look for bullet list paragraphs
		if ( $first_line =~ m/^\s*\*\)/ )
		{
			my ($replace);
			($replace) = $first_line =~ /^\s*\*\)(.+)/;
			splice @{$para->{lines}}, 0, 1, $replace;
			$para->{type} = "bullet item";
			next PARA;			
		}

		# Look for number list paragraphs
		if ( $first_line =~ m/^\s*(\#\w*|\d+)\)/ )
		{
			my ($num, $replace);
			($num,$replace) = $first_line =~ /^\s*(\#\w*|\d+)\)(.+)/;
			splice @{$para->{lines}}, 0, 1, $replace;
			$para->{type} = "number item";
			if ( substr ($num, 0,1) eq "#" )
			{
				my $numkey;
				$numkey = substr ($num, 1);
				if ( $numkey eq "" ) { $numkey = "-"; }
				$para->{number} = ++$self->{numkeys}->{$numkey};
			}
			else
			{
				$para->{number} = $num;
			}
			next PARA;
		}
		
		# Look for name list paragraphs
		if ( $first_line =~ m/^\s*\w(\w|\s)*\)/ )
		{
			my ($name, $replace);
			($name,$replace) = $first_line =~ /^\s*(\w(?:\w|\s)*)\)(.*)/;
			splice @{$para->{lines}}, 0, 1, $replace;
			$para->{type} = "name item";
			$para->{name} = $name;
			next PARA;
		}

		# Look for special types
		if ( $num_lines == 1 && $first_line =~ m/\$\S+\$/ )
		{
			my ($table_type);
			($table_type) = $first_line =~ m/\$(\S+)\$/;
			$para->{type} = "special thing";
			$para->{data} = $table_type;
			next PARA;
		}
		
		# Look for tables - For a table, all lines begine with + or |
		# and my have an optional single caption line as the first or last line
		$istable = 1;
		$captionline = -1;
		$captop = 0;
		$table_lines = 0;
		$l = 0;
		while ( $istable && $l < $num_lines )
		{
			if ( $para->{lines}[$l] !~ m/^\s*(\+|\|)/ )
			{
				if ( ($l == 0 || $l == $num_lines-1) && $captionline == -1 )
				{
					# Caption is not set - and this is the first or last line
					$captionline = $l;
					if ( $l == 0 ) { $captop = 1; }
				}
				else
				{
					# Caption line not first or last - or caption already set
					$istable = 0;
				}
			}
			else
			{
				# This is a table line
				$table_lines++;
			}
			$l++;
		}

		if ( $istable && $table_lines != 0 )
		{
			$para->{type} = "table";
			if ( $captionline != -1 )
			{
				$para->{caption} = $para->{lines}[$captionline];
				if ( $captop ) { $para->{caption_position} = "top"; }
				else { $para->{caption_position} = "bottom"; }
				splice @{$para->{lines}}, $captionline, 1;
				$para->{caption} =~ s/^\s+//;
				$para->{caption} =~ s/\s+$//;
			}
			next PARA;
		}

		# Look for variable setting paragraph - all lines must be variable settings.
		# Variable setting lines consist of a variable, a colon, and
		# an optional data part
		$setvar_lines=0;
		for ( $l = 0; $l < $num_lines; $l++ )
		{
			if ( $para->{lines}[$l] =~ m/^\s*\w+\s*=>/ ) 
			{ 
				$setvar_lines++; 
			}
		}
		if ( $setvar_lines == $num_lines )
		{
			$para->{type} = "variables";
			next PARA;
		}
		
		# Any paragraph that is not otherwise identified is text
		$para->{type} = "text";
	}
}

# ----------------------------------------------------------------------------
sub _trim
{
	my $self = shift;
	my $paragraphs = shift;
	
	my ($para, $l);
	
	# Remove spaces
	for $para ( @$paragraphs )
	{
		# Skip source code paragraphs
		if ( $para->{type} eq "source code" ) { next; }
		
		# Remove blank lines
		$l = 0;
		while ( $l < scalar @{$para->{lines}} )
		{
			if ( $para->{lines}->[$l] =~ m/^\s*$/ )
			{
				splice @{$para->{lines}}, $l, 1;
			}
			else
			{
				$l++;
			}
		}
		
		# Trim remaining lines
		for ( $l=0; $l < scalar @{$para->{lines}}; $l++ )
		{
			$para->{lines}[$l] =~ s/^\s+//;
			$para->{lines}[$l] =~ s/\s+$//;
		}
	}
}

# ----------------------------------------------------------------------------
sub _get_variables
{
	my $self = shift;
	my $paragraphs = shift;
	my $vars = shift;
	
	my ($p, $para, $line, $name, $value);
	
	$p = 0;
	while ( $p < scalar @$paragraphs )
	{
		$para = $paragraphs->[$p];
		if ( $para->{type} eq "variables" )
		{
			for $line ( @{$para->{lines}} )
			{
				($name, $value) = $line =~ m/\s*([^=]+)=>\s*(\S.*)/;
				$name =~ s/\s*$//;
				$value =~ s/\s*$//;
				$vars->{lc $name} = $value;
			}
			
			# Remove the paragraph object
			splice @$paragraphs, $p, 1;
		}
		else
		{
			$p++;
		}

	}
}

# ----------------------------------------------------------------------------
sub _make_lists
{
	my $self = shift;
	my $paragraphs = shift;
	
	my ($p, $inlist, $list_type, $type, $cur_list);
	
	# Start by just printing out the types
	$inlist = 0;
	$list_type = "";
	$p = 0;
	while ( $p < scalar @$paragraphs )
	{
		# Get the paragraph type
		$type = @$paragraphs[$p]->{type};
		
		if ( $inlist )
		{
			# Do we continue the list
			if ( $type eq $list_type )
			{
				push @{$cur_list->{items}}, $paragraphs->[$p];
				splice @$paragraphs, $p, 1;
			}
			else
			{
				$inlist = 0;
				$list_type = "";
			}
		}
		else
		{
			# Look for the beginning of a list
			if ( $type =~ m/item$/ )
			{
				$inlist = 1;
				$list_type = $type;
				
				# Make a new list
				my %list;
				$cur_list = \%list;
				
				# Set its type based on the item type
				$list{type} = $type;
				$list{type} =~ s/item/list/;
				
				# Add the current paragraph to the items list
				$list{items} = [ ];
				push @{$list{items}}, @$paragraphs[$p];
				
				# Replace the first item with the list
				splice @$paragraphs, $p, 1, $cur_list;
			}
			
			# Next paragraph
			$p++;
		}
	}
}

# ----------------------------------------------------------------------------
sub _parse_tables
{
	my $self = shift;
	my $paragraphs = shift;
	
	my ($p);
	
	for $p ( @$paragraphs )
	{
		next if ( $p->{type} ne "table");
		$self->_parse_table ($p);
	}
}

sub _parse_table
{
	my $self = shift;
	my $table = shift;
	
	my ($line, @border_pos, @bp, $first, $b, $valid);

	# The first thing we need to do is validate the table.
	# This supports only grid tables - no row or col span.
	# All + and | must line up exactly. If they don't, the 
	# type is changed from table to source_code, so it will
	# be printed exactly as it appears.
	
	$valid = 1;
	$first = 1;
	for $line ( @{$table->{lines}} )
	{
		last if ( !$valid );
		
		@bp = ( );
		if ( $first )
		{
			$first = 0;
			$self->_get_border_pos ($line, \@border_pos);
			if ( scalar @border_pos < 2 ) { $valid = 0; }
		}
		else
		{
			# Validate that the + and | characters line up
			$self->_get_border_pos ($line, \@bp);
			if ( $#border_pos != $#bp ) { $valid = 0; } 
			for ( $b=0; $b < scalar @border_pos; $b++ )
			{
				if ( $bp[$b] != $border_pos[$b] ) { $valid = 0; }
			}
			
			# Validate that the top border of each cell is valid
			if ( $line =~ m/^\s*\+/ )
			{
				my ($b, $len, $border);
				for ( $b=0; $b < $#border_pos; $b++ )
				{
					$len = $border_pos[$b+1] - $border_pos[$b] - 1;
					$border = substr ($line, $border_pos[$b]+1, $len);
					
					if ( $border !~ m/^=+$/ && $border !~ m/^-+$/ ) { $valid = 0; }
				}
			}
			
		}
	}
	
	if ( ! $valid )
	{
		$table->{type} = "source code";
		return;
	}

	# Table is valid. Break table into cells.
	my ($cur_row, $line_count, $l);

	$table->{border_pos} = \@border_pos;
	$table->{rows} = [ ];
	$line_count = scalar @{$table->{lines}};
	for ( $l=0; $l < $line_count; $l++ )
	{
		$line = $table->{lines}->[$l];
		
		if ( substr ($line, 0,1) eq "+" )
		{
			# Don't process if this is the last line
			next if ( $l == $line_count-1);
			
			# Create a new row
			my (%row, @cells);
			
			# Set up the row
			$row{cells} = \@cells;
			$cur_row = \%row;
			
			# Add cell hashes to the row
			for ( $b=0; $b < $#border_pos; $b++ )
			{
				my (%cell, $len, $border);
				
				# Determine the cell type
				$len = $border_pos[$b+1] - $border_pos[$b] - 1;
				$border = substr ($line, $border_pos[$b]+1, $len);
				if ( $border =~ m/=+/ ) { $cell{type} = "heading"; }
				else                    { $cell{type} = "text";    }
				$cell{width} = $len;
				
				# Add the cell hash to the cells value of the row hash
				$cell{data} = "";
				push @{$cur_row->{cells}}, \%cell;
			}
			
			# Add the row to the rows value in the list
			push @{$table->{rows}}, $cur_row;
		}
		else
		{
			# Add data to the cells
			for ( $b=0; $b < $#border_pos; $b++ )
			{
				my ($len, $cell_data, $cells, $cur_cell);
				
				# Get the cell hash
				$cells = $cur_row->{cells};
				$cur_cell = $cells->[$b];
				
				# Isolate the data from this line for the cell
				$len = $border_pos[$b+1] - $border_pos[$b] - 1;
				$cell_data = substr ($line, $border_pos[$b]+1, $len);
				$cell_data =~ s/^\s+//;
				$cell_data =~ s/\s+$//;

				if ( $cur_cell->{data} ne "" && $cell_data ne "" ) { $cur_cell->{data} .= " "; }
				$cur_cell->{data} .= $cell_data;
			}
		}
	}
	
	# The last row will probably be empty - If so, delete it
	if ( scalar @{$cur_row->{cells}} == 0 ) { pop @{$table->{rows}}; }

	# Delete the lines value - we have moved everything to cells
	delete ($table->{lines});
}

sub _get_border_pos
{
	my $self = shift;
	my $line = shift;
	my $poslist = shift;
	
	my ($l, $char);
	for ( $l=0; $l < length ($line); $l++ )
	{
		$char = substr ($line, $l, 1);
		if ( $char eq "+" || $char eq "|" ) { push @$poslist, $l; }
		if ( $char eq "\t" )
		{
			# Don't allow tabs
			@$poslist = ( -1 );
			return;
		}
	}
}

# ----------------------------------------------------------------------------
sub _combine_lines
{
	my $self = shift;
	my $paragraphs = shift;
	
	my ($para, $line, $data);
	
	for $para ( @$paragraphs )
	{
		next if ( $para->{type} eq "source code" );
		next if ( ! exists ($para->{lines}) );
		
		$data = "";
		for $line ( @{$para->{lines}} )
		{
			$data .= "$line ";
		}
		
		delete ($para->{lines});
		
		$data =~ s/\s+/ /;
		$data =~ s/^\s*//;
		$data =~ s/\s*$//;
		
		$para->{data} = $data;
	}
}

# ============================================================================
# DOCUMENTATION
# ============================================================================
=pod
	
=head1 INPUT FORMAT
	
The input file is plain text. Paragraphs are separated from each other by
one or more blank lines. A blank line contains only space characters.

The document object is a hash containing two values:
	
=over 4
	
=item $document->{variables}

The variables value is a reference to a hash containing variable names
and their values. Variables are set in a paragraph of type variables.
	
=item $document->{paragraphs}

The paragraphs value holds the content of the file as a reference to a
list of hash reference. Each hash reference in a list is a paragraph
object that defines a type value, and may include other values depending on
the paragraph type.
	
=back
	
=head2 Heading Paragraphs
	
You may have headings of any level. The first three headings have special
formatting.
	
=over 4

=item heading 1
	
The last line of a heading 1 paragraph contains only a series of equal signs.

  Example:
	
  This is a heading 1 paragraph
  =============================
	
=item heading 2
 
The last line of a heading 2 paragraph contains only a series of dash characters.

  Example:
	
  This is a heading 2 paragraph
  -----------------------------

=item heading 3
	
The last line of a heading 3 paragraph contains only a series of period characters.

  Example:
	
  This is a heading 2 paragraph
  .............................

=item Alternate heading format

Instead of using = - and . characters to indicate heading level, you can use
an alternate heading format. Heading lines can also be indicated by specifying
the heading level number followed by a greater than sign on the first line
of the paragraph.
	
This is the only way to specify heading levels greater than 3.

 1> This is a level one heading
 10> This is a level ten heading
	
=item Paragraph Structure
	
The $para->{type} is "heading". The $para->{level} holds the level number.
The content of the paragraph is in the $para->{data} element.
	
=back
	
=head2 List Paragraphs
	
A list is identified as a series of list item paragraphs of the same type.
	
There are three types of list paragraphs.

=over 4
	
=item bullet item
	
A bullet item paragraph is identified by the appearance of the string "*)"
as the first non-space characters on the first line of the paragraph.
	
  Example:
  
  *) This is a bullet item paragraph.
     It can contain as many lines as you need.
	
=item number item
	
A number item paragraph is similar to a bullet item paragraph, but
instead of an asterisk, the first line has a number followed
immediately by the close parenthesis character as the first non-space
characters on the line. There must not be a space between the number
and the parenthesis.
	
  Example:
	
  1) This is a number list item
   
  2) Here is another
	
=item name item
	
The name may have any text before the parenthesis. You may place text on
first line along with the name, or the first line may contain only the name.
	
 Example:
	
 a) This is a simple name item paragraph.
	
 A longer example)
   You may want to drop the text down for longer
   name item paragraphs.
	
=back

Each list type paragraphs holds the paragraph type in the $para->{type}
value. Number items hold the number value in $para->{number}, and name
list items hold the name value in $para->{name}. All paragraph types
hold the content of the paragraph in $para->{data}.
	
All consecutive list items of the same type will be collected into a list object.
The list object indicates the type of list as $para->{type}. These are: bullet_list,
number_list, and name_list. The $para->{items} value is a reference to a list of
the list item paragraph hashes.

=head2 Tables
	
Only grid type tables are supported. No column or row spanning is supported.
	
The input format of the table use | + and -characters to create a table layout.
For example:
	
 +=================+==============+
 | State           | Postal Code  |
 +-----------------+--------------+
 | Indiana         | IN           |
 +-----------------+--------------+
 | Michigan        | MI           |
 +-----------------+--------------+
 | Texas           | TX           |
 +-----------------+--------------+

Notice that you may use either ===== or ----- characters to frame the table.
Use === characters to indicate that the cell below it is a heading cell and use
--- to indicate that the cell below it is a data cell.

A table may have a caption. The caption must be on a single line, and must
appear on either the first or last line of the paragraph. The placement of
the caption is not retained. A document render formatter will place it in a
default position.
	
For a paragraph to be recognized as a table, every line that is not the caption
line must have + or | as the first non-space character. All + and | characters
must line up exactly, and there must be no tabs in the table. If a paragraph
is recognized as a table, but the grid structure is not valid (because you
spanned a column or row) the paragraph will be converted to type source_code,
and the table will be rendered exactly as it appears in the input file.

The table paragraph has the following structure. $para->{caption} holds the
table caption text if a caption was specified. $para->{rows} is the reference
to a list holding references to row hashes.
	
Each row hash has a single value, $row->{cells}, which is a reference to a list
of cell references.
	
Each cell reference holds two values. $cell->{type} is either heading or text.
$cell->{data} holds the content of that cell.
	
=head2 Source Code
	
Source code paragraphs retain their exact formatting, including leading and
trailing spaces on a line.
	
A source code paragraph is indicated by having both the first and last line
consist only of a list of dashes.
	
Example:
	
 --------------
 // Sample source code paragraph
 #include <stdio.h>
 int main (int argc, char *argv)
 {
    printf ("Hello World\n");
 }
 --------------

Source code paragraphs will be rendered in a fixed width font.

The lines are stored in $para->{lines}.

=head2 separator
	
A separator paragraph consists of a single line having
a series of dash characters. A separator paragraph
can be used, for example, to separate scenes in a
story.

=head2 page break

A page break paragraph consists of a single line having
as series of plus characters.
	
=head2 block

A block paragraph is set in from other paragraphs, and 
can be used for block quotes. The first line of a block
paragraph consists only of one or more greater than
character.
	
=head2 Part

The part paragraph type creates a special entry
in the computed table of contents for the major part
of a book. The part paragraph should be a single line
with two dashes before and two dashes after the
part name.
	
Example:
	
  -- Part One --
	
=head2 Nav Point
	
Used by the ePub output format, the nav point paragraph
type inserts a table of content entry at the point of
the paragraph. No text is rendered at the point of the
paragraph. Instead, a table of content entry is established
which points to the location of the Nav Point.
	
A Nav Point paragrah type consits of a single line with the table of
content words between less than and greater than characters.

You might put a nav point before an image insertion block.
	
Example:
	
 <Picture Of Home>
	
 @image
 home.jpg
 @end

=head2 Explicit paragraph types
 
Instead of using decorators, you can also explicitly name
paragraphs. This is necessary if you want a single paragraph
to contain blank lines, which would otherwise be separated
into different paragraphs.
	
Named paragraphs begin with @ followed by the paragraph type name
and continue until a line containing @end.
	
Example:

 @source code
 #include <iostream>
 using namespace std;
	
 int main (int argc, char *argv[])
 {
	// Say Hello
	cout << "Hello" << endl;
    return 0;
 }
 @end
	
=head2 Setting the default type
	
By default, all paragraphs start as type "unknown". They are then
identified according to the various decorators described above.
Only paragraphs of type "unknown" will be converted based on
the decoration characters. Paragraphs are still separated
at blank lines.
	
A single line that starts with an ampersand and is followed by
text will set the default paragraph type.
	
Example:
	
 >>>
 This is a block paragraph
	
 &block
	
 This and all subsequent paragraphs will all be type block.
	
 This is another block paragraph.
 
 &unknown
	
 This is a plain paragraph.
 
=head2 Include

A text file can include another text file. An include paragraph
is a single line that begins with #include and is followed by
the name of the included file.
	
=head2 Variables
	
A variables paragraph is not part of the document flow. It causes variables
to be set in the document's variables hash. This can be used to influence
document rendering, or hold document attributes.
	
Each line in the variable paragraph must conform to the syntax of a variable
setting. A variable name may not contain spaces. It may contain word characters,
which are letters, numbers, and underline.
	
The variable name must be followed by => and then the value.
	
Example:
	
 title => Document title
 author => Daniel LaFavers
	
=head3 Variable names
	
The following variable names are used by various output formats.
	
=over 3
	
=item title
	
Defines the title of the work.
	
=item subtitle

Defines the subtitle of the work.

=item author

The author name.

=item copyright

Copyright statement.

=item cover

Path to the cover image of the book.

=item imprint

Path to the imprint image for the book.

=item justify

Set 1 to justify the text.

=item wrapcol

Width of the text. Used by the text output formatter.

=item line_spacing

Set to 1, 2, etc. Used by the rtf output formatter to set line height.

=item book_id

ISBN or other book identifier.

=item epub_buildroot

Directory used as the root of the ebook directory tree.

=item images
	
Comma separated list of images that are included in the
book.

=back
	
=head2 Text paragraphs

Any paragraph not otherwise recognized will be tagged as type text.
	
=head2 Character Formatting
	
Character formatting can be specified using character formatting blocks
as described in the Draw.pm module's text function.
	
A character format block is enclosed within curly braces.
Each format block consists of a format code and text separated by
a colon.

Examples:
	
 Emphasis is shown with {b:bold text}.
 Some words are {i:italic}.
 Titles are {u:underlined}.
 Multiple formats: {b:{i:{u:important message!}}}

=cut
	
	
# ============================================================================
return 1;
