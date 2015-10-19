# ============================================================================
package WebTK::Document::Kindle;

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

sub replace_stuff
{
	my $input = shift;
	$input =~ s/`/{html:&lsquo;}/g;
	$input =~ s/'/{html:&rsquo;}/g;
	$input =~ s/--/{html:&mdash;}/g;
	$input =~ s/\.\.\./{html:&hellip;}/g;
	return $input;
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

	# Fix quotes
	$self->{doc}->formatText (\&fixquote, "{html:&ldquo;}", "{html:&rdquo;}", );
	$self->{doc}->formatText (\&replace_stuff);
	
	# Draw the open wrapper, with style sheets
	my $title = $vars->{title};
	$self->_open_kindle ($title);
	
	# Draw each paragraph
	$self->_render_paragraphs ();

	# Finish
	$self->_close_kindle ();
	
	# Return the document string
	return $drw->draw ();
}


# ============================================================================
# INTERNAL METHODS
# ============================================================================

# ----------------------------------------------------------------------------
sub _open_kindle
{
	my $self = shift;
	my $title = shift;
	my $drw = $self->{drw};
	
	# I can put this back in if I need, but I'm not using it now.
	my $css = $self->_css();
	
	
	$drw->rawtext ("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n");
	$drw->rawtext ("<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">\n");
	
	$drw->html ();
	
    $drw->head ($drw->title ($title),
				$drw->meta ({"http-equiv"=>"Content-Type", 
							 "content"=>"text/html; charset=UTF8"}),
				$drw->style($drw->rawtext ($css)),
				$drw->rawtext ("\n"));

	
	$drw->body ();		
}

# ----------------------------------------------------------------------------
sub _close_kindle
{
	my $self = shift;
	my $drw = $self->{drw};
	
	$drw->rawtext ("\n");
	$drw->_body ();
	$drw->rawtext ("\n");
	$drw->_html ();
	$drw->rawtext ("\n");
}

# ----------------------------------------------------------------------------
sub _kindle_front
{
	my $self = shift;
	my $doc = $self->{doc};
	my $vars = $doc->{variables};
	my $paragraphs = $doc->{paragraphs};
	my $drw = $self->{drw};

	# Build the front matter for the kindle book - including table of contents
	my ($para, $class, $title, $author, $label);

	# Read variables
	my ($title, $subtitle, $author, $copyright);
	$title = $vars->{title};
	$subtitle = $vars->{subtitle};
	$author = $vars->{author};
	$copyright = $vars->{copyright};

	$drw->rawtext ("\n");
	
	# Cover image
	my $cover = $vars->{cover};
	if ( $cover ne "" )
	{
		$drw->div({id=>"cover"});
		$drw->rawtext("\n");
		$drw->center($drw->img_ ({src=>$cover, width=>500}));
		$drw->_div();
		$drw->rawtext ("\n<mbp:pagebreak />\n");
	}
	
	# First title page
	$drw->br_();
	$drw->br_();
	$drw->center ($drw->big($drw->text($title)));
	$drw->rawtext ("\n");
	if ( $subtitle ne "" )
	{
		$drw->center ($drw->text($subtitle));
		$drw->rawtext ("\n");
	}
	$drw->br_();
	$drw->br_();
	$drw->center ($drw->big($drw->text($author)));
	$drw->br_();
	$drw->br_();
	$drw->rawtext ("\n");

	my $imprint = $vars->{imprint};
	$drw->center($drw->img ({src=>$imprint}));
	$drw->rawtext ("\n<mbp:pagebreak />\n");
	
	# Full title page
	$drw->br_();
	$drw->br_();
	$drw->p({class=>"noind"},$drw->text($title));
	if ( $subtitle ne "" )
	{
		$drw->p({class=>"noind"},$drw->text($subtitle));
		$drw->rawtext ("\n");
	}
	$drw->br_();
	$drw->br_();
	$drw->p({class=>"noind"},$drw->text($author));
	$drw->rawtext ("\n");
	
	my @timeData = localtime(time);
	my $cpr;
	$cpr = "Copyright &copy; ";
	$cpr .= 1900+$timeData[5];
	$cpr .= " $author";
	$drw->p ({class=>"noind"},$cpr);
	$drw->rawtext ("\n");
	my $stmt;
	$stmt  = "All rights reserved. Printed in the United States of America.\n";
	$stmt .= "This publication is protected by copyright.\n";
	$drw->p ({class=>"noind"},$stmt);
	
	$drw->rawtext ("\n<mbp:pagebreak />\n");
	
	# Table of contents page
	$drw->div ({id=>"TOC"});
	$drw->br_();
	$drw->br_();
	$drw->center ($drw->big ($drw->text("Contents")));
	$drw->rawtext ("\n");
	
	for $para ( @$paragraphs )
	{
		if ( $para->{type} =~ m/^heading/ )
		{
			$class = "toc" . $para->{level};

			$label = $para->{data};
			$label =~ s/[ '.]//g;
			$label =~ s/{[^}]+}//g;
			
			$para->{label} = $label;
		
			$drw->p({class=>"noind"},
					$drw->a
					({href=>"#$label"}, 
					 $drw->text($para->{data})));
			$drw->rawtext ("\n");
		}
	}
	$drw->_div();
	$drw->rawtext("\n");
}

# ----------------------------------------------------------------------------
sub _render_paragraphs
{
	my $self = shift;
	my $doc = $self->{doc};
	my $vars = $doc->{variables};
	my $paragraphs = $doc->{paragraphs};
	my $drw = $self->{drw};
	my ($para, $first);

	# Prepare the front matter
	$self->_kindle_front ();
	
	# Process the paragraphs
	$first = 1;
	for $para ( @$paragraphs )
	{
		# Put a page break before headings
		# This is here so that it will come before the start
		# anchor for the first heading
		if ( $para->{type} =~ m/^heading/ )
		{
			if ( $para->{level} == 1 )
			{
				$drw->rawtext ("<mbp:pagebreak />\n");
			}
		}
		
		# Add the start mark
		if ( $first )
		{
			$drw->div ({id=>"start"});
			$drw->_div ();
			$first = 0;
		}
		
		# Draw the paragraph based on its type
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

		elsif ( $para->{type} eq "page break" )
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

		$drw->rawtext ("\n");
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

	if ( $level == 1 ) 
	{
		$tag = "h1";
	}
	elsif ( $level <= 6 ) 
	{ 
		$tag = "h" . $level; 
	}
	else
	{ 
		$tag = "b"; 
	}

	$drw->a({name=>"$para->{label}"},
			$drw->open ($tag),
			$drw->text ($para->{data}),
			$drw->close ($tag));
	
	if ( $level == 1 )
	{
		$drw->br_();
	}
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
	
	my ($row, $cell);
	
	# Don't forget table caption
	$drw->table ({border=>"1"});
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
	
	$drw->blockquote ();
	$drw->pre();
	$drw->rawtext ("\n");
	for $line ( @{$para->{lines}} )
	{
		$line =~ s/\s+$//;
		$drw->tt($drw->text ($line));
		$drw->rawtext ("\n");
	}
	$drw->_pre();
	$drw->_blockquote ();
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

	$drw->rawtext ("<mbp:pagebreak />\n");
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

# ----------------------------------------------------------------------------
sub _css
{
	my $self = shift;
	
	return <<EndCss;

h1 {
	text-align: left;
	text-indent: 0;
}
h2 {
	text-align: left;
	text-indent: 0;
}
h3 {
	text-align: left;
	text-indent: 0;
}
h4 {
	text-align: left;
	text-indent: 0;
}
h5 {
	text-indent: 0;
}
.noind {
	text-indent: 0;
}
.right {
	text-indent: 0;
	text-align: right;
}
.left {
	text-align: left;
}
.gray {
	color:#808080;
}
EndCss
}

# ============================================================================
return 1;
