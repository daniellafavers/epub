# ============================================================================
package WebTK::Document::Hash;

# ============================================================================
# DIRECTIVES
# ============================================================================
use strict;

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
	my $self->{varfcn} = undef;
	bless $self, $class;
	
	$self->{doc} = $doc;
	
	return $self;
}

# ----------------------------------------------------------------------------
sub set_var_function
{
    my $self = shift;
    $self->{varfcn} = shift;
}

# ----------------------------------------------------------------------------
sub render
{
	my $self = shift;
	my $doc = $self->{doc};

	my ($vars, $pars);
	$vars = $doc->{variables};
	$pars = $doc->{paragraphs};
	
	my $drw = WebTK::Draw->new ();
	if ( $self->{varfcn} ) { $drw->set_var_function ($self->{varfcn}); }
	my ($para, $var);

	$drw->rawtext ("Variables:\n\n");
	for $var ( sort keys %$vars )
	{
		$drw->rawtext ("$var: $vars->{$var}\n");
	}
	
	$drw->rawtext ("\nParagraphs:\n");
	for $para ( @$pars )
	{
		$drw->rawtext ("\n-----\ntype: $para->{type}\n");
		if ( $para->{type} eq "text" )
		{
			$drw->rawtext ("data: $para->{data}\n");
		}
		elsif ( $para->{type} eq "block" )
		{
			$drw->rawtext ("data: $para->{data}\n");
		}
		elsif ( $para->{type} =~ m/^heading/ )
		{
			$drw->rawtext ("level: $para->{level}\n");
			$drw->rawtext ("data: $para->{data}\n");
		}
		elsif ( $para->{type} eq "bullet list" )
		{
			my $item;
			for $item ( @{$para->{items}} )
			{
				$drw->rawtext ("item: data: $item->{data}\n");
			}
		}
		elsif ( $para->{type} eq "number list" )
		{
			my $item;
			for $item ( @{$para->{items}} )
			{
				$drw->rawtext ("item: number: [$item->{number}] data: $item->{data}\n");
			}
		}
		elsif ( $para->{type} eq "name list" )
		{
			my $item;
			for $item ( @{$para->{items}} )
			{
				$drw->rawtext ("item: name: [$item->{name}] data: $item->{data}\n");
			}
		}
		elsif ( $para->{type} eq "source code" )
		{
			my $line;
			for $line ( @{$para->{lines}} )
			{
				$drw->rawtext ("$line\n");
			}
		}
		elsif ( $para->{type} eq "table" )
		{
			my ($row, $cell);
			if ( $para->{caption} ne "" )
			{
				$drw->rawtext ("  caption: $para->{caption}\n");
				$drw->rawtext ("  caption position: $para->{caption_position}\n");
			}
			for $row ( @{$para->{rows}} )
			{
				$drw->rawtext ("  ROW\n");
				for $cell ( @{$row->{cells}} )
				{
					$drw->rawtext ("    cell: type: [$cell->{type}] data: [$cell->{data}] width: [$cell->{width}]\n");
				}
			}
		}
		else
		{
			my $key;
			for $key ( keys %$para )
			{
				if ( $key ne "type" )
				{
					$drw->rawtext ("$key: $para->{$key}\n");
				}
			}
		}
		
	}
	return $drw->draw ();
	
}


# ============================================================================
# INTERNAL METHODS
# ============================================================================

# ============================================================================
return 1;
