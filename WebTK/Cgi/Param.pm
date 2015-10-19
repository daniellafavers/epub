# ============================================================================
package WebTK::Cgi::Param;

# ============================================================================
# DIRECTIVES
# ============================================================================
use strict;

# ============================================================================
# POD HEADER
# ============================================================================

=pod

=head1 WebTK::Cgi::Param
	
Perform functions to support Cgi parameters. This module is part of
WebTK::Cgi.
	
=head1 SYNOPSIS
 
#! /usr/bin/perl

 use WebTK::Cgi::Param;
 my $param = WebTK::Cgi::Param->new ("base");
 $param->add ("a","hello");    # Creates base.a = hello
 $param->add ("a.b","hello");  # Creates base.a.b = world
 $a = $param->find ("a");
 $a->add ("c", "three");       # Creates base.a.c = three

 print "a="   . $param->value ("a")   . "\n"; # prints "a=hello"
 print "a.b=" . $param->value ("a.b") . "\n"; # prints "a.b=world"
 print "a.c=" . $param->value ("a.c") . "\n"; # prints "a.c=three"
 	
=head1 AUTHOR
	
Daniel LaFavers

=head1 DESCRIPTION
	
WebTK::Cgi::Param manages CGI arguments and cookies as nested hash objects.

These functions provide access to the details of the parameters
in more detail than using the cgi object functions alone.
	
=cut
	
# ============================================================================
# CLASSWIDE VARIABLES
# ============================================================================

# ============================================================================
# CLASS METHODS
# ============================================================================

# ----------------------------------------------------------------------------
# new
=pod
	
=head1 CONSTRUCTOR

=over 4
	
=item $param = WebTK:Cgi::Param->new ($name);

You can use this to create a new empty parameter.

=back
	
=cut
sub new
{
	my $class = shift;
	my $name = shift;
	my ($self);
	
	# Create the object
	$self = { };
	$self->{name}   = $name; # Parameter name
	$self->{values} = [];    # List of values for this parameter 
	$self->{params} = [];    # List of sub-parameters
	bless $self, $class;

	return $self;
}

# ============================================================================
# OBJECT METHODS
# ============================================================================

=pod

=head1 OBJECT METHODS

=over 4
	
=cut

# ----------------------------------------------------------------------------
# add
# Find or create a new sub-parameter within the parameter's namespace and
# add a value to the parameter's value list
=pod
	
=over 4
	
=item $param->add ($name, $value);

This uses the find method to locate or create the named
parameter within this parameter's namespace and then adds a new
value to the found sub-parameter's value list. The name may contain
sub-parameter names, such as "a.b.c".

=back
	
=cut
sub add
{
	my $self = shift;
	my $name = shift;
	my $value = shift;
	
	my (@names, $param);

	# Separate the name into its dot-separated components
	@names = split [\.], $name;
	
	# Find or create the named parameter
	$param = $self->_find (@names, 1);
	
	# Add the value to the found parameter's value list
	if ( $param && $value )
	{
		push @{$param->{values}}, $value;
	}
	
	return $param;
}

# ----------------------------------------------------------------------------
# na=over 4me
# Return the parameter's name
=pod
	
=over 4
	
=item $param->name ();
	
This returns the actual name of the given parameter. 

=back
	
=cut
sub name
{
	my $self = shift;
	return $self->{name};
}
	
# ----------------------------------------------------------------------------
# list
# Returns a list of sub-parameter names
=pod
	
=over 4
	
=item $param->subnames ();

Returns a list of sub-parameter names within the namespace of the parameter
object. This only provides top-level names of the sub-parameters.

=back
	
=cut
sub subnames
{
	my $self = shift;
	my ($p, @list);

	for $p ( @{$self->{params}} )
	{
		push @list, $p->{name};
	}
	return @list;
}
	
# ----------------------------------------------------------------------------
# value
# Find a named value within the parameter's name space and return the
# value. The type is a number or a keyword
=pod
 
=over 4
	
=item $param->value ($name, $type);

This uses the find method to locate the named parameter within
this parameter's namespace and then returns information from that
sub-parameter's value list. To consider the parameter's OWN values,
use "*" as the parameter name. (See description of the find function.)

The second parameter is optional. If omitted, it defaults to the number 0.

The type can be one of:
	
=over 11
	
=item integer
	
If the second parameter is an iteger, the get function will return
the value at that index within the value list.
	
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

=back
	
=cut
sub value
{
	my $self = shift;
	my $name = shift;
	my $type = shift;
	
	my (@names, $param, $listref);
	
	# Find the named parameter - don't create
	$param = $self->find ($name, 0);
	
	# Return undef if we couldn't find the parameter
	return undef if ( ! $param );
	
	# All the return types are related to the list of values
	$listref = $param->{values};
	
	$type = 0 if ( ! defined $type );
	
	if ( $type =~ m/^\d+$/ )
	{
		# Return a numbered item from the list
		return $listref->[$type];
	}
	elsif ( $type eq "count" )
	{
		return scalar @$listref;
	}
	elsif ( $type eq "list" )
	{
		return @$listref;
	}
	elsif ( $type eq "listref" )
	{
		return $listref;
	}
	else
	{
		# Invalid request
		return undef;
	}
}

# ============================================================================
# find
# Wrapper for the internal find function
=pod
	
=over 4
	
=item $param->find ($name, $create_flag);
	
This searches for the named parameter within this parameter's namespace.
If the sub-parameter is not found and the $create_flag is true, the
new parameter will be created. $name is the name of the sub-pararameter.
	
$name can be a dot-separate list of names. For a parameter named A.B, the
find function will first look for a parameter named A in this parameter's
sub-parameter list, and create it if necessary. It will then go to the A
parameter and look for B.

If the name is "*", the function will return the current parameter. 

=back
	
=cut
sub find ()
{
	my $self = shift;
	my $name = shift;
	my $create = shift;
	
	# Separate the name into its dot-separated components
	my @names = split [\.], $name;
	return $self->_find (@names, $create);
}

# ============================================================================
# INTERNAL METHODS
# ============================================================================

# ----------------------------------------------------------------------------
# Find or create a sub-parameter 
sub _find
{
	my $self = shift;
	my $name = shift;
	my $create = shift;
	my @sub = @_;

	my ($param, $found);
	
	# Look for the special * name
	return $self if ( $name eq "*" );
	
	# Look through each sub-parameter
	$found = undef;
	for $param ( @{$self->{params}} )
	{
		if ( $param->{name} eq $name )
		{
			$found = $param;
			last;
		}
	}
	
	# Create the parameter if we need
	if ( ! $found )
	{
		return undef if ( ! $create );
		$found = WebTK::Cgi::Param->new ($name);
		push @{$self->{params}}, $found;
	}
		
	# We're done if there are no more sub parameters to find
	return $found if ( scalar @sub == 0 );
	return $found->_find ($create, @sub);
}

# ============================================================================
return 1;
