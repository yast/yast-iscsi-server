#! /usr/bin/perl -w
#
# functions for IscsiServer module written in Perl
#

package IscsiServerFunctions;
use strict;
use Data::Dumper;
use YaPI;

our %TYPEINFO;

# map of auth and target values
my %config = ();

# map for ini-agent
my %config_file = ();

# for remember add and deleted targets
my %changes = ();

# read data given from ini-agent and put values into %config map
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

# remove item with given key from %config and return result 
BEGIN { $TYPEINFO{removeItem} = ["function", ["map", "string", "any"], "string" ]; }
sub removeItem {
    my $self = shift;
    my $key = shift;
    %config = %{$self->removeKeyFromMap(\%config, $key)};
    return \%config;
}

# accessor for %config
BEGIN { $TYPEINFO{getConfig} = ["function", ["map", "string", "any"] ]; }
sub getConfig {
    my $self = shift;
    return \%config;
}

# internal function :
# return given map without given key
sub removeKeyFromMap {
 my $self = shift;
 my %tmp_map = %{+shift};
 my $key = shift;

 delete $tmp_map{$key} if defined $tmp_map{$key};
 return \%tmp_map;
}

# return targets (ommit 'auth' from %config)
BEGIN { $TYPEINFO{getTargets} = ["function", ["map", "string", "any"] ] ; }
sub getTargets {
 my $self = shift;

 return $self->removeKeyFromMap(\%config, 'auth');
}

# set discovery authentication
BEGIN { $TYPEINFO{setAuth} = ["function", "void", ["list", "string"], "string" ]; }
sub setAuth {
    my $self = shift;
    my @incoming = @{+shift};
    my $outgoing = shift;
    my @tmp_auth = ();

	foreach my $row (@incoming){
	 push(@tmp_auth, {'KEY'=>'IncomingUser', 'VALUE'=>$row});
	}

 push(@tmp_auth, {'KEY'=>'OutgoingUser', 'VALUE'=>$outgoing}) if ($outgoing =~/[\w]+/);
 $config{'auth'}=\@tmp_auth;
}

# set authentication for given target
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

# create new target
BEGIN { $TYPEINFO{addTarget} = ["function", "void", "string", "string" ] ; }
sub addTarget {
 my $self = shift;
 my $target = shift;
 my $lun = shift;

 if (ref($config{$target})){
  my $tmp_list = $config{$target} ; 
  push(@$tmp_list, {'KEY'=>'Target', 'VALUE'=>$target}, {'KEY'=>'Lun', 'VALUE'=>$lun});
 } else {
	 push(@{$changes{'add'}}, $target);
	 $config{$target} = [ {'KEY'=>'Target', 'VALUE'=>$target}, {'KEY'=>'Lun', 'VALUE'=>$lun} ];
	}

}


# check whether target/lun already exists
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

# get highest lun +1
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

# internal function
# create map from given map in format needed by ini-agent
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

# internal function
# copy each row from $config{$target} to $old_map but in format needed by ini-agent
sub addTo {
 my ($old_map, $target) = @_;
 my @tmp_list = ();

 foreach my $row (@{$config{$target}}){
  push(@tmp_list, createMap( $row, [] ));
 }
 $old_map->{$target}=\@tmp_list;
 return $old_map;
}

# parse %config and write it to %config_file for ini-agent
BEGIN { $TYPEINFO{writeConfig} = ["function", ["map", "string", "any"] ]; }
sub writeConfig {
    my $self = shift;
    my $values =  $config_file{'value'};
    my %new_config = ();

    # read old configuration and write it to %new_config
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

    # deleted items add to $changes{'del'}
    foreach my $key (keys %new_config){
     if (! defined $config{$key}){
      delete($new_config{$key});
#      push(@{$changes{'del'}}, $key);
     }
    }

    foreach my $key (keys %config){
     if (! defined $new_config{$key}){
      # add new items
      addTo(\%new_config, $key);
#      push(@{$changes{'add'}}, $key) if ($key ne 'auth');
     } else {
	 # for modifying store comments
	 my %comments = ();
	 foreach my $row (@{$new_config{$key}}){
	  $comments{$row->{'name'}} = $row->{'comment'} if ($row->{'comment'} ne '');
	  $comments{$row->{'name'}}='' if (not defined $comments{$row->{'name'}});
	 }
	 my @new = ();
	 foreach my $row (@{$config{$key}}){
	  my $k = $row->{'KEY'};
	  $comments{$k}='' if not defined $comments{$k};
	 # and put it to new map with old comments
	 push(@new, createMap($row, $comments{$k}));
	 $comments{$k}='';
	 }
	 $new_config{$key} = \@new;
	}
    }
    # write 'auth' into %new_config
    $config_file{'value'} = $new_config{'auth'};
      delete ($new_config{'auth'});
    #write all targets into %new_config
    foreach my $key (reverse(keys %new_config )){
     if (not ref($new_config{$key})){
      push(@{$config_file{'value'}}, $new_config{$key}) ;
     } else {
	     push(@{$config_file{'value'}}, @{$new_config{$key}}) ;
	    }
    }
    return \%config_file;
}

# get now connected targets
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

# accessor for %changes
BEGIN { $TYPEINFO{getChanges} = ["function", ["map", "string", "any"] ]; }
sub getChanges {
#TODO - to 'add' and 'del' add all targets but not @connected from getConnected
 return \%changes;
}


# set modified for %changes
BEGIN { $TYPEINFO{setModifChanges} = ["function", "integer", "string" ]; }
sub setModifChanges {
 my $self = shift;
 my $target = shift;
 my $ret = 0;

 foreach my $section (("del", "add")){
  foreach my $row (@{$changes{$section}}){
   $ret=1 if ($row eq $target);
  }}

  if ($ret==0){
   push(@{$changes{"del"}}, $target);
   push(@{$changes{"add"}}, $target);
  }

 return \$ret;
}


# set deleted for %changes
BEGIN { $TYPEINFO{setDelChanges} = ["function", "integer", "string" ]; }
sub setDelChanges {
 my $self = shift;
 my $target = shift;
 my $ret = 0;

 foreach my $section (("del", "add")){
  my @list=();
  foreach my $row (@{$changes{$section}}){
   push(@list, $row) if ($row ne $target);
  }
  $changes{$section}=\@list;
 }
  push(@{$changes{"del"}}, $target);

 return \$ret;
}

1;
# EOF
