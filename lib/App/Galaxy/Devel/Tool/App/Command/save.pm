# push distribution over
package App::Galaxy::Devel::Tool::App::Command::save;
use App::Galaxy::Devel::Tool::App -command;

#core
use strict;
use warnings;
use autodie;

#cpan modules
use Config::Tiny;
use File::HomeDir;
use File::Spec::Functions;
use File::Path qw(make_path);
use Data::Dumper;
use Data::Validate::Domain qw(is_hostname);

use App::Galaxy::Devel::Tool;

sub usage_desc { "galaxp save [OPTIONS]" } 
sub abstract {
   "Saves the host and keyname with an option to list the current values.";
}

sub opt_spec {
   my ( $class, $app ) = @_;
    return ( 
           [ 'key_path|k=s' => "Path to pem key" ],
           [ 'host|h=s' => "URL to galaxy cloud server"],
           [ 'list|l'   => "List contents of config file"],
    );
}  
  
sub validate_args {
  my ($self, $opt, $args) = @_;

  #need one or the other $opt should not be empty
  if( !(%$opt) ) {
     $self->usage_error("Requires at least one option");
  }
  
  if( defined( $opt->{host} ) ) {
    $self->usage_error( "Please enter a valid host name e.g. ec2-67-202-53-53.compute-1.amazonaws.com\n" )  unless is_hostname( $opt->{host} );  
  } 
  
  if( defined ( $opt->{key_path} ) ) {
   $self->usage_error( 'Path name must be absolute. e.g /home/user/key.pem, c:\keys\key.pem'."\n" ) unless file_name_is_absolute( $opt->{key_path} );
   $self->usage_error( "File path for key does not exist\n") unless ( -e $opt->{key_path} );     
  }
}
  
sub execute {
    my ($self, $opt, $args) = @_;
    
    # Save to ini file in home directory    
    my $tool_dev = App::Galaxy::Devel::Tool->new;
     
    # Make directory .galaxy in std directory 
    my $config_dir =  catdir( $tool_dev->local_config_basename, $tool_dev->local_config_dirname  );
    make_path($config_dir) unless ( stat( $config_dir ) );    
    
    # Read unless it does not exists
    my $config_file = $tool_dev->local_config_file_path;
    my $Config;
    stat ( $config_file ) ? ( $Config = Config::Tiny->read( $config_file ) ) : ( $Config = Config::Tiny->new );
    my $str;
    
    ### Return with printed list - option --list
    if ( $opt->{ list } ) {
        print list_cfg( $Config );
        return 1;
    }
     
    ### option --host and --key    
    # Print the config file before changes 
    if ( stat ( $config_file ) ) {
      print "Config before save:\n";
      print list_cfg($Config);         
    }
    
    # Change host config     
    if(  defined( $opt->{ host } ) ) {
         print "... saving ", $opt->{host}, "\n";
         $Config->{_}->{ host } = $opt->{host};  
    }
    # Change key config
    if( defined( $opt->{key_path} ) ) {
       print "... saving ", $opt->{key_path}, "\n";
       $Config->{_}->{ key } = $opt->{ key_path };
    }
    
    #Write Config File     
    $Config->write( $config_file );
    
    #Print changed config file
    print "\n";
    print "Config file after save:\n";
    print list_cfg($Config);
 };
    
    
sub list_cfg {
  
  my $cfg = shift;
  my $str;
  
  return unless defined( $cfg->{_} );
  my %Config_Hash = %{ $cfg->{_} };
   foreach my $key (keys %Config_Hash ) {
         $str .= $key.": ".$Config_Hash{$key}."\n";
      } 
   return $str;
}    
1;    