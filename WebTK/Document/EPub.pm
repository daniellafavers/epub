# ============================================================================
package WebTK::Document::EPub;
use Cwd;

# ============================================================================
# DIRECTIVES
# ============================================================================
use strict;
use WebTK::Document::Hash;
use WebTK::Draw;
use POSIX;
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

	# Files to be created
	my (%files, %images);
	$self->{files} = \%files;
	
	$self->{doc} = $doc;
	$self->{varfcn} = undef;
	$self->{images} = \%images;
	
	$self->{stub} = 0; # Don't make files or run commands
	
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
	$input =~ s/`/{html:&#8212;}/g;
	$input =~ s/'/{html:&#8217;}/g;
	$input =~ s/--/{html:&#8212;}/g;
	$input =~ s/\.\.\./{html:&#8230;}/g;
	return $input;
}

# ----------------------------------------------------------------------------
sub clean_build
{
	my $self = shift;
	my $file = shift;
	
	my $file_path = $file->{file_path};
	my $cmd = "rm -rf $file_path";
	
	$self->run_cmd ($cmd, "");
}

# ----------------------------------------------------------------------------
sub make_directory
{
	my $self = shift;
	my $file = shift;
	
	my $file_path = $file->{file_path};
	my $cmd = "mkdir $file_path";
	
	$self->run_cmd ($cmd, "");
}

# ----------------------------------------------------------------------------
sub copy_file
{
	my $self = shift;
	my $file = shift;
	my $args = $file->{args};
	my $from = $args->[0];
	
	my $file_path = $file->{file_path};
	my $cmd = "cp $from $file_path";
	
	$self->run_cmd ($cmd, "");
}

# ----------------------------------------------------------------------------
sub opf_metadata
{
	my $self = shift;
	my $doc = $self->{doc};
	my $vars = $doc->{variables};
	my $drw = WebTK::Draw->new ();

	my %meta;
	my @fields;
	
	# Use alias to add dc: to tag names
	@fields = ("title","creator","subject","desccription","publisher",
		"contributor", "date", "type", "format", "identifier", "source",
		"language", "relation", "coverage", "rights");
	my $f;
	for $f ( @fields )
	{
		$drw->alias ($f, "dc:$f");
	}
	
	# Title
	$drw->nl ();
	
	$drw->title ($vars->{title});
	$drw->nl ();
	
	# Creator
	my (@name_parts, $fileas, $n, $i, $creator, $publisher);
	$creator = $vars->{author};
	$publisher = $vars->{publisher};
	if ( $publisher eq "" ) { $publisher = $creator; }
	if ( $creator eq "" ) { $creator = "Anonymous"; }
	@name_parts = split (/\s+/, $creator);
	$n = scalar (@name_parts);
	$fileas = $name_parts[$n-1];
	for ( $i=0; $i < $n-1; $i++ )
	{
		if ( $i == 0 ) { $fileas .= ","; }
		$fileas .= " $name_parts[$i]";
	}
	$drw->creator ({"opf:role"=>"aut","opf:file-as"=>$fileas},$creator);
	$drw->nl ();
	
	# Publisher
	$drw->publisher ($publisher);
	
	# Language
	$drw->language ("en-US");
	$drw->nl ();
	
	# Date
	# Seems that the colon in the time zone value is optional
	#YYYY-MM-DDThh:mm:ssTZD (eg 1997-07-16T19:20:30+01:00)
	my ($date, $timefmt);
	$timefmt = "%Y-%m-%d";
	$date = strftime ($timefmt, localtime);
	$drw->date ($date); # event attribute not allowed by validator
	$drw->nl ();

	# Identifier
	my $id = $vars->{book_id};
	my $id_auth = $vars->{book_id_auth};
	if ( $id == "" ) { $id = "0000"; }
	if ( $id_auth == "" ) { $id_auth = "NONE"; }
	$drw->identifier ({id=>"BookId"}, $id); # scheme attribute not allowed by validator
	$drw->nl ();

	# Rights - general copyright statement
	my $cp;
	$date = strftime ("%Y", localtime);
	$cp = "Copyright $date $creator";
	$drw->rights ($cp);
	$drw->nl ();

	# Cover image
	my $coverimg = $vars->{cover};
	if ( $coverimg ne "" )
	{
		my $base = $self->get_base_from_name ($coverimg);
		my $cover_img_id = $base . "_img";
		$drw->meta_ ({name=>"cover",content=>$cover_img_id});
		$drw->nl ();
	}
	
	return $drw->draw ();
}

sub get_name_from_path
{
	my $self = shift;
	my $path = shift;
	my $name;
	
	# Get the last item from the path
	my (@parts, $count);
	@parts = split /\//, $path;
	$count = scalar @parts;
	$name = $parts[$count-1];
	return $name;
}

sub get_mime_from_name
{
	my $self = shift;
	my $name = shift;
	my $ext;
	my %map;
	
	$map{"jpg"} = "image/jpeg";
	$map{"png"} = "image/png";
	$map{"svg"} = "image/svg+xml";
	
	($ext) = $name =~ m/.+\.(.+)/;
	
	if ( exists ($map{$ext}) )
	{
		return $map{$ext};
	}
	return "application/octet-stream";
}

sub get_base_from_name
{
	my $self = shift;
	my $name = shift;
	my $base;
	
	($base) = $name =~ m/(.+)\..+/;
	return $self->clean_name ($base);
}

sub opf_manifest
{
	my $self = shift;
	my $args = shift;
	my $doc = $self->{doc};
	my $vars = $doc->{variables};
	my $drw = WebTK::Draw->new ();
	my $paragraphs = $doc->{paragraphs};
	
	my $content = $args->[0];
	
	# Main book files
	$drw->nl (),
	my $book_filename;
	for $book_filename ( $self->get_book_filenames() )
	{
		my $base = $self->get_base_from_name ($book_filename);
		$drw->item_ ({id=>$base, href=>$book_filename, "media-type"=>$self->get_book_mime()});
		$drw->nl ();
	}
	
	my $name;
	for $name ( keys %{$self->{images}} )
	{
		my ($id, $mime);
		$id = $self->get_base_from_name ($name) . "_img";
		$mime = $self->get_mime_from_name ($name);
		$drw->nl ();
		$drw->item_ ({id=>$id, href=>"img/$name", "media-type"=>$mime});
	}
	

	# css
	$drw->nl ();
	my $cssname = $self->get_css_name ();
	my $cssid = $self->get_base_from_name ($cssname);
	$drw->item_ ({id=>$cssid, href=>"css/$cssname", "media-type"=>$self->get_css_mime()});
	
	# ncx
	$drw->nl ();
	my $ncxname = $self->get_ncx_name ();
	my $ncxid = $self->get_base_from_name ($ncxname);
	$drw->item_ ({id=>$ncxid, href=>$ncxname, "media-type"=>$self->get_ncx_mime()});
	
	# cover page
	if ( $vars->{cover} ne "" )
	{
		$drw->nl ();
		my $coverpg = $self->get_cover_page_name ();
		my $coverid = $self->get_base_from_name ($coverpg);
		$drw->item_ ({id=>$coverid, href=>$coverpg, "media-type"=>$self->get_book_mime()});
	}
	
	# title page
	$drw->nl ();
	my $titlepg = $self->get_title_page_name ();
	my $titleid = $self->get_base_from_name ($titlepg);
	$drw->item_ ({id=>$titleid, href=>$titlepg, "media-type"=>$self->get_book_mime()});
	
	# table of contents
	$drw->nl ();
	my $tocname = $self->get_toc_name ();
	my $tocid = $self->get_base_from_name ($tocname);
	$drw->item_ ({id=>$tocid, href=>$tocname, "media-type"=>$self->get_book_mime()});

	$drw->nl ();
	return $drw->draw ();
}

sub opf_spine
{
	my $self = shift;
	my $doc = $self->{doc};
	my $vars = $doc->{variables};
	my $drw = WebTK::Draw->new ();
	
	if ( $vars->{cover} ne "" )
	{
		$drw->nl ();
		my $coverpg = $self->get_cover_page_name ();
		my $coverid = $self->get_base_from_name ($coverpg);
		my %coverhash;
		if ( $vars->{kindle} eq "true" ) 
		{
			$coverhash{idref} = $coverid;
			$coverhash{linear} = "no";
		}
		else
		{
			$coverhash{idref} = $coverid;
		}
		$drw->itemref_ (\%coverhash);
	}
	
	$drw->nl ();
	my $titlepg = $self->get_title_page_name ();
	my $titleid = $self->get_base_from_name ($titlepg);
	$drw->itemref_ ({idref=>$titleid});
	
	$drw->nl ();
	my $toc = $self->get_toc_name ();
	my $tocid = $self->get_base_from_name ($toc);
	$drw->itemref_ ({idref=>$tocid});
	
	$drw->nl ();
	
	my $name;
	for $name ( $self->get_book_filenames() )
	{
		my $base = $self->get_base_from_name ($name);
		$drw->itemref_ ({idref=>$base});
		$drw->nl ();
	}
	
	return $drw->draw ();
}

sub opf_guide
{
	my $self = shift;
	my $doc = $self->{doc};
	my $vars = $doc->{variables};
	my $drw = WebTK::Draw->new ();
	
	$drw->nl ();
	my $covername = $self->get_cover_page_name ();
	my $coverid = $self->get_base_from_name ($covername);
	$drw->reference_ ({type=>"cover", title=>"Book Cover", href=>$covername});

	# This one seems to confuse the Kindle viewer - once you're on this
	# it wont navigate forward with the << or >> buttons
	
	#$drw->nl ();
	#my $title_name = $self->get_title_page_name();
	#my $title_id = $self->get_base_from_name ($title_name);
	#$drw->reference_ ({type=>"title-page", title=>"Title Page", href=>$title_name});
	
	$drw->nl ();
	my $tocname = $self->get_toc_name ();
	my $tocid = $self->get_base_from_name ($tocname);
	$drw->reference_ ({type=>"toc", title=>"Table of Contents", href=>$tocname});
	
	# Make a guide reference only to the first item
	$drw->nl ();
	my @book_filenames = $self->get_book_filenames();
	my $book = $book_filenames[0];
	$drw->reference_ ({type=>"text", title=>"Text", href=>$book});

	$drw->nl ();
	return $drw->draw ();
}

sub make_opf
{
	my $self = shift;
	my $file = shift;
	my $args = $file->{args};
	my $drw = $file->{drw};
	
	my $ncxname = $self->get_ncx_name ();
	my $ncxid = $self->get_base_from_name ($ncxname);
	
	$drw->rawtext ("<?xml version=\"1.0\"?>\n");
	$drw->package
		(
		 {"version"=>"2.0", "xmlns"=>"http://www.idpf.org/2007/opf", "unique-identifier"=>"BookId"},

		 $drw->rawtext ("\n\n"),
		 $drw->metadata (
			 {"xmlns:dc"=>"http://purl.org/dc/elements/1.1/", "xmlns:opf"=>"http://www.idpf.org/2007/opf"},
			 $self->opf_metadata($args)
		 ),
		 
		 $drw->rawtext ("\n\n"),
		 $drw->manifest ($self->opf_manifest($args)),
		 
		 $drw->rawtext ("\n\n"),
		 $drw->spine ({toc=>$ncxid}, $self->opf_spine($args)),
		 
		 $drw->rawtext ("\n\n"),
		 $drw->guide ($self->opf_guide($args)),
		 $drw->rawtext ("\n\n"),
		);
	
	$self->store_file ($file);
}

# ----------------------------------------------------------------------------
sub make_ebook
{
	my $self = shift;
	my $file = shift;
	my $doc = $self->{doc};
	my $args = $file->{args};
	my $drw = $file->{drw};
	my $book_filename = $args->[0];
	
	$self->render_paragraphs ($drw, $book_filename);
	$self->store_file ($file);
}

# ----------------------------------------------------------------------------
sub make_css
{
	my $self = shift;
	my $file = shift;
	my $doc = $self->{doc};
	my $vars = $doc->{variables};
	my $args = $file->{args};
	my $drw = $file->{drw};

	my $css;
	if ( $vars->{css} ne "" )
	{
		my $file = $vars->{css};
		
		my (@lines);
		open (CSS, "<$file") or die "Unable to open $file: $!";
		@lines = <CSS>;
		chomp @lines;
		close CSS;
		$css = join "\n", @lines;
	}
	else
	{
		$css = &default_css;
	}
	
	my @css_lines = split /\n/, $css;
	my $c;
	
	for $c ( @css_lines )
	{
		$drw->rawtext ("$c\n");
	}

	$self->store_file ($file);
}

# ----------------------------------------------------------------------------
sub default_css
{
	my $css;
	
	my $css;
	$css = <<EOT;
h1
{
	text-align: center;
	font-size: 20pt;
	border-bottom: 2px solid black;
	margin-top: 65px;
	margin-bottom: 30px;
	page-break-before : always;
}

h2
{
	border-bottom : 2px solid black;
	margin-top : 40px;
} 

h3
{
	border-bottom : 2px solid black;
	margin-top : 30px;
	font-weight: bold;
	text-indent : 30px;
}

h4
{
	border-bottom : 2px solid black;
	margin-top : 30px;
	font-weight: bold;
	font-style: italic;
	text-indent : 30px;
}

h5
{
	border-bottom : 2px solid black;
	margin-top : 30px;
	font-weight: italic;
	text-indent : 30px;
}

h6
{
	border-bottom : 2px solid black;
	margin-top : 30px;
	text-indent : 30px;
	font-style: italic;
}

h1.part
{
	text-align : center;
	margin-top: 30px;
}

p
{
	text-indent : 30px;
	margin-top : 2px;
	margin-bottom : 2px;
	font-family : serif;
	font-size : 12pt;
}

p.block
{
	text-indent: 0;
	margin-left: 10px;
	margin-right: 10px;
	margin-top: 10px;
	margin-bottom: 10px;
	font-size: 8pt;
}

div.toc
{
	font-family : serif;
	font-size : 10pt;	
	margin-top : 1px;
	margin-bottom : 1px;
	margin-left : 5px;
}

div.toc_part
{
	font-family : serif;
	font-size : 10pt;	
	margin-top : 1px;
	margin-bottom : 1px;
	margin-left : 5px;
}

div.toc a
	div.toc_part a
{
	text-decoration : none;
}

pre.code
{
	margin-left : 30px;
}

p.title
{
	width : 60%;
	font-family : serif;
	font-style : italic;
	font-size : 24pt;
	text-align : center;
	margin-bottom : 100px;
	margin-left : auto;
	margin-right : auto;
}

p.subtitle
{
	width : 60%;
	border-top : 1pxs olid black;
	border-bottom : 1px solid black;
	font-family : serif;
	font-size : 16pt;
	text-align : center;
	margin-bottom : 100px;
	font-style : italic;
	padding : 0;
	text-align : center;
	margin-left : auto;
	margin-right : auto;
}

p.title_note
{
	text-indent : 0;
	margin-left: 0;
	margin-right: 0;
	margin-top: 50px;
	font-family : serif;
	font-size: 10pt;
	font-style : italic;
}

p.center
{
	text-align: center;
}

div.imprintimg
{
	text-align: center;
	width : 80%;
}

div.titlepg
{
	font-size : 10pt;
	margin-left : 30px;
}

div.titlepg p
{
	text-indent : 0;
	font-family : serif;
	font-size: 10pt;
}

div.cover img
{
    display: block;
	margin-left : auto;
	margin-right : auto;
	text-align : center;
}
EOT
return $css;	
}

# ----------------------------------------------------------------------------
sub make_ncx
{
	my $self = shift;
	my $file = shift;
	my $doc = $self->{doc};
	my $vars = $doc->{variables};
	my $args = $file->{args};
	my $drw = $file->{drw};
	
	$drw->alias ("tx", "text");
	
	my $book_id = $vars->{book_id};
	my $title = $vars->{title};
	my $author = $vars->{author};
	
	my $navmap = $drw->open ("navMap", "The Map");
	
	$drw->ncx (
		{xmlns=>"http://www.daisy.org/z3986/2005/ncx/",
		 version=>"2005-1",
		 "xml:lang"=>"en-US"},
		$drw->nl (),
		$drw->head (
			$drw->nl (),
			$drw->meta_({name=>"dtb:uid",content=>$book_id}),
			$drw->nl (),
			$drw->meta_({name=>"dtb:depth",content=>"1"}),
			$drw->nl (),
			$drw->meta_({name=>"dtb:totalPageCount",content=>"0"}),
			$drw->nl (),
			$drw->meta_({name=>"dtb:maxPageNumber",content=>"0"}),
			$drw->nl (),
		),
		$drw->nl (),
		$drw->docTitle ($drw->tx ($title)),
		$drw->nl (),
		$drw->docAuthor ($drw->tx ($author)),
		$drw->nl (),
		$self->build_navmap (),
		$drw->nl (),
		);

	$self->store_file ($file);
}

# ----------------------------------------------------------------------------
sub make_toc
{
	my $self = shift;
	my $file = shift;
	my $doc = $self->{doc};
	my $args = $file->{args};
	my $drw = $file->{drw};

	my $paragraphs = $doc->{paragraphs};
	my $cssname = $self->get_css_name ();
	
	$self->open_xhtml ($drw);
	$drw->head ();
	$drw->title ("Table of Contents");
	$drw->nl ();
	$drw->link_ ({rel=>"styleSheet", href=>"css/$cssname", type=>"text/css"});
	$drw->_head ();
	$drw->nl ();
	$drw->body (
		$drw->nl (),
		$drw->h1 ("Table of Contents"),
		$drw->nl(),
		$self->build_toc ()
		);

	$drw->nl ();
	$drw->_html ();
	
	$self->store_file ($file);
}

# ----------------------------------------------------------------------------
sub make_cover_page
{
	my $self = shift;
	my $file = shift;
	my $doc = $self->{doc};
	my $args = $file->{args};
	my $drw = $file->{drw};
	my $cover_image = $args->[0];
	
	my $cssname = $self->get_css_name ();

	$self->open_xhtml ($drw);
	$drw->head ();
	$drw->title ("Cover Page");
	$drw->nl ();
	$drw->link_ ({rel=>"styleSheet", href=>"css/$cssname", type=>"text/css"});
	$drw->_head ();
	$drw->nl ();
	$drw->body ();
	$drw->nl ();
	$drw->div ({class=>"cover"}, $drw->img_ ({src=>$cover_image, alt=>"Cover Image"}));
	$drw->nl ();
	$drw->_body ();
	$drw->nl ();
	$drw->_html ();
	
	$self->store_file ($file);
}

# ----------------------------------------------------------------------------
sub make_title_page
{
	my $self = shift;
	my $file = shift;
	my $doc = $self->{doc};
	my $vars = $doc->{variables};
	my $args = $file->{args};
	my $drw = $file->{drw};

	my $cssname = $self->get_css_name ();
	
	$self->open_xhtml ($drw);
	$drw->head ();
	$drw->title ("Title Page");
	$drw->nl ();
	$drw->link_ ({rel=>"styleSheet", href=>"css/$cssname", type=>"text/css"});
	$drw->_head ();
	$drw->nl ();
	$drw->body ();
	$drw->div ();
	$drw->nl ();
	
	my $author = $vars->{author};
	my $publisher = $vars->{publisher};
	if ( $publisher eq "" ) { $publisher = $author; }

	my $title = $vars->{title};
	if ( $title eq "" ) { $title = "No Title"; }
	$drw->p ({class=>"title"}, $drw->text ($title));
	$drw->nl ();
	
	my $subtitle = $vars->{subtitle};
	if ( $subtitle ne "" )
	{
		$drw->p ({class=>"subtitle"}, $drw->text ($subtitle));
		$drw->nl ();
	}
	
	my $imprint = $vars->{imprint};
	if ( $imprint ne "" )
	{
		$drw->div ({class=>"imprint"},
				   $drw->img_ ({src=>"img/$imprint",alt=>"[$publisher - imprint]"}));
		$drw->nl ();	
	}

	$drw->nl ();	

	# Copyright stuff
	$drw->div ({class=>"titlepg"});
	
	$drw->nl ();
	$drw->p ($drw->b($title));
	if ( $subtitle ne "" ) { $drw->p ($drw->b ($subtitle)); }

	my ($date, $timefmt);
	$timefmt = "%Y";
	$date = strftime ($timefmt, localtime);
	$drw->p ("Copyright &copy; $date $author");
	$drw->nl ();
	$drw->_div ();

	my $title_page_note = $vars->{title_page_note};
	if ( $title_page_note ne "" )
	{
		$drw->p ({class=>"title_note"},$title_page_note);
	}
	
	$drw->nl ();
	$drw->_div ();
	$drw->_body ();
	$drw->nl ();
	$drw->_html ();
	
	$self->store_file ($file);
}

# ----------------------------------------------------------------------------
sub mimetype
{
	my $self = shift;
	my $file = shift;
	my $drw = $file->{drw};
	
	$drw->text ($self->get_ebook_mime());
	$self->store_file ($file);
}

# ----------------------------------------------------------------------------
sub make_container
{
	my $self = shift;
	my $file = shift;
	my $doc = $self->{doc};
	my $args = $file->{args};
	my $drw = $file->{drw};
	my $content = $args->[0];
	
	my $opfname = $self->get_opf_name ();
	
	$drw->rawtext ("<?xml version=\"1.0\"?>\n");
	$drw->container (
		{version=>"1.0",xmlns=>"urn:oasis:names:tc:opendocument:xmlns:container"},
		$drw->nl (),
		$drw->rootfiles
		(
		 $drw->nl (),
		 $drw->rootfile_ ({"full-path"=>"$content/$opfname",
						   "media-type"=>$self->get_opf_mime()}),
		 $drw->nl ()
		 ),
		$drw->nl ()
		);

	$self->store_file ($file);
}

# ----------------------------------------------------------------------------
sub make_epub
{
	my $self = shift;
	my $file = shift;
	
	my $doc = $self->{doc};
	my $args = $file->{args};
	my $drw = $file->{drw};
	my $metadata_dir = $args->[0];
	my $content_dir = $args->[1];
	my $file_path = $file->{rel_path};

	my $vars = $self->{vars};
	my $root = $vars->{epub_buildroot};
	my $book = $vars->{epub_bookroot};
	
	my $cmd;
	
	# These will cd to the book root dir before running command
	
	$cmd = "rm -f ../$file_path";
	$self->run_cmd ($cmd, $book);
	
	$cmd = "zip -X ../$file_path mimetype";
	$self->run_cmd ($cmd, $book);
	
	$cmd = "zip -rg ../$file_path $metadata_dir";
	$self->run_cmd ($cmd, $book);

	$cmd = "zip -rg ../$file_path $content_dir";
	$self->run_cmd ($cmd, $book);
}

# ----------------------------------------------------------------------------
sub collect_images
{
	my $self = shift;
	my $doc = $self->{doc};
	my $vars = $doc->{variables};
	my $paragraphs = $doc->{paragraphs};

	my $images = $self->{images};
	my $imglist = $vars->{images};

	# There can only be one images with a given name.
	# The hash is name=>path.
	
	# From the image list variable
	print "Image list is $imglist\n";
	if ( $imglist ne "" )
	{
		my ($i, @images, $imgitems, $name, $id, $mime);
		@images = split (/,\s*/, $imglist);
		for $i ( @images )
		{
			my $name = $self->get_name_from_path ($i);
			$images->{$name} = $i;
			print "Collecting from list $name => $i\n";
		}
	}
	
	# Get images from the paragraphs
	my $para;
	for $para ( @$paragraphs )
	{
		my ($name, $id, $name, $mime);
		if ( $para->{type} eq "image" )
		{
			$name = $self->get_name_from_path ($para->{data});
			$images->{$name} = $para->{data};
			print "Collecting from paragraphs $name => $para->{data}\n";
		}
	}
}

# ----------------------------------------------------------------------------
sub render
{
	my $self = shift;
	my $doc = $self->{doc};
	
	my ($vars, $pars);
	$vars = $doc->{variables};
	$pars = $doc->{paragraphs};

	my $showvars = 0;
	if ( $showvars )
	{
		my $v;
		print "===== Vars =====\n";
		for $v ( keys %$vars )
		{
			print "$v = $vars->{$v}\n";
		}
		print "================\n";
	}

	# Set book filenames
	$self->set_book_filenames ();
	
	# Collect all unique images
	$self->collect_images ();
	
	# Give identifiers to all the heading paragraphs
	$self->set_heading_names ();
	
	# Get the file name from the variables
	my $filename = $self->get_file_name ();
	
	# Fix quotes
	$self->{doc}->formatText (\&fixquote, "{html:&#8220;}", "{html:&#8221;}", );
	$self->{doc}->formatText (\&replace_stuff);

	# Get the location of the build directory
	my $root = $self->getvar (".", "epub_buildroot");
	my $book = "$root/ebook";
	$self->{vars}->{epub_buildroot} = $root;
	$self->{vars}->{epub_bookroot} = $book;
	
	# Make directories
	my ($metadata, $content);
	$metadata = "META-INF";
	$content = "OEBPS";
	
	$self->add_file ("", \&clean_build);
	$self->add_file ("", \&make_directory);
	
	$self->add_file ("mimetype", \&mimetype);
	$self->add_file ($metadata, \&make_directory);
	$self->add_file ($content, \&make_directory);
	$self->add_file ("$content/img", \&make_directory);
	$self->add_file ("$content/css", \&make_directory);

	my $name;
	for $name ( keys %{$self->{images}} )
	{
		$self->add_file ("$content/img/$name", \&copy_file, $self->{images}->{$name});
	}
	
	my $ops_package_name = $self->get_opf_name();
	$self->add_file ("$content/$ops_package_name", \&make_opf, $content);
	
	# Add all of the main content files
	my @content_files = $self->get_book_filenames ();
	my $main_content;
	for $main_content ( @content_files )
	{
		$self->add_file ("$content/$main_content", \&make_ebook, $main_content);
	}
	
	my $css = $self->get_css_name ();
	$self->add_file ("$content/css/$css", \&make_css);
	
	my $ncx = $self->get_ncx_name ();
	$self->add_file ("$content/$ncx", \&make_ncx);
	
	if ( $vars->{cover} ne "" )
	{
		my $coverpg = $self->get_cover_page_name ();
		my $coverimg = $vars->{cover};
		$self->add_file ("$content/$coverpg", \&make_cover_page, "img/$coverimg");
	}
	
	my $titlepg = $self->get_title_page_name ();
	$self->add_file ("$content/$titlepg", \&make_title_page);
	
	my $toc = $self->get_toc_name ();
	$self->add_file ("$content/$toc", \&make_toc);
	
	my $container = $self->get_container_name ();
	$self->add_file ("$metadata/$container", \&make_container, $content);

	$self->add_file ($filename, \&make_epub, $metadata, $content);
	
	#$self->add_file ("", \&clean_build);
	
	# Render all the files
	my $f;
	for $f ( sort keys %{$self->{files}} )
	{
		my $file = $self->{files}->{$f};
		
		# Call the render function
		&{$file->{render_fcn}} ($self, $file);
	}
	
	# Done - return the filename
	return $filename;
}

# ----------------------------------------------------------------------------
# Clean the filename
sub clean_name
{
	my $self = shift;
	my $name = shift;
	$name =~ s/[ '.-]//g;
	return lc $name;
}

# ----------------------------------------------------------------------------
sub get_opf_name
{
	my $self = shift;
	my $name;
	$name = "content.opf";
	return $name;
}

# ----------------------------------------------------------------------------
sub get_opf_mime
{
	my $self = shift;
	my $mime;
	$mime = "application/oebps-package+xml";
	return $mime;
}

# ----------------------------------------------------------------------------
sub get_book_filenames
{
	my $self = shift;
	my $doc = $self->{doc};
	my $paragraphs = $doc->{paragraphs};
	my ($para, %book_filenames);
	
	for $para ( @$paragraphs )
	{
		$book_filenames{$para->{book_filename}} = 1;
	}
	return sort keys %book_filenames;
}

# ----------------------------------------------------------------------------
sub get_book_mime
{
	my $self = shift;
	my $mime;
	$mime = "application/xhtml+xml";
	return $mime;
}

# ----------------------------------------------------------------------------
sub get_file_name
{
	my $self = shift;
	my $name;
	my $doc = $self->{doc};
	my $vars = $doc->{variables};
	if ( $vars->{kindle} eq "true" )
	{
		$name = $self->get_base_name () . "_kindle.epub";
	}
	else
	{
		$name = $self->get_base_name () . ".epub";
	}
	return $name;
}
	
# ----------------------------------------------------------------------------
sub get_ncx_name
{
	my $self = shift;
	my $name;
	$name = "nav.ncx";
	return $name;
}
	
# ----------------------------------------------------------------------------
sub get_ncx_mime
{
	my $self = shift;
	my $mime;
	$mime = "application/x-dtbncx+xml";
	return $mime;
}
	
# ----------------------------------------------------------------------------
sub get_css_name
{
	my $self = shift;
	my $name;
	$name = "stylesheet.css";
	return $name;
}

# ----------------------------------------------------------------------------
sub get_css_mime
{
	my $self = shift;
	my $mime;
	$mime = "text/css";
	return $mime;
}

# ----------------------------------------------------------------------------
sub get_toc_name
{
	my $self = shift;
	my $name;
	$name = "toc.xhtml";
	return $name;
}

# ----------------------------------------------------------------------------
sub get_title_page_name
{
	my $self = shift;
	my $name;
	$name = "title_page.xhtml";
	return $name;
}

# ----------------------------------------------------------------------------
sub get_container_name
{
	my $self = shift;
	my $name;
	$name = "container.xml";
	return $name;
}

# ----------------------------------------------------------------------------
sub get_ebook_mime
{
	my $self = shift;
	my $mime;
	$mime = "application/epub+zip";
	return $mime;
}

# ----------------------------------------------------------------------------
sub get_cover_page_name
{
	my $self = shift;
	my $name;
	$name = "cover.xhtml";
	return $name;
}

# ----------------------------------------------------------------------------
sub get_base_name
{
	my $self = shift;
	my $doc = $self->{doc};
	my $vars = $doc->{variables};
	my $name;

	$name = $self->getvar ("ebook", "epub_filename","title","load_file");
	$name =~ s/\..+//;
	$name = $self->clean_name ($name);
	$vars->{epub_filename} = $name;
	return $name;
}

# ----------------------------------------------------------------------------
sub open_xhtml
{
	my $self = shift;
	my $drw = shift;
	
	$drw->rawtext ("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
	$drw->rawtext ("<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\" \"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">");
	$drw->nl ();
	$drw->html ({xmlns=>"http://www.w3.org/1999/xhtml", "xml:lang"=>"en-US"});
}

# ----------------------------------------------------------------------------
sub set_document_files
{
	my $self = shift;
	my $doc = $self->{doc};
	my $paragraphs = $doc->{paragraphs};
	
}

# ----------------------------------------------------------------------------
sub open_book_file
{
	my $self = shift;
	my $drw = shift;
	my $title = shift;
	my $cssname = shift;
	
	$self->open_xhtml ($drw);
	$drw->nl ();
	
	$drw->head ();
	$drw->nl ();
	$drw->title($title);
	$drw->nl ();
	$drw->link_ ({rel=>"styleSheet", href=>"css/$cssname", type=>"text/css"});
	$drw->nl ();
	$drw->_head ();
	$drw->nl ();
	
	$drw->body ();
	$drw->nl ();
}

# ----------------------------------------------------------------------------
sub close_book_file
{
	my $self = shift;
	my $drw = shift;

	$drw->nl();
	$drw->_body (); 
	$drw->nl ();
	$drw->_html ();
}

# ----------------------------------------------------------------------------
sub set_book_filenames
{
	my $self = shift;
	my $doc = $self->{doc};
	my $paragraphs = $doc->{paragraphs};
	my ($para, $base, $count, $fname);
	
	$base = $self->get_base_name ();
	$count = 0;
	$fname = sprintf ("%s_%03d.xhtml", $base, $count);
		
	for $para ( @$paragraphs )
	{
		# Advance to a new book file on each major heading
		if ( $para->{type} =~ m/^heading/ )
		{
			if ( $para->{level} == 1 )
			{
				$count++;
				$fname = sprintf ("%s_%03d.xhtml", $base, $count);
			}
		}
		
		$para->{book_filename} = $fname;
	}
}

# ----------------------------------------------------------------------------
sub render_paragraphs
{
	my $self = shift;
	my $drw = shift;
	my $book_filename = shift;
	my $doc = $self->{doc};
	my $vars = $doc->{variables};
	my $paragraphs = $doc->{paragraphs};
	my $para;

	# Open
	my $title = $drw->text ($vars->{title});

	my $cssname = $self->get_css_name ();
	my $book_file = "";
	
	# Process the paragraphs
	$self->open_book_file ($drw, $title, $cssname);
	
	if ( $self->{stub} )
	{
		$drw->text ("STUB OF BOOK");
	}
	else
	{
		for $para ( @$paragraphs )
		{
			# Only include paragraphs for this book
			next if ( $book_filename ne $para->{book_filename} );
			
			# Draw the paragraph based on its type
			if ( $para->{type} =~ m/^heading/ )
			{
				$self->heading ($para, $drw);
			}
			
			elsif ( $para->{type} eq "part" )
			{
				$self->part ($para, $drw);
			}
			
			elsif ( $para->{type} eq "navpoint" )
			{
				$self->navpoint ($para, $drw);
			}
			
			elsif ( $para->{type} eq "image" )
			{
				$self->image ($para, $drw);
			}
			
			elsif ( $para->{type} eq "bullet list" )
			{
				$self->bullet_list ($para, $drw);
			}
			
			elsif ( $para->{type} eq "number list" )
			{
				$self->number_list ($para, $drw);
			}
			
			elsif ( $para->{type} eq "name list" )
			{
				$self->name_list ($para, $drw);
			}
			
			elsif ( $para->{type} eq "table" )
			{
				$self->table ($para, $drw);
			}
			
			elsif ( $para->{type} eq "source code" )
			{
				$self->source_code ($para, $drw);
			}
			
			elsif ( $para->{type} eq "separator" )
			{
				$self->separator ($para, $drw);
			}
			
			elsif ( $para->{type} eq "page break" )
			{
				$self->page_break ($para, $drw);
			}
			
			elsif ( $para->{type} eq "block" )
			{
				$self->block ($para, $drw);
			}
			
			elsif ( $para->{type} eq "text" )
			{
				$self->text ($para, $drw);
			}		

			elsif ( $para->{type} eq "text" )
			{
				$self->text ($para, $drw);
			}		
			
			elsif ( $para->{type} eq "center" )
			{
				$self->center ($para, $drw);
			}		
			
			else
			{
				$self->text ($para, $drw);
			}
			
			$drw->nl ();
		}
	}

	$self->close_book_file ($drw);
}

# ----------------------------------------------------------------------------
sub heading
{
	my $self = shift;
	my $para = shift;
	my $drw  = shift;

	my ($level, $tag);
	
	# Get the heading level
	$level = $para->{level};
	
	if ( $level <= 6 ) 
	{ 
		$tag = "h" . $level; 
	}
	else
	{ 
		$tag = "div"; 
	}

	$drw->open ($tag, {id=>$para->{id}}, $drw->text ($para->{data}));
}

# ----------------------------------------------------------------------------
sub part
{
	my $self = shift;
	my $para = shift;
	my $drw  = shift;

	my ($level, $tag);
	
	$drw->h1 ({class=>"part", id=>$para->{id}}, $drw->text ($para->{data}));
	$drw->nl ();
}

# ----------------------------------------------------------------------------
sub navpoint
{
	my $self = shift;
	my $para = shift;
	my $drw  = shift;
	
	# Draw an empty paragraph with this id
	$drw->p_ ({id=>$para->{id}});
	$drw->nl ();
}

# ----------------------------------------------------------------------------
sub image
{
	my $self = shift;
	my $para = shift;
	my $drw  = shift;
	
	my ($name);
	
	$name = $self->get_name_from_path ($para->{data});
	$drw->div ({style=>"text-align:center;"},$drw->img_ ({src=>"img/$name", alt=>"img"}));
}

# ----------------------------------------------------------------------------
sub bullet_list
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
sub number_list
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
sub name_list
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
sub table
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
sub source_code
{
	my $self = shift;
	my $para = shift;
	my $drw  = shift;
	
	my $line;
	
	$drw->pre({class=>"code"});
	$drw->nl ();
	for $line ( @{$para->{lines}} )
	{
		$line =~ s/\s+$//;
		$drw->tt($drw->text ($line));
		$drw->nl ();
	}
	$drw->_pre();
}

# ----------------------------------------------------------------------------
sub separator
{
	my $self = shift;
	my $para = shift;
	my $drw  = shift;
	
	$drw->hr_();
}

# ----------------------------------------------------------------------------
sub page_break
{
	my $self = shift;
	my $para = shift;
	my $drw  = shift;

	$drw->p_ ({style=>"page-break-before:always;"});
}

# ----------------------------------------------------------------------------
sub block
{
	my $self = shift;
	my $para = shift;
	my $drw  = shift;
	
	$drw->p({class=>"block"},$drw->text($para->{data}));
}

# ----------------------------------------------------------------------------
sub text
{
	my $self = shift;
	my $para = shift;
	my $drw  = shift;
	
	$drw->p ($drw->text($para->{data}));
}

# ----------------------------------------------------------------------------
sub center
{
	my $self = shift;
	my $para = shift;
	my $drw  = shift;
	
	$drw->p ({class=>"center"},$drw->text($para->{data}));
}

# ----------------------------------------------------------------------------
sub getvar
{
	my $self = shift;
	my $default = shift;
	my $doc = $self->{doc};
	my $vars = $doc->{variables};
	my @names = @_;
	my $n;
	for $n ( @_ )
	{
		if ( exists ($vars->{$n}) )
		{
			return $vars->{$n};
		}
	}
	return $default;
}

# ----------------------------------------------------------------------------
sub add_file
{
	my $self = shift;
	my $rel_path = shift;
	my $render_fcn = shift;
	my @args = @_;

	my $vars = $self->{vars};
	my $root = $vars->{epub_bookroot};
	
	my %newfile;
	
	$newfile{rel_path} = $rel_path;
	$newfile{file_path} = "$root/$rel_path";
	$newfile{render_fcn} = $render_fcn;
	$newfile{args} = \@args;
	$newfile{drw} = WebTK::Draw->new ();
	
	my ($count, $index);
	$count = scalar (keys %{$self->{files}});
	$index = sprintf ("%05d", $count);
	$self->{files}->{$index} = \%newfile;
}

# ----------------------------------------------------------------------------
sub store_file
{
	my $self = shift;
	my $file = shift;
	
	my $file_path = $file->{file_path};
	my $drw = $file->{drw};

	if ( $self->{stub} )
	{
		print "\nGenerating $file_path\n";
		print "--- Content of $file_path ---\n";
		print $drw->draw();
		print "\n---\n";
		return;
	}
	
	if ( open (EPUB_FILE, ">$file_path") )
	{
		print "Making file $file_path\n";
		print EPUB_FILE $drw->draw ();
		close EPUB_FILE;
	}
	else
	{
		print "Error opening $file_path\n";
		exit (1);
	}
}

# ----------------------------------------------------------------------------
sub run_cmd
{
	my $self = shift;
	my $cmd = shift;
	my $dir = shift;
	my @c = split /\s+/, $cmd;
	
	print "Run command: $cmd";
	if ( $dir ne "" )
	{
		print " in $dir";
	}
	print "\n";
	if ( $self->{stub} == 0 )
	{
		my $curdir;
		if ( $dir ne "" )
		{
			$curdir = getcwd();
			chdir $dir;
		}
		
		my $status = system (@c);
		if ( $status != 0 )
		{
			print "Error running \"$cmd\"\n";
			exit (1);
		}
		
		if ( $curdir ne "" )
		{
			chdir $curdir;
		}
	}
}

# ----------------------------------------------------------------------------
sub set_heading_names
{
	my $self = shift;
	my $doc = $self->{doc};
	my $paragraphs = $doc->{paragraphs};
	
	my ($para, $count, $id);
	$count = 0;
	for $para ( @$paragraphs )
	{
		if ( $para->{type} =~ m/^heading/ )
		{
			$count = $count + 1;
			$id = sprintf ("h%d", $count);
			$para->{id} = $id;
		}
		elsif ( $para->{type} eq "part" )
		{
			$count = $count + 1;
			$id = sprintf ("p%d", $count);
			$para->{id} = $id;
		}
		elsif ( $para->{type} eq "navpoint" )
		{
			$count = $count + 1;
			$id = sprintf ("nav%d", $count);
			$para->{id} = $id;
		}
	}
}

# ----------------------------------------------------------------------------
sub build_navmap
{
	my $self = shift;
	my $doc = $self->{doc};
	my $paragraphs = $doc->{paragraphs};
	
	my $drw = WebTK::Draw->new ();

	$drw->navMap ();
	$drw->nl ();
	
	my $cover = $self->get_cover_page_name ();
	my $title_page = $self->get_title_page_name ();
	my $toc_page = $self->get_toc_name ();
	
	$self->add_navpoint ($drw, 1, "Cover", "", $cover);
	$self->add_navpoint ($drw, 1, "Title Page", "", $title_page);
	$self->add_navpoint ($drw, 1, "Table of Contents", "", $toc_page);
	
	my ($para, $level, $text, $id, $bookname);
	for $para ( @$paragraphs )
	{
		$bookname = $para->{book_filename};
		if ( $para->{type} =~ m/^heading/ )
		{
			$level = $para->{level};
			$text = $drw->text ($para->{data});
			
			$text =~ s/&rsquo;/'/;
			
			$id = $para->{id};
			$self->add_navpoint ($drw, $level, $text, $id, $bookname);
		}
		elsif ( $para->{type} eq "part" || $para->{type} eq "navpoint" )
		{
			$text = $drw->text ($para->{data});
			$id = $para->{id};
			$self->add_navpoint ($drw, 1, $text, $id, $bookname);
		}
	}
	$self->add_navpoint ($drw, 1, "/last/", "", "");
	
	$drw->_navMap ();
	return $drw->draw ();
}
	
# ----------------------------------------------------------------------------
sub pad
{
	my $self = shift;
	my $lvl = shift;

	my ($pad, $sp, $s);
	$pad = "    ";
	for ($s=0; $s < $lvl-1; $s++ ) { $sp .= $pad; }
	
	return $sp;
}

sub nav_open
{
	my $self = shift;
	my $drw = shift;
	my $lvl = shift;
	my $txt = shift;
	my $id = shift;
	my $file = shift;
	
	my $play_order = $self->{nav_playorder};
	
	$drw->rawtext ($self->pad($lvl));
	
	if ( $id eq "nolink" )
	{
		$drw->navPoint ({class=>"h$lvl", playOrder=>$play_order});
	}
	else
	{
		$drw->navPoint ({class=>"h$lvl", id=>$id, playOrder=>$play_order});
	}
	$drw->nl (),
	
	$drw->rawtext ($self->pad($lvl+1));
	$drw->navLabel ($drw->open ("text", $txt));
	$drw->nl (),
	
	$drw->rawtext ($self->pad($lvl+1));
	my $link = $file;
	if ( $id ne "" ) { $link .= "#$id"; }
	$drw->content_ ({src=>$link});
	$drw->nl ();
}

sub nav_close
{
	my $self = shift;
	my $drw = shift;
	my $lvl = shift;

	$drw->rawtext ($self->pad($lvl));
	$drw->_navPoint ();
	$drw->nl ();
}

sub add_navpoint
{
	my $self = shift;
	my $drw = shift;
	my $lvl = shift;
	my $txt = shift;
	my $id = shift;
	my $file = shift;
	
	my ($cur, $l);
	
	if ( ! exists ($self->{cur_nav_level}) )
	{
		$self->{cur_nav_level} = 0;
		$self->{nav_playorder} = 0;
	}
	$cur = $self->{cur_nav_level};

	# Close previous
	if ( $lvl <= $cur )
	{
		for ($l=$cur; $l>=$lvl; $l--)
		{
			$self->nav_close ($drw, $l);
		}
	}
	
	$self->{nav_playorder} += 1;
	
	# Add blank headers
	if ($lvl > $cur+1 )
	{
		for ($l=$cur+1; $l<$lvl; $l++ )
		{
			$self->nav_open ($drw, $l, "Blank Header", "nolink", $file);
		}
	}
	
	if ( $txt ne "/last/" )
	{
		$self->nav_open ($drw, $lvl, $txt, $id, $file);
		$self->{cur_nav_level} = $lvl;
	}
}

# ----------------------------------------------------------------------------
sub build_toc
{
	my $self = shift;
	my $doc = $self->{doc};
	my $paragraphs = $doc->{paragraphs};
	
	my $drw = WebTK::Draw->new ();
	
	my ($para, $level, $text, $id, $bookname);
	for $para ( @$paragraphs )
	{
		$bookname = $para->{book_filename};
		
		if ( $para->{type} =~ m/^heading/ )
		{
			$level = $para->{level};
			$text = $drw->text ($para->{data});
			$id = $para->{id};
			$self->add_tocitem ($drw, $level, $text, $id, $bookname);
		}
		elsif ( $para->{type} eq "part" || $para->{type} eq "navpoint" )
		{
			$level = 1;
			$text = $drw->text ($para->{data});
			$id = $para->{id};
			$self->add_tocitem ($drw, $level, $text, $id, $bookname);			
		}
	}
	$self->add_tocitem ($drw, 1, "/last/", "", "");
	return $drw->draw ();
}

sub toc_open
{
	my $self = shift;
	my $drw = shift;
	my $lvl = shift;
	my $txt = shift;
	my $id = shift;
	my $file = shift;
	
	my $class;
	
	if ( $id =~ m/^p/ || $id =~ m/^n/ )
	{
		$class = "toc_part";
	}
	else
	{
		$class = "toc";
	}
	
	$drw->rawtext ($self->pad($lvl));
	$drw->div ({class=>$class});
	$drw->nl ();
	
	$drw->rawtext ($self->pad($lvl+1));
	$drw->a ({href=>"$file#$id"},$txt);
	$drw->nl ();
}

sub toc_close
{
	my $self = shift;
	my $drw = shift;
	my $lvl = shift;
	
	$drw->rawtext ($self->pad($lvl));
	$drw->_div ();
	$drw->nl ();
}

sub add_tocitem
{
	my $self = shift;
	my $drw = shift;
	my $lvl = shift;
	my $txt = shift;
	my $id = shift;
	my $file = shift;
	
	my ($cur, $l);
	
	if ( ! exists ($self->{cur_toc_level}) )
	{
		$self->{cur_toc_level} = 0;
	}
	$cur = $self->{cur_toc_level};

	# Close previous
	if ( $lvl <= $cur )
	{
		for ($l=$cur; $l>=$lvl; $l--)
		{
			$self->toc_close ($drw, $l);
		}
	}
	
	# Open blank headers
	if ( $lvl > $cur+1 )
	{
		for ($l=$cur+1; $l<$lvl; $l++ )
		{
			$self->toc_open ($drw, $l, "Blank Header", "nolink", $file);
		}
	}
	
	if ( $txt ne "/last/" )
	{
		$self->toc_open ($drw, $lvl, $txt, $id, $file);
	}
	$self->{cur_toc_level} = $lvl;
}

# ----------------------------------------------------------------------
