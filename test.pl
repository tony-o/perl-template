#!/usr/bin/env perl

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
$parser->compile("test2", $template);

print '"' . $parser->run("test2", { 
   peter  => 'pan' 
  ,peter2 => 'tinkerbell'
}) . '"';

$parser->register('p', sub{
  my $output = shift;
  my $params = shift;
  my $stuff  = shift;
  $$output .= '<p>' . $stuff . '</p>';
  return 1;
});

$parser->compile("test2", $template);

print '"' . $parser->run("test2", { 
   peter  => 'pan' 
  ,peter2 => 'tinkerbell'
}) . '"';

1;
