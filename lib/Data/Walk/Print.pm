package Data::Walk::Print;
use version; our $VERSION = qv('0.024.004');

use Moose::Role;
requires 
	'_get_had_secondary', 
	'_process_the_data',
	'_dispatch_method';
use MooseX::Types::Moose qw(
        HashRef
        ArrayRef
        Bool
        Str
        Ref
		Num
    );######<---------------------------------------------------------  ADD New types here
if( $ENV{ Smart_Comments } ){
	use Smart::Comments -ENV;
	### Smart-Comments turned on for Data-Walk-Print ...
}

#########1 Package Variables  3#########4#########5#########6#########7#########8#########9

$| = 1;
my $print_keys = {
    print_ref => 'primary_ref',
    match_ref => 'secondary_ref',
};

#########1 Dispatch Tables    3#########4#########5#########6#########7#########8#########9

my	$before_pre_string_dispatch ={######<-----------------------------  ADD New types here
		HASH => \&_before_hash_pre_string,
		ARRAY => \&_before_array_pre_string,
		DEFAULT => sub{ 0 },
		name => 'print - before pre string dispatch',
		###### Receives: the current $passed_ref and the last branch_ref array
		###### Returns: nothing
		###### Action: adds the necessary pre string and match string 
		######           for the currently pending position
	};
		

my 	$before_method_dispatch ={######<----------------------------------  ADD New types here
		HASH => \&_before_hash_printing,
		ARRAY => \&_before_array_printing,
		OBJECT => \&_before_object_printing,
		DEFAULT => sub{ 0 },
		name => 'print - before_method_dispatch',
		###### Receives: the passed_ref
		###### Returns: 1|0 if the string should be printed
		###### Action: adds the necessary before string and match string to the currently 
		######           pending line
	};

my 	$after_method_dispatch ={######<-----------------------------------  ADD New types here
		UNDEF => \&_after_undef_printing,
		SCALAR => \&_after_scalar_printing,
		HASH => \&_after_hash_printing,
		ARRAY => \&_after_array_printing,
		OBJECT => \&_after_object_printing,
		name => 'print - after_method_dispatch',
		###### Receives: the passed_ref
		###### Returns: 1|0 if the string should be printed
		###### Action: adds the necessary after string and match string to the currently 
		######           pending line
	};

#########1 Public Attributes  3#########4#########5#########6#########7#########8#########9

has 'match_highlighting' =>(
    is      	=> 'ro',
    isa     	=> Bool,
    writer  	=> 'set_match_highlighting',
	predicate	=> 'has_match_highlighting',
	reader		=> 'get_match_highlighting',
	clearer		=> 'clear_match_highlighting',
    default 	=> 1,
);

has 'to_string' =>(
    is      	=> 'ro',
    isa     	=> Bool,
	reader		=> 'get_to_string',
    writer  	=> 'set_to_string',
	predicate	=> 'has_to_string',
	clearer		=> 'clear_to_string',
    default 	=> 0,
);


#########1 Public Methods     3#########4#########5#########6#########7#########8#########9

sub print_data{
    ### <where> - Made it to print
    ##### <where> - Passed input  : @_
    my  $self = $_[0];
    my  $passed_ref = 
            ( 	@_ == 2 and 
                (   ( is_HashRef( $_[1] ) and 
					!( exists $_[1]->{print_ref} ) ) or
				!is_HashRef( $_[1] )						) ) ? 
					{ print_ref => $_[1] }  :
            ( 	@_ == 2 and is_HashRef( $_[1] ) ) ? 
					$_[1] : 
					{ @_[1 .. $#_] } ;
    ##### <where> - Passed hashref: $passed_ref
    @$passed_ref{ 'before_method', 'after_method' } = 
        ( '_print_before_method', '_print_after_method' );
    ##### <where> - Start recursive parsing with: $passed_ref
    $passed_ref = $self->_process_the_data( $passed_ref, $print_keys );
    ### <where> - End recursive parsing with: $passed_ref
	my $return = ( $self->get_to_string ) ? $self->_get_final_string : 1;
	$self->_clear_final_string;
    return $return;
}

#########1 Private Attributes 3#########4#########5#########6#########7#########8#########9

has '_pending_string' =>(
    is          => 'ro',
    isa         => Str,
    writer      => '_set_pending_string',
    clearer     => '_clear_pending_string',
    predicate   => '_has_pending_string',
	reader		=> '_get_pending_string',
);

has '_match_string' =>(
    is          => 'ro',
    isa         => Str,
    writer      => '_set_match_string',
    clearer     => '_clear_match_string',
    predicate   => '_has_match_string',
	reader		=> '_get_match_string',
);

has '_final_string' =>(
    is          => 'ro',
    isa         => Str,
    traits  	=> ['String'],
    writer      => '_set_final_string',
    clearer     => '_clear_final_string',
    predicate   => '_has_final_string',
	reader		=> '_get_final_string',
    handles => {
        _add_to_final_string => 'append',
    },,
    default => q{},
);

#########1 Private Methods    3#########4#########5#########6#########7#########8#########9

sub _print_before_method{
    my ( $self, $passed_ref ) = @_;
    ### <where> - reached before_method ...
    #### <where> - received input: $passed_ref
	##### <where> - self: $self
	my ( $should_print );
	if( 	$self->get_match_highlighting and
			!$self->_has_match_string 			){
		$self->_set_match_string( '#<--- ' );
	}
	### <where> - add before pre-string ...
	if( $self->_get_current_level ){ 
		### <where> - only available at level 1 + ...
		$self->_dispatch_method(
			$before_pre_string_dispatch,
			$passed_ref->{branch_ref}->[-1]->[0],
			$passed_ref,
			$passed_ref->{branch_ref}->[-1],
		);
	}
	### <where> - printing reference bracket ...
	if( $passed_ref->{skip} eq 'NO' ){
		$should_print = $self->_dispatch_method(
			$before_method_dispatch,
			$passed_ref->{primary_type},
			$passed_ref,
		);
	}else{
		### <where> - Found a skip - handling it in the after_method ...
	}
	### <where> - print as needed ...
    if( $should_print ){
		### <where> - found a line that should print ...
        $self->_print_pending_string;
    }
    ### <where> - leaving before_method
	return $passed_ref;
}

sub _print_after_method{
    my ( $self, $passed_ref ) = @_;
    ### <where> - reached the print after_method ...
    #### <where> - received input: $passed_ref
	##### <where> - self: $self
	my  $should_print = $self->_dispatch_method(
		$after_method_dispatch,
		$passed_ref->{primary_type}, 
		$passed_ref,
	);
	### <where> - Should Print: $should_print
    if( $should_print ){
		### <where> - found a line that should print ...
        $self->_print_pending_string;
    }
    ### <where> - after_method complete
    #### <where> - returning: $passed_ref
    return $passed_ref;
}

sub _add_to_pending_string{
    my ( $self, $string ) = @_;
    ### <where> - reached _add_to_pending_string
    ### <where> - adding: $string
    $self->_set_pending_string( 
        (($self->_has_pending_string) ?
            $self->_get_pending_string : '') . 
        ( ( $string ) ? $string : '' )
    );
    return 1;
}

sub _add_to_match_string{
    my ( $self, $string ) = @_;
    ### <where> - reached _add_to_match_string
    ### <where> - adding: $string
    $self->_set_match_string( 
        (($self->_has_match_string) ?
            $self->_get_match_string : '') . 
        ( ( $string ) ? $string : '' )
    );
    return 1;
}

sub _print_pending_string{
    my ( $self, $input ) = @_;
    ### <where> - reached print pending string ...
	### <where> - called with additional input: $input
	#### <where> - match_highlighting called: $self->has_match_highlighting
	#### <where> - match_highlighting on: $self->get_match_highlighting
	#### <where> - secondary_ref exists: $self->_get_had_secondary
	#### <where> - has pending match string: $self->_has_match_string
    if( $self->_has_pending_string ){
        my	$new_string = $self->_add_tabs( $self->_get_current_level );
			$new_string .= $self->_get_pending_string;
			$new_string .= $input if $input;
            if(	$self->has_match_highlighting and
                $self->get_match_highlighting and
                $self->_get_had_secondary and
                $self->_has_match_string        ){
                ### <where> - match_highlighting on - adding match string
                $new_string .= $self->_get_match_string;
            }
            $new_string .= "\n";
        ### <where> - printing string: $new_string
		if( $self->get_to_string ){
			$self->_add_to_final_string( $new_string );
		}else{
			print  $new_string;
		}
    }
    $self->_clear_pending_string;
    $self->_clear_match_string;
    return 1;
}

sub _before_hash_pre_string{
    my ( $self, $passed_ref, $branch_ref ) = @_;
    ### <where> - reached _before_hash_pre_string ...
	#### <where> - passed ref: $passed_ref
	$self->_add_to_pending_string( $branch_ref->[1] . ' => ' );
	$self->_add_to_match_string(
		( $passed_ref->{secondary_type} ne 'DNE' ) ? 
			'Hash Key Match - ' : 'Hash Key Mismatch - '
	);
	### <where> - current pending string: $self->_get_pending_string
	### <where> - current match string: $self->_get_match_string
}

sub _before_array_pre_string{
    my ( $self, $passed_ref, $branch_ref ) = @_;
    ### <where> - reached _before_array_pre_string ...
	#### <where> - passed ref: $passed_ref
	$self->_add_to_match_string(
		( $passed_ref->{secondary_type} ne 'DNE' ) ? 
			'Position Exists - ' : 'No Matching Position - '
	);
	### <where> - current pending string: $self->_get_pending_string
	### <where> - current match string: $self->_get_match_string
}

sub _before_hash_printing{
    my ( $self, $passed_ref ) = @_;
    ### <where> - reached _before_hash_printing ...
	$self->_add_to_pending_string( '{' );
	$self->_add_to_match_string(
		( $passed_ref->{secondary_type} eq 'HASH' ) ? 
			'Ref Type Match' : 'Ref Type Mismatch'
	);
	### <where> - current pending string: $self->_get_pending_string
	### <where> - current match string: $self->_get_match_string
    return 1;
}

sub _before_array_printing{
    my ( $self, $passed_ref ) = @_;
    ### <where> - reached _before_array_printing ...
	#### <where> - passed ref: $passed_ref
	$self->_add_to_pending_string( '[' );
	$self->_add_to_match_string(
		( $passed_ref->{secondary_type} eq 'ARRAY' ) ? 
			'Ref Type Match' : 'Ref Type Mismatch'
	);
	### <where> - current pending string: $self->_get_pending_string
	### <where> - current match string: $self->_get_match_string
    return 1;
}

sub _before_object_printing{
    my ( $self, $passed_ref ) = @_;
    ### <where> - reached _before_object_printing ...
	#### <where> - passed ref: $passed_ref
	$self->_add_to_pending_string( 'BLESS : [' );
	$self->_add_to_match_string(
		( $passed_ref->{secondary_type} eq 'ARRAY' ) ? 
			'Ref Type Match' : 'Ref Type Mismatch'
	);
	### <where> - current pending string: $self->_get_pending_string
	### <where> - current match string: $self->_get_match_string
    return 1;
}

sub _after_scalar_printing{
    my ( $self, $passed_ref, ) = @_;
    ### <where> - reached _after_scalar_printing ...
	##### <where> - passed ref: $passed_ref
	$self->_add_to_pending_string(
		(
			( is_Num( $passed_ref->{primary_ref} )  ) ?
				$passed_ref->{primary_ref} : 
				"'$passed_ref->{primary_ref}'" 
		) . ','
	);
	$self->_add_to_match_string(
		( $passed_ref->{match} eq 'YES' ) ? 
			'Scalar Value Matches' : 
			'Scalar Value Does NOT Match'
	);
	### <where> - current pending string: $self->_get_pending_string
	### <where> - current match string: $self->_get_match_string
	return 1;
}

sub _after_undef_printing{
    my ( $self, $passed_ref, ) = @_;
    ### <where> - reached _after_scalar_printing ...
	##### <where> - passed ref: $passed_ref
	$self->_add_to_pending_string( 
		"undef," 
	);
	### <where> - current pending string: $self->_get_pending_string
	return 1;
}

sub _after_array_printing{
    my ( $self, $passed_ref ) = @_;
    ### <where> - reached _after_array_printing ...
	##### <where> - passed ref: $passed_ref
	if( $passed_ref->{skip} eq 'YES' ){
		$self->_add_to_pending_string( $passed_ref->{primary_ref} . ',' );
	}else{
		$self->_add_to_pending_string( '],' );
	}
	### <where> - current pending string: $self->_get_pending_string
	return 1;
}

sub _after_hash_printing{
    my ( $self, $passed_ref, $skip_method ) = @_;
    ### <where> - reached _after_hash_printing ...
	##### <where> - passed ref: $passed_ref
	if( $passed_ref->{skip} eq 'YES' ){
		$self->_add_to_pending_string( $passed_ref->{primary_ref} . ',' );
	}else{
		$self->_add_to_pending_string( '},' );
	}
	### <where> - current pending string: $self->_get_pending_string
	return 1;
}

sub _after_object_printing{
    my ( $self, $passed_ref, $skip_method ) = @_;
    ### <where> - reached _after_object_printing ...
	##### <where> - passed ref: $passed_ref
	if( $passed_ref->{skip} eq 'YES' ){
		$self->_add_to_pending_string( $passed_ref->{primary_ref} . ',' );
	}else{
		$self->_add_to_pending_string( '},' );
	}
	### <where> - current pending string: $self->_get_pending_string
	return 1;
}

sub _add_tabs{
    my ( $self, $current_level ) = @_;
    ### <where> - reached _add_tabs ...
	##### <where> - current level: $current_level
    return ("\t" x $current_level);
}

#########1 Phinish Strong     3#########4#########5#########6#########7#########8#########9

no Moose::Role;

1;
# The preceding line will help the module return a true value

#########1 Main POD starts    3#########4#########5#########6#########7#########8#########9

__END__

=head1 NAME

Data::Walk::Print - A data printing function

=head1 SYNOPSIS
    
	#!perl
	use YAML::Any;
	use Moose::Util qw( with_traits );
	use Data::Walk::Extracted;
	use Data::Walk::Print;

	#Use YAML to compress writing the data ref
	my  $firstref = Load(
		'---
		Someotherkey:
			value
		Parsing:
			HashRef:
				LOGGER:
					run: INFO
		Helping:
			- Somelevel
			- MyKey:
				MiddleKey:
					LowerKey1: lvalue1
					LowerKey2:
						BottomKey1: 12345
						BottomKey2:
						- bavalue1
						- bavalue2
						- bavalue3'
	);
	my  $secondref = Load(
		'---
		Someotherkey:
			value
		Helping:
			- Somelevel
			- MyKey:
				MiddleKey:
					LowerKey1: lvalue1
					LowerKey2:
						BottomKey2:
						- bavalue1
						- bavalue3
						BottomKey1: 12354'
	);
	my $AT_ST = with_traits( 
			'Data::Walk::Extracted', 
			( 'Data::Walk::Print' ),
		)->new(
			match_highlighting => 1,#This is the default
		);
	$AT_ST->print_data(
		print_ref	=>  $firstref,
		match_ref	=>  $secondref, 
		sorted_nodes =>{
			HASH => 1, #To force order for demo purposes
		}
	);
    
	#################################################################################
	#     Output of SYNOPSIS
	# 01:{#<--- Ref Type Match
	# 02:	Helping => [#<--- Secondary Key Match - Ref Type Match
	# 03:		'Somelevel',#<--- Secondary Position Exists - Secondary Value Matches
	# 04:		{#<--- Secondary Position Exists - Ref Type Match
	# 05:			MyKey => {#<--- Secondary Key Match - Ref Type Match
	# 06:				MiddleKey => {#<--- Secondary Key Match - Ref Type Match
	# 07:					LowerKey1 => 'lvalue1',#<--- Secondary Key Match - Secondary Value Matches
	# 08:					LowerKey2 => {#<--- Secondary Key Match - Ref Type Match
	# 09:						BottomKey1 => '12345',#<--- Secondary Key Match - Secondary Value Does NOT Match
	# 10:						BottomKey2 => [#<--- Secondary Key Match - Ref Type Match
	# 11:							'bavalue1',#<--- Secondary Position Exists - Secondary Value Matches
	# 12:							'bavalue2',#<--- Secondary Position Exists - Secondary Value Does NOT Match
	# 13:							'bavalue3',#<--- Secondary Position Does NOT Exist - Secondary Value Does NOT Match
	# 14:						],
	# 15:					},
	# 16:				},
	# 17:			},
	# 18:		},
	# 19:	],
	# 20:	Parsing => {#<--- Secondary Key Mismatch - Ref Type Mismatch
	# 21:		HashRef => {#<--- Secondary Key Mismatch - Ref Type Mismatch
	# 22:			LOGGER => {#<--- Secondary Key Mismatch - Ref Type Mismatch
	# 23:				run => 'INFO',#<--- Secondary Key Mismatch - Secondary Value Does NOT Match
	# 24:			},
	# 25:		},
	# 26:	},
	# 27:	Someotherkey => 'value',#<--- Secondary Key Match - Secondary Value Matches
	# 28:},
	#################################################################################

 
=head1 DESCRIPTION

This L<Moose::Role|https://metacpan.org/module/Moose::Manual::Roles> is mostly written 
as a demonstration module for 
L<Data::Walk::Extracted|https://metacpan.org/module/Data::Walk::Extracted>.  
Both L<Data::Dumper|https://metacpan.org/module/Data::Dumper#Functions> - Dumper and 
L<YAML|https://metacpan.org/module/YAML::Any#SUBROUTINES> - Dump functions are more mature than 
the printing function included here.

=head2 USE

This is a L<Moose::Role|https://metacpan.org/module/Moose::Manual::Roles> specifically 
designed to be used with L<Data::Walk::Extracted
|https://metacpan.org/module/Data::Walk::Extracted#Extending-Data::Walk::Extracted>.  
It can be combined traditionaly to the ~::Extracted class using L<Moose
|https://metacpan.org/module/Moose::Manual::Roles> methods or for information on how to join 
this role to Data::Walk::Extracted at run time see L<Moose::Util
|https://metacpan.org/module/Moose::Util> or L<MooseX::ShortCut::BuildInstance
|https://metacpan.org/module/MooseX::ShortCut::BuildInstance> for more information.

=head1 Attributes

Data passed to -E<gt>new when creating an instance.  For modification of these attributes 
see L<Methods|/Methods>.  The -E<gt>new function will either accept fat comma lists or a 
complete hash ref that has the possible attributes as the top keys.  Additionally 
some attributes that have all the following methods; get_$attribute, set_$attribute, 
has_$attribute, and clear_$attribute, can be passed to L<print_data
|/print_data( $arg_ref|%args|$data_ref )> and will be adjusted for just the run of that 
method call.  These are called 'one shot' attributes.  The class and each role (where 
applicable) in this package have a list of L<supported one shot attributes
|/Supported one shot attributes>.

=head2 match_highlighting

=over

B<Definition:> this determines if a comments string is added after each printed 
row that indicates how the 'print_ref' matches the 'match_ref'.

B<Default> True (1)

B<Range> This is a Boolean data type and generally accepts 1 or 0
    
=back

=head2 to_string

=over

B<Definition:> this determines whether the output is sent to STDOUT or coallated 
into a final string and sent as a result of L<print_data
|/print_data( $arg_ref|%args|$data_ref )>.

B<Default> True (1)

B<Range> This is a Boolean data type and generally accepts 1 or 0
    
=back

=head2 (see also)

L<Data::Walk::Extracted|https://metacpan.org/module/Data::Walk::Extracted#Attributes> 
- Attributes

=head1 Methods

=head2 print_data( $arg_ref|%args|$data_ref )

=over

B<Definition:> this is the method used to print a data reference

B<Accepts:> either a single data reference or named arguments 
in a fat comma list or hashref

=over

B<named variable option> - if data comes in a fat comma list or as a hash ref 
and the keys include a 'print_ref' key then the list is processed as follows.

=over

B<print_ref> - this is the data reference that should be printed in a perlish way 
- Required

B<match_ref> - this is a reference used to compare against the 'print_ref'
- Optional

B<[attribute name]> - attribute names are accepted with temporary attribute settings.  
These settings are temporarily set for a single "print_data" call and then the original 
attribute values are restored.  For this to work the the attribute must meet the 
L<necessary criteria|/Attributes>.  These attributes can include all attributes active 
for the constructed class not just this role.

=back

B<single variable option> - if only one data_ref is sent and it fails the test 
for "exists $data_ref->{print_ref}" then the program will attempt to name it as 
print_ref => $data_ref and then process the data as a fat comma list.

=back

B<Returns:> 1 (And prints out the data ref) or a string - see L<to_string|/to_string>

=back

=head2 set_match_highlighting( $bool )

=over

B<Definition:> this is a way to change the L<match_highlighting|/match_highlighting> 
attribute

B<Accepts:> a Boolean value

B<Returns:> ''

=back

=head2 get_match_highlighting

=over

B<Definition:> this is a way to view the state of the L<match_highlighting|/match_highlighting> 
attribute

B<Accepts:> nothing

B<Returns:> The current 'match_highlighting' state

=back

=head2 has_match_highlighting

=over

B<Definition:> this is a way to know if the L<match_highlighting|/match_highlighting> 
attribute is active

B<Accepts:> nothing

B<Returns:> 1 if the attribute is active (not just if it == 1)

=back

=head2 clear_match_highlighting

=over

B<Definition:> this clears the L<match_highlighting|/match_highlighting> attribute

B<Accepts:> nothing

B<Returns:> '' (always successful)

=back

=head2 set_to_string( $bool )

=over

B<Definition:> this is a way to change the L<to_string|/to_string> 
attribute

B<Accepts:> a Boolean value

B<Returns:> ''

=back

=head2 get_to_string

=over

B<Definition:> this is a way to view the state of the L<to_string|/to_string> 
attribute

B<Accepts:> nothing

B<Returns:> The current 'to_string' state

=back

=head2 has_to_string

=over

B<Definition:> this is a way to know if the L<to_string|/to_string> 
attribute is active

B<Accepts:> nothing

B<Returns:> 1 if the attribute is active (not just if it == 1)

=back

=head2 clear_to_string

=over

B<Definition:> this clears the L<to_string|/to_string> attribute

B<Accepts:> nothing

B<Returns:> '' (always successful)

=back

=head1 Caveat utilitor

=head2 Supported Node types

=over

=item ARRAY

=item HASH

=item SCALAR

=item UNDEF

=back

=head2 Supported one shot attributes

L<explanation|/Attributes>

=over

=item match_highlighting

=item to_string

=back

=head2 Printing for skipped nodes

L<Data::Walk::Extracted|https://metacpan.org/module/Data::Walk::Extracted> allows for some 
nodes to be skipped.  When a node is skipped the L<print_data
|/print_data( $arg_ref|%args|$data_ref )> function prints the scalar (perl pointer description) 
of that node.

=head1 GLOBAL VARIABLES

=over

B<$ENV{Smart_Comments}>

The module uses L<Smart::Comments|https://metacpan.org/module/Smart::Comments> if the '-ENV' 
option is set.  The 'use' is encapsulated in an if block triggered by an environmental 
variable to comfort non-believers.  Setting the variable $ENV{Smart_Comments} in a BEGIN 
block will load and turn on smart comment reporting.  There are three levels of 'Smartness' 
available in this module '###',  '####', and '#####'.

=back

=head1 SUPPORT

=over

L<github Data-Walk-Extracted/issues|https://github.com/jandrew/Data-Walk-Extracted/issues>

=back

=head1 TODO

=over

B<1.> Convert from L<Smart::Comments|https://metacpan.org/module/Smart::Comments> debugging 
to L<Log::Shiras|https://metacpan.org/module/Log::Shiras> debugging messages.

B<2.> Support printing Objects / Instances

B<3.> Support printing CodeRefs

B<4.> Support REF types

=back

=head1 AUTHOR

=over

=item Jed Lund

=item jandrew@cpan.org

=back

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

This software is copyrighted (c) 2013 by Jed Lund.

=head1 Dependencies

L<version|https://metacpan.org/module/version>

L<Moose::Role|https://metacpan.org/module/Moose::Role>

=over

B<requires>

=over

=item _process_the_data

=item _get_had_secondary

=item _dispatch_method

=back

=back

L<MooseX::Types::Moose|https://metacpan.org/module/MooseX::Types::Moose>

L<Data::Walk::Extracted|https://metacpan.org/module/Data::Walk::Extracted>

L<Data::Walk::Extracted::Dispatch|https://metacpan.org/module/Data::Walk::Extracted::Dispatch>


=head1 SEE ALSO

=over

L<Smart::Comments|https://metacpan.org/module/Smart::Comments> - is used if the -ENV option is set

L<Data::Walk|https://metacpan.org/module/Data::Walk>

L<Data::Walker|https://metacpan.org/module/Data::Walker>

L<Data::Dumper|https://metacpan.org/module/Data::Dumper> - Dumper

L<YAML|https://metacpan.org/module/YAML> - Dump

L<Data::Walk::Prune|https://metacpan.org/module/Data::Walk::Prune> - available Data::Walk::Extracted Role

L<Data::Walk::Graft|https://metacpan.org/module/Data::Walk::Graft> - available Data::Walk::Extracted Role

L<Data::Walk::Clone|https://metacpan.org/module/Data::Walk::Clone> - available Data::Walk::Extracted Role

=back

=cut

#########1 Main POD ends      3#########4#########5#########6#########7#########8#########9