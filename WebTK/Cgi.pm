# ============================================================================
package WebTK::Cgi;

# ============================================================================
# DIRECTIVES
# ============================================================================
use WebTK::Cgi::Param;

use Carp;
use strict;

# ============================================================================
# POD HEADER
# ============================================================================

=pod
	
=head1 WebTK::Cgi

Read CGI and other server environment information.
	
=head1 SYNOPSIS
	
 use WebTK::Cgi;
 my $cgi = WebTK::Cgi->new ();
 $cgi->showall ();

 or
	
 print "Content-Type: text/plain\n\n";
 print "The value of GET argument X is " . $cgi->get ("X") . "\n";

=head1 AUTHOR
	
Daniel LaFavers

=head1 DESCRIPTION
	
This Cgi.pm module is a simple tool for reading cgi arguments. It does not
provide functions for rendering HTMl pages. The WebTK::Draw module provides
those services.
	
In this module parameters are represented by hashes. Each hash has a name
and holds a list of values and sub-parameters.
	
Every parameter is a list. You do not need to name variables with [] as you
do in other CGI handling modules.
	
 <form method="get", action="script.cgi">
 <input type="hidden" name="arg" value="zero">
 <input type="hidden" name="arg" value="one">
 <input type="hidden" name="arg" value="two">
 <input type="submit">
 </form>	
	
Here the value of arg is a list ('one', 'two', 'three').

You can use square brackets in your variable names if you want, but this
module treats them as ordinary characters.
	
To access the first element in the list use the get method.
	
 my $value = $cgi->get ("arg"); # Set's $value to 'zero'

To access other elements, you need to provide a second parameter.
	
=over 2
	
=over 11
	
=item integer
	
If the second parameter is an iteger, the get function will return
the value at that index within the value list. Thus $cgi->get ("arg", 2)
returns the value 'two'.
	
=item 'count'
	
If the second paramter is the string 'count', the get function will
return the number of values.
	
=item 'list'
	
If the second parameter is the string 'list', the get function will
return all the values in list context.
	
=item 'listref'
   
If the second parameter is the string 'listref', the get function
will return a references to the list of values.
	
=back
	
WebTK::Cgi provides access to CGI variables, cookies, and server
environment variables. Use the env, get, post, and cookie methods.
	
 $cgi->env ("request_method");
 $cgi->cookie ("mycookie");

=back

=head1 SHORTCUTS
	
This module uses the AUTOLOAD function to provide shortcut methods to
environment variables, arguments, and cookies.

 $cgi->request_method ();
 $cgi->mycookie ();
 
The function looks for names in the following order:

 Method name
 Get arguments
 Post arguments
 Cookies
 Environment variables
	
Using shortcuts can provide array-like access to multi-valued arguments.
	
Instad of:
	
 $cgi->get ("myarg", 3);
	
You can use:
	
 $cgi->myarg (3);

=head1 PARAMETER NAMESPACES

Each parameter also acts as a name space for sub-parameters. A sub-paramter
name is separated from a paramter name with a dot.
	
This allows you to specify complex forms more easily.

 <input type="hidden" name="list.1.name" value="one">
 <input type="hidden" name="list.2.name" value="two">

All parameters are objects provided by the WebTK::Cgi::Param module.
	
There is a single root paramter, named root, which you can obtain with the
root method.
	
 $root_param = $cgi->root ();

This parameter provides the namespace for three other parameters: post, 
get, and cookie. Each of these is the namespace for those sets
of parameters. 
	
=cut

# ============================================================================
# CLASSWIDE VARIABLES
# ============================================================================

# The first object to be created will read the stdin filehandle, if necessary.
my $stdin_content = "";

# ============================================================================
# CLASS METHODS
# ============================================================================

# ----------------------------------------------------------------------------
# new
=pod

=head1 CONSTRUCTOR
	
=over 4
	
=item $cgi = WebTK::Cgi->new ();

Creates a new Cgi object. When the object is created it performs the
following tasks:
	
=item Check command line arguments

Command line arguments can be used to simulate the server environment.
Arguments come in two forms: mode-selectors and data.

A mode selector is one of the words: "get" "post" "env" or "cookie". The
default mode is "get".

This determines how the data arguments are handled. Use the get, post, env,
and cookie methods to retrieve the data specified by arguments for that mode.

Get and post arguments can be encoded as an x-www-form-urlencoded string.
Environment settings have the form "name=value". Everything following
the first equal sign becomes part of the environment variables. Thus
the following three argument lists are identical.

 $ myscript.cgi one=first two=second
 $ myscript.cgi get "one=first&two=second"
 $ myscript.cgi env "QUERY_STRING=one=first&two=second"

=item Parse get arguments

If the QUERY_STRING environment variable is set, get arguments
are read and decoded.

=item Read stdin

If the CONTENT_LENGTH environement variable is set, the stdin
filehandle is read and post arguments are read. This module supports
the following type of content type encodings:

 application/x-www-form-urlencoded
 multipart/form-data

The content type is specified by the enctype attribute of the form element.
The default is "application/x-www-form-urlencoded", but if you use a file
input element, you must specify "multipart/form-data".

WebTK::Cgi holds all uploaded data directly in memory. This is usually
sufficient. Future enhancement may take into account the possibility of
exceptionally large uploads.

=item Decode cookies

If the HTTP_COOKIE environment variable is set, the cookie values are
separated and decoded. 
 
=back
	
=cut
sub new
{
	my $class = shift;
	my ($self, %env, $root, $e, $posttype);
	
	# Create the root parameter
	$root = WebTK::Cgi::Param->new ("root");
	
	# Create the object - include shortcuts to the major instances
	$self = { };
	$self->{root}   = $root;
	$self->{get}    = $root->add ("get");
	$self->{post}   = $root->add ("post");
	$self->{cookie} = $root->add ("cookie");
	bless $self, $class;

	# Parse the input commands
	if ( $ARGV[0])
	{
		$self->_parsecl (\%env);
	}
	
	# Set environment variables from the command line
	for $e ( keys %env ) { $ENV{$e} = $env{$e};	}
	
	# Load GET variables
	if ( $ENV{QUERY_STRING} )
	{
		$self->_decode ($ENV{QUERY_STRING}, $self->{get});
	}
	
	# Load POST variables
	if ( $ENV{CONTENT_LENGTH} )
	{
		read (STDIN, $stdin_content, $ENV{CONTENT_LENGTH}) 
			if $stdin_content eq "";
		
		$posttype = $ENV{CONTENT_TYPE};
		
		if ( $posttype =~ m(^multipart/form-data) )
		{
			$self->_multipart_form 
				($posttype, \$stdin_content, $self->{post});
		}
		elsif ( $posttype eq "application/x-www-form-urlencoded" )
		{
			$self->_decode ($stdin_content, $self->{post});
		}
	}
	
	# Decode the cookies
	if ( $ENV{HTTP_COOKIE} )
	{
		$self->_cookies ($ENV{HTTP_COOKIE});
	}
	
	# Return the new object
	return $self;
}

# ============================================================================
# OBJECT METHODS
# ============================================================================

=pod

=head1 OBJECT METHODS

=cut

# ----------------------------------------------------------------------------
# env
=pod

=over 4
	
=item $cgi->env ($env_var);
	
Returns the value of the given environment variable. The 
parameter will be converted to upper case. If the request
environment variable is not found, this will return undef;

Environment variables are also available as shortcut methods.

Thus the following are equivalent:
 
 $m = $ENV{'REQUEST_METHOD'}
 $m = $cgi->env ("REQUEST_METHOD");
 $m = $cgi->env ("request_method");
 $m = $cgi->request_method ();

=back
	
=cut
sub env
{
	my $self = shift;
	my $evar = shift;
	my $val;
	
	return undef if ( ! defined $evar );
	return undef if ( ! defined ($val = $ENV{uc $evar}));
	return $val;
}

# ----------------------------------------------------------------------------
# get
=pod
	
=over 4
	
=item $cgi->get ($arg);
	
Returns the named get argument. Get arguments are sensitive
to case. Thus, $cgi->get ("one") returns a different variable than
$cgi->get ("ONE"). If the argument name does not contain spaces
or special characters, you can access the argument using
a shortcut method that matches the argument name.

=back
	
=cut	
sub get
{
	my $self = shift;
	return $self->{get}->value(@_);
}
	
# ----------------------------------------------------------------------------
# post
=pod

=over 4
	
=item $cgi->post ($arg);
	
Returns the named post argument. Post arguments are sensitive
to case. If the argument name does not contain spaces
or special characters, and there is no get argument with the
same name, you can access the argument using
a shortcut method that matches the argument name.

Information from multipart/form-data:

If you submit a form using the multipart/form-data type encoding,
you can request extra information about post variables.

Here are the items that are available for uploaded files.

=over 2

=over 2

=item filename: name of the uploaded file

=item Content-Type: Mime type of the uploaded file

=back

=back

Information for an argument is stored as a sub parameter
of the argument. If your input looks like this:

 <input type="file" name="upload">

you will be able to access the other values like this:

 $filename = $cgi->post ("upload.filename");
 $type = $cgi->post ("upload.Content-Type");

=back

=cut
sub post
{
	my $self = shift;
	return $self->{post}->value(@_);
}

# ----------------------------------------------------------------------------
# postdata
=pod

=over 4
	
=item $cgi->postdata ();
	
This returns the entire content read from stdin when
$cgi->request_method() eq "POST".

=back
	
=cut
sub postdata
{
	return $stdin_content;
}

# ----------------------------------------------------------------------------
# cookie
=pod
	
=over 4
	
=item $cgi->cookie ($name);
	
The cookie function returns the value for the named cookie.

Because you can have multiple cookies with the same name, you can
access the cookies or the list using the same techniques described
for accessing mult-valued get and post arguments.

If the cookie name does not contain spaces or special characters,
and is not the same as a get or post argument, you can access the
cookie value using a method shortcut.

 $cgi->cookie ("mycookie");
 $cgi->mycookie ();

=back
	
=cut
sub cookie
{
	my $self = shift;
	return $self->{cookie}->value (@_);
}

# ----------------------------------------------------------------------------
# AUTOLOAD
=pod
	
=over 4
	
=item Method shortcuts

This module uses the AUTOLOAD feature to create method shortcuts
as described in the Shortcuts section of the Description above.

In the following examples, the two paired statements are equivalent

 $cgi->env ("REMOTE_HOST");
 $cgi->remote_host ();
 
 $cgi->get ("city");
 $cgi->city ();
 
 $cgi->post ("spam", 300);
 $cgi->spam (300);

 $cgi->cookie ("auth");
 $cgi->auth ();

You can use the underscore character to stand in for a dot. $cgi->company_name () will
return the value of variable "company_name". If no such variable exists, the function
will look for a "company.name" variable.

If the value does not exist, this returns undef. Be careful using
this, because if you intended to call a function but type the name incorrectly
this will return undef string instead of generating an error.

=back
	
=cut
sub AUTOLOAD
{
	my $self = shift;
	my $name = $WebTK::Cgi::AUTOLOAD;
	
	# Remove the package name
	$name =~ s/.*:://;
	
	# Skip functions we don't want to handle
	return if ( $name eq "DESTROY");

	# Look up the value
	return $self->value ($name, @_);
}

# ----------------------------------------------------------------------------
# value
=pod

=over 4
	
=item $cgi->value ($name, $what)

The value function returns the value of the named string.

The second parameter is optional. If provided, it will return
a special value as described in the section Multi-Valued arguments.
	
This function can be used to return the value of a get or post
argument or a cookie without specifying the type of argument.

It begins by searching the root namespace. If it does not
find a match, it then searches the get, post, and cookie name
spaces.

Thus the following will all return the value of a post argument
named "color".

 $c = $cgi->post ("color");
 $c = $cgi->value ("color");
 $c = $cgi->value ("post.color");
 $c = $cgi->color ();

The function may take additional arguments. For example
	
 $argc = $cgi->value ("post.list", 4);
 @addr_lines = $cgi->value ("address", "list");

This function is used by the AUTOLOAD function, and so you may use either
a dot or underline to indicate the separatation of parameters and sub-parameters.
This capability is not available for the get, post, cookie, or env functions.
If any variable actually includes an underline character, that will match first.

Example: my.cgi:
	
 use WebTK::Cgi;
 my $cgi = WebTK::Cgi->new ();
 print $cgi->var_name();

 If you invoke as "my.cgi var_name=one var.name=two" this will print "one".
 If you invoke as "my.cgi xxx_name=one var.name=two" this will print "two".
	
=back
	
=cut	
sub value
{
	my $self = shift;
	my $name = shift;
	my ($value, @names, $n, $dot_pattern);

	# The dot pattern allows autoload to reference dot-separated names
	$dot_pattern = "_";
	
	# If we don't find a match with the exact name, convert
	# the $dot_pattern to a dot and try again
	push @names, $name;
	if ( $name =~ m/$dot_pattern/ )
	{
		$name =~ s/$dot_pattern/\./g;
		push @names, $name;
	}
	
	for $n ( @names )
	{
		# Look for an instance in one of the primary name spaces
		$value = $self->{root}->value ($n, @_);
		$value = $self->{get}->value ($n, @_) if ( ! $value );
		$value = $self->{post}->value ($n, @_) if ( ! $value );
		$value = $self->{cookie}->value ($n, @_) if ( ! $value );
		
		return $value if ( $value );
		
		# Look for an environment variable
		return $ENV{uc $n} if ( exists ($ENV{uc $n}) );
	}
	return undef;
}

# ----------------------------------------------------------------------------
# showall
=pod

=over 4
	
=item $cgi->showall ();
	
This function prints a web page with the content type "text/plain" that
contains a list of all environment variables, get and post arguments,
and cookies.

This is usually called from a small test script, which can be set
as the action target of a form.

 #! /usr/bin/perl
 use WebTK::Cgi;
 my $cgi = WebTK::Cgi->new ();
 $cgi->showall ();

=back

=cut
sub showall
{
	my $self = shift;
	my $s;
	# Print the page header
	print "Content-Type: text/plain\n\n";
	
	print "\n----------------------------------------\n";
	print "GET ARGUMENTS\n";
	for $s ( @{$self->{get}->{params}} ) { $self->_show_args ($s); }
	
	print "\n----------------------------------------\n";
	print "POST ARGUMENTS\n";
	for $s ( @{$self->{post}->{params}} ) { $self->_show_args ($s); }
	
	print "\n----------------------------------------\n";
	print "COOKIES\n";
	for $s ( @{$self->{cookie}->{params}} ) { $self->_show_args ($s); }
		
	print "\n----------------------------------------\n";
	print "ENVIRONMENT\n";
	my $e;
	for $e ( sort keys %ENV )
	{
		print "  $e = $ENV{$e}\n";
	}
}

# ----------------------------------------------------------------------------
# root
=pod

=over 4
	
=item $cgi->root ()
	
Returns the root parameter. This parameter contains sub-paramters
named "get", "post", and "cookie", each of which contains only
a single, default instance.
	
All other arguments and cookies are defined as sub parameter sets
within these instances.

If there is a GET paramter named "a", the following methods to read
its value are equivalent.
	
  $value = $cgi->a ();
  
  $value = $cgi->get ("a");
  
  $value = $cgi->get ("a", 0);
  
  $root = $cgi->root (); 
  $i = $root->find ("get.a"); 
  $value = $i->value ("*", 0);
	
SEE ALSO:
	
WebTK::Cgi::Param

=back
	
=cut
sub root
{
	my $self = shift;
	return $self->{root};
}

# ============================================================================
# INTERNAL METHODS
# ============================================================================

# ============================================================================
# Parse command line arguments
sub _parsecl
{
	my $self = shift;
	my $env = shift;

	my ($arg, $param);
	
	$param = $self->{get};
	for $arg ( @ARGV )
	{
		if    ( lc $arg eq "get" )    { $param = $self->{get}; }
		elsif ( lc $arg eq "post" )   { $param = $self->{post}; }
		elsif ( lc $arg eq "cookie" ) { $param = $self->{cookie}; }
		elsif ( lc $arg eq "env" )    { $param = 0; }
		else
		{
			if ( $param == 0 )
			{
				# Parse an environment setting
				my ($name, $value) = $arg =~ m/([^=]+)=(.+)/;
				$env->{$name} = $value;
			}
			else
			{
				# Assume query string format
				$self->_decode ($arg, $param);
			}
		}
	}
}
	
# ============================================================================
# Decode data from an x-www-form-urlencoded string and place name/value
# pairs into the given hash.
sub _decode
{
	my $self = shift;
	my $args = shift;
	my $param = shift;

	my (@pairs, $pair, $name, $value, $clean_name, $clean_value);
	
	# Separate the name/value pairs
	@pairs = split /&/, $args;
	
	foreach $pair ( @pairs )
	{
		# Separate the name from the value
		($name, $value) = split /=/, $pair;
		
		# Unescape the name and value
		$clean_name  = $self->_unescape ($name);
		$clean_value = $self->_unescape ($value);
		
		# Add them to the parameter
		$param->add ($clean_name, $clean_value);
	}	
}

# ============================================================================
# Decode multipart form data - data is passed by scalar reference
# This works okay, but I would like to rewrite this in the future.
# Not only does it need to be cleaner, perhaps splitting into 
# separate lines, but it also needs to be able to handle
# very large files and error conditions. What if content-length
# bytes can't be read from stdin. I might want to snoop through
# CGI.pm a bit to get some ideas.
sub _multipart_form
{
	my $self = shift;
	my $type = shift;
	my $dataref = shift;
	my $param = shift;

	my ($boundary, $splitter, @parts, $part, $header, $sep, $data);
	my (@head, $h, $n, $v, $key, $i);
	
	# Find the boundary
	($boundary) = $type =~ m/boundary=(.+)/;
	
	# Multipart files are encoded where each part is preceded by a line containing
	# -- plus the boundary, and ends with -- boundary --. Because the split function
	# expects delimiters between items, we will end up with empty parts at the
	# beginning and the end, which are easy to ignore.
	# The splitter regular expression eats the extra --s and newlines

	$splitter = "(\r\n)?--$boundary-*(\r\n)?"; 
	@parts = split /$splitter/, $$dataref;

	# Handle each part. Each part is a separate form data element.
	for $part ( @parts )
	{
		# Ignore empty parts. These are generated because I'm 
		# using split instead of parsing it all more precisely.
		next if ( $part eq "" || $part eq "\r\n" );

		# Separate the header part from the data. We're looking for the
		# empty line, marked by two consecutive end of line markers
		($header, $sep, $data) = $part =~ m/(.+)(\r\n\r\n)(.+)/s;

		# Now split the header into its individual elements. Break on
		# a semi-colon or a line break
		@head = split /;\s*|\n\r?\s*/, $header;
		
		# We're almost there - next, break each header element into 
		# it's name/value pair. Sometimes they are: name: value
		# and other times you get: name="value".

		# Make a new info hash
		my %info;

		for $h ( @head )
		{
			if ( $h =~ m/: / ) 
			{
				($n, $v) = $h =~ m/(.+): (.+)/; 
			}
			elsif ( $h =~ m/=\".+\"/ )  
			{
				($n, $v) = $h =~ m/(.+)=\"(.+)\"/; 
			}
			else { next;  }
			
			$info{$n} = $v;
		}
		
		# Now it's time to set up the post variables
		next if ( ! exists $info{name} );
		
		# Write the data into the post hash
		$param->add ($info{name}, $data);

		# Add the file information.
		for $key ( keys %info )
		{
			next if ( $key eq "Content-Disposition");
			next if ( $key eq "name");
			$i="$info{name}.$key";
			$param->add ($i, $info{$key});
		}
	}
}

# ============================================================================
# Decode the cookies
sub _cookies
{
	my $self = shift;
	my $data = shift;
	
	my (@cookies, $c);
		
	# Separate the cookies
	@cookies = split /\s*;\s*/, $data;
	
	# Get and decode the name and value
	for $c ( @cookies )
	{
		$self->_decode ($c, $self->{cookie});
	}
}

# ============================================================================
# Support for the show all function
sub _show_args
{
	my $self = shift;
	my $param = shift;
	my $prefix = shift;
	my ( $c, $v, $s, $p );

	# Show the values
	$c = scalar (@{$param->{values}});
	if ( $c == 1 )
	{
		print $prefix . "$param->{name} = $param->{values}->[0]\n";
	}
	elsif ( $c > 1 )
	{
		print $prefix . "$param->{name}\n";
		$c = 0;
		for $v ( @{$param->{values}} )
		{
			print "  [$c] = " . $param->{values}->[$c] . "\n";
			$c++;
		}
	}
	
	# Now show the sub-parameters for this
	if ( $prefix eq "" ) { $p = $param->{name} . "."; }
	else { $p = $prefix . $param->{name} . "."; }
	for $s ( @{$param->{params}} )
	{
		$self->_show_args ($s, "$p");
	}
}

# ----------------------------------------------------------------------------
# Replace a URL encoded string with a plain text string
sub _unescape
{
	my $self = shift;
	my $data = shift;
	
	$data =~ tr/+/ /;
	$data =~ s/%([a-fA-F0-9]{2})/pack("C",hex($1))/eg;
	return $data;
}

# ----------------------------------------------------------------------------
# URL encode a string
sub _escape
{
	my $self = shift;
	my $data = shift;
	
	$data =~ s/([^0-9a-zA-Z ])/sprintf("%%%02X",ord($1))/eg;
	$data =~ tr/ /+/;
	return $data;
}

# ============================================================================
return 1;
