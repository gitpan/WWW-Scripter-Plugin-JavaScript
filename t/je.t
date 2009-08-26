#!perl

# Copied from WWW::Mechanize::Plugin::JavaScript and modified.

# I have not got round to writing a complete set of tests yet. For now I’m
# just testing for fixed bugs and other changes.

use strict; use warnings;
use lib 't';
use Test::More;

use HTML'DOM 0.027;
use HTML::DOM::Interface ':all';
use URI::file;
use WWW::Scripter;

sub data_url {
	my $u = new URI 'data:';
	$u->media_type('text/html');
	$u->data(shift);
	$u
}

# blank page for playing with JS; some tests need their own, though
my $js = (my $m = new WWW::Scripter)->use_plugin('JavaScript',
	engine => 'JE'
);
$m->get(URI::file->new_abs( 't/blank.html' ));
$js->new_function($_ => \&$_) for qw 'is ok';

use tests 2; # third arg to new_function
{
	$js->new_function(foo => sub { return 72 }, 'String');
	$js->new_function(bar => sub { return 72 }, 'Number');
	is ($m->eval('typeof foo()'), 'string', 'third arg passed ...');
	is ($m->eval('typeof bar()'), 'number', '... to new_function');
}

use tests 1; # types of bound read-only properties
{
	is $m->eval(
		'typeof document.nodeType'
	), 'number', 'types of bound read-only properties';
}

use tests 1; # unwrap
{
	sub Foo::Bar::baz{
		return join ',', map ref||(defined()?$_:'^^'),@_
	};
	$js->bind_classes({
		'Foo::Bar' => 'Bar', 
		Bar => {
			baz => METHOD | STR
		}
	});
	$js->set('baz', bless[], 'Foo::Bar');
	is($m->eval('baz.baz(null, undefined, 3, "4", baz)'),
	   'Foo::Bar,^^,^^,JE::Number,JE::String,Foo::Bar', 'unwrap');
}

use tests 4; # null DOMString
{
	sub Phoo::Bar::bar {
		return (undef,765)[!!pop];
	}
	sub Phoo::Bar::baz { "heelo" }
	sub Phoo::Bar::nullbaz {}
	$js->bind_classes({
		'Phoo::Bar' => 'Phoo', 
		Phoo => {
			bar => METHOD | STR,
			baz => STR,
			nullbaz => STR,
		}
	});
	$js->set('baz', bless[], 'Phoo::Bar');
	ok($m->eval('baz.bar(0) === null'),
		'undef --> null conversion for a DOMString retval');
	ok($m->eval('baz.bar(1) === "765"'),
		'any --> string conversion for a DOMString retval');
	ok($m->eval('baz.nullbaz === null'),
		'undef --> null conversion when getting a DOMString prop');
	ok($m->eval('baz.baz === "heelo"'),
		'any --> string conversion when getting a DOMString prop');
}

use tests 2; # window wrappers
{
	ok $m->eval('window === top'),
		'windows are wrapped up in global objects';
	ok $m->eval('window === document.defaultView'),
		'window === document.defaultView';
}

use tests 3; # frames
{
	$m->eval(q|
		document.write("<iframe id=i src='data:text/html,'>")
		document.close()
	|);
	ok $m->eval('frames[0] && "document" in frames[0] &&
			frames[0].document.defaultView == frames[0]'),
		'frame access by array index', or diag $@;
	ok $m->eval('frames.i && "document" in frames.i'),
		'frame access by name';
	ok $m->eval('frames.i === frames[0]'),
		'the two methods return the same object';
}

use tests 1; # var statements should create vars (broken in 0.006
{            # [Mech plugin])
	ok $m->eval(q|
		var zarbardar;
		"zarbardar" in this
	|), 'var statements without "=" do create the vars';
}

use tests 1; # form event attributes with unusable scope chains
{            # (broken in 0.002; fixed in 0.007 [Mech plugin])
 $m->get(URI::file->new_abs( 't/je-form-event.html' ));
 $m->submit_form(
       form_name => 'y',
       button    => 'Search Now'
  );
 like $m->uri->query, qr/x=lofasz/, 'form event attributes';
}

use tests 2; # inline HTML comments (support added in 0.002)
SKIP:{
 skip("JE 0.034 required for this test",2) unless eval '1;use JE 0.034';

 my $warnings;
 local $SIG{__WARN__} = sub { ++$warnings; diag shift };

 $m->get(data_url <<'</html>');
<script type="text/javascript" language="JavaScript">
    function isginnf(omr)
      {
      avrn <!--o=wnwe aDt(e);
      ofmr.itmzeoenOffste.avleu=onwg.teTmieoznOefsfe(t);
<!-- UU_OMDP L480003D PTA- >-
      ofr.muluoignwp.avleu=ofr.mpdw.avleu;
<!-- nEdU UM_O D->-
      ertrun; 
      }
</script>
</html>
 
 ok(!$warnings,
   'no warnings (syntax errors) when HTML comments are embedded in JS');
 ok $m->eval('isginnf'), 'The code around the HTML comments actually runs';
}
