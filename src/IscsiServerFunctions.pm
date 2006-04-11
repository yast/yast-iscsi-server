#! /usr/bin/perl -w
#
# functions for IscsiServer module written in Perl
#

package IscsiServerFunctions;
use strict;
use Data::Dumper;
use YaPI;

our %TYPEINFO;

my %config = ();
my %config_file = ();
my %changes = ();

BEGIN { $TYPEINFO{parseConfig} = ["function", ["map", "string", "any"], ["map", "string", "any"] ]; }
sub parseConfig {
    my $self = shift;
    %config_file = %{+shift};
    my $values =  $config_file{'value'};

    my $scope="auth";
    foreach  my $row ( @$values ){
     if ($$row{'name'} eq 'Target'){
      $scope = $$row{'value'};
      $config{$scope} =  [ {'KEY' => 'Target', 'VALUE' => $scope } ];
     } else {
	    if (!ref($config{$scope})) {
	     $config{$scope} = [ {'KEY' => $$row{'name'}, 'VALUE' => $$row{'value'} } ];
	    } else {
		    push(@{$config{$scope}}, ({'KEY'=>$$row{'name'}, 'VALUE'=>$$row{'value'}}));
	 	   }
	   }
    };
    return \%config;
}

BEGIN { $TYPEINFO{removeItem} = ["function", ["map", "string", "any"], "string" ]; }
sub removeItem {
    my $self = shift;
    my $key = shift;
    %config = %{$self->removeKeyFromMap(\%config, $key)};
    return \%config;
}

BEGIN { $TYPEINFO{getConfig} = ["function", ["map", "string", "any"] ]; }
sub getConfig {
    my $self = shift;
    return \%config;
}

sub removeKeyFromMap {
 my $self = shift;
 my %tmp_map = %{+shift};
 my $key = shift;

 delete $tmp_map{$key} if defined $tmp_map{$key};
 return \%tmp_map;
}

BEGIN { $TYPEINFO{getTargets} = ["function", ["map", "string", "any"] ] ; }
sub getTargets {
 my $self = shift;

 return $self->removeKeyFromMap(\%config, 'auth');
}

BEGIN { $TYPEINFO{setAuth} = ["function", "void", ["list", "string"], "string" ]; }
sub setAuth {
    my $self = shift;
    my @incoming = @{+shift};
    my $outgoing = shift;
    my @tmp_auth = ();

	foreach my $row (@incoming){
	 push(@tmp_auth, {'KEY'=>'IncomingUser', 'VALUE'=>$row});
	}

open(FILE, ">>/tmp/perl.log");
print FILE Dumper($outgoing);
 push(@tmp_auth, {'KEY'=>'OutgoingUser', 'VALUE'=>$outgoing}) if ($outgoing =~/[\w]+/);
print FILE Dumper(@tmp_auth);
 $config{'auth'}=\@tmp_auth;
close(FILE);
}

BEGIN { $TYPEINFO{setTargetAuth} = ["function", "void", "string", ["list", "string"], "string" ]; }
sub setTargetAuth {
    my $self = shift;
    my $target = shift;
    my @incoming = @{+shift};
    my $outgoing = shift;
    my $tmp_auth = $config{$target};

	foreach my $row (@incoming){
	 push(@$tmp_auth, {'KEY'=>'IncomingUser', 'VALUE'=>$row});
	}
 push(@$tmp_auth, {'KEY'=>'OutgoingUser', 'VALUE'=>$outgoing}) if ($outgoing =~/[\w]+/);
}

BEGIN { $TYPEINFO{addTarget} = ["function", "void", "string", "string" ] ; }
sub addTarget {
 my $self = shift;
 my $target = shift;
 my $lun = shift;

 if (ref($config{$target})){
  my $tmp_list = $config{$target} ; 
  push(@$tmp_list, {'KEY'=>'Target', 'VALUE'=>$target}, {'KEY'=>'Lun', 'VALUE'=>$lun});
 } else {
	 $config{$target} = [ {'KEY'=>'Target', 'VALUE'=>$target}, {'KEY'=>'Lun', 'VALUE'=>$lun} ];
	}

}



BEGIN { $TYPEINFO{ifExists} = ["function", "boolean", "string", "string" ] ; }
sub ifExists {
 my $self = shift;
 my $key = shift;
 my $val = shift;
 
 my $ret = 0;

 foreach my $target (keys %config) {
 if ($target ne 'auth'){
  foreach my $tmp_hash (@{$config{$target}}){
   if (($$tmp_hash{'KEY'} eq $key)&&($$tmp_hash{'VALUE'} eq $val)) { 
	$ret = 1;
    }
   }
  }
 }
 return $ret; 
}

BEGIN { $TYPEINFO{getNextLun} = [ "function", "integer" ] ; }
sub getNextLun {
 my $self = shift;
 my $lun = -1;
 foreach my $target (keys %{$self->removeKeyFromMap(\%config, 'auth')}){
  foreach my $tmp_hash (@{$config{$target}}){
   if ($$tmp_hash{'KEY'} eq 'Lun'){
    if ($$tmp_hash{'VALUE'}=~/([\d]+)[\s]*/) {
     $lun=$1 if ($1>$lun);
    }
   }
  }
 } 
 return $lun+1;
}

sub createMap {
 my ($old_map, $comment) = @_;

 $comment='' if (ref($comment) eq 'ARRAY');
 my %tmp_map = (
		"name"=>$old_map->{"KEY"},
           "value"=>$old_map->{"VALUE"},
           "kind"=>"value",
           "type"=>1,
           "comment"=> $comment 
		);
 return \%tmp_map;
}

sub addTo {
 my ($old_map, $target) = @_;
 my @tmp_list = ();

 foreach my $row (@{$config{$target}}){
  push(@tmp_list, createMap( $row, [] ));
 }
 $old_map->{$target}=\@tmp_list;
 return $old_map;
}

BEGIN { $TYPEINFO{writeConfig} = ["function", ["map", "string", "any"] ]; }
sub writeConfig {
    my $self = shift;
    my $values =  $config_file{'value'};
    my %new_config = ();

    my $scope="auth";
    foreach  my $row ( @$values ){
     if ($$row{'name'} eq 'Target'){
      $scope = $$row{'value'};
      $new_config{$scope} =  [ $row ];
     } else {
	    if (!ref($new_config{$scope})) {
	     $new_config{$scope} = [ $row ];
	    } else {
		    push(@{$new_config{$scope}}, ($row));
	 	   }
	   }
    };

    foreach my $key (keys %new_config){
     if (! defined $config{$key}){
      delete($new_config{$key});
      push(@{$changes{'del'}}, $key);
     }
    }

    foreach my $key (keys %config){
     if (! defined $new_config{$key}){
      addTo(\%new_config, $key);
      push(@{$changes{'add'}}, $key) if ($key ne 'auth');
     } else {
	 my %comments = ();
	 foreach my $row (@{$new_config{$key}}){
	  $comments{$row->{'name'}} = $row->{'comment'} if ($row->{'comment'} ne '');
	  $comments{$row->{'name'}}='' if (not defined $comments{$row->{'name'}});
	 }
	 my @new = ();
	 foreach my $row (@{$config{$key}}){
	  my $k = $row->{'KEY'};
	  $comments{$k}='' if not defined $comments{$k};
	 push(@new, createMap($row, $comments{$k}));
	 $comments{$k}='';
	 }
	 $new_config{$key} = \@new;
	}
    }
    $config_file{'value'} = $new_config{'auth'};
      delete ($new_config{'auth'});

    foreach my $key (reverse(keys %new_config )){
     if (not ref($new_config{$key})){
      push(@{$config_file{'value'}}, $new_config{$key}) ;
     } else {
	     push(@{$config_file{'value'}}, @{$new_config{$key}}) ;
	    }
    }
    return \%config_file;
}


BEGIN { $TYPEINFO{getConnected} = ["function", ["list", "string"] ]; }
sub getConnected {
 open(PROC, "< /proc/net/iet/session");
 my $target="";
 my @connected = ();
 foreach my $row (<PROC>){
  $target=$1 if ( $row =~ /tid:[\d]+ name:([\S]+)/);
  my $find = 0;

   foreach my $conn (@connected){
    $find = 1 if ( $conn =~ $target);
   }
  push(@connected, $target) if (( $row =~ /sid:[\d]+/)&&(not $find));
 }
 close(PROC);
return \@connected;
}

BEGIN { $TYPEINFO{getChanges} = ["function", ["map", "string", "any"] ]; }
sub getChanges {
#TODO - to 'add' and 'del' add all targets but not @connected from getConnected
 return \%changes;
}

1;
# EOF
