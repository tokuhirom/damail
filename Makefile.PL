use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'Damail',
    AUTHOR        => 'Some Person <person@example.com>',
    VERSION_FROM  => 'app.psgi',
    PREREQ_PM     => {
        'Amon2'                           => '3.37',
        'Amon2::Lite'                     => '0.08',
        'Text::Xslate'                    => '1.5006',
        'Plack::Session'                  => '0.14',
		'Encode::IMAPUTF7' => 0,
		'Net::IMAP::Client' => 0,
		'Data::Page' => 0,
		'Config::Pit' => 0,
		'Email::MIME::Encodings' => 0,
		'Log::Minimal' => 0,
		Encode => 0,
    },
    MIN_PERL_VERSION => '5.008001',
    (-d 'xt' and $ENV{AUTOMATED_TESTING} || $ENV{RELEASE_TESTING}) ? (
        test => {
            TESTS => 't/*.t xt/*.t',
        },
    ) : (),
);
