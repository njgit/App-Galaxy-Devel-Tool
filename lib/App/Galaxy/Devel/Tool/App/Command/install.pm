# push distribution over
package App::Galaxy::Devel::Tool::App::Command::install;
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

sub usage_desc { "galaxp install [OPTIONS] [FILE|MODULE_NAME]" } 
sub abstract {
  "Installs a perl distribution on the remote host."
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

    die "Requires FILE or MODULE_NAME" unless my $dir = $args->[0];
    
    my $custom_tool_dir = $opt->{custom_tool_dir};     
     
    print "No key_path defined, attempt to use config file..\n" unless defined($opt->{ key_path });
    print "No host defined, attempt to use config file..\n" unless defined($opt->{ host });
    my $tool_dev = App::Galaxy::Devel::Tool->new;    
    $tool_dev->host( $opt->{ host } ) if ( defined( $opt->{ host } ) ); # otherwise they will be loaded from config
    $tool_dev->key_path( $opt->{ key_path } ) if ( defined( $opt->{ key_path }  ) );
    
    try { 
    
       print "Connecting to galaxy cloud...\n"; 
      
       # if its a local file, send over and install
       if( stat( $args->[0] ) ) { 
          $tool_dev->send_remote( $args->[0] );            # sends to /tmp on remote machine
          my ($volume,$directories,$file) = splitpath( $args->[0] );
          print "Installing... (this may take a while)\n";
          # uses cpanm to install into  home/galaxy/perl5 directory
          speak( $tool_dev->install_module_remote( catdir( '/tmp', $file )  ) );
        }
        else {
         #assume its a cpan module that will be installed using cpanm remotely.
          print "Installing... (this may take a while)\n";
          speak( $tool_dev->install_module_remote( $args->[0] ) );
        }   
      }catch {            
        die $_;               
      };
 }
 
 sub speak {
  my $out = shift;
  if(ref($out) eq 'ARRAY') {
    for ( 0 .. @$out-1 ) { print $out->[$_], "\n"; }    
  }; 
}

1;