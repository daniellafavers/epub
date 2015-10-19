# ============================================================================
package WebTK::Document::Rtf;

# ============================================================================
# DIRECTIVES
# ============================================================================
use strict;
use POSIX;
use WebTK::Document::Hash;
use WebTK::Rtf;
our @ISA = ("WebTK::Document::Hash");

# ============================================================================
# POD HEADER
# ============================================================================

# ============================================================================
# CLASSWIDE VARIABLES
# ============================================================================

# ============================================================================
# CLASS METHODS
# ============================================================================

# ============================================================================
# OBJECT METHODS
# ============================================================================

# ----------------------------------------------------------------------------
sub new
{
	my $class = shift;
	my $doc = shift;
	
	# Create the object
	my $self = { };
	$self->{varfcn} = undef;
	bless $self, $class;

	my $rtf = WebTK::Rtf->new ();
	$self->{rtf} = $rtf;
	$self->{doc} = $doc;
	
	# Paragraph types
	$self->{para_types} =
		[ qw /
		  title subtitle author list namelist-name namelist-body text
		  table-space table-head table-cell h1 h2 h3 h9
		  code code-border-top code-border-bottom 
          page-break, block
		  / ];
	
	# Defaults
	$self->set_defaults ();
	
	return $self;
}

# ----------------------------------------------------------------------------
sub set_defaults
{
}

# ----------------------------------------------------------------------------
sub get_para_types
{
	my $self = shift;
	return $self->{para_types};
}

# ----------------------------------------------------------------------------
sub set_para_type
{
	my $self = shift;
	my $name = shift;
	my $hash = shift;
	
	# Make sure the name is legal
	my ($type);
	
	for $type ( @{$self->{para_types}} )
	{
		if ( $type eq $name )
		{
		}
	}
}

# ----------------------------------------------------------------------------
sub set_var_function
{
    my $self = shift;
    $self->{varfcn} = shift;
}

# ----------------------------------------------------------------------------
# Not a class function
sub fixquote
{
	my $input = shift;
	my $leftquote = shift;
	my $rightquote = shift;
	my $left = 1;
	my $len = length ($input);
	my ($i, $c, $out);
	$out = "";
	for ( $i=0; $i < $len; $i++ )
	{
		$c = substr ($input, $i, 1);
		if ( $c eq "\"" )
		{
			if ( $left )
			{
				$out .= $leftquote;
				$left = 0;
			}
			else
			{
				$out .= $rightquote;
				$left = 1;
			}
		}
		else
		{
			$out .= $c;
		}
	}
	return $out;
}

sub replace_stuff_1
{
	# The sequence for characters include the single
	# quote. Change all actual single quotes and other
	# characters to a special marker, then after we
	# do the quotes, update these
	my $input = shift;
	$input =~ s/`/_LSQ_/g;
	$input =~ s/'/_RSQ_/g;
	$input =~ s/--/_MDSH_/g;
	$input =~ s/\.\.\./_ELIP_/g;
	return $input;
}

sub replace_stuff_2
{
	my $input = shift;
	$input =~ s/_LSQ_/\\lquote /g;
	$input =~ s/_RSQ_/\\rquote /g;
	$input =~ s/_MDSH_/\\emdash /g;
	$input =~ s/_ELIP_/\\u8230\\'c9/g;
	return $input;
}

# ----------------------------------------------------------------------------
sub render
{
	my $self = shift;
	my $doc = $self->{doc};
	
	my ($vars, $pars, $rtf);
	
	$vars = $doc->{variables};
	$pars = $doc->{paragraphs};
	$rtf = $self->{rtf};

	# Setup the rtf object
	my $title = $vars->{title};
	my $author = $vars->{author};
	
	my ($title_font, $code_font, $main_font, $header_font, $part_font, $line_spacing, $lspace);
	$main_font = "Times New Roman";
	$code_font = "Courier New";
	$title_font = "Times New Roman";
	$header_font = "Times New Roman";
	$part_font = "Times New Roman";
	
	# Fonts
	$rtf->font ($main_font);
	$rtf->font ($code_font);
	$rtf->font ($header_font);
	$rtf->font ($title_font);
	$rtf->font ($part_font);

	# Line spacing
	$line_spacing = $vars->{line_spacing};
	if ( $line_spacing == "" || $line_spacing == 0 || $line_spacing > 3 )
	{
		$line_spacing = 1;
	}
	$lspace = $line_spacing * 12;
	
	# Set up the paragraph types
	$rtf->para_type ("title", 
					 {
						 before=>"20",
						 after=>"20",
						 size=>"72",
						 font=>$title_font,
						 align=>"center",
					 });
	
	$rtf->para_type ("subtitle", 
					 {
						 before=>"20",
						 after=>"20",
						 size=>"48",
						 font=>$title_font,
						 align=>"center",
					 });
	
	$rtf->para_type ("author", 
					 {
						 before=>"20",
						 after=>"20",
						 size=>"36",
						 font=>$title_font,
						 align=>"center",
					 });
	
	$rtf->para_type ("list", 
					 {
						 first=>"-0.2",
						 indent=>"0.5",
						 before=>"6",
						 size=>"12",
						 font=>$main_font,
						 align=>"left",
					 });

	$rtf->para_type ("namelist-name", 
					 {
						 indent=>"0.5",
						 before=>"6",
						 size=>"12",
						 font=>$main_font,
						 align=>"left",
					 });
	
	$rtf->para_type ("namelist-body", 
					 {
						 indent=>"0.5",
						 size=>"12",
						 font=>$main_font,
						 align=>"left",
					 });
	
	$rtf->para_type ("text", 
					 {
						 before=>"12",
						 first=>"0",
						 size=>"12",
						 font=>$main_font,
						 align=>"left",
						 line=>$lspace,
					 });
	
	$rtf->para_type ("center", 
					 {
						 before=>"6",
						 size=>"12",
						 font=>$main_font,
						 align=>"center",
					 });
	
	$rtf->para_type ("table-space", 
					 {
						 before=>"6",
						 size=>"6",
					 });
	
	$rtf->para_type ("table-head", 
					 {
						 size=>"8",
						 font=>$header_font,
						 before=>"3",
						 after=>"3",
						 align=>"center",
					 });
	
	$rtf->para_type ("table-cell", 
					 {
						 size=>"8",
						 font=>$main_font,
						 before=>"3",
						 after=>"1",
						 align=>"left",
					 });
	
	$rtf->para_type ("h1",
					 {
						 page_break=>"before",
						 before=>"12",
						 after=>"6",
						 size=>"16",
						 font=>$main_font,
						 align=>"left",
						 border_bottom=>"40",
					 });

	$rtf->para_type ("h2",
					 {
						 before=>"12",
						 after=>"6",
						 size=>"14",
						 font=>$main_font,
						 align=>"left",
						 border_bottom=>"30",
					 });

	$rtf->para_type ("h3",
					 {
						 before=>"12",
						 after=>"6",
						 size=>"12",
						 font=>$main_font,
						 align=>"left",
						 border_bottom=>"20",
					 });

	$rtf->para_type ("h9",
					 {
						 page_break=>"before",
						 before=>"220",
						 after=>"6",
						 size=>"48",
						 font=>$part_font,
						 align=>"center",
					 });

	$rtf->para_type ("code",
					 {
						 indent => "0.5",
						 indent_right=>"0.5",
						 size=>"10",
						 font=>$code_font,
						 align=>"left",
					 });
					 
	$rtf->para_type ("separator",
					 {
						 before=>"12",
						 after=>"6",
						 indent => "1.5",
						 indent_right=>"1.5",
						 align=>"center",
					 });
					 

	$rtf->para_type ("page-break",
					 {
						 page_break=>"before",
					 });
	
	$rtf->para_type ("block",
					 {
						 indent => "0.5",
						 indent_right=>"0.5",
						 before=>"6",
						 size=>"12",
						 font=>$main_font,
						 align=>"left",
					 });
					 
	# Set the margins
	$rtf->margins
		({
			left => "1",
			right => "1",
			top => "1",
			bottom => "1",
		});
	
	# Set headers and footers
	my $hd = "";
	if ( $title )  { $hd .= "$title / "; }
	if ( $author ) { $hd .= "$author / "; }
	$hd .= "{pg:Page #}";
	
	$rtf->header
		({
			type => "all",
			font => $header_font,
			size => "8",
			align => "right",
			content => $hd,
		});

	#
	#$rtf->footer
	#	({
	#		type => "all",
	#		font => $main_font,
	#		size => "8",
	#		align => "right",
	#		content => "{pg:#}",
	#	});
	
	# Prepare the rtf buffer
	$rtf->open ();

	# Draw the title pages
	$self->_title_pages ();
	
	# Fix quotes and other stuff
	$self->{doc}->formatText (\&replace_stuff_1);
	$self->{doc}->formatText (\&fixquote, "\\ldblquote ","\\rdblquote ");
	$self->{doc}->formatText (\&replace_stuff_2);
	
	# Draw each paragraph
	$self->_render_paragraphs ($vars, $pars);

	# Finalize the rtf buffer
	$rtf->close ();
	
	# Return the documnent string
	return $rtf->draw ();
}

# ============================================================================
# INTERNAL METHODS
# ============================================================================

# ----------------------------------------------------------------------------
# This performs the format steps on data that is added directly to the
# rtf stream
sub _format_text
{
	my $before = shift;
	my ($a, $b, $c);
	$a = replace_stuff_1 ($before);
	$b = fixquote ($a, "\\ldblquote ","\\rdblquote ");
	$c = replace_stuff_2 ($b);
	return $c;
}

# ----------------------------------------------------------------------------
sub _title_pages ()
{
	my $self = shift;
	my $doc = $self->{doc};
	my $rtf = $self->{rtf};
	my $vars = $doc->{variables};

	my ($title, $subtitle, $author, $copyright);
	$title = $vars->{title};
	$subtitle = $vars->{subtitle};
	$author = $vars->{author};
	$copyright = $vars->{copyright};
	
	# First title page
	if ( $title ) { $rtf->para ("title", _format_text ($title)); }
	if ( $subtitle ) { $rtf->para ("subtitle", _format_text ($subtitle)); }
	if ( $author ) { $rtf->para ("author", _format_text ($author)); }
	
	
# 	# Full title page
# 	$rtf->para ("text", $title);
# 	$rtf->para ("text", $subtitle);
# 	$rtf->para ("text", $author);

# 	my @timeData = localtime(time);
# 	my $cpr;
# 	$cpr = "Copyright \\'A9 ";
# 	$cpr .= 1900+$timeData[5];
# 	$cpr .= " $author";
# 	$rtf->para ("text", $cpr);
# 	my $stmt;
# 	$stmt  = "All rights reserved. Printed in the United States of America.\n";
# 	$stmt .= "This publication is protected by copyright.\n";
# 	$rtf->para ("text", $stmt);
# 	$rtf->para ("page-break:", " ");
}

# ----------------------------------------------------------------------------
sub _render_paragraphs
{
	my $self = shift;
	my $vars = shift;
	my $para = shift;

	for $para ( @$para )
	{
		if ( $para->{type} =~ m/^heading/ )
		{
			$self->_heading ($para);
		}
		
		elsif ( $para->{type} eq "part" )
		{
			$self->_part ($para);
		}
		
		elsif ( $para->{type} eq "bullet list" )
		{
			$self->_bullet_list ($para);
		}
		
		elsif ( $para->{type} eq "number list" )
		{
			$self->_number_list ($para);
		}
		
		elsif ( $para->{type} eq "name list" )
		{
			$self->_name_list ($para);
		}
		
		elsif ( $para->{type} eq "table" )
		{
			$self->_table ($para);
		}
		
		elsif ( $para->{type} eq "source code" )
		{
			$self->_source_code ($para);
		}
		
		elsif ( $para->{type} eq "separator" )
		{
			$self->_separator ($para);
		}

		elsif ( $para->{type} eq "page break" )
		{
			$self->_page_break ($para);
		}
		
		elsif ( $para->{type} eq "block" )
		{
			$self->_block ($para);
		}
		
		elsif ( $para->{type} eq "text" )
		{
			$self->_text ($para);
		}
	}
}

# ----------------------------------------------------------------------------
sub _heading
{
	my $self = shift;
	my $para = shift;
	my $rtf = $self->{rtf};

	my ($level, $paratype);
	
	# Get the heading level
	$level = $para->{level};
	$paratype = "h$level";
	$rtf->para ($paratype, $para->{data});
}

# ----------------------------------------------------------------------------
sub _part
{
	my $self = shift;
	my $para = shift;
	my $rtf = $self->{rtf};

	my ($level, $paratype);
	
	# Get the heading level
	$level = 1;
	$paratype = "h$level";
	$rtf->para ($paratype, $para->{data});
}

# ----------------------------------------------------------------------------
sub _bullet_list
{
	my $self = shift;
	my $para = shift;
	my $rtf  = $self->{rtf};
	
	my $item;
	for $item ( @{$para->{items}} )
	{
		my ($content);
		$content = "\\bullet\\tab $item->{data}";
		
		$rtf->para ("list", $content);
	}
}


# ----------------------------------------------------------------------------
sub _number_list
{
	my $self = shift;
	my $para = shift;
	my $rtf  = $self->{rtf};

	my $item;
	for $item ( @{$para->{items}} )
	{
		my ($content);
		$content = "$item->{number})\\tab $item->{data}";
		
		$rtf->para ("list", $content);
	}
}

# ----------------------------------------------------------------------------
sub _name_list
{
	my $self = shift;
	my $para = shift;
	my $rtf  = $self->{rtf};
	
	my $item;
	for $item ( @{$para->{items}} )
	{
		$rtf->para ("namelist-name", "{b:" . $item->{name} . "}");
		$rtf->para ("namelist-body", $item->{data});
	}
}

# ----------------------------------------------------------------------------
sub _table
{
	my $self = shift;
	my $para = shift;
	my $rtf  = $self->{rtf};
	
	my ($row, $cell);

	$rtf->para ("table-space", "");
	for $row ( @{$para->{rows}} )
	{
		my @cols;
		for $cell ( @{$row->{cells}} )
		{
			my %col;
			if ( $cell->{type} eq "heading" )
			{
				$col{paratype} = "table-head";
				$col{text} = "{b:" . $cell->{data} . "}";
			}
			else
			{
				$col{paratype} = "table-cell";
				$col{text} = $cell->{data};
			}
			$col{width} = $cell->{width};
			push @cols, \%col;
		}
		$rtf->row (\@cols);
	}
}

# ----------------------------------------------------------------------------
sub _source_code
{
	my $self = shift;
	my $para = shift;
	my $rtf  = $self->{rtf};
	
	my $line;
	$rtf->para ("code", " ");
	for $line ( @{$para->{lines}} )
	{
		$rtf->para ("code", $line);
	}
}

# ----------------------------------------------------------------------------
sub _separator
{
	my $self = shift;
	my $para = shift;
	my $rtf = $self->{rtf};
	
	$rtf->para ("separator", "* * *");
}

# ----------------------------------------------------------------------------
sub _page_break
{
	my $self = shift;
	my $para = shift;
	my $rtf  = $self->{rtf};
	
	$rtf->para ("page-break", " ");
}

# ----------------------------------------------------------------------------
sub _block
{
	my $self = shift;
	my $para = shift;
	my $rtf  = $self->{rtf};
	
	$rtf->para ("block", $para->{data});
}

# ----------------------------------------------------------------------------
sub _text
{
	my $self = shift;
	my $para = shift;
	my $rtf  = $self->{rtf};
	
	$rtf->para ("text", $para->{data});
}

# ============================================================================
return 1;
