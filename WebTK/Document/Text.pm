# ============================================================================
package WebTK::Document::Text;

# ============================================================================
# DIRECTIVES
# ============================================================================
use strict;
use WebTK::Document::Hash;
use WebTK::Draw;
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

# ----------------------------------------------------------------------------
sub new
{
	my $class = shift;
	my $doc = shift;
	
	# Create the object
	my $self = { };
	bless $self, $class;

	my $drw = WebTK::Draw->new ();
	$self->{drw} = $drw;
	$self->{doc} = $doc;
	$self->{varfcn} = undef;

	$self->{justify} = 0;
	$self->{wrap} = 75;
	
	return $self;
}

# ============================================================================
# OBJECT METHODS
# ============================================================================

# ----------------------------------------------------------------------------
sub set_var_function
{
    my $self = shift;
	my $drw = $self->{drw};
    $self->{varfcn} = shift;
	$drw->set_var_function ($self->{varfcn});
}

# ----------------------------------------------------------------------------
# Render only the paragraphs. The caller must provide the rest of the page.
sub render
{
	my $self = shift;
	my $doc = $self->{doc};
	
	my ($vars, $pars, $drw);
	$vars = $doc->{variables};
	$pars = $doc->{paragraphs};
	$drw = $self->{drw};

	# Set variables
	if ( $vars->{wrapcol} ne "" ) { $self->{wrap} = $vars->{wrapcol}; }
	if ( $vars->{justify} ne "" ) { $self->{justify} = $vars->{justify}; }
	
	# Draw each paragraph
	$self->_render_paragraphs ($vars, $pars);

	# Return the document string
	return $drw->draw ();
}


# ============================================================================
# INTERNAL METHODS
# ============================================================================

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
		else
		{
			$self->_other ($para);
		}
	}
}

# ----------------------------------------------------------------------------
sub _padchar
{
	my $self = shift;
	my $char = shift;
	my $len = shift;
	my ($i, $pad);
	for ( $i=0; $i<$len; $i++ )
	{
		$pad .= $char;
	}
	return $pad;
}

# ----------------------------------------------------------------------------
sub _heading
{
	my $self = shift;
	my $para = shift;
	my $drw  = $self->{drw};

	my ($level, $len, $linechar);
	
	# Get the heading level
	$level = $para->{level};
	
	$len = length ($para->{data});
	if    ( $level == 1 ) { $linechar = "="; }
	elsif ( $level == 2 ) { $linechar = "-"; }
	elsif ( $level == 3 ) { $linechar = "."; }
	else                  { $linechar = ""; }
	
	my $line;
	$line = $self->_padchar ($linechar, $len);
	
	$drw->rawtext ("$para->{data}\n");
	$drw->rawtext ("$line\n") if ( $linechar ne "" );
	$drw->rawtext ("\n");
}

# ----------------------------------------------------------------------------
sub _part
{
	my $self = shift;
	my $para = shift;
	my $drw  = $self->{drw};

	my $len = length ($para->{data});
	my $padlen = ($self->{wrap}-$len)/2;
	my $pad;
	if ( $padlen > 1 )
	{
		$pad = $self->_padchar (" ", $padlen);
	}
	
	my ($linechar, $line);
	$linechar = "*";
	$line = $self->_padchar ($linechar, $self->{wrap}) . "\n";
	$drw->rawtext ("\n\n");
	$drw->rawtext ($line);
	$drw->rawtext ($pad . $para->{data} . "\n");
	$drw->rawtext ($line);
	$drw->rawtext ("\n\n");
}
	
# ----------------------------------------------------------------------------
sub _item
{
	my $self = shift;
	my $text = shift;
	my $bullet = shift;
	my $leftpad = shift;
	my $wrapcol = shift;
	my $drw = $self->{drw};

	my ($b, $indent);
	# The bullet should hang in the leftpad area - but until I get that
	# working, just wrap it into the text
	if ( $bullet ne "" )
	{
		$b = "$bullet ";
		$indent = -1 * length ($b);
	}
	else
	{
		$b = "";
		$indent = 0;
	}
	$text = "$b$text";
	
	$self->_wrap ($text, $leftpad, $wrapcol, $indent, $self->{justify});
	$drw->rawtext ("\n");
}

# ----------------------------------------------------------------------------
sub _bullet_list
{
	my $self = shift;
	my $para = shift;
	my $drw  = $self->{drw};
	
	my $item;
	
	for $item ( @{$para->{items}} )
	{
		$self->_item ($item->{data}, "*", 6, $self->{wrap});
	}
}


# ----------------------------------------------------------------------------
sub _number_list
{
	my $self = shift;
	my $para = shift;
	my $drw  = $self->{drw};

	# Use ol with start attribute 
	# Check to make sure numbers are consecutive. If not, don't
	# What if they're not consecutive?

	my ($item, $bullet_len);
	
	$bullet_len = 0;
	for $item ( @{$para->{items}} )
	{
		if ( length ($item->{number}) > $bullet_len )
		{
			$bullet_len = length ($item->{number});
		}
	}
	
	for $item ( @{$para->{items}} )
	{
		$self->_item ($item->{data}, $item->{number}, 
					  $bullet_len+5, $self->{wrap});
	}
}

# ----------------------------------------------------------------------------
sub _name_list
{
	my $self = shift;
	my $para = shift;
	my $drw  = $self->{drw};
	
	my $item;
	
	for $item ( @{$para->{items}} )
	{
		my $text = "$item->{name}:";
		$self->_wrap ($text, 3, $self->{wrap}, 0, $self->{justify});
		$self->_item ($item->{data}, "", 3, $self->{wrap});
	}
}

# ----------------------------------------------------------------------------
sub _table
{
	my $self = shift;
	my $para = shift;
	my $drw  = $self->{drw};
	
	my ($row, $cell);
	
	# Needs work - Wrap each cell to a separate draw object,
	# then split the lines of each one. Combine lines for rows
	# and so on.
	for $row ( @{$para->{rows}} )
	{
		for $cell ( @{$row->{cells}} )
		{
			$self->_wrap ($cell->{data},
						  0, $cell->{width},
						  0, 0);
			$drw->rawtext ("\n");
		}
	}
	
	$drw->rawtext ("\n");
}

# ----------------------------------------------------------------------------
sub _source_code
{
	my $self = shift;
	my $para = shift;
	my $drw  = $self->{drw};
	
	my $line;
	
	for $line ( @{$para->{lines}} )
	{
		$drw->rawtext (": $line\n");
	}
	$drw->rawtext ("\n");
}

# ----------------------------------------------------------------------------
sub _justify
{
	my $self = shift;
	my $text = shift;
	my $wrapcol = shift;
	my $len = length ($text);
	my $add = $wrapcol - $len;

	# Find the positions of the punctuation
	my @punctpos;
	my ($i, $char, $next, $foundspace);
	for ( $i=0; $i < $len; $i++ )
	{
		$char = substr ($text, $i, 1);
		$next = substr ($text, $i+1, 1);
		if ( $next eq " " && 
			 ($char eq "." || $char eq ",") )
		{
			push @punctpos, $i;
		}
	}
	
	# Add spaces after punct
	while ( $add )
	{
		if ( scalar @punctpos )
		{
			$i = shift @punctpos;
			$text = substr ($text, 0, $i+1)." ".substr($text,$i+1);
			$add--;
		}
		last;
	}

	while ( $add )
	{
		# Average spacer 
		my ($ave, $start);
		$ave = int ($wrapcol / ($add+1));
		$start = $ave;
		while ( $add && $start < $wrapcol )
		{
			# Look for next space
			$i = $start;
			while ( $i < $wrapcol )
			{
				$char = substr ($text, $i, 1);
				if ( $char eq " " || $char eq "-" ) { last; }
				$i++;
			}
			if ( $i < $wrapcol )
			{
				if ( $char == " " || $char eq "-" )
				{
					$text = substr ($text, 0, $i+1)." ".substr($text,$i+1);
					$add--;
				}
			}
			else
			{
				# No space found
				return $text;
			}
			
			$start = $start + $ave;
		}
	}
	
	return $text;
}

# ----------------------------------------------------------------------------
sub _wrap
{
	my $self = shift;
	my $text = shift;
	my $leftpad = shift;
	my $rightcol = shift;
	my $indent = shift;
	my $justify = shift;
	
	my $first_leftpad = $leftpad+$indent;
	if ( $first_leftpad < 0 ) { $first_leftpad = 0; }
	my $first_wrapcol = $rightcol - ($first_leftpad);
	my $first_pad = $self->_padchar (" ", $first_leftpad);
	
	my $wrapcol = $rightcol - $leftpad;
	my $pad = $self->_padchar (" ", $leftpad);
	
	my $drw = $self->{drw};

	my ($line, $pos, $wc, $p);
	
	$wc = $first_wrapcol; 
	$p = $first_pad;
	while ( length ($text) > $wc )
	{
		for ($pos = $wc; $pos > 0; $pos-- )
		{
			if ( substr ($text, $pos, 1) eq " " ) { last; }
		}
		if ( $pos == 0 )
		{
			# No suitable breaking point - break in the middle
			$line = substr ($text, 0, $wc);
			$text = substr ($text, $wc);
		}
		else
		{
			$line = substr ($text, 0, $pos);
			$text = substr ($text, $pos+1);
		}
		
		if ( $justify )
		{
			$line = $self->_justify ($line, $wc);
		}
		$drw->rawtext ("$p$line\n");
		$wc = $wrapcol;
		$p = $pad;
	}
	if ( length ($text) > 0 ) 
	{
		$drw->rawtext ("$p$text\n");
	}
}

# ----------------------------------------------------------------------------
sub _separator
{
	my $self = shift;
	my $para = shift;
	my $drw = $self->{drw};
	
	my ($len, $space, $pad, $l, $sep);
	
	$len = $self->{wrap} / 2;
	$space = $self->{wrap} - $len;
	$pad = $space / 2;
	
	$sep = "";
	for ( $l = 0; $l < $len; $l++ ) { $sep .= "-"; }
	
	$self->_item ($sep, "", $pad, $self->{wrap});
}

# ----------------------------------------------------------------------------
sub _page_break
{
	my $self = shift;
	my $para = shift;
	my $drw = $self->{drw};
	$drw->rawtext ("\f");
}

# ----------------------------------------------------------------------------
sub _other
{
	my $self = shift;
	my $para = shift;
	my $drw = $self->{drw};
	
	$drw->rawtext();
	$drw->rawtext ("Para type " . + $para->{type} . "\n");
	$self->_wrap ($para->{data}, 0, $self->{wrap}, 0, 
				  $self->{justify});
	$drw->rawtext ("\n");
}

# ----------------------------------------------------------------------------
sub _block
{
	my $self = shift;
	my $para = shift;
	my $drw  = $self->{drw};
	my $left = 8;
	
	$self->_wrap ($para->{data}, $left, $self->{wrap}-$left, 0, 
				  $self->{justify});
	$drw->rawtext ("\n");
}

# ----------------------------------------------------------------------------
sub _text
{
	my $self = shift;
	my $para = shift;
	my $drw  = $self->{drw};

	$self->_wrap ($para->{data}, 0, $self->{wrap}, 0, 
				  $self->{justify});
	
	$drw->rawtext ("\n");
}

# ============================================================================
return 1;
