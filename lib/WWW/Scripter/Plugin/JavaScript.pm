package WWW::Scripter::Plugin::JavaScript;

use strict;   # :-(
use warnings; # :-(

use Encode 'decode_utf8';
use Scalar::Util qw'weaken';
use URI::Escape 'uri_unescape';

our $VERSION = '0.001';

# Attribute constants (array indices)
sub mech() { 0 }
sub jsbe() { 1 } # JavaScript back-end (object)
sub benm() { 2 } # Back-end name
sub init_cb() { 3 } # callback routine that's called whenever a new js
                    # environment is created
sub alert()   { 4 }
sub confirm() { 5 }
sub prompt()  { 6 }
sub cb() { 7 } # class bindings
sub tmout() { 8 } # timeouts

{no warnings; no strict;
undef *$_ for qw/mech jsbe benm init_cb
                alert confirm prompt tmout/} # These are PRIVATE constants!

sub init {

	my ($package, $mech) = @_;

	my $self = bless [$mech], $package;
	weaken $self->[mech];

	$mech->script_handler( default => $self );
	$mech->script_handler(
	 qr/(?:^|\/)(?:x-)?(?:ecma|j(?:ava)?)script[\d.]*\z/i => $self
	);

	$mech->set_my_handler(request_preprepare => sub {
		my($request,$mech) = @_;
		$self->eval(
		 $mech, decode_utf8 uri_unescape opaque {uri $request}
		);
		$@ and $mech->warn($@);
		WWW'Scripter'abort;
	}, m_scheme => 'javascript');

	# stop closures from preventing destruction
	weaken $mech;
	my $life_raft = $self;
	weaken $self;

	$self;
}

sub options {
	my $self = shift;
	my %opts = @_;

	my $w;
	for(keys %opts) {
		if($_ eq 'engine') {
			if($self->[jsbe] &&
			   $self->[benm] ne $opts{$_}
			) {
			    $self->[mech]->die(
			        "Can't set JavaScript engine to " .
			        "'$opts{$_}' since $self->[benm] is " .
			        "already loaded.");;
			}
			$self->[benm] = $opts{$_};;
		}
		elsif($_ eq 'init') {
			$self->[init_cb] = $opts{$_};
		}
		else {
			$self->[mech]->die(
			    "JavaScript plugin: Unrecognized option '$_'"
			);
		}
	}
}

sub eval {
	my($plugin,$mech,$code,$url,$line,$inline) = @_;

	if(
	 $code =~ s/^(\s*)<!--[^\cm\cj\x{2028}\x{2029}]*(?x:
	         )(?:\cm\cj?|[\cj\x{2028}\x{2029}])//
	) {
		$line += 1 + (()= $1 =~ /(\cm\cj?|[\cj\x{2028}\x{2029}])/g)
	}
	$code =~ s/-->\s*\z//;
		
	my $be = $plugin->_start_engine;

	$be->eval($code, $url, $line);
}

sub event2sub {
		my($self,$mech,$elem,undef,$code,$url,$line) = @_;

		my $func = $self->
			_start_engine->event2sub($code,$elem,$url,$line);

		sub {
			my $event_obj = shift;
			my $ret = &$func($event_obj);
			defined $ret and !$ret and
				$event_obj->preventDefault;
			# ~~~ I need to change this logic for whichever
			#     event has it reversed (don't remember which
			#     it was; I'll have to look it up!).
		};
}


sub _start_engine {
	my $self = shift;
	return $self->[jsbe] if $self->[jsbe];
	
	if(!$self->[benm]) {
	    # try this one first, since it's faster:
	    eval{require WWW::Scripter::Plugin::JavaScript::SpiderMonkey};
	    if($@) {
	        require 
	            WWW::Scripter::Plugin::JavaScript::JE;
                $self->[benm] = 'JE'
            }
	    else { $self->[benm] = 'SpiderMonkey' };
	}
	else {
		require "WWW/Scripter/Plugin/JavaScript/" .
			"$$self[benm].pm";
	}

	$self->[jsbe] = "WWW::Scripter::Plugin::JavaScript::$$self[benm]"
		-> new( my $w = $self->[mech] );
	require HTML::DOM::Interface;
	require CSS::DOM::Interface;
	for ($$self[jsbe]) {
		for my $class_info( $self->[mech]->class_info ) {
		 $_->bind_classes($class_info) ;
		}
		for my $__(@{$self->[cb]||[]}){
			$_->bind_classes($__)
		}

		$_->set('screen', {});
			# ~~~ This doesn’t belong here. I need to get a
			#     wround to addy nit two the win dough object
			#     one sigh figger out zackly how it shoe be
			#     done.

	} # for $$self->[jsbe];
	{ ($self->[init_cb]||next)->($self); }
	weaken $self; # closures
	return $$self[jsbe];
}

sub bind_classes {
	my $plugin = shift;
	push @{$plugin->[cb]}, $_[0];
	$plugin->[jsbe] && $plugin->[jsbe]->bind_classes($_[0]);
}

for(qw/set new_function/) {
	no strict 'refs';
	*$_ = eval "sub { shift->_start_engine->$_(\@_) }";
}


# ~~~ This is experimental. The purposed for this is that code that relies
#     on a particular version of a JS back end can check to see which back
#     end is being used before doing Foo->VERSION($bar). The problem with
#     it is that it returns nothing unless the JS environment has already
#     been loaded. If we have it start the JS engine, we may load it and
#     then not use it.
sub engine { shift->[benm] }


# ------------------ DOCS --------------------#

1;


=head1 NAME

WWW::Scripter::Plugin::JavaScript - JavaScript plugin for WWW::Scripter

=head1 VERSION

Version 0.001 (alpha)

=head1 SYNOPSIS

  use WWW::Scripter;
  $w = new WWW::Scripter;
  
  $w->use_plugin('JavaScript');
  $w->get('http://www.cpan.org/');
  $w->get('javascript:alert("Hello!")'); # prints Hello!
  
  $w->use_plugin(JavaScript =>
          engine  => 'SpiderMonkey',
          init    => \&init, # initialisation function
  );                         # for the JS environment
  
=head1 DESCRIPTION

This module is a plugin for L<WWW::Scripter> that provides JavaScript
capabilities (who would have guessed?).

To load the plugin, just use L<WWW::Scripter>'s C<use_plugin> method:

  $w = new WWW::Scripter;
  $w->use_plugin('JavaScript');

You can pass options to the plugin via the C<use_plugin> method. It takes
hash-style arguments and they are as follows:

=over 4

=item engine

Which JavaScript back end to use. Currently, this module only supports
L<JE>, a pure-Perl JavaScript interpreter. Later it will support
SpiderMonkey via either L<JavaScript::SpiderMonkey> or 
L<JavaScript.pm|JavaScript>. If this option is
not specified, either SpiderMonkey or JE will be used, whichever is
available. It is possible to
write one's own bindings for a particular JavaScript engine. See below,
under L</BACK ENDS>. 

=item init

Pass to this option a reference to a subroutine and it will be run every
time a new JavaScript environment is initialised. This happens after the
functions above have been created. The first argument will
be the WWW::Scripter object. You can use this, for instance, 
to make your
own functions available to JavaScript.

=back

=head1 METHODS

L<WWW::Scripter>'s C<use_plugin> method will return a plugin object. The
same object can be retrieved via C<< $w->plugin('JavaScript') >> after the
plugin is loaded. The following methods can be called on that object:

=over 4

=begin comment

~~~ Should this be public? The interface is not what is shown below,
    as the first arg has to be $w. That makes it awkward to use. $w->eval
    is much easier.

=item eval

This evaluates the JavaScript code passed to it. You can optionally pass
two more arguments: the file name or URL, and the first line number.

=end comment

=item new_function

This creates a new global JavaScript function out of a coderef. Pass the 
name as
the first argument and the code ref as the second.

=item set

Sets the named variable to the value given. If you want to assign to a
property of a property ... of a global property, pass each property name
as a separate argument:

  $w->plugin('JavaScript')->set(
          'document', 'location', 'href' => 'http://www.perl.org/'
  );

=item bind_classes

Instead of using this method, you might consider L<WWW::Scripter>'s
C<class_info> method, which is more general-purpose (it applies also to
whatever other scripting languages might be available).

With this you can bind Perl classes to JavaScript, so that JavaScript can
handle objects of those classes. These class bindings will persist from one
page to the next.

You should pass a hash ref that has the
structure described in L<HTML::DOM::Interface>, except that this method
also accepts a C<< _constructor >> hash element, which should be set to the
name of the method to be called when the constructor function is called
within JavaScript; e.g., C<< _constructor => 'new' >>.

=back

=head1 JAVASCRIPT FEATURES

The members of the HTML DOM that are available depend on the versions of
L<HTML::DOM> and L<CSS::DOM> installed. See L<HTML::DOM::Interface> and
L<CSS::DOM::Interface>.

For a list of the properties of the window object, see 
L<WWW::Scripter>.

The JavaScript plugin itself provides just the C<screen> object, which is
empty. Later this may be moved to the WWW::Scripter, but that
should make little difference to you, unless you are writing bindings for
another scripting language.

=head1 BACK ENDS

A back end has to be in the WWW::Scripter::Plugin::JavaScript:: name
space. It will be C<require>d by this plugin implicitly when its name is
passed to the C<engine> option.

The following methods must be implemented:

=head2 Class methods

=over 4

=item new

This method is passed a window (L<WWW::Scripter>)
object.

It has to create a JavaScript environment, in which the global object
delegates to the window object for the members listed in 
L<C<%WWW::Scripter::WindowInterface>| WWW::Scripter::WindowInterface/THE C<%WindowInterface> HASH>.

When the window object or its frames collection (WWW::Scripter::Frames
object) is passed to the JavaScript 
environment, the global
object must be returned instead.

This method can optionally create C<window>, C<self> and C<frames>
properties
that refer to the global object, but this is not necessary. It might make
things a little more efficient.

Finally, it has to return an object that implements the interface below.

The back end has to do some magic to make sure that, when the global object
is passed to another JS environment, references to it automatically point
to a new global object when the user (or calling code) browses to another
page.

For instance, it could wrap up the global object in a proxy object
that delegates to whichever global object corresponds to the document.

=back

=head2 Object Methods

=over 4

=item eval

This should accept up to three arguments: a string of code, the file name
or URL, and the first line number.

=item new_function

=item set

=item bind_classes

These correspond to those 
listed above for
the plugin object. Those methods are simply delegated to the back end, 
except that C<bind_classes> also does some caching if the back end hasn't
been initialised yet.

C<new_function> must also accept a third argument, indicating the return
type. This (when specified) will be the name of a JavaScript function that
does the type conversion. Only 'Number' is used right now.

=item event2sub ($code, $elem, $url, $first_line)

This method needs to turn the
event handler code in C<$code> into a
coderef, or an object that can be used as such, and then return it. That 
coderef will be
called with an HTML::DOM::Event object as its sole argument. It's return 
value, if
defined, will be used to determine whether the event's C<preventDefault>
method should be called.

=item define_setter

This will be called
with a list of property names representing the 'path' to the property. The
last argument will be a coderef that must be called with the value assigned
to the property.

B<Note:> This is actually not used right now. The requirement for this may
be removed some time before version 1.

=head1 PREREQUISITES

perl 5.8.3 or higher (5.8.4 or higher recommended)

HTML::DOM 0.010 or later

JE 0.022 or later (when there is a SpiderMonkey binding available it will 
become optional)

CSS::DOM

WWW::Scripter

URI

=head1 BUGS

=for comment
(See also L<WWW::Scripter::Plugin::JavaScript::JE/Bugs>.)

There is currently no system in place for preventing pages from different
sites from communicating with each other.

To report bugs, please e-mail the author.

=head1 AUTHOR & COPYRIGHT

Copyright (C) 2009 Father Chrysostomos
<C<< join '@', sprout => join '.', reverse org => 'cpan' >>E<gt>

This program is free software; you may redistribute it and/or modify
it under the same terms as perl.

=head1 SEE ALSO

=over 4

=item -

L<WWW::Scripter>

=item -

L<HTML::DOM>

=item -

L<JE>

=item -

L<JavaScript.pm|JavaScript>

=item -

L<JavaScript::SpiderMonkey>

=item -

L<WWW::Mechanize::Plugin::JavaScript> (the original version of this module)

=back
