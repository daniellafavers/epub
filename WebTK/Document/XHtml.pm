# ============================================================================
package WebTK::Document::XHtml;

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
	
	# Draw each paragraph
	$self->_render_paragraphs ($vars, $pars, $drw);

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
	my $paragraphs = shift;
	my $para;
	my $drw = shift;
	
	
	for $para ( @$paragraphs )
	{
		$drw->rawtext ("\n");
		if ( $para->{type} =~ m/^heading/ )
		{
			$self->_heading ($para, $drw);
		}
		
		elsif ( $para->{type} eq "bullet list" )
		{
			$self->_bullet_list ($para, $drw);
		}
		
		elsif ( $para->{type} eq "number list" )
		{
			$self->_number_list ($para, $drw);
		}
		
		elsif ( $para->{type} eq "name list" )
		{
			$self->_name_list ($para, $drw);
		}
		
		elsif ( $para->{type} eq "table" )
		{
			$self->_table ($para, $drw);
		}
		
		elsif ( $para->{type} eq "source code" )
		{
			$self->_source_code ($para, $drw);
		}

		elsif ( $para->{type} eq "separator" )
		{
			$self->_separator ($para, $drw);
		}

		elsif ( $para->{type} eq "page_break" )
		{
			$self->_page_break ($para, $drw);
		}
		
		elsif ( $para->{type} eq "block" )
		{
			$self->_block ($para, $drw);
		}

		elsif ( $para->{type} eq "text" )
		{
			$self->_text ($para, $drw);
		}
	}
}

# ----------------------------------------------------------------------------
sub _heading
{
	my $self = shift;
	my $para = shift;
	my $drw  = shift;

	my ($level, $tag);
	
	# Get the heading level
	$level = $para->{level};

	if ( $level <= 6 ) { $tag = "h" . $level; }
	else               { $tag = "b"; }
	
	$drw->open ($tag);
	$drw->text ($para->{data});
	$drw->close ($tag);
}

# ----------------------------------------------------------------------------
sub _bullet_list
{
	my $self = shift;
	my $para = shift;
	my $drw  = shift;
	
	my $item;
	
	$drw->ul();
	for $item ( @{$para->{items}} )
	{
		$drw->li ($drw->text ($item->{data}));
	}
	$drw->_ul();
}


# ----------------------------------------------------------------------------
sub _number_list
{
	my $self = shift;
	my $para = shift;
	my $drw  = shift;

	# Use ol with start attribute 
	# Check to make sure numbers are consecutive. If not, don't
	# What if they're not consecutive?

	my $item;
	
	$drw->ol();
	for $item ( @{$para->{items}} )
	{
		$drw->li ($drw->text ($item->{data}));
	}
	$drw->_ol();
	
}

# ----------------------------------------------------------------------------
sub _name_list
{
	my $self = shift;
	my $para = shift;
	my $drw  = shift;
	
	my $item;
	
	for $item ( @{$para->{items}} )
	{
		my $text;
		$text = $drw->b ($drw->text($item->{name}));
		$text .= $drw->br_ ();
		$text .= $drw->text ($item->{data});
		
		$drw->blockquote ($drw->p ($text));
	}
}

# ----------------------------------------------------------------------------
sub _table
{
	my $self = shift;
	my $para = shift;
	my $drw  = shift;
	
	my ($row, $cell, $caption_style);

	$drw->table ({border=>"1"});
	if ( $para->{caption} ne "" )
	{
		if ( $para->{caption_position} eq "top" )
		{
			$caption_style = "caption-side: top;";
		}
		else
		{
			$caption_style = "caption-side: bottom;";
		}
		$drw->caption ({style=>$caption_style}, $para->{caption});
	}
	for $row ( @{$para->{rows}} )
	{
		$drw->tr();
		for $cell ( @{$row->{cells}} )
		{
			if ( $cell->{type} eq "heading" )
			{
				$drw->th ($drw->text($cell->{data}));
			}
			else
			{
				$drw->td ($drw->text($cell->{data}));
			}
		}
		$drw->_tr();
	}
	$drw->_table();
}

# ----------------------------------------------------------------------------
sub _source_code
{
	my $self = shift;
	my $para = shift;
	my $drw  = shift;
	
	my $line;
	
	$drw->pre ();
	for $line ( @{$para->{lines}} )
	{
		$drw->text ($line);
		$drw->br_();
	}
	$drw->_pre ();
}

# ----------------------------------------------------------------------------
sub _separator
{
	my $self = shift;
	my $para = shift;
	my $drw  = shift;
	
	$drw->hr_();
}

# ----------------------------------------------------------------------------
sub _page_break
{
	my $self = shift;
	my $para = shift;
	my $drw  = shift;
	
	$drw->hr_();
	$drw->hr_();
}

# ----------------------------------------------------------------------------
sub _block
{
	my $self = shift;
	my $para = shift;
	my $drw  = shift;
	
	$drw->blockquote ($drw->text($para->{data}));
}

# ----------------------------------------------------------------------------
sub _text
{
	my $self = shift;
	my $para = shift;
	my $drw  = shift;
	
	$drw->p ($drw->text($para->{data}));
}

# ============================================================================
return 1;
