use 5.010001;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'RSBX::Orgs::IETF::RFC2849::Unfold',
    VERSION_FROM      => 'lib/RSBX/Orgs/IETF/RFC2849/Unfold.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ABSTRACT_FROM     => 'lib/RSBX/Orgs/IETF/RFC2849/Unfold.pm', # retrieve abstract from module
    AUTHOR            => 'Raymond S Brand <rsbx@acm.org>',
);
