# ============================================================================
package WebTK::Draw;

# ============================================================================
# DIRECTIVES
# ============================================================================
use Carp;
use strict;

# ============================================================================
# POD HEADER
# ============================================================================

=pod

=head1 NAME

WebTK::Draw - Write web pages
    
=head1 SYNOPSIS
 
 use WebTK::Draw;
 my $p = WebTK::Draw->new ();
 $p->html ($p->body ("Hello"));
 $p->printpage ();
    
=head1 AUTHOR
    
Daniel LaFavers

=head1 DESCRIPTION
    
The WebTK::Draw object provides functions for creating web pages. It includes
several functions for setting HTTP headers and writing elements.

The headers are kept in a hash, and the text of a page is kept in a buffer.
The drawpage method renders both the headers and the body, while the draw
method renders only the text.

The AUTOLOAD feature is used to capture unknown methods and convert them into
open/close elements. Thus $p->anyelem (); will generate an element open tag:
<anyelem>. Use $p->_anyelem (); to render the element close tag:
</anyelem>.

Element attributes are set by passing in a reference to a hash. For
example,

 $page->table ({border=>"1"});

generates:

 <table border="1">

WARNING

Be careful that all built-in function calls are spelled properly. If not,
they will be turned into tags and written into the buffer. For example,

 $page->print_table ();  # Writes an empty tag <print_table>
 $page->print_tables (); # Calls the print_tables method
 
=cut

# ============================================================================
# CLASSWIDE VARIABLES
# ============================================================================

# Define the alias tables
    
# Form shortcuts
$WebTK::Draw::alias_tables{form} =
    [
     ["getform", "form", {method=>"get"}],
     ["postform", "form", {method=>"post"}],
     ["multiform", "form", {method=>"post", enctype=>"multipart/form-data"}],
     ["button", "input", {type=>"button"}],
     ["checkbox", "input", {type=>"checkbox"}],
     ["file", "input", {type=>"file"}],
     ["hidden", "input", {type=>"hidden"}],
     ["image", "input", {type=>"image"}],
     ["password", "input", {type=>"password"}],
     ["radio", "input", {type=>"radio"}],
     ["reset", "input", {type=>"reset"}],
     ["submit", "input", {type=>"submit"}],
     ["textinput", "input", {type=>"text"}],
     ["selected", "option", {selected=>undef}],
     ["radioch", "input", {type=>"radio", checked=>undef}],
     ["checkboxch", "input", {type=>"checkbox", checked=>undef}],
     ];

# ============================================================================
# CLASS METHODS
# ============================================================================

# ----------------------------------------------------------------------------
# Constructor

=pod

=head1 CONSTRUCTOR

=over 4

=item $page = WebTK::Draw->new ()
    
Creates a new draw object.

By default, the constructor loads internal alias tables. To disable
this, pass "noalias" to the constructor. You can
then load the tables separately if you want using the alias_group
method.
    
A draw object has two primary components:
    
=over 4
    
=item 1)
    
The header hash contains lines that are written as part of
the page header. This is initialized to have one value,
Content-Type, with its value set to "text/html". If you do not
want this default header, call $page->clear_headers();

The header elements are rendered when the drawpage method
is called.

=item 2)
    
The page body buffer contains the actual HTML page. All of the
page generation methods write to the page buffer when they are
called in void context.

Void context means that the method is called without any variable to
accept its output.

For example,

 $page->text ("Pe", "rl");

writes "Perl" into the page buffer, while
    
 my $lang = $page->text ("Pe", "rl");

sets $lang to "Perl" without writing anything into the page buffer.

=back
    
=back

=cut
sub new
{
    my $class = shift;
    my ($self, $buf, @http, @cookie, %alias, $table);

    # Create the object
    $self = {};
    bless $self, $class;
    
    # Set its initial values
    $self->{buf} = $buf;
    $self->{varfcn} = undef;
	$self->{replacevars} = 1;
    
    # Set up the HTTP headers
	push @http, "Content-Type: text/html; charset=iso-8859-1";
    $self->{http} = \@http;
    
    # Build the empty cookie hash
    $self->{cookie} = \@cookie;
    
    # Build the empty alias hash
    $self->{alias} = \%alias;

    $self->{doctype} = "";
	
    # Skip loading the alias tables if asked to
    return $self if ( defined $_[0] && $_[0] eq "noalias" );
    
    # Load alias groups
    for $table ( keys %WebTK::Draw::alias_tables )
    {
        $self->alias_group 
            ($WebTK::Draw::alias_tables{$table});
    }
    
    return $self;
}


# ============================================================================
# OBJECT METHODS
# ============================================================================

=pod

=head1 OBJECT METHODS

=cut
    
# ============================================================================
# HEADER METHODS
# ============================================================================

=pod
    
=head2 Header methods

=cut 

# ----------------------------------------------------------------------------
# header
=pod

=over 4
	
=item $page->header ("name", "value");
    
This sets an HTTP header. The header will be rendered in the form:
"$name: $value\n".

Headers are kept in a hash and are generated along with the page
by the drawpage method.

When the object is created, it sets "Content-Type" to "text/html".
    
You can use this function to set cookies, but the cookie method
provides an easier interface for setting expiration dates and other
cookie values.
	
If the value is omitted, only the name will be printed. This allows you
to specify the exact contents of the header.

=back
	
=cut
sub header
{
    my $self = shift;
    my $name = shift;
    my $value = shift;
    
    my $http = $self->{http};
	if ( $value )
	{
		push @$http, "$name: $value";
	}
	else
	{
		push @$http, $name;
	}
}

# ----------------------------------------------------------------------------
=pod
	
=over 4
	
=item $page->clear_headers ();

Clears all header values. This is useful to remove the default Content-Type
header that is added in the constructor.

=back
	
=cut
sub clear_headers
{
	my $self = shift;
	my @empty_list;
	$self->{http} = \@empty_list;
}
   
# ----------------------------------------------------------------------------
# cookie
=pod

=over 4

=item $page->cookie ($name, $value) or $page->cookie ($cookie_hash);

The cookie method accepts two types of input. If two scalar values
are passed, they are taken as the cookie name and value, and no
other information is set for the cookie.

The second form must be used to specify additional information about
the cookie. The second form takes a reference to a hash with the
following values:

 $page->cookie ({name=>$name, 
                 value=>$value,
                 path=>$path_name, 
                 domain=>$domain_name, 
                 expires=>$time, 
                 secure=>1});

All items, except name and value, are optional. The I<value> of secure
is ignored. If it is present the secure option will be set.
                 
This funtion only sets cookie headers. Use the WebTK::Cgi
module to read cookies.
    
Some of the following text is borrowed from "Webmaster in a nutshell",
page 92.
    
=over 4

=item name and value

Both name and value strings will are allowed to be any string.
The set_cookie function will escape spaces and other special
characters.
    
=item path_name

The path attribute supplies a URL range for which the cookie is valid.
If path is set to /pub, for example, the cookie will be sent for URLs
in /pub as well as lower levels such as /pub/docs and pub/images. A
pathname of "/" indicates that the cookie will be used for all URLs
at that site from which the cookie originated. No path attribute means
that the cookie is valid only for the originating URL.
    
=item domain_name
    
This attribute sepcifies a domain name range for which the cookie
will be returned. The domain-name must contain at least two dots
(.), e.g., .ora.com. This value would cover both www.ora.com and
software.ora.com, and any other server in the ora.com domain.

=item expires

The expires value is either a time value, as returned by time () and
modified by you, or a string containing a modifier that specifies some
time in the future from now. If you want to make your own time value,
do it like this.

 my $seconds = 60*60*3; # Number of seconds in three hours
 $cookie_hash{expires} = time () + $seconds;

A modifier string provides a shortcut to multiplying all those
seconds together. The modifier is a series of space separated
adjustments, where each adjustment consists of:

=over 2

=item + or -: (optional)

+ adds the time and - subtracts time. + is assumed.

=item number:

How many of the units

=item unit:

Use these codes:

 s for second
 m for minute
 h for hour
 d for day
 M for month
 y for year

=back
 
For example

 $cookie_hash{expires} = "3h 30m"; # Now plus three and a half hours
 
The function will format the time into a proper GMT cookie format,
which is something like this:

Wed, 01-Sep-96 00:00:00 GMT.
    
The offset parser is available as a callable function, so the following
two lines are equivalent.
    
 $cookie_hash{expires} = "1d 3m 15s";
 $cookie_hash{expires} = time () + $page->time_offset ("1d 3m 15s");

Invalid time expressions will throw an exception.
    
=item secure

The secure attribute tells the client to return the cookie only over
a secure connection (via SHTTP and SSL). Leaving out this attribute
means that the cookie will always be returned regardless of the
connection

=back

=back
	
=cut
sub cookie
{
    my $self = shift;
    my ($defn, $cookie, $safename, $safevalue);
    
    # Look for the two scalar form of method
    if ( scalar @_ == 2 && ! ref $_[0] && ! ref $_[1] )
    {
        $defn = { name=>$_[0], value=>$_[1] };
    }
    elsif ( scalar @_ == 1 && ref $_[0] eq "HASH" )
    {
        $defn = shift;
    }
    else
    {
        croak "Expecting two scalars or a hash ref";
    }
    
    # Make sure we have what we need
    croak "Cookie must specify name and value"
        if ( ! exists ($defn->{name}) || 
             ! exists ($defn->{value}) );
    
    # Encode the cookie name and value
    $safename = $defn->{name};
    $safename =~ s/([^a-zA-Z0-9_.-])/uc sprintf("%%%02x",ord($1))/eg;
    
    $safevalue = $defn->{value};
    $safevalue =~ s/([^a-zA-Z0-9_.-])/uc sprintf("%%%02x",ord($1))/eg;
    
    # Add the name and value
    $cookie = "$safename=$safevalue";

    # Handle converting the expiration time
    if ( exists ($defn->{expires}) )
    {
        my ($when, $gmt);

        # This is either a time value or a modifier
        $when = $defn->{expires};
        if ( $when !~ m/^\d+$/ )
        {
            $when = time () + $self->time_offset ($when);
        }
        
        # Compute the actual string
        my(@mname)=qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;
        my(@dname) = qw/Sun Mon Tue Wed Thu Fri Sat/;
        my($sec,$min,$hour,$mday,$mon,$year,$wday) = gmtime($when);
        $year += 1900;
        $gmt = sprintf("%s, %02d-%s-%04d %02d:%02d:%02d GMT",
                       $dname[$wday],$mday,$mname[$mon],$year,$hour,$min,$sec);
        
        # Add it to the cookie
        $cookie .= "; expires=$gmt";
    }

    # Handle the other values
    $cookie .= "; path=$defn->{path}" if ( exists ($defn->{path}) );
    $cookie .= "; domain=$defn->{domain}" if ( exists ($defn->{domain}) );
    $cookie .= "; secure}" if ( exists ($defn->{secure}) );
    
    # Now push this cookie onto our list
    push @{$self->{cookie}}, $cookie;
}

# ------------- Time offset parse function - also callable
sub time_offset
{
    my $self = shift;
    my $offset_defn = shift;
    my %unit = ('s'=>1, 'm'=>60, 'h'=>3600, 'd'=>86400, 'M'=>2592000, 'y'=>31536000);
    my (@ofs, $o, $offset);
    
    @ofs = split / /, $offset_defn;
    $offset = 0;
    for $o ( @ofs )
    {
        croak "Bad time adjustment: $o"
            if ( ! ($o =~ m/([+-]?\d+)([smhdMy])/) );
        # Compute the adjustment
        $offset += $1 * $unit{$2};
    }
    return $offset;
}

# ============================================================================
# PAGE GENERATION METHODS
# ============================================================================

=pod

=head2 Page generation methods

=cut 
	
# ----------------------------------------------------------------------------
# doctype
=pod

=over 4

=item $page->doctype ($value);

Sets a standard document type. Accetable values are:
	
=over 4
	
=item "xhtml"
	
Generages a standard XHTML 1.1 dtd header

=back
	
=back
	
=cut
sub doctype
{
	my $self = shift;
	my $type = shift;
	
	if ( $type eq "xhtml" )
	{
		$self->{doctype} = 
			"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\"".
			" \"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">\n";

	}
}
	
# ----------------------------------------------------------------------------
#open
=pod

=over 4
	
=item $page->open ("element_name", [attributes], [content]);
    
The open method is the workhorse of element generation. The first parameter
must be the element name. If the next parameter is a reference to a hash, this
is used to define the attributes for the element.

ELEMENT CONTENT
    
There are exactly three types of element content.
    
=over 4
    
=item 1)
    
Empty. Either the name parameter is the only parameter,
or it has a name followed by a reference to a hash containing
attribute names and values. In this case, only the element open
tag is drawn. You can use the close method to draw the
close tag.
    
=item 2)
    
The content consists of a single parameter, which is a
reference to a list containing scalar values.
In this case, each element in the
list is enclosed within an element.
    
=item 3)
    
The content consists of one or more scalars. In this case,
each scalar is written, without spaces, into a single
element.
    
=back
    
XHTML EMPTY ELEMENTS
    
If the element name ends with "/" or "_", then the element is not
allowed to have any content, and it is rendered using the
E<lt>elem /E<gt> format.

ATTRIBUTES
    
To specify an attribute that has no value, use {attribute=>undef}.
To indicate that an attribute should not be displayed at all,
set its value to "-hide-". This is not useful except for overriding
default attributes for an alias. (See method alias below).
    
EXAMPLES
    
 $page->open ("p");
 <p>

 $page->open ("p", {class=>"info"});
 <p class="info">

 $page->open ("p", "content");
 <p>content</p>

 $page->open ("p", {class=>"info"}, "content");
 <p class="info">content</p>

 $page->open ("p", "one", "two");
 <p>onetwo</p>

 $page->open ("p", ['one', 'two', 'three']);
 <p>one</p><p>two</p><p>three</p>

 $page->open ("p", {style="color:red"}, ['one', 'two', 'three']);
 <p style="color:red">one</p><p style="color:red">two</p>
 <p style="color:red">three</p>

 $page->open ("br/");
 <br />
    
 $page->open 
  ("table", {border=>"1"},
   $page->open ("tr",
     [$page->open ("td", ['one','two','three']),
      $page->open ("td", ['four','four','six'])]));
 <table border="1"><tr><td>one</td><td>two
 </td><td>three</td></tr><tr><td>four</td>
 <td>five</td><td>six</td></tr></table>

=back
	
=cut
sub open 
{
    my $self = shift;
    my ($elem, $atref);

    my ($out, $item, $subelem, $listref, $d);
    $out = "";
    
    # Get the element name
    if ( ! defined $_[0] )
    {
        croak "Invalid parameter list: no element name";
    }
    
    # Shift off the element name
    $elem = shift;

    # Look for attributes
    if ( ref $_[0] eq "HASH" )
    {
        # Shift off the attribute hash
        $atref = shift;
    }
    
    # Is there content?
    if ( @_ == 0 ) 
    {
        $out = $self->_elemopen ($elem, $atref);
    }
    else
    {
        # If the element name ends with "/" or "_"
        # it is not allowed to have any content.
        croak "Parameter list not allowed for empty element"
            if ( $elem =~ m|[/_]$| );
            
        
        # Validate the content list
        if ( @_ == 1 && ref $_[0] eq "ARRAY" ) 
        { 
            $listref = $_[0];
            $d = 1; # Distribute element definition for each item
        }
        else
        { 
            $listref = \@_;   
            $d = 0;
        }
        
        # Every item in the list needs to be a scalar
        for $item ( @$listref )
        {
            croak "Invalid parameter list: Non scalar value"
                if ref $item;
        }
        
        # Draw the element(s)
        if ( ! $d ) { $out .= $self->_elemopen ($elem, $atref); }
        for $item ( @$listref )
        {
            if ( $d ) { $out .= $self->_elemopen ($elem, $atref); }
            $out .= $item;
            if ( $d ) { $out .= $self->_elemclose ($elem); }
        }
        if ( ! $d ) { $out .= $self->_elemclose ($elem); }
    }
    
    # Return or save the value
    if ( defined wantarray () ) { return $out; }
    else                        { $self->{buf} .= $out; }
}

# ----------------------------------------------------------------------------
# close
=pod

=over 4

=item $page->close ("element_name");
    
The close method takes a single parameter and generates a close
tag. In void context, the close tag is written into the
page buffer. Otherwise, it is returned.

=back
	
=cut
sub close
{
    my $self = shift;
    my $elem = shift;
    
    if ( defined wantarray () ) { return $self->_elemclose ($elem); }
    else                        { $self->{buf} .= $self->_elemclose ($elem); }
}

# ---------------------------------------------------------------------------
# AUTOLOAD
=pod

=over 4
	
=item $page->any_element ();
    
Most of the time you will use this shortcut to render elements
and their contents. When the Draw module sees any method that is not otherwise
defined, it reads the method name and passes it to either the open
or close method.
    
If the function name begins with "_", the element name is passed to the close
method. Otherwise it is passed to the open method. When the
element name is followed by "_" the element is rendered as an
XHTML empty element.

You can think of the "_" as a substitute for the "/" character.

You can also use this shortcut to access alias definitions.

EXAMPLES

 $page->table ();
 <table>
    
 $page->_table ();
 </table>
    
 $page->br_ ();
 <br />

 $page->alias ("tb", "table");
 $page->tb ();
 <table>

=back
	
=cut
sub AUTOLOAD
{
    my $self = shift;
    my $elem = $WebTK::Draw::AUTOLOAD;
    
    my $string;
    
    # Remove the package name
    $elem =~ s/.*:://;
    
    # Skip some functions we don't want to handle
    return if ( $elem eq "DESTROY");
    
    # What type of element name do we have?
    if ( $elem =~ m/^_/ )
    {
        # Render a close
        $elem =~ s/^_//;
        $string = $self->_elemclose ($elem);
    }
    else
    {
        # Render an open
        $string = $self->open ($elem, @_);
    }
    
    if ( defined wantarray () ) { return $string; }
    else                        { $self->{buf} .= $string; }
}
    
# ----------------------------------------------------------------------------
# text
=pod

=over 4
	
=item $page->text ("text");

This function cleans each parameter by converting characters
that could be interpreted as part of the HTML code.

In void context the parameters are written into the page 
data buffer. Otherwise, it returns the concatenated list.

Use rawtext or markkup to draw unmodified text.
    
EXAMPLES
    
 $page->text ("<boo>");
 &lt;boo&gt;
    
 $page->rawtext ("<boo>");
 <boo>

This function also performs variable replacement, which takes
place after conversion of special characters. This means that
the value of a variable may contain html text that is not
converted.

Variables have the form !(name) or !(name,arg,arg,...)

Note that variables can not be nested. A variable opened by !(
is closed by the first ). 
    
Variables are replaced using a function that you provide.
    
The variable is recognized and the name is split on commas. This
array is passed to your function, and the return value of your
function will be written into the text buffer, replacing
the variable name.

The set_var_function is used to establish your variable
handling function. A full example is provided in the
description of that method.

This function also performs some simple character formatting using
character format blocks.

A character format block is enclosed within curly braces.
Each format block consists of a format code and text separated by
a colon.
	
For example, the following character format block will specify bold text.
	
  Here is an example of {b:bold text}.
	
You can nest format blocks within the data part of another block.
	
 This text is both {red:{b:red and italic}}

A format code block must all be specified on a single line.

 Formatting Codes
 
 b           - bold
 i           - italic
 u           - underline
 red         - make text red. You may use the following colors:
	           red, green, blue, yellow, pink, purple, orange
 #000000     - any color code
 link        - make hypertext link - href|text:
	           {link:http://www.google.com|Go to Google}
 html        - insert any raw html

=back
	
=cut
sub text
{
    my $self = shift;
    my ($t, $text, $cleantext);
    
    $cleantext = "";
    for $text ( @_ )
    {
        $t = $text;
        $t =~ s/&/&amp;/g;
        $t =~ s/</&lt;/g;
        $t =~ s/>/&gt;/g;
        $t =~ s/\"/&quot;/g;
        
        # What others do I need?
        $cleantext .= $t;
    }
    
	# Do variable replacement
	if ( $self->{replacevars} )
	{
		$cleantext =~ s/!\((.+?)\)/$self->_var_lookup($1)/eg;
	}
	
	# Do character formatting
	my $pattern = '{((\w|\d)+):([^{]+?)}';
	while ($cleantext =~ s/$pattern/$self->_char_markup($1,$3)/e) { }
	
    if ( defined wantarray () ) { return $cleantext; }
    else                        { $self->{buf} .= $cleantext; }
}

# ----------------------------------------------------------------------------
# text
=pod

=over 4
	
=item $page->nl ();

Shortcut for $page->text ("\n");

=back
	
=cut
sub nl
{
    my $self = shift;
	my $text = "\n";
    if ( defined wantarray () ) { return $text; }
    else                        { $self->{buf} .= $text; }
}
	
# ----------------------------------------------------------------------------
sub _char_markup
{
    my $self = shift;
    my $cmd = shift;
    my $data = shift;

    my ($color, $font);

    # Simple markup                                                                                                                              
    if ( $cmd eq "b" ) { return "<b>$data</b>"; }
    if ( $cmd eq "i" ) { return "<i>$data</i>"; }
    if ( $cmd eq "u" ) { return "<span style=\"text-decoration:underline\">$data</span>"; }

    # Color names
    for $color ("red", "green", "blue", "yellow", "pink", "purple", "orange", "black", "white")
    {
        if ( $cmd eq $color )
        {
            return "<span style=\"color:$color\">$data</span>";
        }
    }

	# Any color
	if ( $cmd =~ m/[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]/ )
	{
		return "<span style=\"color:#$cmd\">$data</span>";
	}
	
	# Link
	if ( $cmd eq "link" )
	{
		my ($href,$text) = $data =~ m/([^|]+)\|(.+)/;
		return "<a href=\"$href\">$text</a>";
	}
	
	# Link to external site
	if ( $cmd eq "linkout" )
	{
		my ($href,$text) = $data =~ m/([^|]+)\|(.+)/;
		return "<a href=\"$href\" target=\"_new\">$text</a>";
	}
	
	# Href - insert any html text
	if ( $cmd eq "html" )
	{
		# <tags> are converted to &lt;tags&gt; before we get to this function.
		# So what we do here is undo those changes
		$data =~ s/&lt;/</g;
		$data =~ s/&gt;/>/g;
		$data =~ s/&quot;/\"/g;
		$data =~ s/&amp;/&/g;
		return $data;
	}
	
    # Unknown command
    return $data;
}

# ----------------------------------------------------------------------------
# html
=pod
	
=over 4
	
=item $page->markup ();

This method concatenates all parameters. In void context the parameters
are written into the page data buffer. Otherwise, it returns
the concatenated list.

This function is used to add HTML text to the buffer. However, unlike
the rawtext function, this function performs variable interpolation.

=back
	
=cut
sub markup
{
    my $self = shift;
    my ($t, $text);
    
    for $t ( @_ )
    {
		$text .= $t;
    }
    
    # Do variable replacement
    $text =~ s/!\((.+?)\)/$self->_var_lookup($1)/eg;
    
    if ( defined wantarray () ) { return $text; }
    else                        { $self->{buf} .= $text; }
}
	
# ----------------------------------------------------------------------------
# rawtext
=pod

=over 4
	
=item $page->rawtext ();
    
This method concatenates all parameters. In void context the parameters
are written into the page data buffer. Otherwise, it returns
the concatenated list.

No changes is made to the parameters. This is a fallback function that you
can use to generate your own HTML code, if necessary.

 $page->rawtext ("<?php echo $_SERVER['PHP_SELF']?>");

Note that this method DOES NOT perform variable interpolation.

=back
	
=cut
sub rawtext
{
    my $self = shift;
    
    if ( defined wantarray () )
    {
        return join "", @_;
    }
    else
    {
        $self->{buf} .= join "", @_;
    }

}

# ----------------------------------------------------------------------------
# alias
=pod

=over 4
	
=item $page->alias ("alias_name", "element_name", $attr_ref);
    
The alias method defines a name which can be used in place
of an element name. The open and close methods first check to see
if a given name is an alias. If so, the replacement element is used,
and the attributes are initialized to those defined for the
alias. Attributes passed into the open function will extend
or override the default attributes.

To remove a default attribute, override it with a 
value of "-hide-".
    
EXAMPLES
    
 $page->alias ("green", "span", {style=>"color:green"});
 $page->green ("This text is green");
 <span style="color:green">This text is green</span>
    
You can use alias to force proper XML format for empty elements.
    
 $page->alias ("br", "br/");
 $page->br ();
 <br />

Your attributes extend and override the default attributes
    
 $page->alias ("table", "table", {border=>"1"});

 $page->table (); # By default, every table has a border
 <table border="1">

 # You can override the border value
 $page->table ({border=>"0", cellpadding=>"5"});
 <table border="0" cellpadding="5">

 # To remove the border attribute altogether
 $page->table ({border=>"-hide-"});
 <table>

It is also helpful to use an alias to make a shortcut to an
element name that is not a valid method name, and therefore
can not be processed by the AUTOLOAD feature. For example,
if you wanted to make an XML schema, you could have alias
definitions like this:
    
 $page->alias ("xselem", "xs:element");
 $page->xselem ("content");
 <xs:element>content</xs:element>

=back
	
=cut
sub alias
{
    my $self = shift;
    my $name = shift;
    my $elem = shift;
    my $attr = shift;
    
    my $alias = $self->{alias};
    
    # Croak if name and element are not defined
    croak "Invalid alias definition - alias name and element required"
        if ( ! defined $name || ! defined $elem );
    
    # Create the alias definition hash
    my %def;
    
    # Set the element and default attributes
    $def{elem} = $elem;
    if ( defined $attr ) { $def{attr} = $attr; }
    
    # Add it to the table
    $alias->{$name} = \%def;
}

# ----------------------------------------------------------------------------
#unalias
=pod

=over 4
	
=item $page->unalias ("alias_name");

Removes the alias definition. 

To remove all alias definitions, call this with no parameters.

=back
	
=cut
sub unalias
{
    my $self = shift;
    my $name = shift;
    my $alias = $self->{alias};

    if ( defined $name )
    {
        # Delete the named item
        delete $alias->{$name} if ( exists ($alias->{$name}) ); 
    }
    else
    {
        # Clear the entire alias set
        my %empty;
        $self->{alias} = \%empty;
    }
}

# ----------------------------------------------------------------------------
# alias_group
=pod

=over 4
	
=item $page->alias_group ($listref);
    
Loads a set of alias definitions all at once. The parameter must be an
array reference, where each item is another reference to an array
that contains the parameters to the alias function.

Usually this is accomplished using anonymous array constructors.

For example,

 $myaliaslist = 
  [
     ["red", "span", {style=>"color:red"}],
     ["tdtop", "td", {valign=>"top"}],
     ["script", "script", {language=>"JavaScript"}]
  ];
  $page->alias_group ($myaliaslist);

The WebTK::Draw module defines several such alias tables
in a hash variable named %WebTK::Draw::alias_tables. 

You can display the names and contents of these tables
by calling the show_tables function, defined below.

Here is how you load one of the pre-defined alias
tables yourself.

 $page->alias_group ($WebTK::Draw::alias_table{form}

=back

=cut
sub alias_group
{
    my $self = shift;
    my $table = shift;
    my $defn;
        
    croak "Invalid parameter - expecting array reference"
        if ( ref $table ne "ARRAY");
    
    for $defn ( @$table )
    {
        $self->alias (@$defn);
    }
    
}

# ----------------------------------------------------------------------------
# print_alias
=pod

=over 4
	
=item $page->print_alias ();

Print a table of all aliases that are currently set.

=back
	
=cut
sub print_alias
{
    my $self = shift;
    
    my $alias = $self->{alias};
    my ($a, $def);
    
    print "\n";
    print "==================================================\n";
    print "CURRENT ALIAS DEFINITIONS\n";
    print "--------------------------------------------------\n";

    for $a ( sort keys %$alias )
    {
        $def = $alias->{$a};
        $self->_print_alias_defn ([$a, $def->{elem}, $def->{attr}]);
    }
}

# ----------------------------------------------------------------------------
# print_tables
=pod

=over 4
	
=item $page->print_tables ()

The purpose of this function is to document the content of the
built-in alias tables. This will dump all of the tables that
are loaded by the constructor by default. If you pass "noalias"
to the constructor, you can then load the tables individually,
if you want, by calling the alias_group method.

Note that this does not show the currently loaded alias list.
This shows the built-in alias tables that are available within
the WebTK::Draw module, and which are loaded by default.

Use the print_alias function to print out the list of currently
loaded aliases.

=back
	
=cut

sub print_tables
{
    my $self = shift;
    my ($tname, $table, $defn);
    
    for $tname ( sort keys %WebTK::Draw::alias_tables )
    {
        print "\n";
        print "==================================================\n";
        print "ALIAS TABLE: \$WebTK::Draw::alias_table{$tname}\n";
        print "--------------------------------------------------\n";
        $table = $WebTK::Draw::alias_tables {$tname};
        for $defn ( @$table )
        {
            $self->_print_alias_defn ($defn);
        }           
    }
}

# ----------------------------------------------------------------------------
# comment
=pod

=over 4
	
=item $page->comment ("comment text");
    
Generates a comment element. If called in void context,
this writes the comment into the object buffer. Otherwise
it returns the comment.

=back
	
=cut
sub comment
{
    my $self = shift;
    my $text = shift;
    my $comment;
    
    $comment = "<!--" . $text . "-->";
    
    if ( defined wantarray() ) { return $comment; }
    else                       { $self->{buf} .= $comment; }
}

# ============================================================================
# OUTPUT METHODS
# ============================================================================

=pod

=head2 Output methods

=cut 

# ----------------------------------------------------------------------------
# draw
=pod
    
=over 4
	
=item $page->draw ();
    
Returns the text-only portion of the object. Use drawpage (below) to return a 
string that contains the HTTP headers plus the page buffer.

=back
	
=cut
sub draw
{
    my $self = shift;
    return $self->{buf};
}

# ----------------------------------------------------------------------------
# drawpage
=pod

=over 4
	
=item $page->drawpage ();
    
Returns a string that contains the HTTP headers plus the page. This is
the normal method used to display an HTML page. Use the draw method
if you are using a draw object to render a portion of a page.

=back
	
=cut
sub drawpage
{
    my $self = shift;
    my ($headers, $http, $h, $cookie, $c, $doctype);

    # Set the headers
    $headers = "";
    
    # Write the cookies
    for $c ( @{$self->{cookie}} )
    {
        $headers .= "Set-Cookie: $c\n";
    }
    
    # Draw the other headers
    $http = $self->{http};
	for $h ( @$http )
	{
		$headers .= "$h\n";
	}

    # Write the blank line to separate headers from the body
    $headers .= "\n" if ( $headers ne "" );
    
	# Set the doctype
	return $headers . $self->{doctype} . $self->{buf};
}

# ----------------------------------------------------------------------------
# print
=pod

=over 4
	
=item $page->print ();
    
Prints the result of $page->draw () to stdout.

=back
	
=cut
sub print
{
    my $self = shift;
    print $self->draw ();
}

# ----------------------------------------------------------------------------
# printpage
=pod

=over 4
	
=item $page->printpage ()
    
Prints the result of $page->drawpage () to stdout.

=back
	
=cut
sub printpage ()
{
    my $self = shift;
    print $self->drawpage ();
}

# ============================================================================
# OTHER FUNCTIONS
# ============================================================================

=pod

=head2 Other Functions

=cut 

# ----------------------------------------------------------------------------
# set_var_function
=pod

=over 4
	
=item $page->set_var_function (\&your_function);

This method is used to establish a variable replacement function that you
write.
    
When variables appear in the string passed to the text method, variables
will be identified and the variable name and arguments will be passed
to your function.
    
The return value of your function is replaced in the text.
    
Here is a complete program that demonstrates this. Of course your function
can do anything you want it to.
    
 #! /usr/bin/perl
 use WebTK::Draw;
 my $draw = WebTK::Draw->new ();
 $draw->set_var_function (\&var);

 $draw->text ("the time is !(time)\n");
 $draw->text ("HELLO !(uc,world)\n");
 $draw->text("The sum is !(eval,3*5)\n");
 $draw->print ();
 
 sub var {
    my ($name, @args) = @_;
    if ( $name eq "time" ) { return scalar localtime; }
    if ( $name eq "uc"   ) { return uc $args[0]; }
    if ( $name eq "eval" ) { return eval $args[0] }
    return "@_";
 }

The output of this program will look something like this:
    
 the time is Fri Jul  1 23:40:19 2005
 HELLO WORLD
 The sum is 15

=back
	
=cut
sub set_var_function
{
    my $self = shift;
    $self->{varfcn} = shift;
}

# ----------------------------------------------------------------------------
=pod
	
=over 4
	
=item $page->ignore_variables ();

=item $page->recognize_variables ();

This function turns off variable replacement for this draw object. This overrides
the function set by set_var_function. No variable replacement will be done.
	
You can call recognize_variables to turn variable handling back on.

=back
	
=cut
sub ignore_variables
{
	my $self = shift;
	$self->{replacevars} = 0;
}
sub recognize_variables
{
	my $self = shift;
	$self->{replacevars} = 1;
}

# ============================================================================
# INTERNAL FUNCTIONS
# ============================================================================

# ============================================================================
# Generate the element's open tag with its attributes
sub _elemopen
{
    my $self = shift;
    my $elem = shift;
    my $atref = shift;
    
    my ($emptyelem, $alias, $aliasdef, %newattr, $k);
    
    # Look up this name in the alias list
    $alias = $self->{alias};
    if ( exists $alias->{$elem} )
    {
        # Get the alias definition
        $aliasdef = $alias->{$elem};
        
        # Reset the element name
        $elem = $aliasdef->{elem};
        
        # Set up the attribute list
        if ( ref $aliasdef->{attr} eq "HASH" )
        {
            # Copy the default attributes to the local hash
            %newattr = %{$aliasdef->{attr}};
            
            # Add and override using the passed attributes
            if ( ref $atref eq "HASH" )
            {
                for $k ( keys %$atref ) 
                { 
                    $newattr{$k} = $atref->{$k};
                }
            }
            
            # Now use the local hash
            $atref = \%newattr;
        }
    }
    
    # Look for an indication to render <elem /> format.
    # An element name that ends with / or _ sets this.
    $emptyelem = 0;
    if ( $elem =~ m|[/_]$| )
    {
        # Remove the mark
        $elem =~ s|[/_]$||;
        $emptyelem = 1;
    }
    
    my $open = "<" . $elem;
    
    if ( ref $atref eq "HASH" )
    {
        my $at;
        for $at ( keys %$atref )
        {
            if ( ! defined $atref->{$at} )
            {
                # Draw the name only.
                $open .= " $at";
            }
            elsif ( $atref->{$at} ne "-hide-" )
            {
                # Draw both name and value
                $open .= " $at=\"" . $self->text ($atref->{$at}) . "\"";
            }
        }
    }

    if ( $emptyelem ) { $open .= " />"; }
    else              { $open .= ">"; }
    return $open;
}

# ============================================================================
# Generate the element's close tag
sub _elemclose
{
    my $self = shift;
    my $elem = shift;
    
    my ($alias, $aliasdef);
    
    # Look for an alias
    $alias = $self->{alias};
    if ( exists $alias->{$elem} )
    {
        $aliasdef = $alias->{$elem};
        $elem = $aliasdef->{elem};
    }

    croak "Can't close an empty element"
        if ( $elem =~ m|[/_]$| );
        
    return "</" . $elem . ">";
}

# ============================================================================
# Print an alias definition. This is called by show_table and show_alias
sub _print_alias_defn
{
    my $self = shift;
    my $defn = shift;
    my ($in, $out, $attr, $a) = @$defn;
    print "$in: ";
    print "<$out";
    if ( ref $attr eq "HASH" )
    {
        for $a ( keys %$attr )
        {
            if ( defined $attr->{$a} )
            {
                print " $a=\"$attr->{$a}\"";
            }
            else
            {
                print " $a";
            }
        }
    }
    print ">\n";
}

# ============================================================================
# Perform variable replacement
sub _var_lookup
{
    my $self = shift;
    my $name = shift;
    my @args;
    
    # If there is no variable function return a placeholder
    return "[VAR:$name]" if ( ! defined $self->{varfcn} );
    
    # Split the arguments on comma - allow spaces
    @args = split /\s*,\s*/, $name;
    
    # Call the function
    return &{$self->{varfcn}} (@args);
}

# ============================================================================
return 1;
