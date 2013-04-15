#!/usr/bin/env perl
package Template::Tones;
use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use Data::Dumper;

sub new{
  my $class = shift;
  my $defaults = {
     open      => '!!'
    ,close     => '!!'
    ,cache     => {}
    ,functions => {
      '=' => sub{
        my $output = shift;
        my $params = shift;
        my $name   = shift;
        $$output .= defined ${$params}->{$name} ? ${$params}->{$name} : ""; 
        return 1;
      }
    }
    ,nestables => {
      open   => '#'
      ,close => '/'
    }
  };
  my $self = {
    options => shift || {}
  };
  foreach my $key (keys %{$defaults}){
    if(defined $self->{options}->{$key}){
      next;
    }
    $self->{options}->{$key} = $defaults->{$key};
  }
  bless $self, $class;
  return $self;
};

sub register{
  my $self    = shift;
  my $func    = shift;
  my $anonsub = shift;
  $self->{options}->{functions}->{$func} = $anonsub;
  return 1;
};

sub run{
  my $self  = shift;
  my $templ = shift;
  my $parm  = shift;
  my $scr   = $self->{options}->{cache}->{$templ}($parm);
  return $scr;
};

sub compile{
  my $self     = shift;
  my $name     = shift;
  my $template = shift;
  if(!(defined $template)){
    warn 'caching not possible';
    $template = $name;
    undef $name;
  }
  my @parsedata = $self->parse($template);
  my @nodes     = $self->buildtree(\@parsedata);
  my $code      = $self->generate(\@nodes);
  my $sub       = eval($code);
  die $@ if $@;
  if(defined $name){
    $self->{options}->{cache}->{$name} = $sub;
  }
  return $code;
};

sub parse{
  my $self     = shift;
  my $template = shift;
  my $chopper  = '^\s*(' . $self->{options}->{open} . '[\\' . 
    $self->{options}->{nestables}->{open} . '\\' . $self->{options}->{nestables}->{close} .
    '].*?' . $self->{options}->{close} . ')\s*$';
  $template =~ s/$chopper/$1/gm;
  my $length   = length($template);
  my @templarr = split '', $template;
  my @opener   = split '', $self->{options}->{open};
  my @closer   = split '', $self->{options}->{close};
  my $status   = 0; # 0=in text, 1=in code
  my ($index, $counter, $start, @nodes, $nesting, $buffer);
  
  my $isopener = sub{
    for($counter = 0; $counter < @opener; $counter++){
      if($templarr[$counter + $index] ne $opener[$counter]){
        return 0;
      }
    }
    return 1;
  };

  my $iscloser = sub{
    for($counter = 0; $counter < @closer; $counter++){
      if($templarr[$counter + $index] ne $closer[$counter]){
        return 0;
      }
    }
    return 1;
  };

  for($index = 0, $nesting = 0, $start = 0; $index < $length; $index++){
    if(&$isopener() && $status == 0){
      $status = 1;
      push @nodes, {t => substr($template, $start, ($index - $start)), n => $nesting}; 
      $index += @opener;
      $start = $index;
    }elsif(&$iscloser() && $status == 1){
      $status = 0;

      $nesting++ if substr($template, $start, 1) eq $self->{options}->{nestables}->{open};
      push @nodes, {e => substr($template, $start, ($index - $start)), n => $nesting};
      $nesting-- if substr($template, $start, 1) eq $self->{options}->{nestables}->{close};

      $index += @closer;
      $start = $index;
    }
  }
  push @nodes, {($status > 0 ? 'e' : 't') => substr($template, $start), n => $nesting};
  return @nodes;
};

sub trim{
  $_[0] =~ s/^[\r\s]+//g;
  $_[0] =~ s/[\r\s]+$//g;
  return $_[0];
};

sub buildtree{
  my $self   = shift;
  my $nodes  = shift;
  my $inest  = shift || 0;
  my $cnest  = $inest;
  my $lnest  = $cnest;
  my $length = @{$nodes};
  my ($endnest, $index, $node); #current nest vs last nest
  my @leaves;

  while(@{$nodes}){
    $node = shift @{$nodes};
    $cnest = $node->{n};

    if($cnest > $lnest){
      # get the last index of nests to parse
      $endnest = 1;
      while($cnest <= ${$nodes}[$endnest]->{n}){
        $endnest++;
        if($endnest >= @{$nodes}){
          return @leaves;
        }
      }
      my @temp = splice @{$nodes}, 0, $endnest - 1;
      @temp = $self->buildtree(\@temp, $cnest);
      push @leaves, {r => \@temp};
      shift @{$nodes};
    }else{
      push @leaves, $node;
    }

    $lnest = $cnest;
  }
  return @leaves;
};

sub generate{
  my $self  = shift;
  my $nodes = shift;
  my $code  = shift || "sub{\n\tmy \$params = shift;\n\tmy \$output = '';\n";
  my $recr  = shift || 0;
  my $hash  = md5_hex(join('',localtime(time)));
  my ($node,$buffer);
  while(@{$nodes}){
    $node = splice @{$nodes}, 0, 1;
    if(ref($node) eq 'HASH' && defined $node->{t}){
      $buffer = $node->{t};
      $buffer =~ s/[\n]/\\n/gm;
      $buffer =~ s/\$/\\\$/gm;
      $code .= ("\t"x($recr + 1)) . "\$output .= \"" . $buffer . "\";\n";
    }elsif(ref($node) eq 'HASH' && ref($node->{r}) eq 'ARRAY'){
      $code .= $self->generate($node->{r}, "\n", $recr + 1);
    }elsif(ref($node) eq 'HASH' && defined $node->{e}){
      if(defined $self->{options}->{functions}->{substr($node->{e},0,1)}){
        $code .= ("\t"x($recr + 1)) . "\$self->{options}->{functions}->{'" . substr($node->{e},0,1) . "'}->(\\\$output, \\\$params, '" . substr($node->{e},1) . "');\n";
      }else{
        $code .= ("\t"x($recr + 1)) . '#' . $node->{e} . "\n";
      }
    }else{
      warn 'skipped: ' . Dumper($node);
    }
  }
  $code .= $recr == 0 ? "\treturn \$output;\n}\n" : '';
  return $code;
};

1;
