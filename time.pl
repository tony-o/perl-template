#!/usr/bin/env perl

use Benchmark qw(:all);
use Data::Dumper;
use Template::Tones;

my $parser = Template::Tones->new();

my $template = <<END;
  !!#nest1!! 
    !!#nest2.1!! 
      !!=peter!!
      Undefined: !!=peter!! 
      Undefined: !!ppeter!! 
    !!/nest2.1!! 
    !!#nest2.2!! 
      !!=peter2!! 
    !!/nest2.2!! 
  !!/nest1!!
  this is text
END

timethis(1000000, sub{
  $parser->compile("test2", $template);
});

timethis(1000000, sub{
  $parser->run("test2", { 
    peter  => 'pan' 
    ,peter2 => 'tinkerbell'
  }) . '"';
});
1;
