# push distribution over
package App::Galaxy::Devel::Tool::App::Command::ssh;
use App::Galaxy::Devel::Tool::App -command;

#core
use strict;
use warnings;
use autodie;

#cpan modules
use Config::Tiny;

use App::Galaxy::Devel::Tool;

sub usage_desc { "galaxp ssh [OPTIONS]" } 
sub abstract { "Start a ssh session on the Galaxy cloud master instance."; }

sub opt_spec {
   my ( $class, $app ) = @_;
    return ( 
           [ 'key_path|k=s' => "Path to pem key" ],
           [ 'host|h=s' => "URL to galaxy cloud server"],
           [ 'user|u=s' => "user name (default is ubuntu)"],

    );
}  

sub validate_args {
  my ($self, $opt, $args) = @_;

    
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
    
    my $tool_dev = App::Galaxy::Devel::Tool->new;
    my $config_file = $tool_dev->local_config_file_path;
    
    my ( $Config, $key_path, $host, $user);

    $Config = Config::Tiny->read( $config_file )  if stat ( $config_file );
    if( $Config ) {
        $key_path = $Config->{_}->{key};
        $host = $Config->{_}->{host};
    } else { print "No Config file defined... at $config_file \n "}
      
      $user = 'ubuntu';
      $key_path = $opt->{key_path} if defined (  $opt->{key_path} ) ;
      $host = $opt->{host} if defined(  $opt->{host} ) ;
      $user = $opt->{user} if defined(  $opt->{user} ) ;
      $self->usage_error( "Requires host.\n") unless defined($host);
      $self->usage_error( "Requires key path.\n") unless defined($key_path);
      system( "ssh -o StrictHostKeyChecking=no -i $key_path $user".'@'."$host");    
}
1;