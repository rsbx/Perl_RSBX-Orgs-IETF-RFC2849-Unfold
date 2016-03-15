#  Copyright (c) 2016, Raymond S Brand
#  All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions
#  are met:
#
#   * Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#
#   * Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in
#     the documentation and/or other materials provided with the
#     distribution.
#
#   * Redistributions in source or binary form must carry prominent
#     notices of any modifications.
#
#   * Neither the name of Raymond S Brand nor the names of its other
#     contributors may be used to endorse or promote products derived
#     from this software without specific prior written permission.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
#  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
#  FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
#  COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
#  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
#  BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
#  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
#  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
#  ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#  POSSIBILITY OF SUCH DAMAGE.


package RSBX::Orgs::IETF::RFC2849::Unfold v0.3.1.0;


use strict;
use warnings;


require Exporter;
our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( );
our @EXPORT_OK = ( );
our @EXPORT = qw( );


my @optionKeys =
		(
		'RE_Empty',
		'RE_Nonfolded',
		'RE_Continuation',
		'InputTransform',
		);


sub _NullTransform
	{
	my ($line, $lineno) = @_;

	return ($line, $lineno);
	}


sub New
	{
	my ($package, $fh, %options) = @_;

	$package = ref($package) || $package;

	my $self =
		{
		'Accumulator'		=> undef,
		'FileHandle'		=> $fh,
		'InputLineNumber'	=> 0,
		'OutputLineNumber'	=> undef,
		'OutputQueue'		=> [],
		'EOF'			=> undef,
		'RE_Empty'		=> '^()$',
		'RE_Nonfolded'		=> '^([^ ].*)$',
		'RE_Continuation'		=> '^ (.*)$',
		'InputTransform'	=> [\&_NullTransform, ],
		};

	foreach my $key (@optionKeys)
		{
		if (defined $options{$key})
			{
			$self->{$key} = $options{$key};
			}
		}

	return bless $self, $package;
	}


sub GetLine
	{
	my ($self) = @_;

	if (scalar(@{$self->{'OutputQueue'}}))		# Queued
		{
		return (@{shift @{$self->{'OutputQueue'}}}, 1);
		}

	if ($self->{'EOF'})				# EOF
		{
		return (undef, undef, 1);
		}

	my $fh = $self->{'FileHandle'};
	my $RE_Empty = $self->{'RE_Empty'};
	my $RE_Nonfolded = $self->{'RE_Nonfolded'};
	my $RE_Continuation = $self->{'RE_Continuation'};
	my @TransformArray = @{$self->{'InputTransform'}};
	my $TransformFunc = shift @TransformArray;

	while (<$fh>)
		{
		chomp;
		$self->{'InputLineNumber'}++;
		my ($linein, $lineno) = &{$TransformFunc}($_, $self->{'InputLineNumber'}, @TransformArray);
		last if !defined $linein;

		if (defined $self->{'Accumulator'})	# Collecting
			{
			if ($linein =~ /$RE_Nonfolded/)		# Nonfolded
				{
				my ($tl, $tn) = ($self->{'Accumulator'}, $self->{'OutputLineNumber'});
				($self->{'Accumulator'}, $self->{'OutputLineNumber'}) = ($1, $lineno);
				return ($tl, $tn, 1);
				}
			elsif ($linein =~ /$RE_Continuation/)	# Continuation
				{
				$self->{'Accumulator'} .= $1;
				}
			elsif ($linein =~ /$RE_Empty/)		# Empty
				{
				push @{$self->{'OutputQueue'}}, [$1, $lineno];

				my ($tl, $tn) = ($self->{'Accumulator'}, $self->{'OutputLineNumber'});
				($self->{'Accumulator'}, $self->{'OutputLineNumber'}) = (undef, undef);
				return ($tl, $tn, 1);
				}
			else					# Other
				{
				return ($linein, $lineno, 0);
				}
			}
		else					# Idle
			{
			if ($linein =~ /$RE_Nonfolded/)		# Nonfolded
				{
				($self->{'Accumulator'}, $self->{'OutputLineNumber'}) = ($1, $lineno);
				}
			elsif ($linein =~ /$RE_Continuation/)	# Continuation
				{
				return ($linein, $lineno, 0);
				}
			elsif ($linein =~ /$RE_Empty/)		# Empty
				{
				return ($1, $lineno, 1);
				}
			else					# Other
				{
				return ($linein, $lineno, 0);
				}
			}
		}

	$self->{'EOF'} = 1;

	my ($tl, $tn) = ($self->{'Accumulator'}, $self->{'OutputLineNumber'});
	($self->{'Accumulator'}, $self->{'OutputLineNumber'}) = (undef, undef);
	return ($tl, $tn, 1);
	}


1;


__END__


=pod

=head1 NAME

RSBX::Orgs::IETF::RFC2849::Unfold - Undo RFC-2849 (LDIF) line folding.

=head1 SYNOPSIS

 use RSBX::Orgs::IETF::RFC2849::Unfold;
 ...
 open(my $file_handle, '<', $file_name) || die;
 ...
 $input_obj = RSBX::Orgs::IETF::RFC2849::Unfold->New(
         $file_handle,
         OPTIONS
         );

 while ((($line, $line_no, $status) = $input_obj->GetLine())
         && defined($line))
     {
     next if !$status;
     ...
     }
 close($file_handle);
 ...
 unmap $input_obj;

=head1 DESCRIPTION

RSBX::Orgs::IETF::RFC2849::Unfold transforms lines from an input source to a sequence of
non-folded output lines. By default the line processing conforms to the
notes on line folding in L<RFC 2849|/SEE ALSO> but can be, optionally, modified for
special requirements via options.

=head1 CONSTRUCTOR

=over 4

=item New ( I<File_Handle> [, OPTIONS ] )

Create and initialize a new unfolding object.

=over 4

=item I<File_Handle>

An already open filehandle to the source of the (possibly) folded input lines.

=item OPTIONS

Name/value pairs that affect the unfolding operation and/or results.

=over 4

=item C<'RE_Nonfolded'> =E<gt> I<string>

Regular expression that identifies an input line as an non-folded line or the start of a folded line.

Capture group 1 will be part of the resulting output line.

Default: C<'^([^ ].*)$'>

=item C<'RE_Continuation'> =E<gt> I<string>

Regular expression that identifies an input line as a continuation part of a folded line.

Capture group 1 will be part of the resulting output line.

Default: C<'^ (.*)$'>

=item C<'RE_Empty'> =E<gt> I<string>

Regular expression that identifies input line as an empty non-folded line.

Capture group 1 will be the resulting line.

Default: C<'^()$'>

=item C<'InputTransform'> =E<gt> I<ARRAY reference>

See L<INPUTTRANSFORM REQUIREMENTS> for details.

Default: C<undef>

=back

=item RETURNS

An initialized unfolding object if there were no errors. Or C<undef> if there was an error.

=back

=back

=head1 METHODS

=over 4

=item GetLine ( )

Read and process input lines until a new output line is complete.

=over 4

=item RETURNS

An I<ARRAY> containing:

=over 4

=over 4

=item Output line

The next output line. Or C<undef> if EOF has been encountered.

=item Line number

The input line number where the output line started. Or C<undef> if EOF has been encountered.

=item Status

A I<boolean> indicating if the line conformed to the expectations set forth in
L<RFC 2849|/SEE ALSO>; possibly modified by the options to C<New> constructor.

=back

=back

=back

=back

=head1 INPUTTRANSFORM REQUIREMENTS

The input transformation is specified by providing an I<ARRAY reference> with
a I<CODE reference> as the first element and any additional parameters as
subsequent elements.

The C<CODE reference> is invoked with the current input line and current
input line number as the first two parameters and any additional parameters
from the specification I<ARRAY reference> as subsequent parameters.

The C<CODE reference> is expected to return an I<ARRAY> containing:

=over 4

=over 4

=item Transformed input line

C<undef> indicating EOF.

=item Transformed input line number

=back

=back

=head1 BUGS AND LIMITATIONS

=over 4

=item * Almost no parameter validation is performed. Code wisely.

=back

Please report problems to Raymond S Brand E<lt>rsbx@acm.orgE<gt>.

Problem reports without included demonstration code and/or tests will be ignored.

Patches are welcome.

=head1 SEE ALSO

L<RFC 2849|https://www.ietf.org/rfc/rfc2849.txt>

=head1 THEORY OF OPERATION

Input lines are classified via regular expressions into one of the following
line types:

=over 4

=over 4

=item Nonfolded

Lines that match the C<'RE_Nonfolded'> regular expression.

These lines are non-folded and complete or are a prefix of the next non-folded
output line. These lines signal completion of the prior non-folded output line, if any.

=item Continuation

Lines that match the C<'RE_Continuation'> regular expression.

These lines be part of a non-folded output line if the previous input line
was a I<Nonfolded> line or was a I<Continuation> line. Otherwise these input lines
are considered non-conformant (with L<RFC 2849|/SEE ALSO>).

=item Empty

Lines that match the C<'RE_Empty'> regular expression.

These lines are non-folded and complete and signal copmpletion of the prior non-folded output line, if any.

=item Other

All other input lines. By default, no input lines will be classified as this
type. These lines are considered non-conformant (with L<RFC 2849|/SEE ALSO>).

=back

=back

Input lines are read in, classified, and concatenated into a non-folded line
until a non-folded line completion condition it met. Then, the completed
non-folded line is returned to the caller, along with the input line number of
the first input line in the returned non-folded line, and a I<boolean> status
indicating whether or not the line is conformant.

Non-conformat input lines are returned to the caller, along with the input
line number, and a I<false> status.

EOF is signaled to the caller by the first element of the returned array set
to C<undef>.


=head1 AUTHOR

Raymond S Brand E<lt>rsbx@acm.orgE<gt>

=head1 COPYRIGHT

Copyright (c) 2016 Raymond S Brand. All rights reserved.

=head1 LICENSE

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

=over 4

=item *

Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

=item *

Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in
the documentation and/or other materials provided with the
distribution.

=item *

Redistributions in source or binary form must carry prominent
notices of any modifications.

=item *

Neither the name of Raymond S Brand nor the names of its other
contributors may be used to endorse or promote products derived
from this software without specific prior written permission.

=back

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

=cut
