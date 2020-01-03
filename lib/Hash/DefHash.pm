## no critic: Modules::ProhibitAutomaticExportation

package Hash::DefHash;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;

use Scalar::Util qw(blessed);
use String::Trim::More qw(trim_blank_lines);

use Exporter qw(import);
our @EXPORT = qw(defhash);

our $re_prop = qr/\A[A-Za-z_][A-Za-z0-9_]*\z/;
our $re_attr = qr/\A[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*\z/;
our $re_key  = qr/
    \A(?:
        # 1 = property
        ([A-Za-z_][A-Za-z0-9_]*)
        (?:
            (?:
                # 2 = attr
                \. ([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)
            ) |
            (?:
                # 3 = (LANG) shortcut
                \(([A-Za-z]{2}(?:_[A-Za-z]{2})?)\)
            )
        )?
    |
        # 4 = attr without property
        \.([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)
    )\z/x;

sub defhash {
    # avoid wrapping twice if already a defhash
    return $_[0] if blessed($_[0]) && $_[0]->isa(__PACKAGE__);

    __PACKAGE__->new(@_);
}

sub new {
    my $class = shift;

    my ($hash, %opts) = @_;
    $hash //= {};

    my $self = bless {hash=>$hash, parent=>$opts{parent}}, $class;
    if ($opts{check} // 1) {
        $self->check;
    }
    $self;
}

sub hash {
    my $self = shift;

    $self->{hash};
}

sub check {
    my $self = shift;
    my $h = $self->{hash};

    for my $k (keys %$h) {
        next if $k =~ $re_key;
        die "Invalid hash key '$k'";
    }
    1;
}

sub contents {
    my $self = shift;
    my $h = $self->{hash};

    my %props;
    for my $k (keys %$h) {
        my ($p_prop, $p_attr, $p_lang, $p_attr_wo_prop) = $k =~ $re_key
            or die "Invalid hash key '$k'";
        my $v = $h->{$k};
        if (defined $p_prop) {
            next if $p_prop =~ /\A_/;
            $props{$p_prop} //= {};
            if (defined $p_attr) {
                next if $p_attr =~ /(?:\A|\.)_/;
                $props{$p_prop}{$p_attr} = $v;
            } elsif (defined $p_lang) {
                $props{$p_prop}{"alt.lang.$p_lang"} = $v;
            } else {
                $props{$p_prop}{""} = $v;
            }
        } else {
            next if $p_attr_wo_prop =~ /(?:\A|\.)_/;
            $props{""} //= {};
            $props{""}{$p_attr_wo_prop} = $v;
        }
    }
    %props;
}

sub props {
    my $self = shift;
    my $h = $self->{hash};

    my %props;
    for my $k (keys %$h) {
        my ($p_prop, $p_attr, $p_lang, $p_attr_wo_prop) = $k =~ $re_key
            or die "Invalid hash key '$k'";
        next if defined $p_attr || $p_lang || defined $p_attr_wo_prop;
        next if $p_prop =~ /\A_/;
        $props{$p_prop}++;
    }
    sort keys %props;
}

sub prop {
    my ($self, $prop) = @_;
    my $h = $self->{hash};

    die "Property '$prop' not found" unless exists $h->{$prop};
    $h->{$prop};
}

sub get_prop {
    my ($self, $prop) = @_;
    my $h = $self->{hash};

    $h->{$prop};
}

sub prop_exists {
    my ($self, $prop) = @_;
    my $h = $self->{hash};

    exists $h->{$prop};
}

sub add_prop {
    my ($self, $prop, $val) = @_;
    my $h = $self->{hash};

    die "Invalid property name '$prop'" unless $prop =~ $re_prop;
    die "Property '$prop' already exists" if exists $h->{$prop};
    $h->{$prop} = $val;
}

sub set_prop {
    my ($self, $prop, $val) = @_;
    my $h = $self->{hash};

    die "Invalid property name '$prop'" unless $prop =~ $re_prop;
    if (exists $h->{$prop}) {
        my $old = $h->{$prop};
        $h->{$prop} = $val;
        return $old;
    } else {
        $h->{$prop} = $val;
        return undef;
    }
}

sub del_prop {
    my ($self, $prop, $val) = @_;
    my $h = $self->{hash};

    die "Invalid property name '$prop'" unless $prop =~ $re_prop;
    if (exists $h->{$prop}) {
        return delete $h->{$prop};
    } else {
        return undef;
    }
}

sub del_all_props {
    my ($self, $delattrs) = @_;
    my $h = $self->{hash};

    for my $k (keys %$h) {
        my ($p_prop, $p_attr, $p_lang, $p_attr_wo_prop) = $k =~ $re_key
            or die "Invalid hash key '$k'";
        next if defined $p_prop && $p_prop =~ /\A_/;
        next if defined $p_attr && $p_attr =~ /(?:\A|\.)_/;
        next if defined $p_attr_wo_prop && $p_attr_wo_prop =~ /(?:\A|\.)_/;
        if (defined $p_attr || defined $p_lang || defined $p_attr_wo_prop) {
            delete $h->{$k} if $delattrs;
        } else {
            delete $h->{$k};
        }
    }
}

sub attrs {
    my ($self, $prop) = @_;
    $prop //= "";
    my $h = $self->{hash};

    unless ($prop eq '') {
        die "Invalid property name '$prop'" unless $prop =~ $re_prop;
    }

    my %attrs;
    for my $k (keys %$h) {
        my ($p_prop, $p_attr, $p_lang, $p_attr_wo_prop) = $k =~ $re_key
            or die "Invalid hash key '$k'";
        $p_prop //= '';
        my $v = $h->{$k};
        if (defined $p_attr) {
            next unless $prop eq $p_prop;
            next if $p_attr =~ /(?:\A|\.)_/;
            $attrs{$p_attr} = $v;
        } elsif (defined $p_lang) {
            next unless $prop eq $p_prop;
            $attrs{"alt.lang.$p_lang"} = $v;
        } elsif (defined $p_attr_wo_prop) {
            next unless $prop eq '';
            next if $p_attr_wo_prop =~ /(?:\A|\.)_/;
            $attrs{$p_attr_wo_prop} = $v;
        }
    }
    %attrs;
}

sub attr {
    my ($self, $prop, $attr) = @_;
    $prop //= "";
    my $h = $self->{hash};

    my $k = "$prop.$attr";
    die "Attribute '$attr' for property '$prop' not found" if !exists($h->{$k});
    $h->{$k};
}

sub get_attr {
    my ($self, $prop, $attr) = @_;
    $prop //= "";
    my $h = $self->{hash};

    my $k = "$prop.$attr";
    $h->{$k};
}

sub attr_exists {
    my ($self, $prop, $attr) = @_;
    $prop //= "";
    my $h = $self->{hash};

    my $k = "$prop.$attr";
    exists $h->{$k};
}

sub add_attr {
    my ($self, $prop, $attr, $val) = @_;
    $prop //= "";
    my $h = $self->{hash};

    if ($prop ne '') {
        die "Invalid property name '$prop'"  unless $prop =~ $re_prop;
    }
    die "Invalid attribute name '$attr'" unless $attr =~ $re_attr;
    my $k = "$prop.$attr";
    die "Attribute '$attr' for property '$prop' already exists"
        if exists($h->{$k});
    $h->{$k} = $val;
}

sub set_attr {
    my ($self, $prop, $attr, $val) = @_;
    $prop //= "";
    my $h = $self->{hash};

    if ($prop ne '') {
        die "Invalid property name '$prop'"  unless $prop =~ $re_prop;
    }
    die "Invalid attribute name '$attr'" unless $attr =~ $re_attr;
    my $k = "$prop.$attr";
    if (exists($h->{$k})) {
        my $old = $h->{$k};
        $h->{$k} = $val;
        return $old;
    } else {
        $h->{$k} = $val;
        return undef;
    }
}

sub del_attr {
    my ($self, $prop, $attr) = @_;
    $prop //= "";
    my $h = $self->{hash};

    if ($prop ne '') {
        die "Invalid property name '$prop'"  unless $prop =~ $re_prop;
    }
    die "Invalid attribute name '$attr'" unless $attr =~ $re_attr;
    my $k = "$prop.$attr";
    if (exists($h->{$k})) {
        return delete $h->{$k};
    } else {
        return undef;
    }
}

sub del_all_attrs {
    my ($self, $prop) = @_;
    $prop //= "";
    my $h = $self->{hash};

    for my $k (keys %$h) {
        my ($p_prop, $p_attr, $p_lang, $p_attr_wo_prop) = $k =~ $re_key
            or die "Invalid hash key '$k'";
        if (defined $p_attr) {
            next unless $prop eq $p_prop;
            next if $p_attr =~ /(?:\A|\.)_/;
        } elsif ($p_lang) {
            next unless $prop eq $p_prop;
        } elsif (defined $p_attr_wo_prop) {
            next unless $prop eq '';
            next if $p_attr_wo_prop =~ /(?:\A|\.)_/;
        } else {
            next;
        }
        delete $h->{$k};
    }
}

sub defhash_v {
    my ($self) = @_;
    $self->get_prop('defhash_v') // 1;
}

sub v {
    my ($self) = @_;
    $self->get_prop('v') // 1;
}

sub default_lang {
    my ($self) = @_;
    my $par;
    if ($self->{parent}) {
        $par = $self->{parent}->default_lang;
    }
    my $res = $self->get_prop('default_lang') // $par // $ENV{LANG} // "en_US";
    $res = "en_US" if $res eq "C";
    $res;
}

sub name {
    my ($self) = @_;
    $self->get_prop('name');
}

sub summary {
    my ($self) = @_;
    $self->get_prop('summary');
}

sub description {
    my ($self) = @_;
    $self->get_prop('description');
}

sub tags {
    my ($self) = @_;
    $self->get_prop('tags');
}

sub get_prop_lang {
    my ($self, $prop, $lang, $opts) = @_;
    my $h = $self->{hash};
    $opts //= {};

    my $deflang = $self->default_lang;
    $lang     //= $deflang;
    my $mark    = $opts->{mark_different_lang} // 1;
    #print "deflang=$deflang, lang=$lang, mark_different_lang=$mark\n";

    my @k;
    if ($lang eq $deflang) {
        @k = ([$lang, $prop, 0]);
    } else {
        @k = ([$lang, "$prop.alt.lang.$lang", 0], [$deflang, $prop, $mark]);
    }

    for my $k (@k) {
        #print "k=".join(", ", @$k)."\n";
        my $v = $h->{$k->[1]};
        if (defined $v) {
            if ($k->[2]) {
                my $has_nl = $v =~ s/\R\z//;
                $v = "{$k->[0] $v}" . ($has_nl ? "\n" : "");
            }
            return trim_blank_lines($v);
        }
    }
    return undef;
}

sub get_prop_all_langs {
    die "Not yet implemented";
}

sub set_prop_lang {
    die "Not yet implemented";
}

1;
# ABSTRACT: Manipulate defhash

=head1 SYNOPSIS

 use Hash::DefHash; # imports defhash()

 # create a new defhash object, die when hash is invalid defhash
 $dh = Hash::DefHash->new;                        # creates an empty defhash
 $dh = Hash::DefHash->new({a=>1});                # use the hashref
 $dh = Hash::DefHash->new({"contains space"=>1}); # dies!

 # defhash() is a synonym for Hash::DefHash->new().
 $dh = defhash({foo=>1});

 # return the original hash
 $hash = $dh->hash;

 # list properties
 @props = $dh->props;

 # list property names, values, and attributes, will return ($prop => $attrs,
 # ...). Property values will be put in $attrs with key "". For example:
 %content = DefHash::Hash->new({p1=>1, "p1.a"=>2, p2=>3})->contents;
 # => (p1 => {""=>1, a=>2}, p2=>3)

 # get property value, will die if property does not exist
 $propval = $dh->prop($prop);

 # like prop(), but will return undef if property does not exist
 $propval = $dh->get_prop($prop);

 # check whether property exists
 say "exists" if $dh->prop_exists($prop);

 # add a new property, will die if property already exists
 $dh->add_prop($prop, $propval);

 # add new property, or set value for existing property
 $oldpropval = $dh->set_prop($prop, $propval);

 # delete property, noop if property already does not exist. set $delattrs to
 # true to delete all property's attributes.
 $oldpropval = $dh->del_prop($prop, $delattrs);

 # delete all properties, set $delattrs to true to delete all properties's
 # attributes too.
 $dh->del_all_props($delattrs);

 # get property's attributes. to list defhash attributes, set $prop to undef or
 # ""
 %attrs = $dh->attrs($prop);

 # get attribute value, will die if attribute does not exist
 $attrval = $dh->attr($prop, $attr);

 # like attr(), but will return undef if attribute does not exist
 $attrval = $dh->get_attr($prop, $attr);

 # check whether an attribute exists
 @attrs = $dh->attr_exists($prop, $attr);

 # add attribute to a property, will die if attribute already exists
 $dh->add_attr($prop, $attr, $attrval);

 # add attribute to a property, or set value of existing attribute
 $oldatrrval = $dh->set_attr($prop, $attr, $attrval);

 # delete property's attribute, noop if attribute already does not exist
 $oldattrval = $dh->del_attr($prop, $attr, $attrval);

 # delete all attributes of a property
 $dh->del_all_attrs($prop);

 # get predefined properties
 say $dh->v;            # shortcut for $dh->get_prop('v')
 say $dh->default_lang; # shortcut for $dh->get_prop('default_lang')
 say $dh->name;         # shortcut for $dh->get_prop('name')
 say $dh->summary;      # shortcut for $dh->get_prop('summary')
 say $dh->description;  # shortcut for $dh->get_prop('description')
 say $dh->tags;         # shortcut for $dh->get_prop('tags')

 # get value in alternate languages
 $propval = $dh->get_prop_lang($prop, $lang);

 # get value in all available languages, result is a hash mapping lang => val
 %vals = $dh->get_prop_all_langs($prop);

 # set value for alternative language
 $oldpropval = $dh->set_prop_lang($prop, $lang, $propval);


=head1 FUNCTIONS

=head2 defhash([ $hash ]) => OBJ

Shortcut for C<< Hash::DefHash->new($hash) >>. As a bonus, can also detect if
C<$hash> is already a defhash and returns it immediately instead of wrapping it
again. Exported by default.


=head1 METHODS

=head2 new

Usage:

 $dh = Hash::DefHash->new([ $hash ],[ %opts ]);

Constructor. Create a new Hash::DefHash object, which is a thin OO skin over the
regular Perl hash. If C<$hash> is not specified, a new anonymous hash is
created.

Internally, the object contains a hash reference which contains reference to the
hash (C<< bless({hash=>$orig_hash, ...}, 'Hash::DefHash') >>). It does not
create a copy of the hash or bless the hash directly. Be careful not to assume
that the two are the same!

Will check the keys of hash for invalid properties/attributes and will die if
one is found, e.g..

 $dh = Hash::DefHash->new({"contains space" => 1}); # dies!

Known options:

=over 4

=item * check => BOOL (default: 1)

Whether to check that hash is a valid defhash. Will die if hash turns out to
contain invalid keys/values.

=item * parent => HASH/DEFHASH_OBJ

Set defhash's parent. Default language (C<default_lang>) will follow parent's if
unset in the current hash.

=back

=head2 hash

Usage:

 $hashref = $dh->hash;

Return the original hashref.

=head2 check

Usage:

 $dh->check;

=head2 contents

Usage:

 my %contents = $dh->contents;

=head2 default_lang

Usage:

 $default_lang = $dh->default_lang;

=head2 props

Usage:

 @props = $dh->props;

Return list of properties. Will ignore properties that begin with underscore,
e.g.:

 $dh = defhash({a=>1, _b=>2});
 $dh->props;

=head2 prop

Usage:

 $val = $dh->prop($name);

Get property value, will die if property does not exist.

=head2 get_prop

 $val = $dh->get_prop($name);

Like L</prop>(), but will return undef if property does not exist.

=head2 prop_exists

Usage:

 $exists = $dh->prop_exists;

=head2 add_prop

=head2 set_prop

=head2 del_prop

=head2 del_all_props

=head2 attrs

=head2 attr

=head2 get_attr

=head2 attr_exists

=head2 add_attr

=head2 set_attr

=head2 del_attr

=head2 del_all_attrs

=head2 defhash_v

=head2 v

=head2 name

=head2 summary

=head2 description

=head2 tags

=head2 get_prop_lang

=head2 get_prop_all_langs

=head2 set_prop_lang


=head1 SEE ALSO

L<DefHash> specification

=cut
