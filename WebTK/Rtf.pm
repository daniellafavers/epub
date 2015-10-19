# ============================================================================
package WebTK::Rtf;

# ============================================================================
# DIRECTIVES
# ============================================================================
use strict;
use POSIX;

# ============================================================================
# POD HEADER
# ============================================================================

=pod
	
=head1 NAME
	
WebTK::Rtf - Write rtf files
	
=head1 SYNOPSIS
 
 use WebTK::Rtf;
 my $rtf = WebTK::Rtf->new ();
 $rtf->font ("Courier");
 $rtf->para_type ("tx", { font=>"Courier" });
 $rtf->open ();
 $rtf->para ("tx", "Hello World");
 $rtf->close ();
 $rtf->print ();

=head1 AUTHOR
    
Daniel LaFavers

=head1 DESCRIPTION
    
The WebTK::Rtf object provides functions for formatting and writing RTF files.
Function use hash tables to convey setting information to the functions.
	
=cut

# ============================================================================
# CLASSWIDE VARIABLES
# ============================================================================

# ============================================================================
# CLASS METHODS
# ============================================================================

# ----------------------------------------------------------------------------
sub new
{
	my $class = shift;
	
	my ($self, $buf, @fonts, %fontnames, @colors, %paratypes);
	
	$self = { };
	bless $self, $class;
	
	$self->{buf} = $buf;
	$self->{fonts} = \@fonts;
	$self->{fontnames} = \%fontnames;
	$self->{colors} = \@colors;
	$self->{paratypes} = \%paratypes;
	$self->{margins} = { };
	$self->{headers} = [ ];
	$self->{footers} = [ ];
	
	return $self;
}

# ============================================================================
# OBJECT METHODS
# ============================================================================

# ----------------------------------------------------------------------------
sub font
{
	my $self = shift;
	my $font = shift;
	
	my $fontnum = scalar @{$self->{fonts}};
	
	# Push the name onto the list for the font table
	push @{$self->{fonts}}, $font;
	
	# Create a map from the font name to the font number
	$self->{fontnames}->{$font} = $fontnum;
}

# ----------------------------------------------------------------------------
sub para_type
{
	my $self = shift;
	my $name = shift;
	my $format = shift;

	if ( ref $format eq "HASH" )
	{
		$format->{name} = $name;
		$self->{paratypes}->{$name} = $format;
	}
}

# ----------------------------------------------------------------------------
sub margins
{
	my $self = shift;
	my $margins = shift;
	
	if ( ref $margins eq "HASH" )
	{
		$self->{margins} = $margins;
	}
}

# ----------------------------------------------------------------------------
sub header
{
	my $self = shift;
	my $header = shift;
	
	if ( ref $header eq "HASH" )
	{
		push @{$self->{headers}},  $header;
	}
}

# ----------------------------------------------------------------------------
sub footer
{
	my $self = shift;
	my $footer = shift;
	
	if ( ref $footer eq "HASH" )
	{
		push @{$self->{footers}},  $footer;
	}
}

# ----------------------------------------------------------------------------
sub open
{
	my $self = shift;
	
	# Add the open mark
	$self->{buf} .= "{\\rtf1\\ansi\\deff0\n";
	
	# Add the font table - fonts are specified by the user by calling font
	$self->_fonttable ();

	# Fill the color table - colors are only specified internally so we can
	# use consistent color names in the chracter formatting
	$self->{colors} = 
		[
		 { red=>"255", green=>"0", blue=>"0" }, # red
		 { red=>"0", green=>"255", blue=>"0" }, # green
		 { red=>"0", green=>"0", blue=>"255" }, # blue
		 ];
	
	# Add the color table
	$self->_colortable ();
	
	# Set margins
	$self->_margins ();
	
	# Set header and footer
	$self->_headers ();
	$self->_footers ();
}

# ----------------------------------------------------------------------------
sub para
{
	my $self = shift;
	my $type = shift;
	my $content = shift;
	
	my ($t);
	
	# Look up the paragraph type name
	$t = $self->{paratypes}->{$type};
	
	# Use default if this is not a valid name
	if ( ! defined ($t) ) { $t = { name => "default"}; }
	$self->_para ($t, $content);
}

# ----------------------------------------------------------------------------
sub cellpara
{
	my $self = shift;
	my $type = shift;
	my $content = shift;
	
	my ($t);
	
	# Look up the paragraph type name
	$t = $self->{paratypes}->{$type};
	
	# Use default if this is not a valid name
	if ( ! defined ($t) ) { $t = { name => "default"}; }
	$self->_cellpara ($t, $content);
}

# ----------------------------------------------------------------------------
sub row
{
	my $self = shift;
	my $cells = shift;
	
	my ($cell);
	
	$self->_openrow ($cells);
	for $cell ( @$cells )
	{
		my ($paratype, $text);
		$paratype = $cell->{paratype};
		$text     = $cell->{text};
		
		$self->cellpara ($paratype, $text);
	}
	$self->_closerow ();
}

# ----------------------------------------------------------------------------
sub close
{
	my $self = shift;
	$self->{buf} .= "}\n";
}

# ----------------------------------------------------------------------------
sub draw
{
	my $self = shift;
	return $self->{buf};
}

# ----------------------------------------------------------------------------
sub print
{
	my $self = shift;
	print $self->draw ();
}

# ============================================================================
# INTERNAL METHODS
# ============================================================================

# ----------------------------------------------------------------------------
sub _fonttable
{
	my $self = shift;

	my ($font, $num, $table);
	
	return if ( scalar @{$self->{fonts}} == 0 );
	
	$table = "{\\fonttbl\n";
	
	$num = 0;
	for $font ( @{$self->{fonts}} )
	{
		$table .= "{\\f${num} ${font};}\n";
		$num++;
	}
	$table .= "}\n";

	$self->{buf} .= $table;
}

# ----------------------------------------------------------------------------
sub _colortable
{
	my $self = shift;

	my ($color, $num, $table);
	
	return if ( scalar @{$self->{colors}} == 0 );

	$table = "{\\colortbl\n;\n";
	
	for $color ( @{$self->{colors}} )
	{
		$table .= "\\red$color->{red}\\green$color->{green}\\blue$color->{blue};\n";
	}
	$table .= "}\n";

	$self->{buf} .= $table;
}

# ----------------------------------------------------------------------------
sub _margins
{
	my $self = shift;
	my $mref = $self->{margins};
	my ($margins, $cmd, $twips, $key, $count);
	
	$margins = "";
	$count = 0;
	for $key ( qw / left right bottom top / )
	{
		next if ( ! exists ($mref->{$key}) );
		
		# Set the command margl, margr, margb, margt
		if ( $key eq "left" )   { $cmd = '\margl'; $count++; }
		if ( $key eq "right" )  { $cmd = '\margr'; $count++; }
		if ( $key eq "top" )    { $cmd = '\margt'; $count++; }
		if ( $key eq "bottom" ) { $cmd = '\margb'; $count++; }
		
		# Convert inches to twips
		$twips = $self->_inches_to_twips ($mref->{$key});
		
		$margins .= $cmd . $twips;
	}
	$margins .= "\n";
	
	if ( $count ) { $self->{buf} .= $margins; }
}

# ----------------------------------------------------------------------------
# Set headers - This takes a reference to a hash. The keys and values are:
# type - all, first, left, right
# font - Font number
# size - Font size in points
# align - alignment
# content - header contents
sub _headers
{
	my $self = shift;
	
	my ($ref, $header, $p, $twips);
	my ($type, $font, $size, $align, $content);
	my ($fontname, $fontnum);
	
	for $ref ( @{$self->{headers}} )
	{
		for $p ( qw / type font size align / )
		{
			next if ( ! exists ($ref->{$p}) );
			
			if ( $p eq "type" )
			{
				if ( $ref->{$p} eq "all" )    { $type = "header";  $align = "qr"; }
				if ( $ref->{$p} eq "first" )  { $type = "headerf"; $align = "qr"; }
				if ( $ref->{$p} eq "left" )   { $type = "headerl"; $align = "ql"; }
				if ( $ref->{$p} eq "right" )  { $type = "headerr"; $align = "qr"; }
			}
			elsif ( $p eq "font" )
			{
				$fontname = $ref->{$p};
				$fontnum = $self->{fontnames}->{$fontname};
				if ( ! defined $fontnum ) { $fontnum = "0"; }
			}
			elsif ( $p eq "size" )
			{
				# Convert to half point
				$size = floor($ref->{$p} * 2);
			}
			elsif ( $p eq "align" )
			{
				if ( $ref->{$p} eq "left" )    { $align = "ql"; }
				if ( $ref->{$p} eq "right" )   { $align = "qr"; }
				if ( $ref->{$p} eq "center" )  { $align = "qc"; }
				if ( $ref->{$p} eq "justify" ) { $align = "qj"; }
			}
		}
		
		# Convert markup
		$self->_convert_markup (\$ref->{content});
		
		# Put it all together
		$header = "{\\" . $type . "{\\" . $align .
			"\\f" . $fontnum . "\\fs" . $size .
			"{" . $ref->{content} . "\\par}}}\n";
		
	}
	$self->{buf} .= $header;
}
# ----------------------------------------------------------------------------
# Set footers - This takes a reference to a hash. The keys and values are:
# type - all, first, left, right
# font - Font number
# size - Font size in points
# align - alignment
# content - header contents
sub _footers
{
	my $self = shift;
	
	my ($ref, $header, $p, $twips);
	my ($type, $font, $size, $align, $content);
	my ($fontname, $fontnum);
	
	for $ref ( @{$self->{footers}} )
	{
		for $p ( qw / type font size align / )
		{
			next if ( ! exists ($ref->{$p}) );
			
			if ( $p eq "type" )
			{
				if ( $ref->{$p} eq "all" )    { $type = "footer";  $align = "qr"; }
				if ( $ref->{$p} eq "first" )  { $type = "footerf"; $align = "qr"; }
				if ( $ref->{$p} eq "left" )   { $type = "footerl"; $align = "ql"; }
				if ( $ref->{$p} eq "right" )  { $type = "footerr"; $align = "qr"; }
			}
			elsif ( $p eq "font" )
			{
				$fontname = $ref->{$p};
				$fontnum = $self->{fontnames}->{$fontname};
				if ( ! defined $fontnum ) { $fontnum = "0"; }
			}
			elsif ( $p eq "size" )
			{
				# Convert to half point
				$size = floor($ref->{$p} * 2);
			}
			elsif ( $p eq "align" )
			{
				if ( $ref->{$p} eq "left" )    { $align = "ql"; }
				if ( $ref->{$p} eq "right" )   { $align = "qr"; }
				if ( $ref->{$p} eq "center" )  { $align = "qc"; }
				if ( $ref->{$p} eq "justify" ) { $align = "qj"; }
			}
		}
		
		# Convert markup
		$self->_convert_markup (\$ref->{content});
		
		# Put it all together
		$header = "{\\" . $type . "{\\" . $align .
			"\\f" . $fontnum . "\\fs" . $size .
			"{" . $ref->{content} . "\\par}}}\n";
		
	}
	$self->{buf} .= $header;
}

# ----------------------------------------------------------------------------
# Paragraph - This takes a reference to a format hash.
# The hash keys and values are:
#   indent: indent of first line in inches
#   align - left, right, justify, center
#   font - Font number
#   size - Font size in points
#   before - Space before in points
#   after - Space after in points
#   line - Exact spacing between lines
#
# The second parameter is the content
sub _para
{
	my $self = shift;
	my $fmt = shift;
	my $content = shift;
	
	my ($para, $p, $twips, $b);
	
	$para = "{\\pard";

	# Set opening commands
	for $p ( qw /first indent indent_right align font page_break size before after line
			     border_top border_bottom border_left border_right / )
	{
		next if ( ! exists ($fmt->{$p}) );
		
		if ( $p eq "first" ) 
		{
			$twips = $self->_inches_to_twips ($fmt->{$p});
			$para .= "\\fi" . $twips; 
		}
		elsif ( $p eq "indent" ) 
		{
			$twips = $self->_inches_to_twips ($fmt->{$p});
			$para .= "\\li" . $twips; 
		}
		elsif ( $p eq "indent_right" ) 
		{
			$twips = $self->_inches_to_twips ($fmt->{$p});
			$para .= "\\ri" . $twips; 
		}
		elsif ( $p eq "align" )
		{
			if    ( $fmt->{$p} eq "left" )    { $para .= "\\ql"; }
			elsif ( $fmt->{$p} eq "right" )   { $para .= "\\qr"; }
			elsif ( $fmt->{$p} eq "justify" ) { $para .= "\\qj"; }
			elsif ( $fmt->{$p} eq "center" )  { $para .= "\\qc"; }
		}
		elsif ( $p eq "font" )
		{
			my ($fontname, $fontnum);
			$fontname = $fmt->{$p};
			$fontnum = $self->{fontnames}->{$fontname};
			if ( ! defined $fontnum ) { $fontnum = "0"; }
			$para .= "\\f" . $fontnum;
		}
		elsif ( $p eq "size" )
		{
			# Font size is expressed in half points
			$para .= "\\fs" . floor ($fmt->{$p} * 2);
		}
		elsif ( $p eq "before" )
		{
			$twips = $self->_points_to_twips ($fmt->{$p});
			$para .= "\\sb" . $twips;
		}
		elsif ( $p eq "after" )
		{
			$twips = $self->_points_to_twips ($fmt->{$p});
			$para .= "\\sa" . $twips;
		}
		elsif ( $p eq "page_break" )
		{
			if ( $fmt->{$p} eq "before" ) { $para .= "\\pagebb"; }
		}
		elsif ( $p eq "line" )
		{
			$twips = $self->_points_to_twips ($fmt->{$p});
			$para .= "\\sl" . $twips . "\\slmult1";
		}
		elsif ( $p eq "border_top" )
		{
			$b = $fmt->{$p};
			$para .= "\n\\brdrt \\brdrs \\brdrw$b \\brsp50";
		}
		elsif ( $p eq "border_bottom" )
		{
			$b = $fmt->{$p};
			$para .= "\n\\brdrb \\brdrs \\brdrw$b \\brsp50";
		}
		elsif ( $p eq "border_left" )
		{
			$b = $fmt->{$p};
			$para .= "\n\\brdrl \\brdrs \\brdrw$b \\brsp50";
		}
		elsif ( $p eq "border_right" )
		{
			$b = $fmt->{$p};
			$para .= "\n\\brdrr \\brdrs \\brdrw$b \\brsp50";
		}
	}
	$para .= "\n";

	$self->_convert_markup (\$content);

	$para .= $content . "\n";
	$para .= "\\par}\n";
	
	$self->{buf} .= $para;
}

# ----------------------------------------------------------------------------
# Cell Paragraph - This takes a reference to a format hash.
# The hash keys and values are:
#   indent: indent of first line in inches
#   align - left, right, justify, center
#   font - Font number
#   size - Font size in points
#   before - Space before in points
#   after - Space after in points
#   line - Exact spacing between lines
#
# The second parameter is the content
sub _cellpara
{
	my $self = shift;
	my $fmt = shift;
	my $content = shift;
	
	my ($para, $p, $twips);
	
	$para = "\\pard\\intbl";

	# Set opening commands
	for $p ( qw /align font size before after line/ )
	{
		next if ( ! exists ($fmt->{$p}) );
		
		if ( $p eq "align" )
		{
			if    ( $fmt->{$p} eq "left" )    { $para .= "\\ql"; }
			elsif ( $fmt->{$p} eq "right" )   { $para .= "\\qr"; }
			elsif ( $fmt->{$p} eq "justify" ) { $para .= "\\qj"; }
			elsif ( $fmt->{$p} eq "center" )  { $para .= "\\qc"; }
		}
		elsif ( $p eq "font" )
		{
			my ($fontname, $fontnum);
			$fontname = $fmt->{$p};
			$fontnum = $self->{fontnames}->{$fontname};
			if ( ! defined $fontnum ) { $fontnum = "0"; }
			$para .= "\\f" . $fontnum;
		}
		elsif ( $p eq "size" )
		{
			# Font size is expressed in half points
			$para .= "\\fs" . floor ($fmt->{$p} * 2);
		}
		elsif ( $p eq "before" )
		{
			$twips = $self->_points_to_twips ($fmt->{$p});
			$para .= "\\sb" . $twips;
		}
		elsif ( $p eq "after" )
		{
			$twips = $self->_points_to_twips ($fmt->{$p});
			$para .= "\\sa" . $twips;
		}
		elsif ( $p eq "line" )
		{
			$twips = $self->_points_to_twips ($fmt->{$p});
			$para .= "\\sl-" . $twips;
		}
	}
	$self->_convert_markup (\$content);

	$para .= " $content";
	$para .= "\\cell\n";
	
	$self->{buf} .= $para;
}

# ----------------------------------------------------------------------------
sub _convert_markup
{
	my $self = shift;
	my $content = shift; # Reference to string
	
	# Convert markup
	my $pattern = '{(\w+):([^{]+?)}';
	while ($$content =~ s/$pattern/$self->_char_markup($1,$2)/e) { }
	
	# Convert any stray { and } to \{ and \}
	$$content =~ s/{/\\{/g;
	$$content =~ s/}/\\}/g;
	
	# Converted translated braces back to their natural form
	$$content =~ s/<op>/{/g;
	$$content =~ s/<cl>/}/g;
}

# ----------------------------------------------------------------------------
# Because both rtf and the {code:data} format both use curly braces, we wil
# never write { or } into the data. Instead, we write <op> and <cl>, and then
# do a substitution after all replacements are finished.
sub _char_markup
{
	my $self = shift;
	my $cmd = shift;
	my $data = shift;
	
	if ( $cmd eq "b" ) { return '<op>\b ' . $data . '<cl>'; }
	if ( $cmd eq "i" ) { return '<op>\i ' . $data . '<cl>'; }
	if ( $cmd eq "u" ) { return '<op>\ul ' . $data . '<cl>'; }
	
	if ( $cmd eq "red" )    { return '<op>\cf1 ' . $data . '<cl>'; }
	if ( $cmd eq "green" )  { return '<op>\cf2 ' . $data . '<cl>'; }
	if ( $cmd eq "blue" )   { return '<op>\cf3 ' . $data . '<cl>'; }

	if ( $cmd eq "pg" ) 
	{
		$data =~ s/\#/\\chpgn /g;
		return $data; 
	}
	
	if ( $cmd eq "link" || $cmd eq "linkout" )
	{
		my ($href,$text) = $data =~ m/([^|]+)\|(.+)/;
		return '<op>\field<op>\*\fldinst<op>HYPERLINK "' . $href . 
			'"<cl><cl><op>\fldrslt<op>\ul ' . $text . '<cl><cl><cl>';
	}
	
	# Unknown command
	return $data;
}

# ----------------------------------------------------------------------------
sub _openrow
{
	my $self = shift;
	my $cells = shift;
	
	my ($c, $b, $right);
	
	$self->{buf} .= "\\trowd \\trgaph130\n";
	
	$right = 0;
	for $c ( @$cells )
	{
		$right += $c->{width}*100;
		for $b (qw/t l b r/)
		{
			$self->{buf} .= "\\clbrdr$b\\brdrw15\\brdrs";
		}
		$self->{buf} .= "\\cellx$right";
	}
	$self->{buf} .= "\n";
}

# ----------------------------------------------------------------------------
sub _closerow
{
	my $self = shift;
	$self->{buf} .= "\\row\n";
}

# ----------------------------------------------------------------------------
sub _inches_to_twips
{
	my $self = shift;
	my $inches = shift;
	my $twips;
	
	$twips = floor ($inches * 1440);
	return $twips;
}

# ----------------------------------------------------------------------------
sub _points_to_twips
{
	my $self = shift;
	my $points = shift;
	my $twips;
	
	$twips = floor ($points * 20);
	return $twips;
}

# ============================================================================
return 1;
