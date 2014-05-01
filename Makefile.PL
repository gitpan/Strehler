
use strict;
use warnings;



use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "A light-weight, nerdy, smart CMS in perl based on Perl Dancer2 framework.",
  "AUTHOR" => "Simone Fare' <cymon\@tiscali.it>",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "Strehler",
  "EXE_FILES" => [
    "script/strehler"
  ],
  "LICENSE" => "perl",
  "NAME" => "Strehler",
  "PREREQ_PM" => {
    "Authen::Passphrase::BlowfishCrypt" => 0,
    "Carp" => 0,
    "Cwd" => 0,
    "DBIx::Class::Core" => 0,
    "DBIx::Class::Schema" => 0,
    "DBIx::Class::Schema::Loader" => 0,
    "DBIx::Class::TimeStamp" => 0,
    "Dancer2" => "0.11",
    "Dancer2::Core::App" => 0,
    "Dancer2::Core::Runner" => 0,
    "Dancer2::Plugin" => 0,
    "Dancer2::Plugin::Ajax" => 0,
    "Dancer2::Plugin::DBIC" => 0,
    "DateTime::Format::SQLite" => 0,
    "DateTime::Format::Strptime" => 0,
    "File::Copy" => 0,
    "File::Copy::Recursive" => 0,
    "HTML::FormFu" => "1.00",
    "HTML::FormFu::Element::Block" => 0,
    "HTML::FormFu::Element::Select" => 0,
    "HTML::FormFu::Validator" => 0,
    "Moo" => 0,
    "Moose" => 0,
    "SQL::Translator" => 0,
    "Term::ReadKey" => 0,
    "Text::Unidecode" => 0,
    "Unicode::Normalize" => 0,
    "YAML::XS" => 0
  },
  "TEST_REQUIRES" => {
    "FindBin" => 0,
    "LWP::UserAgent" => 0,
    "Test::More" => 0,
    "Test::TCP" => 0
  },
  "VERSION" => "1.1.7",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  my $tr = delete $WriteMakefileArgs{TEST_REQUIRES};
  my $br = $WriteMakefileArgs{BUILD_REQUIRES};
  for my $mod ( keys %$tr ) {
    if ( exists $br->{$mod} ) {
      $br->{$mod} = $tr->{$mod} if $tr->{$mod} > $br->{$mod};
    }
    else {
      $br->{$mod} = $tr->{$mod};
    }
  }
}

unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



