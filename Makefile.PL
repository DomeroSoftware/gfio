use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'gfio',
    VERSION_FROM => 'lib/gfio.pm', # finds $VERSION
    AUTHOR       => 'Domnero Software <domerosoftware@gmail.com>',
    ABSTRACT     => 'A module for general file input/output operations',
    LICENSE      => 'perl',
    PREREQ_PM    => {
        'strict'    => 0,
        'warnings'  => 0,
        'Exporter'  => 0,
        'utf8'      => 0,
        'Test::More' => 0,
    },
    META_MERGE   => {
        'meta-spec' => { version => 2 },
        resources   => {
            homepage    => 'https://domero.nl/',
            repository  => 'https://github.com/DomeroSoftware/gfio',
            bugtracker  => 'https://github.com/DomeroSoftware/gfio/issues',
        },
    },
    PL_FILES     => {},
    EXE_FILES    => [],
    DIR          => ['lib', 't', 'example'],
    clean        => { FILES => 'gfio-*' },
);

