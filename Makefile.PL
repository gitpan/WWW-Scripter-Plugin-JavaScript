#!/usr/bin/perl

BEGIN{ require 5.006; }
use ExtUtils::MakeMaker;

# I’m keeping these separate, in case these modules should ever be dis-
# tributed individually:
%js_prq = (
	CSS::DOM::Interface  => 0,
	Encode               => 0,
	HTML::DOM::Interface => 0,
	Scalar::Util         => 0,
	strict               => 0,
	URI::Escape          => 0,
	warnings             => 0,
# for testing:
	lib          => 0,
	Test::More   => 0,
	URI::file    => 0,
	WWW'Scripter => 0,
);
%je_prq = (
	Carp                          => 0,
	Hash::Util::FieldHash::Compat => 0,
	HTML::DOM::Interface          => 0,
	JE                            =>  .022, # bind_class’s
	Scalar::Util                  => 0,     # unwrap option
	strict                        => 0,
	warnings                      => 0,
# for testing:
	lib          => 0,
	Test::More   => 0,
	URI::file    => 0,
	WWW'Scripter => 0,
);

for(\(%js_prq, %je_prq)) {
	for $k(keys %$_) {
		$prq{$k} = $$_{$k}
			unless exists $prq{$k} and $$_{$k} < $prq{$k};
	}
}

WriteMakefile(
    NAME                => 'WWW::Scripter::Plugin::JavaScript',
    AUTHOR              => 'Father Chrysostomos <sprout & cpan . org>',
    VERSION_FROM        => 'lib/WWW/Scripter/Plugin/JavaScript.pm',
#    VERSION             => "0.009c",
    ABSTRACT_FROM       => 'lib/WWW/Scripter/Plugin/JavaScript.pm',
    PL_FILES            => {},
    PREREQ_PM           => \%prq,
    dist               => { COMPRESS => 'gzip -9f', SUFFIX => 'gz',
                            TAR => 'COPYFILE_DISABLE=1 tar' },
    clean              => { FILES => 'WWW-Scripter-Plugin-JavaScript-*' },
);
