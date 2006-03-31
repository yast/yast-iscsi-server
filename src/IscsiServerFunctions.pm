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



BEGIN { $TYPEINFO{setConfigFile} = ["function", "void", ["map", "string", "any"] ]; }
sub setConfigFile {
    my $self = shift;
    %config_file = %{+shift};
}

BEGIN { $TYPEINFO{getConfigFile} = ["function", ["map", "string", "any"] ]; }
sub getConfigFile {
    my $self = shift;
    return \%config_file;
}

BEGIN { $TYPEINFO{parseConfig} = ["function", ["map", "string", "any"] ]; }
sub parseConfig {
    my $self = shift;
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

BEGIN { $TYPEINFO{removeConfig} = ["function", ["map", "string", "any"], "string" ]; }
sub removeConfig {
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

BEGIN { $TYPEINFO{setConfig} = ["function", "void", ["map", "string", "any"] ]; }
sub setConfig {
    my $self = shift;
    %config = %{+shift};
}

BEGIN { $TYPEINFO{removeKeyFromMap} = ["function", ["map", "string", "any"], ["map", "string", "any"], "string"] ; }
sub removeKeyFromMap {
 my $self = shift;
 my %tmp_map = %{+shift};
 my $key = shift;

 delete $tmp_map{$key};
 return \%tmp_map;
}

BEGIN { $TYPEINFO{removeKey} = ["function", ["map", "string", "any"], "string"] ; }
sub removeKey {
 my $self = shift;
 my $key = shift;

 return $self->removeKeyFromMap(\%config, $key);
}

BEGIN { $TYPEINFO{getKeys} = ["function", ["list", "string"], ["map", "string", "any"] ] ; }
sub getKeys {
 my $self = shift;
 my %tmp_map = %{+shift};

 my @keylist = keys(%tmp_map);

 return \@keylist;
}


BEGIN { $TYPEINFO{hashConfig} = ["function", ["map", "string", "any"] ]; }
sub hashConfig {
    my $self = shift;
    my $values =  $config_file{'value'};
    my %tmp_hash = ();

    my $scope="auth";
    foreach  my $row ( @$values ){
     if ($$row{'name'} eq 'Target'){
      $scope = $$row{'value'};
      $tmp_hash{$scope} =  [ $row ];
     } else {
	    if (!ref($tmp_hash{$scope})) {
	     $tmp_hash{$scope} = [ $row ];
	    } else {
		    push(@{$tmp_hash{$scope}}, ($row));
	 	   }
	   }
    };
    return \%tmp_hash;
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
 push(@tmp_auth, {'KEY'=>'OutgoingUser', 'VALUE'=>$outgoing}) if ($outgoing =~/[w]+/);
 $config{'auth'}=\@tmp_auth;
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

BEGIN { $TYPEINFO{createMap} = [ "function", ["map", "string", "any"], ["map", "string", "any"], ["list", "string"] ] ; }
sub createMap {
 my $self = shift;
 my %old_map = %{+shift}; 
 my @comment = @{+shift}; 

 my %tmp_map = (
		"name"=>$old_map{"KEY"},
           "value"=>$old_map{"VALUE"},
           "kind"=>"value",
           "type"=>1,
           "comment"=> \@comment 
		);
 return \%tmp_map;
}

BEGIN { $TYPEINFO{addTo} = [ "function", ["map", "string", "any"], ["map", "string", "any"], "string" ] ; }
sub addTo {
 my $self = shift;
 my %old_map = %{+shift};
 my $target = shift;

 my @tmp_list = ();

open(FILE, ">>/tmp/perl.log");
print FILE Dumper($config{$target});
close(FILE);
 return \%old_map;
}





1;
# EOF
