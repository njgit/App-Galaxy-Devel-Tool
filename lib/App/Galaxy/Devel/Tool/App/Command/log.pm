# push distribution over
package App::Galaxy::Devel::Tool::App::Command::log;
use App::Galaxy::Devel::Tool::App -command;

#core
use strict;
use warnings;
use autodie;

#cpan
#use File::Path qw(make_path remove_tree);
use File::chdir;
use File::Spec::Functions qw(catdir splitpath);
use Data::Validate::Domain qw(is_hostname);
use Try::Tiny;
use File::HomeDir;
use Config::Tiny;

# lib
use App::Galaxy::Devel::Tool;

sub usage_desc { "galaxp install [OPTIONS]" } 

sub abstract {
  "Currently reads the cpanminus install log of the Galaxy cloud instance, which records details of the last installed perl distribution.";
}


sub opt_spec {
   my ( $class, $app ) = @_;
    return (            
           [ 'key_path|k=s' => "Path to pem key." ],
           [ 'host|h=s' => "URL to galaxy cloud server"],
    );
}  

sub validate_args {
  my ($self, $opt, $args) = @_;

  #need one or the other $opt should not be empty
 
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
        
    print "No key_path defined, attempt to use config file..\n" unless defined($opt->{ key_path });
    print "No host defined, attempt to use config file..\n" unless defined($opt->{ host });
    
    my $tool_dev = App::Galaxy::Devel::Tool->new; #catdir ensures trailing slashes don't interfere
    $tool_dev->host( $opt->{ host } ) if ( defined( $opt->{ host } ) ); # otherwise they will be loaded from config
    $tool_dev->key_path( $opt->{ key_path } ) if ( defined( $opt->{ key_path }  ) );

    # read log file
    print "Getting log contents ...\n";
    my $cpanm_log = $tool_dev->read_remote_cpanm_log->[0];
    print $cpanm_log, "\n";
    system
}    
1;